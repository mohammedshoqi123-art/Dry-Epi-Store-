import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGINS') ?? 'https://mohammedshoqi123-art.github.io',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Vary': 'Origin',
}

// ─── Role hierarchy for permission validation ────────────────
const ROLE_HIERARCHY: Record<string, number> = {
  'admin': 5,
  'central': 4,
  'governorate': 3,
  'district': 2,
  'data_entry': 1,
}

// ─── Rate limiting via DB (survives across stateless invocations) ──
async function checkRateLimit(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  limit = 10,
  windowSeconds = 60
): Promise<boolean> {
  const { data } = await supabase.rpc('check_and_increment_rate_limit', {
    p_user_id: userId,
    p_endpoint: 'submit-form',
    p_window_seconds: windowSeconds,
    p_max_requests: limit,
  })
  return data?.[0]?.allowed ?? true
}

// ─── Hierarchical permission validation ──────────────────────
interface UserProfile {
  role: string
  governorate_id: string | null
  district_id: string | null
}

async function validateSubmissionPermissions(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  targetGovId: string | null,
  targetDistId: string | null
): Promise<{ valid: boolean; error?: string }> {
  const { data: profile, error } = await supabase
    .from('profiles')
    .select('role, governorate_id, district_id')
    .eq('id', userId)
    .single()

  if (error || !profile) return { valid: false, error: 'User profile not found' }

  const p = profile as UserProfile

  switch (p.role) {
    case 'admin':
    case 'central':
      // Can submit for any governorate/district
      return { valid: true }

    case 'governorate':
      if (targetGovId && targetGovId !== p.governorate_id) {
        return { valid: false, error: 'Cannot submit data for a different governorate' }
      }
      return { valid: true }

    case 'district':
      if (targetGovId && targetGovId !== p.governorate_id) {
        return { valid: false, error: 'Cannot submit data for a different governorate' }
      }
      if (targetDistId && targetDistId !== p.district_id) {
        return { valid: false, error: 'Cannot submit data for a different district' }
      }
      return { valid: true }

    case 'data_entry':
      if (targetGovId !== p.governorate_id || targetDistId !== p.district_id) {
        return { valid: false, error: 'Data entry users can only submit for their assigned area' }
      }
      return { valid: true }

    default:
      return { valid: false, error: `Invalid role: ${p.role}` }
  }
}

// ─── Main handler ────────────────────────────────────────────
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

    // ─── Rate Limiting ──────────────────────────────────────
    if (!(await checkRateLimit(supabase, user.id))) {
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

    // ─── Validate Required Fields ───────────────────────────
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

    // Validate payload size (max 1MB)
    const payloadSize = JSON.stringify(body).length
    if (payloadSize > 1024 * 1024) {
      return new Response(JSON.stringify({ error: 'Payload too large (max 1MB)' }), {
        status: 413, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ─── Hierarchical Permission Check ──────────────────────
    const permCheck = await validateSubmissionPermissions(
      supabase, user.id,
      governorate_id ?? null,
      district_id ?? null
    )
    if (!permCheck.valid) {
      return new Response(JSON.stringify({ error: permCheck.error }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ─── Verify Form Exists ─────────────────────────────────
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

    // Get user profile for role check
    const { data: profile } = await supabase
      .from('profiles')
      .select('governorate_id, district_id, role')
      .eq('id', user.id)
      .single()

    // Check role permission against form's allowed_roles
    if (form.allowed_roles && profile?.role && !form.allowed_roles.includes(profile.role)) {
      return new Response(JSON.stringify({ error: 'Your role does not have permission to submit this form' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
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

    // ─── Use authoritative profile values (NOT user-supplied) ────
    // Only admin/central can override governorate/district
    const effectiveGovId = (profile?.role === 'admin' || profile?.role === 'central')
      ? (governorate_id || profile?.governorate_id || null)
      : (profile?.governorate_id || null)

    const effectiveDistId = (profile?.role === 'admin' || profile?.role === 'central')
      ? (district_id || profile?.district_id || null)
      : (profile?.district_id || null)

    const submissionData = {
      form_id,
      submitted_by: user.id,
      governorate_id: effectiveGovId,
      district_id: effectiveDistId,
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

    // ─── Check for duplicate offline submission (Idempotency) ────
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

    // Log audit (fire-and-forget)
    await supabase.from('audit_logs').insert({
      user_id: user.id,
      action: 'submit',
      table_name: 'form_submissions',
      record_id: submission.id,
      metadata: { form_id, is_offline, offline_id, governorate_id: effectiveGovId }
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
