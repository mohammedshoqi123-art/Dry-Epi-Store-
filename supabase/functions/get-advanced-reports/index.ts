/**
 * ═══════════════════════════════════════════════════════════════════
 *  Advanced Reports — Submissions, Users, Shortages, Governorate Performance
 * ═══════════════════════════════════════════════════════════════════
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { authenticateRequest, createUserClient, createAdminClient } from '../_shared/auth.ts'

serve(async (req) => {
  const origin = req.headers.get('Origin')
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    const supabase = createUserClient(authHeader)
    const auth = await authenticateRequest(supabase, authHeader)
    if (!auth) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    const { data: profile } = await supabase
      .from('profiles')
      .select('role, governorate_id')
      .eq('id', auth.userId)
      .single()

    if (!profile || !['admin', 'central', 'governorate'].includes(profile.role)) {
      return jsonResponse({ error: 'Access denied' }, 403, origin)
    }

    const adminClient = createAdminClient()
    const db = adminClient ?? supabase

    const body = await req.json().catch(() => ({}))
    const { report_type, from_date, to_date, governorate_id, district_id, form_id, status } = body

    const fromDate = from_date ?? new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()
    const toDate = to_date ?? new Date().toISOString()

    switch (report_type) {
      case 'submissions': {
        let query = db
          .from('form_submissions')
          .select(`
            id, status, data, gps_lat, gps_lng, notes, created_at, submitted_at,
            reviewed_at, review_notes,
            forms(title_ar),
            profiles!submitted_by(full_name, role),
            governorates(name_ar),
            districts(name_ar)
          `, { count: 'exact' })
          .gte('created_at', fromDate)
          .lte('created_at', toDate)
          .is('deleted_at', null)
          .order('created_at', { ascending: false })

        if (governorate_id) query = query.eq('governorate_id', governorate_id)
        if (district_id) query = query.eq('district_id', district_id)
        if (form_id) query = query.eq('form_id', form_id)
        if (status) query = query.eq('status', status)

        const { data, error, count } = await query.limit(500)
        if (error) return jsonResponse({ error: error.message }, 400, origin)

        // Aggregate stats
        const statusCounts: Record<string, number> = {}
        const dailyCounts: Record<string, number> = {}
        for (const s of data ?? []) {
          statusCounts[s.status] = (statusCounts[s.status] ?? 0) + 1
          const day = s.created_at.split('T')[0]
          dailyCounts[day] = (dailyCounts[day] ?? 0) + 1
        }

        return jsonResponse({
          report_type: 'submissions',
          period: { from: fromDate, to: toDate },
          total: count,
          submissions: data,
          aggregates: { by_status: statusCounts, by_day: dailyCounts },
        }, 200, origin)
      }

      case 'governorate_performance': {
        // Get all governorates with submission stats
        const { data: governorates } = await db
          .from('governorates')
          .select('id, name_ar, name_en, code, population')
          .eq('is_active', true)
          .is('deleted_at', null)
          .order('name_ar')

        const performance = await Promise.all((governorates ?? []).map(async (gov) => {
          const [total, approved, rejected, pending, districtsCount, facilitiesCount, usersCount] = await Promise.all([
            db.from('form_submissions').select('*', { count: 'exact', head: true })
              .eq('governorate_id', gov.id).gte('created_at', fromDate).lte('created_at', toDate).is('deleted_at', null),
            db.from('form_submissions').select('*', { count: 'exact', head: true })
              .eq('governorate_id', gov.id).eq('status', 'approved').gte('created_at', fromDate).lte('created_at', toDate).is('deleted_at', null),
            db.from('form_submissions').select('*', { count: 'exact', head: true })
              .eq('governorate_id', gov.id).eq('status', 'rejected').gte('created_at', fromDate).lte('created_at', toDate).is('deleted_at', null),
            db.from('form_submissions').select('*', { count: 'exact', head: true })
              .eq('governorate_id', gov.id).eq('status', 'submitted').gte('created_at', fromDate).lte('created_at', toDate).is('deleted_at', null),
            db.from('districts').select('*', { count: 'exact', head: true })
              .eq('governorate_id', gov.id).eq('is_active', true).is('deleted_at', null),
            db.from('health_facilities').select('*', { count: 'exact', head: true })
              .eq('is_active', true).is('deleted_at', null),
            db.from('profiles').select('*', { count: 'exact', head: true })
              .eq('governorate_id', gov.id).eq('is_active', true).is('deleted_at', null),
          ])

          const totalCount = total.count ?? 0
          const approvedCount = approved.count ?? 0
          return {
            ...gov,
            submissions: {
              total: totalCount,
              approved: approvedCount,
              rejected: rejected.count ?? 0,
              pending: pending.count ?? 0,
              approval_rate: totalCount > 0 ? Math.round(approvedCount / totalCount * 100) : 0,
            },
            districts: districtsCount.count ?? 0,
            facilities: facilitiesCount.count ?? 0,
            users: usersCount.count ?? 0,
          }
        }))

        return jsonResponse({
          report_type: 'governorate_performance',
          period: { from: fromDate, to: toDate },
          governorates: performance.sort((a, b) => b.submissions.total - a.submissions.total),
        }, 200, origin)
      }

      case 'users': {
        const { data, error, count } = await db
          .from('profiles')
          .select('id, full_name, email, role, is_active, last_login, created_at, governorate_id, governorates(name_ar), districts(name_ar)', { count: 'exact' })
          .is('deleted_at', null)
          .order('created_at', { ascending: false })

        if (error) return jsonResponse({ error: error.message }, 400, origin)

        // Aggregate by role
        const roleCounts: Record<string, number> = {}
        const activeCounts: Record<string, number> = {}
        for (const u of data ?? []) {
          roleCounts[u.role] = (roleCounts[u.role] ?? 0) + 1
          if (u.is_active) activeCounts[u.role] = (activeCounts[u.role] ?? 0) + 1
        }

        return jsonResponse({
          report_type: 'users',
          total: count,
          users: data,
          aggregates: { by_role: roleCounts, active_by_role: activeCounts },
        }, 200, origin)
      }

      case 'shortages': {
        let query = db
          .from('supply_shortages')
          .select(`
            id, item_name, item_category, quantity_needed, quantity_available,
            unit, severity, notes, is_resolved, created_at,
            profiles!reported_by(full_name),
            governorates(name_ar),
            districts(name_ar)
          `, { count: 'exact' })
          .gte('created_at', fromDate)
          .lte('created_at', toDate)
          .is('deleted_at', null)
          .order('created_at', { ascending: false })

        if (governorate_id) query = query.eq('governorate_id', governorate_id)
        if (district_id) query = query.eq('district_id', district_id)

        const { data, error, count } = await query.limit(500)
        if (error) return jsonResponse({ error: error.message }, 400, origin)

        const severityCounts: Record<string, number> = {}
        const categoryCounts: Record<string, number> = {}
        let resolvedCount = 0
        for (const s of data ?? []) {
          severityCounts[s.severity] = (severityCounts[s.severity] ?? 0) + 1
          if (s.item_category) categoryCounts[s.item_category] = (categoryCounts[s.item_category] ?? 0) + 1
          if (s.is_resolved) resolvedCount++
        }

        return jsonResponse({
          report_type: 'shortages',
          period: { from: fromDate, to: toDate },
          total: count,
          shortages: data,
          aggregates: {
            by_severity: severityCounts,
            by_category: categoryCounts,
            resolved: resolvedCount,
            unresolved: (count ?? 0) - resolvedCount,
          },
        }, 200, origin)
      }

      case 'audit': {
        const { page = 1, limit = 50, user_id, action: auditAction, table_name } = body
        let query = db
          .from('audit_logs')
          .select('*, profiles(full_name, role)', { count: 'exact' })
          .gte('created_at', fromDate)
          .lte('created_at', toDate)
          .order('created_at', { ascending: false })
          .range((page - 1) * limit, page * limit - 1)

        if (user_id) query = query.eq('user_id', user_id)
        if (auditAction) query = query.eq('action', auditAction)
        if (table_name) query = query.eq('table_name', table_name)

        const { data, error, count } = await query
        if (error) return jsonResponse({ error: error.message }, 400, origin)

        return jsonResponse({
          report_type: 'audit',
          period: { from: fromDate, to: toDate },
          total: count,
          page,
          limit,
          logs: data,
        }, 200, origin)
      }

      default:
        return jsonResponse({ error: `Unknown report type: ${report_type}` }, 400, origin)
    }
  } catch (error) {
    console.error('Reports error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, origin)
  }
})
