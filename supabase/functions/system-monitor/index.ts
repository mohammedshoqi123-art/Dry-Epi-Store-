/**
 * ═══════════════════════════════════════════════════════════════════
 *  System Monitor — Health, Stats, Backups, Rate Limits
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
      .select('role')
      .eq('id', auth.userId)
      .single()

    if (!profile || !['admin', 'central'].includes(profile.role)) {
      return jsonResponse({ error: 'Admin access required' }, 403, origin)
    }

    const adminClient = createAdminClient()
    if (!adminClient) return jsonResponse({ error: 'Admin not configured' }, 500, origin)

    const body = await req.json().catch(() => ({}))
    const { action } = body

    switch (action) {
      case 'health': {
        const now = new Date()
        const hourAgo = new Date(now.getTime() - 60 * 60 * 1000).toISOString()
        const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString()

        // Check each table
        const checks = await Promise.allSettled([
          adminClient.from('profiles').select('id', { count: 'exact', head: true }),
          adminClient.from('governorates').select('id', { count: 'exact', head: true }),
          adminClient.from('districts').select('id', { count: 'exact', head: true }),
          adminClient.from('forms').select('id', { count: 'exact', head: true }),
          adminClient.from('form_submissions').select('id', { count: 'exact', head: true }),
          adminClient.from('supply_shortages').select('id', { count: 'exact', head: true }),
          adminClient.from('audit_logs').select('id', { count: 'exact', head: true }),
          adminClient.from('health_facilities').select('id', { count: 'exact', head: true }),
          adminClient.from('notifications').select('id', { count: 'exact', head: true }),
          adminClient.from('app_settings').select('key', { count: 'exact', head: true }),
        ])

        const tableNames = ['profiles', 'governorates', 'districts', 'forms', 'form_submissions', 'supply_shortages', 'audit_logs', 'health_facilities', 'notifications', 'app_settings']
        const tableStats: Record<string, { count: number; status: string }> = {}

        checks.forEach((result, i) => {
          tableStats[tableNames[i]] = {
            count: result.status === 'fulfilled' ? (result.value.count ?? 0) : -1,
            status: result.status === 'fulfilled' ? 'healthy' : 'error',
          }
        })

        // Recent activity
        const [{ count: recentSubmissions }, { count: recentLogs }, { count: recentNotifications }] = await Promise.all([
          adminClient.from('form_submissions').select('*', { count: 'exact', head: true }).gte('created_at', hourAgo),
          adminClient.from('audit_logs').select('*', { count: 'exact', head: true }).gte('created_at', hourAgo),
          adminClient.from('notifications').select('*', { count: 'exact', head: true }).gte('created_at', hourAgo),
        ])

        // Sync status
        const [{ count: offlinePending }, { count: syncFailed }] = await Promise.all([
          adminClient.from('form_submissions').select('*', { count: 'exact', head: true })
            .eq('is_offline', true).is('synced_at', null),
          adminClient.from('form_submissions').select('*', { count: 'exact', head: true })
            .eq('is_offline', true).is('synced_at', null).lt('created_at', dayAgo),
        ])

        // Backup history
        const { data: backups } = await adminClient
          .from('backup_history')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(5)

        // Recent errors from audit logs
        const { data: recentErrors } = await adminClient
          .from('audit_logs')
          .select('id, action, table_name, created_at')
          .in('action', ['delete'])
          .gte('created_at', dayAgo)
          .order('created_at', { ascending: false })
          .limit(10)

        return jsonResponse({
          status: 'ok',
          timestamp: now.toISOString(),
          database: {
            tables: tableStats,
            total_records: Object.values(tableStats).reduce((sum, t) => sum + (t.count > 0 ? t.count : 0), 0),
          },
          recent_activity: {
            submissions_last_hour: recentSubmissions ?? 0,
            audit_logs_last_hour: recentLogs ?? 0,
            notifications_last_hour: recentNotifications ?? 0,
          },
          sync: {
            pending_offline: offlinePending ?? 0,
            failed_sync: syncFailed ?? 0,
            status: (syncFailed ?? 0) > 10 ? 'warning' : 'healthy',
          },
          backups: backups ?? [],
          recent_deletes: recentErrors ?? [],
        }, 200, origin)
      }

      case 'backup': {
        const { tables } = body
        const backupId = crypto.randomUUID()
        const now = new Date()

        // Create backup record
        const { data: backup, error } = await adminClient
          .from('backup_history')
          .insert({
            id: backupId,
            backup_type: 'manual',
            status: 'completed',
            tables_included: tables ?? ['profiles', 'forms', 'form_submissions', 'supply_shortages', 'governorates', 'districts'],
            started_at: now.toISOString(),
            completed_at: now.toISOString(),
            created_by: auth.userId,
          })
          .select()
          .single()

        if (error) return jsonResponse({ error: error.message }, 400, origin)
        return jsonResponse({
          success: true,
          backup,
          message: 'تم إنشاء سجل النسخ الاحتياطي',
        }, 200, origin)
      }

      case 'cleanup': {
        const daysAgo = body.days ?? 90
        const cutoff = new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000).toISOString()

        // Clean old rate limits
        const { error: rlError } = await adminClient
          .from('rate_limits')
          .delete()
          .lt('window_start', cutoff)

        // Clean old read notifications
        const { error: notifError } = await adminClient
          .from('notifications')
          .delete()
          .eq('is_read', true)
          .lt('created_at', cutoff)

        return jsonResponse({
          success: true,
          message: `تم تنظيف البيانات الأقدم من ${daysAgo} يوم`,
          errors: [rlError?.message, notifError?.message].filter(Boolean),
        }, 200, origin)
      }

      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400, origin)
    }
  } catch (error) {
    console.error('System monitor error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, origin)
  }
})
