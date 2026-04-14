import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Vary': 'Origin',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent'
const GEMINI_STREAM_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:streamGenerateContent'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    // Auth check
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Parse request
    const { message, history = [], context, language = 'ar', mode, stream = false } = await req.json()

    if (!message) {
      return new Response(JSON.stringify({ error: 'Message is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Check Gemini API key
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      // Suggestions mode fallback
      if (mode === 'suggestions') {
        return new Response(JSON.stringify({
          suggestions: [
            'ما هي المحافظات الأكثر نشاطاً في الإرسال؟',
            'ما أكثر النواقص شيوعاً هذا الشهر؟',
            'كيف تقارن إرساليات هذا الأسبوع بالأسبوع الماضي؟'
          ]
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
      return new Response(JSON.stringify({
        error: 'AI service not configured',
        reply: 'خدمة الذكاء الاصطناعي غير مُعدّة حالياً. يرجى التواصل مع مدير النظام.',
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Build context
    let systemContext = ''
    if (context) {
      systemContext = `
أنت مساعد ذكي متخصص في تحليل بيانات حملات التطعيم في اليمن.
قدم إجابات مفيدة ودقيقة باللغة العربية.
البيانات المتاحة:
${JSON.stringify(context, null, 2)}
`
    }

    // Build conversation
    const contents = []
    if (systemContext) {
      contents.push({ role: 'user', parts: [{ text: systemContext }] })
      contents.push({ role: 'model', parts: [{ text: 'فهمت. سأقوم بتحليل البيانات وتقديم رؤى مفيدة.' }] })
    }

    // Add history
    for (const msg of history.slice(-10)) {
      contents.push({
        role: msg.role === 'user' ? 'user' : 'model',
        parts: [{ text: msg.content }]
      })
    }

    // Add current message
    contents.push({ role: 'user', parts: [{ text: message }] })

    const requestBody = {
      contents,
      generationConfig: {
        maxOutputTokens: 2048,
        temperature: 0.7,
        ...(mode === 'suggestions' ? { responseMimeType: 'application/json' } : {}),
      },
      ...(mode === 'suggestions' ? {
        systemInstruction: {
          parts: [{ text: 'اقترح 3 أسئلة تحليلية مفيدة. أرجع النتيجة كـ JSON array من strings فقط.' }]
        }
      } : {}),
    }

    // ─── Streaming response ────────────────────────────────
    if (stream) {
      const response = await fetch(GEMINI_STREAM_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': geminiApiKey,
        },
        body: JSON.stringify({ ...requestBody, alt: 'sse' }),
      })

      if (!response.ok) {
        const err = await response.text()
        console.error('Gemini stream error:', err)
        return new Response(JSON.stringify({
          error: 'AI service error',
          reply: 'حدث خطأ في خدمة الذكاء الاصطناعي.'
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // Stream SSE chunks to the client
      const reader = response.body?.getReader()
      if (!reader) {
        return new Response(JSON.stringify({ error: 'Stream unavailable' }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const { readable, writable } = new TransformStream()
      const writer = writable.getWriter()
      const encoder = new TextEncoder()
      const decoder = new TextDecoder()

      // Process stream in background
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
              if (line.startsWith('data: ')) {
                const data = line.slice(6).trim()
                if (data === '[DONE]') continue
                try {
                  const parsed = JSON.parse(data)
                  const text = parsed.candidates?.[0]?.content?.parts?.[0]?.text
                  if (text) {
                    await writer.write(encoder.encode(`data: ${JSON.stringify({ text })}\n\n`))
                  }
                } catch { /* skip malformed JSON */ }
              }
            }
          }
          await writer.write(encoder.encode('data: [DONE]\n\n'))
        } catch (err) {
          console.error('Stream processing error:', err)
        } finally {
          await writer.close()
        }
      })()

      return new Response(readable, {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
      })
    }

    // ─── Non-streaming response (default) ──────────────────
    const response = await fetch(GEMINI_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': geminiApiKey,
      },
      body: JSON.stringify(requestBody),
    })

    const result = await response.json()

    if (!response.ok) {
      console.error('Gemini error:', result)
      return new Response(JSON.stringify({
        error: 'AI service error',
        reply: 'حدث خطأ في خدمة الذكاء الاصطناعي. يرجى المحاولة لاحقاً.'
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Suggestions mode — parse as JSON
    if (mode === 'suggestions') {
      try {
        const text = result.candidates?.[0]?.content?.parts?.[0]?.text ?? '[]'
        const suggestions = JSON.parse(text)
        return new Response(JSON.stringify({ suggestions }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      } catch {
        return new Response(JSON.stringify({ suggestions: [] }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }

    const reply = result.candidates?.[0]?.content?.parts?.[0]?.text ??
      'عذراً، لم أتمكن من معالجة طلبك.'

    return new Response(JSON.stringify({ reply }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('AI chat error:', error)
    return new Response(JSON.stringify({
      error: 'Internal error',
      reply: 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.'
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
