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

function parseJwtPayload(token: string): { sub: string; email?: string; role?: string } | null {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')))
    return payload.sub ? payload : null
  } catch { return null }
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

    const token = authHeader.replace('Bearer ', '')
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    // Try getUser() first, fall back to JWT parsing
    let userId: string | null = null
    try {
      const { data: { user }, error } = await supabase.auth.getUser()
      if (!error && user) userId = user.id
    } catch { /* fallback below */ }

    if (!userId) {
      const jwt = parseJwtPayload(token)
      if (jwt) {
        userId = jwt.sub
        console.warn('[Auth] Using JWT fallback for user:', userId)
      }
    }

    if (!userId) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
      })
    }

    const body = await req.json().catch(() => ({}))
    const targetUserId = body.user_id || userId

    const { data, error } = await supabase.rpc('get_dashboard_stats', {
      p_user_id: targetUserId
    })

    if (error) {
      console.error('Dashboard stats RPC error:', error)
      return new Response(JSON.stringify({
        role: 'data_entry',
        my_submissions: 0, pending: 0, approved: 0, rejected: 0, drafts: 0,
        unread_notifications: 0,
        _error: error.message
      }), {
        status: 200, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify(data ?? {}), {
      status: 200,
      headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500, headers: { ...corsHeaders(req.headers.get('Origin')), 'Content-Type': 'application/json' }
    })
  }
})
