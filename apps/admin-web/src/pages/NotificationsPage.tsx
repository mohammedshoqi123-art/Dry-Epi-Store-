import { useState, useMemo } from 'react'
import {
  Bell, CheckCheck, Filter, Info, CheckCircle, AlertCircle, Clock,
  Trash2, MoreVertical, Eye, EyeOff, Settings, Send, Search,
  AlertTriangle, FileText, Users, MapPin, MessageSquare, RefreshCw
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
import { useNotifications, useMarkNotificationRead, useMarkAllNotificationsRead } from '@/hooks/useApi'
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
  const [selectedNotif, setSelectedNotif] = useState<Notification | null>(null)
  const [composeOpen, setComposeOpen] = useState(false)

  const { data: notifications, isLoading, isError, error, refetch } = useNotifications()
  const markRead = useMarkNotificationRead()
  const markAllRead = useMarkAllNotificationsRead()
  const { toast } = useToast()

  // Filter notifications
  const filtered = useMemo(() => {
    return notifications?.filter((n: Notification) => {
      if (typeFilter !== 'all' && n.type !== typeFilter) return false
      if (categoryFilter !== 'all' && n.category !== categoryFilter) return false
      if (readFilter === 'unread' && n.is_read) return false
      if (readFilter === 'read' && !n.is_read) return false
      if (search && !n.title.includes(search) && !n.body.includes(search)) return false
      return true
    }) || []
  }, [notifications, typeFilter, categoryFilter, readFilter, search])

  const unreadCount = notifications?.filter((n: Notification) => !n.is_read).length || 0
  const todayCount = notifications?.filter((n: Notification) => {
    const notifDate = new Date(n.created_at).toDateString()
    return notifDate === new Date().toDateString()
  }).length || 0

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

        {/* Actions Bar */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              placeholder="بحث في الإشعارات..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pr-10"
            />
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

          <div className="flex gap-2 mr-auto">
            {unreadCount > 0 && (
              <Button
                variant="outline"
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
            <Button className="gap-2" onClick={() => setComposeOpen(true)}>
              <Send className="w-4 h-4" />
              إشعار جديد
            </Button>
          </div>
        </div>

        {/* Notifications List */}
        <div className="space-y-2">
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
                  {search || typeFilter || categoryFilter ? 'جرّب تغيير الفلاتر' : 'ستظهر الإشعارات الجديدة هنا'}
                </p>
              </CardContent>
            </Card>
          ) : (
            filtered.map((notif: Notification) => {
              const typeInfo = TYPE_CONFIG[notif.type] || TYPE_CONFIG.info
              const catInfo = CATEGORY_CONFIG[notif.category]
              const TypeIcon = typeInfo.icon
              const CatIcon = catInfo?.icon

              return (
                <Card
                  key={notif.id}
                  className={cn(
                    'transition-all duration-200 cursor-pointer hover:shadow-md group',
                    !notif.is_read && 'border-r-4 border-r-primary bg-primary/[0.03]'
                  )}
                  onClick={() => {
                    setSelectedNotif(notif)
                    if (!notif.is_read) markRead.mutate(notif.id)
                  }}
                >
                  <CardContent className="p-4">
                    <div className="flex gap-3">
                      {/* Type Icon */}
                      <div className={cn(
                        'p-2.5 rounded-xl shrink-0 border',
                        typeInfo.bg
                      )}>
                        <TypeIcon className={cn('w-5 h-5', typeInfo.color)} />
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
                          'text-sm leading-relaxed',
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
                            markRead.mutate(notif.id)
                          }}>
                            {notif.is_read ? <EyeOff className="w-4 h-4 ml-2" /> : <Eye className="w-4 h-4 ml-2" />}
                            {notif.is_read ? 'تحديد كغير مقروء' : 'تحديد كمقروء'}
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem
                            className="text-red-600 focus:text-red-600"
                            onClick={(e) => e.stopPropagation()}
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
  const { toast } = useToast()

  const handleSend = () => {
    if (!title.trim() || !body.trim()) {
      toast({ title: 'العنوان والنص مطلوبان', variant: 'destructive' })
      return
    }
    // Would call supabase function to create notification
    toast({ title: 'تم إرسال الإشعار بنجاح', variant: 'success' })
    setTitle('')
    setBody('')
    onOpenChange(false)
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
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button onClick={handleSend} className="gap-2">
            <Send className="w-4 h-4" />
            إرسال
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
