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
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
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
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const body = await req.json()
    const { message, history = [], context, mode = 'chat', language = 'ar' } = body

    if (!message || typeof message !== 'string') {
      return new Response(JSON.stringify({ error: 'Message is required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Build Gemini prompt
    const systemPrompt = `أنت مساعد ذكي متخصص في تحليل بيانات حملات التطعيم في العراق.
    
أنت تعمل ضمن "منصة مشرف EPI" - نظام إشراف ميداني لمتابعة حملات التطعيم.

مهامك:
1. تحليل بيانات الإرساليات والنواقص وتقديم رؤى مفيدة
2. الإجابة على الأسئلة المتعلقة بالبيانات بدقة وإيجاز
3. تقديم توصيات عملية لتحسين الأداء الميداني
4. استخدام اللغة العربية الفصحى البسيطة

${context ? `البيانات المتاحة حالياً:\n${JSON.stringify(context, null, 2)}` : ''}

قوانين الإجابة:
- أجب بالعربية دائماً ما لم يُطلب منك غير ذلك
- كن موجزاً ومفيداً (لا تزيد عن 3 فقرات)
- استخدم أرقام ونسب مئوية من البيانات عند الإمكان
- إذا لم تكن لديك بيانات كافية، اطلب توضيحاً`

    // Build conversation history for Gemini
    const contents = []
    
    // Add history
    for (const msg of history.slice(-10)) { // last 10 messages max
      if (msg.role === 'user') {
        contents.push({ role: 'user', parts: [{ text: msg.content }] })
      } else if (msg.role === 'assistant') {
        contents.push({ role: 'model', parts: [{ text: msg.content }] })
      }
    }

    // Add current message (if not already in history)
    const lastContent = contents[contents.length - 1]
    if (!lastContent || lastContent.role !== 'user' || lastContent.parts[0].text !== message) {
      contents.push({ role: 'user', parts: [{ text: message }] })
    }

    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      // Fallback response when API key not configured
      return new Response(JSON.stringify({
        reply: 'عذراً، لم يتم تهيئة مفتاح Gemini API بعد. يرجى الاتصال بمدير النظام.',
        mode
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const geminiResponse = await fetch(`${GEMINI_API_URL}?key=${geminiApiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents,
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 1024,
          topP: 0.9,
        },
        safetySettings: [
          { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
          { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
        ]
      })
    })

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text()
      console.error('Gemini API error:', errText)
      return new Response(JSON.stringify({
        reply: 'عذراً، حدث خطأ في الاتصال بالمساعد الذكي. يرجى المحاولة مرة أخرى.',
        error: errText
      }), {
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const geminiData = await geminiResponse.json()
    const reply = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text 
      || 'عذراً، لم أتمكن من توليد إجابة.'

    // Log AI usage
    await supabase.from('audit_logs').insert({
      user_id: user.id,
      action: 'read',
      table_name: 'ai_chat',
      metadata: { message_length: message.length, mode }
    }).then(() => {}).catch(() => {})

    return new Response(JSON.stringify({ reply, mode }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('AI Chat error:', error)
    return new Response(JSON.stringify({
      reply: 'عذراً، حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.',
      error: error instanceof Error ? error.message : 'Unknown error'
    }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
