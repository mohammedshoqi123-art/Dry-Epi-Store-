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

// ─── MiMo API Configuration (OpenAI-compatible) ───────────
const MIMO_API_URL = 'https://api.xiaomimimo.com/v1/chat/completions'
const MIMO_MODEL = 'mimo-v2-pro'

const SYSTEM_PROMPT = `أنت مساعد ذكي متخصص في تحليل بيانات حملات التطعيم في اليمن (منصة مشرف EPI).
مهامك:
- تحليل بيانات الإرساليات والنواقص والإحصائيات
- تقديم رؤى وتوصيات مبنية على البيانات
- الإجابة باللغة العربية بشكل احترافي ومفيد
- اقتراح حلول للمشاكل الميدانية
- مقارنة الأداء بين المحافظات والفترات

قواعد الإجابة:
- كن دقيقاً ومختصراً
- استخدم الأرقام من البيانات المتاحة
- قدم توصيات عملية قابلة للتنفيذ
- إذا لم تتوفر بيانات كافية، اطلب توضيحاً`

function parseJwtPayload(token: string): { sub: string; email?: string; role?: string } | null {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')))
    return payload.sub ? payload : null
  } catch { return null }
}

serve(async (req) => {
  const origin = req.headers.get('Origin')
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) })

  const jsonResponse = (data: unknown, status: number) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    })

  try {
    // Auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401)

    const token = authHeader.replace('Bearer ', '')
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    let userId: string | null = null
    try {
      const { data: { user }, error } = await supabase.auth.getUser()
      if (!error && user) userId = user.id
    } catch { /* fallback */ }

    if (!userId) {
      const jwt = parseJwtPayload(token)
      if (jwt) { userId = jwt.sub; console.warn('[Auth] JWT fallback:', userId) }
    }
    if (!userId) return jsonResponse({ error: 'Unauthorized' }, 401)

    // Parse request
    const { message, history = [], context, mode, stream = false } = await req.json()
    if (!message) return jsonResponse({ error: 'Message is required' }, 400)

    // Check MiMo API key
    const mimoApiKey = Deno.env.get('MIMO_API_KEY') ?? Deno.env.get('GEMINI_API_KEY')
    if (!mimoApiKey) {
      if (mode === 'suggestions') {
        return jsonResponse({
          suggestions: [
            'ما هي المحافظات الأكثر نشاطاً في الإرسال؟',
            'ما أكثر النواقص شيوعاً هذا الشهر؟',
            'كيف تقارن إرساليات هذا الأسبوع بالأسبوع الماضي؟',
          ]
        }, 200)
      }
      return jsonResponse({
        error: 'AI service not configured',
        reply: 'خدمة الذكاء الاصطناعي غير مُعدّة حالياً. يرجى التواصل مع مدير النظام.',
      }, 200)
    }

    // Build messages (OpenAI format)
    const messages: Array<{ role: string; content: string }> = []

    // System prompt
    let systemContent = SYSTEM_PROMPT
    if (context) {
      systemContent += `\n\nالبيانات المتاحة:\n${JSON.stringify(context, null, 2)}`
    }
    if (mode === 'suggestions') {
      systemContent = 'اقترح 3 أسئلة تحليلية مفيدة لمستخدم منصة إشراف التطعيم. أرجع كل سؤال في سطر منفصل بدون ترقيم.'
    }
    messages.push({ role: 'system', content: systemContent })

    // History (last 10 messages)
    for (const msg of history.slice(-10)) {
      messages.push({
        role: msg.role === 'user' ? 'user' : 'assistant',
        content: msg.content
      })
    }

    // Current message
    messages.push({ role: 'user', content: message })

    const requestBody = {
      model: MIMO_MODEL,
      messages,
      max_tokens: 2048,
      temperature: 0.7,
      stream,
    }

    // ─── Streaming response ────────────────────────────────
    if (stream) {
      const response = await fetch(MIMO_API_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${mimoApiKey}`,
        },
        body: JSON.stringify(requestBody),
      })

      if (!response.ok) {
        const err = await response.text()
        console.error('MiMo stream error:', err)
        return jsonResponse({
          error: 'AI service error',
          reply: 'حدث خطأ في خدمة الذكاء الاصطناعي.'
        }, 200)
      }

      const reader = response.body?.getReader()
      if (!reader) {
        return jsonResponse({ error: 'Stream unavailable' }, 500)
      }

      const { readable, writable } = new TransformStream()
      const writer = writable.getWriter()
      const encoder = new TextEncoder()
      const decoder = new TextDecoder()

      ;(async () => {
        try {
          let buffer = ''
          while (true) {
            const { done, value } = await reader.read()
            if (done) break

            buffer += decoder.decode(value, { stream: true })
            const lines = buffer.split('\n')
            buffer = lines.pop() ?? ''

            for (const line of lines) {
              const trimmed = line.trim()
              if (!trimmed || !trimmed.startsWith('data: ')) continue
              const data = trimmed.slice(6)
              if (data === '[DONE]') {
                await writer.write(encoder.encode('data: [DONE]\n\n'))
                continue
              }
              try {
                const parsed = JSON.parse(data)
                const text = parsed.choices?.[0]?.delta?.content
                if (text) {
                  await writer.write(encoder.encode(`data: ${JSON.stringify({ text })}\n\n`))
                }
              } catch { /* skip malformed */ }
            }
          }
          await writer.write(encoder.encode('data: [DONE]\n\n'))
        } catch (err) {
          console.error('Stream error:', err)
        } finally {
          await writer.close()
        }
      })()

      return new Response(readable, {
        status: 200,
        headers: {
          ...corsHeaders(origin),
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
      })
    }

    // ─── Non-streaming response ────────────────────────────
    const response = await fetch(MIMO_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${mimoApiKey}`,
      },
      body: JSON.stringify(requestBody),
    })

    const result = await response.json()

    if (!response.ok) {
      console.error('MiMo error:', result)
      return jsonResponse({
        error: 'AI service error',
        reply: 'حدث خطأ في خدمة الذكاء الاصطناعي. يرجى المحاولة لاحقاً.'
      }, 200)
    }

    // Suggestions mode
    if (mode === 'suggestions') {
      try {
        const text = result.choices?.[0]?.message?.content ?? ''
        const suggestions = text.split('\n').filter((s: string) => s.trim().length > 5).slice(0, 3)
        return jsonResponse({ suggestions }, 200)
      } catch {
        return jsonResponse({ suggestions: [] }, 200)
      }
    }

    const reply = result.choices?.[0]?.message?.content ??
      'عذراً، لم أتمكن من معالجة طلبك.'

    return jsonResponse({ reply }, 200)

  } catch (error) {
    console.error('AI chat error:', error)
    return jsonResponse({
      error: 'Internal error',
      reply: 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.'
    }, 500)
  }
})
