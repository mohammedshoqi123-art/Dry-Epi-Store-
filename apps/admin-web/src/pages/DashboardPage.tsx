import { useState } from 'react'
import {
  Users, FileText, FileStack, AlertTriangle, TrendingUp, TrendingDown,
  CheckCircle2, XCircle, Clock, Activity, BarChart3, ArrowUpRight,
  Shield, Zap, Target, Sparkles, Calendar, RefreshCw
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Skeleton } from '@/components/ui/skeleton'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Button } from '@/components/ui/button'
import { Header } from '@/components/layout/header'
import { useDashboardStats, useSubmissionsChart, useGovernorateStats, useRoleDistribution } from '@/hooks/useApi'
import { formatNumber, formatPercent, cn } from '@/lib/utils'
import { useCampaign } from '@/lib/campaign-context'
import {
  AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend
} from 'recharts'

const CHART_COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4', '#ec4899']

interface StatCardProps {
  title: string
  value: number | string
  change?: number
  icon: React.ElementType
  color: string
  bgColor: string
  description?: string
  gradient?: string
}

function StatCard({ title, value, change, icon: Icon, color, bgColor, description, gradient }: StatCardProps) {
  return (
    <Card className="group relative overflow-hidden hover:shadow-xl hover:shadow-primary/5 transition-all duration-300 hover:-translate-y-0.5 border-0 shadow-md">
      {/* Top gradient line */}
      <div className={cn('absolute top-0 left-0 right-0 h-[3px] opacity-0 group-hover:opacity-100 transition-opacity duration-300', gradient || 'bg-gradient-to-r from-blue-500 to-blue-600')} />

      {/* Subtle background glow on hover */}
      <div className={cn('absolute -top-12 -right-12 w-32 h-32 rounded-full blur-2xl opacity-0 group-hover:opacity-20 transition-opacity duration-500', bgColor)} />

      <CardContent className="p-6 relative">
        <div className="flex items-start justify-between">
          <div className="space-y-2">
            <p className="text-sm font-medium text-muted-foreground">{title}</p>
            <div className="flex items-baseline gap-2">
              <span className="text-3xl font-heading font-bold tabular-nums">{value}</span>
              {change !== undefined && (
                <span className={cn(
                  'text-xs font-semibold flex items-center gap-0.5 px-1.5 py-0.5 rounded-full',
                  change >= 0 ? 'text-emerald-700 bg-emerald-50' : 'text-red-700 bg-red-50'
                )}>
                  {change >= 0 ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
                  {formatPercent(change)}
                </span>
              )}
            </div>
            {description && <p className="text-xs text-muted-foreground">{description}</p>}
          </div>
          <div className={cn('p-3 rounded-2xl transition-all duration-300 group-hover:scale-110 group-hover:rotate-3', bgColor)}>
            <Icon className={cn('w-6 h-6', color)} />
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

function StatCardSkeleton() {
  return (
    <Card className="border-0 shadow-md">
      <CardContent className="p-6">
        <div className="flex items-start justify-between">
          <div className="space-y-3 flex-1">
            <Skeleton className="w-24 h-4" />
            <Skeleton className="w-16 h-9" />
            <Skeleton className="w-20 h-3" />
          </div>
          <Skeleton className="w-12 h-12 rounded-2xl" />
        </div>
      </CardContent>
    </Card>
  )
}

// Custom Tooltip for charts
function CustomTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null
  return (
    <div className="bg-white/95 backdrop-blur-sm border border-gray-200/60 rounded-xl shadow-xl p-3 min-w-[140px]">
      <p className="text-xs font-medium text-gray-500 mb-2">{label}</p>
      {payload.map((entry: any, i: number) => (
        <div key={i} className="flex items-center justify-between gap-4 text-sm">
          <div className="flex items-center gap-1.5">
            <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: entry.color }} />
            <span className="text-gray-600">{entry.name}</span>
          </div>
          <span className="font-bold tabular-nums">{entry.value}</span>
        </div>
      ))}
    </div>
  )
}

export default function DashboardPage() {
  const { campaign, labelAr, isFiltered } = useCampaign()
  const { data: stats, isLoading: statsLoading, refetch, isFetching } = useDashboardStats(campaign)
  const { data: chartData, isLoading: chartLoading } = useSubmissionsChart(campaign)
  const { data: govStats, isLoading: govLoading } = useGovernorateStats(campaign)
  const { data: roleDistribution, isLoading: roleLoading } = useRoleDistribution()

  const statCards: StatCardProps[] = stats ? [
    {
      title: 'إجمالي المستخدمين',
      value: formatNumber(stats.total_users),
      change: 8.2,
      icon: Users,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50',
      gradient: 'bg-gradient-to-r from-blue-500 to-blue-600',
      description: `${stats.active_users} نشط من أصل ${stats.total_users}`,
    },
    {
      title: 'إرساليات اليوم',
      value: formatNumber(stats.submissions_today),
      change: stats.submissions_trend,
      icon: FileStack,
      color: 'text-emerald-600',
      bgColor: 'bg-emerald-50',
      gradient: 'bg-gradient-to-r from-emerald-500 to-emerald-600',
      description: `${formatNumber(stats.total_submissions)} إجمالي`,
    },
    {
      title: 'بانتظار المراجعة',
      value: formatNumber(stats.pending_submissions),
      icon: Clock,
      color: 'text-amber-600',
      bgColor: 'bg-amber-50',
      gradient: 'bg-gradient-to-r from-amber-500 to-amber-600',
      description: `${stats.approval_rate.toFixed(1)}% معدل الاعتماد`,
    },
    {
      title: 'النواقص الحرجة',
      value: formatNumber(stats.critical_shortages),
      icon: AlertTriangle,
      color: 'text-red-600',
      bgColor: 'bg-red-50',
      gradient: 'bg-gradient-to-r from-red-500 to-red-600',
      description: `من أصل ${stats.total_shortages} ناقص`,
    },
  ] : []

  // Weekly highlight
  const weeklyHighlight = stats ? {
    submissions: stats.submissions_this_week,
    approvalRate: stats.approval_rate,
    activeUsers: stats.active_users,
    totalUsers: stats.total_users,
  } : null

  return (
    <div className="page-enter">
      <Header
        title="لوحة التحكم"
        subtitle={isFiltered ? `عرض بيانات: ${labelAr}` : 'مرحباً بك في لوحة إدارة منصة EPI Supervisor\'s'}
        onRefresh={() => refetch()}
      />

      <div className="p-6 space-y-6">
        {/* Stats Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-5">
          {statsLoading
            ? Array.from({ length: 4 }).map((_, i) => <StatCardSkeleton key={i} />)
            : statCards.map((card, i) => (
                <div key={i} className="animate-fade-in" style={{ animationDelay: `${i * 0.08}s` }}>
                  <StatCard {...card} />
                </div>
              ))
          }
        </div>

        {/* Charts Row */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
          {/* Submissions Trend Chart */}
          <Card className="xl:col-span-2 border-0 shadow-md overflow-hidden">
            <CardHeader className="flex flex-row items-center justify-between pb-3">
              <div>
                <CardTitle className="text-lg font-heading flex items-center gap-2">
                  <Activity className="w-5 h-5 text-primary" />
                  حركة الإرساليات
                </CardTitle>
                <CardDescription>آخر 30 يوم — معتمدة، مرفوضة، قيد المراجعة</CardDescription>
              </div>
              <Tabs defaultValue="30d">
                <TabsList className="h-8 bg-muted/50">
                  <TabsTrigger value="7d" className="text-xs px-3 data-[state=active]:bg-white">7 أيام</TabsTrigger>
                  <TabsTrigger value="30d" className="text-xs px-3 data-[state=active]:bg-white">30 يوم</TabsTrigger>
                </TabsList>
              </Tabs>
            </CardHeader>
            <CardContent className="pt-0">
              {chartLoading ? (
                <Skeleton className="w-full h-[300px] rounded-xl" />
              ) : (
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={chartData || []}>
                    <defs>
                      <linearGradient id="colorApproved" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                        <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                      </linearGradient>
                      <linearGradient id="colorRejected" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3} />
                        <stop offset="95%" stopColor="#ef4444" stopOpacity={0} />
                      </linearGradient>
                      <linearGradient id="colorPending" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                        <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                    <XAxis
                      dataKey="date"
                      tick={{ fontSize: 11, fill: '#6b7280' }}
                      tickFormatter={(v) => v.slice(5)}
                      stroke="#d1d5db"
                    />
                    <YAxis tick={{ fontSize: 11, fill: '#6b7280' }} stroke="#d1d5db" />
                    <Tooltip content={<CustomTooltip />} />
                    <Legend
                      formatter={(value) => <span className="text-xs font-medium">{value}</span>}
                    />
                    <Area type="monotone" dataKey="approved" name="معتمدة" stroke="#10b981" fill="url(#colorApproved)" strokeWidth={2.5} dot={false} activeDot={{ r: 5, strokeWidth: 2 }} />
                    <Area type="monotone" dataKey="pending" name="قيد المراجعة" stroke="#3b82f6" fill="url(#colorPending)" strokeWidth={2.5} dot={false} activeDot={{ r: 5, strokeWidth: 2 }} />
                    <Area type="monotone" dataKey="rejected" name="مرفوضة" stroke="#ef4444" fill="url(#colorRejected)" strokeWidth={2.5} dot={false} activeDot={{ r: 5, strokeWidth: 2 }} />
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* Role Distribution */}
          <Card className="border-0 shadow-md overflow-hidden">
            <CardHeader className="pb-2">
              <CardTitle className="text-lg font-heading flex items-center gap-2">
                <Shield className="w-5 h-5 text-primary" />
                توزيع الأدوار
              </CardTitle>
              <CardDescription>عدد المستخدمين حسب المستوى</CardDescription>
            </CardHeader>
            <CardContent>
              {roleLoading ? (
                <Skeleton className="w-full h-[280px] rounded-xl" />
              ) : (
                <>
                  <ResponsiveContainer width="100%" height={220}>
                    <PieChart>
                      <Pie
                        data={roleDistribution || []}
                        cx="50%"
                        cy="50%"
                        innerRadius={55}
                        outerRadius={85}
                        paddingAngle={4}
                        dataKey="value"
                        strokeWidth={2}
                        stroke="#fff"
                      >
                        {(roleDistribution || []).map((_, index) => (
                          <Cell key={`cell-${index}`} fill={CHART_COLORS[index % CHART_COLORS.length]} />
                        ))}
                      </Pie>
                      <Tooltip content={<CustomTooltip />} />
                    </PieChart>
                  </ResponsiveContainer>
                  {/* Legend as list */}
                  <div className="space-y-2 mt-2">
                    {(roleDistribution || []).map((item, i) => (
                      <div key={i} className="flex items-center justify-between text-sm">
                        <div className="flex items-center gap-2">
                          <div className="w-3 h-3 rounded-sm" style={{ backgroundColor: CHART_COLORS[i % CHART_COLORS.length] }} />
                          <span className="text-muted-foreground">{item.name}</span>
                        </div>
                        <span className="font-bold tabular-nums">{item.value}</span>
                      </div>
                    ))}
                  </div>
                </>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Governorate Stats & Quick Actions */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
          {/* Governorate Stats */}
          <Card className="xl:col-span-2 border-0 shadow-md overflow-hidden">
            <CardHeader className="pb-3">
              <CardTitle className="text-lg font-heading flex items-center gap-2">
                <BarChart3 className="w-5 h-5 text-primary" />
                الإرساليات حسب المحافظة
              </CardTitle>
              <CardDescription>أعلى المحافظات نشاطاً</CardDescription>
            </CardHeader>
            <CardContent className="pt-0">
              {govLoading ? (
                <div className="space-y-3">
                  {Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="w-full h-10 rounded-lg" />)}
                </div>
              ) : (
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={(govStats || []).slice(0, 10)} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" horizontal={false} />
                    <XAxis type="number" tick={{ fontSize: 11, fill: '#6b7280' }} stroke="#d1d5db" />
                    <YAxis
                      dataKey="name"
                      type="category"
                      tick={{ fontSize: 11, fill: '#6b7280' }}
                      stroke="#d1d5db"
                      width={80}
                    />
                    <Tooltip content={<CustomTooltip />} />
                    <Bar dataKey="submissions" name="إرساليات" radius={[0, 8, 8, 0]} fill="url(#barGradient)">
                      <defs>
                        <linearGradient id="barGradient" x1="0" y1="0" x2="1" y2="0">
                          <stop offset="0%" stopColor="#3b82f6" />
                          <stop offset="100%" stopColor="#6366f1" />
                        </linearGradient>
                      </defs>
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* Quick Stats */}
          <Card className="border-0 shadow-md overflow-hidden">
            <CardHeader className="pb-3">
              <CardTitle className="text-lg font-heading flex items-center gap-2">
                <Zap className="w-5 h-5 text-amber-500" />
                إحصائيات سريعة
              </CardTitle>
              <CardDescription>نظرة عامة على الأداء</CardDescription>
            </CardHeader>
            <CardContent className="space-y-5">
              {statsLoading ? (
                <div className="space-y-4">
                  {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="w-full h-12 rounded-lg" />)}
                </div>
              ) : stats ? (
                <>
                  {/* Approval Rate */}
                  <div className="space-y-2.5">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground flex items-center gap-1.5">
                        <CheckCircle2 className="w-4 h-4 text-emerald-500" />
                        معدل الاعتماد
                      </span>
                      <span className="font-bold tabular-nums">{stats.approval_rate.toFixed(1)}%</span>
                    </div>
                    <div className="relative">
                      <Progress value={stats.approval_rate} indicatorClassName="bg-gradient-to-r from-emerald-500 to-emerald-600" />
                    </div>
                  </div>

                  {/* Active Forms */}
                  <div className="space-y-2.5">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground flex items-center gap-1.5">
                        <FileText className="w-4 h-4 text-blue-500" />
                        النماذج النشطة
                      </span>
                      <span className="font-bold tabular-nums">{stats.active_forms} / {stats.total_forms}</span>
                    </div>
                    <Progress
                      value={stats.total_forms > 0 ? (stats.active_forms / stats.total_forms) * 100 : 0}
                      indicatorClassName="bg-gradient-to-r from-blue-500 to-blue-600"
                    />
                  </div>

                  {/* Active Users */}
                  <div className="space-y-2.5">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground flex items-center gap-1.5">
                        <Activity className="w-4 h-4 text-purple-500" />
                        المستخدمون النشطون
                      </span>
                      <span className="font-bold tabular-nums">{stats.active_users} / {stats.total_users}</span>
                    </div>
                    <Progress
                      value={stats.total_users > 0 ? (stats.active_users / stats.total_users) * 100 : 0}
                      indicatorClassName="bg-gradient-to-r from-purple-500 to-purple-600"
                    />
                  </div>

                  {/* Weekly Summary Card */}
                  <div className="p-4 rounded-2xl bg-gradient-to-br from-blue-500/5 via-indigo-500/5 to-purple-500/5 border border-blue-200/30 relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-24 h-24 bg-blue-400/10 rounded-full blur-2xl" />
                    <div className="relative flex items-center gap-4">
                      <div className="p-3 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 shadow-lg shadow-blue-500/20">
                        <Sparkles className="w-6 h-6 text-white" />
                      </div>
                      <div>
                        <p className="text-3xl font-heading font-bold bg-gradient-to-r from-blue-600 to-indigo-600 bg-clip-text text-transparent">
                          {formatNumber(stats.submissions_this_week)}
                        </p>
                        <p className="text-xs text-muted-foreground">إرسالية هذا الأسبوع</p>
                      </div>
                    </div>
                  </div>
                </>
              ) : null}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
