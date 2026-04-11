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

    // Verify auth
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const body = await req.json().catch(() => ({}))
    const { governorate_id, district_id, start_date, end_date } = body

    // ─── Submission Stats (aggregated in DB) ──────────────────
    // Total count
    let totalQuery = supabase
      .from('form_submissions')
      .select('*', { count: 'exact', head: true })
      .is('deleted_at', null)

    if (governorate_id) totalQuery = totalQuery.eq('governorate_id', governorate_id)
    if (district_id) totalQuery = totalQuery.eq('district_id', district_id)
    if (start_date) totalQuery = totalQuery.gte('created_at', start_date)
    if (end_date) totalQuery = totalQuery.lte('created_at', end_date)

    const { count: totalCount } = await totalQuery

    // Today's count
    const today = new Date().toISOString().split('T')[0]
    let todayQuery = supabase
      .from('form_submissions')
      .select('*', { count: 'exact', head: true })
      .is('deleted_at', null)
      .gte('created_at', `${today}T00:00:00Z`)
      .lte('created_at', `${today}T23:59:59Z`)

    if (governorate_id) todayQuery = todayQuery.eq('governorate_id', governorate_id)
    if (district_id) todayQuery = todayQuery.eq('district_id', district_id)

    const { count: todayCount } = await todayQuery

    // By status — use a limited query grouped in SQL
    let statusQuery = supabase
      .from('form_submissions')
      .select('status')
      .is('deleted_at', null)

    if (governorate_id) statusQuery = statusQuery.eq('governorate_id', governorate_id)
    if (district_id) statusQuery = statusQuery.eq('district_id', district_id)
    if (start_date) statusQuery = statusQuery.gte('created_at', start_date)
    if (end_date) statusQuery = statusQuery.lte('created_at', end_date)

    const { data: statusRows } = await statusQuery.limit(10000)

    const byStatus: Record<string, number> = {}
    for (const row of (statusRows ?? [])) {
      byStatus[row.status] = (byStatus[row.status] || 0) + 1
    }

    // By day (last 7 days)
    const last7Days: Record<string, number> = {}
    for (let i = 6; i >= 0; i--) {
      const d = new Date()
      d.setDate(d.getDate() - i)
      const dayKey = d.toISOString().split('T')[0]

      let dayQuery = supabase
        .from('form_submissions')
        .select('*', { count: 'exact', head: true })
        .is('deleted_at', null)
        .gte('created_at', `${dayKey}T00:00:00Z`)
        .lte('created_at', `${dayKey}T23:59:59Z`)

      if (governorate_id) dayQuery = dayQuery.eq('governorate_id', governorate_id)
      if (district_id) dayQuery = dayQuery.eq('district_id', district_id)

      const { count } = await dayQuery
      last7Days[dayKey] = count ?? 0
    }

    // ─── Shortage Stats (aggregated) ──────────────────────────
    let shortageTotalQuery = supabase
      .from('supply_shortages')
      .select('*', { count: 'exact', head: true })
      .is('deleted_at', null)

    if (governorate_id) shortageTotalQuery = shortageTotalQuery.eq('governorate_id', governorate_id)
    if (district_id) shortageTotalQuery = shortageTotalQuery.eq('district_id', district_id)

    const { count: shortageTotal } = await shortageTotalQuery

    // Resolved shortages
    let resolvedQuery = supabase
      .from('supply_shortages')
      .select('*', { count: 'exact', head: true })
      .is('deleted_at', null)
      .eq('is_resolved', true)

    if (governorate_id) resolvedQuery = resolvedQuery.eq('governorate_id', governorate_id)
    if (district_id) resolvedQuery = resolvedQuery.eq('district_id', district_id)

    const { count: resolvedCount } = await resolvedQuery

    // By severity
    let severityQuery = supabase
      .from('supply_shortages')
      .select('severity')
      .is('deleted_at', null)

    if (governorate_id) severityQuery = severityQuery.eq('governorate_id', governorate_id)
    if (district_id) severityQuery = severityQuery.eq('district_id', district_id)

    const { data: severityRows } = await severityQuery.limit(2000)

    const bySeverity: Record<string, number> = {}
    for (const row of (severityRows ?? [])) {
      bySeverity[row.severity] = (bySeverity[row.severity] || 0) + 1
    }

    // ─── Top Governorates ─────────────────────────────────────
    let govQuery = supabase
      .from('form_submissions')
      .select('governorate_id')
      .not('governorate_id', 'is', null)
      .is('deleted_at', null)
      .limit(5000)

    if (start_date) govQuery = govQuery.gte('created_at', start_date)
    if (end_date) govQuery = govQuery.lte('created_at', end_date)

    const { data: govRows } = await govQuery

    const govCounts: Record<string, number> = {}
    for (const row of (govRows ?? [])) {
      govCounts[row.governorate_id] = (govCounts[row.governorate_id] || 0) + 1
    }

    const topGovernorates = Object.entries(govCounts)
      .map(([id, count]) => ({ governorate_id: id, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5)

    const analytics = {
      submissions: {
        total: totalCount ?? 0,
        today: todayCount ?? 0,
        byStatus,
        byDay: last7Days,
      },
      shortages: {
        total: shortageTotal ?? 0,
        resolved: resolvedCount ?? 0,
        pending: (shortageTotal ?? 0) - (resolvedCount ?? 0),
        bySeverity,
      },
      topGovernorates,
      generatedAt: new Date().toISOString(),
      filters: { governorate_id, district_id, start_date, end_date },
    }

    return new Response(JSON.stringify(analytics), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Analytics error:', error)
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
