import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// In-memory rate limiter (per instance, sufficient for Edge Functions)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>()

function checkRateLimit(userId: string, limit = 10, windowMs = 60000): boolean {
  const now = Date.now()
  const entry = rateLimitMap.get(userId)

  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(userId, { count: 1, resetAt: now + windowMs })
    return true
  }

  if (entry.count >= limit) {
    return false
  }

  entry.count++
  return true
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ─── Rate Limiting ────────────────────────────────────────
    if (!checkRateLimit(user.id)) {
      return new Response(JSON.stringify({ error: 'Rate limit exceeded. Max 10 submissions per minute.' }), {
        status: 429,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Retry-After': '60',
        }
      })
    }

    const body = await req.json()
    const {
      form_id, data: formData, status = 'submitted', governorate_id, district_id,
      gps_lat, gps_lng, gps_accuracy, photos = [], notes,
      offline_id, device_id, app_version, is_offline = false
    } = body

    // ─── Validate Required Fields ─────────────────────────────
    if (!form_id || typeof form_id !== 'string') {
      return new Response(JSON.stringify({ error: 'form_id is required and must be a string' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Validate status enum
    const validStatuses = ['draft', 'submitted', 'reviewed', 'approved', 'rejected']
    if (!validStatuses.includes(status)) {
      return new Response(JSON.stringify({ error: `Invalid status. Must be one of: ${validStatuses.join(', ')}` }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Validate GPS coordinates if provided
    if (gps_lat !== undefined && gps_lat !== null) {
      if (typeof gps_lat !== 'number' || gps_lat < -90 || gps_lat > 90) {
        return new Response(JSON.stringify({ error: 'Invalid gps_lat: must be between -90 and 90' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }
    if (gps_lng !== undefined && gps_lng !== null) {
      if (typeof gps_lng !== 'number' || gps_lng < -180 || gps_lng > 180) {
        return new Response(JSON.stringify({ error: 'Invalid gps_lng: must be between -180 and 180' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }

    // ─── Verify Form Exists ───────────────────────────────────
    const { data: form, error: formError } = await supabase
      .from('forms')
      .select('id, requires_gps, requires_photo, allowed_roles, schema')
      .eq('id', form_id)
      .eq('is_active', true)
      .is('deleted_at', null)
      .single()

    if (formError || !form) {
      return new Response(JSON.stringify({ error: 'Form not found or inactive' }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Check GPS requirement
    if (form.requires_gps && (gps_lat === undefined || gps_lat === null || gps_lng === undefined || gps_lng === null)) {
      return new Response(JSON.stringify({ error: 'GPS location is required for this form' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Check photo requirement
    if (form.requires_photo && (!photos || photos.length === 0)) {
      return new Response(JSON.stringify({ error: 'At least one photo is required for this form' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Get user profile for role + governorate/district
    const { data: profile } = await supabase
      .from('profiles')
      .select('governorate_id, district_id, role')
      .eq('id', user.id)
      .single()

    // Check role permission
    if (form.allowed_roles && profile?.role && !form.allowed_roles.includes(profile.role)) {
      return new Response(JSON.stringify({ error: 'Your role does not have permission to submit this form' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const submissionData = {
      form_id,
      submitted_by: user.id,
      governorate_id: governorate_id || profile?.governorate_id || null,
      district_id: district_id || profile?.district_id || null,
      status,
      data: formData || {},
      gps_lat: gps_lat || null,
      gps_lng: gps_lng || null,
      gps_accuracy: gps_accuracy || null,
      photos: Array.isArray(photos) ? photos : [],
      notes: notes || null,
      offline_id: offline_id || null,
      device_id: device_id || null,
      app_version: app_version || null,
      is_offline,
      submitted_at: status === 'submitted' ? new Date().toISOString() : null,
      synced_at: is_offline ? new Date().toISOString() : null,
    }

    // Check for duplicate offline submission
    if (offline_id) {
      const { data: existing } = await supabase
        .from('form_submissions')
        .select('id, status')
        .eq('offline_id', offline_id)
        .maybeSingle()

      if (existing) {
        return new Response(JSON.stringify({
          success: true,
          status: 'duplicate',
          submission: existing,
          offline_id
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }

    const { data: submission, error: submitError } = await supabase
      .from('form_submissions')
      .insert(submissionData)
      .select()
      .single()

    if (submitError) {
      console.error('Submit error:', submitError)
      return new Response(JSON.stringify({ error: submitError.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Log audit
    await supabase.from('audit_logs').insert({
      user_id: user.id,
      action: 'submit',
      table_name: 'form_submissions',
      record_id: submission.id,
      metadata: { form_id, is_offline, offline_id }
    }).then(() => {}).catch(() => {})

    return new Response(JSON.stringify({
      success: true,
      submission,
      offline_id
    }), {
      status: 201,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Unhandled error:', error)
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
