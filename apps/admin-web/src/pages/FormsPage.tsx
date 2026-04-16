import { useState, useCallback, useMemo, useRef, useEffect } from 'react'
import {
  Search, Plus, MoreVertical, Edit, Eye, EyeOff,
  FileText, MapPin, Globe, Smartphone, Shield, Trash2,
  ChevronUp, ChevronDown, Copy, Calendar, Clock,
  Hash, ListChecks, Camera, QrCode, PenTool, Type, ArrowUpDown,
  Settings, LayoutGrid, Columns3, Tag, BarChart3, AlertTriangle,
  Send, X, Check, Loader2, CheckCircle2
} from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Switch } from '@/components/ui/switch'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import { ScrollArea } from '@/components/ui/scroll-area'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue
} from '@/components/ui/select'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from '@/components/ui/dropdown-menu'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Header } from '@/components/layout/header'
import { useForms, useCreateForm, useUpdateForm, useDeleteForm, useFormSubmissionCounts } from '@/hooks/useApi'
import { ROLE_LABELS, ROLE_HIERARCHY, type Form, type UserRole } from '@/types/database'
import { formatDate, formatNumber, cn } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'
import { useCampaign } from '@/lib/campaign-context'

// ==================== Field Types ====================

export type FormFieldType =
  | 'text' | 'number' | 'select' | 'multi_select'
  | 'date' | 'time' | 'gps' | 'photo' | 'signature' | 'barcode'

export interface FormFieldOption {
  value: string
  label_ar: string
  label_en: string
}

export interface FormFieldValidation {
  min?: number
  max?: number
  pattern?: string
  custom_message?: string
}

export interface FormField {
  id: string
  type: FormFieldType
  label_ar: string
  label_en: string
  required: boolean
  placeholder_ar?: string
  placeholder_en?: string
  options?: FormFieldOption[]
  validation?: FormFieldValidation
  order: number
}

export interface FormSchema {
  fields: FormField[]
  category?: string
  submission_deadline?: string
  is_recurring?: boolean
  recurring_schedule?: string
  notify_on_submit?: boolean
  notify_on_review?: boolean
  gps_accuracy?: 'low' | 'medium' | 'high'
}

export type FormCategory =
  | 'vaccination' | 'report' | 'inspection' | 'survey'
  | 'inventory' | 'training' | 'emergency' | 'other'

const FIELD_TYPE_LABELS: Record<FormFieldType, { ar: string; en: string; icon: typeof Type }> = {
  text: { ar: 'نص', en: 'Text', icon: Type },
  number: { ar: 'رقم', en: 'Number', icon: Hash },
  select: { ar: 'قائمة منسدلة', en: 'Select', icon: ListChecks },
  multi_select: { ar: 'اختيار متعدد', en: 'Multi Select', icon: Columns3 },
  date: { ar: 'تاريخ', en: 'Date', icon: Calendar },
  time: { ar: 'وقت', en: 'Time', icon: Clock },
  gps: { ar: 'موقع GPS', en: 'GPS Location', icon: MapPin },
  photo: { ar: 'صورة', en: 'Photo', icon: Camera },
  signature: { ar: 'توقيع', en: 'Signature', icon: PenTool },
  barcode: { ar: 'باركود', en: 'Barcode', icon: QrCode },
}

const CATEGORY_LABELS: Record<FormCategory, { ar: string; en: string }> = {
  vaccination: { ar: 'تطعيم', en: 'Vaccination' },
  report: { ar: 'تقرير', en: 'Report' },
  inspection: { ar: 'تفتيش', en: 'Inspection' },
  survey: { ar: 'استبيان', en: 'Survey' },
  inventory: { ar: 'جرد', en: 'Inventory' },
  training: { ar: 'تدريب', en: 'Training' },
  emergency: { ar: 'طوارئ', en: 'Emergency' },
  other: { ar: 'أخرى', en: 'Other' },
}

const GPS_ACCURACY_LABELS: Record<string, { ar: string; en: string }> = {
  low: { ar: 'منخفضة (100م)', en: 'Low (100m)' },
  medium: { ar: 'متوسطة (10م)', en: 'Medium (10m)' },
  high: { ar: 'عالية (1م)', en: 'High (1m)' },
}

const RECURRING_OPTIONS = [
  { value: 'daily', label_ar: 'يومي', label_en: 'Daily' },
  { value: 'weekly', label_ar: 'أسبوعي', label_en: 'Weekly' },
  { value: 'monthly', label_ar: 'شهري', label_en: 'Monthly' },
  { value: 'quarterly', label_ar: 'ربع سنوي', label_en: 'Quarterly' },
  { value: 'yearly', label_ar: 'سنوي', label_en: 'Yearly' },
]

function generateId(): string {
  return `f_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
}

function parseFormSchema(schema: Record<string, unknown>): FormSchema {
  if (!schema || typeof schema !== 'object') return { fields: [] }
  const s = schema as Partial<FormSchema>
  return {
    fields: Array.isArray(s.fields) ? s.fields : [],
    category: s.category,
    submission_deadline: s.submission_deadline,
    is_recurring: s.is_recurring,
    recurring_schedule: s.recurring_schedule,
    notify_on_submit: s.notify_on_submit,
    notify_on_review: s.notify_on_review,
    gps_accuracy: s.gps_accuracy,
  }
}

// ==================== Main Page ====================

export default function FormsPage() {
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [showCreateDialog, setShowCreateDialog] = useState(false)
  const [editForm, setEditForm] = useState<Form | null>(null)
  const [previewForm, setPreviewForm] = useState<Form | null>(null)
  const [deleteConfirmForm, setDeleteConfirmForm] = useState<Form | null>(null)
  const searchTimer = useRef<ReturnType<typeof setTimeout>>()
  const { campaign, labelAr, isFiltered } = useCampaign()

  useEffect(() => {
    searchTimer.current = setTimeout(() => setDebouncedSearch(search), 300)
    return () => clearTimeout(searchTimer.current)
  }, [search])

  const { data: formsResult, isLoading, refetch } = useForms({ search: debouncedSearch || undefined, campaignType: campaign })
  const { data: submissionCounts } = useFormSubmissionCounts(campaign)
  const { toast } = useToast()

  const forms = formsResult?.data
  const totalCount = formsResult?.count || 0

  return (
    <div className="page-enter">
      <Header title="إدارة النماذج" subtitle={isFiltered ? `${formatNumber(totalCount)} نموذج — ${labelAr}` : `${formatNumber(totalCount)} نموذج`} onRefresh={() => refetch()} />

      <div className="p-6 space-y-6">
        {/* Actions Bar */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              placeholder="بحث في النماذج..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pr-10"
            />
            {search && (
              <Button
                variant="ghost"
                size="icon-sm"
                className="absolute left-2 top-1/2 -translate-y-1/2 h-6 w-6"
                onClick={() => setSearch('')}
              >
                <X className="w-3 h-3" />
              </Button>
            )}
          </div>
          <Button className="gap-2" onClick={() => setShowCreateDialog(true)}>
            <Plus className="w-4 h-4" />
            نموذج جديد
          </Button>
        </div>

        {/* Forms Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {isLoading
            ? Array.from({ length: 6 }).map((_, i) => (
                <Card key={i}>
                  <CardContent className="p-5">
                    <Skeleton className="w-full h-48" />
                  </CardContent>
                </Card>
              ))
            : forms?.map((form) => (
                <FormCard
                  key={form.id}
                  form={form}
                  submissionCount={submissionCounts?.[form.id]}
                  onEdit={() => setEditForm(form)}
                  onPreview={() => setPreviewForm(form)}
                  onDelete={() => setDeleteConfirmForm(form)}
                />
              ))
          }
        </div>

        {/* Empty state */}
        {!isLoading && forms?.length === 0 && (
          <div className="text-center py-16">
            <FileText className="w-16 h-16 mx-auto text-muted-foreground/30 mb-4" />
            <h3 className="text-lg font-medium mb-1">
              {debouncedSearch ? 'لا توجد نتائج' : 'لا توجد نماذج بعد'}
            </h3>
            <p className="text-sm text-muted-foreground mb-4">
              {debouncedSearch ? 'جرّب البحث بكلمات مختلفة' : 'ابدأ بإنشاء نموذج جديد'}
            </p>
            {!debouncedSearch && (
              <Button className="gap-2" onClick={() => setShowCreateDialog(true)}>
                <Plus className="w-4 h-4" />
                إنشاء نموذج
              </Button>
            )}
          </div>
        )}
      </div>

      {/* Create Dialog */}
      <FormDialog
        key="create"
        open={showCreateDialog}
        onOpenChange={setShowCreateDialog}
        onSuccess={() => { setShowCreateDialog(false); refetch() }}
      />

      {/* Edit Dialog */}
      {editForm && (
        <FormDialog
          key={editForm.id}
          open={!!editForm}
          onOpenChange={(open) => { if (!open) setEditForm(null) }}
          form={editForm}
          onSuccess={() => { setEditForm(null); refetch() }}
        />
      )}

      {/* Preview Dialog */}
      {previewForm && (
        <FormPreviewDialog
          open={!!previewForm}
          onOpenChange={(open) => { if (!open) setPreviewForm(null) }}
          form={previewForm}
        />
      )}

      {/* Delete Confirmation Dialog */}
      {deleteConfirmForm && (
        <DeleteFormDialog
          open={!!deleteConfirmForm}
          onOpenChange={(open) => { if (!open) setDeleteConfirmForm(null) }}
          form={deleteConfirmForm}
          onSuccess={() => { setDeleteConfirmForm(null); refetch() }}
        />
      )}
    </div>
  )
}

// ==================== Form Card ====================

interface FormCardProps {
  form: Form
  submissionCount?: { total: number; approved: number; pending: number; rejected: number }
  onEdit: () => void
  onPreview: () => void
  onDelete: () => void
}

function FormCard({ form, submissionCount, onEdit, onPreview, onDelete }: FormCardProps) {
  const updateForm = useUpdateForm()
  const { toast } = useToast()
  const schema = parseFormSchema(form.schema)
  const fieldCount = schema.fields?.length || 0
  const category = schema.category ? CATEGORY_LABELS[schema.category as FormCategory] : null

  return (
    <Card className={cn(
      'group hover:shadow-card-hover transition-all duration-200 relative overflow-hidden',
      !form.is_active && 'opacity-60'
    )}>
      {/* Status indicator */}
      <div className={cn(
        'absolute top-0 left-0 right-0 h-1',
        form.is_active ? 'bg-emerald-500' : 'bg-gray-400'
      )} />

      <CardContent className="p-5 pt-6">
        {/* Header */}
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-primary/10">
              <FileText className="w-6 h-6 text-primary" />
            </div>
            <div className="min-w-0">
              <h3 className="font-bold font-heading truncate">{form.title_ar}</h3>
              <p className="text-xs text-muted-foreground truncate">{form.title_en}</p>
            </div>
          </div>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100">
                <MoreVertical className="w-4 h-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={onPreview}>
                <Eye className="w-4 h-4 ml-2" />معاينة
              </DropdownMenuItem>
              <DropdownMenuItem onClick={onEdit}>
                <Edit className="w-4 h-4 ml-2" />تعديل
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => {
                updateForm.mutate({ id: form.id, is_active: !form.is_active }, {
                  onSuccess: () => toast({ title: form.is_active ? 'تم إخفاء النموذج' : 'تم إظهار النموذج', variant: 'success' })
                })
              }}>
                {form.is_active ? <EyeOff className="w-4 h-4 ml-2" /> : <Eye className="w-4 h-4 ml-2" />}
                {form.is_active ? 'إخفاء النموذج' : 'إظهار النموذج'}
              </DropdownMenuItem>
              <DropdownMenuItem onClick={onDelete} className="text-destructive focus:text-destructive">
                <Trash2 className="w-4 h-4 ml-2" />حذف
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>

        {/* Description */}
        {form.description_ar && (
          <p className="text-sm text-muted-foreground mb-3 line-clamp-2">{form.description_ar}</p>
        )}

        {/* Meta Info Row */}
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground mb-3">
          {category && (
            <span className="flex items-center gap-1">
              <Tag className="w-3 h-3" />
              {category.ar}
            </span>
          )}
          <span className="flex items-center gap-1">
            <LayoutGrid className="w-3 h-3" />
            {fieldCount} حقل
          </span>
          <span className="flex items-center gap-1">
            <BarChart3 className="w-3 h-3" />
            الإصدار {form.version}
          </span>
          {submissionCount && submissionCount.total > 0 && (
            <span className="flex items-center gap-1">
              <Send className="w-3 h-3" />
              {formatNumber(submissionCount.total)} تقديم
            </span>
          )}
        </div>

        {/* Tags */}
        <div className="flex flex-wrap gap-1.5 mb-3">
          {form.requires_gps && (
            <Badge variant="outline" className="text-[10px] gap-1">
              <MapPin className="w-3 h-3" /> GPS
            </Badge>
          )}
          {form.requires_photo && (
            <Badge variant="outline" className="text-[10px] gap-1">
              <Camera className="w-3 h-3" />
              صور {form.max_photos > 0 ? `(≤${form.max_photos})` : ''}
            </Badge>
          )}
          {schema.is_recurring && (
            <Badge variant="outline" className="text-[10px] gap-1">
              <Calendar className="w-3 h-3" />
              {RECURRING_OPTIONS.find(r => r.value === schema.recurring_schedule)?.label_ar || 'متكرر'}
            </Badge>
          )}
          {schema.submission_deadline && (
            <Badge variant="outline" className="text-[10px] gap-1 text-amber-600 border-amber-300">
              <AlertTriangle className="w-3 h-3" />
              انتهاء الموعد
            </Badge>
          )}
          {form.campaign_type && (
            <Badge variant="outline" className={cn(
              'text-[10px] gap-1',
              form.campaign_type === 'polio_campaign'
                ? 'text-blue-600 border-blue-300 bg-blue-50'
                : 'text-emerald-600 border-emerald-300 bg-emerald-50'
            )}>
              {form.campaign_type === 'polio_campaign' ? '💉 شلل أطفال' : '🏥 إيصالي'}
            </Badge>
          )}
        </div>

        {/* Field Types Preview */}
        {fieldCount > 0 && (
          <div className="flex flex-wrap gap-1 mb-3">
            {[...new Set(schema.fields.map(f => f.type))].map((type) => {
              const ft = FIELD_TYPE_LABELS[type as FormFieldType]
              if (!ft) return null
              const Icon = ft.icon
              return (
                <Badge key={type} variant="secondary" className="text-[10px] gap-1">
                  <Icon className="w-3 h-3" />
                  {ft.ar}
                </Badge>
              )
            })}
          </div>
        )}

        {/* Allowed Roles */}
        <div className="mb-3">
          <p className="text-xs text-muted-foreground mb-1.5 flex items-center gap-1">
            <Shield className="w-3 h-3" /> الصلاحيات المسموحة
          </p>
          <div className="flex flex-wrap gap-1">
            {form.allowed_roles.map((role) => (
              <Badge key={role} variant="secondary" className="text-[10px]">
                {ROLE_LABELS[role]}
              </Badge>
            ))}
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between pt-3 border-t">
          <span className="text-xs text-muted-foreground">{formatDate(form.created_at)}</span>
          <div className="flex items-center gap-2">
            <span className="text-xs text-muted-foreground">{form.is_active ? 'نشط' : 'معطّل'}</span>
            <Switch
              checked={form.is_active}
              onCheckedChange={(checked) => {
                updateForm.mutate({ id: form.id, is_active: checked }, {
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

// ==================== Form Dialog (Create / Edit) ====================

interface FormDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  form?: Form
  onSuccess: () => void
}

function FormDialog({ open, onOpenChange, form, onSuccess }: FormDialogProps) {
  const isEdit = !!form
  const { toast } = useToast()
  const createForm = useCreateForm()
  const updateForm = useUpdateForm()

  // Parse schema once
  const initialSchema = form ? parseFormSchema(form.schema) : { fields: [] }

  // Basic info — initialized from form prop (key= forces remount)
  const [titleAr, setTitleAr] = useState(form?.title_ar || '')
  const [titleEn, setTitleEn] = useState(form?.title_en || '')
  const [descriptionAr, setDescriptionAr] = useState(form?.description_ar || '')
  const [descriptionEn, setDescriptionEn] = useState(form?.description_en || '')
  const [category, setCategory] = useState<FormCategory>((initialSchema.category as FormCategory) || 'other')
  const [isActive, setIsActive] = useState(form?.is_active ?? true)

  // GPS & Photo
  const [requiresGps, setRequiresGps] = useState(form?.requires_gps || false)
  const [gpsAccuracy, setGpsAccuracy] = useState<string>(initialSchema.gps_accuracy || 'medium')
  const [requiresPhoto, setRequiresPhoto] = useState(form?.requires_photo || false)
  const [maxPhotos, setMaxPhotos] = useState(form?.max_photos || 5)

  // Roles
  const [allowedRoles, setAllowedRoles] = useState<UserRole[]>(form?.allowed_roles || ['data_entry'])

  // Schema fields
  const [fields, setFields] = useState<FormField[]>(initialSchema.fields || [])

  // Settings
  const [submissionDeadline, setSubmissionDeadline] = useState(initialSchema.submission_deadline || '')
  const [isRecurring, setIsRecurring] = useState(initialSchema.is_recurring || false)
  const [recurringSchedule, setRecurringSchedule] = useState(initialSchema.recurring_schedule || 'monthly')
  const [notifyOnSubmit, setNotifyOnSubmit] = useState(initialSchema.notify_on_submit !== false)
  const [notifyOnReview, setNotifyOnReview] = useState(initialSchema.notify_on_review !== false)

  // Active tab
  const [activeTab, setActiveTab] = useState('basic')

  // Campaign type
  const [campaignType, setCampaignType] = useState(form?.campaign_type || 'polio_campaign')

  // Field being edited inline
  const [editingFieldId, setEditingFieldId] = useState<string | null>(null)

  const allRoles: UserRole[] = ['admin', 'central', 'governorate', 'district', 'data_entry']

  const toggleRole = (role: UserRole) => {
    setAllowedRoles((prev) =>
      prev.includes(role) ? prev.filter((r) => r !== role) : [...prev, role]
    )
  }

  // Field management
  const addField = (type: FormFieldType) => {
    const newField: FormField = {
      id: generateId(),
      type,
      label_ar: FIELD_TYPE_LABELS[type].ar,
      label_en: FIELD_TYPE_LABELS[type].en,
      required: false,
      order: fields.length,
      options: (type === 'select' || type === 'multi_select')
        ? [{ value: 'option_1', label_ar: 'خيار 1', label_en: 'Option 1' }]
        : undefined,
    }
    setFields(prev => [...prev, newField])
    setEditingFieldId(newField.id)
  }

  const updateField = (id: string, updates: Partial<FormField>) => {
    setFields(prev => prev.map(f => f.id === id ? { ...f, ...updates } : f))
  }

  const removeField = (id: string) => {
    setFields(prev => {
      const filtered = prev.filter(f => f.id !== id)
      return filtered.map((f, i) => ({ ...f, order: i }))
    })
    if (editingFieldId === id) setEditingFieldId(null)
  }

  const moveField = (id: string, direction: 'up' | 'down') => {
    setFields(prev => {
      const idx = prev.findIndex(f => f.id === id)
      if (idx === -1) return prev
      const targetIdx = direction === 'up' ? idx - 1 : idx + 1
      if (targetIdx < 0 || targetIdx >= prev.length) return prev
      const next = [...prev]
      const [item] = next.splice(idx, 1)
      next.splice(targetIdx, 0, item)
      return next.map((f, i) => ({ ...f, order: i }))
    })
  }

  const duplicateField = (id: string) => {
    setFields(prev => {
      const src = prev.find(f => f.id === id)
      if (!src) return prev
      const idx = prev.findIndex(f => f.id === id)
      const dup: FormField = {
        ...src,
        id: generateId(),
        label_ar: `${src.label_ar} (نسخة)`,
        label_en: `${src.label_en} (Copy)`,
        order: idx + 1,
        options: src.options ? [...src.options] : undefined,
      }
      const next = [...prev]
      next.splice(idx + 1, 0, dup)
      return next.map((f, i) => ({ ...f, order: i }))
    })
  }

  const addFieldOption = (fieldId: string) => {
    setFields(prev => prev.map(f => {
      if (f.id !== fieldId) return f
      const opts = f.options || []
      const num = opts.length + 1
      return {
        ...f,
        options: [...opts, { value: `option_${num}`, label_ar: `خيار ${num}`, label_en: `Option ${num}` }]
      }
    }))
  }

  const updateFieldOption = (fieldId: string, optIdx: number, updates: Partial<FormFieldOption>) => {
    setFields(prev => prev.map(f => {
      if (f.id !== fieldId || !f.options) return f
      const opts = [...f.options]
      opts[optIdx] = { ...opts[optIdx], ...updates }
      return { ...f, options: opts }
    }))
  }

  const removeFieldOption = (fieldId: string, optIdx: number) => {
    setFields(prev => prev.map(f => {
      if (f.id !== fieldId || !f.options) return f
      return { ...f, options: f.options.filter((_, i) => i !== optIdx) }
    }))
  }

  const handleSubmit = () => {
    if (!titleAr.trim() || !titleEn.trim()) {
      toast({ title: 'الرجاء إدخال العنوان بالعربية والإنجليزية', variant: 'destructive' })
      setActiveTab('basic')
      return
    }

    const schema: FormSchema = {
      fields,
      category,
      submission_deadline: submissionDeadline || undefined,
      is_recurring: isRecurring,
      recurring_schedule: isRecurring ? recurringSchedule : undefined,
      notify_on_submit: notifyOnSubmit,
      notify_on_review: notifyOnReview,
      gps_accuracy: requiresGps ? (gpsAccuracy as 'low' | 'medium' | 'high') : undefined,
    }

    const payload = {
      title_ar: titleAr,
      title_en: titleEn,
      description_ar: descriptionAr || undefined,
      description_en: descriptionEn || undefined,
      schema: schema as unknown as Record<string, unknown>,
      requires_gps: requiresGps,
      requires_photo: requiresPhoto,
      max_photos: requiresPhoto ? maxPhotos : 0,
      allowed_roles: allowedRoles,
      is_active: isActive,
      campaign_type: campaignType,
    }

    if (isEdit) {
      updateForm.mutate({ id: form.id, ...payload }, {
        onSuccess: () => {
          toast({ title: 'تم تحديث النموذج', variant: 'success' })
          onSuccess()
        },
      })
    } else {
      createForm.mutate(payload, {
        onSuccess: () => {
          toast({ title: 'تم إنشاء النموذج', variant: 'success' })
          onSuccess()
        },
      })
    }
  }

  const isPending = createForm.isPending || updateForm.isPending

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-3xl max-h-[90vh] flex flex-col p-0">
        <DialogHeader className="px-6 pt-6 pb-0">
          <DialogTitle>{isEdit ? 'تعديل النموذج' : 'نموذج جديد'}</DialogTitle>
          <DialogDescription>
            {isEdit ? 'قم بتعديل بيانات النموذج وحقوله' : 'أدخل بيانات النموذج الجديد وأضف حقوله'}
          </DialogDescription>
        </DialogHeader>

        <Tabs value={activeTab} onValueChange={setActiveTab} className="flex-1 flex flex-col min-h-0 px-6">
          <TabsList className="w-full justify-start gap-1 mb-2 bg-transparent p-0 h-auto flex-wrap">
            <TabsTrigger value="basic" className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground rounded-md px-3 py-1.5">
              <Globe className="w-4 h-4 ml-1" />基本信息
            </TabsTrigger>
            <TabsTrigger value="fields" className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground rounded-md px-3 py-1.5">
              <LayoutGrid className="w-4 h-4 ml-1" />الحقول ({fields.length})
            </TabsTrigger>
            <TabsTrigger value="roles" className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground rounded-md px-3 py-1.5">
              <Shield className="w-4 h-4 ml-1" />الصلاحيات
            </TabsTrigger>
            <TabsTrigger value="settings" className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground rounded-md px-3 py-1.5">
              <Settings className="w-4 h-4 ml-1" />الإعدادات
            </TabsTrigger>
          </TabsList>

          <ScrollArea className="flex-1 max-h-[55vh]">
            {/* ===== BASIC TAB ===== */}
            <TabsContent value="basic" className="mt-0 space-y-4 pr-2">
              {/* Title Arabic */}
              <div>
                <Label htmlFor="title_ar">العنوان بالعربية *</Label>
                <Input
                  id="title_ar"
                  value={titleAr}
                  onChange={(e) => setTitleAr(e.target.value)}
                  placeholder="مثال: تقرير التطعيم الشهري"
                />
              </div>

              {/* Title English */}
              <div>
                <Label htmlFor="title_en">العنوان بالإنجليزية *</Label>
                <Input
                  id="title_en"
                  value={titleEn}
                  onChange={(e) => setTitleEn(e.target.value)}
                  placeholder="e.g. Monthly Vaccination Report"
                  dir="ltr"
                />
              </div>

              {/* Description Arabic */}
              <div>
                <Label htmlFor="desc_ar">الوصف بالعربية</Label>
                <Input
                  id="desc_ar"
                  value={descriptionAr}
                  onChange={(e) => setDescriptionAr(e.target.value)}
                  placeholder="وصف النموذج..."
                />
              </div>

              {/* Description English */}
              <div>
                <Label htmlFor="desc_en">الوصف بالإنجليزية</Label>
                <Input
                  id="desc_en"
                  value={descriptionEn}
                  onChange={(e) => setDescriptionEn(e.target.value)}
                  placeholder="Form description..."
                  dir="ltr"
                />
              </div>

              {/* Category */}
              <div>
                <Label>التصنيف</Label>
                <Select value={category} onValueChange={(v) => setCategory(v as FormCategory)}>
                  <SelectTrigger>
                    <SelectValue placeholder="اختر التصنيف" />
                  </SelectTrigger>
                  <SelectContent>
                    {Object.entries(CATEGORY_LABELS).map(([key, val]) => (
                      <SelectItem key={key} value={key}>{val.ar}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {/* Campaign Type */}
              <div>
                <Label>النشاط / الحملة</Label>
                <Select value={campaignType} onValueChange={setCampaignType}>
                  <SelectTrigger>
                    <SelectValue placeholder="اختر النشاط" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="polio_campaign">💉 حملة شلل الأطفال</SelectItem>
                    <SelectItem value="integrated_activity">🏥 النشاط الإيصالي التكاملي</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <Separator />

              {/* GPS */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label htmlFor="gps" className="flex items-center gap-2">
                    <MapPin className="w-4 h-4 text-muted-foreground" />
                    يتطلب GPS
                  </Label>
                  <Switch id="gps" checked={requiresGps} onCheckedChange={setRequiresGps} />
                </div>
                {requiresGps && (
                  <div className="mr-6">
                    <Label className="text-xs text-muted-foreground">مستوى الدقة</Label>
                    <Select value={gpsAccuracy} onValueChange={setGpsAccuracy}>
                      <SelectTrigger className="mt-1">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {Object.entries(GPS_ACCURACY_LABELS).map(([key, val]) => (
                          <SelectItem key={key} value={key}>{val.ar}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                )}
              </div>

              {/* Photo */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label htmlFor="photo" className="flex items-center gap-2">
                    <Camera className="w-4 h-4 text-muted-foreground" />
                    يتطلب صور
                  </Label>
                  <Switch id="photo" checked={requiresPhoto} onCheckedChange={setRequiresPhoto} />
                </div>
                {requiresPhoto && (
                  <div className="mr-6 flex items-center gap-3">
                    <Label className="text-xs text-muted-foreground whitespace-nowrap">الحد الأقصى للصور</Label>
                    <Input
                      type="number"
                      min={1}
                      max={20}
                      value={maxPhotos}
                      onChange={(e) => setMaxPhotos(parseInt(e.target.value) || 1)}
                      className="w-20"
                    />
                  </div>
                )}
              </div>

              <Separator />

              {/* Active Toggle */}
              <div className="flex items-center justify-between">
                <Label htmlFor="active" className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 text-muted-foreground" />
                  النموذج نشط
                </Label>
                <Switch id="active" checked={isActive} onCheckedChange={setIsActive} />
              </div>
            </TabsContent>

            {/* ===== FIELDS TAB ===== */}
            <TabsContent value="fields" className="mt-0 space-y-4 pr-2">
              {/* Add Field Buttons */}
              <div>
                <Label className="text-sm font-medium mb-2 block">إضافة حقل جديد</Label>
                <div className="flex flex-wrap gap-2">
                  {(Object.entries(FIELD_TYPE_LABELS) as [FormFieldType, typeof FIELD_TYPE_LABELS['text']][]).map(
                    ([type, info]) => {
                      const Icon = info.icon
                      return (
                        <Button
                          key={type}
                          variant="outline"
                          size="sm"
                          className="gap-1.5 text-xs"
                          onClick={() => addField(type)}
                        >
                          <Icon className="w-3.5 h-3.5" />
                          {info.ar}
                        </Button>
                      )
                    }
                  )}
                </div>
              </div>

              <Separator />

              {/* Fields List */}
              {fields.length === 0 ? (
                <div className="text-center py-12 text-muted-foreground">
                  <LayoutGrid className="w-12 h-12 mx-auto mb-3 opacity-30" />
                  <p className="text-sm">لا توجد حقول بعد</p>
                  <p className="text-xs mt-1">اضغط على أحد الأزرار أعلاه لإضافة حقل</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {fields.map((field, idx) => {
                    const ft = FIELD_TYPE_LABELS[field.type]
                    const Icon = ft.icon
                    const isEditing = editingFieldId === field.id

                    return (
                      <Card key={field.id} className={cn(
                        'transition-all',
                        isEditing ? 'ring-2 ring-primary' : ''
                      )}>
                        <CardContent className="p-4">
                          {/* Field Header */}
                          <div className="flex items-center gap-2 mb-2">
                            <div className="flex flex-col gap-0.5">
                              <Button
                                variant="ghost"
                                size="icon-sm"
                                className="h-5 w-5"
                                onClick={() => moveField(field.id, 'up')}
                                disabled={idx === 0}
                              >
                                <ChevronUp className="w-3 h-3" />
                              </Button>
                              <Button
                                variant="ghost"
                                size="icon-sm"
                                className="h-5 w-5"
                                onClick={() => moveField(field.id, 'down')}
                                disabled={idx === fields.length - 1}
                              >
                                <ChevronDown className="w-3 h-3" />
                              </Button>
                            </div>
                            <Badge variant="secondary" className="gap-1 text-[10px] shrink-0">
                              <Icon className="w-3 h-3" />
                              {ft.ar}
                            </Badge>
                            <span className="text-sm font-medium truncate flex-1">
                              {field.label_ar}
                            </span>
                            {field.required && (
                              <Badge variant="destructive" className="text-[10px]">مطلوب</Badge>
                            )}
                            <div className="flex items-center gap-1 shrink-0">
                              <Button
                                variant="ghost"
                                size="icon-sm"
                                onClick={() => setEditingFieldId(isEditing ? null : field.id)}
                                title="تعديل"
                              >
                                <Edit className="w-3.5 h-3.5" />
                              </Button>
                              <Button
                                variant="ghost"
                                size="icon-sm"
                                onClick={() => duplicateField(field.id)}
                                title="نسخ"
                              >
                                <Copy className="w-3.5 h-3.5" />
                              </Button>
                              <Button
                                variant="ghost"
                                size="icon-sm"
                                onClick={() => removeField(field.id)}
                                className="text-destructive hover:text-destructive"
                                title="حذف"
                              >
                                <Trash2 className="w-3.5 h-3.5" />
                              </Button>
                            </div>
                          </div>

                          {/* Expanded Edit Area */}
                          {isEditing && (
                            <div className="space-y-3 pt-3 border-t">
                              <div className="grid grid-cols-2 gap-3">
                                <div>
                                  <Label className="text-xs">التسمية (عربي)</Label>
                                  <Input
                                    value={field.label_ar}
                                    onChange={(e) => updateField(field.id, { label_ar: e.target.value })}
                                    className="mt-1 h-8 text-sm"
                                  />
                                </div>
                                <div>
                                  <Label className="text-xs">Label (English)</Label>
                                  <Input
                                    value={field.label_en}
                                    onChange={(e) => updateField(field.id, { label_en: e.target.value })}
                                    className="mt-1 h-8 text-sm"
                                    dir="ltr"
                                  />
                                </div>
                              </div>

                              <div className="grid grid-cols-2 gap-3">
                                <div>
                                  <Label className="text-xs">Placeholder (عربي)</Label>
                                  <Input
                                    value={field.placeholder_ar || ''}
                                    onChange={(e) => updateField(field.id, { placeholder_ar: e.target.value })}
                                    className="mt-1 h-8 text-sm"
                                    placeholder="نص توضيحي..."
                                  />
                                </div>
                                <div>
                                  <Label className="text-xs">Placeholder (EN)</Label>
                                  <Input
                                    value={field.placeholder_en || ''}
                                    onChange={(e) => updateField(field.id, { placeholder_en: e.target.value })}
                                    className="mt-1 h-8 text-sm"
                                    placeholder="Helper text..."
                                    dir="ltr"
                                  />
                                </div>
                              </div>

                              <div className="flex items-center justify-between">
                                <Label className="text-xs">حقل مطلوب</Label>
                                <Switch
                                  checked={field.required}
                                  onCheckedChange={(checked) => updateField(field.id, { required: checked })}
                                />
                              </div>

                              {/* Validation for number type */}
                              {field.type === 'number' && (
                                <div className="grid grid-cols-2 gap-3">
                                  <div>
                                    <Label className="text-xs">الحد الأدنى</Label>
                                    <Input
                                      type="number"
                                      value={field.validation?.min ?? ''}
                                      onChange={(e) => updateField(field.id, {
                                        validation: { ...field.validation, min: e.target.value ? Number(e.target.value) : undefined }
                                      })}
                                      className="mt-1 h-8 text-sm"
                                    />
                                  </div>
                                  <div>
                                    <Label className="text-xs">الحد الأقصى</Label>
                                    <Input
                                      type="number"
                                      value={field.validation?.max ?? ''}
                                      onChange={(e) => updateField(field.id, {
                                        validation: { ...field.validation, max: e.target.value ? Number(e.target.value) : undefined }
                                      })}
                                      className="mt-1 h-8 text-sm"
                                    />
                                  </div>
                                </div>
                              )}

                              {/* Validation for text type */}
                              {field.type === 'text' && (
                                <div className="grid grid-cols-2 gap-3">
                                  <div>
                                    <Label className="text-xs">الحد الأدنى للحروف</Label>
                                    <Input
                                      type="number"
                                      value={field.validation?.min ?? ''}
                                      onChange={(e) => updateField(field.id, {
                                        validation: { ...field.validation, min: e.target.value ? Number(e.target.value) : undefined }
                                      })}
                                      className="mt-1 h-8 text-sm"
                                    />
                                  </div>
                                  <div>
                                    <Label className="text-xs">الحد الأقصى للحروف</Label>
                                    <Input
                                      type="number"
                                      value={field.validation?.max ?? ''}
                                      onChange={(e) => updateField(field.id, {
                                        validation: { ...field.validation, max: e.target.value ? Number(e.target.value) : undefined }
                                      })}
                                      className="mt-1 h-8 text-sm"
                                    />
                                  </div>
                                </div>
                              )}

                              {/* Options for select/multi_select */}
                              {(field.type === 'select' || field.type === 'multi_select') && (
                                <div className="space-y-2">
                                  <Label className="text-xs">الخيارات</Label>
                                  {field.options?.map((opt, optIdx) => (
                                    <div key={optIdx} className="flex items-center gap-2">
                                      <Input
                                        value={opt.label_ar}
                                        onChange={(e) => updateFieldOption(field.id, optIdx, { label_ar: e.target.value })}
                                        className="h-7 text-xs flex-1"
                                        placeholder="عربي"
                                      />
                                      <Input
                                        value={opt.label_en}
                                        onChange={(e) => updateFieldOption(field.id, optIdx, { label_en: e.target.value, value: e.target.value.toLowerCase().replace(/\s+/g, '_') })}
                                        className="h-7 text-xs flex-1"
                                        placeholder="English"
                                        dir="ltr"
                                      />
                                      <Button
                                        variant="ghost"
                                        size="icon-sm"
                                        className="h-7 w-7 text-destructive shrink-0"
                                        onClick={() => removeFieldOption(field.id, optIdx)}
                                        disabled={(field.options?.length || 0) <= 1}
                                      >
                                        <X className="w-3 h-3" />
                                      </Button>
                                    </div>
                                  ))}
                                  <Button
                                    variant="outline"
                                    size="sm"
                                    className="gap-1 text-xs h-7"
                                    onClick={() => addFieldOption(field.id)}
                                  >
                                    <Plus className="w-3 h-3" /> إضافة خيار
                                  </Button>
                                </div>
                              )}
                            </div>
                          )}
                        </CardContent>
                      </Card>
                    )
                  })}
                </div>
              )}
            </TabsContent>

            {/* ===== ROLES TAB ===== */}
            <TabsContent value="roles" className="mt-0 space-y-4 pr-2">
              <div>
                <Label className="text-sm font-medium mb-3 block">الأدوار المسموحة بتعبئة النموذج</Label>
                <div className="space-y-2">
                  {allRoles.map((role) => {
                    const isSelected = allowedRoles.includes(role)
                    return (
                      <div
                        key={role}
                        className={cn(
                          'flex items-center justify-between p-3 rounded-lg border cursor-pointer transition-all',
                          isSelected ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/30'
                        )}
                        onClick={() => toggleRole(role)}
                      >
                        <div className="flex items-center gap-3">
                          <div className={cn(
                            'w-5 h-5 rounded border-2 flex items-center justify-center transition-colors',
                            isSelected ? 'border-primary bg-primary' : 'border-muted-foreground/30'
                          )}>
                            {isSelected && <Check className="w-3 h-3 text-primary-foreground" />}
                          </div>
                          <div>
                            <span className="text-sm font-medium">{ROLE_LABELS[role]}</span>
                            <span className="text-xs text-muted-foreground mr-2">
                              (مستوى {ROLE_HIERARCHY[role]})
                            </span>
                          </div>
                        </div>
                        <Badge
                          variant="outline"
                          className={cn('text-[10px]', isSelected && 'border-primary text-primary')}
                        >
                          {role}
                        </Badge>
                      </div>
                    )
                  })}
                </div>
              </div>

              <Separator />

              {/* Selected Summary */}
              <div>
                <Label className="text-xs text-muted-foreground mb-2 block">الأدوار المختارة</Label>
                <div className="flex flex-wrap gap-2">
                  {allowedRoles.length === 0 ? (
                    <span className="text-xs text-muted-foreground">لم يتم اختيار أي دور</span>
                  ) : (
                    allowedRoles.map((role) => (
                      <Badge key={role} variant="default" className="gap-1 cursor-pointer" onClick={() => toggleRole(role)}>
                        {ROLE_LABELS[role]}
                        <X className="w-3 h-3" />
                      </Badge>
                    ))
                  )}
                </div>
              </div>
            </TabsContent>

            {/* ===== SETTINGS TAB ===== */}
            <TabsContent value="settings" className="mt-0 space-y-4 pr-2">
              {/* Submission Deadline */}
              <div>
                <Label htmlFor="deadline" className="flex items-center gap-2">
                  <Calendar className="w-4 h-4 text-muted-foreground" />
                  موعد انتهاء التقديم
                </Label>
                <Input
                  id="deadline"
                  type="datetime-local"
                  value={submissionDeadline}
                  onChange={(e) => setSubmissionDeadline(e.target.value)}
                  className="mt-1"
                />
                <p className="text-[10px] text-muted-foreground mt-1">اتركه فارغاً إذا لم يكن هناك موعد نهائي</p>
              </div>

              <Separator />

              {/* Recurring */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label htmlFor="recurring" className="flex items-center gap-2">
                    <ArrowUpDown className="w-4 h-4 text-muted-foreground" />
                    نموذج متكرر
                  </Label>
                  <Switch id="recurring" checked={isRecurring} onCheckedChange={setIsRecurring} />
                </div>
                {isRecurring && (
                  <div>
                    <Label className="text-xs text-muted-foreground">فترة التكرار</Label>
                    <Select value={recurringSchedule} onValueChange={setRecurringSchedule}>
                      <SelectTrigger className="mt-1">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {RECURRING_OPTIONS.map((opt) => (
                          <SelectItem key={opt.value} value={opt.value}>
                            {opt.label_ar}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                )}
              </div>

              <Separator />

              {/* Notifications */}
              <div className="space-y-3">
                <Label className="text-sm font-medium flex items-center gap-2">
                  <Send className="w-4 h-4 text-muted-foreground" />
                  إعدادات الإشعارات
                </Label>
                <div className="space-y-2 mr-6">
                  <div className="flex items-center justify-between">
                    <Label htmlFor="notif_submit" className="text-xs text-muted-foreground">
                      إشعار عند التقديم
                    </Label>
                    <Switch
                      id="notif_submit"
                      checked={notifyOnSubmit}
                      onCheckedChange={setNotifyOnSubmit}
                    />
                  </div>
                  <div className="flex items-center justify-between">
                    <Label htmlFor="notif_review" className="text-xs text-muted-foreground">
                      إشعار عند المراجعة
                    </Label>
                    <Switch
                      id="notif_review"
                      checked={notifyOnReview}
                      onCheckedChange={setNotifyOnReview}
                    />
                  </div>
                </div>
              </div>

              <Separator />

              {/* Version Info (edit only) */}
              {isEdit && (
                <div className="p-3 bg-muted/50 rounded-lg">
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div>
                      <span className="text-muted-foreground">الإصدار الحالي:</span>
                      <span className="font-medium mr-1">v{form.version}</span>
                    </div>
                    <div>
                      <span className="text-muted-foreground">آخر تحديث:</span>
                      <span className="font-medium mr-1">{formatDate(form.updated_at)}</span>
                    </div>
                    <div>
                      <span className="text-muted-foreground">تاريخ الإنشاء:</span>
                      <span className="font-medium mr-1">{formatDate(form.created_at)}</span>
                    </div>
                    <div>
                      <span className="text-muted-foreground">معرف النموذج:</span>
                      <span className="font-mono text-[10px] mr-1">{form.id.slice(0, 8)}…</span>
                    </div>
                  </div>
                </div>
              )}
            </TabsContent>
          </ScrollArea>
        </Tabs>

        <DialogFooter className="px-6 pb-6 pt-2 border-t flex-row gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)} className="flex-1">
            إلغاء
          </Button>
          <Button onClick={handleSubmit} disabled={isPending} className="flex-1 gap-2">
            {isPending && <Loader2 className="w-4 h-4 animate-spin" />}
            {isPending ? 'جاري الحفظ...' : isEdit ? 'حفظ التعديلات' : 'إنشاء النموذج'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ==================== Form Preview Dialog ====================

interface FormPreviewDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  form: Form
}

function FormPreviewDialog({ open, onOpenChange, form }: FormPreviewDialogProps) {
  const schema = parseFormSchema(form.schema)
  const [values, setValues] = useState<Record<string, unknown>>({})

  const setValue = (fieldId: string, value: unknown) => {
    setValues(prev => ({ ...prev, [fieldId]: value }))
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md max-h-[90vh] flex flex-col p-0">
        <DialogHeader className="px-6 pt-6 pb-4 border-b">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
              <Smartphone className="w-5 h-5 text-primary" />
            </div>
            <div>
              <DialogTitle>معاينة النموذج</DialogTitle>
              <DialogDescription>كما سيظهر على الهاتف المحمول</DialogDescription>
            </div>
          </div>
        </DialogHeader>

        {/* Mobile Preview Frame */}
        <div className="flex-1 overflow-y-auto px-6 pb-6">
          <div className="bg-background border rounded-2xl overflow-hidden shadow-lg">
            {/* Mobile Header */}
            <div className="bg-primary text-primary-foreground p-4 text-center">
              <h3 className="font-bold text-lg">{form.title_ar}</h3>
              <p className="text-xs opacity-80 mt-0.5">{form.title_en}</p>
            </div>

            <div className="p-4 space-y-4">
              {/* Form Meta Badges */}
              <div className="flex flex-wrap gap-1.5">
                {form.requires_gps && (
                  <Badge variant="outline" className="text-[10px] gap-1">
                    <MapPin className="w-3 h-3" /> سيتم تحديد الموقع
                  </Badge>
                )}
                {form.requires_photo && (
                  <Badge variant="outline" className="text-[10px] gap-1">
                    <Camera className="w-3 h-3" />
                    مرفق صور {form.max_photos > 0 && `(حتى ${form.max_photos})`}
                  </Badge>
                )}
              </div>

              {/* Description */}
              {form.description_ar && (
                <p className="text-xs text-muted-foreground">{form.description_ar}</p>
              )}

              <Separator />

              {/* Fields Preview */}
              {schema.fields.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  <FileText className="w-8 h-8 mx-auto mb-2 opacity-30" />
                  <p className="text-xs">لا توجد حقول في هذا النموذج</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {schema.fields.map((field) => {
                    const value = values[field.id]

                    return (
                      <div key={field.id} className="space-y-1.5">
                        <Label className="text-sm flex items-center gap-1">
                          {field.label_ar}
                          {field.required && <span className="text-destructive text-xs">*</span>}
                        </Label>

                        {/* Text Input */}
                        {field.type === 'text' && (
                          <Input
                            placeholder={field.placeholder_ar || 'أدخل النص...'}
                            value={(value as string) || ''}
                            onChange={(e) => setValue(field.id, e.target.value)}
                            className="h-9 text-sm"
                          />
                        )}

                        {/* Number Input */}
                        {field.type === 'number' && (
                          <Input
                            type="number"
                            placeholder={field.placeholder_ar || 'أدخل الرقم...'}
                            value={(value as string) || ''}
                            onChange={(e) => setValue(field.id, e.target.value)}
                            className="h-9 text-sm"
                            min={field.validation?.min}
                            max={field.validation?.max}
                          />
                        )}

                        {/* Select */}
                        {field.type === 'select' && (
                          <Select
                            value={(value as string) || ''}
                            onValueChange={(v) => setValue(field.id, v)}
                          >
                            <SelectTrigger className="h-9 text-sm">
                              <SelectValue placeholder="اختر..." />
                            </SelectTrigger>
                            <SelectContent>
                              {field.options?.map((opt, i) => (
                                <SelectItem key={i} value={opt.value}>
                                  {opt.label_ar}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        )}

                        {/* Multi Select */}
                        {field.type === 'multi_select' && (
                          <div className="flex flex-wrap gap-1.5">
                            {field.options?.map((opt, i) => {
                              const selected = Array.isArray(value) && (value as string[]).includes(opt.value)
                              return (
                                <Badge
                                  key={i}
                                  variant={selected ? 'default' : 'outline'}
                                  className="cursor-pointer text-xs"
                                  onClick={() => {
                                    const arr = Array.isArray(value) ? [...value as string[]] : []
                                    if (selected) {
                                      setValue(field.id, arr.filter(v => v !== opt.value))
                                    } else {
                                      setValue(field.id, [...arr, opt.value])
                                    }
                                  }}
                                >
                                  {opt.label_ar}
                                </Badge>
                              )
                            })}
                          </div>
                        )}

                        {/* Date */}
                        {field.type === 'date' && (
                          <Input
                            type="date"
                            value={(value as string) || ''}
                            onChange={(e) => setValue(field.id, e.target.value)}
                            className="h-9 text-sm"
                          />
                        )}

                        {/* Time */}
                        {field.type === 'time' && (
                          <Input
                            type="time"
                            value={(value as string) || ''}
                            onChange={(e) => setValue(field.id, e.target.value)}
                            className="h-9 text-sm"
                          />
                        )}

                        {/* GPS */}
                        {field.type === 'gps' && (
                          <div className="flex items-center gap-2 p-3 bg-muted/50 rounded-lg">
                            <MapPin className="w-4 h-4 text-primary" />
                            <span className="text-xs text-muted-foreground">
                              سيتم تحديد الموقع تلقائياً
                            </span>
                          </div>
                        )}

                        {/* Photo */}
                        {field.type === 'photo' && (
                          <div className="border-2 border-dashed rounded-lg p-4 text-center">
                            <Camera className="w-6 h-6 mx-auto text-muted-foreground mb-1" />
                            <p className="text-xs text-muted-foreground">اضغط لالتقاط صورة</p>
                          </div>
                        )}

                        {/* Signature */}
                        {field.type === 'signature' && (
                          <div className="border-2 border-dashed rounded-lg p-4 text-center bg-muted/30">
                            <PenTool className="w-6 h-6 mx-auto text-muted-foreground mb-1" />
                            <p className="text-xs text-muted-foreground">اضغط للتوقيع</p>
                          </div>
                        )}

                        {/* Barcode */}
                        {field.type === 'barcode' && (
                          <div className="flex items-center gap-2 p-3 bg-muted/50 rounded-lg">
                            <QrCode className="w-4 h-4 text-primary" />
                            <span className="text-xs text-muted-foreground">
                              اضغط لمسح الباركود
                            </span>
                          </div>
                        )}

                        {field.placeholder_en && (
                          <p className="text-[10px] text-muted-foreground" dir="ltr">{field.placeholder_en}</p>
                        )}
                      </div>
                    )
                  })}
                </div>
              )}

              {/* Submit Button Preview */}
              {schema.fields.length > 0 && (
                <>
                  <Separator />
                  <Button className="w-full gap-2" disabled>
                    <Send className="w-4 h-4" />
                    إرسال النموذج
                  </Button>
                </>
              )}
            </div>
          </div>
        </div>

        <DialogFooter className="px-6 pb-6 border-t">
          <Button variant="outline" onClick={() => onOpenChange(false)} className="w-full">
            إغلاق
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ==================== Delete Confirmation Dialog ====================

interface DeleteFormDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  form: Form
  onSuccess: () => void
}

function DeleteFormDialog({ open, onOpenChange, form, onSuccess }: DeleteFormDialogProps) {
  const deleteForm = useDeleteForm()
  const { toast } = useToast()
  const schema = parseFormSchema(form.schema)
  const fieldCount = schema.fields?.length || 0

  const handleDelete = () => {
    deleteForm.mutate(form.id, {
      onSuccess: () => {
        toast({ title: 'تم حذف النموذج', variant: 'success' })
        onSuccess()
      },
      onError: () => {
        toast({ title: 'فشل حذف النموذج', variant: 'destructive' })
      },
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 text-destructive">
            <AlertTriangle className="w-5 h-5" />
            تأكيد الحذف
          </DialogTitle>
          <DialogDescription>
            هل أنت متأكد من حذف هذا النموذج؟ لا يمكن التراجع عن هذا الإجراء.
          </DialogDescription>
        </DialogHeader>

        <div className="p-3 bg-destructive/5 border border-destructive/20 rounded-lg space-y-1">
          <p className="font-medium text-sm">{form.title_ar}</p>
          <p className="text-xs text-muted-foreground" dir="ltr">{form.title_en}</p>
          <div className="flex gap-3 text-xs text-muted-foreground pt-1">
            <span>{fieldCount} حقل</span>
            <span>v{form.version}</span>
            <span>الإصدار {formatDate(form.created_at)}</span>
          </div>
        </div>

        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={deleteForm.isPending}>
            إلغاء
          </Button>
          <Button variant="destructive" onClick={handleDelete} disabled={deleteForm.isPending} className="gap-2">
            {deleteForm.isPending && <Loader2 className="w-4 h-4 animate-spin" />}
            {deleteForm.isPending ? 'جاري الحذف...' : 'حذف النموذج'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
