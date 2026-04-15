import { useState, useMemo, useCallback, useRef } from 'react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import { Header } from '@/components/layout/header'
import {
  useDashboardStats, useSubmissionsChart, useGovernorateStats,
  useRoleDistribution, useForms, useSubmissions, useUsers, useGovernorates,
} from '@/hooks/useApi'
import { formatNumber, cn, generateColor } from '@/lib/utils'
import type { Form, FormSubmission } from '@/types/database'
import {
  BarChart, Bar, PieChart, Pie, Cell, LineChart, Line,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
  AreaChart, Area, RadarChart, Radar, PolarGrid, PolarAngleAxis,
  PolarRadiusAxis, ScatterChart, Scatter, ComposedChart,
} from 'recharts'
import {
  Download, FileSpreadsheet, TrendingUp, TrendingDown, Minus,
  Users, FileText, MapPin, CheckCircle2, XCircle, Clock, BarChart3,
  PieChartIcon, Activity, Target, AlertTriangle, Award, Filter,
  Calendar, Hash, Type, ListChecks, Image,
} from 'lucide-react'

// ──────────────────────────────────────────────
// Constants
// ──────────────────────────────────────────────
const CHART_COLORS = [
  '#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6',
  '#06b6d4', '#ec4899', '#84cc16', '#f97316', '#6366f1',
  '#14b8a6', '#f43f5e', '#a855f7', '#eab308', '#0ea5e9',
]

const CHART_TOOLTIP_STYLE = {
  backgroundColor: 'hsl(var(--popover))',
  border: '1px solid hsl(var(--border))',
  borderRadius: '8px',
  direction: 'rtl' as const,
}

const DAY_NAMES = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت']

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────
function computeMedian(values: number[]): number {
  if (values.length === 0) return 0
  const sorted = [...values].sort((a, b) => a - b)
  const mid = Math.floor(sorted.length / 2)
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
}

function buildHistogram(values: number[], bins = 10): { range: string; count: number }[] {
  if (values.length === 0) return []
  const min = Math.min(...values)
  const max = Math.max(...values)
  const step = (max - min) / bins || 1
  const result: { range: string; count: number }[] = []
  for (let i = 0; i < bins; i++) {
    const lo = min + i * step
    const hi = min + (i + 1) * step
    result.push({
      range: `${lo.toFixed(1)}-${hi.toFixed(1)}`,
      count: values.filter(v => v >= lo && (i === bins - 1 ? v <= hi : v < hi)).length,
    })
  }
  return result
}

function extractWordFrequency(texts: string[], topN = 15): { word: string; count: number }[] {
  const freq: Record<string, number> = {}
  const stopWords = new Set(['في', 'من', 'على', 'إلى', 'هذا', 'هذه', 'التي', 'الذي', 'أن', 'لا', 'ما', 'و', 'أو', 'ثم', 'هو', 'هي', 'كان', 'كانت', 'the', 'a', 'an', 'is', 'are', 'was', 'were', 'of', 'in', 'to', 'for', 'and', 'or', 'with', 'on', 'at', 'by'])
  for (const text of texts) {
    const words = text.toLowerCase().replace(/[^\w\s\u0600-\u06FF]/g, '').split(/\s+/)
    for (const w of words) {
      if (w.length > 2 && !stopWords.has(w)) {
        freq[w] = (freq[w] || 0) + 1
      }
    }
  }
  return Object.entries(freq)
    .sort(([, a], [, b]) => b - a)
    .slice(0, topN)
    .map(([word, count]) => ({ word, count }))
}

function exportToCSV(headers: string[], rows: (string | number)[][], filename: string) {
  const csvContent = [
    headers.join(','),
    ...rows.map(r => r.map(v => `"${v}"`).join(',')),
  ].join('\n')
  const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${filename}_${new Date().toISOString().split('T')[0]}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function exportChartAsImage(ref: React.RefObject<HTMLDivElement>, filename: string) {
  if (!ref.current) return
  import('html-to-image').then(({ toPng }) => {
    toPng(ref.current!, { backgroundColor: '#ffffff' }).then((dataUrl) => {
      const a = document.createElement('a')
      a.href = dataUrl
      a.download = `${filename}_${new Date().toISOString().split('T')[0]}.png`
      a.click()
    })
  }).catch(() => {
    // Fallback: just notify
    alert('ميزة التصدير كصورة غير متاحة حالياً')
  })
}

// ──────────────────────────────────────────────
// Sub-components
// ──────────────────────────────────────────────

interface KpiCardProps {
  label: string
  value: string | number
  icon: React.ReactNode
  color: string
  trend?: number
  subtitle?: string
}

function KpiCard({ label, value, icon, color, trend, subtitle }: KpiCardProps) {
  return (
    <Card className="relative overflow-hidden">
      <CardContent className="p-4">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <p className="text-xs text-muted-foreground mb-1">{label}</p>
            <p className={cn('text-2xl font-heading font-bold', color)}>{value}</p>
            {subtitle && <p className="text-[11px] text-muted-foreground mt-0.5">{subtitle}</p>}
            {trend !== undefined && (
              <div className={cn('flex items-center gap-1 mt-1 text-xs', trend > 0 ? 'text-emerald-600' : trend < 0 ? 'text-red-600' : 'text-muted-foreground')}>
                {trend > 0 ? <TrendingUp className="w-3 h-3" /> : trend < 0 ? <TrendingDown className="w-3 h-3" /> : <Minus className="w-3 h-3" />}
                <span>{trend > 0 ? '+' : ''}{trend.toFixed(1)}%</span>
                <span className="text-muted-foreground">vs الفترة السابقة</span>
              </div>
            )}
          </div>
          <div className={cn('w-10 h-10 rounded-lg flex items-center justify-center', color.replace('text-', 'bg-').replace('600', '100'))}>
            {icon}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

function ChartCard({
  title, description, children, className, loading, chartRef,
}: {
  title: string; description?: string; children: React.ReactNode
  className?: string; loading?: boolean; chartRef?: React.RefObject<HTMLDivElement>
}) {
  return (
    <Card className={className}>
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <div>
            <CardTitle className="font-heading text-base">{title}</CardTitle>
            {description && <CardDescription className="text-xs">{description}</CardDescription>}
          </div>
          {chartRef && (
            <Button variant="ghost" size="icon-sm" onClick={() => exportChartAsImage(chartRef, title)} title="تصدير كصورة">
              <Image className="w-4 h-4" />
            </Button>
          )}
        </div>
      </CardHeader>
      <CardContent ref={chartRef}>
        {loading ? <Skeleton className="w-full h-[280px]" /> : children}
      </CardContent>
    </Card>
  )
}

// ──────────────────────────────────────────────
// Form field analysis type
// ──────────────────────────────────────────────
interface FormFieldSchema {
  type: string
  label?: string
  label_ar?: string
  label_en?: string
  options?: string[] | { label?: string; value?: string }[]
  required?: boolean
}

function getFieldLabel(field: FormFieldSchema): string {
  return field.label_ar || field.label || field.label_en || 'حقل غير معروف'
}

function getFieldTypeIcon(type: string) {
  switch (type) {
    case 'text': case 'textarea': case 'string': return <Type className="w-3.5 h-3.5" />
    case 'number': case 'integer': case 'float': return <Hash className="w-3.5 h-3.5" />
    case 'select': case 'radio': return <ListChecks className="w-3.5 h-3.5" />
    case 'multiselect': case 'checkbox': return <ListChecks className="w-3.5 h-3.5" />
    case 'date': case 'datetime': return <Calendar className="w-3.5 h-3.5" />
    case 'gps': case 'location': return <MapPin className="w-3.5 h-3.5" />
    case 'photo': case 'image': return <Image className="w-3.5 h-3.5" />
    default: return <FileText className="w-3.5 h-3.5" />
  }
}

function getFieldTypeLabel(type: string): string {
  const labels: Record<string, string> = {
    text: 'نص', textarea: 'نص طويل', string: 'نص',
    number: 'رقم', integer: 'عدد صحيح', float: 'عشري',
    select: 'اختيار', radio: 'اختيار', multiselect: 'اختيار متعدد',
    checkbox: 'مربعات اختيار', date: 'تاريخ', datetime: 'تاريخ ووقت',
    gps: 'موقع', location: 'موقع', photo: 'صورة', image: 'صورة',
    boolean: 'صح/خطأ',
  }
  return labels[type] || type
}

// ──────────────────────────────────────────────
// Main Component
// ──────────────────────────────────────────────
export default function AnalyticsPage() {
  // Data hooks
  const { data: stats, isLoading: statsLoading } = useDashboardStats()
  const { data: chartData, isLoading: chartLoading } = useSubmissionsChart()
  const { data: govStats, isLoading: govLoading } = useGovernorateStats()
  const { data: roleDistribution, isLoading: roleLoading } = useRoleDistribution()
  const { data: formsResult, isLoading: formsLoading } = useForms()
  const forms = formsResult?.data
  const { data: users, isLoading: usersLoading } = useUsers()
  const { data: governorates } = useGovernorates()

  // Fetch all submissions for deep analysis (paginated internally, get a large batch)
  const { data: allSubmissionsData } = useSubmissions({ pageSize: 500 })

  // Local state
  const [selectedFormId, setSelectedFormId] = useState<string>('')
  const [timeGranularity, setTimeGranularity] = useState<'daily' | 'weekly' | 'monthly'>('daily')

  // Refs for chart export
  const timeChartRef = useRef<HTMLDivElement>(null)
  const govChartRef = useRef<HTMLDivElement>(null)
  const qualityChartRef = useRef<HTMLDivElement>(null)

  const allSubmissions = allSubmissionsData?.data || []

  // ── Selected form ──
  const selectedForm = useMemo(
    () => forms?.find(f => f.id === selectedFormId),
    [forms, selectedFormId]
  )

  // ── Form submissions ──
  const formSubmissions = useMemo(
    () => selectedFormId ? allSubmissions.filter(s => s.form_id === selectedFormId) : [],
    [allSubmissions, selectedFormId]
  )

  // ── Parse form schema fields ──
  const formFields = useMemo((): FormFieldSchema[] => {
    if (!selectedForm?.schema) return []
    const schema = selectedForm.schema as Record<string, unknown>
    // Schema could have a "fields" array or be a flat object of field definitions
    if (Array.isArray(schema.fields)) return schema.fields as FormFieldSchema[]
    if (Array.isArray(schema.properties)) return schema.properties as FormFieldSchema[]
    // Flat object: keys are field names, values are field configs
    return Object.entries(schema).map(([key, val]) => {
      if (typeof val === 'object' && val !== null) {
        return { ...(val as FormFieldSchema), label: (val as FormFieldSchema).label || key }
      }
      return { type: 'text', label: key }
    })
  }, [selectedForm])

  // ── Field-level analytics ──
  const fieldAnalytics = useMemo(() => {
    if (!formFields.length || !formSubmissions.length) return []
    return formFields.map((field) => {
      const label = getFieldLabel(field)
      const values = formSubmissions
        .map(s => (s.data as Record<string, unknown>)?.[field.label || field.label_ar || field.label_en || ''])
        .filter(v => v !== undefined && v !== null && v !== '')

      const nonEmpty = values.length
      const completeness = formSubmissions.length > 0 ? (nonEmpty / formSubmissions.length) * 100 : 0
      const type = field.type || 'text'

      // Numeric analysis
      let numericStats: { min: number; max: number; avg: number; median: number; histogram: { range: string; count: number }[] } | undefined
      if (['number', 'integer', 'float'].includes(type)) {
        const nums = values.map(Number).filter(n => !isNaN(n))
        if (nums.length > 0) {
          numericStats = {
            min: Math.min(...nums),
            max: Math.max(...nums),
            avg: nums.reduce((a, b) => a + b, 0) / nums.length,
            median: computeMedian(nums),
            histogram: buildHistogram(nums, 8),
          }
        }
      }

      // Categorical analysis (select / multiselect)
      let categoryData: { name: string; value: number }[] = []
      if (['select', 'radio', 'multiselect', 'checkbox'].includes(type)) {
        const freq: Record<string, number> = {}
        for (const v of values) {
          if (Array.isArray(v)) {
            for (const item of v) {
              const key = String(item)
              freq[key] = (freq[key] || 0) + 1
            }
          } else {
            const key = String(v)
            freq[key] = (freq[key] || 0) + 1
          }
        }
        categoryData = Object.entries(freq).map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value)
      }

      // Text word frequency
      let wordFrequency: { word: string; count: number }[] = []
      if (['text', 'textarea', 'string'].includes(type)) {
        wordFrequency = extractWordFrequency(values.map(String))
      }

      // Date distribution
      let dateDistribution: { date: string; count: number }[] = []
      if (['date', 'datetime'].includes(type)) {
        const freq: Record<string, number> = {}
        for (const v of values) {
          const d = new Date(String(v))
          if (!isNaN(d.getTime())) {
            const key = d.toISOString().split('T')[0].slice(0, 7) // month
            freq[key] = (freq[key] || 0) + 1
          }
        }
        dateDistribution = Object.entries(freq).sort(([a], [b]) => a.localeCompare(b)).map(([date, count]) => ({ date, count }))
      }

      // GPS count
      let gpsCount = 0
      if (['gps', 'location'].includes(type)) {
        gpsCount = nonEmpty
      }

      return { label, type, nonEmpty, completeness, numericStats, categoryData, wordFrequency, dateDistribution, gpsCount }
    })
  }, [formFields, formSubmissions])

  // ── Time-based analysis ──
  const timeAnalysis = useMemo(() => {
    if (!allSubmissions.length) return { hourly: [], dayOfWeek: [], periodComparison: null }

    // Hourly distribution
    const hourFreq: Record<number, number> = {}
    for (let h = 0; h < 24; h++) hourFreq[h] = 0
    allSubmissions.forEach(s => {
      const h = new Date(s.created_at).getHours()
      hourFreq[h]++
    })
    const hourly = Object.entries(hourFreq).map(([hour, count]) => ({ hour: `${hour}:00`, count }))

    // Day of week
    const dayFreq: Record<number, number> = {}
    for (let d = 0; d < 7; d++) dayFreq[d] = 0
    allSubmissions.forEach(s => {
      const d = new Date(s.created_at).getDay()
      dayFreq[d]++
    })
    const dayOfWeek = Object.entries(dayFreq).map(([day, count]) => ({ day: DAY_NAMES[Number(day)], count }))

    // Period comparison (this 30 days vs previous 30 days)
    const now = new Date()
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
    const sixtyDaysAgo = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000)
    const currentPeriod = allSubmissions.filter(s => new Date(s.created_at) >= thirtyDaysAgo).length
    const previousPeriod = allSubmissions.filter(s => {
      const d = new Date(s.created_at)
      return d >= sixtyDaysAgo && d < thirtyDaysAgo
    }).length
    const periodChange = previousPeriod > 0 ? ((currentPeriod - previousPeriod) / previousPeriod) * 100 : 0

    return { hourly, dayOfWeek, periodComparison: { current: currentPeriod, previous: previousPeriod, change: periodChange } }
  }, [allSubmissions])

  // ── Geographic coverage ──
  const geoCoverage = useMemo(() => {
    if (!governorates || !allSubmissions.length) return []
    const totalSubs = allSubmissions.length
    return governorates.map(gov => {
      const count = allSubmissions.filter(s => s.governorate_id === gov.id).length
      return {
        name: gov.name_ar,
        submissions: count,
        coverage: totalSubs > 0 ? (count / totalSubs) * 100 : 0,
      }
    }).sort((a, b) => b.submissions - a.submissions)
  }, [governorates, allSubmissions])

  // ── Quality analysis ──
  const qualityAnalysis = useMemo(() => {
    if (!allSubmissions.length) return { rejectionReasons: [], completenessByForm: [] }

    // Rejection reasons
    const reasonFreq: Record<string, number> = {}
    allSubmissions.filter(s => s.status === 'rejected').forEach(s => {
      const reason = s.review_notes || 'غير محدد'
      reasonFreq[reason] = (reasonFreq[reason] || 0) + 1
    })
    const rejectionReasons = Object.entries(reasonFreq)
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value)
      .slice(0, 10)

    // Data completeness per form
    const completenessByForm = (forms || []).map(form => {
      const subs = allSubmissions.filter(s => s.form_id === form.id)
      if (subs.length === 0) return { name: form.title_ar, completeness: 0, submissions: 0 }
      const schema = form.schema as Record<string, unknown>
      const fields = Array.isArray(schema.fields) ? schema.fields : Array.isArray(schema.properties) ? schema.properties : Object.keys(schema)
      const totalFields = fields.length * subs.length
      let filledFields = 0
      subs.forEach(s => {
        const data = s.data as Record<string, unknown>
        if (data) filledFields += Object.values(data).filter(v => v !== undefined && v !== null && v !== '').length
      })
      return {
        name: form.title_ar,
        completeness: totalFields > 0 ? (filledFields / totalFields) * 100 : 0,
        submissions: subs.length,
      }
    }).filter(f => f.submissions > 0)

    return { rejectionReasons, completenessByForm }
  }, [allSubmissions, forms])

  // ── User performance ──
  const userPerformance = useMemo(() => {
    if (!allSubmissions.length || !users) return { topContributors: [], distribution: [] }

    const userMap: Record<string, { name: string; submissions: number; approved: number; rejected: number }> = {}
    allSubmissions.forEach(s => {
      const uid = s.submitted_by
      if (!uid) return
      if (!userMap[uid]) {
        const user = users.find(u => u.id === uid)
        userMap[uid] = { name: user?.full_name || 'غير معروف', submissions: 0, approved: 0, rejected: 0 }
      }
      userMap[uid].submissions++
      if (s.status === 'approved') userMap[uid].approved++
      if (s.status === 'rejected') userMap[uid].rejected++
    })

    const topContributors = Object.values(userMap)
      .sort((a, b) => b.submissions - a.submissions)
      .slice(0, 10)

    const distribution = Object.values(userMap).reduce<Record<string, number>>((acc, u) => {
      const bucket = u.submissions <= 5 ? '1-5' : u.submissions <= 10 ? '6-10' : u.submissions <= 25 ? '11-25' : u.submissions <= 50 ? '26-50' : '51+'
      acc[bucket] = (acc[bucket] || 0) + 1
      return acc
    }, {})
    const distData = Object.entries(distribution).map(([range, count]) => ({ range, count }))

    return { topContributors, distribution: distData }
  }, [allSubmissions, users])

  // ── CSV export helpers ──
  const handleExportSubmissions = useCallback(() => {
    exportToCSV(
      ['النموذج', 'الحالة', 'تاريخ الإنشاء', 'المحافظة'],
      allSubmissions.map(s => [
        (s as FormSubmission).forms?.title_ar || '',
        s.status,
        s.created_at,
        s.governorate_id || '',
      ]),
      'submissions'
    )
  }, [allSubmissions])

  const handleExportGovStats = useCallback(() => {
    exportToCSV(
      ['المحافظة', 'الإرساليات', 'النسبة'],
      geoCoverage.map(g => [g.name, g.submissions, `${g.coverage.toFixed(1)}%`]),
      'governorate_stats'
    )
  }, [geoCoverage])

  // ── Formatted chart data for time granularity ──
  const timeChartData = useMemo(() => {
    if (!chartData) return []
    if (timeGranularity === 'daily') return chartData

    const groups: Record<string, { date: string; approved: number; rejected: number; pending: number }> = {}
    chartData.forEach(d => {
      let key: string
      if (timeGranularity === 'weekly') {
        const date = new Date(d.date)
        const weekStart = new Date(date.getTime() - date.getDay() * 24 * 60 * 60 * 1000)
        key = weekStart.toISOString().split('T')[0]
      } else {
        key = d.date.slice(0, 7)
      }
      if (!groups[key]) groups[key] = { date: key, approved: 0, rejected: 0, pending: 0 }
      groups[key].approved += d.approved
      groups[key].rejected += d.rejected
      groups[key].pending += d.pending
    })
    return Object.values(groups)
  }, [chartData, timeGranularity])

  // ── Status data for pie chart ──
  const statusData = useMemo(() => stats ? [
    { name: 'معتمدة', value: stats.approved_submissions, color: '#10b981' },
    { name: 'مرفوضة', value: stats.rejected_submissions, color: '#ef4444' },
    { name: 'قيد المراجعة', value: stats.pending_submissions, color: '#3b82f6' },
    { name: 'مسودة', value: stats.draft_submissions, color: '#6b7280' },
  ] : [], [stats])

  // ── Loading states ──
  const isLoading = statsLoading || chartLoading || govLoading

  return (
    <div className="page-enter">
      <Header title="التحليلات" subtitle="رؤى وإحصائيات تفصيلية شاملة" />

      <div className="p-6 space-y-6">

        {/* ═══════════════════════════════════════ */}
        {/* 1. KPI CARDS ROW                        */}
        {/* ═══════════════════════════════════════ */}
        <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">
          {statsLoading ? Array.from({ length: 6 }).map((_, i) => (
            <Card key={i}><CardContent className="p-4"><Skeleton className="w-full h-16" /></CardContent></Card>
          )) : stats ? (
            <>
              <KpiCard
                label="إجمالي الإرساليات"
                value={formatNumber(stats.total_submissions)}
                icon={<FileText className="w-5 h-5 text-blue-600" />}
                color="text-blue-600"
                trend={stats.submissions_trend}
              />
              <KpiCard
                label="معدل الاعتماد"
                value={`${stats.approval_rate.toFixed(1)}%`}
                icon={<CheckCircle2 className="w-5 h-5 text-emerald-600" />}
                color="text-emerald-600"
                subtitle={`${stats.approved_submissions} معتمدة`}
              />
              <KpiCard
                label="مرفوضة"
                value={formatNumber(stats.rejected_submissions)}
                icon={<XCircle className="w-5 h-5 text-red-600" />}
                color="text-red-600"
              />
              <KpiCard
                label="قيد المراجعة"
                value={formatNumber(stats.pending_submissions)}
                icon={<Clock className="w-5 h-5 text-amber-600" />}
                color="text-amber-600"
              />
              <KpiCard
                label="المستخدمون النشطون"
                value={`${stats.active_users}/${stats.total_users}`}
                icon={<Users className="w-5 h-5 text-purple-600" />}
                color="text-purple-600"
              />
              <KpiCard
                label="النماذج النشطة"
                value={`${stats.active_forms}/${stats.total_forms}`}
                icon={<Target className="w-5 h-5 text-cyan-600" />}
                color="text-cyan-600"
              />
            </>
          ) : null}
        </div>

        {/* ═══════════════════════════════════════ */}
        {/* 2. TIME-BASED ANALYSIS                  */}
        {/* ═══════════════════════════════════════ */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
          {/* Submissions over time */}
          <div className="xl:col-span-2">
            <ChartCard
              title="الإرساليات عبر الزمن"
              description="تطور الإرساليات حسب الحالة"
              loading={chartLoading}
              chartRef={timeChartRef}
            >
              <div className="flex items-center gap-2 mb-4">
                <Tabs value={timeGranularity} onValueChange={(v) => setTimeGranularity(v as typeof timeGranularity)}>
                  <TabsList>
                    <TabsTrigger value="daily">يومي</TabsTrigger>
                    <TabsTrigger value="weekly">أسبوعي</TabsTrigger>
                    <TabsTrigger value="monthly">شهري</TabsTrigger>
                  </TabsList>
                </Tabs>
                {timeAnalysis.periodComparison && (
                  <Badge variant="outline" className={cn('text-xs', timeAnalysis.periodComparison.change > 0 ? 'text-emerald-600 border-emerald-200' : 'text-red-600 border-red-200')}>
                    {timeAnalysis.periodComparison.change > 0 ? '↑' : '↓'} {Math.abs(timeAnalysis.periodComparison.change).toFixed(1)}% مقارنة بالفترة السابقة
                  </Badge>
                )}
              </div>
              <ResponsiveContainer width="100%" height={300}>
                <AreaChart data={timeChartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                  <XAxis dataKey="date" tick={{ fontSize: 10 }} tickFormatter={v => timeGranularity === 'monthly' ? v : v.slice(5)} stroke="hsl(var(--muted-foreground))" />
                  <YAxis tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" />
                  <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
                  <Legend wrapperStyle={{ direction: 'rtl', fontSize: 11 }} />
                  <Area type="monotone" dataKey="approved" name="معتمدة" stroke="#10b981" fill="#10b981" fillOpacity={0.15} strokeWidth={2} />
                  <Area type="monotone" dataKey="pending" name="معلقة" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.15} strokeWidth={2} />
                  <Area type="monotone" dataKey="rejected" name="مرفوضة" stroke="#ef4444" fill="#ef4444" fillOpacity={0.15} strokeWidth={2} />
                </AreaChart>
              </ResponsiveContainer>
            </ChartCard>
          </div>

          {/* Status distribution */}
          <ChartCard title="توزيع الحالات" description="نسب الإرساليات حسب الحالة">
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie data={statusData} cx="50%" cy="50%" outerRadius={90} innerRadius={50} paddingAngle={3} dataKey="value"
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                >
                  {statusData.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                </Pie>
                <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
              </PieChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>

        {/* Peak hours & days */}
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
          <ChartCard title="ساعات الذروة" description="توزيع الإرساليات حسب ساعة اليوم">
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={timeAnalysis.hourly}>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                <XAxis dataKey="hour" tick={{ fontSize: 9 }} stroke="hsl(var(--muted-foreground))" interval={2} />
                <YAxis tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" />
                <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
                <Bar dataKey="count" name="إرساليات" fill="#8b5cf6" radius={[3, 3, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard title="توزيع أيام الأسبوع" description="الإرساليات حسب اليوم">
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={timeAnalysis.dayOfWeek}>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                <XAxis dataKey="day" tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" />
                <YAxis tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" />
                <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
                <Bar dataKey="count" name="إرساليات" fill="#06b6d4" radius={[3, 3, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>

        {/* ═══════════════════════════════════════ */}
        {/* 3. GEOGRAPHIC ANALYSIS                  */}
        {/* ═══════════════════════════════════════ */}
        <ChartCard
          title="التحليل الجغرافي"
          description="عدد الإرساليات ونسبة التغطية حسب المحافظة"
          loading={govLoading}
          className="xl:col-span-2"
          chartRef={govChartRef}
        >
          <div className="flex gap-2 mb-4">
            <Button variant="outline" size="sm" onClick={handleExportGovStats}>
              <Download className="w-3.5 h-3.5 ml-1.5" />
              تصدير CSV
            </Button>
          </div>
          <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
            <ResponsiveContainer width="100%" height={350}>
              <BarChart data={geoCoverage} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                <XAxis type="number" tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" />
                <YAxis type="category" dataKey="name" tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" width={90} />
                <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
                <Bar dataKey="submissions" name="إرساليات" fill="#3b82f6" radius={[0, 4, 4, 0]} />
              </BarChart>
            </ResponsiveContainer>
            <div className="space-y-3">
              <h4 className="text-sm font-medium text-muted-foreground">نسبة التغطية</h4>
              {geoCoverage.slice(0, 12).map((gov, i) => (
                <div key={i} className="space-y-1">
                  <div className="flex items-center justify-between text-xs">
                    <span>{gov.name}</span>
                    <span className="font-mono tabular-nums">{gov.coverage.toFixed(1)}%</span>
                  </div>
                  <Progress value={gov.coverage} className="h-1.5" indicatorClassName={cn(gov.coverage > 10 ? 'bg-emerald-500' : gov.coverage > 5 ? 'bg-amber-500' : 'bg-red-500')} />
                </div>
              ))}
            </div>
          </div>
        </ChartCard>

        {/* ═══════════════════════════════════════ */}
        {/* 4. FORM-SPECIFIC ANALYSIS               */}
        {/* ═══════════════════════════════════════ */}
        <Card>
          <CardHeader>
            <div className="flex flex-col sm:flex-row sm:items-center gap-4">
              <div className="flex-1">
                <CardTitle className="font-heading">تحليل النماذج</CardTitle>
                <CardDescription>تحليل تفصيلي لكل حقل في النموذج المحدد</CardDescription>
              </div>
              <Select value={selectedFormId} onValueChange={setSelectedFormId}>
                <SelectTrigger className="w-[280px]">
                  <SelectValue placeholder="اختر نموذجاً للتحليل..." />
                </SelectTrigger>
                <SelectContent>
                  {forms?.map(form => (
                    <SelectItem key={form.id} value={form.id}>
                      {form.title_ar}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </CardHeader>
          <CardContent>
            {!selectedFormId ? (
              <div className="flex flex-col items-center justify-center py-16 text-muted-foreground">
                <BarChart3 className="w-12 h-12 mb-3 opacity-30" />
                <p className="text-sm">اختر نموذجاً لعرض التحليل التفصيلي للحقول</p>
              </div>
            ) : formsLoading ? (
              <div className="space-y-4">
                {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="w-full h-40" />)}
              </div>
            ) : !formFields.length ? (
              <div className="text-center py-12 text-muted-foreground">
                <p>لا توجد حقول محددة في مخطط النموذج</p>
              </div>
            ) : (
              <div className="space-y-6">
                {/* Form summary */}
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                  <div className="p-3 rounded-lg bg-muted/50">
                    <p className="text-xs text-muted-foreground">الإرساليات</p>
                    <p className="text-lg font-bold text-blue-600">{formSubmissions.length}</p>
                  </div>
                  <div className="p-3 rounded-lg bg-muted/50">
                    <p className="text-xs text-muted-foreground">الحقول</p>
                    <p className="text-lg font-bold text-purple-600">{formFields.length}</p>
                  </div>
                  <div className="p-3 rounded-lg bg-muted/50">
                    <p className="text-xs text-muted-foreground">معدل الإكمال</p>
                    <p className="text-lg font-bold text-emerald-600">
                      {fieldAnalytics.length > 0
                        ? (fieldAnalytics.reduce((a, f) => a + f.completeness, 0) / fieldAnalytics.length).toFixed(1) + '%'
                        : '0%'}
                    </p>
                  </div>
                  <div className="p-3 rounded-lg bg-muted/50">
                    <p className="text-xs text-muted-foreground">معدل الاعتماد</p>
                    <p className="text-lg font-bold text-amber-600">
                      {formSubmissions.length > 0
                        ? ((formSubmissions.filter(s => s.status === 'approved').length / formSubmissions.length) * 100).toFixed(1) + '%'
                        : '0%'}
                    </p>
                  </div>
                </div>

                {/* Field-by-field analysis */}
                <div className="space-y-4">
                  <h3 className="text-sm font-medium">تحليل الحقول</h3>
                  {fieldAnalytics.map((field, idx) => (
                    <Card key={idx} className="border-muted">
                      <CardContent className="p-4">
                        <div className="flex items-center justify-between mb-3">
                          <div className="flex items-center gap-2">
                            {getFieldTypeIcon(field.type)}
                            <span className="font-medium text-sm">{field.label}</span>
                            <Badge variant="outline" className="text-[10px]">{getFieldTypeLabel(field.type)}</Badge>
                          </div>
                          <div className="flex items-center gap-3 text-xs text-muted-foreground">
                            <span>{field.nonEmpty}/{formSubmissions.length} مُعبأ</span>
                            <span className={cn('font-medium', field.completeness > 80 ? 'text-emerald-600' : field.completeness > 50 ? 'text-amber-600' : 'text-red-600')}>
                              {field.completeness.toFixed(0)}%
                            </span>
                          </div>
                        </div>
                        <Progress value={field.completeness} className="h-1 mb-3" />

                        {/* Numeric: stats + histogram */}
                        {field.numericStats && (
                          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3">
                            <div className="grid grid-cols-2 gap-2">
                              <div className="p-2 rounded bg-muted/30 text-center">
                                <p className="text-[10px] text-muted-foreground">الأدنى</p>
                                <p className="text-sm font-bold">{field.numericStats.min.toFixed(2)}</p>
                              </div>
                              <div className="p-2 rounded bg-muted/30 text-center">
                                <p className="text-[10px] text-muted-foreground">الأعلى</p>
                                <p className="text-sm font-bold">{field.numericStats.max.toFixed(2)}</p>
                              </div>
                              <div className="p-2 rounded bg-muted/30 text-center">
                                <p className="text-[10px] text-muted-foreground">المتوسط</p>
                                <p className="text-sm font-bold">{field.numericStats.avg.toFixed(2)}</p>
                              </div>
                              <div className="p-2 rounded bg-muted/30 text-center">
                                <p className="text-[10px] text-muted-foreground">الوسيط</p>
                                <p className="text-sm font-bold">{field.numericStats.median.toFixed(2)}</p>
                              </div>
                            </div>
                            <ResponsiveContainer width="100%" height={150}>
                              <BarChart data={field.numericStats.histogram}>
                                <XAxis dataKey="range" tick={{ fontSize: 8 }} stroke="hsl(var(--muted-foreground))" />
                                <YAxis tick={{ fontSize: 9 }} stroke="hsl(var(--muted-foreground))" />
                                <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
                                <Bar dataKey="count" name="العدد" fill="#8b5cf6" radius={[2, 2, 0, 0]} />
                              </BarChart>
                            </ResponsiveContainer>
                          </div>
                        )}

                        {/* Categorical: pie chart */}
                        {field.categoryData.length > 0 && (
                          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3">
                            <ResponsiveContainer width="100%" height={180}>
                              <PieChart>
                                <Pie data={field.categoryData} cx="50%" cy="50%" outerRadius={70} innerRadius={35} paddingAngle={2} dataKey="value"
                                  label={({ name, percent }) => percent > 0.05 ? `${name.slice(0, 10)}` : ''}
                                >
                                  {field.categoryData.map((_, i) => <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />)}
                                </Pie>
                                <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
                              </PieChart>
                            </ResponsiveContainer>
                            <div className="space-y-1.5 max-h-[180px] overflow-y-auto">
                              {field.categoryData.map((cat, ci) => (
                                <div key={ci} className="flex items-center justify-between text-xs">
                                  <div className="flex items-center gap-2">
                                    <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: CHART_COLORS[ci % CHART_COLORS.length] }} />
                                    <span>{cat.name}</span>
                                  </div>
                                  <span className="font-mono text-muted-foreground">{cat.value}</span>
                                </div>
                              ))}
                            </div>
                          </div>
                        )}

                        {/* Text: word frequency */}
                        {field.wordFrequency.length > 0 && (
                          <div className="mt-3">
                            <p className="text-xs text-muted-foreground mb-2">أكثر الكلمات تكراراً</p>
                            <div className="flex flex-wrap gap-2">
                              {field.wordFrequency.map((w, wi) => (
                                <Badge key={wi} variant="secondary" className="text-xs" style={{ opacity: 0.5 + (w.count / field.wordFrequency[0].count) * 0.5 }}>
                                  {w.word} ({w.count})
                                </Badge>
                              ))}
                            </div>
                          </div>
                        )}

                        {/* Date: timeline */}
                        {field.dateDistribution.length > 0 && (
                          <div className="mt-3">
                            <ResponsiveContainer width="100%" height={150}>
                              <BarChart data={field.dateDistribution}>
                                <XAxis dataKey="date" tick={{ fontSize: 9 }} stroke="hsl(var(--muted-foreground))" />
                                <YAxis tick={{ fontSize: 9 }} stroke="hsl(var(--muted-foreground))" />
                                <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
                                <Bar dataKey="count" name="العدد" fill="#f59e0b" radius={[2, 2, 0, 0]} />
                              </BarChart>
                            </ResponsiveContainer>
                          </div>
                        )}

                        {/* GPS: coverage info */}
                        {field.gpsCount > 0 && (
                          <div className="mt-3 p-3 rounded-lg bg-muted/30 flex items-center gap-3">
                            <MapPin className="w-4 h-4 text-emerald-600" />
                            <div>
                              <p className="text-xs text-muted-foreground">البيانات الجغرافية</p>
                              <p className="text-sm font-medium">{field.gpsCount} من {formSubmissions.length} إرسالية ({((field.gpsCount / formSubmissions.length) * 100).toFixed(0)}%) تحتوي على بيانات GPS</p>
                            </div>
                          </div>
                        )}
                      </CardContent>
                    </Card>
                  ))}
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* ═══════════════════════════════════════ */}
        {/* 5. QUALITY ANALYSIS                    */}
        {/* ═══════════════════════════════════════ */}
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
          <ChartCard title="أسباب الرفض" description="أكثر أسباب رفض الإرساليات" chartRef={qualityChartRef}>
            {qualityAnalysis.rejectionReasons.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <ResponsiveContainer width="100%" height={250}>
                  <PieChart>
                    <Pie data={qualityAnalysis.rejectionReasons} cx="50%" cy="50%" outerRadius={80} innerRadius={40} dataKey="value"
                      label={({ name, percent }) => percent > 0.08 ? `${name.slice(0, 12)}` : ''}
                    >
                      {qualityAnalysis.rejectionReasons.map((_, i) => <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />)}
                    </Pie>
                    <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
                  </PieChart>
                </ResponsiveContainer>
                <div className="space-y-2 max-h-[250px] overflow-y-auto">
                  {qualityAnalysis.rejectionReasons.map((r, i) => (
                    <div key={i} className="flex items-center gap-2 text-xs">
                      <span className="w-3 h-3 rounded-full shrink-0" style={{ backgroundColor: CHART_COLORS[i % CHART_COLORS.length] }} />
                      <span className="flex-1 truncate">{r.name}</span>
                      <Badge variant="outline" className="text-[10px]">{r.value}</Badge>
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <p className="text-center text-sm text-muted-foreground py-8">لا توجد إرساليات مرفوضة</p>
            )}
          </ChartCard>

          <ChartCard title="اكتمال البيانات" description="نسبة اكتمال البيانات لكل نموذج">
            {qualityAnalysis.completenessByForm.length > 0 ? (
              <div className="space-y-3 max-h-[300px] overflow-y-auto">
                {qualityAnalysis.completenessByForm.map((f, i) => (
                  <div key={i} className="space-y-1.5">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-medium truncate max-w-[200px]">{f.name}</span>
                      <div className="flex items-center gap-2">
                        <span className="text-muted-foreground">{f.submissions} إرسالية</span>
                        <span className={cn('font-mono font-bold', f.completeness > 80 ? 'text-emerald-600' : f.completeness > 50 ? 'text-amber-600' : 'text-red-600')}>
                          {f.completeness.toFixed(1)}%
                        </span>
                      </div>
                    </div>
                    <Progress value={f.completeness} className="h-2"
                      indicatorClassName={cn(f.completeness > 80 ? 'bg-emerald-500' : f.completeness > 50 ? 'bg-amber-500' : 'bg-red-500')}
                    />
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-center text-sm text-muted-foreground py-8">لا توجد بيانات كافية</p>
            )}
          </ChartCard>
        </div>

        {/* ═══════════════════════════════════════ */}
        {/* 6. USER PERFORMANCE                    */}
        {/* ═══════════════════════════════════════ */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
          {/* Top contributors */}
          <Card className="xl:col-span-2">
            <CardHeader>
              <CardTitle className="font-heading text-base">أفضل المساهمين</CardTitle>
              <CardDescription>المستخدمون الأكثر نشاطاً في الإدخال</CardDescription>
            </CardHeader>
            <CardContent>
              {usersLoading ? <Skeleton className="w-full h-[300px]" /> : userPerformance.topContributors.length > 0 ? (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead className="text-right">#</TableHead>
                      <TableHead className="text-right">الاسم</TableHead>
                      <TableHead className="text-right">الإرساليات</TableHead>
                      <TableHead className="text-right">معتمدة</TableHead>
                      <TableHead className="text-right">مرفوضة</TableHead>
                      <TableHead className="text-right">معدل الاعتماد</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {userPerformance.topContributors.map((u, i) => (
                      <TableRow key={i}>
                        <TableCell>
                          {i < 3 ? (
                            <Award className={cn('w-4 h-4', i === 0 ? 'text-yellow-500' : i === 1 ? 'text-gray-400' : 'text-amber-600')} />
                          ) : (
                            <span className="text-muted-foreground text-sm">{i + 1}</span>
                          )}
                        </TableCell>
                        <TableCell className="font-medium">{u.name}</TableCell>
                        <TableCell className="font-mono">{u.submissions}</TableCell>
                        <TableCell className="text-emerald-600 font-mono">{u.approved}</TableCell>
                        <TableCell className="text-red-600 font-mono">{u.rejected}</TableCell>
                        <TableCell>
                          <Badge variant="outline" className={cn('text-xs', u.submissions > 0 && u.approved / u.submissions > 0.8 ? 'text-emerald-600' : 'text-amber-600')}>
                            {u.submissions > 0 ? ((u.approved / u.submissions) * 100).toFixed(0) : 0}%
                          </Badge>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              ) : (
                <p className="text-center text-sm text-muted-foreground py-8">لا توجد بيانات مستخدمين</p>
              )}
            </CardContent>
          </Card>

          {/* Distribution */}
          <ChartCard title="توزيع المستخدمين" description="حسب عدد الإرساليات">
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie data={userPerformance.distribution} cx="50%" cy="50%" outerRadius={90} innerRadius={45} paddingAngle={3} dataKey="count" nameKey="range"
                  label={({ range, percent }) => `${range} (${(percent * 100).toFixed(0)}%)`}
                >
                  {userPerformance.distribution.map((_, i) => <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />)}
                </Pie>
                <Tooltip contentStyle={CHART_TOOLTIP_STYLE} formatter={(value: number, _name: string, props: any) => [`${value} مستخدم`, props?.payload?.range || '']} />
              </PieChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>

        {/* ═══════════════════════════════════════ */}
        {/* 7. ROLE DISTRIBUTION                   */}
        {/* ═══════════════════════════════════════ */}
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
          <ChartCard title="توزيع الأدوار" description="عدد المستخدمين حسب الدور" loading={roleLoading}>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <ResponsiveContainer width="100%" height={250}>
                <PieChart>
                  <Pie data={roleDistribution || []} cx="50%" cy="50%" outerRadius={80} innerRadius={40} dataKey="value" nameKey="name"
                    label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                  >
                    {(roleDistribution || []).map((_, i) => <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />)}
                  </Pie>
                  <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
                </PieChart>
              </ResponsiveContainer>
              <ResponsiveContainer width="100%" height={250}>
                <RadarChart data={(roleDistribution || []).map(d => ({ subject: d.name, count: d.value }))}>
                  <PolarGrid stroke="hsl(var(--border))" />
                  <PolarAngleAxis dataKey="subject" tick={{ fontSize: 10 }} />
                  <PolarRadiusAxis tick={{ fontSize: 9 }} />
                  <Radar name="المستخدمون" dataKey="count" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.3} />
                  <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
                </RadarChart>
              </ResponsiveContainer>
            </div>
          </ChartCard>

          {/* Export section */}
          <Card>
            <CardHeader>
              <CardTitle className="font-heading text-base">تصدير البيانات</CardTitle>
              <CardDescription>تحميل التقارير والبيانات الخام</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 gap-3">
                <Button variant="outline" className="justify-start gap-2 h-auto py-3" onClick={handleExportSubmissions}>
                  <FileSpreadsheet className="w-4 h-4 text-emerald-600" />
                  <div className="text-right flex-1">
                    <p className="text-sm font-medium">الإرساليات (CSV)</p>
                    <p className="text-xs text-muted-foreground">{allSubmissions.length} سجل</p>
                  </div>
                </Button>
                <Button variant="outline" className="justify-start gap-2 h-auto py-3" onClick={handleExportGovStats}>
                  <FileSpreadsheet className="w-4 h-4 text-blue-600" />
                  <div className="text-right flex-1">
                    <p className="text-sm font-medium">إحصائيات المحافظات (CSV)</p>
                    <p className="text-xs text-muted-foreground">{geoCoverage.length} محافظة</p>
                  </div>
                </Button>
                <Button variant="outline" className="justify-start gap-2 h-auto py-3" onClick={() => exportChartAsImage(timeChartRef, 'submissions_over_time')}>
                  <Image className="w-4 h-4 text-purple-600" />
                  <div className="text-right flex-1">
                    <p className="text-sm font-medium">الإرساليات عبر الزمن (صورة)</p>
                    <p className="text-xs text-muted-foreground">PNG</p>
                  </div>
                </Button>
                <Button variant="outline" className="justify-start gap-2 h-auto py-3" onClick={() => exportChartAsImage(govChartRef, 'governorate_stats')}>
                  <Image className="w-4 h-4 text-amber-600" />
                  <div className="text-right flex-1">
                    <p className="text-sm font-medium">إحصائيات المحافظات (صورة)</p>
                    <p className="text-xs text-muted-foreground">PNG</p>
                  </div>
                </Button>
              </div>

              {/* Quick stats summary */}
              {stats && (
                <div className="border-t pt-4 mt-4">
                  <h4 className="text-xs font-medium text-muted-foreground mb-3">ملخص سريع</h4>
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div className="flex justify-between"><span className="text-muted-foreground">الإرساليات اليوم</span><span className="font-mono">{stats.submissions_today}</span></div>
                    <div className="flex justify-between"><span className="text-muted-foreground">هذا الأسبوع</span><span className="font-mono">{stats.submissions_this_week}</span></div>
                    <div className="flex justify-between"><span className="text-muted-foreground">النقص الحرج</span><span className="font-mono text-red-600">{stats.critical_shortages}</span></div>
                    <div className="flex justify-between"><span className="text-muted-foreground">الإشعارات</span><span className="font-mono">{stats.unread_notifications}</span></div>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

      </div>
    </div>
  )
}
