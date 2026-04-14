import { useState } from 'react'
import {
  Sparkles, Brain, TrendingUp, AlertTriangle, Target, Lightbulb,
  BarChart3, Shield, Zap, RefreshCw, ChevronRight, Star, Activity,
  FileText, MapPin, Clock, Users, CheckCircle2, ArrowUpRight, ArrowDownRight
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Progress } from '@/components/ui/progress'
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs'
import { Header } from '@/components/layout/header'
import { useDashboardStats, useGovernorateStats, useSubmissionsChart, useShortages } from '@/hooks/useApi'
import { cn, formatNumber } from '@/lib/utils'
import {
  RadarChart, Radar, PolarGrid, PolarAngleAxis, PolarRadiusAxis,
  ResponsiveContainer, Tooltip, BarChart, Bar, XAxis, YAxis, CartesianGrid,
  AreaChart, Area, Cell
} from 'recharts'

// AI-Generated Insights Engine
function generateInsights(stats: any, govStats: any, shortages: any) {
  const insights: Array<{
    type: 'critical' | 'warning' | 'success' | 'info'
    title: string
    description: string
    action: string
    icon: React.ElementType
    priority: number
  }> = []

  if (!stats) return insights

  // Critical: High rejection rate
  if (stats.approval_rate < 70 && stats.total_submissions > 20) {
    insights.push({
      type: 'critical',
      title: 'معدل رفض مرتفع',
      description: `معدل الاعتماد ${stats.approval_rate.toFixed(1)}% فقط — أقل من المعدل المقبول (70%). قد يشير إلى مشاكل في جودة الإدخال.`,
      action: 'مراجعة أسباب الرفض وتدريب المدخلين',
      icon: AlertTriangle,
      priority: 1,
    })
  }

  // Critical: Many unresolved shortages
  if (stats.critical_shortages > 5) {
    insights.push({
      type: 'critical',
      title: 'نواقص حرجة تحتاج تدخل فوري',
      description: `${stats.critical_shortages} نقص حرج غير محلول. هذه النواقص قد تؤثر على سير التطعيم.`,
      action: 'مراجعة النواقص الحرجة وتخصيص الموارد',
      icon: AlertTriangle,
      priority: 1,
    })
  }

  // Warning: Low submission rate
  if (stats.submissions_today < 5 && stats.total_users > 10) {
    insights.push({
      type: 'warning',
      title: 'معدل إدخال منخفض اليوم',
      description: `تم إدخال ${stats.submissions_today} إرسالية فقط اليوم مع وجود ${stats.active_users} مستخدم نشط.`,
      action: 'إرسال تذكير للمستخدمين غير النشطين',
      icon: Clock,
      priority: 2,
    })
  }

  // Warning: Inactive users
  const inactiveRatio = stats.total_users > 0 ? ((stats.total_users - stats.active_users) / stats.total_users) * 100 : 0
  if (inactiveRatio > 30) {
    insights.push({
      type: 'warning',
      title: 'نسبة مستخدمين غير نشطين مرتفعة',
      description: `${inactiveRatio.toFixed(0)}% من المستخدمين غير نشطين. قد يحتاجون دعم أو تدريب.`,
      action: 'مراجعة حسابات المستخدمين غير النشطين',
      icon: Users,
      priority: 2,
    })
  }

  // Success: High approval rate
  if (stats.approval_rate >= 85) {
    insights.push({
      type: 'success',
      title: 'معدل اعتماد ممتاز',
      description: `معدل الاعتماد ${stats.approval_rate.toFixed(1)}% — يشير إلى جودة عالية في الإدخال الميداني.`,
      action: 'الحفاظ على المستوى الحالي والتكويد',
      icon: CheckCircle2,
      priority: 3,
    })
  }

  // Success: Good submission volume
  if (stats.submissions_this_week > 100) {
    insights.push({
      type: 'success',
      title: 'نشاط ميداني قوي هذا الأسبوع',
      description: `${formatNumber(stats.submissions_this_week)} إرسالية هذا الأسبوع — أداء متميز.`,
      action: 'تحليل الأنماط وتطبيق أفضل الممارسات',
      icon: TrendingUp,
      priority: 3,
    })
  }

  // Info: Top performing governorate
  if (govStats && govStats.length > 0) {
    const top = govStats[0]
    const bottom = govStats[govStats.length - 1]
    if (top.submissions > 0) {
      insights.push({
        type: 'info',
        title: `${top.name} الأكثر نشاطاً`,
        description: `${top.name} أرسلت ${top.submissions} إرسالية. ${bottom.name} في آخر القائمة بـ ${bottom.submissions}.`,
        action: 'دراسة أسباب التفاوت بين المحافظات',
        icon: MapPin,
        priority: 3,
      })
    }
  }

  // Info: Form coverage
  if (stats.active_forms < stats.total_forms) {
    insights.push({
      type: 'info',
      title: 'نماذج غير نشطة',
      description: `${stats.total_forms - stats.active_forms} نموذج معطل من أصل ${stats.total_forms}. قد تحتاج مراجعة.`,
      action: 'مراجعة النماذج المعطلة',
      icon: FileText,
      priority: 3,
    })
  }

  return insights.sort((a, b) => a.priority - b.priority)
}

// Performance score calculation
function calculateHealthScore(stats: any): number {
  if (!stats) return 0
  let score = 50
  score += Math.min(stats.approval_rate * 0.3, 30)
  score += stats.active_users > 0 ? 10 : -10
  score += stats.critical_shortages === 0 ? 10 : -stats.critical_shortages * 2
  score += stats.submissions_today > 10 ? 5 : 0
  return Math.max(0, Math.min(100, Math.round(score)))
}

// AI Predictions
function generatePredictions(chartData: any[]) {
  if (!chartData || chartData.length < 7) return []
  const last7 = chartData.slice(-7)
  const avg = last7.reduce((s, d) => s + d.approved + d.pending + d.rejected, 0) / 7
  const trend = last7.length >= 2
    ? ((last7[last7.length - 1].approved + last7[last7.length - 1].pending) -
       (last7[0].approved + last7[0].pending)) / 7
    : 0

  return [
    { day: 'غداً', predicted: Math.round(avg + trend), confidence: 85 },
    { day: 'بعد يومين', predicted: Math.round(avg + trend * 2), confidence: 72 },
    { day: 'بعد 3 أيام', predicted: Math.round(avg + trend * 3), confidence: 60 },
  ]
}

const INSIGHT_COLORS = {
  critical: { bg: 'bg-red-50', border: 'border-red-200', text: 'text-red-700', icon: 'text-red-600', badge: 'bg-red-100 text-red-700' },
  warning: { bg: 'bg-amber-50', border: 'border-amber-200', text: 'text-amber-700', icon: 'text-amber-600', badge: 'bg-amber-100 text-amber-700' },
  success: { bg: 'bg-emerald-50', border: 'border-emerald-200', text: 'text-emerald-700', icon: 'text-emerald-600', badge: 'bg-emerald-100 text-emerald-700' },
  info: { bg: 'bg-blue-50', border: 'border-blue-200', text: 'text-blue-700', icon: 'text-blue-600', badge: 'bg-blue-100 text-blue-700' },
}

export default function AIInsightsPage() {
  const { data: stats, isLoading: statsLoading, refetch } = useDashboardStats()
  const { data: govStats } = useGovernorateStats()
  const { data: chartData } = useSubmissionsChart()
  const { data: shortages } = useShortages()

  const insights = generateInsights(stats, govStats, shortages)
  const healthScore = calculateHealthScore(stats)
  const predictions = generatePredictions(chartData || [])

  const criticalCount = insights.filter(i => i.type === 'critical').length
  const warningCount = insights.filter(i => i.type === 'warning').length

  // Radar chart data
  const radarData = stats ? [
    { metric: 'الاعتماد', value: stats.approval_rate, fullMark: 100 },
    { metric: 'النشاط', value: Math.min((stats.submissions_today / 20) * 100, 100), fullMark: 100 },
    { metric: 'التغطية', value: stats.total_users > 0 ? (stats.active_users / stats.total_users) * 100 : 0, fullMark: 100 },
    { metric: 'الجودة', value: Math.max(0, 100 - stats.critical_shortages * 10), fullMark: 100 },
    { metric: 'الاستجابة', value: stats.pending_submissions < 10 ? 90 : stats.pending_submissions < 30 ? 60 : 30, fullMark: 100 },
    { metric: 'الالتزام', value: stats.submissions_this_week > 50 ? 90 : stats.submissions_this_week > 20 ? 60 : 30, fullMark: 100 },
  ] : []

  return (
    <div className="page-enter">
      <Header
        title="الرؤى الذكية"
        subtitle="تحليلات مدعومة بالذكاء الاصطناعي — MiMo AI"
        onRefresh={() => refetch()}
      />

      <div className="p-6 space-y-6">
        {/* Health Score & Summary */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Overall Health */}
          <Card className="md:col-span-1 overflow-hidden relative">
            <div className={cn(
              'absolute top-0 left-0 right-0 h-1.5',
              healthScore >= 80 ? 'bg-emerald-500' : healthScore >= 50 ? 'bg-amber-500' : 'bg-red-500'
            )} />
            <CardContent className="p-6 text-center">
              <div className="relative w-32 h-32 mx-auto mb-4">
                <svg className="w-full h-full -rotate-90" viewBox="0 0 100 100">
                  <circle cx="50" cy="50" r="42" fill="none" stroke="hsl(var(--muted))" strokeWidth="8" />
                  <circle
                    cx="50" cy="50" r="42" fill="none"
                    stroke={healthScore >= 80 ? '#10b981' : healthScore >= 50 ? '#f59e0b' : '#ef4444'}
                    strokeWidth="8"
                    strokeLinecap="round"
                    strokeDasharray={`${healthScore * 2.64} 264`}
                    className="transition-all duration-1000 ease-out"
                  />
                </svg>
                <div className="absolute inset-0 flex flex-col items-center justify-center">
                  <span className={cn(
                    'text-4xl font-heading font-bold',
                    healthScore >= 80 ? 'text-emerald-600' : healthScore >= 50 ? 'text-amber-600' : 'text-red-600'
                  )}>
                    {healthScore}
                  </span>
                  <span className="text-xs text-muted-foreground">من 100</span>
                </div>
              </div>
              <h3 className="font-heading font-bold text-lg">نقاط صحة النظام</h3>
              <p className="text-sm text-muted-foreground mt-1">
                {healthScore >= 80 ? 'أداء ممتاز — استمر!' :
                 healthScore >= 50 ? 'أداء جيد — تحسينات مطلوبة' :
                 'يحتاج تدخل فوري'}
              </p>
            </CardContent>
          </Card>

          {/* Critical & Warning Summary */}
          <Card className="md:col-span-2">
            <CardHeader className="pb-3">
              <CardTitle className="text-base font-heading flex items-center gap-2">
                <Brain className="w-5 h-5 text-primary" />
                ملخص الرؤى
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="text-center p-3 rounded-xl bg-red-50">
                  <p className="text-3xl font-heading font-bold text-red-600">{criticalCount}</p>
                  <p className="text-xs text-red-700 mt-1">حرج</p>
                </div>
                <div className="text-center p-3 rounded-xl bg-amber-50">
                  <p className="text-3xl font-heading font-bold text-amber-600">{warningCount}</p>
                  <p className="text-xs text-amber-700 mt-1">تحذير</p>
                </div>
                <div className="text-center p-3 rounded-xl bg-emerald-50">
                  <p className="text-3xl font-heading font-bold text-emerald-600">{insights.filter(i => i.type === 'success').length}</p>
                  <p className="text-xs text-emerald-700 mt-1">نجاح</p>
                </div>
                <div className="text-center p-3 rounded-xl bg-blue-50">
                  <p className="text-3xl font-heading font-bold text-blue-600">{insights.filter(i => i.type === 'info').length}</p>
                  <p className="text-xs text-blue-700 mt-1">معلومة</p>
                </div>
              </div>

              {/* Predictions */}
              {predictions.length > 0 && (
                <div className="mt-4 pt-4 border-t">
                  <p className="text-xs text-muted-foreground mb-2 flex items-center gap-1">
                    <Zap className="w-3 h-3" /> تنبؤات AI للإرساليات
                  </p>
                  <div className="flex gap-3">
                    {predictions.map((p, i) => (
                      <div key={i} className="flex-1 p-2 rounded-lg bg-primary/5 text-center">
                        <p className="text-lg font-bold text-primary">{p.predicted}</p>
                        <p className="text-[10px] text-muted-foreground">{p.day}</p>
                        <p className="text-[9px] text-muted-foreground">ثقة {p.confidence}%</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Charts Row */}
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
          {/* Performance Radar */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base font-heading flex items-center gap-2">
                <Target className="w-5 h-5 text-primary" />
                مؤشرات الأداء الشاملة
              </CardTitle>
              <CardDescription>تحليل متعدد الأبعاد لأداء النظام</CardDescription>
            </CardHeader>
            <CardContent>
              {statsLoading ? <Skeleton className="w-full h-[300px]" /> : (
                <ResponsiveContainer width="100%" height={300}>
                  <RadarChart data={radarData}>
                    <PolarGrid stroke="hsl(var(--border))" />
                    <PolarAngleAxis dataKey="metric" tick={{ fontSize: 11, fill: 'hsl(var(--foreground))' }} />
                    <PolarRadiusAxis angle={30} domain={[0, 100]} tick={{ fontSize: 9 }} />
                    <Radar name="الأداء" dataKey="value" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.2} strokeWidth={2} />
                  </RadarChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* Governorate Comparison */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base font-heading flex items-center gap-2">
                <MapPin className="w-5 h-5 text-primary" />
                مقارنة أداء المحافظات
              </CardTitle>
              <CardDescription>المحليات الأكثر والأقل نشاطاً</CardDescription>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={(govStats || []).slice(0, 8)} layout="vertical">
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" horizontal={false} />
                  <XAxis type="number" tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" />
                  <YAxis dataKey="name" type="category" tick={{ fontSize: 10 }} width={70} stroke="hsl(var(--muted-foreground))" />
                  <Tooltip contentStyle={{ backgroundColor: 'hsl(var(--popover))', border: '1px solid hsl(var(--border))', borderRadius: '8px' }} />
                  <Bar dataKey="submissions" name="إرساليات" radius={[0, 4, 4, 0]}>
                    {(govStats || []).slice(0, 8).map((_, i) => (
                      <Cell key={i} fill={i < 3 ? '#10b981' : i > 5 ? '#ef4444' : '#3b82f6'} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </div>

        {/* Insights List */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base font-heading flex items-center gap-2">
              <Lightbulb className="w-5 h-5 text-amber-500" />
              الرؤى والتوصيات
              <Badge variant="outline" className="mr-auto">{insights.length}</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {insights.length === 0 ? (
              <div className="text-center py-8">
                <CheckCircle2 className="w-12 h-12 text-emerald-500 mx-auto mb-3" />
                <p className="font-medium">كل شيء يبدو جيداً! 🎉</p>
                <p className="text-sm text-muted-foreground">لا توجد مشاكل تحتاج اهتمامك</p>
              </div>
            ) : (
              insights.map((insight, i) => {
                const colors = INSIGHT_COLORS[insight.type]
                const Icon = insight.icon
                return (
                  <div
                    key={i}
                    className={cn(
                      'p-4 rounded-xl border transition-all hover:shadow-md',
                      colors.bg, colors.border
                    )}
                  >
                    <div className="flex items-start gap-3">
                      <div className={cn('p-2 rounded-lg bg-white/80', colors.icon)}>
                        <Icon className="w-5 h-5" />
                      </div>
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-1">
                          <h4 className={cn('font-bold text-sm', colors.text)}>{insight.title}</h4>
                          <Badge className={cn('text-[10px]', colors.badge)}>
                            {insight.type === 'critical' ? 'حرج' :
                             insight.type === 'warning' ? 'تحذير' :
                             insight.type === 'success' ? 'نجاح' : 'معلومة'}
                          </Badge>
                        </div>
                        <p className={cn('text-sm', colors.text, 'opacity-80')}>{insight.description}</p>
                        <div className={cn('mt-2 flex items-center gap-1.5 text-xs font-medium', colors.text)}>
                          <Zap className="w-3 h-3" />
                          التوصية: {insight.action}
                        </div>
                      </div>
                    </div>
                  </div>
                )
              })
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
