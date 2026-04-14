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
const VALID_ROLES = Object.keys(ROLE_HIERARCHY)

serve(async (req) => {
  const origin = req.headers.get('Origin')
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) })

  try {
    // ─── Internal Secret Check (defense in depth) ───────────
    const internalSecret = req.headers.get('x-internal-secret')
    const expectedSecret = Deno.env.get('CREATE_ADMIN_SECRET')
    if (expectedSecret && internalSecret !== expectedSecret) {
      return jsonResponse({ error: 'Invalid internal secret' }, 403, origin)
    }

    // ─── Authentication ────────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonResponse({ error: 'Missing authorization header' }, 401, origin)
    }

    const supabaseAdmin = createAdminClient()
    if (!supabaseAdmin) {
      return jsonResponse({ error: 'Admin operations not configured' }, 500, origin)
    }

    // Verify caller via admin client (validates JWT signature)
    const supabase = createUserClient(authHeader)
    const auth = await authenticateRequest(supabase, authHeader)
    if (!auth) {
      return jsonResponse({ error: 'Invalid or expired token' }, 401, origin)
    }

    // Check that the caller has admin role
    const { data: callerProfile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', auth.userId)
      .single()

    if (profileError || !callerProfile || callerProfile.role !== 'admin') {
      return jsonResponse({ error: 'Forbidden: admin role required' }, 403, origin)
    }

    // ─── Parse Request ─────────────────────────────────────
    const body = await req.json()
    const { email, password, full_name, role = 'admin' } = body

    if (!email || !password || !full_name) {
      return jsonResponse({ error: 'email, password, and full_name are required' }, 400, origin)
    }

    if (!VALID_ROLES.includes(role)) {
      return jsonResponse({ error: `Invalid role. Must be one of: ${VALID_ROLES.join(', ')}` }, 400, origin)
    }

    // ─── Role hierarchy enforcement ────────────────────────
    const callerLevel = ROLE_HIERARCHY[callerProfile.role]
    const targetLevel = ROLE_HIERARCHY[role]
    if (targetLevel >= callerLevel) {
      return jsonResponse({
        error: `Cannot assign role '${role}' — you can only assign roles lower than your own`,
      }, 403, origin)
    }

    // ─── Check if User Already Exists ──────────────────────
    const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers()
    const existingUser = existingUsers?.users?.find((u) => u.email === email)

    if (existingUser) {
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('id, role')
        .eq('id', existingUser.id)
        .maybeSingle()

      if (profile) {
        if (profile.role !== role) {
          await supabaseAdmin
            .from('profiles')
            .update({ role, full_name, updated_at: new Date().toISOString() })
            .eq('id', existingUser.id)
        }
        return jsonResponse({
          success: true,
          message: 'User already exists. Profile updated.',
          user: { id: existingUser.id, email: existingUser.email, role },
        }, 200, origin)
      } else {
        await supabaseAdmin.from('profiles').insert({
          id: existingUser.id,
          email,
          full_name,
          role,
        })
        return jsonResponse({
          success: true,
          message: 'User existed in auth. Profile created.',
          user: { id: existingUser.id, email: existingUser.email, role },
        }, 200, origin)
      }
    }

    // ─── Create New Auth User ──────────────────────────────
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name, role },
    })

    if (createError) {
      return jsonResponse({ error: `Failed to create user: ${createError.message}` }, 400, origin)
    }

    return jsonResponse({
      success: true,
      message: 'User created successfully',
      user: {
        id: newUser.user.id,
        email: newUser.user.email,
        role,
      },
    }, 201, origin)

  } catch (error) {
    console.error('Create admin error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, origin)
  }
})
