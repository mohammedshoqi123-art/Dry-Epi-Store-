import { useState } from 'react'
import {
  Sparkles, Brain, Key, Settings, Shield, Zap, Activity,
  Save, Eye, EyeOff, TestTube, CheckCircle2, XCircle,
  FileText, Upload, Download, RefreshCw, AlertTriangle,
  MessageSquare, BarChart3, Target, Clock, DollarSign,
  Sliders, BookOpen, Wand2, Gauge, Thermometer, Cpu
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs'
import { Progress } from '@/components/ui/progress'
import { Skeleton } from '@/components/ui/skeleton'
import { Header } from '@/components/layout/header'
import { cn } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'

// ═══════════════════════════════════════
// Types
// ═══════════════════════════════════════

interface AIProviderConfig {
  provider: string
  apiKey: string
  model: string
  temperature: number
  maxTokens: number
  systemPrompt: string
}

interface AIFeatureToggle {
  id: string
  label: string
  description: string
  enabled: boolean
  icon: React.ElementType
}

interface PromptTemplate {
  id: string
  name: string
  description: string
  prompt: string
  category: string
  isBuiltIn: boolean
}

// ═══════════════════════════════════════
// Default Data
// ═══════════════════════════════════════

const defaultProviderConfig: AIProviderConfig = {
  provider: 'gemini',
  apiKey: '',
  model: 'gemini-2.0-flash',
  temperature: 0.7,
  maxTokens: 4096,
  systemPrompt: `أنت مساعد ذكي متخصص في برنامج الرصد الوبائي (EPI).
 תפקידك مساعدة المشرفين في تحليل البيانات، اكتشاف النواقص، وتقديم توصيات مبنية على أفضل ممارسات منظمة الصحة العالمية.
 يجب عليك الرد بالعربية ما لم يُطلب منك غير ذلك.
 قدم إجابات دقيقة ومفصلة مع إحالات إلى المعايير الصحية المعتمدة.`,
}

const defaultFeatures: AIFeatureToggle[] = [
  { id: 'form_analysis', label: 'تحليل النماذج', description: 'تحليل ذكي لإجابات النماذج واكتشاف الأنماط', enabled: true, icon: FileText },
  { id: 'submission_review', label: 'مراجعة الإرساليات', description: 'اقتراحات ذكية لمراجعة الإرساليات المرسلة', enabled: true, icon: CheckCircle2 },
  { id: 'shortage_prediction', label: 'توقع النواقص', description: 'توقع النواقص المستقبلية بناءً على البيانات التاريخية', enabled: true, icon: AlertTriangle },
  { id: 'report_generation', label: 'إنتاج التقارير', description: 'إنشاء تقارير تحليلية تلقائياً', enabled: true, icon: BarChart3 },
  { id: 'chat_assistant', label: 'مساعد المحادثة', description: 'الرد على استفسارات المستخدمين في الشات', enabled: true, icon: MessageSquare },
  { id: 'anomaly_detection', label: 'اكتشاف الشذوذ', description: 'اكتشاف البيانات غير الطبيعية تلقائياً', enabled: false, icon: Target },
  { id: 'auto_categorization', label: 'التصنيف التلقائي', description: 'تصنيف الإرساليات والنواقص تلقائياً', enabled: false, icon: Wand2 },
  { id: 'smart_notifications', label: 'الإشعارات الذكية', description: 'إرسال إشعارات ذكية بناءً على الأولوية', enabled: true, icon: Zap },
]

const defaultTemplates: PromptTemplate[] = [
  {
    id: 'analyze-form',
    name: 'تحليل نموذج',
    description: 'تحليل شامل لإجابات نموذج معين',
    prompt: 'قم بتحليل إجابات النموذج التالي واكتشف الأنماط والاتجاهات: [DATA]',
    category: 'تحليل',
    isBuiltIn: true,
  },
  {
    id: 'shortage-report',
    name: 'تقرير النواقص',
    description: 'إنتاج تقرير عن النواقص الحالية',
    prompt: 'أنشئ تقريراً مفصلاً عن النواقص الحالية مع التوصيات: [DATA]',
    category: 'تقارير',
    isBuiltIn: true,
  },
  {
    id: 'submission-review',
    name: 'مراجعة إرسالية',
    description: 'مراجعة إرسالية وتحديد المشاكل المحتملة',
    prompt: 'راجع الإرسالية التالية وحدد أي مشاكل أو أخطاء محتملة: [DATA]',
    category: 'مراجعة',
    isBuiltIn: true,
  },
  {
    id: 'weekly-summary',
    name: 'ملخص أسبوعي',
    description: 'إنتاج ملخص أسبوعي للنشاط',
    prompt: 'أنشئ ملخصاً أسبوعياً يوضح الإنجازات والتحديات والتوصيات: [DATA]',
    category: 'تقارير',
    isBuiltIn: true,
  },
  {
    id: 'gov-comparison',
    name: 'مقارنة المحافظات',
    description: 'مقارنة أداء المحافظات',
    prompt: 'قارن أداء المحافظات التالية وحدد نقاط القوة والضعف: [DATA]',
    category: 'تحليل',
    isBuiltIn: true,
  },
]

// ═══════════════════════════════════════
// Main Component
// ═══════════════════════════════════════

export default function AISettingsPage() {
  const { toast } = useToast()
  const [activeTab, setActiveTab] = useState('provider')
  const [showApiKey, setShowApiKey] = useState(false)
  const [testing, setTesting] = useState(false)
  const [testResult, setTestResult] = useState<'success' | 'error' | null>(null)
  const [saved, setSaved] = useState(false)

  // Provider config state
  const [config, setConfig] = useState<AIProviderConfig>(defaultProviderConfig)

  // Features state
  const [features, setFeatures] = useState<AIFeatureToggle[]>(defaultFeatures)

  // Behavior settings
  const [responseLanguage, setResponseLanguage] = useState('ar')
  const [responseStyle, setResponseStyle] = useState('formal')
  const [confidenceThreshold, setConfidenceThreshold] = useState(70)
  const [autoAction, setAutoAction] = useState(false)

  // Templates state
  const [templates, setTemplates] = useState<PromptTemplate[]>(defaultTemplates)
  const [editingTemplate, setEditingTemplate] = useState<PromptTemplate | null>(null)

  // Usage stats (mock)
  const usageStats = {
    callsToday: 142,
    callsMonth: 3847,
    costEstimate: '$12.45',
    avgResponseTime: '1.2s',
    errorRate: 0.3,
    tokensUsed: 284500,
    tokensLimit: 1000000,
  }

  const handleSave = () => {
    setSaved(true)
    toast({ title: 'تم حفظ إعدادات الذكاء الاصطناعي', variant: 'success' })
    setTimeout(() => setSaved(false), 3000)
  }

  const handleTestConnection = async () => {
    setTesting(true)
    setTestResult(null)
    // Simulate API test
    await new Promise(resolve => setTimeout(resolve, 2000))
    setTestResult(config.apiKey.length > 10 ? 'success' : 'error')
    setTesting(false)
    if (config.apiKey.length > 10) {
      toast({ title: 'تم الاتصال بنجاح ✅', variant: 'success' })
    } else {
      toast({ title: 'فشل الاتصال — تحقق من مفتاح API', variant: 'destructive' })
    }
  }

  const toggleFeature = (id: string) => {
    setFeatures(features.map(f => f.id === id ? { ...f, enabled: !f.enabled } : f))
  }

  return (
    <div className="page-enter">
      <Header
        title="إعدادات الذكاء الاصطناعي"
        subtitle="تكوين نظام AI المدمج — MiMo / Gemini"
        onRefresh={() => {}}
      />

      <div className="p-6">
        <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
          <TabsList className="bg-muted/50 p-1">
            <TabsTrigger value="provider" className="gap-2">
              <Key className="w-4 h-4" />
              مزود الخدمة
            </TabsTrigger>
            <TabsTrigger value="features" className="gap-2">
              <Zap className="w-4 h-4" />
              الميزات
            </TabsTrigger>
            <TabsTrigger value="behavior" className="gap-2">
              <Sliders className="w-4 h-4" />
              السلوك
            </TabsTrigger>
            <TabsTrigger value="prompts" className="gap-2">
              <BookOpen className="w-4 h-4" />
              قوالب الأوامر
            </TabsTrigger>
            <TabsTrigger value="usage" className="gap-2">
              <Activity className="w-4 h-4" />
              الاستخدام
            </TabsTrigger>
          </TabsList>

          {/* ═══ Provider Configuration ═══ */}
          <TabsContent value="provider" className="space-y-6 animate-fade-in">
            <Card>
              <CardHeader>
                <CardTitle className="font-heading flex items-center gap-2">
                  <Key className="w-5 h-5 text-primary" />
                  تكوين مزود الذكاء الاصطناعي
                </CardTitle>
                <CardDescription>إعدادات الاتصال بنموذج الذكاء الاصطناعي</CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Provider Selection */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {[
                    { id: 'gemini', label: 'Google Gemini', desc: 'نموذج جوجل المتقدم', icon: '🔮', badge: 'موصى به' },
                    { id: 'local', label: 'MiMo Local', desc: 'نموذج محلي بدون إنترنت', icon: '🏠', badge: 'خصوصية' },
                    { id: 'openai', label: 'OpenAI GPT', desc: 'نموذج OpenAI', icon: '🤖', badge: null },
                  ].map((p) => (
                    <button
                      key={p.id}
                      onClick={() => setConfig({ ...config, provider: p.id })}
                      className={cn(
                        'p-4 rounded-xl border-2 text-right transition-all relative',
                        config.provider === p.id
                          ? 'border-primary bg-primary/5 shadow-md'
                          : 'border-border hover:border-primary/30 hover:shadow-sm'
                      )}
                    >
                      {p.badge && (
                        <Badge className="absolute top-2 left-2 text-[9px]" variant="secondary">{p.badge}</Badge>
                      )}
                      <span className="text-3xl block mb-2">{p.icon}</span>
                      <p className="font-bold text-sm">{p.label}</p>
                      <p className="text-xs text-muted-foreground mt-0.5">{p.desc}</p>
                    </button>
                  ))}
                </div>

                <Separator />

                {/* API Key */}
                <div className="space-y-2">
                  <Label className="flex items-center gap-2">
                    <Shield className="w-4 h-4 text-muted-foreground" />
                    مفتاح API
                  </Label>
                  <div className="flex gap-2">
                    <div className="relative flex-1">
                      <Input
                        type={showApiKey ? 'text' : 'password'}
                        value={config.apiKey}
                        onChange={(e) => setConfig({ ...config, apiKey: e.target.value })}
                        placeholder="أدخل مفتاح API..."
                        dir="ltr"
                        className="pl-10"
                      />
                      <button
                        onClick={() => setShowApiKey(!showApiKey)}
                        className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                      >
                        {showApiKey ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                    <Button
                      variant="outline"
                      onClick={handleTestConnection}
                      disabled={testing || !config.apiKey}
                      className="gap-2 shrink-0"
                    >
                      {testing ? (
                        <RefreshCw className="w-4 h-4 animate-spin" />
                      ) : testResult === 'success' ? (
                        <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                      ) : testResult === 'error' ? (
                        <XCircle className="w-4 h-4 text-red-600" />
                      ) : (
                        <TestTube className="w-4 h-4" />
                      )}
                      اختبار الاتصال
                    </Button>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    🔒 المفتاح مخزن بشكل آمن ولن يُعرض في التقارير
                  </p>
                </div>

                {/* Model & Parameters */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  <div className="space-y-2">
                    <Label>النموذج</Label>
                    <Select value={config.model} onValueChange={(v) => setConfig({ ...config, model: v })}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {config.provider === 'gemini' && (
                          <>
                            <SelectItem value="gemini-2.0-flash">Gemini 2.0 Flash</SelectItem>
                            <SelectItem value="gemini-1.5-pro">Gemini 1.5 Pro</SelectItem>
                            <SelectItem value="gemini-1.5-flash">Gemini 1.5 Flash</SelectItem>
                          </>
                        )}
                        {config.provider === 'local' && (
                          <>
                            <SelectItem value="mimo-v2-pro">MiMo V2 Pro</SelectItem>
                            <SelectItem value="mimo-v2-lite">MiMo V2 Lite</SelectItem>
                          </>
                        )}
                        {config.provider === 'openai' && (
                          <>
                            <SelectItem value="gpt-4o">GPT-4o</SelectItem>
                            <SelectItem value="gpt-4o-mini">GPT-4o Mini</SelectItem>
                            <SelectItem value="gpt-3.5-turbo">GPT-3.5 Turbo</SelectItem>
                          </>
                        )}
                      </SelectContent>
                    </Select>
                  </div>

                  <div className="space-y-2">
                    <Label className="flex items-center gap-2">
                      <Thermometer className="w-4 h-4" />
                      درجة الحرارة: {config.temperature}
                    </Label>
                    <input
                      type="range"
                      min="0"
                      max="2"
                      step="0.1"
                      value={config.temperature}
                      onChange={(e) => setConfig({ ...config, temperature: parseFloat(e.target.value) })}
                      className="w-full accent-primary"
                    />
                    <div className="flex justify-between text-[10px] text-muted-foreground">
                      <span>دقيق ومحدد</span>
                      <span>متوازن</span>
                      <span>إبداعي</span>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <Label>الحد الأقصى للرموز</Label>
                    <Input
                      type="number"
                      value={config.maxTokens}
                      onChange={(e) => setConfig({ ...config, maxTokens: parseInt(e.target.value) || 4096 })}
                      min={256}
                      max={16384}
                    />
                    <p className="text-[10px] text-muted-foreground">بين 256 و 16,384 رمز</p>
                  </div>
                </div>

                <Separator />

                {/* System Prompt */}
                <div className="space-y-2">
                  <Label className="flex items-center gap-2">
                    <Cpu className="w-4 h-4 text-muted-foreground" />
                    أمر النظام (System Prompt)
                  </Label>
                  <textarea
                    value={config.systemPrompt}
                    onChange={(e) => setConfig({ ...config, systemPrompt: e.target.value })}
                    className="w-full h-40 p-4 rounded-xl border bg-muted/30 text-sm font-mono resize-y focus:outline-none focus:ring-2 focus:ring-primary/30"
                    dir="rtl"
                    placeholder="اكتب أمر النظام الذي يحدد سلوك الذكاء الاصطناعي..."
                  />
                  <div className="flex items-center justify-between">
                    <p className="text-xs text-muted-foreground">
                      {config.systemPrompt.length} حرف
                    </p>
                    <Button variant="ghost" size="sm" onClick={() => setConfig({ ...config, systemPrompt: defaultProviderConfig.systemPrompt })}>
                      استعادة الافتراضي
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* ═══ Features Toggle ═══ */}
          <TabsContent value="features" className="space-y-6 animate-fade-in">
            <Card>
              <CardHeader>
                <CardTitle className="font-heading flex items-center gap-2">
                  <Zap className="w-5 h-5 text-amber-500" />
                  ميزات الذكاء الاصطناعي
                </CardTitle>
                <CardDescription>تفعيل أو تعطيل ميزات AI في النظام</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {features.map((feature) => {
                    const Icon = feature.icon
                    return (
                      <div
                        key={feature.id}
                        className={cn(
                          'p-4 rounded-xl border-2 transition-all',
                          feature.enabled
                            ? 'border-primary/30 bg-primary/5'
                            : 'border-border bg-muted/30 opacity-60'
                        )}
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex items-start gap-3">
                            <div className={cn(
                              'p-2 rounded-lg',
                              feature.enabled ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground'
                            )}>
                              <Icon className="w-5 h-5" />
                            </div>
                            <div>
                              <h4 className="font-bold text-sm">{feature.label}</h4>
                              <p className="text-xs text-muted-foreground mt-0.5">{feature.description}</p>
                            </div>
                          </div>
                          <Switch
                            checked={feature.enabled}
                            onCheckedChange={() => toggleFeature(feature.id)}
                          />
                        </div>
                      </div>
                    )
                  })}
                </div>
              </CardContent>
            </Card>

            {/* Quick Actions */}
            <Card>
              <CardHeader>
                <CardTitle className="text-base font-heading">إجراءات سريعة</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-wrap gap-3">
                <Button variant="outline" className="gap-2" onClick={() => setFeatures(features.map(f => ({ ...f, enabled: true })))}>
                  <CheckCircle2 className="w-4 h-4" />
                  تفعيل الكل
                </Button>
                <Button variant="outline" className="gap-2" onClick={() => setFeatures(features.map(f => ({ ...f, enabled: false })))}>
                  <XCircle className="w-4 h-4" />
                  تعطيل الكل
                </Button>
                <Button variant="outline" className="gap-2">
                  <RefreshCw className="w-4 h-4" />
                  استعادة الافتراضي
                </Button>
              </CardContent>
            </Card>
          </TabsContent>

          {/* ═══ Behavior Settings ═══ */}
          <TabsContent value="behavior" className="space-y-6 animate-fade-in">
            <Card>
              <CardHeader>
                <CardTitle className="font-heading flex items-center gap-2">
                  <Sliders className="w-5 h-5 text-purple-500" />
                  سلوك الذكاء الاصطناعي
                </CardTitle>
                <CardDescription>تحكم في طريقة ردود وتفاعلات النظام الذكي</CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {/* Language */}
                  <div className="space-y-2">
                    <Label>لغة الرد</Label>
                    <Select value={responseLanguage} onValueChange={setResponseLanguage}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="ar">العربية</SelectItem>
                        <SelectItem value="en">English</SelectItem>
                        <SelectItem value="auto">تلقائي (حسب لغة السؤال)</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  {/* Style */}
                  <div className="space-y-2">
                    <Label>أسلوب الرد</Label>
                    <Select value={responseStyle} onValueChange={setResponseStyle}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="formal">رسمي</SelectItem>
                        <SelectItem value="casual">ودّي</SelectItem>
                        <SelectItem value="technical">تقني</SelectItem>
                        <SelectItem value="concise">مختصر</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                <Separator />

                {/* Confidence Threshold */}
                <div className="space-y-3">
                  <Label className="flex items-center gap-2">
                    <Gauge className="w-4 h-4" />
                    عتبة الثقة: {confidenceThreshold}%
                  </Label>
                  <input
                    type="range"
                    min="0"
                    max="100"
                    step="5"
                    value={confidenceThreshold}
                    onChange={(e) => setConfidenceThreshold(parseInt(e.target.value))}
                    className="w-full accent-primary"
                  />
                  <div className="flex justify-between text-[10px] text-muted-foreground">
                    <span>مغامر (0%)</span>
                    <span>متوازن (50%)</span>
                    <span>حذر (100%)</span>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    الإجابات أقل من هذه العتبة ستُعلَّم بأنها "غير مؤكدة"
                  </p>
                </div>

                <Separator />

                {/* Auto Action */}
                <div className="flex items-center justify-between p-4 rounded-xl border">
                  <div className="flex items-center gap-3">
                    <div className="p-2 rounded-lg bg-amber-50">
                      <Wand2 className="w-5 h-5 text-amber-600" />
                    </div>
                    <div>
                      <p className="font-medium text-sm">التنفيذ التلقائي</p>
                      <p className="text-xs text-muted-foreground">
                        السماح للذكاء الاصطناعي بتنفيذ إجراءات مباشرة بدون تأكيد
                      </p>
                    </div>
                  </div>
                  <Switch checked={autoAction} onCheckedChange={setAutoAction} />
                </div>

                {autoAction && (
                  <div className="p-4 rounded-xl bg-amber-50 border border-amber-200 animate-fade-in">
                    <div className="flex items-start gap-2">
                      <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
                      <div>
                        <p className="text-sm font-medium text-amber-800">تحذير</p>
                        <p className="text-xs text-amber-700 mt-1">
                          تفعيل هذه الميزة يسمح للذكاء الاصطناعي باتخاذ إجراءات مباشرة مثل تحديث حالة الإرساليات أو إرسال إشعارات. استخدم بحذر.
                        </p>
                      </div>
                    </div>
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* ═══ Prompt Templates ═══ */}
          <TabsContent value="prompts" className="space-y-6 animate-fade-in">
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle className="font-heading flex items-center gap-2">
                      <BookOpen className="w-5 h-5 text-emerald-500" />
                      قوالب الأوامر
                    </CardTitle>
                    <CardDescription>أوامر مُعرّفة مسبقاً للمهام الشائعة</CardDescription>
                  </div>
                  <Button className="gap-2" onClick={() => {
                    const newTemplate: PromptTemplate = {
                      id: `custom-${Date.now()}`,
                      name: 'قالب جديد',
                      description: 'وصف القالب',
                      prompt: 'اكتب الأمر هنا... [DATA]',
                      category: 'مخصص',
                      isBuiltIn: false,
                    }
                    setTemplates([...templates, newTemplate])
                    setEditingTemplate(newTemplate)
                  }}>
                    <Sparkles className="w-4 h-4" />
                    قالب جديد
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {templates.map((template) => (
                    <div
                      key={template.id}
                      className={cn(
                        'p-4 rounded-xl border transition-all hover:shadow-sm',
                        editingTemplate?.id === template.id ? 'border-primary bg-primary/5' : 'border-border'
                      )}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="flex-1">
                          <div className="flex items-center gap-2 mb-1">
                            <h4 className="font-bold text-sm">{template.name}</h4>
                            <Badge variant="outline" className="text-[9px]">{template.category}</Badge>
                            {template.isBuiltIn && (
                              <Badge variant="secondary" className="text-[9px]">内置</Badge>
                            )}
                          </div>
                          <p className="text-xs text-muted-foreground">{template.description}</p>

                          {editingTemplate?.id === template.id && (
                            <div className="mt-3 space-y-3 animate-fade-in">
                              <div className="grid grid-cols-2 gap-3">
                                <Input
                                  value={editingTemplate.name}
                                  onChange={(e) => setEditingTemplate({ ...editingTemplate, name: e.target.value })}
                                  placeholder="اسم القالب"
                                />
                                <Input
                                  value={editingTemplate.category}
                                  onChange={(e) => setEditingTemplate({ ...editingTemplate, category: e.target.value })}
                                  placeholder="التصنيف"
                                />
                              </div>
                              <Input
                                value={editingTemplate.description}
                                onChange={(e) => setEditingTemplate({ ...editingTemplate, description: e.target.value })}
                                placeholder="الوصف"
                              />
                              <textarea
                                value={editingTemplate.prompt}
                                onChange={(e) => setEditingTemplate({ ...editingTemplate, prompt: e.target.value })}
                                className="w-full h-24 p-3 rounded-lg border bg-background text-sm font-mono resize-y focus:outline-none focus:ring-2 focus:ring-primary/30"
                                dir="rtl"
                                placeholder="اكتب الأمر..."
                              />
                              <div className="flex gap-2">
                                <Button size="sm" onClick={() => {
                                  setTemplates(templates.map(t => t.id === editingTemplate.id ? editingTemplate : t))
                                  setEditingTemplate(null)
                                  toast({ title: 'تم حفظ القالب', variant: 'success' })
                                }}>
                                  حفظ
                                </Button>
                                <Button size="sm" variant="outline" onClick={() => setEditingTemplate(null)}>
                                  إلغاء
                                </Button>
                              </div>
                            </div>
                          )}
                        </div>

                        {editingTemplate?.id !== template.id && (
                          <div className="flex gap-1 shrink-0">
                            <Button variant="ghost" size="icon-sm" onClick={() => setEditingTemplate(template)}>
                              <Settings className="w-4 h-4" />
                            </Button>
                            {!template.isBuiltIn && (
                              <Button
                                variant="ghost"
                                size="icon-sm"
                                className="text-red-500 hover:text-red-700"
                                onClick={() => {
                                  setTemplates(templates.filter(t => t.id !== template.id))
                                  toast({ title: 'تم حذف القالب', variant: 'success' })
                                }}
                              >
                                <XCircle className="w-4 h-4" />
                              </Button>
                            )}
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* ═══ Usage & Monitoring ═══ */}
          <TabsContent value="usage" className="space-y-6 animate-fade-in">
            {/* Usage Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <Card>
                <CardContent className="p-4 text-center">
                  <div className="p-2 rounded-lg bg-blue-50 w-fit mx-auto mb-2">
                    <Activity className="w-5 h-5 text-blue-600" />
                  </div>
                  <p className="text-2xl font-heading font-bold text-blue-600">{usageStats.callsToday}</p>
                  <p className="text-xs text-muted-foreground">استدعاء اليوم</p>
                </CardContent>
              </Card>
              <Card>
                <CardContent className="p-4 text-center">
                  <div className="p-2 rounded-lg bg-emerald-50 w-fit mx-auto mb-2">
                    <BarChart3 className="w-5 h-5 text-emerald-600" />
                  </div>
                  <p className="text-2xl font-heading font-bold text-emerald-600">{usageStats.callsMonth.toLocaleString()}</p>
                  <p className="text-xs text-muted-foreground">استدعاء هذا الشهر</p>
                </CardContent>
              </Card>
              <Card>
                <CardContent className="p-4 text-center">
                  <div className="p-2 rounded-lg bg-amber-50 w-fit mx-auto mb-2">
                    <DollarSign className="w-5 h-5 text-amber-600" />
                  </div>
                  <p className="text-2xl font-heading font-bold text-amber-600">{usageStats.costEstimate}</p>
                  <p className="text-xs text-muted-foreground">التكلفة المقدرة</p>
                </CardContent>
              </Card>
              <Card>
                <CardContent className="p-4 text-center">
                  <div className="p-2 rounded-lg bg-purple-50 w-fit mx-auto mb-2">
                    <Clock className="w-5 h-5 text-purple-600" />
                  </div>
                  <p className="text-2xl font-heading font-bold text-purple-600">{usageStats.avgResponseTime}</p>
                  <p className="text-xs text-muted-foreground">متوسط الاستجابة</p>
                </CardContent>
              </Card>
            </div>

            {/* Token Usage */}
            <Card>
              <CardHeader>
                <CardTitle className="text-base font-heading">استهلاك الرموز</CardTitle>
                <CardDescription>{usageStats.tokensUsed.toLocaleString()} / {usageStats.tokensLimit.toLocaleString()} رمز</CardDescription>
              </CardHeader>
              <CardContent>
                <Progress value={(usageStats.tokensUsed / usageStats.tokensLimit) * 100} className="h-3" />
                <div className="flex justify-between mt-2 text-xs text-muted-foreground">
                  <span>{((usageStats.tokensUsed / usageStats.tokensLimit) * 100).toFixed(1)}% مستخدم</span>
                  <span>{(usageStats.tokensLimit - usageStats.tokensUsed).toLocaleString()} متبقي</span>
                </div>
              </CardContent>
            </Card>

            {/* System Health */}
            <Card>
              <CardHeader>
                <CardTitle className="text-base font-heading">صحة النظام</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-sm">معدل الخطأ</span>
                  <div className="flex items-center gap-2">
                    <Progress value={usageStats.errorRate} className="w-24 h-2" />
                    <span className={cn(
                      'text-xs font-mono',
                      usageStats.errorRate < 1 ? 'text-emerald-600' : usageStats.errorRate < 5 ? 'text-amber-600' : 'text-red-600'
                    )}>
                      {usageStats.errorRate}%
                    </span>
                  </div>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm">حالة الاتصال</span>
                  <Badge variant="success" className="gap-1">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                    متصل
                  </Badge>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm">آخر استدعاء</span>
                  <span className="text-xs text-muted-foreground">منذ 3 دقائق</span>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>

        {/* Save Button */}
        <div className="flex items-center justify-end gap-3 mt-6 pt-6 border-t">
          {saved && (
            <div className="flex items-center gap-2 text-emerald-600 animate-fade-in">
              <CheckCircle2 className="w-4 h-4" />
              <span className="text-sm">تم الحفظ بنجاح</span>
            </div>
          )}
          <Button onClick={handleSave} className="gap-2">
            <Save className="w-4 h-4" />
            حفظ الإعدادات
          </Button>
        </div>
      </div>
    </div>
  )
}
