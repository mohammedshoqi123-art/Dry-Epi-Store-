import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'npm:@supabase/supabase-js'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { authenticateRequest, createUserClient } from '../_shared/auth.ts'

const DASHBOARD_RATE_LIMIT = 30
const DASHBOARD_RATE_WINDOW = 60

async function checkRateLimit(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<boolean> {
  try {
    const { data, error } = await supabase.rpc('check_and_increment_rate_limit', {
      p_user_id: userId,
      p_endpoint: 'get-dashboard-stats',
      p_window_seconds: DASHBOARD_RATE_WINDOW,
      p_max_requests: DASHBOARD_RATE_LIMIT,
    })
    if (error) { console.error('Dashboard rate limit RPC error (blocking):', error.message); return false }
    return data?.[0]?.allowed ?? false
  } catch (e) { console.error('Dashboard rate limit failed (blocking):', e); return false }
}

serve(async (req) => {
  const origin = req.headers.get('Origin')
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    const supabase = createUserClient(authHeader)
    const auth = await authenticateRequest(supabase, authHeader)
    if (!auth) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    // Rate limiting (fail-closed)
    if (!(await checkRateLimit(supabase, auth.userId))) {
      return jsonResponse({ error: 'Rate limit exceeded' }, 429, origin)
    }

    const body = await req.json().catch(() => ({}))
    const targetUserId = body.user_id || auth.userId
    const campaignType = body.campaign_type

    const { data, error } = await supabase.rpc('get_dashboard_stats', {
      p_user_id: targetUserId,
      p_campaign_type: campaignType || null
    })

    if (error) {
      console.error('Dashboard stats RPC error:', error)
      return jsonResponse({
        role: 'data_entry',
        my_submissions: 0, pending: 0, approved: 0, rejected: 0, drafts: 0,
        unread_notifications: 0,
        _error: error.message
      }, 200, origin)
    }

    return jsonResponse(data ?? {}, 200, origin)
  } catch (error) {
    console.error('Dashboard stats error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, origin)
  }
})
