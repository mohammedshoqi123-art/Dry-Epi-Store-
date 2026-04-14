import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { authenticateRequest, createUserClient } from '../_shared/auth.ts'

serve(async (req) => {
  const origin = req.headers.get('Origin')
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    // Authenticate — no JWT fallback
    const supabase = createUserClient(authHeader)
    const auth = await authenticateRequest(supabase, authHeader)
    if (!auth) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    const body = await req.json().catch(() => ({}))
    const { governorate_id, district_id, start_date, end_date, form_id } = body

    const today = new Date().toISOString().split('T')[0]

    const applyFilters = (q: any) => {
      if (governorate_id) q = q.eq('governorate_id', governorate_id)
      if (district_id) q = q.eq('district_id', district_id)
      if (form_id) q = q.eq('form_id', form_id)
      return q
    }

    const applyDateFilters = (q: any) => {
      q = applyFilters(q)
      if (start_date) q = q.gte('created_at', start_date)
      if (end_date) q = q.lte('created_at', end_date)
      return q
    }

    // ═══ FIX: Fetch submissions with governorate_id and form_id for proper breakdowns ═══
    const [
      { count: todayCount },
      { count: totalCount },
      { data: statusRows },
      { data: dayRows },
      { count: shortageTotal },
      { count: resolvedCount },
      { data: severityRows },
      { data: allGovs },
      { data: allForms },
      // ═══ NEW: Fetch full submissions for governorate + form breakdowns ═══
      { data: fullSubmissions },
    ] = await Promise.all([
      applyFilters(
        supabase.from('form_submissions').select('*', { count: 'exact', head: true })
          .is('deleted_at', null)
          .gte('created_at', `${today}T00:00:00Z`)
          .lte('created_at', `${today}T23:59:59Z`)
      ),
      applyDateFilters(
        supabase.from('form_submissions').select('*', { count: 'exact', head: true })
          .is('deleted_at', null)
      ),
      applyDateFilters(
        supabase.from('form_submissions').select('status')
          .is('deleted_at', null).limit(5000)
      ),
      applyFilters(
        supabase.from('form_submissions').select('created_at')
          .is('deleted_at', null)
          .gte('created_at', (() => { const d = new Date(); d.setDate(d.getDate() - 6); return d.toISOString().split('T')[0] + 'T00:00:00Z' })())
          .limit(5000)
      ),
      applyFilters(
        supabase.from('supply_shortages').select('*', { count: 'exact', head: true })
          .is('deleted_at', null)
      ),
      applyFilters(
        supabase.from('supply_shortages').select('*', { count: 'exact', head: true })
          .is('deleted_at', null).eq('is_resolved', true)
      ),
      applyFilters(
        supabase.from('supply_shortages').select('severity')
          .is('deleted_at', null).limit(2000)
      ),
      supabase.from('governorates').select('id, name_ar, name_en').eq('is_active', true),
      supabase.from('forms').select('id, title_ar, title_en, schema').eq('is_active', true).is('deleted_at', null),
      // ═══ FIX: Fetch submissions with governorate_id, form_id, and status for breakdowns ═══
      applyDateFilters(
        supabase.from('form_submissions').select('governorate_id, form_id, status')
          .is('deleted_at', null).limit(5000)
      ),
    ])

    const byStatus: Record<string, number> = {}
    for (const row of (statusRows ?? [])) byStatus[row.status] = (byStatus[row.status] || 0) + 1

    const last7Days: Record<string, number> = {}
    for (let i = 6; i >= 0; i--) { const d = new Date(); d.setDate(d.getDate() - i); last7Days[d.toISOString().split('T')[0]] = 0 }
    for (const row of (dayRows ?? [])) { const dayKey = row.created_at.split('T')[0]; if (last7Days[dayKey] !== undefined) last7Days[dayKey]++ }

    const bySeverity: Record<string, number> = {}
    for (const row of (severityRows ?? [])) bySeverity[row.severity] = (bySeverity[row.severity] || 0) + 1

    // ═══ FIX: Compute per-governorate submission counts ═══
    const govSubmissionCounts: Record<string, number> = {}
    for (const row of (fullSubmissions ?? [])) {
      const govId = row.governorate_id
      if (govId) govSubmissionCounts[govId] = (govSubmissionCounts[govId] || 0) + 1
    }

    // ═══ FIX: Compute per-form stats with status breakdowns ═══
    const formStatusCounts: Record<string, Record<string, number>> = {}
    const formTotals: Record<string, number> = {}
    for (const row of (fullSubmissions ?? [])) {
      const fId = row.form_id
      if (!fId) continue
      formTotals[fId] = (formTotals[fId] || 0) + 1
      if (!formStatusCounts[fId]) formStatusCounts[fId] = {}
      formStatusCounts[fId][row.status] = (formStatusCounts[fId][row.status] || 0) + 1
    }

    // ═══ FIX: Build governorate breakdown with actual counts ═══
    const govBreakdown = (allGovs ?? []).map((g: any) => ({
      id: g.id,
      nameAr: g.name_ar,
      nameEn: g.name_en,
      count: govSubmissionCounts[g.id] || 0,
    }))

    // ═══ FIX: Build form analytics with actual stats and questions from schema ═══
    const formAnalytics = (allForms ?? []).map((f: any) => {
      const schema = f.schema ?? {}
      const questions = (schema.fields ?? schema.questions ?? []).map((q: any) => ({
        label: q.label ?? q.labelAr ?? q.name ?? '',
        type: q.type ?? 'text',
        completionRate: 0,
        answered: 0,
        notAnswered: 0,
        totalSubmissions: formTotals[f.id] || 0,
      }))

      return {
        formId: f.id,
        titleAr: f.title_ar,
        titleEn: f.title_en,
        stats: {
          total: formTotals[f.id] || 0,
          byStatus: formStatusCounts[f.id] || {},
        },
        questions,
      }
    })

    // ═══ FIX: Build byGovernorate map for charts ═══
    const byGovernorate: Record<string, number> = {}
    for (const g of (allGovs ?? [])) {
      byGovernorate[g.name_ar ?? g.name_en ?? g.id] = govSubmissionCounts[g.id] || 0
    }

    return jsonResponse({
      submissions: { total: totalCount ?? 0, today: todayCount ?? 0, byStatus, byDay: last7Days, byGovernorate },
      shortages: { total: shortageTotal ?? 0, resolved: resolvedCount ?? 0, pending: (shortageTotal ?? 0) - (resolvedCount ?? 0), bySeverity },
      topGovernorates: govBreakdown.sort((a: any, b: any) => b.count - a.count).slice(0, 10),
      forms: formAnalytics,
      governorateBreakdown: govBreakdown.sort((a: any, b: any) => b.count - a.count),
      generatedAt: new Date().toISOString(),
      filters: { governorate_id, district_id, start_date, end_date, form_id },
    }, 200, origin)

  } catch (error) {
    console.error('Analytics error:', error)
    return jsonResponse({ error: error instanceof Error ? error.message : 'Internal server error' }, 500, origin)
  }
})
