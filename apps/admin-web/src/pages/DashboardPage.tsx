import { useState } from 'react'
import {
  Users, FileText, FileStack, AlertTriangle, TrendingUp, TrendingDown,
  CheckCircle2, XCircle, Clock, Activity, BarChart3, ArrowUpRight,
  Shield, Zap, Target
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Skeleton } from '@/components/ui/skeleton'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Header } from '@/components/layout/header'
import { useDashboardStats, useSubmissionsChart, useGovernorateStats, useRoleDistribution } from '@/hooks/useApi'
import { formatNumber, formatPercent, cn } from '@/lib/utils'
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
}

function StatCard({ title, value, change, icon: Icon, color, bgColor, description }: StatCardProps) {
  return (
    <Card className="stat-card-glow hover:shadow-card-hover transition-all duration-300 group overflow-hidden relative">
      <CardContent className="p-6">
        <div className="flex items-start justify-between">
          <div className="space-y-2">
            <p className="text-sm font-medium text-muted-foreground">{title}</p>
            <div className="flex items-baseline gap-2">
              <span className="text-3xl font-heading font-bold count-up">{value}</span>
              {change !== undefined && (
                <span className={cn(
                  'text-xs font-medium flex items-center gap-0.5',
                  change >= 0 ? 'text-emerald-600' : 'text-red-600'
                )}>
                  {change >= 0 ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
                  {formatPercent(change)}
                </span>
              )}
            </div>
            {description && <p className="text-xs text-muted-foreground">{description}</p>}
          </div>
          <div className={cn('p-3 rounded-xl transition-transform duration-300 group-hover:scale-110', bgColor)}>
            <Icon className={cn('w-6 h-6', color)} />
          </div>
        </div>
        {/* Animated bottom bar */}
        <div className={cn('absolute bottom-0 left-0 right-0 h-1 opacity-0 group-hover:opacity-100 transition-opacity', bgColor)} />
      </CardContent>
    </Card>
  )
}

function StatCardSkeleton() {
  return (
    <Card>
      <CardContent className="p-6">
        <div className="flex items-start justify-between">
          <div className="space-y-3 flex-1">
            <Skeleton className="w-24 h-4" />
            <Skeleton className="w-16 h-8" />
          </div>
          <Skeleton className="w-12 h-12 rounded-xl" />
        </div>
      </CardContent>
    </Card>
  )
}

export default function DashboardPage() {
  const { data: stats, isLoading: statsLoading, refetch } = useDashboardStats()
  const { data: chartData, isLoading: chartLoading } = useSubmissionsChart()
  const { data: govStats, isLoading: govLoading } = useGovernorateStats()
  const { data: roleDistribution, isLoading: roleLoading } = useRoleDistribution()

  const statCards: StatCardProps[] = stats ? [
    {
      title: 'إجمالي المستخدمين',
      value: formatNumber(stats.total_users),
      change: 8.2,
      icon: Users,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50',
      description: `${stats.active_users} نشط`,
    },
    {
      title: 'الإرساليات',
      value: formatNumber(stats.total_submissions),
      change: stats.submissions_trend,
      icon: FileStack,
      color: 'text-emerald-600',
      bgColor: 'bg-emerald-50',
      description: `${stats.submissions_today} اليوم`,
    },
    {
      title: 'بانتظار المراجعة',
      value: formatNumber(stats.pending_submissions),
      icon: Clock,
      color: 'text-amber-600',
      bgColor: 'bg-amber-50',
      description: `${stats.approval_rate.toFixed(0)}% معدل الاعتماد`,
    },
    {
      title: 'النواقص الحرجة',
      value: formatNumber(stats.critical_shortages),
      icon: AlertTriangle,
      color: 'text-red-600',
      bgColor: 'bg-red-50',
      description: `من أصل ${stats.total_shortages} ناقص`,
    },
  ] : []

  return (
    <div className="page-enter">
      <Header
        title="لوحة التحكم"
        subtitle="مرحباً بك في لوحة إدارة منصة مشرف EPI"
        onRefresh={() => refetch()}
      />

      <div className="p-6 space-y-6">
        {/* Stats Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
          {statsLoading
            ? Array.from({ length: 4 }).map((_, i) => <StatCardSkeleton key={i} />)
            : statCards.map((card, i) => (
                <div key={i} className="animate-fade-in" style={{ animationDelay: `${i * 0.1}s` }}>
                  <StatCard {...card} />
                </div>
              ))
          }
        </div>

        {/* Charts Row */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
          {/* Submissions Trend Chart */}
          <Card className="xl:col-span-2">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <div>
                <CardTitle className="text-lg font-heading">حركة الإرساليات</CardTitle>
                <CardDescription>آخر 30 يوم — معتمدة، مرفوضة، قيد المراجعة</CardDescription>
              </div>
              <Tabs defaultValue="30d">
                <TabsList className="h-8">
                  <TabsTrigger value="7d" className="text-xs px-2">7 أيام</TabsTrigger>
                  <TabsTrigger value="30d" className="text-xs px-2">30 يوم</TabsTrigger>
                </TabsList>
              </Tabs>
            </CardHeader>
            <CardContent>
              {chartLoading ? (
                <Skeleton className="w-full h-[300px]" />
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
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                    <XAxis
                      dataKey="date"
                      tick={{ fontSize: 11 }}
                      tickFormatter={(v) => v.slice(5)}
                      stroke="hsl(var(--muted-foreground))"
                    />
                    <YAxis tick={{ fontSize: 11 }} stroke="hsl(var(--muted-foreground))" />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: 'hsl(var(--popover))',
                        border: '1px solid hsl(var(--border))',
                        borderRadius: '8px',
                        direction: 'rtl',
                      }}
                    />
                    <Legend />
                    <Area type="monotone" dataKey="approved" name="معتمدة" stroke="#10b981" fill="url(#colorApproved)" strokeWidth={2} />
                    <Area type="monotone" dataKey="pending" name="قيد المراجعة" stroke="#3b82f6" fill="url(#colorPending)" strokeWidth={2} />
                    <Area type="monotone" dataKey="rejected" name="مرفوضة" stroke="#ef4444" fill="url(#colorRejected)" strokeWidth={2} />
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* Role Distribution */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg font-heading">توزيع الأدوار</CardTitle>
              <CardDescription>عدد المستخدمين حسب المستوى</CardDescription>
            </CardHeader>
            <CardContent>
              {roleLoading ? (
                <Skeleton className="w-full h-[300px]" />
              ) : (
                <ResponsiveContainer width="100%" height={250}>
                  <PieChart>
                    <Pie
                      data={roleDistribution || []}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={90}
                      paddingAngle={4}
                      dataKey="value"
                    >
                      {(roleDistribution || []).map((_, index) => (
                        <Cell key={`cell-${index}`} fill={CHART_COLORS[index % CHART_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip
                      contentStyle={{
                        backgroundColor: 'hsl(var(--popover))',
                        border: '1px solid hsl(var(--border))',
                        borderRadius: '8px',
                        direction: 'rtl',
                      }}
                    />
                    <Legend
                      formatter={(value) => <span className="text-xs">{value}</span>}
                    />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Governorate Stats & Quick Actions */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
          {/* Governorate Stats */}
          <Card className="xl:col-span-2">
            <CardHeader>
              <CardTitle className="text-lg font-heading">الإرساليات حسب المحافظة</CardTitle>
              <CardDescription>أعلى المحافظات نشاطاً</CardDescription>
            </CardHeader>
            <CardContent>
              {govLoading ? (
                <div className="space-y-3">
                  {Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="w-full h-10" />)}
                </div>
              ) : (
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={(govStats || []).slice(0, 10)} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" horizontal={false} />
                    <XAxis type="number" tick={{ fontSize: 11 }} stroke="hsl(var(--muted-foreground))" />
                    <YAxis
                      dataKey="name"
                      type="category"
                      tick={{ fontSize: 11 }}
                      stroke="hsl(var(--muted-foreground))"
                      width={80}
                    />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: 'hsl(var(--popover))',
                        border: '1px solid hsl(var(--border))',
                        borderRadius: '8px',
                        direction: 'rtl',
                      }}
                    />
                    <Bar dataKey="submissions" name="إرساليات" fill="#3b82f6" radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* Quick Stats */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg font-heading">إحصائيات سريعة</CardTitle>
              <CardDescription>نظرة عامة على الأداء</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              {statsLoading ? (
                <div className="space-y-4">
                  {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="w-full h-12" />)}
                </div>
              ) : stats ? (
                <>
                  {/* Approval Rate */}
                  <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground flex items-center gap-1.5">
                        <CheckCircle2 className="w-4 h-4 text-emerald-500" />
                        معدل الاعتماد
                      </span>
                      <span className="font-bold">{stats.approval_rate.toFixed(1)}%</span>
                    </div>
                    <Progress value={stats.approval_rate} indicatorClassName="bg-emerald-500" />
                  </div>

                  {/* Active Forms */}
                  <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground flex items-center gap-1.5">
                        <FileText className="w-4 h-4 text-blue-500" />
                        النماذج النشطة
                      </span>
                      <span className="font-bold">{stats.active_forms} / {stats.total_forms}</span>
                    </div>
                    <Progress
                      value={stats.total_forms > 0 ? (stats.active_forms / stats.total_forms) * 100 : 0}
                      indicatorClassName="bg-blue-500"
                    />
                  </div>

                  {/* Active Users */}
                  <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground flex items-center gap-1.5">
                        <Activity className="w-4 h-4 text-purple-500" />
                        المستخدمون النشطون
                      </span>
                      <span className="font-bold">{stats.active_users} / {stats.total_users}</span>
                    </div>
                    <Progress
                      value={stats.total_users > 0 ? (stats.active_users / stats.total_users) * 100 : 0}
                      indicatorClassName="bg-purple-500"
                    />
                  </div>

                  {/* This Week */}
                  <div className="p-4 rounded-xl bg-gradient-to-br from-primary/5 to-primary/10 border border-primary/20">
                    <div className="flex items-center gap-3">
                      <div className="p-2 rounded-lg bg-primary/10">
                        <Zap className="w-5 h-5 text-primary" />
                      </div>
                      <div>
                        <p className="text-2xl font-heading font-bold">{formatNumber(stats.submissions_this_week)}</p>
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
