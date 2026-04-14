import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { authenticateRequest, createUserClient } from '../_shared/auth.ts'

serve(async (req) => {
  const origin = req.headers.get('Origin')
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    // Authenticate — no JWT fallback
    const supabase = createUserClient(authHeader)
    const auth = await authenticateRequest(supabase, authHeader)
    if (!auth) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    const body = await req.json().catch(() => ({}))
    const startDate = body.start_date
    const endDate = body.end_date

    const { data, error } = await supabase.rpc('get_governorate_report', {
      p_start_date: startDate || null,
      p_end_date: endDate || null
    })

    if (error) {
      console.error('Governorate report error:', error)
      return jsonResponse({ error: error.message }, 400, origin)
    }

    return jsonResponse(data ?? [], 200, origin)
  } catch (error) {
    console.error('Governorate report error:', error)
    return jsonResponse({ error: 'Internal server error' }, 500, origin)
  }
})
