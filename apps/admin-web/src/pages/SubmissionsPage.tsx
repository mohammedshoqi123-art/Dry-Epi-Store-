import { useState } from 'react'
import {
  Search, Filter, CheckCircle2, XCircle, Clock, Eye, MessageSquare,
  ChevronLeft, ChevronRight, MapPin, Calendar, User, FileText, Download,
  AlertTriangle, RefreshCw
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Header } from '@/components/layout/header'
import { useSubmissions, useUpdateSubmissionStatus, useForms, useGovernorates } from '@/hooks/useApi'
import { supabase } from '@/lib/supabase'
import { STATUS_LABELS, STATUS_COLORS, type SubmissionStatus, type FormSubmission } from '@/types/database'
import { formatDateTime, formatRelativeTime, cn } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'

function convertToCSV(data: Record<string, unknown>[], headers: string[]): string {
  const headerRow = headers.join(',')
  const rows = data.map((row) =>
    headers.map((h) => {
      const val = row[h]
      const str = val === null || val === undefined ? '' : String(val)
      // Escape quotes and wrap in quotes if contains comma/quote/newline
      if (str.includes(',') || str.includes('"') || str.includes('\n')) {
        return `"${str.replace(/"/g, '""')}"`
      }
      return str
    }).join(',')
  )
  return [headerRow, ...rows].join('\n')
}

function downloadCSV(content: string, filename: string) {
  const blob = new Blob(['\uFEFF' + content], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}

async function exportSubmissions() {
  const { data } = await supabase
    .from('form_submissions')
    .select('*, forms(title_ar), profiles(full_name, email)')
    .is('deleted_at', null)
    .order('created_at', { ascending: false })
    .limit(5000)

  if (!data || data.length === 0) return

  const headers = ['الرقم', 'النموذج', 'المُرسل', 'البريد', 'الحالة', 'التاريخ']
  const rows = data.map((s, i) => ({
    'الرقم': i + 1,
    'النموذج': s.forms?.title_ar || '',
    'المُرسل': s.profiles?.full_name || '',
    'البريد': s.profiles?.email || '',
    'الحالة': s.status,
    'التاريخ': s.created_at,
  }))

  const csv = convertToCSV(rows, headers)
  downloadCSV(csv, `submissions_${new Date().toISOString().split('T')[0]}.csv`)
}

export default function SubmissionsPage() {
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [formFilter, setFormFilter] = useState<string>('all')
  const [page, setPage] = useState(1)
  const [selectedSubmission, setSelectedSubmission] = useState<FormSubmission | null>(null)

  const { data, isLoading, isError, error, refetch } = useSubmissions({
    status: statusFilter !== 'all' ? (statusFilter as SubmissionStatus) : undefined,
    formId: formFilter !== 'all' ? formFilter : undefined,
    page,
    pageSize: 20,
  })

  const { data: formsResult } = useForms()
  const forms = formsResult?.data
  const submissions = data?.data || []
  const totalCount = data?.count || 0
  const totalPages = Math.ceil(totalCount / 20)

  return (
    <div className="page-enter">
      <Header title="الإرساليات" subtitle={`${totalCount} إرسالية`} onRefresh={() => refetch()} />

      <div className="p-6 space-y-6">
        {/* Error State */}
        {isError && (
          <Card className="border-red-200 bg-red-50/50">
            <CardContent className="p-6 text-center">
              <AlertTriangle className="w-10 h-10 text-red-500 mx-auto mb-3" />
              <h3 className="font-bold text-red-700 mb-1">حدث خطأ في تحميل الإرساليات</h3>
              <p className="text-sm text-red-600 mb-3">{(error as Error)?.message || 'تعذر الاتصال بالخادم'}</p>
              <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-2">
                <RefreshCw className="w-4 h-4" /> إعادة المحاولة
              </Button>
            </CardContent>
          </Card>
        )}

        {/* Filters */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <Tabs value={statusFilter} onValueChange={(v) => { setStatusFilter(v); setPage(1) }}>
            <TabsList>
              <TabsTrigger value="all" className="text-xs">الكل</TabsTrigger>
              <TabsTrigger value="submitted" className="text-xs">مرسلة</TabsTrigger>
              <TabsTrigger value="reviewed" className="text-xs">تمت المراجعة</TabsTrigger>
              <TabsTrigger value="approved" className="text-xs">معتمدة</TabsTrigger>
              <TabsTrigger value="rejected" className="text-xs">مرفوضة</TabsTrigger>
            </TabsList>
          </Tabs>

          <Select value={formFilter} onValueChange={(v) => { setFormFilter(v); setPage(1) }}>
            <SelectTrigger className="w-48">
              <SelectValue placeholder="كل النماذج" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">كل النماذج</SelectItem>
              {forms?.map((f) => <SelectItem key={f.id} value={f.id}>{f.title_ar}</SelectItem>)}
            </SelectContent>
          </Select>

          <Button variant="outline" className="gap-2 mr-auto" onClick={() => exportSubmissions()}>
            <Download className="w-4 h-4" />
            تصدير CSV
          </Button>
        </div>

        {/* Table */}
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-6 space-y-3">
                {Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="w-full h-12" />)}
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/50">
                    <TableHead className="w-12">#</TableHead>
                    <TableHead>النموذج</TableHead>
                    <TableHead>المُرسل</TableHead>
                    <TableHead>الحالة</TableHead>
                    <TableHead>التاريخ</TableHead>
                    <TableHead className="w-12">إجراءات</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {submissions.map((sub, idx) => (
                    <TableRow key={sub.id} className="table-row-hover cursor-pointer" onClick={() => setSelectedSubmission(sub)}>
                      <TableCell className="text-muted-foreground text-sm">
                        {(page - 1) * 20 + idx + 1}
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <FileText className="w-4 h-4 text-muted-foreground" />
                          <span className="font-medium">{sub.forms?.title_ar || '—'}</span>
                        </div>
                      </TableCell>
                      <TableCell>
                        <div>
                          <p className="font-medium text-sm">{sub.profiles?.full_name || '—'}</p>
                          <p className="text-xs text-muted-foreground">{sub.profiles?.email}</p>
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge className={cn('text-xs', STATUS_COLORS[sub.status as SubmissionStatus])}>
                          {STATUS_LABELS[sub.status as SubmissionStatus]}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {formatRelativeTime(sub.created_at)}
                      </TableCell>
                      <TableCell>
                        <Button variant="ghost" size="icon-sm">
                          <Eye className="w-4 h-4" />
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between">
            <p className="text-sm text-muted-foreground">
              عرض {(page - 1) * 20 + 1} — {Math.min(page * 20, totalCount)} من {totalCount}
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

      {/* Submission Detail Dialog */}
      {selectedSubmission && (
        <SubmissionDetailDialog
          submission={selectedSubmission}
          open={!!selectedSubmission}
          onOpenChange={() => setSelectedSubmission(null)}
        />
      )}
    </div>
  )
}

function SubmissionDetailDialog({ submission, open, onOpenChange }: {
  submission: FormSubmission; open: boolean; onOpenChange: (v: boolean) => void
}) {
  const [reviewNotes, setReviewNotes] = useState('')
  const updateStatus = useUpdateSubmissionStatus()
  const { toast } = useToast()

  const handleAction = (status: SubmissionStatus) => {
    updateStatus.mutate({ id: submission.id, status, review_notes: reviewNotes || undefined }, {
      onSuccess: () => {
        toast({ title: status === 'approved' ? 'تم الاعتماد' : 'تم الرفض', variant: status === 'approved' ? 'success' : 'destructive' })
        onOpenChange(false)
      },
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>تفاصيل الإرسالية</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <p className="text-muted-foreground">النموذج</p>
              <p className="font-medium">{submission.forms?.title_ar || '—'}</p>
            </div>
            <div>
              <p className="text-muted-foreground">الحالة</p>
              <Badge className={cn('text-xs', STATUS_COLORS[submission.status as SubmissionStatus])}>
                {STATUS_LABELS[submission.status as SubmissionStatus]}
              </Badge>
            </div>
            <div>
              <p className="text-muted-foreground">المُرسل</p>
              <p className="font-medium">{submission.profiles?.full_name || '—'}</p>
            </div>
            <div>
              <p className="text-muted-foreground">التاريخ</p>
              <p className="font-medium">{formatDateTime(submission.created_at)}</p>
            </div>
          </div>

          {submission.notes && (
            <div>
              <p className="text-sm text-muted-foreground mb-1">ملاحظات</p>
              <p className="text-sm bg-muted p-3 rounded-lg">{submission.notes}</p>
            </div>
          )}

          {/* Data Preview */}
          <div>
            <p className="text-sm text-muted-foreground mb-2">البيانات</p>
            <pre className="text-xs bg-muted p-3 rounded-lg overflow-x-auto max-h-48" dir="ltr">
              {JSON.stringify(submission.data, null, 2)}
            </pre>
          </div>

          {/* Review Actions */}
          {(submission.status === 'submitted' || submission.status === 'reviewed') && (
            <div className="space-y-3 pt-3 border-t">
              <Input
                placeholder="ملاحظات المراجعة (اختياري)"
                value={reviewNotes}
                onChange={(e) => setReviewNotes(e.target.value)}
              />
              <div className="flex gap-2">
                <Button
                  variant="success"
                  className="flex-1 gap-2"
                  onClick={() => handleAction('approved')}
                  disabled={updateStatus.isPending}
                >
                  <CheckCircle2 className="w-4 h-4" />
                  اعتماد
                </Button>
                <Button
                  variant="destructive"
                  className="flex-1 gap-2"
                  onClick={() => handleAction('rejected')}
                  disabled={updateStatus.isPending}
                >
                  <XCircle className="w-4 h-4" />
                  رفض
                </Button>
              </div>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}
