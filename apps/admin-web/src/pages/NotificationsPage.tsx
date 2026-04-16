import { useState, useMemo, useCallback } from 'react'
import {
  Bell, CheckCheck, Filter, Info, CheckCircle, AlertCircle, Clock,
  Trash2, MoreVertical, Eye, EyeOff, Settings, Send, Search,
  AlertTriangle, FileText, Users, MapPin, MessageSquare, RefreshCw,
  Calendar, ChevronDown, Download, CheckSquare, Square, MinusSquare,
  Volume2, VolumeX, Smartphone, Mail, Loader2, X
} from 'lucide-react'
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
import { useNotifications, useMarkNotificationRead, useMarkAllNotificationsRead, useDeleteNotification, useDeleteAllNotifications, useToggleNotificationRead, useSendNotification, useGovernorates } from '@/hooks/useApi'
import { formatRelativeTime, formatDateTime, cn } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'
import type { Notification } from '@/types/database'

// ═══════════════════════════════════════
// Notification Type Config
// ═══════════════════════════════════════

const TYPE_CONFIG: Record<string, { icon: React.ElementType; color: string; bg: string; label: string }> = {
  info: { icon: Info, color: 'text-blue-600', bg: 'bg-blue-50 border-blue-200', label: 'معلومة' },
  success: { icon: CheckCircle, color: 'text-emerald-600', bg: 'bg-emerald-50 border-emerald-200', label: 'نجاح' },
  error: { icon: AlertCircle, color: 'text-red-600', bg: 'bg-red-50 border-red-200', label: 'خطأ' },
  warning: { icon: AlertTriangle, color: 'text-amber-600', bg: 'bg-amber-50 border-amber-200', label: 'تحذير' },
}

const CATEGORY_CONFIG: Record<string, { icon: React.ElementType; label: string }> = {
  submission: { icon: FileText, label: 'إرسالية' },
  user: { icon: Users, label: 'مستخدم' },
  shortage: { icon: AlertTriangle, label: 'نقص' },
  system: { icon: Settings, label: 'نظام' },
  chat: { icon: MessageSquare, label: 'محادثة' },
  location: { icon: MapPin, label: 'موقع' },
}

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
  const [bulkMenuOpen, setBulkMenuOpen] = useState(false)

  const { data: notifications, isLoading, isError, error, refetch } = useNotifications()
  const markRead = useMarkNotificationRead()
  const markAllRead = useMarkAllNotificationsRead()
  const deleteNotif = useDeleteNotification()
  const deleteAll = useDeleteAllNotifications()
  const toggleRead = useToggleNotificationRead()
  const { toast } = useToast()

  // Filter notifications
  const filtered = useMemo(() => {
    return notifications?.filter((n: Notification) => {
      if (typeFilter !== 'all' && n.type !== typeFilter) return false
      if (categoryFilter !== 'all' && n.category !== categoryFilter) return false
      if (readFilter === 'unread' && n.is_read) return false
      if (readFilter === 'read' && !n.is_read) return false
      if (search && !n.title.includes(search) && !n.body.includes(search)) return false
      if (dateFrom) {
        const from = new Date(dateFrom)
        from.setHours(0, 0, 0, 0)
        if (new Date(n.created_at) < from) return false
      }
      if (dateTo) {
        const to = new Date(dateTo)
        to.setHours(23, 59, 59, 999)
        if (new Date(n.created_at) > to) return false
      }
      return true
    }) || []
  }, [notifications, typeFilter, categoryFilter, readFilter, search, dateFrom, dateTo])

  const unreadCount = notifications?.filter((n: Notification) => !n.is_read).length || 0
  const todayCount = notifications?.filter((n: Notification) => {
    const notifDate = new Date(n.created_at).toDateString()
    return notifDate === new Date().toDateString()
  }).length || 0

  const isAllSelected = filtered.length > 0 && filtered.every((n: Notification) => selectedIds.has(n.id))
  const isSomeSelected = filtered.some((n: Notification) => selectedIds.has(n.id))

  // Bulk actions
  const toggleSelect = useCallback((id: string) => {
    setSelectedIds(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }, [])

  const toggleSelectAll = useCallback(() => {
    if (isAllSelected) {
      setSelectedIds(new Set())
    } else {
      setSelectedIds(new Set(filtered.map((n: Notification) => n.id)))
    }
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
    deleteNotif.mutate(id, {
      onSuccess: () => toast({ title: 'تم حذف الإشعار', variant: 'success' })
    })
  }

  const handleDeleteAll = () => {
    if (!confirm('هل أنت متأكد من حذف جميع الإشعارات؟')) return
    deleteAll.mutate(undefined, {
      onSuccess: () => toast({ title: 'تم حذف جميع الإشعارات', variant: 'success' })
    })
  }

  // Export to CSV
  const handleExport = useCallback(() => {
    const data = filtered.length > 0 ? filtered : notifications || []
    if (data.length === 0) {
      toast({ title: 'لا توجد بيانات للتصدير', variant: 'destructive' })
      return
    }

    const headers = ['العنوان', 'النص', 'النوع', 'التصنيف', 'الحالة', 'تاريخ الإنشاء']
    const rows = data.map((n: Notification) => [
      `"${n.title.replace(/"/g, '""')}"`,
      `"${n.body.replace(/"/g, '""')}"`,
      TYPE_CONFIG[n.type]?.label || n.type,
      CATEGORY_CONFIG[n.category]?.label || n.category,
      n.is_read ? 'مقروء' : 'غير مقروء',
      formatDateTime(n.created_at),
    ])

    const csvContent = '\uFEFF' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n')
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `notifications_${new Date().toISOString().split('T')[0]}.csv`
    link.click()
    URL.revokeObjectURL(url)
    toast({ title: `تم تصدير ${data.length} إشعار`, variant: 'success' })
  }, [filtered, notifications, toast])

  const activeFiltersCount = [
    typeFilter !== 'all',
    categoryFilter !== 'all',
    readFilter !== 'all',
    dateFrom,
    dateTo,
    search,
  ].filter(Boolean).length

  const clearFilters = () => {
    setTypeFilter('all')
    setCategoryFilter('all')
    setReadFilter('all')
    setDateFrom('')
    setDateTo('')
    setSearch('')
  }

  return (
    <div className="page-enter">
      <Header
        title="الإشعارات"
        subtitle={unreadCount > 0 ? `${unreadCount} غير مقروء • ${todayCount} اليوم` : 'كلها مقروءة'}
        onRefresh={() => refetch()}
      />

      <div className="p-6 space-y-6">
        {/* Error State */}
        {isError && (
          <Card className="border-red-200 bg-red-50/50">
            <CardContent className="p-6 text-center">
              <AlertCircle className="w-10 h-10 text-red-500 mx-auto mb-3" />
              <h3 className="font-bold text-red-700 mb-1">حدث خطأ في تحميل الإشعارات</h3>
              <p className="text-sm text-red-600 mb-3">{(error as Error)?.message || 'تعذر الاتصال بالخادم'}</p>
              <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-2">
                <RefreshCw className="w-4 h-4" /> إعادة المحاولة
              </Button>
            </CardContent>
          </Card>
        )}

        {/* Stats Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card className={cn(unreadCount > 0 && 'border-primary/30 bg-primary/5')}>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/10">
                <Bell className="w-5 h-5 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold">{notifications?.length || 0}</p>
                <p className="text-xs text-muted-foreground">إجمالي</p>
              </div>
            </CardContent>
          </Card>
          <Card className={cn(unreadCount > 0 && 'border-amber-300 bg-amber-50/50')}>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-amber-100">
                <EyeOff className="w-5 h-5 text-amber-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold text-amber-600">{unreadCount}</p>
                <p className="text-xs text-muted-foreground">غير مقروء</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-emerald-100">
                <Clock className="w-5 h-5 text-emerald-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold">{todayCount}</p>
                <p className="text-xs text-muted-foreground">اليوم</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-blue-100">
                <CheckCircle className="w-5 h-5 text-blue-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold">{(notifications?.length || 0) - unreadCount}</p>
                <p className="text-xs text-muted-foreground">مقروء</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* ═══ Actions Bar ═══ */}
        <div className="space-y-3">
          <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
            <div className="relative flex-1">
              <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                placeholder="بحث في الإشعارات..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pr-10"
              />
              {search && (
                <button
                  onClick={() => setSearch('')}
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                >
                  <X className="w-3.5 h-3.5" />
                </button>
              )}
            </div>

            <Tabs value={readFilter} onValueChange={setReadFilter}>
              <TabsList>
                <TabsTrigger value="all" className="text-xs">الكل</TabsTrigger>
                <TabsTrigger value="unread" className="text-xs">غير مقروء</TabsTrigger>
                <TabsTrigger value="read" className="text-xs">مقروء</TabsTrigger>
              </TabsList>
            </Tabs>

            <Select value={typeFilter} onValueChange={setTypeFilter}>
              <SelectTrigger className="w-36">
                <SelectValue placeholder="النوع" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">كل الأنواع</SelectItem>
                {Object.entries(TYPE_CONFIG).map(([key, cfg]) => (
                  <SelectItem key={key} value={key}>{cfg.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>

            <Select value={categoryFilter} onValueChange={setCategoryFilter}>
              <SelectTrigger className="w-36">
                <SelectValue placeholder="التصنيف" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">كل التصنيفات</SelectItem>
                {Object.entries(CATEGORY_CONFIG).map(([key, cfg]) => (
                  <SelectItem key={key} value={key}>{cfg.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>

            <Button
              variant={showDateFilter ? 'secondary' : 'outline'}
              size="sm"
              className="gap-2"
              onClick={() => setShowDateFilter(!showDateFilter)}
            >
              <Calendar className="w-4 h-4" />
              التاريخ
              {activeFiltersCount > 0 && (
                <Badge className="h-5 w-5 rounded-full p-0 text-[10px] flex items-center justify-center">
                  {activeFiltersCount}
                </Badge>
              )}
            </Button>
          </div>

          {/* Date Range Filter */}
          {showDateFilter && (
            <div className="flex flex-wrap items-center gap-3 p-3 rounded-lg bg-muted/30 border">
              <div className="flex items-center gap-2">
                <label className="text-xs text-muted-foreground whitespace-nowrap">من</label>
                <Input
                  type="date"
                  value={dateFrom}
                  onChange={(e) => setDateFrom(e.target.value)}
                  className="h-8 text-xs w-36"
                />
              </div>
              <div className="flex items-center gap-2">
                <label className="text-xs text-muted-foreground whitespace-nowrap">إلى</label>
                <Input
                  type="date"
                  value={dateTo}
                  onChange={(e) => setDateTo(e.target.value)}
                  className="h-8 text-xs w-36"
                />
              </div>
              {activeFiltersCount > 0 && (
                <Button variant="ghost" size="sm" className="text-xs gap-1 h-8" onClick={clearFilters}>
                  <X className="w-3 h-3" />
                  مسح الفلاتر ({activeFiltersCount})
                </Button>
              )}
            </div>
          )}

          {/* Action Buttons Row */}
          <div className="flex items-center gap-2 flex-wrap">
            {/* Bulk Select */}
            {filtered.length > 0 && (
              <Button
                variant="ghost"
                size="sm"
                className="gap-2"
                onClick={toggleSelectAll}
              >
                {isAllSelected ? (
                  <CheckSquare className="w-4 h-4 text-primary" />
                ) : isSomeSelected ? (
                  <MinusSquare className="w-4 h-4 text-primary" />
                ) : (
                  <Square className="w-4 h-4" />
                )}
                تحديد
              </Button>
            )}

            {/* Bulk Actions (shown when items selected) */}
            {selectedIds.size > 0 && (
              <>
                <Badge variant="secondary" className="gap-1">
                  {selectedIds.size} محدد
                </Badge>
                <Button variant="outline" size="sm" className="gap-2" onClick={handleBulkMarkRead}>
                  <Eye className="w-3.5 h-3.5" />
                  تحديد كمقروء
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  className="gap-2 text-red-600 hover:text-red-700 hover:bg-red-50 border-red-200"
                  onClick={handleBulkDelete}
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  حذف المحدد
                </Button>
                <Button variant="ghost" size="sm" onClick={clearSelection}>
                  إلغاء التحديد
                </Button>
              </>
            )}

            <div className="flex-1" />

            {/* Right-side actions */}
            <Button variant="outline" size="sm" className="gap-2" onClick={handleExport}>
              <Download className="w-4 h-4" />
              تصدير CSV
            </Button>

            {notifications && notifications.length > 0 && (
              <Button
                variant="ghost"
                size="sm"
                className="gap-2 text-red-600 hover:text-red-700 hover:bg-red-50"
                onClick={handleDeleteAll}
                disabled={deleteAll.isPending}
              >
                <Trash2 className="w-4 h-4" />
                حذف الكل
              </Button>
            )}

            {unreadCount > 0 && (
              <Button
                variant="outline"
                size="sm"
                className="gap-2"
                onClick={() => markAllRead.mutate(undefined, {
                  onSuccess: () => toast({ title: 'تم تحديد الكل كمقروء', variant: 'success' })
                })}
                disabled={markAllRead.isPending}
              >
                <CheckCheck className="w-4 h-4" />
                قراءة الكل
              </Button>
            )}

            <Button variant="outline" size="sm" className="gap-2" onClick={() => setSettingsOpen(true)}>
              <Settings className="w-4 h-4" />
              إعدادات
            </Button>

            <Button size="sm" className="gap-2" onClick={() => setComposeOpen(true)}>
              <Send className="w-4 h-4" />
              إشعار جديد
            </Button>
          </div>
        </div>

        {/* ═══ Notifications List ═══ */}
        <div className="space-y-2">
          {/* Results count */}
          {!isLoading && (
            <div className="flex items-center justify-between px-1">
              <p className="text-xs text-muted-foreground">
                {filtered.length} إشعار{filtered.length !== (notifications?.length || 0) && ` من أصل ${notifications?.length || 0}`}
              </p>
            </div>
          )}

          {isLoading ? (
            Array.from({ length: 5 }).map((_, i) => (
              <Card key={i}><CardContent className="p-4"><Skeleton className="w-full h-16" /></CardContent></Card>
            ))
          ) : filtered.length === 0 ? (
            <Card>
              <CardContent className="p-16 flex flex-col items-center text-muted-foreground">
                <div className="w-20 h-20 rounded-2xl bg-muted flex items-center justify-center mb-4">
                  <Bell className="w-10 h-10 opacity-30" />
                </div>
                <p className="font-heading font-bold text-lg">لا توجد إشعارات</p>
                <p className="text-sm mt-1">
                  {activeFiltersCount > 0 ? 'جرّب تغيير الفلاتر' : 'ستظهر الإشعارات الجديدة هنا'}
                </p>
                {activeFiltersCount > 0 && (
                  <Button variant="outline" size="sm" className="mt-3" onClick={clearFilters}>
                    مسح الفلاتر
                  </Button>
                )}
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
                <Card
                  key={notif.id}
                  className={cn(
                    'transition-all duration-200 cursor-pointer hover:shadow-md group',
                    !notif.is_read && 'border-r-4 border-r-primary bg-primary/[0.03]',
                    isSelected && 'ring-2 ring-primary/40 bg-primary/[0.06]'
                  )}
                  onClick={(e) => {
                    if (selectedIds.size > 0) {
                      e.preventDefault()
                      toggleSelect(notif.id)
                      return
                    }
                    setSelectedNotif(notif)
                    if (!notif.is_read) markRead.mutate(notif.id)
                  }}
                >
                  <CardContent className="p-4">
                    <div className="flex gap-3">
                      {/* Checkbox / Type Icon */}
                      <div
                        className="relative shrink-0"
                        onClick={(e) => {
                          e.stopPropagation()
                          toggleSelect(notif.id)
                        }}
                      >
                        <div className={cn(
                          'p-2.5 rounded-xl border transition-all',
                          isSelected ? 'bg-primary/10 border-primary/30' : typeInfo.bg
                        )}>
                          {isSelected ? (
                            <CheckSquare className="w-5 h-5 text-primary" />
                          ) : (
                            <TypeIcon className={cn('w-5 h-5', typeInfo.color)} />
                          )}
                        </div>
                      </div>

                      {/* Content */}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between gap-2 mb-1">
                          <div className="flex items-center gap-2 flex-wrap">
                            <h3 className={cn(
                              'font-bold text-sm',
                              !notif.is_read ? 'text-foreground' : 'text-foreground/80'
                            )}>
                              {notif.title}
                            </h3>
                            {!notif.is_read && (
                              <span className="w-2 h-2 rounded-full bg-primary shrink-0" />
                            )}
                          </div>
                          <div className="flex items-center gap-2 shrink-0">
                            <Badge className={cn('text-[9px]', typeInfo.bg, typeInfo.color)}>
                              {typeInfo.label}
                            </Badge>
                            <span className="text-[10px] text-muted-foreground flex items-center gap-1">
                              <Clock className="w-3 h-3" />
                              {formatRelativeTime(notif.created_at)}
                            </span>
                          </div>
                        </div>
                        <p className={cn(
                          'text-sm leading-relaxed line-clamp-2',
                          !notif.is_read ? 'text-foreground/70' : 'text-muted-foreground'
                        )}>
                          {notif.body}
                        </p>
                        <div className="flex items-center gap-2 mt-2">
                          {notif.category && CatIcon && (
                            <Badge variant="outline" className="text-[10px] gap-1">
                              <CatIcon className="w-3 h-3" />
                              {catInfo.label}
                            </Badge>
                          )}
                        </div>
                      </div>

                      {/* Actions */}
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button
                            variant="ghost"
                            size="icon-sm"
                            className="opacity-0 group-hover:opacity-100 shrink-0"
                            onClick={(e) => e.stopPropagation()}
                          >
                            <MoreVertical className="w-4 h-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem onClick={(e) => {
                            e.stopPropagation()
                            toggleRead.mutate({ id: notif.id, isRead: notif.is_read }, {
                              onSuccess: () => toast({
                                title: notif.is_read ? 'تم تحديد كغير مقروء' : 'تم تحديد كمقروء',
                                variant: 'success'
                              })
                            })
                          }}>
                            {notif.is_read ? <EyeOff className="w-4 h-4 ml-2" /> : <Eye className="w-4 h-4 ml-2" />}
                            {notif.is_read ? 'تحديد كغير مقروء' : 'تحديد كمقروء'}
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={(e) => {
                            e.stopPropagation()
                            toggleSelect(notif.id)
                          }}>
                            <CheckSquare className="w-4 h-4 ml-2" />
                            {isSelected ? 'إلغاء التحديد' : 'تحديد'}
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem
                            className="text-red-600 focus:text-red-600"
                            onClick={(e) => {
                              e.stopPropagation()
                              handleDelete(notif.id)
                            }}
                          >
                            <Trash2 className="w-4 h-4 ml-2" />
                            حذف
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

        {/* Load More */}
        {filtered.length > 0 && filtered.length >= 50 && (
          <div className="text-center">
            <Button variant="outline" className="gap-2">
              <RefreshCw className="w-4 h-4" />
              تحميل المزيد
            </Button>
          </div>
        )}
      </div>

      {/* Notification Detail Dialog */}
      {selectedNotif && (
        <NotificationDetailDialog
          notification={selectedNotif}
          open={!!selectedNotif}
          onOpenChange={() => setSelectedNotif(null)}
        />
      )}

      {/* Compose Notification Dialog */}
      <ComposeNotificationDialog
        open={composeOpen}
        onOpenChange={setComposeOpen}
      />

      {/* Notification Settings Dialog */}
      <NotificationSettingsDialog
        open={settingsOpen}
        onOpenChange={setSettingsOpen}
      />
    </div>
  )
}

// ═══════════════════════════════════════
// Notification Detail Dialog
// ═══════════════════════════════════════

function NotificationDetailDialog({ notification, open, onOpenChange }: {
  notification: Notification
  open: boolean
  onOpenChange: (v: boolean) => void
}) {
  const typeInfo = TYPE_CONFIG[notification.type] || TYPE_CONFIG.info
  const TypeIcon = typeInfo.icon

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <div className="flex items-center gap-3 mb-2">
            <div className={cn('p-2.5 rounded-xl border', typeInfo.bg)}>
              <TypeIcon className={cn('w-6 h-6', typeInfo.color)} />
            </div>
            <div>
              <DialogTitle className="text-lg">{notification.title}</DialogTitle>
              <p className="text-xs text-muted-foreground mt-0.5">
                {formatDateTime(notification.created_at)}
              </p>
            </div>
          </div>
        </DialogHeader>

        <div className="space-y-4">
          <div className="p-4 rounded-xl bg-muted/30 text-sm leading-relaxed">
            {notification.body}
          </div>

          <div className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <p className="text-muted-foreground text-xs">النوع</p>
              <Badge className={cn('text-xs mt-1', typeInfo.bg, typeInfo.color)}>
                {typeInfo.label}
              </Badge>
            </div>
            {notification.category && (
              <div>
                <p className="text-muted-foreground text-xs">التصنيف</p>
                <Badge variant="outline" className="text-xs mt-1">
                  {CATEGORY_CONFIG[notification.category]?.label || notification.category}
                </Badge>
              </div>
            )}
            <div>
              <p className="text-muted-foreground text-xs">الحالة</p>
              <Badge variant={notification.is_read ? 'secondary' : 'default'} className="text-xs mt-1">
                {notification.is_read ? 'مقروء' : 'غير مقروء'}
              </Badge>
            </div>
            {notification.read_at && (
              <div>
                <p className="text-muted-foreground text-xs">تاريخ القراءة</p>
                <p className="text-sm font-medium mt-1">{formatDateTime(notification.read_at)}</p>
              </div>
            )}
          </div>

          {notification.data && Object.keys(notification.data).length > 0 && (
            <div>
              <p className="text-sm text-muted-foreground mb-2">بيانات إضافية</p>
              <pre className="text-xs bg-muted p-3 rounded-lg overflow-x-auto max-h-32" dir="ltr">
                {JSON.stringify(notification.data, null, 2)}
              </pre>
            </div>
          )}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إغلاق</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ═══════════════════════════════════════
// Compose Notification Dialog
// ═══════════════════════════════════════

function ComposeNotificationDialog({ open, onOpenChange }: {
  open: boolean
  onOpenChange: (v: boolean) => void
}) {
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
    if (!title.trim() || !body.trim()) {
      toast({ title: 'العنوان والنص مطلوبان', variant: 'destructive' })
      return
    }
    sendNotif.mutate(
      { title: title.trim(), body: body.trim(), type, category, target: target as any, governorate_id: governorateId || undefined },
      {
        onSuccess: (data) => {
          toast({ title: `تم إرسال ${data.sent_count} إشعار بنجاح`, variant: 'success' })
          setTitle('')
          setBody('')
          setType('info')
          setCategory('system')
          setTarget('all')
          setGovernorateId('')
          onOpenChange(false)
        },
        onError: (err) => {
          toast({ title: 'فشل الإرسال', description: (err as Error).message, variant: 'destructive' })
        }
      }
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Send className="w-5 h-5 text-primary" />
            إرسال إشعار جديد
          </DialogTitle>
          <DialogDescription>أنشئ إشعاراً لجميع المستخدمين أو مجموعة محددة</DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-2">
          <div className="space-y-2">
            <label className="text-sm font-medium">العنوان *</label>
            <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="عنوان الإشعار" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">النص *</label>
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              className="w-full h-24 p-3 rounded-lg border bg-background text-sm resize-y focus:outline-none focus:ring-2 focus:ring-primary/30"
              placeholder="اكتب نص الإشعار..."
            />
          </div>

          <div className="grid grid-cols-3 gap-3">
            <div className="space-y-2">
              <label className="text-sm font-medium">النوع</label>
              <Select value={type} onValueChange={setType}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {Object.entries(TYPE_CONFIG).map(([key, cfg]) => (
                    <SelectItem key={key} value={key}>{cfg.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">التصنيف</label>
              <Select value={category} onValueChange={setCategory}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {Object.entries(CATEGORY_CONFIG).map(([key, cfg]) => (
                    <SelectItem key={key} value={key}>{cfg.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">المستلمين</label>
              <Select value={target} onValueChange={setTarget}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">جميع المستخدمين</SelectItem>
                  <SelectItem value="admin">المديرين فقط</SelectItem>
                  <SelectItem value="field">العاملين الميدانيين</SelectItem>
                  <SelectItem value="governorate">محافظة محددة</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          {target === 'governorate' && (
            <div className="space-y-2">
              <label className="text-sm font-medium">اختر المحافظة</label>
              <Select value={governorateId} onValueChange={setGovernorateId}>
                <SelectTrigger><SelectValue placeholder="اختر محافظة..." /></SelectTrigger>
                <SelectContent>
                  {governorates?.map((g: any) => (
                    <SelectItem key={g.id} value={g.id}>{g.name_ar}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          )}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button onClick={handleSend} className="gap-2" disabled={sendNotif.isPending}>
            {sendNotif.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
            {sendNotif.isPending ? 'جاري الإرسال...' : 'إرسال'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ═══════════════════════════════════════
// Notification Settings Dialog
// ═══════════════════════════════════════

function NotificationSettingsDialog({ open, onOpenChange }: {
  open: boolean
  onOpenChange: (v: boolean) => void
}) {
  const { toast } = useToast()
  const [settings, setSettings] = useState({
    // Channel preferences
    inApp: true,
    email: true,
    push: false,
    // Category toggles
    submissions: true,
    shortages: true,
    users: true,
    system: true,
    chat: true,
    // Quiet hours
    quietEnabled: false,
    quietFrom: '22:00',
    quietTo: '07:00',
    // Sound
    soundEnabled: true,
    soundVolume: 80,
  })

  const updateSetting = (key: string, value: boolean | number | string) => {
    setSettings(prev => ({ ...prev, [key]: value }))
  }

  const handleSave = () => {
    // Would save to Supabase user preferences
    localStorage.setItem('notification_settings', JSON.stringify(settings))
    toast({ title: 'تم حفظ الإعدادات', variant: 'success' })
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Settings className="w-5 h-5 text-primary" />
            إعدادات الإشعارات
          </DialogTitle>
          <DialogDescription>خصّص كيفية استلامك للإشعارات</DialogDescription>
        </DialogHeader>

        <div className="space-y-6 py-2">
          {/* Channels */}
          <div>
            <h4 className="text-sm font-bold mb-3">قنوات الاستلام</h4>
            <div className="space-y-2">
              <SettingToggle
                icon={Bell}
                label="إشعارات داخل التطبيق"
                description="تنبيهات في لوحة التحكم"
                checked={settings.inApp}
                onChange={(v) => updateSetting('inApp', v)}
              />
              <SettingToggle
                icon={Mail}
                label="إشعارات البريد الإلكتروني"
                description="إرسال ملخص إلى بريدك"
                checked={settings.email}
                onChange={(v) => updateSetting('email', v)}
              />
              <SettingToggle
                icon={Smartphone}
                label="إشعارات الدفع (Push)"
                description="تنبيهات فورية على الجهاز"
                checked={settings.push}
                onChange={(v) => updateSetting('push', v)}
              />
            </div>
          </div>

          {/* Categories */}
          <div>
            <h4 className="text-sm font-bold mb-3">أنواع الإشعارات</h4>
            <div className="space-y-2">
              <SettingToggle
                icon={FileText}
                label="الإرساليات"
                description="إشعارات الإرساليات الجديدة والمحدثة"
                checked={settings.submissions}
                onChange={(v) => updateSetting('submissions', v)}
              />
              <SettingToggle
                icon={AlertTriangle}
                label="النواقص"
                description="تنبيهات النواقص والتقارير"
                checked={settings.shortages}
                onChange={(v) => updateSetting('shortages', v)}
              />
              <SettingToggle
                icon={Users}
                label="المستخدمين"
                description="إشعارات تسجيل مستخدمين جدد"
                checked={settings.users}
                onChange={(v) => updateSetting('users', v)}
              />
              <SettingToggle
                icon={Settings}
                label="النظام"
                description="تحديثات وصيانة النظام"
                checked={settings.system}
                onChange={(v) => updateSetting('system', v)}
              />
              <SettingToggle
                icon={MessageSquare}
                label="المحادثات"
                description="رسائل جديدة في المحادثات"
                checked={settings.chat}
                onChange={(v) => updateSetting('chat', v)}
              />
            </div>
          </div>

          {/* Sound */}
          <div>
            <h4 className="text-sm font-bold mb-3">الصوت</h4>
            <div className="space-y-3">
              <SettingToggle
                icon={settings.soundEnabled ? Volume2 : VolumeX}
                label="تفعيل الصوت"
                description="تشغيل صوت عند استلام إشعار"
                checked={settings.soundEnabled}
                onChange={(v) => updateSetting('soundEnabled', v)}
              />
              {settings.soundEnabled && (
                <div className="pr-10">
                  <div className="flex items-center gap-3">
                    <VolumeX className="w-3.5 h-3.5 text-muted-foreground" />
                    <input
                      type="range"
                      min="0"
                      max="100"
                      value={settings.soundVolume}
                      onChange={(e) => updateSetting('soundVolume', Number(e.target.value))}
                      className="flex-1 h-1.5 accent-primary"
                    />
                    <Volume2 className="w-3.5 h-3.5 text-muted-foreground" />
                    <span className="text-xs text-muted-foreground w-8 text-left">{settings.soundVolume}%</span>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Quiet Hours */}
          <div>
            <h4 className="text-sm font-bold mb-3">ساعات الهدوء</h4>
            <SettingToggle
              icon={Clock}
              label="تفعيل ساعات الهدوء"
              description="كتم الإشعارات في فترة محددة"
              checked={settings.quietEnabled}
              onChange={(v) => updateSetting('quietEnabled', v)}
            />
            {settings.quietEnabled && (
              <div className="flex items-center gap-3 mt-3 pr-10">
                <div className="flex items-center gap-2 flex-1">
                  <label className="text-xs text-muted-foreground">من</label>
                  <Input
                    type="time"
                    value={settings.quietFrom}
                    onChange={(e) => updateSetting('quietFrom', e.target.value)}
                    className="h-8 text-xs"
                  />
                </div>
                <div className="flex items-center gap-2 flex-1">
                  <label className="text-xs text-muted-foreground">إلى</label>
                  <Input
                    type="time"
                    value={settings.quietTo}
                    onChange={(e) => updateSetting('quietTo', e.target.value)}
                    className="h-8 text-xs"
                  />
                </div>
              </div>
            )}
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button onClick={handleSave} className="gap-2">
            <CheckCircle className="w-4 h-4" />
            حفظ الإعدادات
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function SettingToggle({ icon: Icon, label, description, checked, onChange }: {
  icon: React.ElementType
  label: string
  description: string
  checked: boolean
  onChange: (v: boolean) => void
}) {
  return (
    <div
      className={cn(
        'flex items-center gap-3 p-3 rounded-lg border cursor-pointer transition-all',
        checked ? 'bg-primary/5 border-primary/20' : 'bg-muted/30 border-transparent hover:bg-muted/50'
      )}
      onClick={() => onChange(!checked)}
    >
      <div className={cn(
        'p-1.5 rounded-md',
        checked ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground'
      )}>
        <Icon className="w-4 h-4" />
      </div>
      <div className="flex-1 min-w-0">
        <p className={cn('text-sm font-medium', !checked && 'text-muted-foreground')}>{label}</p>
        <p className="text-[11px] text-muted-foreground">{description}</p>
      </div>
      <div className={cn(
        'w-9 h-5 rounded-full transition-colors relative',
        checked ? 'bg-primary' : 'bg-muted-foreground/30'
      )}>
        <div className={cn(
          'w-4 h-4 rounded-full bg-white absolute top-0.5 transition-transform shadow-sm',
          checked ? 'translate-x-0.5 rtl:-translate-x-0.5' : 'translate-x-4 rtl:-translate-x-4'
        )} />
      </div>
    </div>
  )
}
