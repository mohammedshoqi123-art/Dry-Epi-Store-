import { useState } from 'react'
import {
  Users, FileText, FileStack, AlertTriangle, TrendingUp, TrendingDown,
  CheckCircle2, Clock, Activity, BarChart3, Shield, Zap,
  Sparkles, Package, ArrowUpDown, Truck, RefreshCw, Eye,
  CalendarDays, Layers, Database, Globe
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Skeleton } from '@/components/ui/skeleton'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Button } from '@/components/ui/button'
import { Header } from '@/components/layout/header'
import { useDashboardStats, useSubmissionsChart, useGovernorateStats, useRoleDistribution, useWarehouseDashboardStats } from '@/hooks/useApi'
import { formatNumber, formatPercent, cn } from '@/lib/utils'
import { useCampaign } from '@/lib/campaign-context'
import {
  AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend
} from 'recharts'

const COLORS = {
  blue: '#3b82f6', emerald: '#10b981', amber: '#f59e0b', red: '#ef4444',
  purple: '#8b5cf6', cyan: '#06b6d4', pink: '#ec4899', indigo: '#6366f1',
  teal: '#14b8a6', orange: '#f97316'
}
const CHART_PALETTE = [COLORS.blue, COLORS.emerald, COLORS.amber, COLORS.red, COLORS.purple, COLORS.cyan, COLORS.pink]

/* ─── Animated Stat Card ─────────────────────────────────── */
interface StatCardProps {
  title: string; value: number | string; change?: number
  icon: React.ElementType; color: string; bgFrom: string; bgTo: string
  description?: string; pulse?: boolean
}
function StatCard({ title, value, change, icon: Icon, color, bgFrom, bgTo, description, pulse }: StatCardProps) {
  return (
    <Card className={cn(
      'group relative overflow-hidden border-0 shadow-sm hover:shadow-xl transition-all duration-500 hover:-translate-y-1',
      pulse && 'ring-2 ring-red-200/60 animate-pulse-gentle'
    )}>
      <div className={cn('absolute inset-0 opacity-[0.04] bg-gradient-to-br', bgFrom, bgTo)} />
      <CardContent className="p-5 relative">
        <div className="flex items-start justify-between">
          <div className="space-y-2 flex-1">
            <p className="text-[13px] font-medium text-muted-foreground/80 tracking-wide">{title}</p>
            <div className="flex items-baseline gap-2.5">
              <span className="text-[28px] font-extrabold tracking-tight font-sans">{value}</span>
              {change !== undefined && (
                <span className={cn(
                  'text-[11px] font-bold flex items-center gap-0.5 px-2 py-0.5 rounded-full',
                  change >= 0 ? 'text-emerald-700 bg-emerald-50 border border-emerald-100' : 'text-red-700 bg-red-50 border border-red-100'
                )}>
                  {change >= 0 ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
                  {formatPercent(change)}
                </span>
              )}
            </div>
            {description && <p className="text-[11px] text-muted-foreground/60">{description}</p>}
          </div>
          <div className={cn(
            'p-3 rounded-2xl transition-all duration-500 group-hover:scale-110 group-hover:rotate-6',
            'bg-gradient-to-br shadow-lg', bgFrom, bgTo
          )} style={{ boxShadow: `0 8px 20px -4px ${color}33` }}>
            <Icon className="w-5 h-5 text-white" />
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
function StatSkeleton() {
  return <Card className="border-0 shadow-sm"><CardContent className="p-5"><div className="flex items-start justify-between"><div className="space-y-3 flex-1"><Skeleton className="w-20 h-3"/><Skeleton className="w-14 h-8"/><Skeleton className="w-16 h-2"/></div><Skeleton className="w-11 h-11 rounded-2xl"/></div></CardContent></Card>
}

/* ─── Chart Tooltip ─────────────────────────────────────── */
function ChartTip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null
  return (
    <div className="bg-white/95 backdrop-blur-sm border border-gray-100 rounded-2xl shadow-2xl p-4 min-w-[160px]">
      <p className="text-[11px] font-semibold text-gray-400 mb-2.5 tracking-wide">{label}</p>
      {payload.map((e: any, i: number) => (
        <div key={i} className="flex items-center justify-between gap-5 py-1">
          <div className="flex items-center gap-2">
            <div className="w-2.5 h-2.5 rounded-full ring-2 ring-white shadow-sm" style={{ backgroundColor: e.color }}/>
            <span className="text-[12px] text-gray-500">{e.name}</span>
          </div>
          <span className="text-[13px] font-bold tabular-nums text-gray-800">{formatNumber(e.value)}</span>
        </div>
      ))}
    </div>
  )
}

/* ─── Page ───────────────────────────────────────────────── */
export default function DashboardPage() {
  const { campaign, labelAr, isFiltered } = useCampaign()
  const { data: stats, isLoading: sL, refetch } = useDashboardStats(campaign)
  const { data: chart, isLoading: cL } = useSubmissionsChart(campaign)
  const { data: gov, isLoading: gL } = useGovernorateStats(campaign)
  const { data: roles, isLoading: rL } = useRoleDistribution()
  const { data: whStats } = useWarehouseDashboardStats()

  const cards: StatCardProps[] = stats ? [
    { title: 'المستخدمون', value: formatNumber(stats.total_users), change: 8.2, icon: Users, color: COLORS.blue, bgFrom: 'from-blue-500', bgTo: 'to-blue-600', description: `${stats.active_users} نشط` },
    { title: 'إرساليات اليوم', value: formatNumber(stats.submissions_today), change: stats.submissions_trend, icon: FileStack, color: COLORS.emerald, bgFrom: 'from-emerald-500', bgTo: 'to-emerald-600', description: `${formatNumber(stats.total_submissions)} إجمالي` },
    { title: 'بانتظار المراجعة', value: formatNumber(stats.pending_submissions), icon: Clock, color: COLORS.amber, bgFrom: 'from-amber-500', bgTo: 'to-amber-600', description: `${stats.approval_rate.toFixed(1)}% معدل الاعتماد` },
    { title: 'نواقص حرجة', value: formatNumber(stats.critical_shortages), icon: AlertTriangle, color: COLORS.red, bgFrom: 'from-red-500', bgTo: 'to-red-600', description: `من ${stats.total_shortages} ناقص`, pulse: stats.critical_shortages > 0 },
  ] : []

  return (
    <div className="min-h-screen bg-[#f8fafc]">
      <Header title="لوحة التحكم" subtitle={isFiltered ? labelAr : 'نظرة شاملة على أداء المنصة'} onRefresh={() => refetch()}/>

      <div className="px-4 sm:px-6 lg:px-8 py-6 space-y-6 max-w-[1440px] mx-auto">

        {/* ─── Stats Row ─── */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {sL ? Array.from({length:4}).map((_,i)=><StatSkeleton key={i}/>)
            : cards.map((c,i)=><div key={i} className="animate-fade-in" style={{animationDelay:`${i*60}ms`}}><StatCard {...c}/></div>)}
        </div>

        {/* ─── Warehouse Quick Stats ─── */}
        {whStats && (
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {[
              { label: 'المخازن النشطة', val: whStats.active_warehouses, icon: Database, c: COLORS.indigo },
              { label: 'إجمالي المخزون', val: formatNumber(whStats.total_quantity), icon: Package, c: COLORS.teal },
              { label: 'حركات اليوم', val: whStats.today_movements, icon: ArrowUpDown, c: COLORS.purple },
              { label: 'قريب الانتهاء', val: whStats.expiring_soon, icon: CalendarDays, c: COLORS.orange },
            ].map((s,i)=>(
              <div key={i} className="flex items-center gap-3 bg-white rounded-xl px-4 py-3 shadow-sm border border-gray-100/80 hover:shadow-md transition-shadow">
                <div className="p-2 rounded-lg" style={{backgroundColor:`${s.c}15`}}><s.icon className="w-4 h-4" style={{color:s.c}}/></div>
                <div><p className="text-[11px] text-muted-foreground">{s.label}</p><p className="text-lg font-bold tabular-nums">{s.val}</p></div>
              </div>
            ))}
          </div>
        )}

        {/* ─── Charts ─── */}
        <div className="grid grid-cols-1 xl:grid-cols-5 gap-5">
          {/* Area Chart — 3 cols */}
          <Card className="xl:col-span-3 border-0 shadow-sm">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <div>
                <CardTitle className="text-base font-bold flex items-center gap-2">
                  <Activity className="w-4 h-4 text-blue-500"/>حركة الإرساليات
                </CardTitle>
                <CardDescription className="text-[11px]">آخر 30 يوم</CardDescription>
              </div>
              <Tabs defaultValue="30d">
                <TabsList className="h-7 bg-gray-50">
                  <TabsTrigger value="7d" className="text-[10px] px-2.5 data-[state=active]:bg-white data-[state=active]:shadow-sm">7 أيام</TabsTrigger>
                  <TabsTrigger value="30d" className="text-[10px] px-2.5 data-[state=active]:bg-white data-[state=active]:shadow-sm">30 يوم</TabsTrigger>
                </TabsList>
              </Tabs>
            </CardHeader>
            <CardContent className="pt-0">
              {cL ? <Skeleton className="w-full h-[280px]"/> : (
                <ResponsiveContainer width="100%" height={280}>
                  <AreaChart data={chart||[]}>
                    <defs>
                      <linearGradient id="gA" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor={COLORS.emerald} stopOpacity={0.25}/><stop offset="100%" stopColor={COLORS.emerald} stopOpacity={0}/></linearGradient>
                      <linearGradient id="gP" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor={COLORS.blue} stopOpacity={0.2}/><stop offset="100%" stopColor={COLORS.blue} stopOpacity={0}/></linearGradient>
                      <linearGradient id="gR" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor={COLORS.red} stopOpacity={0.15}/><stop offset="100%" stopColor={COLORS.red} stopOpacity={0}/></linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9"/>
                    <XAxis dataKey="date" tick={{fontSize:10,fill:'#94a3b8'}} tickFormatter={v=>v.slice(5)} stroke="none"/>
                    <YAxis tick={{fontSize:10,fill:'#94a3b8'}} stroke="none"/>
                    <Tooltip content={<ChartTip/>}/>
                    <Legend formatter={v=><span className="text-[11px] font-medium text-gray-500">{v}</span>}/>
                    <Area type="monotone" dataKey="approved" name="معتمدة" stroke={COLORS.emerald} fill="url(#gA)" strokeWidth={2.5} dot={false} activeDot={{r:4,strokeWidth:2}}/>
                    <Area type="monotone" dataKey="pending" name="قيد المراجعة" stroke={COLORS.blue} fill="url(#gP)" strokeWidth={2.5} dot={false} activeDot={{r:4,strokeWidth:2}}/>
                    <Area type="monotone" dataKey="rejected" name="مرفوضة" stroke={COLORS.red} fill="url(#gR)" strokeWidth={2} dot={false} activeDot={{r:4,strokeWidth:2}}/>
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* Donut — 2 cols */}
          <Card className="xl:col-span-2 border-0 shadow-sm">
            <CardHeader className="pb-1">
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <Shield className="w-4 h-4 text-purple-500"/>توزيع الأدوار
              </CardTitle>
              <CardDescription className="text-[11px]">حسب المستوى الوظيفي</CardDescription>
            </CardHeader>
            <CardContent>
              {rL ? <Skeleton className="w-full h-[260px]"/> : (
                <div className="flex flex-col items-center">
                  <ResponsiveContainer width="100%" height={180}>
                    <PieChart>
                      <Pie data={roles||[]} cx="50%" cy="50%" innerRadius={52} outerRadius={78} paddingAngle={5} dataKey="value" strokeWidth={0}>
                        {(roles||[]).map((_,i)=><Cell key={i} fill={CHART_PALETTE[i%CHART_PALETTE.length]}/>)}
                      </Pie>
                      <Tooltip content={<ChartTip/>}/>
                    </PieChart>
                  </ResponsiveContainer>
                  <div className="grid grid-cols-2 gap-x-6 gap-y-1.5 w-full mt-1">
                    {(roles||[]).map((r:any,i:number)=>(
                      <div key={i} className="flex items-center gap-2 text-[12px]">
                        <div className="w-2.5 h-2.5 rounded-full" style={{backgroundColor:CHART_PALETTE[i%CHART_PALETTE.length]}}/>
                        <span className="text-gray-500 flex-1 truncate">{r.name}</span>
                        <span className="font-bold tabular-nums text-gray-700">{r.value}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* ─── Governorate + Quick Stats ─── */}
        <div className="grid grid-cols-1 xl:grid-cols-5 gap-5">
          {/* Governorate Bar Chart */}
          <Card className="xl:col-span-3 border-0 shadow-sm">
            <CardHeader className="pb-2">
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <BarChart3 className="w-4 h-4 text-blue-500"/>الإرساليات حسب المحافظة
              </CardTitle>
              <CardDescription className="text-[11px]">أعلى المحافظات نشاطاً</CardDescription>
            </CardHeader>
            <CardContent className="pt-0">
              {gL ? <div className="space-y-2">{Array.from({length:5}).map((_,i)=><Skeleton key={i} className="w-full h-8"/>)}</div> : (
                <ResponsiveContainer width="100%" height={280}>
                  <BarChart data={(gov||[]).slice(0,10)} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" horizontal={false}/>
                    <XAxis type="number" tick={{fontSize:10,fill:'#94a3b8'}} stroke="none"/>
                    <YAxis dataKey="name" type="category" tick={{fontSize:10,fill:'#64748b'}} stroke="none" width={80}/>
                    <Tooltip content={<ChartTip/>}/>
                    <Bar dataKey="submissions" name="إرساليات" radius={[0,6,6,0]} fill="url(#govGrad)">
                      <defs><linearGradient id="govGrad" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stopColor={COLORS.blue}/><stop offset="100%" stopColor={COLORS.indigo}/></linearGradient></defs>
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* KPI Sidebar */}
          <Card className="xl:col-span-2 border-0 shadow-sm">
            <CardHeader className="pb-2">
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <Zap className="w-4 h-4 text-amber-500"/>مؤشرات الأداء
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {sL ? Array.from({length:3}).map((_,i)=><Skeleton key={i} className="w-full h-10"/>) : stats ? (
                <>
                  {[
                    { label: 'معدل الاعتماد', val: `${stats.approval_rate.toFixed(1)}%`, pct: stats.approval_rate, icon: CheckCircle2, grad: 'from-emerald-400 to-emerald-600' },
                    { label: 'النماذج النشطة', val: `${stats.active_forms}/${stats.total_forms}`, pct: stats.total_forms ? (stats.active_forms/stats.total_forms)*100 : 0, icon: FileText, grad: 'from-blue-400 to-blue-600' },
                    { label: 'المستخدمون النشطون', val: `${stats.active_users}/${stats.total_users}`, pct: stats.total_users ? (stats.active_users/stats.total_users)*100 : 0, icon: Users, grad: 'from-purple-400 to-purple-600' },
                  ].map((k,i)=>(
                    <div key={i} className="p-3.5 rounded-xl bg-gray-50/80 border border-gray-100/60">
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-[12px] text-gray-500 flex items-center gap-1.5">
                          <k.icon className="w-3.5 h-3.5 text-gray-400"/>{k.label}
                        </span>
                        <span className="text-[14px] font-bold tabular-nums">{k.val}</span>
                      </div>
                      <Progress value={k.pct} className="h-1.5" indicatorClassName={cn('bg-gradient-to-r', k.grad)}/>
                    </div>
                  ))}

                  {/* Weekly highlight */}
                  <div className="p-4 rounded-2xl bg-gradient-to-br from-blue-600 via-indigo-600 to-purple-600 text-white relative overflow-hidden">
                    <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGRlZnM+PHBhdHRlcm4gaWQ9ImciIHdpZHRoPSI2MCIgaGVpZ2h0PSI2MCIgcGF0dGVyblVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+PGNpcmNsZSBjeD0iMzAiIGN5PSIzMCIgcj0iMC41IiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMDgpIi8+PC9wYXR0ZXJuPjwvZGVmcz48cmVjdCBmaWxsPSJ1cmwoI2cpIiB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIi8+PC9zdmc+')] opacity-50"/>
                    <div className="relative flex items-center gap-4">
                      <div className="p-3 rounded-xl bg-white/20 backdrop-blur-sm">
                        <Sparkles className="w-6 h-6"/>
                      </div>
                      <div>
                        <p className="text-3xl font-extrabold tracking-tight">{formatNumber(stats.submissions_this_week)}</p>
                        <p className="text-[11px] opacity-80">إرسالية هذا الأسبوع</p>
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
