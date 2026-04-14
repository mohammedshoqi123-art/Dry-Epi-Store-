/**
 * Shared CORS helper for Edge Functions.
 * All functions should import from here instead of duplicating CORS logic.
 */

const ALLOWED_ORIGINS = (Deno.env.get('ALLOWED_ORIGINS') ?? '').split(',').map(s => s.trim()).filter(Boolean)

export function corsHeaders(origin: string | null): Record<string, string> {
  // ═══ FIX: If no origins configured, allow requests with no Origin header
  // (direct API calls, mobile apps) and also allow requests from any http/https origin.
  // This is needed because Flutter web sends an Origin header, and blocking it
  // causes the web app to fail entirely.
  // For production, set ALLOWED_ORIGINS env var to restrict to your domains.
  if (ALLOWED_ORIGINS.length === 0) {
    // Allow any origin when not explicitly configured — needed for Flutter web + mobile
    return {
      'Access-Control-Allow-Origin': origin ?? '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Vary': 'Origin',
    }
  }

  // Allow all only if explicitly set (not recommended for production)
  if (ALLOWED_ORIGINS.includes('*')) {
    return {
      'Access-Control-Allow-Origin': '*',
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
