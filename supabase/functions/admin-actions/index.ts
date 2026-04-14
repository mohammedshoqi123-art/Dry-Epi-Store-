import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const ALLOWED_ORIGINS = (Deno.env.get('ALLOWED_ORIGINS') ?? '*').split(',').map(s => s.trim())

function corsHeaders(origin: string | null): Record<string, string> {
  const allowed = ALLOWED_ORIGINS.includes('*')
    ? '*'
    : (origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0] ?? '*')
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

const ROLE_HIERARCHY: Record<string, number> = {
  admin: 5,
  central: 4,
  governorate: 3,
  district: 2,
  data_entry: 1,
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req.headers.get('Origin')) })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
      })
    }

    // Client with user auth (for permission check)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    // Verify auth
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
      })
    }

    // Check if user is admin
    const { data: callerProfile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (callerProfile?.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Admin access required' }), {
        status: 403, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
      })
    }

    // Admin client (bypasses RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    const body = await req.json()
    const { action } = body

    switch (action) {
      case 'update_role': {
        const { user_id, role, governorate_id, district_id } = body
        if (!user_id || !role) {
          return new Response(JSON.stringify({ error: 'user_id and role are required' }), {
            status: 400, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
          })
        }
        if (!ROLE_HIERARCHY[role]) {
          return new Response(JSON.stringify({ error: `Invalid role: ${role}` }), {
            status: 400, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
          })
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
          return new Response(JSON.stringify({ error: updateError.message }), {
            status: 400, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
          })
        }

        return new Response(JSON.stringify({ success: true, message: 'Role updated' }), {
          status: 200, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
        })
      }

      case 'toggle_active': {
        const { user_id, is_active } = body
        if (!user_id || is_active === undefined) {
          return new Response(JSON.stringify({ error: 'user_id and is_active are required' }), {
            status: 400, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
          })
        }

        const { error: toggleError } = await supabaseAdmin
          .from('profiles')
          .update({ is_active, updated_at: new Date().toISOString() })
          .eq('id', user_id)

        if (toggleError) {
          return new Response(JSON.stringify({ error: toggleError.message }), {
            status: 400, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
          })
        }

        return new Response(JSON.stringify({ success: true, message: is_active ? 'User activated' : 'User deactivated' }), {
          status: 200, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
        })
      }

      case 'delete_user': {
        const { user_id } = body
        if (!user_id) {
          return new Response(JSON.stringify({ error: 'user_id is required' }), {
            status: 400, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
          })
        }

        // Prevent self-deletion
        if (user_id === user.id) {
          return new Response(JSON.stringify({ error: 'Cannot delete your own account' }), {
            status: 400, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
          })
        }

        // Soft delete profile
        await supabaseAdmin
          .from('profiles')
          .update({ deleted_at: new Date().toISOString(), is_active: false })
          .eq('id', user_id)

        // Disable auth user (can't delete via admin API easily, so we disable)
        await supabaseAdmin.auth.admin.updateUserById(user_id, {
          ban_duration: '876000h', // ~100 years
        })

        return new Response(JSON.stringify({ success: true, message: 'User deleted' }), {
          status: 200, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
        })
      }

      default:
        return new Response(JSON.stringify({ error: `Unknown action: ${action}` }), {
          status: 400, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
        })
    }
  } catch (error) {
    console.error('Admin action error:', error)
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
    })
  }
})
