import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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
    const { governorate_id, district_id, start_date, end_date, form_id } = body

    // ─── Submission Stats (using RPC for aggregation) ─────────
    // Try using the dashboard stats function first
    const { data: dashStats } = await supabase.rpc('get_dashboard_stats', {
      p_user_id: user.id
    }).maybeSingle()

    // ─── Today's count ──────────────────────────────────────
    const today = new Date().toISOString().split('T')[0]
    let todayQuery = supabase
      .from('form_submissions')
      .select('*', { count: 'exact', head: true })
      .is('deleted_at', null)
      .gte('created_at', `${today}T00:00:00Z`)
      .lte('created_at', `${today}T23:59:59Z`)

    if (governorate_id) todayQuery = todayQuery.eq('governorate_id', governorate_id)
    if (district_id) todayQuery = todayQuery.eq('district_id', district_id)
    if (form_id) todayQuery = todayQuery.eq('form_id', form_id)

    const { count: todayCount } = await todayQuery

    // ─── Submissions by status (single query) ───────────────
    let statusQuery = supabase
      .from('form_submissions')
      .select('status')
      .is('deleted_at', null)

    if (governorate_id) statusQuery = statusQuery.eq('governorate_id', governorate_id)
    if (district_id) statusQuery = statusQuery.eq('district_id', district_id)
    if (form_id) statusQuery = statusQuery.eq('form_id', form_id)
    if (start_date) statusQuery = statusQuery.gte('created_at', start_date)
    if (end_date) statusQuery = statusQuery.lte('created_at', end_date)

    const { data: statusRows } = await statusQuery.limit(10000)

    const byStatus: Record<string, number> = {}
    let totalCount = 0
    for (const row of (statusRows ?? [])) {
      byStatus[row.status] = (byStatus[row.status] || 0) + 1
      totalCount++
    }

    // ─── By day (last 7 days) — single query with date filter ──
    const last7Days: Record<string, number> = {}
    const sevenDaysAgo = new Date()
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6)
    const startDate7d = sevenDaysAgo.toISOString().split('T')[0]

    let dayQuery = supabase
      .from('form_submissions')
      .select('created_at')
      .is('deleted_at', null)
      .gte('created_at', `${startDate7d}T00:00:00Z`)

    if (governorate_id) dayQuery = dayQuery.eq('governorate_id', governorate_id)
    if (district_id) dayQuery = dayQuery.eq('district_id', district_id)
    if (form_id) dayQuery = dayQuery.eq('form_id', form_id)

    const { data: dayRows } = await dayQuery.limit(10000)

    // Initialize all 7 days to 0
    for (let i = 6; i >= 0; i--) {
      const d = new Date()
      d.setDate(d.getDate() - i)
      last7Days[d.toISOString().split('T')[0]] = 0
    }
    // Count from actual data
    for (const row of (dayRows ?? [])) {
      const dayKey = row.created_at.split('T')[0]
      if (last7Days[dayKey] !== undefined) {
        last7Days[dayKey]++
      }
    }

    // ─── Shortage Stats ─────────────────────────────────────
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

    // By severity (single query)
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

    // ─── Top Governorates (single query) ────────────────────
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

    // ─── Governorate breakdown (single aggregation query) ──
    const { data: allGovs } = await supabase
      .from('governorates')
      .select('id, name_ar, name_en')
      .eq('is_active', true)

    // Fetch all submission governorate_ids in one query
    let allSubGovQuery = supabase
      .from('form_submissions')
      .select('governorate_id')
      .not('governorate_id', 'is', null)
      .is('deleted_at', null)
      .limit(10000)

    if (form_id) allSubGovQuery = allSubGovQuery.eq('form_id', form_id)
    if (start_date) allSubGovQuery = allSubGovQuery.gte('created_at', start_date)
    if (end_date) allSubGovQuery = allSubGovQuery.lte('created_at', end_date)

    const { data: allSubGovRows } = await allSubGovQuery

    const govBreakdownCounts: Record<string, number> = {}
    for (const row of (allSubGovRows ?? [])) {
      const gid = row.governorate_id
      govBreakdownCounts[gid] = (govBreakdownCounts[gid] || 0) + 1
    }

    const govBreakdown: any[] = []
    const govNameMap: Record<string, { nameAr: string; nameEn: string }> = {}
    for (const gov of (allGovs ?? [])) {
      govNameMap[gov.id] = { nameAr: gov.name_ar, nameEn: gov.name_en }
      const count = govBreakdownCounts[gov.id] ?? 0
      if (count > 0) {
        govBreakdown.push({
          id: gov.id,
          nameAr: gov.name_ar,
          nameEn: gov.name_en,
          count,
        })
      }
    }
    govBreakdown.sort((a, b) => b.count - a.count)

    // ─── Forms + Per-Form Stats ─────────────────────────────
    const { data: allForms } = await supabase
      .from('forms')
      .select('id, title_ar, title_en, schema')
      .eq('is_active', true)
      .is('deleted_at', null)

    // Fetch all form submissions grouped by form_id in one query
    let formCountQuery = supabase
      .from('form_submissions')
      .select('form_id, status, data')
      .is('deleted_at', null)

    if (governorate_id) formCountQuery = formCountQuery.eq('governorate_id', governorate_id)
    if (district_id) formCountQuery = formCountQuery.eq('district_id', district_id)
    if (start_date) formCountQuery = formCountQuery.gte('created_at', start_date)
    if (end_date) formCountQuery = formCountQuery.lte('created_at', end_date)

    const { data: formSubRows } = await formCountQuery.limit(10000)

    // Group submissions by form_id
    const formSubmissions: Record<string, any[]> = {}
    const formStats: Record<string, { total: number; byStatus: Record<string, number> }> = {}
    for (const row of (formSubRows ?? [])) {
      const fid = row.form_id
      if (!formStats[fid]) {
        formStats[fid] = { total: 0, byStatus: {} }
        formSubmissions[fid] = []
      }
      formStats[fid].total++
      formStats[fid].byStatus[row.status] = (formStats[fid].byStatus[row.status] || 0) + 1
      formSubmissions[fid].push(row)
    }

    // Per-question analysis
    const formAnalytics: any[] = []
    const targetForms = form_id
      ? (allForms ?? []).filter((f: any) => f.id === form_id)
      : (allForms ?? [])

    for (const form of targetForms) {
      const schema = form.schema as any
      const sections = schema?.sections ?? schema?.fields ?? []
      const formId = form.id

      const submissions = formSubmissions[formId] ?? []

      // Flatten all fields from sections
      const allFields: any[] = []
      if (Array.isArray(sections)) {
        for (const section of sections) {
          if (section.fields && Array.isArray(section.fields)) {
            allFields.push(...section.fields)
          } else if (section.key) {
            allFields.push(section)
          }
        }
      }

      // Analyze each question
      const questionAnalytics: any[] = []
      for (const field of allFields) {
        const key = field.key as string
        const type = field.type as string
        const label = field.label_ar as string

        if (!key || !label) continue
        if (['photo', 'signature', 'gps', 'textarea'].includes(type)) continue

        const answers: any[] = []
        let answered = 0
        let notAnswered = 0

        for (const sub of submissions) {
          const data = sub.data as Record<string, any> ?? {}
          const value = data[key]

          if (value !== null && value !== undefined && value !== '') {
            answered++
            answers.push(value)
          } else {
            notAnswered++
          }
        }

        const totalSubmissions = submissions.length
        const completionRate = totalSubmissions > 0 ? Math.round((answered / totalSubmissions) * 100) : 0

        // Calculate answer distribution
        const distribution: Record<string, number> = {}
        for (const ans of answers) {
          const strAns = String(ans)
          distribution[strAns] = (distribution[strAns] || 0) + 1
        }

        let yesCount = 0
        let noCount = 0
        if (type === 'yesno') {
          for (const ans of answers) {
            if (ans === true || ans === 'true') yesCount++
            else if (ans === false || ans === 'false') noCount++
          }
        }

        let numericStats = null
        if (type === 'number') {
          const nums = answers.map(a => Number(a)).filter(n => !isNaN(n))
          if (nums.length > 0) {
            numericStats = {
              min: Math.min(...nums),
              max: Math.max(...nums),
              avg: Math.round(nums.reduce((a, b) => a + b, 0) / nums.length * 100) / 100,
              total: nums.reduce((a, b) => a + b, 0),
            }
          }
        }

        questionAnalytics.push({
          key,
          label,
          type,
          answered,
          notAnswered,
          totalSubmissions,
          completionRate,
          distribution,
          ...(type === 'yesno' ? { yesCount, noCount, yesRate: answered > 0 ? Math.round((yesCount / answered) * 100) : 0 } : {}),
          ...(numericStats ? { numericStats } : {}),
        })
      }

      formAnalytics.push({
        formId: form.id,
        titleAr: form.title_ar,
        titleEn: form.title_en,
        stats: formStats[formId] ?? { total: 0, byStatus: {} },
        questions: questionAnalytics,
      })
    }

    const analytics = {
      submissions: {
        total: totalCount,
        today: todayCount ?? 0,
        byStatus,
        byDay: last7Days,
        byGovernorate: govBreakdown.reduce((acc: Record<string, number>, g) => {
          acc[g.nameAr] = g.count
          return acc
        }, {}),
      },
      shortages: {
        total: shortageTotal ?? 0,
        resolved: resolvedCount ?? 0,
        pending: (shortageTotal ?? 0) - (resolvedCount ?? 0),
        bySeverity,
      },
      topGovernorates,
      forms: formAnalytics,
      governorateBreakdown: govBreakdown,
      dashboardStats: dashStats ?? {},
      generatedAt: new Date().toISOString(),
      filters: { governorate_id, district_id, start_date, end_date, form_id },
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
