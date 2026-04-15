/**
 * Shared CORS helper for Edge Functions.
 * All functions should import from here instead of duplicating CORS logic.
 *
 * SECURITY: Default is fail-closed. Set ALLOWED_ORIGINS in Supabase Edge Function Secrets.
 * Example: ALLOWED_ORIGINS=https://your-app.com,https://admin.your-app.com
 */

const ALLOWED_ORIGINS = (Deno.env.get('ALLOWED_ORIGINS') ?? '').split(',').map(s => s.trim()).filter(Boolean)

export function corsHeaders(origin: string | null): Record<string, string> {
  // ═══ FAIL-CLOSED: If no origins configured, only allow requests without Origin header ═══
  // Mobile apps (Flutter Android/iOS) don't send Origin header → they pass through.
  // Browser requests (Flutter Web) send Origin header → they must be explicitly allowed.
  if (ALLOWED_ORIGINS.length === 0) {
    // No Origin header = direct API call from mobile app → allow
    if (!origin) {
      return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      }
    }
    // Origin header present but no allowlist configured → block (fail-closed)
    return {
      'Access-Control-Allow-Origin': 'null',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Vary': 'Origin',
    }
  }

  // Check if origin is in allowlist
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : 'null'
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

/**
 * Create a JSON response with CORS headers.
 */
export function jsonResponse(data: unknown, status: number, origin: string | null): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
  })
}
