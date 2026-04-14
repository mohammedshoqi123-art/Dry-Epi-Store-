import { useState } from 'react'
import {
  MapPin, Users, FileStack, TrendingUp, AlertTriangle, Eye,
  ChevronDown, Search, Building2, Activity, BarChart3, Target
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Progress } from '@/components/ui/progress'
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs'
import { Input } from '@/components/ui/input'
import { Header } from '@/components/layout/header'
import { useGovernorates, useDistricts, useDashboardStats, useGovernorateStats } from '@/hooks/useApi'
import { formatNumber, cn } from '@/lib/utils'
import {
  BarChart, Bar, PieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend,
  XAxis, YAxis, CartesianGrid, Treemap
} from 'recharts'

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4', '#ec4899', '#84cc16', '#f97316', '#6366f1', '#14b8a6', '#e11d48', '#a855f7', '#22c55e', '#eab308', '#0ea5e9', '#d946ef', '#f43f5e', '#64748b']

export default function GovernoratesPage() {
  const [selectedGov, setSelectedGov] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const { data: governorates, isLoading } = useGovernorates()
  const { data: districts } = useDistricts(selectedGov || undefined)
  const { data: stats } = useDashboardStats()
  const { data: govStats } = useGovernorateStats()

  // Merge governorates with stats
  const enrichedGovs = (governorates || []).map(gov => {
    const statEntry = govStats?.find(s => s.name === gov.name_ar)
    return {
      ...gov,
      submissions: statEntry?.submissions || 0,
    }
  }).sort((a, b) => b.submissions - a.submissions)

  const filteredGovs = enrichedGovs.filter(g =>
    g.name_ar.includes(search) || g.name_en.toLowerCase().includes(search.toLowerCase())
  )

  const totalSubmissions = enrichedGovs.reduce((s, g) => s + g.submissions, 0)
  const maxSubmissions = enrichedGovs[0]?.submissions || 1

  // Treemap data
  const treemapData = enrichedGovs.map(g => ({
    name: g.name_ar,
    size: g.submissions || 1,
    fill: COLORS[enrichedGovs.indexOf(g) % COLORS.length],
  }))

  // Performance tiers
  const highPerformers = enrichedGovs.filter(g => g.submissions >= maxSubmissions * 0.7)
  const midPerformers = enrichedGovs.filter(g => g.submissions >= maxSubmissions * 0.3 && g.submissions < maxSubmissions * 0.7)
  const lowPerformers = enrichedGovs.filter(g => g.submissions < maxSubmissions * 0.3)

  return (
    <div className="page-enter">
      <Header
        title="المحافظات والمديريات"
        subtitle={`${enrichedGovs.length} محافظة — ${formatNumber(totalSubmissions)} إرسالية`}
      />

      <div className="p-6 space-y-6">
        {/* Summary Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-blue-50">
                  <MapPin className="w-5 h-5 text-blue-600" />
                </div>
                <div>
                  <p className="text-2xl font-heading font-bold">{enrichedGovs.length}</p>
                  <p className="text-xs text-muted-foreground">محافظة</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-emerald-50">
                  <TrendingUp className="w-5 h-5 text-emerald-600" />
                </div>
                <div>
                  <p className="text-2xl font-heading font-bold text-emerald-600">{highPerformers.length}</p>
                  <p className="text-xs text-muted-foreground">أداء عالي</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-amber-50">
                  <Activity className="w-5 h-5 text-amber-600" />
                </div>
                <div>
                  <p className="text-2xl font-heading font-bold text-amber-600">{midPerformers.length}</p>
                  <p className="text-xs text-muted-foreground">أداء متوسط</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-red-50">
                  <AlertTriangle className="w-5 h-5 text-red-600" />
                </div>
                <div>
                  <p className="text-2xl font-heading font-bold text-red-600">{lowPerformers.length}</p>
                  <p className="text-xs text-muted-foreground">يحتاج دعم</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Charts */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
          {/* Bar Chart */}
          <Card className="xl:col-span-2">
            <CardHeader>
              <CardTitle className="text-base font-heading">الإرساليات حسب المحافظة</CardTitle>
              <CardDescription>ترتيب تنازلي حسب عدد الإرساليات</CardDescription>
            </CardHeader>
            <CardContent>
              {isLoading ? <Skeleton className="w-full h-[400px]" /> : (
                <ResponsiveContainer width="100%" height={400}>
                  <BarChart data={enrichedGovs.slice(0, 15)} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" horizontal={false} />
                    <XAxis type="number" tick={{ fontSize: 10 }} stroke="hsl(var(--muted-foreground))" />
                    <YAxis dataKey="name_ar" type="category" tick={{ fontSize: 10 }} width={80} stroke="hsl(var(--muted-foreground))" />
                    <Tooltip contentStyle={{ backgroundColor: 'hsl(var(--popover))', border: '1px solid hsl(var(--border))', borderRadius: '8px' }} />
                    <Bar dataKey="submissions" name="إرساليات" radius={[0, 6, 6, 0]}>
                      {enrichedGovs.slice(0, 15).map((g, i) => (
                        <Cell
                          key={i}
                          fill={g.submissions >= maxSubmissions * 0.7 ? '#10b981' :
                                g.submissions >= maxSubmissions * 0.3 ? '#3b82f6' : '#ef4444'}
                        />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* Pie Chart */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base font-heading">توزيع الإرساليات</CardTitle>
              <CardDescription>نسبة كل محافظة</CardDescription>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={350}>
                <PieChart>
                  <Pie
                    data={enrichedGovs.filter(g => g.submissions > 0).slice(0, 10)}
                    cx="50%"
                    cy="50%"
                    outerRadius={110}
                    innerRadius={55}
                    paddingAngle={2}
                    dataKey="submissions"
                    nameKey="name_ar"
                  >
                    {enrichedGovs.filter(g => g.submissions > 0).slice(0, 10).map((_, i) => (
                      <Cell key={i} fill={COLORS[i % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip contentStyle={{ backgroundColor: 'hsl(var(--popover))', border: '1px solid hsl(var(--border))', borderRadius: '8px' }} />
                  <Legend formatter={(value) => <span className="text-[10px]">{value}</span>} />
                </PieChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </div>

        {/* Search & Governorate Cards */}
        <div className="relative">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="بحث عن محافظة..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pr-10 max-w-md"
          />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {isLoading
            ? Array.from({ length: 6 }).map((_, i) => (
                <Card key={i}><CardContent className="p-5"><Skeleton className="w-full h-32" /></CardContent></Card>
              ))
            : filteredGovs.map((gov, idx) => {
                const percentage = maxSubmissions > 0 ? (gov.submissions / maxSubmissions) * 100 : 0
                const tier = percentage >= 70 ? 'high' : percentage >= 30 ? 'mid' : 'low'
                return (
                  <Card
                    key={gov.id}
                    className={cn(
                      'cursor-pointer hover:shadow-lg transition-all duration-200 overflow-hidden group',
                      selectedGov === gov.id && 'ring-2 ring-primary'
                    )}
                    onClick={() => setSelectedGov(selectedGov === gov.id ? null : gov.id)}
                  >
                    <div className={cn(
                      'h-1',
                      tier === 'high' ? 'bg-emerald-500' : tier === 'mid' ? 'bg-blue-500' : 'bg-red-500'
                    )} />
                    <CardContent className="p-5">
                      <div className="flex items-start justify-between mb-3">
                        <div>
                          <h3 className="font-heading font-bold text-lg">{gov.name_ar}</h3>
                          <p className="text-xs text-muted-foreground">{gov.name_en} — {gov.code}</p>
                        </div>
                        <Badge className={cn(
                          'text-[10px]',
                          tier === 'high' ? 'bg-emerald-100 text-emerald-700' :
                          tier === 'mid' ? 'bg-blue-100 text-blue-700' : 'bg-red-100 text-red-700'
                        )}>
                          {tier === 'high' ? 'ممتاز' : tier === 'mid' ? 'متوسط' : 'يحتاج دعم'}
                        </Badge>
                      </div>

                      <div className="flex items-end justify-between mb-2">
                        <div>
                          <p className="text-3xl font-heading font-bold">{formatNumber(gov.submissions)}</p>
                          <p className="text-xs text-muted-foreground">إرسالية</p>
                        </div>
                        <div className="text-left">
                          <p className="text-sm font-bold text-muted-foreground">{percentage.toFixed(0)}%</p>
                          <p className="text-[10px] text-muted-foreground">من الأعلى</p>
                        </div>
                      </div>

                      <Progress value={percentage} className="h-1.5" />

                      {/* Expanded: Districts */}
                      {selectedGov === gov.id && districts && (
                        <div className="mt-4 pt-4 border-t animate-fade-in">
                          <p className="text-xs text-muted-foreground mb-2 flex items-center gap-1">
                            <Building2 className="w-3 h-3" /> المديريات ({districts.length})
                          </p>
                          <div className="flex flex-wrap gap-1.5 max-h-24 overflow-y-auto">
                            {districts.map((d) => (
                              <Badge key={d.id} variant="outline" className="text-[10px]">
                                {d.name_ar}
                              </Badge>
                            ))}
                          </div>
                        </div>
                      )}
                    </CardContent>
                  </Card>
                )
              })}
        </div>
      </div>
    </div>
  )
}
