import { useState } from 'react'
import {
  Package, Warehouse as WarehouseIcon, TrendingUp, AlertTriangle,
  ArrowUpDown, Clock, CheckCircle2, XCircle, Search, Filter,
  RefreshCw, Eye, MapPin, Calendar, BarChart3, Truck
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Skeleton } from '@/components/ui/skeleton'
import { Progress } from '@/components/ui/progress'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Header } from '@/components/layout/header'
import {
  useWarehouseDashboardStats, useWarehouses, useAllStockLevels,
  useStockMovements, useWarehouseAlerts, useItemCategories
} from '@/hooks/useApi'
import { formatNumber, cn } from '@/lib/utils'
import {
  MOVEMENT_TYPE_LABELS, MOVEMENT_STATUS_LABELS, MOVEMENT_STATUS_COLORS,
  ALERT_TYPE_WH_LABELS, ALERT_SEVERITY_WH_COLORS
} from '@/types/database'
import {
  BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer
} from 'recharts'

const CHART_COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4', '#ec4899']

interface WHStatCardProps {
  title: string
  value: number | string
  icon: React.ElementType
  color: string
  bgColor: string
  subtitle?: string
  alert?: boolean
}

function WHStatCard({ title, value, icon: Icon, color, bgColor, subtitle, alert }: WHStatCardProps) {
  return (
    <Card className={cn(
      'group relative overflow-hidden hover:shadow-lg transition-all duration-300 border-0 shadow-md',
      alert && 'ring-2 ring-red-200'
    )}>
      <CardContent className="p-5">
        <div className="flex items-start justify-between">
          <div className="space-y-1.5">
            <p className="text-sm font-medium text-muted-foreground">{title}</p>
            <span className="text-2xl font-heading font-bold tabular-nums">{value}</span>
            {subtitle && <p className="text-xs text-muted-foreground">{subtitle}</p>}
          </div>
          <div className={cn('p-2.5 rounded-xl transition-all group-hover:scale-110', bgColor)}>
            <Icon className={cn('w-5 h-5', color)} />
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

function WHStatSkeleton() {
  return (
    <Card className="border-0 shadow-md">
      <CardContent className="p-5">
        <div className="flex items-start justify-between">
          <div className="space-y-2 flex-1">
            <Skeleton className="w-20 h-4" />
            <Skeleton className="w-14 h-8" />
          </div>
          <Skeleton className="w-10 h-10 rounded-xl" />
        </div>
      </CardContent>
    </Card>
  )
}

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

export default function WarehouseDashboardPage() {
  const { data: stats, isLoading: statsLoading, refetch, isFetching } = useWarehouseDashboardStats()
  const { data: warehouses, isLoading: whLoading } = useWarehouses()
  const { data: stockLevels, isLoading: stockLoading } = useAllStockLevels()
  const { data: movementsData, isLoading: movLoading } = useStockMovements({ pageSize: 10 })
  const { data: alerts, isLoading: alertLoading } = useWarehouseAlerts({ resolved: false })
  const { data: categories } = useItemCategories()

  const [activeTab, setActiveTab] = useState('overview')

  // Stock by warehouse for chart
  const stockByWarehouse = stockLevels ? (() => {
    const grouped: Record<string, { name: string; qty: number }> = {}
    stockLevels.forEach((s: any) => {
      const name = s.warehouses?.name_ar || 'غير معروف'
      if (!grouped[name]) grouped[name] = { name, qty: 0 }
      grouped[name].qty += s.quantity || 0
    })
    return Object.values(grouped).sort((a, b) => b.qty - a.qty).slice(0, 10)
  })() : []

  // Stock by category for pie chart
  const stockByCategory = stockLevels ? (() => {
    const grouped: Record<string, { name: string; qty: number }> = {}
    stockLevels.forEach((s: any) => {
      const name = s.items?.item_categories?.name_ar || 'أخرى'
      if (!grouped[name]) grouped[name] = { name, qty: 0 }
      grouped[name].qty += s.quantity || 0
    })
    return Object.values(grouped).filter(g => g.qty > 0)
  })() : []

  // Expiry alerts
  const expiryAlerts = stockLevels ? stockLevels.filter((s: any) => {
    if (!s.expiry_date) return false
    const days = Math.ceil((new Date(s.expiry_date).getTime() - Date.now()) / (1000 * 60 * 60 * 24))
    return days <= 90
  }).sort((a: any, b: any) => new Date(a.expiry_date).getTime() - new Date(b.expiry_date).getTime()).slice(0, 5) : []

  return (
    <div className="page-enter">
      <Header
        title="لوحة المخزون"
        subtitle="إدارة المخازن والمخزون والحركات — Dry Store EPI"
        onRefresh={() => refetch()}
      />

      <div className="p-6 space-y-6">
        {/* Stats Cards */}
        <div className="grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-6 gap-4">
          {statsLoading ? (
            Array.from({ length: 6 }).map((_, i) => <WHStatSkeleton key={i} />)
          ) : stats ? (
            <>
              <WHStatCard title="المخازن" value={stats.active_warehouses} icon={WarehouseIcon} color="text-blue-600" bgColor="bg-blue-50" subtitle={`من أصل ${stats.total_warehouses}`} />
              <WHStatCard title="إجمالي المخزون" value={formatNumber(stats.total_quantity)} icon={Package} color="text-emerald-600" bgColor="bg-emerald-50" subtitle={`${stats.total_stock_items} صنف`} />
              <WHStatCard title="حركات اليوم" value={stats.today_movements} icon={ArrowUpDown} color="text-purple-600" bgColor="bg-purple-50" />
              <WHStatCard title="قيد الانتظار" value={stats.pending_movements} icon={Clock} color="text-amber-600" bgColor="bg-amber-50" />
              <WHStatCard title="قريب الانتهاء" value={stats.expiring_soon} icon={Calendar} color="text-orange-600" bgColor="bg-orange-50" subtitle="خلال 30 يوم" alert={stats.expiring_soon > 0} />
              <WHStatCard title="تنبيهات حرجة" value={stats.critical_alerts} icon={AlertTriangle} color="text-red-600" bgColor="bg-red-50" alert={stats.critical_alerts > 0} />
            </>
          ) : null}
        </div>

        {/* Charts Row */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
          {/* Stock by Warehouse */}
          <Card className="xl:col-span-2 border-0 shadow-md">
            <CardHeader className="pb-3">
              <CardTitle className="text-lg font-heading flex items-center gap-2">
                <BarChart3 className="w-5 h-5 text-primary" />
                المخزون حسب المخزن
              </CardTitle>
              <CardDescription>توزيع الكميات على المخازن</CardDescription>
            </CardHeader>
            <CardContent>
              {stockLoading ? (
                <Skeleton className="w-full h-[300px]" />
              ) : (
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={stockByWarehouse} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" horizontal={false} />
                    <XAxis type="number" tick={{ fontSize: 11, fill: '#6b7280' }} />
                    <YAxis dataKey="name" type="category" tick={{ fontSize: 11, fill: '#6b7280' }} width={100} />
                    <Tooltip content={<CustomTooltip />} />
                    <Bar dataKey="qty" name="الكمية" radius={[0, 8, 8, 0]} fill="url(#whBarGradient)">
                      <defs>
                        <linearGradient id="whBarGradient" x1="0" y1="0" x2="1" y2="0">
                          <stop offset="0%" stopColor="#0D7C66" />
                          <stop offset="100%" stopColor="#10b981" />
                        </linearGradient>
                      </defs>
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          {/* Stock by Category */}
          <Card className="border-0 shadow-md">
            <CardHeader className="pb-2">
              <CardTitle className="text-lg font-heading flex items-center gap-2">
                <Package className="w-5 h-5 text-primary" />
                توزيع الأصناف
              </CardTitle>
              <CardDescription>حسب الفئة</CardDescription>
            </CardHeader>
            <CardContent>
              {stockLoading ? (
                <Skeleton className="w-full h-[280px]" />
              ) : (
                <>
                  <ResponsiveContainer width="100%" height={200}>
                    <PieChart>
                      <Pie
                        data={stockByCategory}
                        cx="50%"
                        cy="50%"
                        innerRadius={50}
                        outerRadius={80}
                        paddingAngle={3}
                        dataKey="qty"
                        strokeWidth={2}
                        stroke="#fff"
                      >
                        {stockByCategory.map((_, index) => (
                          <Cell key={`cell-${index}`} fill={CHART_COLORS[index % CHART_COLORS.length]} />
                        ))}
                      </Pie>
                      <Tooltip content={<CustomTooltip />} />
                    </PieChart>
                  </ResponsiveContainer>
                  <div className="space-y-1.5 mt-2">
                    {stockByCategory.map((item, i) => (
                      <div key={i} className="flex items-center justify-between text-sm">
                        <div className="flex items-center gap-2">
                          <div className="w-3 h-3 rounded-sm" style={{ backgroundColor: CHART_COLORS[i % CHART_COLORS.length] }} />
                          <span className="text-muted-foreground">{item.name}</span>
                        </div>
                        <span className="font-bold tabular-nums">{formatNumber(item.qty)}</span>
                      </div>
                    ))}
                  </div>
                </>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Recent Movements & Expiry Alerts */}
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
          {/* Recent Movements */}
          <Card className="border-0 shadow-md">
            <CardHeader className="pb-3">
              <CardTitle className="text-lg font-heading flex items-center gap-2">
                <Truck className="w-5 h-5 text-primary" />
                آخر الحركات
              </CardTitle>
              <CardDescription>أحدث حركات المخزون</CardDescription>
            </CardHeader>
            <CardContent>
              {movLoading ? (
                <div className="space-y-3">
                  {Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="w-full h-12" />)}
                </div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead className="text-right">الرقم</TableHead>
                      <TableHead className="text-right">النوع</TableHead>
                      <TableHead className="text-right">الصنف</TableHead>
                      <TableHead className="text-right">الكمية</TableHead>
                      <TableHead className="text-right">الحالة</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {(movementsData?.data || []).slice(0, 8).map((mov: any) => (
                      <TableRow key={mov.id}>
                        <TableCell className="font-mono text-xs">{mov.movement_number}</TableCell>
                        <TableCell>
                          <Badge variant="outline" className="text-xs">
                            {MOVEMENT_TYPE_LABELS[mov.movement_type as keyof typeof MOVEMENT_TYPE_LABELS] || mov.movement_type}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-sm">{mov.items?.name_ar || '—'}</TableCell>
                        <TableCell className="font-bold tabular-nums">{formatNumber(mov.quantity)}</TableCell>
                        <TableCell>
                          <Badge className={cn('text-xs', MOVEMENT_STATUS_COLORS[mov.status as keyof typeof MOVEMENT_STATUS_COLORS])}>
                            {MOVEMENT_STATUS_LABELS[mov.status as keyof typeof MOVEMENT_STATUS_LABELS] || mov.status}
                          </Badge>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>

          {/* Expiry Alerts */}
          <Card className="border-0 shadow-md">
            <CardHeader className="pb-3">
              <CardTitle className="text-lg font-heading flex items-center gap-2">
                <AlertTriangle className="w-5 h-5 text-orange-500" />
                تحذيرات انتهاء الصلاحية
              </CardTitle>
              <CardDescription>أصناف قريبة الانتهاء (90 يوم)</CardDescription>
            </CardHeader>
            <CardContent>
              {stockLoading ? (
                <div className="space-y-3">
                  {Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="w-full h-12" />)}
                </div>
              ) : expiryAlerts.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  <CheckCircle2 className="w-10 h-10 mx-auto mb-2 text-emerald-500" />
                  <p>لا توجد تحذيرات — كل الأصناف صالحة ✅</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {expiryAlerts.map((item: any) => {
                    const days = Math.ceil((new Date(item.expiry_date).getTime() - Date.now()) / (1000 * 60 * 60 * 24))
                    const isExpired = days <= 0
                    const isCritical = days <= 30
                    return (
                      <div key={item.id} className={cn(
                        'flex items-center gap-3 p-3 rounded-xl border',
                        isExpired ? 'bg-red-50 border-red-200' : isCritical ? 'bg-orange-50 border-orange-200' : 'bg-yellow-50 border-yellow-200'
                      )}>
                        <div className={cn(
                          'p-2 rounded-lg',
                          isExpired ? 'bg-red-100' : isCritical ? 'bg-orange-100' : 'bg-yellow-100'
                        )}>
                          {isExpired ? <XCircle className="w-4 h-4 text-red-600" /> : <Clock className="w-4 h-4 text-orange-600" />}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium truncate">{item.items?.name_ar || 'غير معروف'}</p>
                          <p className="text-xs text-muted-foreground">
                            {item.warehouses?.name_ar} — دفعة: {item.batch_number || '—'}
                          </p>
                        </div>
                        <div className="text-right">
                          <p className={cn('text-sm font-bold', isExpired ? 'text-red-600' : isCritical ? 'text-orange-600' : 'text-yellow-600')}>
                            {isExpired ? 'منتهي' : `${days} يوم`}
                          </p>
                          <p className="text-xs text-muted-foreground">{item.expiry_date}</p>
                        </div>
                      </div>
                    )
                  })}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Warehouses List */}
        <Card className="border-0 shadow-md">
          <CardHeader className="pb-3">
            <CardTitle className="text-lg font-heading flex items-center gap-2">
              <WarehouseIcon className="w-5 h-5 text-primary" />
              قائمة المخازن
            </CardTitle>
            <CardDescription>جميع المخازن المسجلة في النظام</CardDescription>
          </CardHeader>
          <CardContent>
            {whLoading ? (
              <div className="space-y-3">
                {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="w-full h-14" />)}
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
                {(warehouses || []).map((wh: any) => {
                  const whStock = stockLevels?.filter((s: any) => s.warehouse_id === wh.id) || []
                  const totalQty = whStock.reduce((sum: number, s: any) => sum + (s.quantity || 0), 0)
                  const uniqueItems = new Set(whStock.map((s: any) => s.item_id)).size
                  return (
                    <Card key={wh.id} className="hover:shadow-md transition-shadow border">
                      <CardContent className="p-4">
                        <div className="flex items-start gap-3">
                          <div className="p-2 rounded-xl bg-emerald-50">
                            <WarehouseIcon className="w-5 h-5 text-emerald-600" />
                          </div>
                          <div className="flex-1 min-w-0">
                            <h4 className="font-heading font-bold truncate">{wh.name_ar}</h4>
                            <p className="text-xs text-muted-foreground flex items-center gap-1">
                              <Badge variant="outline" className="text-[10px]">{wh.code}</Badge>
                              {wh.governorates?.name_ar && (
                                <span className="flex items-center gap-0.5">
                                  <MapPin className="w-3 h-3" /> {wh.governorates.name_ar}
                                </span>
                              )}
                            </p>
                            <div className="flex items-center gap-4 mt-2 text-sm">
                              <div>
                                <span className="text-muted-foreground">الكمية: </span>
                                <span className="font-bold tabular-nums">{formatNumber(totalQty)}</span>
                              </div>
                              <div>
                                <span className="text-muted-foreground">أصناف: </span>
                                <span className="font-bold">{uniqueItems}</span>
                              </div>
                            </div>
                          </div>
                          <Badge className={wh.is_active ? 'bg-emerald-100 text-emerald-800' : 'bg-gray-100 text-gray-600'}>
                            {wh.is_active ? 'نشط' : 'غير نشط'}
                          </Badge>
                        </div>
                      </CardContent>
                    </Card>
                  )
                })}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Warehouse Alerts */}
        {!alertLoading && alerts && alerts.length > 0 && (
          <Card className="border-0 shadow-md border-l-4 border-l-red-500">
            <CardHeader className="pb-3">
              <CardTitle className="text-lg font-heading flex items-center gap-2">
                <AlertTriangle className="w-5 h-5 text-red-500" />
                تنبيهات المخزون ({alerts.length})
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                {alerts.slice(0, 5).map((alert: any) => (
                  <div key={alert.id} className={cn(
                    'flex items-center gap-3 p-3 rounded-xl border',
                    ALERT_SEVERITY_WH_COLORS[alert.severity as keyof typeof ALERT_SEVERITY_WH_COLORS] || 'bg-gray-50'
                  )}>
                    <AlertTriangle className="w-4 h-4 shrink-0" />
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium">{alert.title}</p>
                      <p className="text-xs opacity-80">{alert.message}</p>
                    </div>
                    <Badge variant="outline" className="text-[10px] shrink-0">
                      {ALERT_TYPE_WH_LABELS[alert.alert_type as keyof typeof ALERT_TYPE_WH_LABELS] || alert.alert_type}
                    </Badge>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  )
}
