import { useState } from 'react'
import { Search, Filter, Eye, Clock, User, Database, Activity } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table'
import { Header } from '@/components/layout/header'
import { useAuditLogs } from '@/hooks/useApi'
import { supabase } from '@/lib/supabase'
import { formatDateTime, formatRelativeTime, cn } from '@/lib/utils'

const ACTION_LABELS: Record<string, string> = {
  create: 'إنشاء', read: 'عرض', update: 'تحديث', delete: 'حذف',
  login: 'دخول', logout: 'خروج', submit: 'إرسال', approve: 'اعتماد', reject: 'رفض', export: 'تصدير',
}

const ACTION_COLORS: Record<string, string> = {
  create: 'bg-emerald-100 text-emerald-700',
  read: 'bg-blue-100 text-blue-700',
  update: 'bg-amber-100 text-amber-700',
  delete: 'bg-red-100 text-red-700',
  login: 'bg-purple-100 text-purple-700',
  logout: 'bg-gray-100 text-gray-700',
  submit: 'bg-cyan-100 text-cyan-700',
  approve: 'bg-emerald-100 text-emerald-700',
  reject: 'bg-red-100 text-red-700',
  export: 'bg-indigo-100 text-indigo-700',
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
    'الجدول': log.table_name,
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
  const [actionFilter, setActionFilter] = useState<string>('')
  const [page, setPage] = useState(1)
  const { data, isLoading, refetch } = useAuditLogs({
    action: actionFilter || undefined,
    page,
  })

  const logs = data?.data || []
  const totalCount = data?.count || 0

  return (
    <div className="page-enter">
      <Header title="سجل التدقيق" subtitle={`${totalCount} سجل`} onRefresh={() => refetch()} />

      <div className="p-6 space-y-6">
        {/* Filters */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <Select value={actionFilter} onValueChange={(v) => { setActionFilter(v); setPage(1) }}>
            <SelectTrigger className="w-48">
              <SelectValue placeholder="كل العمليات" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="">كل العمليات</SelectItem>
              {Object.entries(ACTION_LABELS).map(([key, label]) => (
                <SelectItem key={key} value={key}>{label}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Button variant="outline" className="gap-2 mr-auto" onClick={() => exportAuditLogs()}>
            <Activity className="w-4 h-4" />
            تصدير السجل
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
                    <TableHead>الإجراء</TableHead>
                    <TableHead>الجدول</TableHead>
                    <TableHead>المستخدم</TableHead>
                    <TableHead>التوقيت</TableHead>
                    <TableHead>العنوان IP</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {logs.map((log) => (
                    <TableRow key={log.id} className="table-row-hover">
                      <TableCell>
                        <Badge className={cn('text-xs', ACTION_COLORS[log.action] || 'bg-gray-100 text-gray-700')}>
                          {ACTION_LABELS[log.action] || log.action}
                        </Badge>
                      </TableCell>
                      <TableCell className="font-mono text-sm">{log.table_name}</TableCell>
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
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>

        {/* Pagination */}
        {totalCount > 50 && (
          <div className="flex items-center justify-between">
            <p className="text-sm text-muted-foreground">
              عرض {(page - 1) * 50 + 1} — {Math.min(page * 50, totalCount)} من {totalCount}
            </p>
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>السابق</Button>
              <span className="text-sm">{page}</span>
              <Button variant="outline" size="sm" onClick={() => setPage(p => p + 1)}>التالي</Button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
