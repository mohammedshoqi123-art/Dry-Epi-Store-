import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { authenticateRequest, createUserClient, createAdminClient } from '../_shared/auth.ts'

const ROLE_HIERARCHY: Record<string, number> = {
  admin: 5,
  central: 4,
  governorate: 3,
  district: 2,
  data_entry: 1,
}

serve(async (req) => {
  const origin = req.headers.get('Origin')
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonResponse({ error: 'Unauthorized' }, 401, origin)
    }

    // Authenticate — no JWT fallback
    const supabase = createUserClient(authHeader)
    const auth = await authenticateRequest(supabase, authHeader)
    if (!auth) {
      return jsonResponse({ error: 'Unauthorized' }, 401, origin)
    }

    // Check if user is admin
    const { data: callerProfile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', auth.userId)
      .single()

    if (callerProfile?.role !== 'admin') {
      return jsonResponse({ error: 'Admin access required' }, 403, origin)
    }

    // Admin client (bypasses RLS)
    const supabaseAdmin = createAdminClient()
    if (!supabaseAdmin) {
      return jsonResponse({ error: 'Admin operations not configured' }, 500, origin)
    }

    const body = await req.json()
    const { action } = body

    switch (action) {
      case 'update_role': {
        const { user_id, role, governorate_id, district_id } = body
        if (!user_id || !role) {
          return jsonResponse({ error: 'user_id and role are required' }, 400, origin)
        }
        if (!ROLE_HIERARCHY[role]) {
          return jsonResponse({ error: `Invalid role: ${role}` }, 400, origin)
        }

        const updateData: Record<string, unknown> = {
          role,
          updated_at: new Date().toISOString(),
        }
        if (governorate_id !== undefined) updateData.governorate_id = governorate_id
        if (district_id !== undefined) updateData.district_id = district_id

        const { error: updateError } = await supabaseAdmin
          .from('profiles')
          .update(updateData)
          .eq('id', user_id)

        if (updateError) {
          return jsonResponse({ error: updateError.message }, 400, origin)
        }

        return jsonResponse({ success: true, message: 'Role updated' }, 200, origin)
      }

      case 'toggle_active': {
        const { user_id, is_active } = body
        if (!user_id || is_active === undefined) {
          return jsonResponse({ error: 'user_id and is_active are required' }, 400, origin)
        }

        const { error: toggleError } = await supabaseAdmin
          .from('profiles')
          .update({ is_active, updated_at: new Date().toISOString() })
          .eq('id', user_id)

        if (toggleError) {
          return jsonResponse({ error: toggleError.message }, 400, origin)
        }

        return jsonResponse({ success: true, message: is_active ? 'User activated' : 'User deactivated' }, 200, origin)
      }

      case 'delete_user': {
        const { user_id } = body
        if (!user_id) {
          return jsonResponse({ error: 'user_id is required' }, 400, origin)
        }

        // Prevent self-deletion
        if (user_id === auth.userId) {
          return jsonResponse({ error: 'Cannot delete your own account' }, 400, origin)
        }

        // Soft delete profile
        await supabaseAdmin
          .from('profiles')
          .update({ deleted_at: new Date().toISOString(), is_active: false })
          .eq('id', user_id)

        // Disable auth user
        await supabaseAdmin.auth.admin.updateUserById(user_id, {
          ban_duration: '876000h', // ~100 years
        })

        return jsonResponse({ success: true, message: 'User deleted' }, 200, origin)
      }

      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400, origin)
    }
  } catch (error) {
    console.error('Admin action error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, origin)
  }
})
