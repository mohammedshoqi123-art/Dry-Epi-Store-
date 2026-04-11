import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent'

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
    const { message, history = [], context, language = 'ar', mode } = await req.json()

    if (!message) {
      return new Response(JSON.stringify({ error: 'Message is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Check Gemini API key
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      return new Response(JSON.stringify({
        error: 'AI service not configured',
        reply: 'خدمة الذكاء الاصطناعي غير مُعدّة حالياً. يرجى التواصل مع مدير النظام.',
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

    // Build context
    let systemContext = ''
    if (context) {
      systemContext = `
أنت مساعد ذكي متخصص في تحليل بيانات حملات التطعيم في العراق.
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

    // Call Gemini
    const response = await fetch(`${GEMINI_API_URL}?key=${geminiApiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents,
        generationConfig: {
          maxOutputTokens: 2048,
          temperature: 0.7,
        }
      })
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
