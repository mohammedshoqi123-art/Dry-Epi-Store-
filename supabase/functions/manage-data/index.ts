/**
 * ═══════════════════════════════════════════════════════════════════
 *  Manage Data — Governorates, Districts, Facilities, Forms, Settings
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
    const { resource, action } = body

    switch (resource) {
      // ═══════════════════════════════════════════
      // GOVERNORATES
      // ═══════════════════════════════════════════
      case 'governorates': {
        if (action === 'list') {
          const { data, error } = await adminClient
            .from('governorates')
            .select('*, districts(count)')
            .is('deleted_at', null)
            .order('name_ar')

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ governorates: data }, 200, origin)
        }

        if (action === 'create') {
          const { name_ar, name_en, code, center_lat, center_lng, population } = body
          const { data, error } = await adminClient
            .from('governorates')
            .insert({ name_ar, name_en, code, center_lat, center_lng, population })
            .select()
            .single()

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true, governorate: data }, 200, origin)
        }

        if (action === 'update') {
          const { id, ...updates } = body
          const { data, error } = await adminClient
            .from('governorates')
            .update({ ...updates, updated_at: new Date().toISOString() })
            .eq('id', id)
            .select()
            .single()

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true, governorate: data }, 200, origin)
        }

        if (action === 'delete') {
          const { id } = body
          const { error } = await adminClient
            .from('governorates')
            .update({ deleted_at: new Date().toISOString(), is_active: false })
            .eq('id', id)

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true }, 200, origin)
        }

        return jsonResponse({ error: 'Unknown action for governorates' }, 400, origin)
      }

      // ═══════════════════════════════════════════
      // DISTRICTS
      // ═══════════════════════════════════════════
      case 'districts': {
        if (action === 'list') {
          const { governorate_id, page = 1, limit = 50, search } = body
          let query = adminClient
            .from('districts')
            .select('*, governorates(name_ar)', { count: 'exact' })
            .is('deleted_at', null)
            .order('name_ar')
            .range((page - 1) * limit, page * limit - 1)

          if (governorate_id) query = query.eq('governorate_id', governorate_id)
          if (search) query = query.or(`name_ar.ilike.%${search}%,name_en.ilike.%${search}%`)

          const { data, error, count } = await query
          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ districts: data, total: count }, 200, origin)
        }

        if (action === 'create') {
          const { governorate_id, name_ar, name_en, code, center_lat, center_lng, population } = body
          const { data, error } = await adminClient
            .from('districts')
            .insert({ governorate_id, name_ar, name_en, code, center_lat, center_lng, population })
            .select()
            .single()

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true, district: data }, 200, origin)
        }

        if (action === 'update') {
          const { id, ...updates } = body
          const { data, error } = await adminClient
            .from('districts')
            .update({ ...updates, updated_at: new Date().toISOString() })
            .eq('id', id)
            .select()
            .single()

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true, district: data }, 200, origin)
        }

        if (action === 'delete') {
          const { id } = body
          const { error } = await adminClient
            .from('districts')
            .update({ deleted_at: new Date().toISOString(), is_active: false })
            .eq('id', id)

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true }, 200, origin)
        }

        return jsonResponse({ error: 'Unknown action for districts' }, 400, origin)
      }

      // ═══════════════════════════════════════════
      // HEALTH FACILITIES
      // ═══════════════════════════════════════════
      case 'facilities': {
        if (action === 'list') {
          const { district_id, page = 1, limit = 50, search } = body
          let query = adminClient
            .from('health_facilities')
            .select('*, districts(name_ar, governorates(name_ar))', { count: 'exact' })
            .is('deleted_at', null)
            .order('name_ar')
            .range((page - 1) * limit, page * limit - 1)

          if (district_id) query = query.eq('district_id', district_id)
          if (search) query = query.or(`name_ar.ilike.%${search}%,name_en.ilike.%${search}%,code.ilike.%${search}%`)

          const { data, error, count } = await query
          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ facilities: data, total: count }, 200, origin)
        }

        if (action === 'create') {
          const { district_id, name_ar, name_en, code, facility_type } = body
          const { data, error } = await adminClient
            .from('health_facilities')
            .insert({ district_id, name_ar, name_en, code, facility_type })
            .select()
            .single()

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true, facility: data }, 200, origin)
        }

        if (action === 'update') {
          const { id, ...updates } = body
          const { data, error } = await adminClient
            .from('health_facilities')
            .update({ ...updates, updated_at: new Date().toISOString() })
            .eq('id', id)
            .select()
            .single()

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true, facility: data }, 200, origin)
        }

        if (action === 'delete') {
          const { id } = body
          const { error } = await adminClient
            .from('health_facilities')
            .update({ deleted_at: new Date().toISOString(), is_active: false })
            .eq('id', id)

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true }, 200, origin)
        }

        return jsonResponse({ error: 'Unknown action for facilities' }, 400, origin)
      }

      // ═══════════════════════════════════════════
      // APP SETTINGS
      // ═══════════════════════════════════════════
      case 'settings': {
        if (action === 'list') {
          const { data, error } = await adminClient
            .from('app_settings')
            .select('*')
            .order('category')

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ settings: data }, 200, origin)
        }

        if (action === 'update') {
          const { settings } = body // Array of { key, value }
          if (!Array.isArray(settings)) {
            return jsonResponse({ error: 'settings array required' }, 400, origin)
          }

          const results = []
          for (const setting of settings) {
            const { data, error } = await adminClient
              .from('app_settings')
              .upsert({
                key: setting.key,
                value: setting.value,
                updated_at: new Date().toISOString(),
              })
              .select()
              .single()

            if (error) {
              return jsonResponse({ error: `Failed to update ${setting.key}: ${error.message}` }, 400, origin)
            }
            results.push(data)
          }

          return jsonResponse({ success: true, settings: results }, 200, origin)
        }

        return jsonResponse({ error: 'Unknown action for settings' }, 400, origin)
      }

      // ═══════════════════════════════════════════
      // FORMS
      // ═══════════════════════════════════════════
      case 'forms': {
        if (action === 'list') {
          const { data, error } = await adminClient
            .from('forms')
            .select('*, profiles!created_by(full_name), form_submissions(count)')
            .is('deleted_at', null)
            .order('created_at', { ascending: false })

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ forms: data }, 200, origin)
        }

        if (action === 'create') {
          const { title_ar, title_en, description_ar, description_en, schema, requires_gps, requires_photo, max_photos, allowed_roles } = body
          const { data, error } = await adminClient
            .from('forms')
            .insert({
              title_ar, title_en, description_ar, description_en,
              schema: schema ?? {},
              requires_gps: requires_gps ?? false,
              requires_photo: requires_photo ?? false,
              max_photos: max_photos ?? 5,
              allowed_roles: allowed_roles ?? ['data_entry', 'district', 'governorate', 'central', 'admin'],
              created_by: auth.userId,
            })
            .select()
            .single()

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true, form: data }, 200, origin)
        }

        if (action === 'update') {
          const { id, ...updates } = body
          const { data, error } = await adminClient
            .from('forms')
            .update({ ...updates, updated_at: new Date().toISOString() })
            .eq('id', id)
            .select()
            .single()

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true, form: data }, 200, origin)
        }

        if (action === 'toggle_active') {
          const { id, is_active } = body
          const { error } = await adminClient
            .from('forms')
            .update({ is_active, updated_at: new Date().toISOString() })
            .eq('id', id)

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true }, 200, origin)
        }

        return jsonResponse({ error: 'Unknown action for forms' }, 400, origin)
      }

      // ═══════════════════════════════════════════
      // PAGES
      // ═══════════════════════════════════════════
      case 'pages': {
        if (action === 'list') {
          const { data, error } = await adminClient
            .from('pages')
            .select('*')
            .order('nav_order')

          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ pages: data }, 200, origin)
        }

        if (action === 'create' || action === 'update') {
          const { id, slug, title_ar, content_ar, icon, show_in_nav, nav_order, roles, is_active } = body
          const payload = { slug, title_ar, content_ar: content_ar ?? {}, icon, show_in_nav, nav_order, roles, is_active }

          let query = adminClient.from('pages')
          if (id) {
            query = query.upsert({ id, ...payload, updated_at: new Date().toISOString() })
          } else {
            query = query.insert(payload)
          }

          const { data, error } = await query.select().single()
          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true, page: data }, 200, origin)
        }

        if (action === 'delete') {
          const { id } = body
          const { error } = await adminClient.from('pages').delete().eq('id', id)
          if (error) return jsonResponse({ error: error.message }, 400, origin)
          return jsonResponse({ success: true }, 200, origin)
        }

        return jsonResponse({ error: 'Unknown action for pages' }, 400, origin)
      }

      default:
        return jsonResponse({ error: `Unknown resource: ${resource}` }, 400, origin)
    }
  } catch (error) {
    console.error('Data management error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, origin)
  }
})
