import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { authenticateRequest, createUserClient } from '../_shared/auth.ts'

const MIMO_API_URL = 'https://api.xiaomimimo.com/v1/chat/completions'
const MIMO_MODEL = 'mimo-v2-pro'

// ═══════════════════════════════════════════════════════════════
// KNOWLEDGE BASE — EPI Yemen + Platform Reference
// Source: WHO EMRO Yemen EPI + Project Documentation + Guidelines
// ═══════════════════════════════════════════════════════════════
const EPI_KNOWLEDGE = `أنت "مساعد EPI" — متخصص في برنامج التطعيم الموسع في اليمن ومنصة مشرف EPI.

== معلومات EPI اليمن ==
• تأسس 1974. يحتاج الطفل 5 زيارات سنة أولى + زيارة سنة ثانية + زيارة سنة خامسة.
• التطعيمات (14): BCG (ولادة), OPV/IPV (شلل), Penta DPT+HepB+Hib (خماسي), PCV (رئوي), Rotavirus, MR (حصبة), HepB ولادي.
• الجدول: ولادة→BCG+OPV0+HepB. 6 أسابيع→Penta1+OPV1+PCV1+Rota1. 10 أسابيع→Penta2+OPV2+PCV2+Rota2. 14 أسبوع→Penta3+OPV3+PCV3+IPV. 9 أشهر→MR.
• التحديات: 27% أطفال غير مطعمين, إعادة شلل 2020-2021, نزوح, ضعف صحي.
• المؤشرات: Penta3=وصول, Dropout=استمرارية, الحصبة=حماية جماعية.
• Health Score: 80+=ممتاز, 50-79=متوسط, <50=ضعيف.
• معدل الرفض: <5%=جيد, 5-15%=تدريب, >15%=مشكلة خطيرة.

== منصة مشرف EPI ==
• Flutter + Supabase + MiMo AI. Offline-first.
• 5 مستويات: admin(5)>central(4)>governorate(3)>district(2)>data_entry(1).
• نماذج: JSON Schema ديناميكية. حقول: نص/رقم/نعم-لا/اختيار/تاريخ.
• سير العمل: مسودة→مرسل→مراجعة→اعتماد/رفض.
• نواقص: supply_shortages بمستويات حرج/عالي/متوسط/منخفض.
• التحليلات: KPIs, رسوم بيانية, تصدير CSV/PDF.
• بدون إنترنت: Hive + تشفير AES + مزامنة تلقائية.

== قواعد الإجابة ==
• مختصر (≤120 كلمة عادة). أرقام من البيانات. توصيات عملية.
• العربية احترافية. للأسئلة العامة: 3-5 جمل.
• للتقارير: قوالب جاهزة. لا تختلق أرقام.`

// ─── Report Template Prompts (token-optimized) ─────────
const TEMPLATES: Record<string, string> = {
  daily: 'أنشئ تقريراً يومياً: ملخص الإرساليات، توزيع الحالات، النواقص الحرجة، 3 توصيات.',
  weekly: 'حلل اتجاه الأسبوع: هل الإرساليات في تحسن؟ مقارنة بيوم متوسط. أسباب.',
  governorate: 'رتب المحافظات بالأداء: الأفضل/الأضعف. نسب. سبب التفاوت. توصية.',
  shortages: 'حلل النواقص: حسب الخطورة، حسب الموقع، أولويات معالجة.',
  quality: 'حلل جودة الإدخال: نسبة الرفض، اكتمال الحقول، أكثر الأخطاء. تحسينات.',
  comparison: 'قارن فترتين: الأسبوع الحالي vs السابق. نسب تغيير. تفسير.',
  coverage: 'حلل تغطية التطعيم: Penta3, dropout, حصبة. فجوات. تدخلات.',
  field_performance: 'تقييم أداء المشرفين الميدانيين: عدد الإرساليات، جودة، التزام.',
}

serve(async (req) => {
  const origin = req.headers.get('Origin')
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(origin) })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    const supabase = createUserClient(authHeader)
    const auth = await authenticateRequest(supabase, authHeader)
    if (!auth) return jsonResponse({ error: 'Unauthorized' }, 401, origin)

    const { message, history = [], context, mode, template, stream = false } = await req.json()
    if (!message && !template) return jsonResponse({ error: 'Message required' }, 400, origin)

    const mimoApiKey = Deno.env.get('MIMO_API_KEY') ?? Deno.env.get('GEMINI_API_KEY')
    if (!mimoApiKey) return fallbackResponse(mode, origin)

    const messages: Array<{ role: string; content: string }> = []
    let system = EPI_KNOWLEDGE

    // Inject compressed data context
    if (context) system += `\n\nبيانات حالية:\n${compress(context)}`

    // Template mode
    if (template && TEMPLATES[template]) {
      system += `\n\nمهمة: ${TEMPLATES[template]}`
    }

    // Special modes
    if (mode === 'suggestions') {
      system = `اقترح 5 اقتراحات متنوعة لمستخدم منصة مشرف EPI اليمن.
أنواع: سؤال تحليلي، طلب تقرير، نصيحة استخدام، اكتشاف مشكلة، سؤال عن التطعيمات.
صيغة: اقتراح واحد في سطر بدون ترقيم أو رموز.`
    }

    if (mode === 'report_templates') {
      system = `أرجع 8 قوالب تقارير لمنصة مشرف EPI.
JSON array: [{"id":"...","name":"...","description":"...","icon":"..."}]
قوالب: يومي، أسبوعي، محافظات، نواقص، جودة، مقارنة، تغطية تطعيم، أداء ميداني.`
    }

    // Help mode
    if (mode === 'guide') {
      system = EPI_KNOWLEDGE + `\n\nالمستخدم يسأل عن كيفية استخدام ميزة. اشرح بخطوات مختصرة (3-5 خطوات).`
    }

    // Contextual quick actions
    if (mode === 'quick_actions') {
      system = `اقترح 6 إجراءات سريعة بناءً على البيانات. كل إجراء: {"label":"...","icon":"...","action":"..."}.
JSON array. الإجراءات: تقرير، تحليل، فحص نواقص، مقارنة، تغطية، جودة.`
    }

    messages.push({ role: 'system', content: system })

    // Compressed history (last 6 = 3 turns)
    for (const msg of history.slice(-6)) {
      messages.push({
        role: msg.role === 'user' ? 'user' : 'assistant',
        content: String(msg.content).slice(0, 1200)
      })
    }

    messages.push({ role: 'user', content: message ?? template })

    const body = {
      model: MIMO_MODEL,
      messages,
      max_tokens: mode === 'suggestions' ? 300
        : mode === 'report_templates' ? 500
        : mode === 'quick_actions' ? 400
        : 800,
      temperature: mode === 'suggestions' ? 0.8 : 0.4,
      stream,
    }

    if (stream) return await handleStream(MIMO_API_URL, mimoApiKey, body, origin)

    const resp = await fetch(MIMO_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${mimoApiKey}` },
      body: JSON.stringify(body),
    })

    const result = await resp.json()
    if (!resp.ok) {
      console.error('MiMo error:', result)
      return jsonResponse({ reply: 'حدث خطأ. حاول مرة أخرى.' }, 200, origin)
    }

    const text = result.choices?.[0]?.message?.content ?? ''

    if (mode === 'suggestions') {
      return jsonResponse({ suggestions: text.split('\n').filter((s: string) => s.trim().length > 5).slice(0, 5) }, 200, origin)
    }

    if (mode === 'report_templates') {
      try { return jsonResponse({ templates: JSON.parse(text) }, 200, origin) }
      catch { return jsonResponse({ templates: defaultTemplates() }, 200, origin) }
    }

    if (mode === 'quick_actions') {
      try { return jsonResponse({ actions: JSON.parse(text) }, 200, origin) }
      catch { return jsonResponse({ actions: defaultQuickActions() }, 200, origin) }
    }

    return jsonResponse({ reply: text || 'عذراً، لم أتمكن من المعالجة.' }, 200, origin)

  } catch (error) {
    console.error('AI error:', error)
    return jsonResponse({ reply: 'حدث خطأ غير متوقع.' }, 500, origin)
  }
})

// ─── Helpers ──────────────────────────────────────────────

function compress(ctx: any): string {
  const s = ctx.submissions ?? {}, sh = ctx.shortages ?? {}
  const byS = s.byStatus ?? {}, bySev = sh.bySeverity ?? {}
  return [
    `إرسالات: كلي=${s.total} اليوم=${s.today}`,
    `حالات: ${Object.entries(byS).map(([k,v])=>`${k}=${v}`).join(' ')}`,
    `نواقص: كلي=${sh.total} محلول=${sh.resolved} معلق=${sh.pending}`,
    `خطورة: ${Object.entries(bySev).map(([k,v])=>`${k}=${v}`).join(' ')}`,
  ].join('\n')
}

function fallbackResponse(mode: string | undefined, origin: string | null) {
  if (mode === 'suggestions') return jsonResponse({ suggestions: [
    '📊 ما حالة الإرساليات اليوم؟', '⚠️ أين النواقص الحرجة؟',
    '📈 اعرض تقرير أسبوعي', '🗺️ أي المحافظات تحتاج دعم؟',
    '💉 ما تغطية التطعيم؟'
  ] }, 200, origin)
  if (mode === 'report_templates') return jsonResponse({ templates: defaultTemplates() }, 200, origin)
  if (mode === 'quick_actions') return jsonResponse({ actions: defaultQuickActions() }, 200, origin)
  return jsonResponse({ reply: 'خدمة AI غير مُعدّة. تواصل مع المدير.' }, 200, origin)
}

function defaultTemplates() {
  return [
    { id: 'daily', name: 'التقرير اليومي', description: 'ملخص شامل ليوم العمل', icon: '📅' },
    { id: 'weekly', name: 'التقرير الأسبوعي', description: 'تحليل اتجاه الأسبوع', icon: '📊' },
    { id: 'governorate', name: 'تقرير المحافظات', description: 'مقارنة أداء المحافظات', icon: '🗺️' },
    { id: 'shortages', name: 'تقرير النواقص', description: 'تحليل النواقص والحلول', icon: '⚠️' },
    { id: 'quality', name: 'تقرير جودة البيانات', description: 'اكتمال ودقة الإدخال', icon: '✅' },
    { id: 'comparison', name: 'تقرير مقارنة', description: 'مقارنة فترتين زمنيتين', icon: '🔄' },
    { id: 'coverage', name: 'تقرير التغطية', description: 'تغطية التطعيمات وفجوات', icon: '💉' },
    { id: 'field', name: 'تقييم الميدانيين', description: 'أداء المشرفين الميدانيين', icon: '👥' },
  ]
}

function defaultQuickActions() {
  return [
    { label: 'تقرير يومي', icon: '📅', action: 'daily_report' },
    { label: 'فحص النواقص', icon: '⚠️', action: 'check_shortages' },
    { label: 'تغطية التطعيم', icon: '💉', action: 'vaccination_coverage' },
    { label: 'أداء المحافظات', icon: '🗺️', action: 'governorate_performance' },
    { label: 'جودة الإدخال', icon: '✅', action: 'data_quality' },
    { label: 'اتجاه الأسبوع', icon: '📈', action: 'weekly_trend' },
  ]
}

async function handleStream(url: string, key: string, body: any, origin: string | null) {
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${key}` },
    body: JSON.stringify(body),
  })
  if (!resp.ok) return jsonResponse({ reply: 'خطأ في الخدمة.' }, 200, origin)

  const reader = resp.body?.getReader()
  if (!reader) return jsonResponse({ error: 'Stream unavailable' }, 500, origin)

  const { readable, writable } = new TransformStream()
  const writer = writable.getWriter()
  const enc = new TextEncoder()
  const dec = new TextDecoder()

  ;(async () => {
    try {
      let buf = ''
      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        buf += dec.decode(value, { stream: true })
        const lines = buf.split('\n')
        buf = lines.pop() ?? ''
        for (const line of lines) {
          const t = line.trim()
          if (!t.startsWith('data: ')) continue
          const d = t.slice(6)
          if (d === '[DONE]') { await writer.write(enc.encode('data: [DONE]\n\n')); continue }
          try {
            const p = JSON.parse(d)
            const text = p.choices?.[0]?.delta?.content
            if (text) await writer.write(enc.encode(`data: ${JSON.stringify({ text })}\n\n`))
          } catch {}
        }
      }
      await writer.write(enc.encode('data: [DONE]\n\n'))
    } catch (e) { console.error('Stream:', e) }
    finally { await writer.close() }
  })()

  return new Response(readable, {
    status: 200,
    headers: { ...corsHeaders(origin), 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' },
  })
}
