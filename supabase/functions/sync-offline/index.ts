import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGINS') ?? 'https://mohammedshoqi123-art.github.io',
  'Vary': 'Origin',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
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

    const body = await req.json()
    const { items = [] } = body

    if (!Array.isArray(items) || items.length === 0) {
      return new Response(JSON.stringify({ results: [], errors: [], message: 'No items to sync' }), {
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const results: Array<{ offline_id: string; status: string; submission_id?: string }> = []
    const errors: Array<{ offline_id?: string; error: string }> = []

    // Use service role for sync to bypass RLS during batch insert
    const adminSupabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch user profile ONCE (not N times in the loop)
    const { data: profile } = await adminSupabase
      .from('profiles')
      .select('governorate_id, district_id, role')
      .eq('id', user.id)
      .single()

    // Pre-check: collect all offline_ids to detect duplicates in one query
    const offlineIds = items.filter(i => i.offline_id).map(i => i.offline_id)
    const existingMap = new Map<string, string>()
    if (offlineIds.length > 0) {
      const { data: existing } = await adminSupabase
        .from('form_submissions')
        .select('offline_id, id')
        .in('offline_id', offlineIds)
      if (existing) {
        for (const row of existing) {
          existingMap.set(row.offline_id, row.id)
        }
      }
    }

    for (const item of items) {
      const offlineId = item.offline_id as string | undefined

      try {
        // Check for duplicate using pre-fetched map (no DB query)
        if (offlineId && existingMap.has(offlineId)) {
          results.push({ offline_id: offlineId, status: 'duplicate', submission_id: existingMap.get(offlineId) })
          continue
        }

        const submissionData = {
          form_id: item.form_id,
          submitted_by: user.id,
          governorate_id: item.governorate_id || profile?.governorate_id || null,
          district_id: item.district_id || profile?.district_id || null,
          status: 'submitted',
          data: item.data || {},
          gps_lat: item.gps_lat || null,
          gps_lng: item.gps_lng || null,
          gps_accuracy: item.gps_accuracy || null,
          photos: item.photos || [],
          notes: item.notes || null,
          offline_id: offlineId || null,
          device_id: item.device_id || null,
          app_version: item.app_version || null,
          is_offline: true,
          submitted_at: item.created_at || new Date().toISOString(),
          synced_at: new Date().toISOString(),
        }

        // Insert submission
        const { data: submission, error: insertError } = await adminSupabase
          .from('form_submissions')
          .insert(submissionData)
          .select('id')
          .single()

        if (insertError) {
          errors.push({ offline_id: offlineId, error: insertError.message })
          continue
        }

        results.push({ offline_id: offlineId || '', status: 'synced', submission_id: submission.id })

        // Log audit
        await adminSupabase.from('audit_logs').insert({
          user_id: user.id,
          action: 'create',
          table_name: 'form_submissions',
          record_id: submission.id,
          metadata: { offline_sync: true, offline_id: offlineId }
        }).then(() => {}).catch(() => {})

      } catch (err) {
        errors.push({ offline_id: offlineId, error: err instanceof Error ? err.message : String(err) })
      }
    }

    const response = {
      results,
      errors,
      summary: {
        total: items.length,
        synced: results.filter(r => r.status === 'synced').length,
        duplicate: results.filter(r => r.status === 'duplicate').length,
        failed: errors.length,
      }
    }

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Sync error:', error)
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Internal server error', results: [], errors: [{ error: error instanceof Error ? error.message : 'Internal server error' }] }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
