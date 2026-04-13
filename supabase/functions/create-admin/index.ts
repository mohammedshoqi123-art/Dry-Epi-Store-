import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGINS') ?? 'https://mohammedshoqi123-art.github.io',
  'Vary': 'Origin',
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

    // Use service role key for admin operations
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    )

    // ─── Authorization: Verify caller is an admin ───────────────
    // Extract the caller's JWT from the Authorization header
    const jwt = authHeader.replace('Bearer ', '')
    const { data: { user: caller }, error: callerError } =
      await supabaseAdmin.auth.getUser(jwt)

    if (callerError || !caller) {
      return new Response(JSON.stringify({ error: 'Invalid or expired token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Check that the caller has admin role
    const { data: callerProfile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', caller.id)
      .single()

    if (profileError || !callerProfile || callerProfile.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Forbidden: admin role required' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ─── Parse Request ─────────────────────────────────────────
    const body = await req.json()
    const { email, password, full_name, role = 'admin' } = body

    // Validate inputs
    if (!email || !password || !full_name) {
      return new Response(
        JSON.stringify({ error: 'email, password, and full_name are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    if (!VALID_ROLES.includes(role)) {
      return new Response(
        JSON.stringify({
          error: `Invalid role. Must be one of: ${VALID_ROLES.join(', ')}`,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // ─── Role hierarchy enforcement ────────────────────────────
    const callerLevel = ROLE_HIERARCHY[callerProfile.role]
    const targetLevel = ROLE_HIERARCHY[role]
    if (targetLevel >= callerLevel) {
      return new Response(
        JSON.stringify({
          error: `Cannot assign role '${role}' — you can only assign roles lower than your own`,
        }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // ─── Check if User Already Exists ──────────────────────────
    const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers()
    const existingUser = existingUsers?.users?.find((u) => u.email === email)

    if (existingUser) {
      // User exists - check if profile exists and update role
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('id, role')
        .eq('id', existingUser.id)
        .maybeSingle()

      if (profile) {
        // Update role if different
        if (profile.role !== role) {
          await supabaseAdmin
            .from('profiles')
            .update({ role, full_name, updated_at: new Date().toISOString() })
            .eq('id', existingUser.id)
        }

        return new Response(
          JSON.stringify({
            success: true,
            message: 'User already exists. Profile updated.',
            user: {
              id: existingUser.id,
              email: existingUser.email,
              role: role,
            },
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        )
      } else {
        // User exists in auth but no profile - create profile
        await supabaseAdmin.from('profiles').insert({
          id: existingUser.id,
          email: email,
          full_name: full_name,
          role: role,
        })

        return new Response(
          JSON.stringify({
            success: true,
            message: 'User existed in auth. Profile created.',
            user: {
              id: existingUser.id,
              email: existingUser.email,
              role: role,
            },
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        )
      }
    }

    // ─── Create New Auth User ──────────────────────────────────
    const { data: newUser, error: createError } =
      await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          full_name,
          role,
        },
      })

    if (createError) {
      return new Response(
        JSON.stringify({ error: `Failed to create user: ${createError.message}` }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Profile is auto-created by the handle_new_user() trigger
    // But let's ensure it has the correct data
    if (newUser?.user) {
      await supabaseAdmin
        .from('profiles')
        .upsert({
          id: newUser.user.id,
          email: email,
          full_name: full_name,
          role: role,
        })
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'User created successfully',
        user: {
          id: newUser?.user?.id,
          email: email,
          role: role,
        },
      }),
      {
        status: 201,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: `Internal error: ${(error as Error).message}` }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
