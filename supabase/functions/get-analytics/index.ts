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
    ])

    const byStatus: Record<string, number> = {}
    for (const row of (statusRows ?? [])) byStatus[row.status] = (byStatus[row.status] || 0) + 1

    const last7Days: Record<string, number> = {}
    for (let i = 6; i >= 0; i--) { const d = new Date(); d.setDate(d.getDate() - i); last7Days[d.toISOString().split('T')[0]] = 0 }
    for (const row of (dayRows ?? [])) { const dayKey = row.created_at.split('T')[0]; if (last7Days[dayKey] !== undefined) last7Days[dayKey]++ }

    const bySeverity: Record<string, number> = {}
    for (const row of (severityRows ?? [])) bySeverity[row.severity] = (bySeverity[row.severity] || 0) + 1

    const govBreakdown = (allGovs ?? []).map((g: any) => ({ id: g.id, nameAr: g.name_ar, nameEn: g.name_en, count: 0 }))
    const formAnalytics = (allForms ?? []).map((f: any) => ({ formId: f.id, titleAr: f.title_ar, titleEn: f.title_en, stats: { total: 0, byStatus: {} }, questions: [] }))

    return jsonResponse({
      submissions: { total: totalCount ?? 0, today: todayCount ?? 0, byStatus, byDay: last7Days, byGovernorate: {} },
      shortages: { total: shortageTotal ?? 0, resolved: resolvedCount ?? 0, pending: (shortageTotal ?? 0) - (resolvedCount ?? 0), bySeverity },
      topGovernorates: [], forms: formAnalytics, governorateBreakdown: govBreakdown,
      generatedAt: new Date().toISOString(),
      filters: { governorate_id, district_id, start_date, end_date, form_id },
    }, 200, origin)

  } catch (error) {
    console.error('Analytics error:', error)
    return jsonResponse({ error: error instanceof Error ? error.message : 'Internal server error' }, 500, origin)
  }
})
