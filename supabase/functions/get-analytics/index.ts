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

    const body = await req.json().catch(() => ({}))
    const { governorate_id, district_id, start_date, end_date } = body

    // Build filters
    const submissionFilters: Record<string, unknown> = {}
    if (governorate_id) submissionFilters.governorate_id = governorate_id
    if (district_id) submissionFilters.district_id = district_id

    // Fetch submissions
    let submissionsQuery = supabase
      .from('form_submissions')
      .select('id, status, governorate_id, district_id, created_at, submitted_at')
      .is('deleted_at', null)

    if (governorate_id) submissionsQuery = submissionsQuery.eq('governorate_id', governorate_id)
    if (district_id) submissionsQuery = submissionsQuery.eq('district_id', district_id)
    if (start_date) submissionsQuery = submissionsQuery.gte('created_at', start_date)
    if (end_date) submissionsQuery = submissionsQuery.lte('created_at', end_date)

    const { data: submissions = [] } = await submissionsQuery.limit(5000)

    // Fetch shortages
    let shortagesQuery = supabase
      .from('supply_shortages')
      .select('id, severity, is_resolved, governorate_id, district_id, created_at')
      .is('deleted_at', null)

    if (governorate_id) shortagesQuery = shortagesQuery.eq('governorate_id', governorate_id)
    if (district_id) shortagesQuery = shortagesQuery.eq('district_id', district_id)

    const { data: shortages = [] } = await shortagesQuery.limit(2000)

    // Compute submission stats
    const byStatus: Record<string, number> = {}
    const byDay: Record<string, number> = {}
    let todayCount = 0
    const today = new Date().toISOString().split('T')[0]

    for (const s of submissions) {
      // By status
      byStatus[s.status] = (byStatus[s.status] || 0) + 1
      // By day (last 7 days)
      const day = s.created_at?.split('T')[0]
      if (day) byDay[day] = (byDay[day] || 0) + 1
      // Today
      if (day === today) todayCount++
    }

    // Fill last 7 days
    const last7Days: Record<string, number> = {}
    for (let i = 6; i >= 0; i--) {
      const d = new Date()
      d.setDate(d.getDate() - i)
      const key = d.toISOString().split('T')[0]
      last7Days[key] = byDay[key] || 0
    }

    // Compute shortage stats
    const bySeverity: Record<string, number> = {}
    let resolvedCount = 0
    for (const s of shortages) {
      bySeverity[s.severity] = (bySeverity[s.severity] || 0) + 1
      if (s.is_resolved) resolvedCount++
    }

    // Top governorates
    const govCounts: Record<string, number> = {}
    for (const s of submissions) {
      if (s.governorate_id) {
        govCounts[s.governorate_id] = (govCounts[s.governorate_id] || 0) + 1
      }
    }

    const analytics = {
      submissions: {
        total: submissions.length,
        today: todayCount,
        byStatus,
        byDay: last7Days,
      },
      shortages: {
        total: shortages.length,
        resolved: resolvedCount,
        pending: shortages.length - resolvedCount,
        bySeverity,
      },
      topGovernorates: Object.entries(govCounts)
        .map(([id, count]) => ({ governorate_id: id, count }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 5),
      generatedAt: new Date().toISOString(),
      filters: { governorate_id, district_id, start_date, end_date },
    }

    return new Response(JSON.stringify(analytics), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Analytics error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
