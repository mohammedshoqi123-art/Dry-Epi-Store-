import { useState, useMemo } from 'react'
import {
  Search, AlertTriangle, CheckCircle2, MapPin, Calendar, User, Package,
  Filter, Download, Plus, TrendingUp, TrendingDown, BarChart3, Eye,
  ChevronDown, RefreshCw, XCircle
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Input } from '@/components/ui/input'
import { Progress } from '@/components/ui/progress'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Header } from '@/components/layout/header'
import { useShortages, useResolveShortage, useGovernorates, useForms } from '@/hooks/useApi'
import { SEVERITY_LABELS, SEVERITY_COLORS, type ShortageSeverity, type SupplyShortage } from '@/types/database'
import { formatRelativeTime, formatDateTime, cn, formatNumber } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'
import { useCampaign } from '@/lib/campaign-context'

export default function ShortagesPage() {
  const [severityFilter, setSeverityFilter] = useState<string>('all')
  const [resolvedFilter, setResolvedFilter] = useState<string>('all')
  const [categoryFilter, setCategoryFilter] = useState<string>('all')
  const [govFilter, setGovFilter] = useState<string>('all')
  const [formFilter, setFormFilter] = useState<string>('all')
  const [search, setSearch] = useState('')
  const [selectedShortage, setSelectedShortage] = useState<SupplyShortage | null>(null)
  const { campaign, labelAr, isFiltered } = useCampaign()
  const { data: shortages, isLoading, isError, error, refetch } = useShortages(campaign)
  const { data: governorates } = useGovernorates()
  const { data: formsResult } = useForms({ campaignType: campaign })
  const forms = formsResult?.data
  const resolveShortage = useResolveShortage()
  const { toast } = useToast()

  const filtered = useMemo(() => {
    return shortages?.filter((s: any) => {
      if (severityFilter !== 'all' && s.severity !== severityFilter) return false
      if (resolvedFilter === 'resolved' && !s.is_resolved) return false
      if (resolvedFilter === 'pending' && s.is_resolved) return false
      if (categoryFilter !== 'all' && s.item_category !== categoryFilter) return false
      if (govFilter !== 'all' && s.governorate_id !== govFilter) return false
      if (formFilter !== 'all') {
        const submissionFormId = (s as Record<string, unknown>).form_submissions as { form_id?: string } | undefined
        if (!submissionFormId?.form_id || submissionFormId.form_id !== formFilter) return false
      }
      if (search) {
        const searchLower = search.toLowerCase()
        const name = s.item_name?.toLowerCase() || ''
        const notes = s.notes?.toLowerCase() || ''
        const govName = s.governorates?.name_ar?.toLowerCase() || ''
        if (!name.includes(searchLower) && !notes.includes(searchLower) && !govName.includes(searchLower)) return false
      }
      return true
    })
  }, [shortages, severityFilter, resolvedFilter, categoryFilter, govFilter, formFilter, search])

  // Stats
  const criticalCount = shortages?.filter((s: any) => s.severity === 'critical' && !s.is_resolved).length || 0
  const highCount = shortages?.filter((s: any) => s.severity === 'high' && !s.is_resolved).length || 0
  const totalCount = shortages?.length || 0
  const resolvedCount = shortages?.filter((s: any) => s.is_resolved).length || 0
  const pendingCount = totalCount - resolvedCount
  const resolutionRate = totalCount > 0 ? (resolvedCount / totalCount) * 100 : 0

  // Categories
  const categories = useMemo(() => {
    const cats = new Set<string>()
    shortages?.forEach((s: any) => { if (s.item_category) cats.add(s.item_category) })
    return Array.from(cats)
  }, [shortages])

  return (
    <div className="page-enter">
      <Header
        title="تتبع النواقص"
        subtitle={isFiltered ? `${criticalCount} حرج • ${pendingCount} قيد الانتظار — ${labelAr}` : `${criticalCount} حرج • ${pendingCount} قيد الانتظار`}
        onRefresh={() => refetch()}
      />

      <div className="p-6 space-y-6">
        {/* Error State */}
        {isError && (
          <Card className="border-red-200 bg-red-50/50">
            <CardContent className="p-6 text-center">
              <AlertTriangle className="w-10 h-10 text-red-500 mx-auto mb-3" />
              <h3 className="font-bold text-red-700 mb-1">حدث خطأ في تحميل النواقص</h3>
              <p className="text-sm text-red-600 mb-3">{(error as Error)?.message || 'تعذر الاتصال بالخادم'}</p>
              <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-2">
                <RefreshCw className="w-4 h-4" /> إعادة المحاولة
              </Button>
            </CardContent>
          </Card>
        )}

        {/* Stats Cards */}
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-blue-50">
                <Package className="w-5 h-5 text-blue-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold">{totalCount}</p>
                <p className="text-xs text-muted-foreground">إجمالي</p>
              </div>
            </CardContent>
          </Card>
          <Card className="border-red-200 bg-red-50/30">
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-red-100">
                <AlertTriangle className="w-5 h-5 text-red-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold text-red-600">{criticalCount}</p>
                <p className="text-xs text-muted-foreground">حرج</p>
              </div>
            </CardContent>
          </Card>
          <Card className="border-orange-200 bg-orange-50/30">
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-orange-100">
                <TrendingUp className="w-5 h-5 text-orange-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold text-orange-600">{highCount}</p>
                <p className="text-xs text-muted-foreground">عالي</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-amber-50">
                <RefreshCw className="w-5 h-5 text-amber-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold">{pendingCount}</p>
                <p className="text-xs text-muted-foreground">قيد الانتظار</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center gap-3 mb-2">
                <div className="p-2 rounded-lg bg-emerald-50">
                  <CheckCircle2 className="w-5 h-5 text-emerald-600" />
                </div>
                <div>
                  <p className="text-2xl font-heading font-bold text-emerald-600">{resolvedCount}</p>
                  <p className="text-xs text-muted-foreground">تم الحل</p>
                </div>
              </div>
              <Progress value={resolutionRate} className="h-1.5" />
              <p className="text-[10px] text-muted-foreground mt-1">{resolutionRate.toFixed(0)}% معدل الحل</p>
            </CardContent>
          </Card>
        </div>

        {/* Filters */}
        <div className="flex flex-col lg:flex-row items-stretch lg:items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              placeholder="بحث بالصنف أو المحافظة..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pr-10"
            />
          </div>

          <Select value={severityFilter} onValueChange={setSeverityFilter}>
            <SelectTrigger className="w-36">
              <SelectValue placeholder="الشدة" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">كل الشدات</SelectItem>
              {Object.entries(SEVERITY_LABELS).map(([key, label]) => (
                <SelectItem key={key} value={key}>{label}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Select value={resolvedFilter} onValueChange={setResolvedFilter}>
            <SelectTrigger className="w-36">
              <SelectValue placeholder="الحالة" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">كل الحالات</SelectItem>
              <SelectItem value="pending">قيد الانتظار</SelectItem>
              <SelectItem value="resolved">تم الحل</SelectItem>
            </SelectContent>
          </Select>

          {categories.length > 0 && (
            <Select value={categoryFilter} onValueChange={setCategoryFilter}>
              <SelectTrigger className="w-36">
                <SelectValue placeholder="التصنيف" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">كل التصنيفات</SelectItem>
                {categories.map(cat => (
                  <SelectItem key={cat} value={cat}>{cat}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}

          <Select value={govFilter} onValueChange={setGovFilter}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="المحافظة" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">كل المحافظات</SelectItem>
              {governorates?.map(g => (
                <SelectItem key={g.id} value={g.id}>{g.name_ar}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Select value={formFilter} onValueChange={setFormFilter}>
            <SelectTrigger className="w-44">
              <SelectValue placeholder="النموذج" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">كل النماذج</SelectItem>
              {forms?.map(f => (
                <SelectItem key={f.id} value={f.id}>{f.title_ar}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        {/* Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {isLoading
            ? Array.from({ length: 6 }).map((_, i) => (
                <Card key={i}><CardContent className="p-5"><Skeleton className="w-full h-36" /></CardContent></Card>
              ))
            : filtered?.length === 0 ? (
                <div className="col-span-full text-center py-16">
                  <div className="w-20 h-20 rounded-2xl bg-muted flex items-center justify-center mx-auto mb-4">
                    <Package className="w-10 h-10 text-muted-foreground" />
                  </div>
                  <h3 className="text-lg font-heading font-bold">لا توجد نواقص</h3>
                  <p className="text-sm text-muted-foreground mt-1">
                    {search || severityFilter || resolvedFilter ? 'جرّب تغيير الفلاتر' : 'جميع النواقص تم حلها! 🎉'}
                  </p>
                </div>
              )
            : filtered?.map((shortage) => (
                <Card
                  key={shortage.id}
                  className={cn(
                    'hover:shadow-lg transition-all duration-200 cursor-pointer overflow-hidden',
                    shortage.is_resolved && 'opacity-60'
                  )}
                  onClick={() => setSelectedShortage(shortage)}
                >
                  {/* Severity bar */}
                  <div className={cn(
                    'h-1',
                    shortage.severity === 'critical' ? 'bg-red-500' :
                    shortage.severity === 'high' ? 'bg-orange-500' :
                    shortage.severity === 'medium' ? 'bg-yellow-500' : 'bg-green-500'
                  )} />

                  <CardContent className="p-5">
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <div className={cn(
                          'p-2 rounded-lg',
                          shortage.severity === 'critical' ? 'bg-red-100' :
                          shortage.severity === 'high' ? 'bg-orange-100' :
                          shortage.severity === 'medium' ? 'bg-yellow-100' : 'bg-green-100'
                        )}>
                          <AlertTriangle className={cn(
                            'w-5 h-5',
                            shortage.severity === 'critical' ? 'text-red-600' :
                            shortage.severity === 'high' ? 'text-orange-600' :
                            shortage.severity === 'medium' ? 'text-yellow-600' : 'text-green-600'
                          )} />
                        </div>
                        <div>
                          <h3 className="font-bold text-sm">{shortage.item_name}</h3>
                          {shortage.item_category && (
                            <p className="text-xs text-muted-foreground">{shortage.item_category}</p>
                          )}
                        </div>
                      </div>
                      <Badge className={cn('text-xs border', SEVERITY_COLORS[shortage.severity as ShortageSeverity] || 'bg-gray-100 text-gray-700')}>
                        {SEVERITY_LABELS[shortage.severity as ShortageSeverity] || shortage.severity}
                      </Badge>
                    </div>

                    <div className="space-y-2 text-sm">
                      {shortage.quantity_needed !== undefined && (
                        <div className="flex items-center gap-2 text-muted-foreground">
                          <Package className="w-3.5 h-3.5" />
                          <span>مطلوب: <strong>{formatNumber(shortage.quantity_needed)}</strong> {shortage.unit} | متوفر: <strong>{formatNumber(shortage.quantity_available)}</strong></span>
                        </div>
                      )}
                      {(shortage.governorates?.name_ar || shortage.districts?.name_ar) && (
                        <div className="flex items-center gap-2 text-muted-foreground">
                          <MapPin className="w-3.5 h-3.5" />
                          <span>{[shortage.governorates?.name_ar, shortage.districts?.name_ar].filter(Boolean).join(' - ')}</span>
                        </div>
                      )}
                      <div className="flex items-center gap-2 text-muted-foreground">
                        <Calendar className="w-3.5 h-3.5" />
                        <span>{formatRelativeTime(shortage.created_at)}</span>
                      </div>
                    </div>

                    {shortage.notes && (
                      <p className="text-xs text-muted-foreground mt-3 p-2 bg-muted rounded-md line-clamp-2">{shortage.notes}</p>
                    )}

                    <div className="flex items-center justify-between mt-4 pt-3 border-t">
                      <span className="text-xs text-muted-foreground flex items-center gap-1">
                        <User className="w-3 h-3" />
                        {shortage.profiles?.full_name || '—'}
                      </span>
                      {shortage.is_resolved ? (
                        <Badge variant="success" className="text-[10px] gap-1">
                          <CheckCircle2 className="w-3 h-3" /> تم الحل
                        </Badge>
                      ) : (
                        <Button
                          variant="outline"
                          size="sm"
                          className="text-xs h-7 gap-1"
                          onClick={(e) => {
                            e.stopPropagation()
                            resolveShortage.mutate(shortage.id, {
                              onSuccess: () => toast({ title: 'تم تحديد النقص كمحلول', variant: 'success' }),
                            })
                          }}
                          disabled={resolveShortage.isPending}
                        >
                          <CheckCircle2 className="w-3 h-3" />
                          حل
                        </Button>
                      )}
                    </div>
                  </CardContent>
                </Card>
              ))
          }
        </div>
      </div>

      {/* Shortage Detail Dialog */}
      {selectedShortage && (
        <ShortageDetailDialog
          shortage={selectedShortage}
          open={!!selectedShortage}
          onOpenChange={() => setSelectedShortage(null)}
          onResolve={() => {
            resolveShortage.mutate(selectedShortage.id, {
              onSuccess: () => {
                toast({ title: 'تم تحديد النقص كمحلول', variant: 'success' })
                setSelectedShortage(null)
              },
            })
          }}
          isResolving={resolveShortage.isPending}
        />
      )}
    </div>
  )
}

// ═══════════════════════════════════════
// Shortage Detail Dialog
// ═══════════════════════════════════════

function ShortageDetailDialog({ shortage, open, onOpenChange, onResolve, isResolving }: {
  shortage: SupplyShortage
  open: boolean
  onOpenChange: (v: boolean) => void
  onResolve: () => void
  isResolving: boolean
}) {
  const fillPercent = shortage.quantity_needed
    ? Math.min((shortage.quantity_available / shortage.quantity_needed) * 100, 100)
    : 0

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <AlertTriangle className={cn(
              'w-5 h-5',
              shortage.severity === 'critical' ? 'text-red-600' :
              shortage.severity === 'high' ? 'text-orange-600' :
              shortage.severity === 'medium' ? 'text-yellow-600' : 'text-green-600'
            )} />
            {shortage.item_name}
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <p className="text-muted-foreground text-xs">الشدة</p>
              <Badge className={cn('text-xs mt-1 border', SEVERITY_COLORS[shortage.severity as ShortageSeverity])}>
                {SEVERITY_LABELS[shortage.severity as ShortageSeverity]}
              </Badge>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">التصنيف</p>
              <p className="font-medium mt-1">{shortage.item_category || '—'}</p>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">الكمية المطلوبة</p>
              <p className="font-medium mt-1">{formatNumber(shortage.quantity_needed || 0)} {shortage.unit}</p>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">المتوفر حالياً</p>
              <p className="font-medium mt-1">{formatNumber(shortage.quantity_available)} {shortage.unit}</p>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">المحافظة</p>
              <p className="font-medium mt-1">{shortage.governorates?.name_ar || '—'}</p>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">المديرية</p>
              <p className="font-medium mt-1">{shortage.districts?.name_ar || '—'}</p>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">أبلغ بواسطة</p>
              <p className="font-medium mt-1">{shortage.profiles?.full_name || '—'}</p>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">تاريخ الإبلاغ</p>
              <p className="font-medium mt-1">{formatDateTime(shortage.created_at)}</p>
            </div>
          </div>

          {/* Quantity Progress */}
          {shortage.quantity_needed && (
            <div className="p-3 rounded-lg bg-muted/50">
              <div className="flex justify-between text-xs mb-1">
                <span>نسبة التوفر</span>
                <span className="font-bold">{fillPercent.toFixed(0)}%</span>
              </div>
              <Progress value={fillPercent} className={cn('h-2', fillPercent < 30 && '[&>div]:bg-red-500')} />
              <p className="text-[10px] text-muted-foreground mt-1">
                ناقص {formatNumber(shortage.quantity_needed - shortage.quantity_available)} {shortage.unit}
              </p>
            </div>
          )}

          {shortage.notes && (
            <div>
              <p className="text-sm font-medium mb-1">ملاحظات</p>
              <p className="text-sm bg-muted p-3 rounded-lg">{shortage.notes}</p>
            </div>
          )}

          <div className="flex items-center gap-2">
            <Badge variant={shortage.is_resolved ? 'success' : 'destructive'} className="gap-1">
              {shortage.is_resolved ? <CheckCircle2 className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}
              {shortage.is_resolved ? 'تم الحل' : 'قيد الانتظار'}
            </Badge>
            {shortage.resolved_at && (
              <span className="text-xs text-muted-foreground">
                {formatDateTime(shortage.resolved_at)}
              </span>
            )}
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إغلاق</Button>
          {!shortage.is_resolved && (
            <Button onClick={onResolve} disabled={isResolving} className="gap-2">
              <CheckCircle2 className="w-4 h-4" />
              تحديد كمحلول
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
