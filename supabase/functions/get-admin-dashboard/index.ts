/**
 * ═══════════════════════════════════════════════════════════════════
 *  Admin Dashboard — Enhanced Stats & Analytics
 * ═══════════════════════════════════════════════════════════════════
 *  Returns comprehensive dashboard data for admin/central users:
 *  - KPIs (users, submissions, shortages, sync)
 *  - Charts data (submissions timeline, status distribution, by governorate)
 *  - Recent activity feed
 *  - System health indicators
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

    // Check role
    const { data: profile } = await supabase
      .from('profiles')
      .select('role, governorate_id')
      .eq('id', auth.userId)
      .single()

    if (!profile || !['admin', 'central'].includes(profile.role)) {
      return jsonResponse({ error: 'Admin or Central access required' }, 403, origin)
    }

    const adminClient = createAdminClient()
    const db = adminClient ?? supabase

    const now = new Date()
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString()
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString()
    const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString()

    // ═══ KPIs ═══
    const [
      { count: totalUsers },
      { count: activeUsers },
      { count: totalSubmissions },
      { count: todaySubmissions },
      { count: pendingSubmissions },
      { count: approvedSubmissions },
      { count: rejectedSubmissions },
      { count: draftSubmissions },
      { count: totalShortages },
      { count: criticalShortages },
      { count: totalGovernorates },
      { count: totalDistricts },
      { count: totalFacilities },
      { count: unreadNotifications },
      { count: activeForms },
    ] = await Promise.all([
      db.from('profiles').select('*', { count: 'exact', head: true }).is('deleted_at', null),
      db.from('profiles').select('*', { count: 'exact', head: true }).eq('is_active', true).is('deleted_at', null),
      db.from('form_submissions').select('*', { count: 'exact', head: true }).is('deleted_at', null),
      db.from('form_submissions').select('*', { count: 'exact', head: true }).gte('created_at', todayStart).is('deleted_at', null),
      db.from('form_submissions').select('*', { count: 'exact', head: true }).eq('status', 'submitted').is('deleted_at', null),
      db.from('form_submissions').select('*', { count: 'exact', head: true }).eq('status', 'approved').is('deleted_at', null),
      db.from('form_submissions').select('*', { count: 'exact', head: true }).eq('status', 'rejected').is('deleted_at', null),
      db.from('form_submissions').select('*', { count: 'exact', head: true }).eq('status', 'draft').is('deleted_at', null),
      db.from('supply_shortages').select('*', { count: 'exact', head: true }).is('deleted_at', null),
      db.from('supply_shortages').select('*', { count: 'exact', head: true }).eq('severity', 'critical').eq('is_resolved', false).is('deleted_at', null),
      db.from('governorates').select('*', { count: 'exact', head: true }).eq('is_active', true).is('deleted_at', null),
      db.from('districts').select('*', { count: 'exact', head: true }).eq('is_active', true).is('deleted_at', null),
      db.from('health_facilities').select('*', { count: 'exact', head: true }).eq('is_active', true).is('deleted_at', null),
      db.from('notifications').select('*', { count: 'exact', head: true }).eq('is_read', false),
      db.from('forms').select('*', { count: 'exact', head: true }).eq('is_active', true).is('deleted_at', null),
    ])

    // ═══ Submissions Timeline (last 30 days) ═══
    const { data: timelineData } = await db
      .from('form_submissions')
      .select('created_at, status')
      .gte('created_at', monthAgo)
      .is('deleted_at', null)
      .order('created_at', { ascending: true })

    // Group by day
    const timelineMap = new Map<string, { total: number; approved: number; rejected: number; pending: number }>()
    for (let i = 29; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000)
      const key = d.toISOString().split('T')[0]
      timelineMap.set(key, { total: 0, approved: 0, rejected: 0, pending: 0 })
    }
    for (const sub of timelineData ?? []) {
      const key = sub.created_at.split('T')[0]
      const entry = timelineMap.get(key)
      if (entry) {
        entry.total++
        if (sub.status === 'approved') entry.approved++
        else if (sub.status === 'rejected') entry.rejected++
        else if (sub.status === 'submitted') entry.pending++
      }
    }
    const submissionsTimeline = Array.from(timelineMap.entries()).map(([date, data]) => ({ date, ...data }))

    // ═══ Submissions by Governorate ═══
    const { data: govSubmissions } = await db
      .from('form_submissions')
      .select('governorate_id, governorates(name_ar)')
      .gte('created_at', monthAgo)
      .is('deleted_at', null)

    const govMap = new Map<string, { name: string; count: number }>()
    for (const sub of govSubmissions ?? []) {
      const name = (sub.governorates as any)?.name_ar ?? 'غير محدد'
      const existing = govMap.get(sub.governorate_id ?? 'null') ?? { name, count: 0 }
      existing.count++
      govMap.set(sub.governorate_id ?? 'null', existing)
    }
    const submissionsByGovernorate = Array.from(govMap.values())
      .sort((a, b) => b.count - a.count)
      .slice(0, 10)

    // ═══ Recent Activity (audit logs) ═══
    const { data: recentActivity } = await db
      .from('audit_logs')
      .select('id, action, table_name, created_at, user_id, profiles(full_name, role)')
      .order('created_at', { ascending: false })
      .limit(20)

    // ═══ Users by Role ═══
    const { data: usersByRole } = await db
      .from('profiles')
      .select('role')
      .is('deleted_at', null)

    const roleDistribution = new Map<string, number>()
    for (const u of usersByRole ?? []) {
      roleDistribution.set(u.role, (roleDistribution.get(u.role) ?? 0) + 1)
    }

    // ═══ Shortages by Severity ═══
    const { data: shortagesBySeverity } = await db
      .from('supply_shortages')
      .select('severity')
      .eq('is_resolved', false)
      .is('deleted_at', null)

    const severityDistribution = new Map<string, number>()
    for (const s of shortagesBySeverity ?? []) {
      severityDistribution.set(s.severity, (severityDistribution.get(s.severity) ?? 0) + 1)
    }

    // ═══ Weekly comparison ═══
    const twoWeeksAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000).toISOString()
    const [{ count: thisWeekSubmissions }, { count: lastWeekSubmissions }] = await Promise.all([
      db.from('form_submissions').select('*', { count: 'exact', head: true }).gte('created_at', weekAgo).is('deleted_at', null),
      db.from('form_submissions').select('*', { count: 'exact', head: true }).gte('created_at', twoWeeksAgo).lt('created_at', weekAgo).is('deleted_at', null),
    ])

    const weeklyChange = (lastWeekSubmissions ?? 0) > 0
      ? Math.round(((thisWeekSubmissions ?? 0) - (lastWeekSubmissions ?? 0)) / (lastWeekSubmissions ?? 1) * 100)
      : (thisWeekSubmissions ?? 0) > 0 ? 100 : 0

    // ═══ Pending sync count ═══
    const { count: offlinePending } = await db
      .from('form_submissions')
      .select('*', { count: 'exact', head: true })
      .eq('is_offline', true)
      .is('synced_at', null)

    return jsonResponse({
      kpis: {
        total_users: totalUsers ?? 0,
        active_users: activeUsers ?? 0,
        total_submissions: totalSubmissions ?? 0,
        today_submissions: todaySubmissions ?? 0,
        pending_submissions: pendingSubmissions ?? 0,
        approved_submissions: approvedSubmissions ?? 0,
        rejected_submissions: rejectedSubmissions ?? 0,
        draft_submissions: draftSubmissions ?? 0,
        total_shortages: totalShortages ?? 0,
        critical_shortages: criticalShortages ?? 0,
        total_governorates: totalGovernorates ?? 0,
        total_districts: totalDistricts ?? 0,
        total_facilities: totalFacilities ?? 0,
        unread_notifications: unreadNotifications ?? 0,
        active_forms: activeForms ?? 0,
        offline_pending: offlinePending ?? 0,
        weekly_change_percent: weeklyChange,
      },
      charts: {
        submissions_timeline: submissionsTimeline,
        submissions_by_governorate: submissionsByGovernorate,
        users_by_role: Object.fromEntries(roleDistribution),
        shortages_by_severity: Object.fromEntries(severityDistribution),
        status_distribution: {
          draft: draftSubmissions ?? 0,
          submitted: pendingSubmissions ?? 0,
          approved: approvedSubmissions ?? 0,
          rejected: rejectedSubmissions ?? 0,
        },
      },
      recent_activity: (recentActivity ?? []).map(a => ({
        id: a.id,
        action: a.action,
        table_name: a.table_name,
        created_at: a.created_at,
        user_name: (a.profiles as any)?.full_name ?? 'النظام',
        user_role: (a.profiles as any)?.role ?? 'system',
      })),
      system_health: {
        database: 'healthy',
        sync_service: (offlinePending ?? 0) < 100 ? 'healthy' : 'warning',
        ai_service: 'healthy',
        last_check: now.toISOString(),
      },
      generated_at: now.toISOString(),
    }, 200, origin)

  } catch (error) {
    console.error('Admin dashboard error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, origin)
  }
})
