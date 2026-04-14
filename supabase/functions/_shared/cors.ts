/**
 * Shared CORS helper for Edge Functions.
 * All functions should import from here instead of duplicating CORS logic.
 */

const ALLOWED_ORIGINS = (Deno.env.get('ALLOWED_ORIGINS') ?? '').split(',').map(s => s.trim()).filter(Boolean)

export function corsHeaders(origin: string | null): Record<string, string> {
  // If no origins configured, reject all cross-origin requests
  if (ALLOWED_ORIGINS.length === 0) {
    return {
      'Access-Control-Allow-Origin': 'null',
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
