import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Vary': 'Origin',
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
    const { governorate_id, district_id, start_date, end_date, form_id } = body

    // ─── Submission Stats (aggregated in DB) ──────────────────
    // Total count
    let totalQuery = supabase
      .from('form_submissions')
      .select('*', { count: 'exact', head: true })
      .is('deleted_at', null)

    if (governorate_id) totalQuery = totalQuery.eq('governorate_id', governorate_id)
    if (district_id) totalQuery = totalQuery.eq('district_id', district_id)
    if (form_id) totalQuery = totalQuery.eq('form_id', form_id)
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
    if (form_id) todayQuery = todayQuery.eq('form_id', form_id)

    const { count: todayCount } = await todayQuery

    // By status — use a limited query grouped in SQL
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
      if (form_id) dayQuery = dayQuery.eq('form_id', form_id)

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

    // ─── Per-Form Stats ───────────────────────────────────────
    // Fetch all active forms
    const { data: allForms } = await supabase
      .from('forms')
      .select('id, title_ar, title_en, schema')
      .eq('is_active', true)
      .is('deleted_at', null)

    // Fetch submission counts per form
    let formCountQuery = supabase
      .from('form_submissions')
      .select('form_id, status')
      .is('deleted_at', null)

    if (governorate_id) formCountQuery = formCountQuery.eq('governorate_id', governorate_id)
    if (district_id) formCountQuery = formCountQuery.eq('district_id', district_id)
    if (start_date) formCountQuery = formCountQuery.gte('created_at', start_date)
    if (end_date) formCountQuery = formCountQuery.lte('created_at', end_date)

    const { data: formSubRows } = await formCountQuery.limit(10000)

    // Group by form_id
    const formStats: Record<string, { total: number; byStatus: Record<string, number> }> = {}
    for (const row of (formSubRows ?? [])) {
      const fid = row.form_id
      if (!formStats[fid]) formStats[fid] = { total: 0, byStatus: {} }
      formStats[fid].total++
      formStats[fid].byStatus[row.status] = (formStats[fid].byStatus[row.status] || 0) + 1
    }

    // ─── Per-Question Analysis ────────────────────────────────
    // For each form (or the filtered form), analyze answers per question
    const formAnalytics: any[] = []
    const targetForms = form_id
      ? (allForms ?? []).filter((f: any) => f.id === form_id)
      : (allForms ?? [])

    for (const form of targetForms) {
      const schema = form.schema as any
      const sections = schema?.sections ?? schema?.fields ?? []
      const formId = form.id

      // Fetch submissions for this form
      let subQuery = supabase
        .from('form_submissions')
        .select('data, status, governorate_id, district_id, created_at')
        .eq('form_id', formId)
        .is('deleted_at', null)

      if (governorate_id) subQuery = subQuery.eq('governorate_id', governorate_id)
      if (district_id) subQuery = subQuery.eq('district_id', district_id)
      if (start_date) subQuery = subQuery.gte('created_at', start_date)
      if (end_date) subQuery = subQuery.lte('created_at', end_date)

      const { data: submissions } = await subQuery.limit(5000)

      // Flatten all fields from sections
      const allFields: any[] = []
      if (Array.isArray(sections)) {
        for (const section of sections) {
          if (section.fields && Array.isArray(section.fields)) {
            allFields.push(...section.fields)
          } else if (section.key) {
            // Flat field format (no sections)
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

        // Skip non-analyzable types
        if (['photo', 'signature', 'gps', 'textarea'].includes(type)) continue

        const answers: any[] = []
        let answered = 0
        let notAnswered = 0

        for (const sub of (submissions ?? [])) {
          const data = sub.data as Record<string, any> ?? {}
          const value = data[key]

          if (value !== null && value !== undefined && value !== '') {
            answered++
            answers.push(value)
          } else {
            notAnswered++
          }
        }

        const totalSubmissions = (submissions ?? []).length
        const completionRate = totalSubmissions > 0 ? Math.round((answered / totalSubmissions) * 100) : 0

        // Calculate answer distribution
        const distribution: Record<string, number> = {}
        for (const ans of answers) {
          const strAns = String(ans)
          distribution[strAns] = (distribution[strAns] || 0) + 1
        }

        // For yes/no fields, calculate percentages
        let yesCount = 0
        let noCount = 0
        if (type === 'yesno') {
          for (const ans of answers) {
            if (ans === true || ans === 'true') yesCount++
            else if (ans === false || ans === 'false') noCount++
          }
        }

        // For numeric fields, calculate stats
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

    // ─── Governorate breakdown for current filter ─────────────
    let govBreakdown: any[] = []
    const { data: allGovs } = await supabase
      .from('governorates')
      .select('id, name_ar, name_en')
      .eq('is_active', true)

    if (allGovs) {
      for (const gov of allGovs) {
        let countQuery = supabase
          .from('form_submissions')
          .select('*', { count: 'exact', head: true })
          .eq('governorate_id', gov.id)
          .is('deleted_at', null)

        if (form_id) countQuery = countQuery.eq('form_id', form_id)
        if (start_date) countQuery = countQuery.gte('created_at', start_date)
        if (end_date) countQuery = countQuery.lte('created_at', end_date)

        const { count } = await countQuery
        if ((count ?? 0) > 0) {
          govBreakdown.push({
            id: gov.id,
            nameAr: gov.name_ar,
            nameEn: gov.name_en,
            count: count ?? 0,
          })
        }
      }
      govBreakdown.sort((a, b) => b.count - a.count)
    }

    const analytics = {
      submissions: {
        total: totalCount ?? 0,
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
