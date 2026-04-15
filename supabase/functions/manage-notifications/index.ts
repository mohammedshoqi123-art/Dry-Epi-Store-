/**
 * ═══════════════════════════════════════════════════════════════════
 *  Manage Notifications — Send, List, Update, Delete
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
      case 'list': {
        const { page = 1, limit = 20, is_read, type, category, from_date, to_date } = body
        let query = adminClient
          .from('notifications')
          .select('*, profiles!recipient_id(full_name, email, role)', { count: 'exact' })
          .order('created_at', { ascending: false })
          .range((page - 1) * limit, page * limit - 1)

        if (is_read !== undefined) query = query.eq('is_read', is_read)
        if (type) query = query.eq('type', type)
        if (category) query = query.eq('category', category)
        if (from_date) query = query.gte('created_at', from_date)
        if (to_date) query = query.lte('created_at', to_date)

        const { data, error, count } = await query
        if (error) return jsonResponse({ error: error.message }, 400, origin)

        return jsonResponse({ notifications: data, total: count, page, limit }, 200, origin)
      }

      case 'send': {
        const { title, body: notifBody, type = 'info', category = 'general', target } = body
        if (!title || !notifBody) {
          return jsonResponse({ error: 'title and body are required' }, 400, origin)
        }

        // Determine recipients based on target
        let recipientQuery = adminClient
          .from('profiles')
          .select('id')
          .eq('is_active', true)
          .is('deleted_at', null)

        if (target?.role) {
          recipientQuery = recipientQuery.eq('role', target.role)
        }
        if (target?.governorate_id) {
          recipientQuery = recipientQuery.eq('governorate_id', target.governorate_id)
        }
        if (target?.district_id) {
          recipientQuery = recipientQuery.eq('district_id', target.district_id)
        }
        if (target?.user_ids && Array.isArray(target.user_ids)) {
          recipientQuery = recipientQuery.in('id', target.user_ids)
        }

        const { data: recipients } = await recipientQuery
        if (!recipients || recipients.length === 0) {
          return jsonResponse({ error: 'No recipients found' }, 400, origin)
        }

        // Batch insert notifications
        const notifications = recipients.map(r => ({
          recipient_id: r.id,
          title,
          body: notifBody,
          type,
          category,
          data: body.data ?? {},
        }))

        // Insert in batches of 100
        for (let i = 0; i < notifications.length; i += 100) {
          const batch = notifications.slice(i, i + 100)
          const { error: insertError } = await adminClient.from('notifications').insert(batch)
          if (insertError) {
            return jsonResponse({ error: insertError.message }, 400, origin)
          }
        }

        return jsonResponse({
          success: true,
          sent_count: notifications.length,
          message: `تم إرسال ${notifications.length} إشعار`,
        }, 200, origin)
      }

      case 'mark_read': {
        const { notification_ids } = body
        if (!notification_ids || !Array.isArray(notification_ids)) {
          return jsonResponse({ error: 'notification_ids array required' }, 400, origin)
        }

        const { error } = await adminClient
          .from('notifications')
          .update({ is_read: true, read_at: new Date().toISOString() })
          .in('id', notification_ids)

        if (error) return jsonResponse({ error: error.message }, 400, origin)
        return jsonResponse({ success: true }, 200, origin)
      }

      case 'mark_all_read': {
        const { error } = await adminClient
          .from('notifications')
          .update({ is_read: true, read_at: new Date().toISOString() })
          .eq('is_read', false)

        if (error) return jsonResponse({ error: error.message }, 400, origin)
        return jsonResponse({ success: true }, 200, origin)
      }

      case 'delete': {
        const { notification_ids } = body
        if (!notification_ids || !Array.isArray(notification_ids)) {
          return jsonResponse({ error: 'notification_ids array required' }, 400, origin)
        }

        const { error } = await adminClient
          .from('notifications')
          .delete()
          .in('id', notification_ids)

        if (error) return jsonResponse({ error: error.message }, 400, origin)
        return jsonResponse({ success: true }, 200, origin)
      }

      case 'stats': {
        const [{ count: total }, { count: unread }, { count: todayCount }] = await Promise.all([
          adminClient.from('notifications').select('*', { count: 'exact', head: true }),
          adminClient.from('notifications').select('*', { count: 'exact', head: true }).eq('is_read', false),
          adminClient.from('notifications').select('*', { count: 'exact', head: true })
            .gte('created_at', new Date(new Date().setHours(0, 0, 0, 0)).toISOString()),
        ])

        const { data: byType } = await adminClient
          .from('notifications')
          .select('type')

        const typeDistribution: Record<string, number> = {}
        for (const n of byType ?? []) {
          typeDistribution[n.type] = (typeDistribution[n.type] ?? 0) + 1
        }

        return jsonResponse({
          total: total ?? 0,
          unread: unread ?? 0,
          today: todayCount ?? 0,
          by_type: typeDistribution,
        }, 200, origin)
      }

      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400, origin)
    }
  } catch (error) {
    console.error('Notification management error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, origin)
  }
})
