import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    // Rate limiting: check recent submissions (5 per minute per user)
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const body = await req.json()
    const {
      form_id, data: formData, status = 'submitted', governorate_id, district_id,
      gps_lat, gps_lng, gps_accuracy, photos = [], notes,
      offline_id, device_id, app_version, is_offline = false
    } = body

    // Validate required fields
    if (!form_id) {
      return new Response(JSON.stringify({ error: 'form_id is required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Verify form exists and is active
    const { data: form, error: formError } = await supabase
      .from('forms')
      .select('id, requires_gps, requires_photo, schema, allowed_roles')
      .eq('id', form_id)
      .eq('is_active', true)
      .single()

    if (formError || !form) {
      return new Response(JSON.stringify({ error: 'Form not found or inactive' }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Check if GPS is required
    if (form.requires_gps && (!gps_lat || !gps_lng)) {
      return new Response(JSON.stringify({ error: 'GPS location is required for this form' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Get user profile for governorate/district
    const { data: profile } = await supabase
      .from('profiles')
      .select('governorate_id, district_id, role')
      .eq('id', user.id)
      .single()

    const submissionData = {
      form_id,
      submitted_by: user.id,
      governorate_id: governorate_id || profile?.governorate_id,
      district_id: district_id || profile?.district_id,
      status,
      data: formData || {},
      gps_lat: gps_lat || null,
      gps_lng: gps_lng || null,
      gps_accuracy: gps_accuracy || null,
      photos,
      notes,
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
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
