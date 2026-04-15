import { useState } from 'react'
import { Bell, CheckCheck, Filter, Info, CheckCircle, AlertCircle, Clock } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Header } from '@/components/layout/header'
import { useNotifications, useMarkNotificationRead, useMarkAllNotificationsRead } from '@/hooks/useApi'
import { formatRelativeTime, cn } from '@/lib/utils'
import type { Notification } from '@/types/database'

const TYPE_ICONS: Record<string, React.ElementType> = {
  info: Info,
  success: CheckCircle,
  error: AlertCircle,
}

const TYPE_COLORS: Record<string, string> = {
  info: 'bg-blue-100 text-blue-700',
  success: 'bg-emerald-100 text-emerald-700',
  error: 'bg-red-100 text-red-700',
}

export default function NotificationsPage() {
  const [typeFilter, setTypeFilter] = useState<string>('')
  const { data: notifications, isLoading, refetch } = useNotifications()
  const markRead = useMarkNotificationRead()
  const markAllRead = useMarkAllNotificationsRead()

  const filtered = notifications?.filter((n: Notification) => {
    if (typeFilter && n.type !== typeFilter) return false
    return true
  })

  const unreadCount = notifications?.filter((n: Notification) => !n.is_read).length || 0

  return (
    <div className="page-enter">
      <Header
        title="الإشعارات"
        subtitle={unreadCount > 0 ? `${unreadCount} غير مقروء` : 'كلها مقروءة'}
        onRefresh={() => refetch()}
      />

      <div className="p-6 space-y-6">
        {/* Actions Bar */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <Select value={typeFilter} onValueChange={setTypeFilter}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="كل الأنواع" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="">كل الأنواع</SelectItem>
              <SelectItem value="info">معلومات</SelectItem>
              <SelectItem value="success">نجاح</SelectItem>
              <SelectItem value="error">خطأ</SelectItem>
            </SelectContent>
          </Select>

          {unreadCount > 0 && (
            <Button
              variant="outline"
              className="gap-2 mr-auto"
              onClick={() => markAllRead.mutate()}
              disabled={markAllRead.isPending}
            >
              <CheckCheck className="w-4 h-4" />
              تحديد الكل كمقروء
            </Button>
          )}
        </div>

        {/* Notifications List */}
        <div className="space-y-3">
          {isLoading ? (
            Array.from({ length: 5 }).map((_, i) => (
              <Card key={i}><CardContent className="p-4"><Skeleton className="w-full h-16" /></CardContent></Card>
            ))
          ) : filtered?.length === 0 ? (
            <Card>
              <CardContent className="p-12 flex flex-col items-center text-muted-foreground">
                <Bell className="w-12 h-12 mb-3 opacity-30" />
                <p className="text-sm">لا توجد إشعارات</p>
              </CardContent>
            </Card>
          ) : (
            filtered?.map((notif: Notification) => {
              const Icon = TYPE_ICONS[notif.type] || Info
              return (
                <Card
                  key={notif.id}
                  className={cn(
                    'transition-all duration-200 cursor-pointer hover:shadow-card-hover',
                    !notif.is_read && 'border-r-4 border-r-primary bg-primary/5'
                  )}
                  onClick={() => {
                    if (!notif.is_read) markRead.mutate(notif.id)
                  }}
                >
                  <CardContent className="p-4">
                    <div className="flex gap-3">
                      <div className={cn(
                        'p-2 rounded-lg shrink-0',
                        TYPE_COLORS[notif.type] || 'bg-gray-100 text-gray-700'
                      )}>
                        <Icon className="w-5 h-5" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between gap-2 mb-1">
                          <h3 className="font-bold text-sm">{notif.title}</h3>
                          <div className="flex items-center gap-2 shrink-0">
                            {!notif.is_read && (
                              <Badge variant="default" className="text-[10px] px-1.5 py-0">جديد</Badge>
                            )}
                            <span className="text-[10px] text-muted-foreground flex items-center gap-1">
                              <Clock className="w-3 h-3" />
                              {formatRelativeTime(notif.created_at)}
                            </span>
                          </div>
                        </div>
                        <p className="text-sm text-muted-foreground">{notif.body}</p>
                        {notif.category && (
                          <Badge variant="outline" className="text-[10px] mt-2">
                            {notif.category}
                          </Badge>
                        )}
                      </div>
                    </div>
                  </CardContent>
                </Card>
              )
            })
          )}
        </div>
      </div>
    </div>
  )
}
