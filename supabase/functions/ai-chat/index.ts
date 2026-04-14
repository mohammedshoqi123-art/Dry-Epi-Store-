import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { authenticateRequest, createUserClient } from '../_shared/auth.ts'

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

serve(async (req) => {
  const origin = req.headers.get('Origin')
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) })

  try {
    // Auth — no JWT fallback
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    const supabase = createUserClient(authHeader)
    const auth = await authenticateRequest(supabase, authHeader)
    if (!auth) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    // Parse request
    const { message, history = [], context, mode, stream = false } = await req.json()
    if (!message) return jsonResponse({ error: 'Message is required' }, 400, origin)

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
        }, 200, origin)
      }
      return jsonResponse({
        error: 'AI service not configured',
        reply: 'خدمة الذكاء الاصطناعي غير مُعدّة حالياً. يرجى التواصل مع مدير النظام.',
      }, 200, origin)
    }

    // Build messages (OpenAI format)
    const messages: Array<{ role: string; content: string }> = []

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
        }, 200, origin)
      }

      const reader = response.body?.getReader()
      if (!reader) {
        return jsonResponse({ error: 'Stream unavailable' }, 500, origin)
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
      }, 200, origin)
    }

    // Suggestions mode
    if (mode === 'suggestions') {
      try {
        const text = result.choices?.[0]?.message?.content ?? ''
        const suggestions = text.split('\n').filter((s: string) => s.trim().length > 5).slice(0, 3)
        return jsonResponse({ suggestions }, 200, origin)
      } catch {
        return jsonResponse({ suggestions: [] }, 200, origin)
      }
    }

    const reply = result.choices?.[0]?.message?.content ??
      'عذراً، لم أتمكن من معالجة طلبك.'

    return jsonResponse({ reply }, 200, origin)

  } catch (error) {
    console.error('AI chat error:', error)
    return jsonResponse({
      error: 'Internal error',
      reply: 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.'
    }, 500, origin)
  }
})
