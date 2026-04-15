import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from '@supabase/supabase-js'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { authenticateRequest, createUserClient } from '../_shared/auth.ts'

// ─── Role hierarchy for permission validation ────────────────
const ROLE_HIERARCHY: Record<string, number> = {
  'admin': 5,
  'central': 4,
  'governorate': 3,
  'district': 2,
  'data_entry': 1,
}

// ─── Rate limiting via DB (fail-closed for sensitive operations) ──
async function checkRateLimit(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  limit = 10,
  windowSeconds = 60
): Promise<boolean> {
  try {
    const { data, error } = await supabase.rpc('check_and_increment_rate_limit', {
      p_user_id: userId,
      p_endpoint: 'submit-form',
      p_window_seconds: windowSeconds,
      p_max_requests: limit,
    })
    if (error) {
      // RPC failed — fail-closed for form submissions (sensitive operation)
      console.error('Rate limit RPC error (blocking request):', error.message)
      return false
    }
    return data?.[0]?.allowed ?? false
  } catch (e) {
    // Fail-closed: block submissions if rate limiting is broken
    console.error('Rate limit check failed (blocking request):', e)
    return false
  }
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
  const origin = req.headers.get('Origin')
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonResponse({ error: 'Missing authorization header' }, 401, origin)
    }

    const supabase = createUserClient(authHeader)

    // Authenticate — no JWT fallback, signature must be valid
    const auth = await authenticateRequest(supabase, authHeader)
    if (!auth) {
      return jsonResponse({ error: 'Unauthorized' }, 401, origin)
    }

    // ─── Rate Limiting (fail-closed) ──────────────────────
    if (!(await checkRateLimit(supabase, auth.userId))) {
      return new Response(JSON.stringify({ error: 'Rate limit exceeded. Max 10 submissions per minute.' }), {
        status: 429,
        headers: {
          ...corsHeaders(origin),
          'Content-Type': 'application/json',
          'Retry-After': '60',
        },
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
      return jsonResponse({ error: 'form_id is required and must be a string' }, 400, origin)
    }

    const validStatuses = ['draft', 'submitted', 'reviewed', 'approved', 'rejected']
    if (!validStatuses.includes(status)) {
      return jsonResponse({ error: `Invalid status. Must be one of: ${validStatuses.join(', ')}` }, 400, origin)
    }

    if (gps_lat !== undefined && gps_lat !== null) {
      if (typeof gps_lat !== 'number' || gps_lat < -90 || gps_lat > 90) {
        return jsonResponse({ error: 'Invalid gps_lat: must be between -90 and 90' }, 400, origin)
      }
    }
    if (gps_lng !== undefined && gps_lng !== null) {
      if (typeof gps_lng !== 'number' || gps_lng < -180 || gps_lng > 180) {
        return jsonResponse({ error: 'Invalid gps_lng: must be between -180 and 180' }, 400, origin)
      }
    }

    const payloadSize = JSON.stringify(body).length
    if (payloadSize > 1024 * 1024) {
      return jsonResponse({ error: 'Payload too large (max 1MB)' }, 413, origin)
    }

    // ─── Hierarchical Permission Check ──────────────────────
    const permCheck = await validateSubmissionPermissions(
      supabase, auth.userId,
      governorate_id ?? null,
      district_id ?? null
    )
    if (!permCheck.valid) {
      return jsonResponse({ error: permCheck.error }, 403, origin)
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
      return jsonResponse({ error: 'Form not found or inactive' }, 404, origin)
    }

    // Get user profile for role check
    const { data: profile } = await supabase
      .from('profiles')
      .select('governorate_id, district_id, role')
      .eq('id', auth.userId)
      .single()

    // Check role permission against form's allowed_roles
    if (form.allowed_roles && profile?.role && !form.allowed_roles.includes(profile.role)) {
      return jsonResponse({ error: 'Your role does not have permission to submit this form' }, 403, origin)
    }

    // Check GPS requirement
    if (form.requires_gps && (gps_lat == null || gps_lng == null)) {
      return jsonResponse({ error: 'This form requires GPS coordinates' }, 400, origin)
    }

    // Check photo requirement
    if (form.requires_photo && (!photos || photos.length === 0)) {
      return jsonResponse({ error: 'This form requires at least one photo' }, 400, origin)
    }

    // ─── Insert Submission ─────────────────────────────────
    const submissionData = {
      form_id,
      submitted_by: auth.userId,
      governorate_id: governorate_id || profile?.governorate_id || null,
      district_id: district_id || profile?.district_id || null,
      status,
      data: formData || {},
      gps_lat: gps_lat || null,
      gps_lng: gps_lng || null,
      gps_accuracy: gps_accuracy || null,
      photos: photos || [],
      notes: notes || null,
      offline_id: offline_id || null,
      device_id: device_id || null,
      app_version: app_version || null,
      is_offline,
      submitted_at: new Date().toISOString(),
      synced_at: is_offline ? new Date().toISOString() : null,
    }

    const { data: submission, error: insertError } = await supabase
      .from('form_submissions')
      .insert(submissionData)
      .select('id, status, created_at')
      .single()

    if (insertError) {
      if (insertError.code === '23505') {
        // Unique constraint violation — duplicate offline_id
        return jsonResponse({
          success: true,
          message: 'Duplicate submission detected',
          duplicate: true,
        }, 200, origin)
      }
      return jsonResponse({ error: `Submission failed: ${insertError.message}` }, 400, origin)
    }

    return jsonResponse({
      success: true,
      submission_id: submission.id,
      status: submission.status,
      created_at: submission.created_at,
    }, 201, origin)

  } catch (error) {
    console.error('Submit form error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, origin)
  }
})
