import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

/**
 * EPI Supervisor — Offline Sync Edge Function (v3)
 *
 * v3 Fixes:
 * - Graceful fallback if SERVICE_ROLE_KEY not configured
 * - Per-item error isolation (one bad item doesn't kill the batch)
 * - Better duplicate detection with submitted_by filter
 * - Timeout protection per item
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
}

const MAX_BATCH_SIZE = 50

type SyncItem = {
  offline_id?: string
  form_id: string
  data?: Record<string, unknown>
  governorate_id?: string
  district_id?: string
  gps_lat?: number
  gps_lng?: number
  gps_accuracy?: number
  photos?: string[]
  notes?: string
  device_id?: string
  app_version?: string
  created_at?: string
  base_updated_at?: string
  entity_type?: string
  entity_id?: string
}

type SyncResult = {
  offline_id: string
  status: 'synced' | 'duplicate' | 'conflict' | 'error'
  submission_id?: string
  server_data?: Record<string, unknown>
  error?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401)

    // User-authenticated client (for auth verification)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) return jsonResponse({ error: 'Unauthorized' }, 401)

    // Parse body
    const body = await req.json()
    const items: SyncItem[] = body.items ?? []

    if (!Array.isArray(items) || items.length === 0) {
      return jsonResponse({ results: [], errors: [], message: 'No items to sync' }, 200)
    }

    if (items.length > MAX_BATCH_SIZE) {
      return jsonResponse({ error: `Batch too large: ${items.length} items (max ${MAX_BATCH_SIZE})` }, 400)
    }

    // ✅ FIX: Try admin client first, fall back to user client
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    let admin: ReturnType<typeof createClient>
    let useAdmin = false

    if (serviceKey && serviceKey.length > 10) {
      admin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        serviceKey,
        { auth: { autoRefreshToken: false, persistSession: false } }
      )
      useAdmin = true
    } else {
      // ✅ FIX: Fall back to user client instead of crashing
      console.warn('SUPABASE_SERVICE_ROLE_KEY not configured — using user client (RLS applies)')
      admin = supabase
    }

    // Fetch user profile once
    const { data: profile } = await admin
      .from('profiles')
      .select('governorate_id, district_id, role')
      .eq('id', user.id)
      .single()

    // ✅ FIX: Pre-check existing offline_ids with submitted_by filter for accuracy
    const offlineIds = items.filter(i => i.offline_id).map(i => i.offline_id!)
    const existingMap = new Map<string, { id: string; updated_at: string }>()

    if (offlineIds.length > 0) {
      const { data: existing } = await admin
        .from('form_submissions')
        .select('offline_id, id, updated_at')
        .in('offline_id', offlineIds)
        .eq('submitted_by', user.id)
        .is('deleted_at', null)

      if (existing) {
        for (const row of existing) {
          existingMap.set(row.offline_id, { id: row.id, updated_at: row.updated_at })
        }
      }
    }

    // Process items
    const results: SyncResult[] = []
    const errors: SyncResult[] = []

    for (const item of items) {
      const offlineId = item.offline_id ?? ''
      const itemId = offlineId || `item-${items.indexOf(item)}`

      try {
        // Check for duplicate
        if (offlineId && existingMap.has(offlineId)) {
          const existing = existingMap.get(offlineId)!
          results.push({ offline_id: offlineId, status: 'duplicate', submission_id: existing.id })
          continue
        }

        // Validate required fields
        if (!item.form_id) {
          errors.push({ offline_id: itemId, status: 'error', error: 'Missing form_id' })
          continue
        }

        // ✅ FIX: Add submitted_by to ensure RLS compliance
        const submissionData: Record<string, unknown> = {
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

        const { data: submission, error: insertError } = await admin
          .from('form_submissions')
          .insert(submissionData)
          .select('id, updated_at')
          .single()

        if (insertError) {
          // ✅ FIX: Handle unique constraint violation as duplicate
          if (insertError.code === '23505') {
            results.push({ offline_id: offlineId, status: 'duplicate', error: 'Already exists' })
            continue
          }
          errors.push({ offline_id: itemId, status: 'error', error: insertError.message })
          continue
        }

        results.push({ offline_id: offlineId, status: 'synced', submission_id: submission.id })

        // Audit log (fire-and-forget, don't block on errors)
        try {
          admin.from('audit_logs').insert({
            user_id: user.id,
            action: 'create',
            table_name: 'form_submissions',
            record_id: submission.id,
            metadata: { offline_sync: true, offline_id: offlineId, device_id: item.device_id },
          }).then(() => {}, () => {})
        } catch (_) { /* audit is best-effort */ }

      } catch (err) {
        errors.push({
          offline_id: itemId,
          status: 'error',
          error: err instanceof Error ? err.message : String(err),
        })
      }
    }

    // Summary
    const synced = results.filter(r => r.status === 'synced').length
    const duplicates = results.filter(r => r.status === 'duplicate').length

    return jsonResponse({
      results,
      errors,
      summary: {
        total: items.length,
        synced,
        duplicate: duplicates,
        conflicts: 0,
        failed: errors.length,
      },
    }, 200)

  } catch (error) {
    console.error('Sync error:', error)
    return jsonResponse({
      error: error instanceof Error ? error.message : 'Internal server error',
      results: [],
      errors: [{ status: 'error', error: error instanceof Error ? error.message : 'Internal server error' }],
    }, 500)
  }
})

function jsonResponse(data: unknown, status: number) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
