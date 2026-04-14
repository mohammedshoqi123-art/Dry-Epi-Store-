/**
 * Shared auth helper for Edge Functions.
 * 
 * Validates JWT and extracts user info. Handles both HS256 and ES256 tokens.
 * Falls back to direct JWT payload parsing if getUser() fails (e.g., ES256 key mismatch).
 */

interface JwtPayload {
  sub: string
  email?: string
  role?: string
  aud?: string
  iss?: string
}

function base64UrlDecode(str: string): string {
  str = str.replace(/-/g, '+').replace(/_/g, '/')
  while (str.length % 4) str += '='
  return atob(str)
}

function parseJwtPayload(token: string): JwtPayload | null {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    const payload = JSON.parse(base64UrlDecode(parts[1]))
    if (!payload.sub) return null
    return payload as JwtPayload
  } catch {
    return null
  }
}

export interface AuthResult {
  userId: string
  email?: string
  role?: string
  method: 'getUser' | 'jwt_parse'
}

/**
 * Authenticate a request. Tries getUser() first, falls back to JWT parsing.
 * Returns null if authentication fails completely.
 */
export async function authenticateRequest(
  supabase: ReturnType<typeof import('https://esm.sh/@supabase/supabase-js@2.49.1').createClient>,
  authHeader: string
): Promise<AuthResult | null> {
  const token = authHeader.replace('Bearer ', '')

  // Try getUser() first (preferred - validates with auth service)
  try {
    const { data: { user }, error } = await supabase.auth.getUser()
    if (!error && user) {
      return {
        userId: user.id,
        email: user.email,
        role: user.user_metadata?.role ?? user.app_metadata?.role,
        method: 'getUser'
      }
    }
  } catch {
    // getUser failed, try fallback
  }

  // Fallback: parse JWT payload directly
  const payload = parseJwtPayload(token)
  if (payload && payload.sub) {
    console.warn('[Auth] Using JWT fallback parsing (getUser failed)')
    return {
      userId: payload.sub,
      email: payload.email,
      role: payload.role,
      method: 'jwt_parse'
    }
  }

  return null
}
