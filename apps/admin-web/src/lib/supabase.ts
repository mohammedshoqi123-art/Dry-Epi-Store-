import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || ''
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''

// Retry wrapper for fetch to handle "Failed to fetch" errors
const originalFetch = window.fetch.bind(window)
window.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
  const maxRetries = 3
  const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const response = await originalFetch(input, init)
      return response
    } catch (error: unknown) {
      const isLastAttempt = attempt === maxRetries
      const isFetchError = error instanceof TypeError && (error.message === 'Failed to fetch' || error.message.includes('fetch'))
      
      if (!isFetchError || isLastAttempt) {
        throw error
      }
      
      // Wait before retry with exponential backoff
      const delay = Math.min(500 * Math.pow(2, attempt), 3000)
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }
  
  // This should never be reached, but TypeScript needs it
  return originalFetch(input, init)
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
  },
  global: {
    headers: {
      'X-Client-Info': 'epi-supervisor-admin',
    },
  },
})

export const isConfigured = Boolean(supabaseUrl && supabaseAnonKey)
