import { useState, useMemo } from 'react'
import {
  Plus, Search, MoreVertical, Edit, Trash2, Eye, EyeOff,
  FileText, BookOpen, FolderOpen, ExternalLink, Download,
  AlertTriangle, RefreshCw, X, Loader2, Upload, Link as LinkIcon,
  CheckCircle2
} from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Switch } from '@/components/ui/switch'
import { Label } from '@/components/ui/label'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator } from '@/components/ui/dropdown-menu'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Header } from '@/components/layout/header'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase, isConfigured } from '@/lib/supabase'
import { formatDate, formatNumber, cn } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'

// ==================== Types ====================

interface DocReference {
  id: string
  title_ar: string
  description_ar: string | null
  file_url: string | null
  category: string
  is_active: boolean
  created_by: string | null
  created_at: string
  updated_at: string
  deleted_at: string | null
}

type RefCategory = 'guideline' | 'protocol' | 'manual' | 'report' | 'form_template' | 'training' | 'general'

const CATEGORY_LABELS: Record<RefCategory, { ar: string; icon: typeof BookOpen; color: string }> = {
  guideline: { ar: 'دليل/إرشادات', icon: BookOpen, color: 'text-blue-600 bg-blue-50' },
  protocol: { ar: 'بروتوكول', icon: FileText, color: 'text-purple-600 bg-purple-50' },
  manual: { ar: 'كتيب', icon: BookOpen, color: 'text-emerald-600 bg-emerald-50' },
  report: { ar: 'تقرير', icon: FileText, color: 'text-amber-600 bg-amber-50' },
  form_template: { ar: 'قالب نموذج', icon: FolderOpen, color: 'text-pink-600 bg-pink-50' },
  training: { ar: 'تدريب', icon: BookOpen, color: 'text-cyan-600 bg-cyan-50' },
  general: { ar: 'عام', icon: FileText, color: 'text-gray-600 bg-gray-50' },
}

// ==================== Hooks ====================

function useReferences(search?: string) {
  return useQuery({
    queryKey: ['references', search],
    queryFn: async () => {
      let query = supabase
        .from('doc_references')
        .select('*', { count: 'exact' })
        .is('deleted_at', null)
        .order('created_at', { ascending: false })

      if (search) {
        query = query.or(`title_ar.ilike.%${search}%,description_ar.ilike.%${search}%`)
      }

      const { data, error, count } = await query
      if (error) throw error
      return { data: (data || []) as DocReference[], count: count || 0 }
    },
    enabled: isConfigured,
    retry: 3,
    staleTime: 10000,
  })
}

function useCreateReference() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (data: { title_ar: string; description_ar?: string; file_url?: string; category: string; is_active: boolean }) => {
      const { data: { session } } = await supabase.auth.getSession()
      const { data: result, error } = await supabase
        .from('doc_references')
        .insert({ ...data, created_by: session?.user?.id })
        .select()
        .single()
      if (error) throw error
      return result
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['references'] }),
  })
}

function useUpdateReference() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, ...updates }: { id: string } & Partial<{ title_ar: string; description_ar: string; file_url: string; category: string; is_active: boolean }>) => {
      const { data, error } = await supabase
        .from('doc_references')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['references'] }),
  })
}

function useDeleteReference() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from('doc_references')
        .update({ deleted_at: new Date().toISOString() })
        .eq('id', id)
      if (error) throw error
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['references'] }),
  })
}

// ==================== Main Page ====================

export default function ReferencesPage() {
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [categoryFilter, setCategoryFilter] = useState<string>('all')
  const [showCreateDialog, setShowCreateDialog] = useState(false)
  const [editRef, setEditRef] = useState<DocReference | null>(null)
  const [deleteRef, setDeleteRef] = useState<DocReference | null>(null)
  const [searchTimer, setSearchTimer] = useState<ReturnType<typeof setTimeout>>()

  const handleSearch = (val: string) => {
    setSearch(val)
    clearTimeout(searchTimer)
    const timer = setTimeout(() => setDebouncedSearch(val), 300)
    setSearchTimer(timer)
  }

  const { data, isLoading, isError, error, refetch } = useReferences(debouncedSearch || undefined)
  const { toast } = useToast()

  const filtered = useMemo(() => {
    if (!data?.data) return []
    if (categoryFilter === 'all') return data.data
    return data.data.filter(r => r.category === categoryFilter)
  }, [data?.data, categoryFilter])

  const totalCount = data?.count || 0

  const categories = useMemo(() => {
    const cats = new Set<string>()
    data?.data?.forEach(r => { if (r.category) cats.add(r.category) })
    return Array.from(cats)
  }, [data?.data])

  return (
    <div className="page-enter">
      <Header title="إدارة المراجع والكتب" subtitle={`${formatNumber(totalCount)} مرجع`} onRefresh={() => refetch()} />

      <div className="p-6 space-y-6">
        {/* Error */}
        {isError && (
          <Card className="border-red-200 bg-red-50/50">
            <CardContent className="p-6 text-center">
              <AlertTriangle className="w-10 h-10 text-red-500 mx-auto mb-3" />
              <h3 className="font-bold text-red-700 mb-1">حدث خطأ في تحميل المراجع</h3>
              <p className="text-sm text-red-600 mb-3">{(error as Error)?.message || 'تعذر الاتصال بالخادم'}</p>
              <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-2">
                <RefreshCw className="w-4 h-4" /> إعادة المحاولة
              </Button>
            </CardContent>
          </Card>
        )}

        {/* Actions Bar */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input placeholder="بحث في المراجع..." value={search} onChange={(e) => handleSearch(e.target.value)} className="pr-10" />
            {search && (
              <Button variant="ghost" size="icon-sm" className="absolute left-2 top-1/2 -translate-y-1/2 h-6 w-6" onClick={() => { setSearch(''); setDebouncedSearch('') }}>
                <X className="w-3 h-3" />
              </Button>
            )}
          </div>

          <Select value={categoryFilter} onValueChange={setCategoryFilter}>
            <SelectTrigger className="w-44">
              <SelectValue placeholder="كل التصنيفات" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">كل التصنيفات</SelectItem>
              {Object.entries(CATEGORY_LABELS).map(([key, val]) => (
                <SelectItem key={key} value={key}>{val.ar}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Button className="gap-2" onClick={() => setShowCreateDialog(true)}>
            <Plus className="w-4 h-4" /> إضافة مرجع
          </Button>
        </div>

        {/* Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {isLoading ? (
            Array.from({ length: 6 }).map((_, i) => (
              <Card key={i}><CardContent className="p-5"><Skeleton className="w-full h-36" /></CardContent></Card>
            ))
          ) : filtered.length === 0 ? (
            <div className="col-span-full text-center py-16">
              <div className="w-20 h-20 rounded-2xl bg-muted flex items-center justify-center mx-auto mb-4">
                <BookOpen className="w-10 h-10 text-muted-foreground" />
              </div>
              <h3 className="text-lg font-heading font-bold">لا توجد مراجع</h3>
              <p className="text-sm text-muted-foreground mt-1">
                {debouncedSearch ? 'جرّب البحث بكلمات مختلفة' : 'ابدأ بإضافة مرجع جديد'}
              </p>
              {!debouncedSearch && (
                <Button className="gap-2 mt-4" onClick={() => setShowCreateDialog(true)}>
                  <Plus className="w-4 h-4" /> إضافة مرجع
                </Button>
              )}
            </div>
          ) : (
            filtered.map((ref) => (
              <ReferenceCard
                key={ref.id}
                reference={ref}
                onEdit={() => setEditRef(ref)}
                onDelete={() => setDeleteRef(ref)}
              />
            ))
          )}
        </div>
      </div>

      {/* Create Dialog */}
      <ReferenceDialog
        open={showCreateDialog}
        onOpenChange={setShowCreateDialog}
        onSuccess={() => { setShowCreateDialog(false); refetch() }}
      />

      {/* Edit Dialog */}
      {editRef && (
        <ReferenceDialog
          open={!!editRef}
          onOpenChange={(open) => { if (!open) setEditRef(null) }}
          reference={editRef}
          onSuccess={() => { setEditRef(null); refetch() }}
        />
      )}

      {/* Delete Dialog */}
      {deleteRef && (
        <DeleteRefDialog
          open={!!deleteRef}
          onOpenChange={(open) => { if (!open) setDeleteRef(null) }}
          reference={deleteRef}
          onSuccess={() => { setDeleteRef(null); refetch() }}
        />
      )}
    </div>
  )
}

// ==================== Reference Card ====================

function ReferenceCard({ reference, onEdit, onDelete }: {
  reference: DocReference
  onEdit: () => void
  onDelete: () => void
}) {
  const updateRef = useUpdateReference()
  const { toast } = useToast()
  const cat = CATEGORY_LABELS[reference.category as RefCategory] || CATEGORY_LABELS.general
  const Icon = cat.icon

  return (
    <Card className={cn(
      'group hover:shadow-lg transition-all duration-200 relative overflow-hidden',
      !reference.is_active && 'opacity-60'
    )}>
      <div className={cn('absolute top-0 left-0 right-0 h-1', reference.is_active ? 'bg-emerald-500' : 'bg-gray-400')} />

      <CardContent className="p-5 pt-6">
        {/* Header */}
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-3 min-w-0 flex-1">
            <div className={cn('p-2.5 rounded-xl shrink-0', cat.color)}>
              <Icon className="w-6 h-6" />
            </div>
            <div className="min-w-0">
              <h3 className="font-bold font-heading truncate">{reference.title_ar}</h3>
              <Badge variant="secondary" className="text-[10px] mt-1">{cat.ar}</Badge>
            </div>
          </div>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100">
                <MoreVertical className="w-4 h-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {reference.file_url && (
                <DropdownMenuItem onClick={() => window.open(reference.file_url!, '_blank')}>
                  <ExternalLink className="w-4 h-4 ml-2" />فتح الملف
                </DropdownMenuItem>
              )}
              <DropdownMenuItem onClick={onEdit}>
                <Edit className="w-4 h-4 ml-2" />تعديل
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={onDelete} className="text-destructive focus:text-destructive">
                <Trash2 className="w-4 h-4 ml-2" />حذف
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>

        {/* Description */}
        {reference.description_ar && (
          <p className="text-sm text-muted-foreground mb-3 line-clamp-2">{reference.description_ar}</p>
        )}

        {/* File Link */}
        {reference.file_url && (
          <a
            href={reference.file_url}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 text-xs text-primary hover:underline mb-3"
          >
            <Download className="w-3.5 h-3.5" />
            <span className="truncate">{reference.file_url.split('/').pop() || 'تحميل الملف'}</span>
          </a>
        )}

        {/* Footer */}
        <div className="flex items-center justify-between pt-3 border-t">
          <span className="text-xs text-muted-foreground">{formatDate(reference.created_at)}</span>
          <div className="flex items-center gap-2">
            <span className="text-xs text-muted-foreground">{reference.is_active ? 'نشط' : 'معطّل'}</span>
            <Switch
              checked={reference.is_active}
              onCheckedChange={(checked) => {
                updateRef.mutate({ id: reference.id, is_active: checked }, {
                  onSuccess: () => toast({ title: checked ? 'تم التفعيل' : 'تم التعطيل', variant: 'success' })
                })
              }}
            />
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

// ==================== Reference Dialog ====================

function ReferenceDialog({ open, onOpenChange, reference, onSuccess }: {
  open: boolean
  onOpenChange: (open: boolean) => void
  reference?: DocReference
  onSuccess: () => void
}) {
  const isEdit = !!reference
  const { toast } = useToast()
  const createRef = useCreateReference()
  const updateRef = useUpdateReference()

  const [titleAr, setTitleAr] = useState('')
  const [descriptionAr, setDescriptionAr] = useState('')
  const [fileUrl, setFileUrl] = useState('')
  const [category, setCategory] = useState<RefCategory>('general')
  const [isActive, setIsActive] = useState(true)

  // Sync state on open
  const prevIdRef = useState<string | undefined | null>(null)[0]
  const [initialized, setInitialized] = useState(false)

  if (open && !initialized) {
    setInitialized(true)
    if (reference) {
      setTitleAr(reference.title_ar)
      setDescriptionAr(reference.description_ar || '')
      setFileUrl(reference.file_url || '')
      setCategory((reference.category as RefCategory) || 'general')
      setIsActive(reference.is_active)
    } else {
      setTitleAr('')
      setDescriptionAr('')
      setFileUrl('')
      setCategory('general')
      setIsActive(true)
    }
  }
  if (!open && initialized) {
    setInitialized(false)
  }

  const handleSubmit = () => {
    if (!titleAr.trim()) {
      toast({ title: 'الرجاء إدخال العنوان', variant: 'destructive' })
      return
    }

    const payload = {
      title_ar: titleAr,
      description_ar: descriptionAr || undefined,
      file_url: fileUrl || undefined,
      category,
      is_active: isActive,
    }

    if (isEdit) {
      updateRef.mutate({ id: reference.id, ...payload }, {
        onSuccess: () => { toast({ title: 'تم تحديث المرجع', variant: 'success' }); onSuccess() },
      })
    } else {
      createRef.mutate(payload, {
        onSuccess: () => { toast({ title: 'تم إضافة المرجع', variant: 'success' }); onSuccess() },
      })
    }
  }

  const isPending = createRef.isPending || updateRef.isPending

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{isEdit ? 'تعديل المرجع' : 'إضافة مرجع جديد'}</DialogTitle>
          <DialogDescription>{isEdit ? 'قم بتعديل بيانات المرجع' : 'أدخل بيانات المرجع الجديد'}</DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          {/* Title */}
          <div>
            <Label htmlFor="ref-title">العنوان *</Label>
            <Input id="ref-title" value={titleAr} onChange={(e) => setTitleAr(e.target.value)} placeholder="مثال: دليل التطعيم الموسع 2026" />
          </div>

          {/* Description */}
          <div>
            <Label htmlFor="ref-desc">الوصف</Label>
            <Input id="ref-desc" value={descriptionAr} onChange={(e) => setDescriptionAr(e.target.value)} placeholder="وصف مختصر للمرجع..." />
          </div>

          {/* Category */}
          <div>
            <Label>التصنيف</Label>
            <Select value={category} onValueChange={(v) => setCategory(v as RefCategory)}>
              <SelectTrigger><SelectValue placeholder="اختر التصنيف" /></SelectTrigger>
              <SelectContent>
                {Object.entries(CATEGORY_LABELS).map(([key, val]) => (
                  <SelectItem key={key} value={key}>{val.ar}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* File URL */}
          <div>
            <Label htmlFor="ref-url" className="flex items-center gap-2">
              <LinkIcon className="w-3.5 h-3.5 text-muted-foreground" />
              رابط الملف
            </Label>
            <Input id="ref-url" value={fileUrl} onChange={(e) => setFileUrl(e.target.value)} placeholder="https://example.com/file.pdf" dir="ltr" />
            <p className="text-[10px] text-muted-foreground mt-1">رابط مباشر لتحميل الملف (PDF, DOCX, إلخ)</p>
          </div>

          {/* Active */}
          <div className="flex items-center justify-between">
            <Label htmlFor="ref-active" className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-muted-foreground" />
              المرجع نشط
            </Label>
            <Switch id="ref-active" checked={isActive} onCheckedChange={setIsActive} />
          </div>
        </div>

        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button onClick={handleSubmit} disabled={isPending} className="gap-2">
            {isPending && <Loader2 className="w-4 h-4 animate-spin" />}
            {isPending ? 'جاري الحفظ...' : isEdit ? 'حفظ التعديلات' : 'إضافة المرجع'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ==================== Delete Dialog ====================

function DeleteRefDialog({ open, onOpenChange, reference, onSuccess }: {
  open: boolean
  onOpenChange: (open: boolean) => void
  reference: DocReference
  onSuccess: () => void
}) {
  const deleteRef = useDeleteReference()
  const { toast } = useToast()

  const handleDelete = () => {
    deleteRef.mutate(reference.id, {
      onSuccess: () => { toast({ title: 'تم حذف المرجع', variant: 'success' }); onSuccess() },
      onError: () => { toast({ title: 'فشل حذف المرجع', variant: 'destructive' }) },
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 text-destructive">
            <AlertTriangle className="w-5 h-5" />تأكيد الحذف
          </DialogTitle>
          <DialogDescription>هل أنت متأكد من حذف هذا المرجع؟ لا يمكن التراجع عن هذا الإجراء.</DialogDescription>
        </DialogHeader>

        <div className="p-3 bg-destructive/5 border border-destructive/20 rounded-lg">
          <p className="font-medium text-sm">{reference.title_ar}</p>
          {reference.description_ar && <p className="text-xs text-muted-foreground mt-1">{reference.description_ar}</p>}
        </div>

        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={deleteRef.isPending}>إلغاء</Button>
          <Button variant="destructive" onClick={handleDelete} disabled={deleteRef.isPending} className="gap-2">
            {deleteRef.isPending && <Loader2 className="w-4 h-4 animate-spin" />}
            {deleteRef.isPending ? 'جاري الحذف...' : 'حذف المرجع'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
