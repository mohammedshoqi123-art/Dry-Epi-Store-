import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Role hierarchy: higher number = more privilege
const ROLE_HIERARCHY: Record<string, number> = {
  admin: 5,
  central: 4,
  governorate: 3,
  district: 2,
  data_entry: 1,
}

const VALID_ROLES = Object.keys(ROLE_HIERARCHY)

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    // ─── Authentication Check ──────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ─── Authorization — Only admin can create users ───────────
    const { data: callerProfile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (!callerProfile || callerProfile.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Forbidden: only admins can create users' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ─── Parse & Validate Input ────────────────────────────────
    const body = await req.json().catch(() => ({}))
    const { email, password, full_name, role } = body

    if (!email || !password) {
      return new Response(JSON.stringify({ error: 'Email and password are required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (password.length < 8) {
      return new Response(JSON.stringify({ error: 'Password must be at least 8 characters' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const targetRole = role && VALID_ROLES.includes(role) ? role : 'data_entry'
    const callerLevel = ROLE_HIERARCHY[callerProfile.role] ?? 0
    const targetLevel = ROLE_HIERARCHY[targetRole] ?? 0

    if (targetLevel >= callerLevel) {
      return new Response(
        JSON.stringify({ error: 'Cannot assign a role equal to or higher than your own' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // ─── Create User (Service Role) ────────────────────────────
    const adminSupabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: authUser, error: authCreateError } = await adminSupabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: full_name || 'مستخدم جديد',
        role: targetRole,
      },
    })

    if (authCreateError) {
      return new Response(JSON.stringify({ error: authCreateError.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (authUser.user) {
      await adminSupabase
        .from('profiles')
        .update({ role: targetRole, full_name: full_name || 'مستخدم جديد' })
        .eq('id', authUser.user.id)
    }

    // Audit log
    await adminSupabase.from('audit_logs').insert({
      user_id: user.id,
      action: 'create',
      table_name: 'profiles',
      record_id: authUser.user?.id,
      metadata: { created_user_email: email, assigned_role: targetRole },
    }).then(() => {}).catch(() => {})

    return new Response(
      JSON.stringify({
        success: true,
        user: { id: authUser.user?.id, email: authUser.user?.email, role: targetRole },
      }),
      {
        status: 201,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('Create admin error:', error)
    return new Response(
      JSON.stringify({ error: (error instanceof Error ? error.message : 'Internal server error') }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
