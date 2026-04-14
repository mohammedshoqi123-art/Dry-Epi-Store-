/**
 * Shared auth helper for Edge Functions.
 * 
 * Validates JWT via Supabase's getUser() which verifies the token signature.
 * JWT fallback parsing has been REMOVED for security — unsigned tokens are never trusted.
 */

import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

export interface AuthResult {
  userId: string
  email?: string
  role?: string
}

/**
 * Authenticate a request using Supabase's getUser() which validates the JWT signature.
 * Returns null if authentication fails.
 * 
 * SECURITY: No JWT fallback parsing — tokens must be properly signed.
 */
export async function authenticateRequest(
  supabase: SupabaseClient,
  authHeader: string
): Promise<AuthResult | null> {
  if (!authHeader) return null

  try {
    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) return null

    return {
      userId: user.id,
      email: user.email,
      role: user.user_metadata?.role ?? user.app_metadata?.role,
    }
  } catch {
    return null
  }
}

/**
 * Extract the Bearer token from Authorization header.
 */
export function extractToken(authHeader: string | null): string | null {
  if (!authHeader) return null
  const match = authHeader.match(/^Bearer\s+(.+)$/i)
  return match ? match[1] : null
}

/**
 * Create a Supabase client with user auth context.
 */
export function createUserClient(authHeader: string) {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } }
  )
}

/**
 * Create a Supabase admin client (service role, bypasses RLS).
 * Returns null if SERVICE_ROLE_KEY is not configured.
 */
export function createAdminClient() {
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!serviceKey || serviceKey.length < 10) return null

  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    serviceKey,
    { auth: { autoRefreshToken: false, persistSession: false } }
  )
}
