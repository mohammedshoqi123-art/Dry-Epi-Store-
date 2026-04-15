import { useState, useMemo } from 'react'
import {
  Search, Filter, Eye, Clock, User, Database, Activity,
  Download, ChevronLeft, ChevronRight, Calendar, Shield,
  FileText, LogIn, LogOut, CheckCircle, XCircle, RefreshCw
} from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog'
import { Header } from '@/components/layout/header'
import { useAuditLogs } from '@/hooks/useApi'
import { supabase } from '@/lib/supabase'
import { formatDateTime, formatRelativeTime, cn } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'

const ACTION_LABELS: Record<string, string> = {
  create: 'إنشاء', read: 'عرض', update: 'تحديث', delete: 'حذف',
  login: 'دخول', logout: 'خروج', submit: 'إرسال', approve: 'اعتماد',
  reject: 'رفض', export: 'تصدير',
}

const ACTION_COLORS: Record<string, string> = {
  create: 'bg-emerald-100 text-emerald-700 border-emerald-200',
  read: 'bg-blue-100 text-blue-700 border-blue-200',
  update: 'bg-amber-100 text-amber-700 border-amber-200',
  delete: 'bg-red-100 text-red-700 border-red-200',
  login: 'bg-purple-100 text-purple-700 border-purple-200',
  logout: 'bg-gray-100 text-gray-700 border-gray-200',
  submit: 'bg-cyan-100 text-cyan-700 border-cyan-200',
  approve: 'bg-emerald-100 text-emerald-700 border-emerald-200',
  reject: 'bg-red-100 text-red-700 border-red-200',
  export: 'bg-indigo-100 text-indigo-700 border-indigo-200',
}

const ACTION_ICONS: Record<string, React.ElementType> = {
  create: CheckCircle,
  read: Eye,
  update: RefreshCw,
  delete: XCircle,
  login: LogIn,
  logout: LogOut,
  submit: FileText,
  approve: CheckCircle,
  reject: XCircle,
  export: Download,
}

const TABLE_LABELS: Record<string, string> = {
  profiles: 'المستخدمون',
  forms: 'النماذج',
  form_submissions: 'الإرساليات',
  supply_shortages: 'النواقص',
  audit_logs: 'سجل التدقيق',
  chat_messages: 'المحادثات',
  notifications: 'الإشعارات',
  governorates: 'المحافظات',
  districts: 'المديريات',
  pages: 'الصفحات',
}

interface AuditLogEntry {
  id: string
  user_id: string
  action: string
  table_name: string
  record_id?: string
  old_data?: Record<string, unknown>
  new_data?: Record<string, unknown>
  ip_address?: string
  user_agent?: string
  created_at: string
  profiles?: { full_name: string; email: string }
}

async function exportAuditLogs() {
  const { data } = await supabase
    .from('audit_logs')
    .select('*, profiles(full_name, email)')
    .order('created_at', { ascending: false })
    .limit(5000)

  if (!data || data.length === 0) return

  const headers = ['الإجراء', 'الجدول', 'المستخدم', 'البريد', 'التاريخ', 'العنوان IP']
  const rows = data.map((log) => ({
    'الإجراء': ACTION_LABELS[log.action] || log.action,
    'الجدول': TABLE_LABELS[log.table_name] || log.table_name,
    'المستخدم': log.profiles?.full_name || '',
    'البريد': log.profiles?.email || '',
    'التاريخ': log.created_at,
    'العنوان IP': log.ip_address || '',
  }))

  const csv = [headers.join(','), ...rows.map((r) => headers.map((h) => {
    const val = String(r[h as keyof typeof r] || '')
    if (val.includes(',') || val.includes('"')) return `"${val.replace(/"/g, '""')}"`
    return val
  }).join(','))].join('\n')

  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `audit_logs_${new Date().toISOString().split('T')[0]}.csv`
  link.click()
  URL.revokeObjectURL(url)
}

export default function AuditPage() {
  const [actionFilter, setActionFilter] = useState<string>('all')
  const [tableFilter, setTableFilter] = useState<string>('all')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [selectedLog, setSelectedLog] = useState<AuditLogEntry | null>(null)
  const { data, isLoading, isError, error, refetch } = useAuditLogs({
    action: actionFilter !== 'all' ? actionFilter : undefined,
    page,
  })
  const { toast } = useToast()

  const logs = data?.data || []
  const totalCount = data?.count || 0
  const totalPages = Math.ceil(totalCount / 50)

  // Client-side filtering for table and search
  const filteredLogs = useMemo(() => {
    return logs.filter((log: AuditLogEntry) => {
      if (tableFilter !== 'all' && log.table_name !== tableFilter) return false
      if (search) {
        const searchLower = search.toLowerCase()
        const name = log.profiles?.full_name?.toLowerCase() || ''
        const email = log.profiles?.email?.toLowerCase() || ''
        const table = (TABLE_LABELS[log.table_name] || log.table_name).toLowerCase()
        if (!name.includes(searchLower) && !email.includes(searchLower) && !table.includes(searchLower)) return false
      }
      return true
    })
  }, [logs, tableFilter, search])

  // Quick stats
  const actionCounts = useMemo(() => {
    const counts: Record<string, number> = {}
    logs.forEach((log: AuditLogEntry) => {
      counts[log.action] = (counts[log.action] || 0) + 1
    })
    return counts
  }, [logs])

  return (
    <div className="page-enter">
      <Header title="سجل التدقيق" subtitle={`${totalCount} سجل`} onRefresh={() => refetch()} />

      <div className="p-6 space-y-6">
        {/* Error State */}
        {isError && (
          <Card className="border-red-200 bg-red-50/50">
            <CardContent className="p-6 text-center">
              <Shield className="w-10 h-10 text-red-500 mx-auto mb-3" />
              <h3 className="font-bold text-red-700 mb-1">حدث خطأ في تحميل سجل التدقيق</h3>
              <p className="text-sm text-red-600 mb-3">{(error as Error)?.message || 'تعذر الاتصال بالخادم'}</p>
              <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-2">
                <RefreshCw className="w-4 h-4" /> إعادة المحاولة
              </Button>
            </CardContent>
          </Card>
        )}

        {/* Quick Stats */}
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          {Object.entries(ACTION_LABELS).slice(0, 5).map(([key, label]) => {
            const Icon = ACTION_ICONS[key] || Activity
            const count = actionCounts[key] || 0
            return (
              <Card key={key} className="cursor-pointer hover:shadow-md transition-shadow" onClick={() => setActionFilter(actionFilter === key ? '' : key)}>
                <CardContent className="p-3 flex items-center gap-2">
                  <div className={cn('p-1.5 rounded-lg border', ACTION_COLORS[key] || 'bg-gray-100')}>
                    <Icon className="w-4 h-4" />
                  </div>
                  <div>
                    <p className="text-lg font-heading font-bold">{count}</p>
                    <p className="text-[10px] text-muted-foreground">{label}</p>
                  </div>
                </CardContent>
              </Card>
            )
          })}
        </div>

        {/* Filters */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              placeholder="بحث بالمستخدم أو الجدول..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pr-10"
            />
          </div>

          <Select value={actionFilter} onValueChange={(v) => { setActionFilter(v); setPage(1) }}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="كل العمليات" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">كل العمليات</SelectItem>
              {Object.entries(ACTION_LABELS).map(([key, label]) => (
                <SelectItem key={key} value={key}>{label}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Select value={tableFilter} onValueChange={setTableFilter}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="كل الجداول" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">كل الجداول</SelectItem>
              {Object.entries(TABLE_LABELS).map(([key, label]) => (
                <SelectItem key={key} value={key}>{label}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Button variant="outline" className="gap-2" onClick={() => exportAuditLogs()}>
            <Download className="w-4 h-4" />
            تصدير CSV
          </Button>
        </div>

        {/* Table */}
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-6 space-y-3">
                {Array.from({ length: 10 }).map((_, i) => <Skeleton key={i} className="w-full h-12" />)}
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/50">
                    <TableHead className="w-12">#</TableHead>
                    <TableHead>الإجراء</TableHead>
                    <TableHead>الجدول</TableHead>
                    <TableHead>المستخدم</TableHead>
                    <TableHead>التوقيت</TableHead>
                    <TableHead>العنوان IP</TableHead>
                    <TableHead className="w-12"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredLogs.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={7} className="text-center py-12 text-muted-foreground">
                        <Database className="w-10 h-10 mx-auto mb-3 opacity-30" />
                        <p>لا توجد سجلات</p>
                      </TableCell>
                    </TableRow>
                  ) : (
                    filteredLogs.map((log: AuditLogEntry, idx: number) => (
                      <TableRow
                        key={log.id}
                        className="table-row-hover cursor-pointer"
                        onClick={() => setSelectedLog(log)}
                      >
                        <TableCell className="text-muted-foreground text-sm">
                          {(page - 1) * 50 + idx + 1}
                        </TableCell>
                        <TableCell>
                          <Badge className={cn('text-xs border gap-1', ACTION_COLORS[log.action] || 'bg-gray-100 text-gray-700')}>
                            {(() => { const I = ACTION_ICONS[log.action] || Activity; return <I className="w-3 h-3" /> })()}
                            {ACTION_LABELS[log.action] || log.action}
                          </Badge>
                        </TableCell>
                        <TableCell className="font-medium text-sm">
                          {TABLE_LABELS[log.table_name] || log.table_name}
                        </TableCell>
                        <TableCell>
                          <div>
                            <p className="font-medium text-sm">{log.profiles?.full_name || '—'}</p>
                            <p className="text-xs text-muted-foreground">{log.profiles?.email}</p>
                          </div>
                        </TableCell>
                        <TableCell>
                          <div>
                            <p className="text-sm">{formatRelativeTime(log.created_at)}</p>
                            <p className="text-xs text-muted-foreground">{formatDateTime(log.created_at)}</p>
                          </div>
                        </TableCell>
                        <TableCell className="font-mono text-xs text-muted-foreground" dir="ltr">
                          {log.ip_address || '—'}
                        </TableCell>
                        <TableCell>
                          <Button variant="ghost" size="icon-sm" onClick={(e) => { e.stopPropagation(); setSelectedLog(log) }}>
                            <Eye className="w-4 h-4" />
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between">
            <p className="text-sm text-muted-foreground">
              عرض {(page - 1) * 50 + 1} — {Math.min(page * 50, totalCount)} من {totalCount}
            </p>
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>
                <ChevronRight className="w-4 h-4" />
              </Button>
              <span className="text-sm font-medium px-2">{page} / {totalPages}</span>
              <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage(p => p + 1)}>
                <ChevronLeft className="w-4 h-4" />
              </Button>
            </div>
          </div>
        )}
      </div>

      {/* Log Detail Dialog */}
      {selectedLog && (
        <LogDetailDialog
          log={selectedLog}
          open={!!selectedLog}
          onOpenChange={() => setSelectedLog(null)}
        />
      )}
    </div>
  )
}

// ═══════════════════════════════════════
// Log Detail Dialog
// ═══════════════════════════════════════

function LogDetailDialog({ log, open, onOpenChange }: {
  log: AuditLogEntry
  open: boolean
  onOpenChange: (v: boolean) => void
}) {
  const typeInfo = ACTION_COLORS[log.action] || 'bg-gray-100 text-gray-700'

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Shield className="w-5 h-5 text-primary" />
            تفاصيل سجل التدقيق
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <p className="text-muted-foreground text-xs">الإجراء</p>
              <Badge className={cn('text-xs mt-1 border', typeInfo)}>
                {ACTION_LABELS[log.action] || log.action}
              </Badge>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">الجدول</p>
              <p className="font-medium mt-1">{TABLE_LABELS[log.table_name] || log.table_name}</p>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">المستخدم</p>
              <p className="font-medium mt-1">{log.profiles?.full_name || '—'}</p>
              <p className="text-xs text-muted-foreground">{log.profiles?.email}</p>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">التوقيت</p>
              <p className="font-medium mt-1">{formatDateTime(log.created_at)}</p>
            </div>
            <div>
              <p className="text-muted-foreground text-xs">العنوان IP</p>
              <p className="font-mono text-sm mt-1" dir="ltr">{log.ip_address || '—'}</p>
            </div>
            {log.record_id && (
              <div>
                <p className="text-muted-foreground text-xs">معرف السجل</p>
                <p className="font-mono text-xs mt-1 truncate" dir="ltr">{log.record_id}</p>
              </div>
            )}
          </div>

          {log.old_data && Object.keys(log.old_data).length > 0 && (
            <div>
              <p className="text-sm font-medium mb-2 text-amber-600">البيانات القديمة</p>
              <pre className="text-xs bg-amber-50 border border-amber-200 p-3 rounded-lg overflow-x-auto max-h-32" dir="ltr">
                {JSON.stringify(log.old_data, null, 2)}
              </pre>
            </div>
          )}

          {log.new_data && Object.keys(log.new_data).length > 0 && (
            <div>
              <p className="text-sm font-medium mb-2 text-emerald-600">البيانات الجديدة</p>
              <pre className="text-xs bg-emerald-50 border border-emerald-200 p-3 rounded-lg overflow-x-auto max-h-32" dir="ltr">
                {JSON.stringify(log.new_data, null, 2)}
              </pre>
            </div>
          )}

          {log.user_agent && (
            <div>
              <p className="text-sm text-muted-foreground mb-1">وكيل المستخدم</p>
              <p className="text-xs bg-muted p-2 rounded font-mono break-all" dir="ltr">{log.user_agent}</p>
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
