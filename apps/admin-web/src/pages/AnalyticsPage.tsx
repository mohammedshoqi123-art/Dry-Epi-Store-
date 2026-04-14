import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { Header } from '@/components/layout/header'
import { useDashboardStats, useSubmissionsChart, useGovernorateStats, useRoleDistribution } from '@/hooks/useApi'
import { formatNumber } from '@/lib/utils'
import {
  BarChart, Bar, PieChart, Pie, Cell, LineChart, Line,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
  RadarChart, Radar, PolarGrid, PolarAngleAxis, PolarRadiusAxis,
  AreaChart, Area
} from 'recharts'

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4']

export default function AnalyticsPage() {
  const { data: stats, isLoading: statsLoading } = useDashboardStats()
  const { data: chartData, isLoading: chartLoading } = useSubmissionsChart()
  const { data: govStats, isLoading: govLoading } = useGovernorateStats()
  const { data: roleDistribution, isLoading: roleLoading } = useRoleDistribution()

  const statusData = stats ? [
    { name: 'معتمدة', value: stats.approved_submissions, color: '#10b981' },
    { name: 'مرفوضة', value: stats.rejected_submissions, color: '#ef4444' },
    { name: 'قيد المراجعة', value: stats.pending_submissions, color: '#3b82f6' },
    { name: 'مسودة', value: stats.draft_submissions, color: '#6b7280' },
  ] : []

  return (
    <div className="page-enter">
      <Header title="التحليلات" subtitle="رؤى وإحصائيات تفصيلية" />

      <div className="p-6 space-y-6">
        {/* Summary Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {statsLoading ? Array.from({ length: 4 }).map((_, i) => (
            <Card key={i}><CardContent className="p-4"><Skeleton className="w-full h-16" /></CardContent></Card>
          )) : stats && [
            { label: 'معدل الاعتماد', value: `${stats.approval_rate.toFixed(1)}%`, color: 'text-emerald-600' },
            { label: 'الإرساليات اليوم', value: stats.submissions_today, color: 'text-blue-600' },
            { label: 'هذا الأسبوع', value: stats.submissions_this_week, color: 'text-purple-600' },
            { label: 'النماذج النشطة', value: `${stats.active_forms}/${stats.total_forms}`, color: 'text-amber-600' },
          ].map((item, i) => (
            <Card key={i}>
              <CardContent className="p-4 text-center">
                <p className="text-sm text-muted-foreground">{item.label}</p>
                <p className={`text-2xl font-heading font-bold mt-1 ${item.color}`}>{item.value}</p>
              </CardContent>
            </Card>
          ))}
        </div>

        <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
          {/* Submissions Over Time */}
          <Card>
            <CardHeader>
              <CardTitle className="font-heading">الإرساليات عبر الزمن</CardTitle>
              <CardDescription>آخر 30 يوم</CardDescription>
            </CardHeader>
            <CardContent>
              {chartLoading ? <Skeleton className="w-full h-[300px]" /> : (
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={chartData || []}>
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                    <XAxis dataKey="date" tick={{ fontSize: 10 }} tickFormatter={v => v.slice(5)} stroke="hsl(var(--muted-foreground))" />
                    <YAxis tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" />
                    <Tooltip contentStyle={{ backgroundColor: 'hsl(var(--popover))', border: '1px solid hsl(var(--border))', borderRadius: '8px' }} />
                    <Area type="monotone" dataKey="approved" name="معتمدة" stroke="#10b981" fill="#10b981" fillOpacity={0.2} strokeWidth={2} />
                    <Area type="monotone" dataKey="pending" name="معلقة" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.2} strokeWidth={2} />
                    <Area type="monotone" dataKey="rejected" name="مرفوضة" stroke="#ef4444" fill="#ef4444" fillOpacity={0.2} strokeWidth={2} />
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* Status Distribution */}
          <Card>
            <CardHeader>
              <CardTitle className="font-heading">توزيع الحالات</CardTitle>
              <CardDescription>نسبة الإرساليات حسب الحالة</CardDescription>
            </CardHeader>
            <CardContent>
              {statsLoading ? <Skeleton className="w-full h-[300px]" /> : (
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie data={statusData} cx="50%" cy="50%" outerRadius={100} innerRadius={60} paddingAngle={3} dataKey="value" label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}>
                      {statusData.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* Governorate Performance */}
          <Card className="xl:col-span-2">
            <CardHeader>
              <CardTitle className="font-heading">أداء المحافظات</CardTitle>
              <CardDescription>عدد الإرساليات حسب المحافظة</CardDescription>
            </CardHeader>
            <CardContent>
              {govLoading ? <Skeleton className="w-full h-[400px]" /> : (
                <ResponsiveContainer width="100%" height={400}>
                  <BarChart data={govStats || []}>
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                    <XAxis dataKey="name" tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" angle={-45} textAnchor="end" height={80} />
                    <YAxis tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" />
                    <Tooltip contentStyle={{ backgroundColor: 'hsl(var(--popover))', border: '1px solid hsl(var(--border))', borderRadius: '8px' }} />
                    <Bar dataKey="submissions" name="إرساليات" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
