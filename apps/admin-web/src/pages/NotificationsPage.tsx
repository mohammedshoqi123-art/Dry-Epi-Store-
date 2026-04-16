import { useState, useMemo, useCallback, useEffect, useRef } from 'react'
import {
  Bell, CheckCheck, Filter, Info, CheckCircle, AlertCircle, Clock,
  Trash2, MoreVertical, Eye, EyeOff, Settings, Send, Search,
  AlertTriangle, FileText, Users, MapPin, MessageSquare, RefreshCw,
  Calendar, ChevronDown, Download, CheckSquare, Square, MinusSquare,
  Volume2, VolumeX, Smartphone, Mail, Loader2, X, BarChart3,
  PieChart, TrendingUp, LayoutTemplate, Timer, Copy
} from 'lucide-react'
import { PieChart as RePieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Legend } from 'recharts'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Input } from '@/components/ui/input'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator } from '@/components/ui/dropdown-menu'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Header } from '@/components/layout/header'
import { useNotifications, useMarkNotificationRead, useMarkAllNotificationsRead, useDeleteNotification, useDeleteAllNotifications, useToggleNotificationRead, useSendNotification, useGovernorates, useNotificationStats, useNotificationTemplates } from '@/hooks/useApi'
import { formatRelativeTime, formatDateTime, cn } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'
import type { Notification } from '@/types/database'

// ═══════════════════════════════════════
// Configs
// ═══════════════════════════════════════

const TYPE_CONFIG: Record<string, { icon: React.ElementType; color: string; bg: string; label: string; chartColor: string }> = {
  info: { icon: Info, color: 'text-blue-600', bg: 'bg-blue-50 border-blue-200', label: 'معلومة', chartColor: '#3b82f6' },
  success: { icon: CheckCircle, color: 'text-emerald-600', bg: 'bg-emerald-50 border-emerald-200', label: 'نجاح', chartColor: '#10b981' },
  error: { icon: AlertCircle, color: 'text-red-600', bg: 'bg-red-50 border-red-200', label: 'خطأ', chartColor: '#ef4444' },
  warning: { icon: AlertTriangle, color: 'text-amber-600', bg: 'bg-amber-50 border-amber-200', label: 'تحذير', chartColor: '#f59e0b' },
}

const CATEGORY_CONFIG: Record<string, { icon: React.ElementType; label: string; chartColor: string }> = {
  submission: { icon: FileText, label: 'إرسالية', chartColor: '#6366f1' },
  user: { icon: Users, label: 'مستخدم', chartColor: '#8b5cf6' },
  shortage: { icon: AlertTriangle, label: 'نقص', chartColor: '#f43f5e' },
  system: { icon: Settings, label: 'نظام', chartColor: '#64748b' },
  chat: { icon: MessageSquare, label: 'محادثة', chartColor: '#06b6d4' },
  location: { icon: MapPin, label: 'موقع', chartColor: '#14b8a6' },
}

const AUTO_REFRESH_OPTIONS = [
  { label: 'إيقاف', value: 0 },
  { label: '30 ثانية', value: 30000 },
  { label: 'دقيقة', value: 60000 },
  { label: '5 دقائق', value: 300000 },
]

// ═══════════════════════════════════════
// Main Page
// ═══════════════════════════════════════

export default function NotificationsPage() {
  const [typeFilter, setTypeFilter] = useState<string>('all')
  const [categoryFilter, setCategoryFilter] = useState<string>('all')
  const [readFilter, setReadFilter] = useState<string>('all')
  const [search, setSearch] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [selectedNotif, setSelectedNotif] = useState<Notification | null>(null)
  const [composeOpen, setComposeOpen] = useState(false)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [showDateFilter, setShowDateFilter] = useState(false)
  const [statsOpen, setStatsOpen] = useState(false)
  const [templatesOpen, setTemplatesOpen] = useState(false)
  const [autoRefreshMs, setAutoRefreshMs] = useState(0)
  const [lastRefresh, setLastRefresh] = useState(new Date())

  const { data: notifications, isLoading, isError, error, refetch } = useNotifications()
  const markRead = useMarkNotificationRead()
  const markAllRead = useMarkAllNotificationsRead()
  const deleteNotif = useDeleteNotification()
  const deleteAll = useDeleteAllNotifications()
  const toggleRead = useToggleNotificationRead()
  const { toast } = useToast()

  // Auto-refresh
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)
  useEffect(() => {
    if (intervalRef.current) clearInterval(intervalRef.current)
    if (autoRefreshMs > 0) {
      intervalRef.current = setInterval(() => {
        refetch()
        setLastRefresh(new Date())
      }, autoRefreshMs)
    }
    return () => { if (intervalRef.current) clearInterval(intervalRef.current) }
  }, [autoRefreshMs, refetch])

  // Filter
  const filtered = useMemo(() => {
    return notifications?.filter((n: Notification) => {
      if (typeFilter !== 'all' && n.type !== typeFilter) return false
      if (categoryFilter !== 'all' && n.category !== categoryFilter) return false
      if (readFilter === 'unread' && n.is_read) return false
      if (readFilter === 'read' && !n.is_read) return false
      if (search && !n.title.includes(search) && !n.body.includes(search)) return false
      if (dateFrom) {
        const from = new Date(dateFrom); from.setHours(0, 0, 0, 0)
        if (new Date(n.created_at) < from) return false
      }
      if (dateTo) {
        const to = new Date(dateTo); to.setHours(23, 59, 59, 999)
        if (new Date(n.created_at) > to) return false
      }
      return true
    }) || []
  }, [notifications, typeFilter, categoryFilter, readFilter, search, dateFrom, dateTo])

  const unreadCount = notifications?.filter((n: Notification) => !n.is_read).length || 0
  const todayCount = notifications?.filter((n: Notification) => new Date(n.created_at).toDateString() === new Date().toDateString()).length || 0
  const isAllSelected = filtered.length > 0 && filtered.every((n: Notification) => selectedIds.has(n.id))
  const isSomeSelected = filtered.some((n: Notification) => selectedIds.has(n.id))

  const toggleSelect = useCallback((id: string) => {
    setSelectedIds(prev => { const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n })
  }, [])

  const toggleSelectAll = useCallback(() => {
    setSelectedIds(isAllSelected ? new Set() : new Set(filtered.map((n: Notification) => n.id)))
  }, [filtered, isAllSelected])

  const clearSelection = useCallback(() => setSelectedIds(new Set()), [])

  const handleBulkMarkRead = useCallback(() => {
    const ids = Array.from(selectedIds)
    ids.forEach(id => markRead.mutate(id))
    toast({ title: `تم تحديد ${ids.length} إشعار كمقروء`, variant: 'success' })
    clearSelection()
  }, [selectedIds, markRead, toast, clearSelection])

  const handleBulkDelete = useCallback(() => {
    const ids = Array.from(selectedIds)
    if (!confirm(`هل أنت متأكد من حذف ${ids.length} إشعار؟`)) return
    ids.forEach(id => deleteNotif.mutate(id))
    toast({ title: `تم حذف ${ids.length} إشعار`, variant: 'success' })
    clearSelection()
  }, [selectedIds, deleteNotif, toast, clearSelection])

  const handleDelete = (id: string) => {
    deleteNotif.mutate(id, { onSuccess: () => toast({ title: 'تم حذف الإشعار', variant: 'success' }) })
  }

  const handleDeleteAll = () => {
    if (!confirm('هل أنت متأكد من حذف جميع الإشعارات؟')) return
    deleteAll.mutate(undefined, { onSuccess: () => toast({ title: 'تم حذف جميع الإشعارات', variant: 'success' }) })
  }

  const handleExport = useCallback(() => {
    const data = filtered.length > 0 ? filtered : notifications || []
    if (!data.length) { toast({ title: 'لا توجد بيانات للتصدير', variant: 'destructive' }); return }
    const headers = ['العنوان', 'النص', 'النوع', 'التصنيف', 'الحالة', 'تاريخ الإنشاء']
    const rows = data.map((n: Notification) => [
      `"${n.title.replace(/"/g, '""')}"`, `"${n.body.replace(/"/g, '""')}"`,
      TYPE_CONFIG[n.type]?.label || n.type, CATEGORY_CONFIG[n.category]?.label || n.category,
      n.is_read ? 'مقروء' : 'غير مقروء', formatDateTime(n.created_at),
    ])
    const csv = '\uFEFF' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n')
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a'); a.href = url; a.download = `notifications_${new Date().toISOString().split('T')[0]}.csv`; a.click()
    URL.revokeObjectURL(url)
    toast({ title: `تم تصدير ${data.length} إشعار`, variant: 'success' })
  }, [filtered, notifications, toast])

  const activeFiltersCount = [typeFilter !== 'all', categoryFilter !== 'all', readFilter !== 'all', dateFrom, dateTo, search].filter(Boolean).length
  const clearFilters = () => { setTypeFilter('all'); setCategoryFilter('all'); setReadFilter('all'); setDateFrom(''); setDateTo(''); setSearch('') }

  return (
    <div className="page-enter">
      <Header
        title="الإشعارات"
        subtitle={unreadCount > 0 ? `${unreadCount} غير مقروء • ${todayCount} اليوم` : 'كلها مقروءة'}
        onRefresh={() => { refetch(); setLastRefresh(new Date()) }}
      />

      <div className="p-6 space-y-6">
        {/* Error */}
        {isError && (
          <Card className="border-red-200 bg-red-50/50">
            <CardContent className="p-6 text-center">
              <AlertCircle className="w-10 h-10 text-red-500 mx-auto mb-3" />
              <h3 className="font-bold text-red-700 mb-1">حدث خطأ في تحميل الإشعارات</h3>
              <p className="text-sm text-red-600 mb-3">{(error as Error)?.message || 'تعذر الاتصال بالخادم'}</p>
              <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-2"><RefreshCw className="w-4 h-4" /> إعادة المحاولة</Button>
            </CardContent>
          </Card>
        )}

        {/* Stats Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card className={cn(unreadCount > 0 && 'border-primary/30 bg-primary/5')}>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/10"><Bell className="w-5 h-5 text-primary" /></div>
              <div><p className="text-2xl font-heading font-bold">{notifications?.length || 0}</p><p className="text-xs text-muted-foreground">إجمالي</p></div>
            </CardContent>
          </Card>
          <Card className={cn(unreadCount > 0 && 'border-amber-300 bg-amber-50/50')}>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-amber-100"><EyeOff className="w-5 h-5 text-amber-600" /></div>
              <div><p className="text-2xl font-heading font-bold text-amber-600">{unreadCount}</p><p className="text-xs text-muted-foreground">غير مقروء</p></div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-emerald-100"><Clock className="w-5 h-5 text-emerald-600" /></div>
              <div><p className="text-2xl font-heading font-bold">{todayCount}</p><p className="text-xs text-muted-foreground">اليوم</p></div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-blue-100"><CheckCircle className="w-5 h-5 text-blue-600" /></div>
              <div><p className="text-2xl font-heading font-bold">{(notifications?.length || 0) - unreadCount}</p><p className="text-xs text-muted-foreground">مقروء</p></div>
            </CardContent>
          </Card>
        </div>

        {/* ═══ Toolbar ═══ */}
        <div className="space-y-3">
          <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
            <div className="relative flex-1">
              <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input placeholder="بحث في الإشعارات..." value={search} onChange={(e) => setSearch(e.target.value)} className="pr-10" />
              {search && <button onClick={() => setSearch('')} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"><X className="w-3.5 h-3.5" /></button>}
            </div>
            <Tabs value={readFilter} onValueChange={setReadFilter}>
              <TabsList>
                <TabsTrigger value="all" className="text-xs">الكل</TabsTrigger>
                <TabsTrigger value="unread" className="text-xs">غير مقروء</TabsTrigger>
                <TabsTrigger value="read" className="text-xs">مقروء</TabsTrigger>
              </TabsList>
            </Tabs>
            <Select value={typeFilter} onValueChange={setTypeFilter}>
              <SelectTrigger className="w-36"><SelectValue placeholder="النوع" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">كل الأنواع</SelectItem>
                {Object.entries(TYPE_CONFIG).map(([k, c]) => <SelectItem key={k} value={k}>{c.label}</SelectItem>)}
              </SelectContent>
            </Select>
            <Select value={categoryFilter} onValueChange={setCategoryFilter}>
              <SelectTrigger className="w-36"><SelectValue placeholder="التصنيف" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">كل التصنيفات</SelectItem>
                {Object.entries(CATEGORY_CONFIG).map(([k, c]) => <SelectItem key={k} value={k}>{c.label}</SelectItem>)}
              </SelectContent>
            </Select>
            <Button variant={showDateFilter ? 'secondary' : 'outline'} size="sm" className="gap-2" onClick={() => setShowDateFilter(!showDateFilter)}>
              <Calendar className="w-4 h-4" /> التاريخ
              {activeFiltersCount > 0 && <Badge className="h-5 w-5 rounded-full p-0 text-[10px] flex items-center justify-center">{activeFiltersCount}</Badge>}
            </Button>
          </div>

          {/* Date Range */}
          {showDateFilter && (
            <div className="flex flex-wrap items-center gap-3 p-3 rounded-lg bg-muted/30 border">
              <div className="flex items-center gap-2"><label className="text-xs text-muted-foreground whitespace-nowrap">من</label><Input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} className="h-8 text-xs w-36" /></div>
              <div className="flex items-center gap-2"><label className="text-xs text-muted-foreground whitespace-nowrap">إلى</label><Input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} className="h-8 text-xs w-36" /></div>
              {activeFiltersCount > 0 && <Button variant="ghost" size="sm" className="text-xs gap-1 h-8" onClick={clearFilters}><X className="w-3 h-3" /> مسح الفلاتر ({activeFiltersCount})</Button>}
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex items-center gap-2 flex-wrap">
            {filtered.length > 0 && (
              <Button variant="ghost" size="sm" className="gap-2" onClick={toggleSelectAll}>
                {isAllSelected ? <CheckSquare className="w-4 h-4 text-primary" /> : isSomeSelected ? <MinusSquare className="w-4 h-4 text-primary" /> : <Square className="w-4 h-4" />}
                تحديد
              </Button>
            )}
            {selectedIds.size > 0 && (
              <>
                <Badge variant="secondary">{selectedIds.size} محدد</Badge>
                <Button variant="outline" size="sm" className="gap-2" onClick={handleBulkMarkRead}><Eye className="w-3.5 h-3.5" /> تحديد كمقروء</Button>
                <Button variant="outline" size="sm" className="gap-2 text-red-600 hover:bg-red-50 border-red-200" onClick={handleBulkDelete}><Trash2 className="w-3.5 h-3.5" /> حذف المحدد</Button>
                <Button variant="ghost" size="sm" onClick={clearSelection}>إلغاء</Button>
              </>
            )}
            <div className="flex-1" />
            {/* Auto-refresh */}
            <Select value={String(autoRefreshMs)} onValueChange={(v) => setAutoRefreshMs(Number(v))}>
              <SelectTrigger className="w-32 h-8 text-xs gap-1">
                <RefreshCw className={cn('w-3 h-3', autoRefreshMs > 0 && 'animate-spin')} />
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {AUTO_REFRESH_OPTIONS.map(o => <SelectItem key={o.value} value={String(o.value)}>{o.label}</SelectItem>)}
              </SelectContent>
            </Select>
            <Button variant="outline" size="sm" className="gap-2" onClick={() => setStatsOpen(true)}><BarChart3 className="w-4 h-4" /> إحصائيات</Button>
            <Button variant="outline" size="sm" className="gap-2" onClick={() => setTemplatesOpen(true)}><LayoutTemplate className="w-4 h-4" /> قوالب</Button>
            <Button variant="outline" size="sm" className="gap-2" onClick={handleExport}><Download className="w-4 h-4" /> تصدير</Button>
            {notifications && notifications.length > 0 && (
              <Button variant="ghost" size="sm" className="gap-2 text-red-600 hover:text-red-700 hover:bg-red-50" onClick={handleDeleteAll} disabled={deleteAll.isPending}><Trash2 className="w-4 h-4" /> حذف الكل</Button>
            )}
            {unreadCount > 0 && (
              <Button variant="outline" size="sm" className="gap-2" onClick={() => markAllRead.mutate(undefined, { onSuccess: () => toast({ title: 'تم تحديد الكل كمقروء', variant: 'success' }) })} disabled={markAllRead.isPending}><CheckCheck className="w-4 h-4" /> قراءة الكل</Button>
            )}
            <Button variant="outline" size="sm" className="gap-2" onClick={() => setSettingsOpen(true)}><Settings className="w-4 h-4" /> إعدادات</Button>
            <Button size="sm" className="gap-2" onClick={() => setComposeOpen(true)}><Send className="w-4 h-4" /> إشعار جديد</Button>
          </div>
        </div>

        {/* ═══ List ═══ */}
        <div className="space-y-2">
          {!isLoading && <p className="text-xs text-muted-foreground px-1">{filtered.length} إشعار{filtered.length !== (notifications?.length || 0) && ` من أصل ${notifications?.length || 0}`} • آخر تحديث: {lastRefresh.toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' })}</p>}

          {isLoading ? (
            Array.from({ length: 5 }).map((_, i) => <Card key={i}><CardContent className="p-4"><Skeleton className="w-full h-16" /></CardContent></Card>)
          ) : filtered.length === 0 ? (
            <Card>
              <CardContent className="p-16 flex flex-col items-center text-muted-foreground">
                <div className="w-20 h-20 rounded-2xl bg-muted flex items-center justify-center mb-4"><Bell className="w-10 h-10 opacity-30" /></div>
                <p className="font-heading font-bold text-lg">لا توجد إشعارات</p>
                <p className="text-sm mt-1">{activeFiltersCount > 0 ? 'جرّب تغيير الفلاتر' : 'ستظهر الإشعارات الجديدة هنا'}</p>
                {activeFiltersCount > 0 && <Button variant="outline" size="sm" className="mt-3" onClick={clearFilters}>مسح الفلاتر</Button>}
              </CardContent>
            </Card>
          ) : (
            filtered.map((notif: Notification) => {
              const typeInfo = TYPE_CONFIG[notif.type] || TYPE_CONFIG.info
              const catInfo = CATEGORY_CONFIG[notif.category]
              const TypeIcon = typeInfo.icon
              const CatIcon = catInfo?.icon
              const isSelected = selectedIds.has(notif.id)

              return (
                <Card key={notif.id} className={cn('transition-all duration-200 cursor-pointer hover:shadow-md group', !notif.is_read && 'border-r-4 border-r-primary bg-primary/[0.03]', isSelected && 'ring-2 ring-primary/40 bg-primary/[0.06]')}
                  onClick={(e) => { if (selectedIds.size > 0) { e.preventDefault(); toggleSelect(notif.id); return } setSelectedNotif(notif); if (!notif.is_read) markRead.mutate(notif.id) }}>
                  <CardContent className="p-4">
                    <div className="flex gap-3">
                      <div className="relative shrink-0" onClick={(e) => { e.stopPropagation(); toggleSelect(notif.id) }}>
                        <div className={cn('p-2.5 rounded-xl border transition-all', isSelected ? 'bg-primary/10 border-primary/30' : typeInfo.bg)}>
                          {isSelected ? <CheckSquare className="w-5 h-5 text-primary" /> : <TypeIcon className={cn('w-5 h-5', typeInfo.color)} />}
                        </div>
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between gap-2 mb-1">
                          <div className="flex items-center gap-2 flex-wrap">
                            <h3 className={cn('font-bold text-sm', !notif.is_read ? 'text-foreground' : 'text-foreground/80')}>{notif.title}</h3>
                            {!notif.is_read && <span className="w-2 h-2 rounded-full bg-primary shrink-0" />}
                          </div>
                          <div className="flex items-center gap-2 shrink-0">
                            <Badge className={cn('text-[9px]', typeInfo.bg, typeInfo.color)}>{typeInfo.label}</Badge>
                            <span className="text-[10px] text-muted-foreground flex items-center gap-1"><Clock className="w-3 h-3" />{formatRelativeTime(notif.created_at)}</span>
                          </div>
                        </div>
                        <p className={cn('text-sm leading-relaxed line-clamp-2', !notif.is_read ? 'text-foreground/70' : 'text-muted-foreground')}>{notif.body}</p>
                        <div className="flex items-center gap-2 mt-2">
                          {notif.category && CatIcon && <Badge variant="outline" className="text-[10px] gap-1"><CatIcon className="w-3 h-3" />{catInfo.label}</Badge>}
                        </div>
                      </div>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100 shrink-0" onClick={(e) => e.stopPropagation()}><MoreVertical className="w-4 h-4" /></Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem onClick={(e) => { e.stopPropagation(); toggleRead.mutate({ id: notif.id, isRead: notif.is_read }, { onSuccess: () => toast({ title: notif.is_read ? 'تم تحديد كغير مقروء' : 'تم تحديد كمقروء', variant: 'success' }) }) }}>
                            {notif.is_read ? <EyeOff className="w-4 h-4 ml-2" /> : <Eye className="w-4 h-4 ml-2" />}
                            {notif.is_read ? 'تحديد كغير مقروء' : 'تحديد كمقروء'}
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={(e) => { e.stopPropagation(); navigator.clipboard.writeText(notif.title + '\n' + notif.body); toast({ title: 'تم النسخ', variant: 'success' }) }}>
                            <Copy className="w-4 h-4 ml-2" /> نسخ
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem className="text-red-600 focus:text-red-600" onClick={(e) => { e.stopPropagation(); handleDelete(notif.id) }}>
                            <Trash2 className="w-4 h-4 ml-2" /> حذف
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  </CardContent>
                </Card>
              )
            })
          )}
        </div>

        {filtered.length > 0 && filtered.length >= 50 && (
          <div className="text-center"><Button variant="outline" className="gap-2"><RefreshCw className="w-4 h-4" /> تحميل المزيد</Button></div>
        )}
      </div>

      {/* Dialogs */}
      {selectedNotif && <NotificationDetailDialog notification={selectedNotif} open={!!selectedNotif} onOpenChange={() => setSelectedNotif(null)} />}
      <ComposeNotificationDialog open={composeOpen} onOpenChange={setComposeOpen} />
      <NotificationSettingsDialog open={settingsOpen} onOpenChange={setSettingsOpen} />
      <NotificationStatsDialog open={statsOpen} onOpenChange={setStatsOpen} />
      <NotificationTemplatesDialog open={templatesOpen} onOpenChange={setTemplatesOpen} onUseTemplate={(t) => setComposeOpen(true)} />
    </div>
  )
}

// ═══════════════════════════════════════
// Detail Dialog
// ═══════════════════════════════════════

function NotificationDetailDialog({ notification, open, onOpenChange }: { notification: Notification; open: boolean; onOpenChange: (v: boolean) => void }) {
  const typeInfo = TYPE_CONFIG[notification.type] || TYPE_CONFIG.info
  const TypeIcon = typeInfo.icon

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <div className="flex items-center gap-3 mb-2">
            <div className={cn('p-2.5 rounded-xl border', typeInfo.bg)}><TypeIcon className={cn('w-6 h-6', typeInfo.color)} /></div>
            <div><DialogTitle className="text-lg">{notification.title}</DialogTitle><p className="text-xs text-muted-foreground mt-0.5">{formatDateTime(notification.created_at)}</p></div>
          </div>
        </DialogHeader>
        <div className="space-y-4">
          <div className="p-4 rounded-xl bg-muted/30 text-sm leading-relaxed">{notification.body}</div>
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div><p className="text-muted-foreground text-xs">النوع</p><Badge className={cn('text-xs mt-1', typeInfo.bg, typeInfo.color)}>{typeInfo.label}</Badge></div>
            {notification.category && <div><p className="text-muted-foreground text-xs">التصنيف</p><Badge variant="outline" className="text-xs mt-1">{CATEGORY_CONFIG[notification.category]?.label || notification.category}</Badge></div>}
            <div><p className="text-muted-foreground text-xs">الحالة</p><Badge variant={notification.is_read ? 'secondary' : 'default'} className="text-xs mt-1">{notification.is_read ? 'مقروء' : 'غير مقروء'}</Badge></div>
            {notification.read_at && <div><p className="text-muted-foreground text-xs">تاريخ القراءة</p><p className="text-sm font-medium mt-1">{formatDateTime(notification.read_at)}</p></div>}
          </div>
          {notification.data && Object.keys(notification.data).length > 0 && (
            <div><p className="text-sm text-muted-foreground mb-2">بيانات إضافية</p><pre className="text-xs bg-muted p-3 rounded-lg overflow-x-auto max-h-32" dir="ltr">{JSON.stringify(notification.data, null, 2)}</pre></div>
          )}
        </div>
        <DialogFooter><Button variant="outline" onClick={() => onOpenChange(false)}>إغلاق</Button></DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ═══════════════════════════════════════
// Compose Dialog
// ═══════════════════════════════════════

function ComposeNotificationDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [type, setType] = useState('info')
  const [category, setCategory] = useState('system')
  const [target, setTarget] = useState('all')
  const [governorateId, setGovernorateId] = useState('')
  const { toast } = useToast()
  const sendNotif = useSendNotification()
  const { data: governorates } = useGovernorates()

  const handleSend = () => {
    if (!title.trim() || !body.trim()) { toast({ title: 'العنوان والنص مطلوبان', variant: 'destructive' }); return }
    sendNotif.mutate(
      { title: title.trim(), body: body.trim(), type, category, target: target as any, governorate_id: governorateId || undefined },
      {
        onSuccess: (data) => {
          toast({ title: `تم إرسال ${data.sent_count} إشعار بنجاح`, variant: 'success' })
          setTitle(''); setBody(''); setType('info'); setCategory('system'); setTarget('all'); setGovernorateId(''); onOpenChange(false)
        },
        onError: (err) => toast({ title: 'فشل الإرسال', description: (err as Error).message, variant: 'destructive' })
      }
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2"><Send className="w-5 h-5 text-primary" /> إرسال إشعار جديد</DialogTitle>
          <DialogDescription>أنشئ إشعاراً لجميع المستخدمين أو مجموعة محددة</DialogDescription>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-2"><label className="text-sm font-medium">العنوان *</label><Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="عنوان الإประกา" /></div>
          <div className="space-y-2"><label className="text-sm font-medium">النص *</label><textarea value={body} onChange={(e) => setBody(e.target.value)} className="w-full h-24 p-3 rounded-lg border bg-background text-sm resize-y focus:outline-none focus:ring-2 focus:ring-primary/30" placeholder="اكتب نص الإشعار..." /></div>
          <div className="grid grid-cols-3 gap-3">
            <div className="space-y-2"><label className="text-sm font-medium">النوع</label><Select value={type} onValueChange={setType}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent>{Object.entries(TYPE_CONFIG).map(([k, c]) => <SelectItem key={k} value={k}>{c.label}</SelectItem>)}</SelectContent></Select></div>
            <div className="space-y-2"><label className="text-sm font-medium">التصنيف</label><Select value={category} onValueChange={setCategory}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent>{Object.entries(CATEGORY_CONFIG).map(([k, c]) => <SelectItem key={k} value={k}>{c.label}</SelectItem>)}</SelectContent></Select></div>
            <div className="space-y-2"><label className="text-sm font-medium">المستلمين</label><Select value={target} onValueChange={setTarget}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="all">جميع المستخدمين</SelectItem><SelectItem value="admin">المديرين فقط</SelectItem><SelectItem value="field">العاملين الميدانيين</SelectItem><SelectItem value="governorate">محافظة محددة</SelectItem></SelectContent></Select></div>
          </div>
          {target === 'governorate' && (
            <div className="space-y-2"><label className="text-sm font-medium">اختر المحافظة</label><Select value={governorateId} onValueChange={setGovernorateId}><SelectTrigger><SelectValue placeholder="اختر محافظة..." /></SelectTrigger><SelectContent>{governorates?.map((g: any) => <SelectItem key={g.id} value={g.id}>{g.name_ar}</SelectItem>)}</SelectContent></Select></div>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button onClick={handleSend} className="gap-2" disabled={sendNotif.isPending}>{sendNotif.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}{sendNotif.isPending ? 'جاري الإرسال...' : 'إرسال'}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ═══════════════════════════════════════
// Settings Dialog
// ═══════════════════════════════════════

function NotificationSettingsDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const { toast } = useToast()
  const [s, setS] = useState(() => {
    try { return JSON.parse(localStorage.getItem('notification_settings') || '{}') } catch { return {} }
  })
  const [settings, setSettings] = useState({
    inApp: s.inApp ?? true, email: s.email ?? true, push: s.push ?? false,
    submissions: s.submissions ?? true, shortages: s.shortages ?? true, users: s.users ?? true, system: s.system ?? true, chat: s.chat ?? true,
    quietEnabled: s.quietEnabled ?? false, quietFrom: s.quietFrom ?? '22:00', quietTo: s.quietTo ?? '07:00',
    soundEnabled: s.soundEnabled ?? true, soundVolume: s.soundVolume ?? 80,
  })

  const up = (k: string, v: any) => setSettings(p => ({ ...p, [k]: v }))

  const handleSave = () => {
    localStorage.setItem('notification_settings', JSON.stringify(settings))
    toast({ title: 'تم حفظ الإعدادات', variant: 'success' })
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2"><Settings className="w-5 h-5 text-primary" /> إعدادات الإشعارات</DialogTitle>
          <DialogDescription>خصّص كيفية استلامك للإشعارات</DialogDescription>
        </DialogHeader>
        <div className="space-y-6 py-2">
          <div><h4 className="text-sm font-bold mb-3">قنوات الاستلام</h4>
            <div className="space-y-2">
              <Toggle icon={Bell} label="إشعارات داخل التطبيق" desc="تنبيهات في لوحة التحكم" checked={settings.inApp} onChange={() => up('inApp', !settings.inApp)} />
              <Toggle icon={Mail} label="إشعارات البريد الإلكتروني" desc="إرسال ملخص إلى بريدك" checked={settings.email} onChange={() => up('email', !settings.email)} />
              <Toggle icon={Smartphone} label="إشعارات الدفع (Push)" desc="تنبيهات فورية على الجهاز" checked={settings.push} onChange={() => up('push', !settings.push)} />
            </div>
          </div>
          <div><h4 className="text-sm font-bold mb-3">أنواع الإشعارات</h4>
            <div className="space-y-2">
              <Toggle icon={FileText} label="الإرساليات" desc="إشعارات الإرساليات الجديدة" checked={settings.submissions} onChange={() => up('submissions', !settings.submissions)} />
              <Toggle icon={AlertTriangle} label="النواقص" desc="تنبيهات النواقص" checked={settings.shortages} onChange={() => up('shortages', !settings.shortages)} />
              <Toggle icon={Users} label="المستخدمين" desc="تسجيل مستخدمين جدد" checked={settings.users} onChange={() => up('users', !settings.users)} />
              <Toggle icon={Settings} label="النظام" desc="تحديثات وصيانة" checked={settings.system} onChange={() => up('system', !settings.system)} />
              <Toggle icon={MessageSquare} label="المحادثات" desc="رسائل جديدة" checked={settings.chat} onChange={() => up('chat', !settings.chat)} />
            </div>
          </div>
          <div><h4 className="text-sm font-bold mb-3">الصوت</h4>
            <div className="space-y-3">
              <Toggle icon={settings.soundEnabled ? Volume2 : VolumeX} label="تفعيل الصوت" desc="تشغيل صوت عند استلام إشعار" checked={settings.soundEnabled} onChange={() => up('soundEnabled', !settings.soundEnabled)} />
              {settings.soundEnabled && (
                <div className="pr-10 flex items-center gap-3">
                  <VolumeX className="w-3.5 h-3.5 text-muted-foreground" />
                  <input type="range" min="0" max="100" value={settings.soundVolume} onChange={(e) => up('soundVolume', Number(e.target.value))} className="flex-1 h-1.5 accent-primary" />
                  <Volume2 className="w-3.5 h-3.5 text-muted-foreground" />
                  <span className="text-xs text-muted-foreground w-8 text-left">{settings.soundVolume}%</span>
                </div>
              )}
            </div>
          </div>
          <div><h4 className="text-sm font-bold mb-3">ساعات الهدوء</h4>
            <Toggle icon={Clock} label="تفعيل ساعات الهدوء" desc="كتم الإشعارات في فترة محددة" checked={settings.quietEnabled} onChange={() => up('quietEnabled', !settings.quietEnabled)} />
            {settings.quietEnabled && (
              <div className="flex items-center gap-3 mt-3 pr-10">
                <div className="flex items-center gap-2 flex-1"><label className="text-xs text-muted-foreground">من</label><Input type="time" value={settings.quietFrom} onChange={(e) => up('quietFrom', e.target.value)} className="h-8 text-xs" /></div>
                <div className="flex items-center gap-2 flex-1"><label className="text-xs text-muted-foreground">إلى</label><Input type="time" value={settings.quietTo} onChange={(e) => up('quietTo', e.target.value)} className="h-8 text-xs" /></div>
              </div>
            )}
          </div>
        </div>
        <DialogFooter><Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button><Button onClick={handleSave} className="gap-2"><CheckCircle className="w-4 h-4" /> حفظ الإعدادات</Button></DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function Toggle({ icon: Icon, label, desc, checked, onChange }: { icon: any; label: string; desc: string; checked: boolean; onChange: () => void }) {
  return (
    <div className={cn('flex items-center gap-3 p-3 rounded-lg border cursor-pointer transition-all', checked ? 'bg-primary/5 border-primary/20' : 'bg-muted/30 border-transparent hover:bg-muted/50')} onClick={onChange}>
      <div className={cn('p-1.5 rounded-md', checked ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground')}><Icon className="w-4 h-4" /></div>
      <div className="flex-1 min-w-0"><p className={cn('text-sm font-medium', !checked && 'text-muted-foreground')}>{label}</p><p className="text-[11px] text-muted-foreground">{desc}</p></div>
      <div className={cn('w-9 h-5 rounded-full transition-colors relative', checked ? 'bg-primary' : 'bg-muted-foreground/30')}>
        <div className={cn('w-4 h-4 rounded-full bg-white absolute top-0.5 transition-transform shadow-sm', checked ? 'translate-x-0.5' : 'translate-x-4')} />
      </div>
    </div>
  )
}

// ═══════════════════════════════════════
// Stats Dialog
// ═══════════════════════════════════════

function NotificationStatsDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const { data: stats, isLoading } = useNotificationStats()

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2"><BarChart3 className="w-5 h-5 text-primary" /> إحصائيات الإشعارات</DialogTitle>
          <DialogDescription>نظرة عامة على الإشعارات (آخر 500 إشعار)</DialogDescription>
        </DialogHeader>

        {isLoading ? (
          <div className="space-y-4 py-8"><Skeleton className="w-full h-48" /><Skeleton className="w-full h-48" /></div>
        ) : stats ? (
          <div className="space-y-6 py-2">
            {/* Summary */}
            <div className="grid grid-cols-3 gap-4">
              <Card><CardContent className="p-4 text-center"><p className="text-3xl font-heading font-bold">{stats.total}</p><p className="text-xs text-muted-foreground">إجمالي</p></CardContent></Card>
              <Card><CardContent className="p-4 text-center"><p className="text-3xl font-heading font-bold text-primary">{stats.byType.length}</p><p className="text-xs text-muted-foreground">أنواع مختلفة</p></CardContent></Card>
              <Card><CardContent className="p-4 text-center"><p className="text-3xl font-heading font-bold text-emerald-600">{stats.byCategory.length}</p><p className="text-xs text-muted-foreground">تصنيفات</p></CardContent></Card>
            </div>

            {/* Pie Charts */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Card>
                <CardContent className="p-4">
                  <h4 className="text-sm font-bold mb-3 flex items-center gap-2"><PieChart className="w-4 h-4" /> حسب النوع</h4>
                  {stats.byType.length > 0 ? (
                    <ResponsiveContainer width="100%" height={200}>
                      <RePieChart>
                        <Pie data={stats.byType} cx="50%" cy="50%" outerRadius={70} dataKey="value" label={({ name, value }) => `${TYPE_CONFIG[name]?.label || name}: ${value}`}>
                          {stats.byType.map((entry: any) => <Cell key={entry.name} fill={TYPE_CONFIG[entry.name]?.chartColor || '#94a3b8'} />)}
                        </Pie>
                        <Tooltip />
                      </RePieChart>
                    </ResponsiveContainer>
                  ) : <p className="text-sm text-muted-foreground text-center py-8">لا توجد بيانات</p>}
                </CardContent>
              </Card>
              <Card>
                <CardContent className="p-4">
                  <h4 className="text-sm font-bold mb-3 flex items-center gap-2"><PieChart className="w-4 h-4" /> حسب التصنيف</h4>
                  {stats.byCategory.length > 0 ? (
                    <ResponsiveContainer width="100%" height={200}>
                      <RePieChart>
                        <Pie data={stats.byCategory} cx="50%" cy="50%" outerRadius={70} dataKey="value" label={({ name, value }) => `${CATEGORY_CONFIG[name]?.label || name}: ${value}`}>
                          {stats.byCategory.map((entry: any) => <Cell key={entry.name} fill={CATEGORY_CONFIG[entry.name]?.chartColor || '#94a3b8'} />)}
                        </Pie>
                        <Tooltip />
                      </RePieChart>
                    </ResponsiveContainer>
                  ) : <p className="text-sm text-muted-foreground text-center py-8">لا توجد بيانات</p>}
                </CardContent>
              </Card>
            </div>

            {/* Trend Bar Chart */}
            <Card>
              <CardContent className="p-4">
                <h4 className="text-sm font-bold mb-3 flex items-center gap-2"><TrendingUp className="w-4 h-4" /> آخر 7 أيام</h4>
                <ResponsiveContainer width="100%" height={200}>
                  <BarChart data={stats.trend}>
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                    <YAxis tick={{ fontSize: 11 }} />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="total" name="الإجمالي" fill="#6366f1" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="unread" name="غير مقروء" fill="#f59e0b" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>
        ) : null}

        <DialogFooter><Button variant="outline" onClick={() => onOpenChange(false)}>إغلاق</Button></DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ═══════════════════════════════════════
// Templates Dialog
// ═══════════════════════════════════════

function NotificationTemplatesDialog({ open, onOpenChange, onUseTemplate }: { open: boolean; onOpenChange: (v: boolean) => void; onUseTemplate: (t: any) => void }) {
  const { data: templates, isLoading } = useNotificationTemplates()
  const { toast } = useToast()

  const handleCopy = (t: any) => {
    navigator.clipboard.writeText(`${t.title}\n${t.body}`)
    toast({ title: 'تم نسخ القالب', variant: 'success' })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2"><LayoutTemplate className="w-5 h-5 text-primary" /> قوالب الإشعارات</DialogTitle>
          <DialogDescription>قوالب جاهزة للإرسال السريع</DialogDescription>
        </DialogHeader>

        <div className="space-y-2 py-2 max-h-[60vh] overflow-y-auto">
          {isLoading ? (
            Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="w-full h-20" />)
          ) : templates && templates.length > 0 ? (
            templates.map((t: any) => {
              const typeInfo = TYPE_CONFIG[t.type] || TYPE_CONFIG.info
              const TypeIcon = typeInfo.icon
              return (
                <Card key={t.id} className="hover:shadow-md transition-shadow cursor-pointer group" onClick={() => { onUseTemplate(t); onOpenChange(false) }}>
                  <CardContent className="p-4">
                    <div className="flex gap-3">
                      <div className={cn('p-2 rounded-lg border shrink-0', typeInfo.bg)}>
                        <TypeIcon className={cn('w-4 h-4', typeInfo.color)} />
                      </div>
                      <div className="flex-1 min-w-0">
                        <h4 className="font-bold text-sm">{t.title}</h4>
                        <p className="text-xs text-muted-foreground mt-0.5 line-clamp-2">{t.body || '(فارغ — أدخل النص يدوياً)'}</p>
                        <div className="flex items-center gap-2 mt-2">
                          <Badge className={cn('text-[9px]', typeInfo.bg, typeInfo.color)}>{typeInfo.label}</Badge>
                          {t.category && CATEGORY_CONFIG[t.category] && <Badge variant="outline" className="text-[9px]">{CATEGORY_CONFIG[t.category].label}</Badge>}
                        </div>
                      </div>
                      <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100 shrink-0" onClick={(e) => { e.stopPropagation(); handleCopy(t) }}>
                        <Copy className="w-4 h-4" />
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              )
            })
          ) : (
            <p className="text-sm text-muted-foreground text-center py-8">لا توجد قوالب</p>
          )}
        </div>

        <DialogFooter><Button variant="outline" onClick={() => onOpenChange(false)}>إغلاق</Button></DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
