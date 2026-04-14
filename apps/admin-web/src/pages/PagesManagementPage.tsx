import { useState } from 'react'
import {
  Plus, Search, MoreVertical, Edit, Trash2, Eye, EyeOff,
  GripVertical, FileText, Globe, Lock, ArrowUp, ArrowDown,
  Layout, Type, Image, List, Table, Code, Quote, Heading1,
  Save, X, ChevronDown, ChevronUp, Move, Copy, ExternalLink,
  CheckCircle2, AlertCircle, Settings2, Layers
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Switch } from '@/components/ui/switch'
import { Label } from '@/components/ui/label'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator } from '@/components/ui/dropdown-menu'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Separator } from '@/components/ui/separator'
import { Header } from '@/components/layout/header'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { cn } from '@/lib/utils'
import { formatDate } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'
import { ROLE_LABELS, type UserRole } from '@/types/database'

// ═══════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════

interface PageBlock {
  id: string
  type: 'heading' | 'paragraph' | 'image' | 'list' | 'table' | 'code' | 'quote' | 'divider' | 'alert' | 'stats'
  content: string
  props?: Record<string, unknown>
}

interface DynamicPage {
  id: string
  slug: string
  title_ar: string
  content_ar: { blocks: PageBlock[] } | Record<string, unknown>
  icon?: string
  show_in_nav: boolean
  nav_order: number
  roles: string[]
  is_active: boolean
  created_at: string
  updated_at: string
}

// ═══════════════════════════════════════════════════════
// API Hooks
// ═══════════════════════════════════════════════════════

function usePages() {
  return useQuery({
    queryKey: ['pages'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('pages')
        .select('*')
        .order('nav_order', { ascending: true })
      if (error) throw error
      return data as DynamicPage[]
    },
  })
}

function useCreatePage() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (page: Partial<DynamicPage>) => {
      const { data, error } = await supabase
        .from('pages')
        .insert(page)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['pages'] }),
  })
}

function useUpdatePage() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, ...updates }: { id: string } & Partial<DynamicPage>) => {
      const { data, error } = await supabase
        .from('pages')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['pages'] }),
  })
}

function useDeletePage() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('pages').delete().eq('id', id)
      if (error) throw error
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['pages'] }),
  })
}

// ═══════════════════════════════════════════════════════
// Block Types Config
// ═══════════════════════════════════════════════════════

const BLOCK_TYPES = [
  { type: 'heading', label: 'عنوان', icon: Heading1, color: 'text-blue-600', bg: 'bg-blue-50' },
  { type: 'paragraph', label: 'فقرة نصية', icon: Type, color: 'text-gray-600', bg: 'bg-gray-50' },
  { type: 'image', label: 'صورة', icon: Image, color: 'text-emerald-600', bg: 'bg-emerald-50' },
  { type: 'list', label: 'قائمة', icon: List, color: 'text-purple-600', bg: 'bg-purple-50' },
  { type: 'table', label: 'جدول', icon: Table, color: 'text-amber-600', bg: 'bg-amber-50' },
  { type: 'code', label: 'كود', icon: Code, color: 'text-slate-600', bg: 'bg-slate-50' },
  { type: 'quote', label: 'اقتباس', icon: Quote, color: 'text-pink-600', bg: 'bg-pink-50' },
  { type: 'divider', label: 'فاصل', icon: Layers, color: 'text-gray-400', bg: 'bg-gray-50' },
  { type: 'alert', label: 'تنبيه', icon: AlertCircle, color: 'text-red-600', bg: 'bg-red-50' },
] as const

const ICON_OPTIONS = [
  '📄', '📋', '📊', '📈', '📉', '🗂️', '📁', '📝', '✏️', '📌',
  '🏷️', '🔖', '📎', '🔗', '🌐', '🏠', '⚙️', '🔧', '🎯', '💡',
  '📢', '🔔', '⚡', '🌟', '✅', '❌', '⚠️', '🛡️', '🏥', '💉',
]

// ═══════════════════════════════════════════════════════
// Main Component
// ═══════════════════════════════════════════════════════

export default function PagesManagementPage() {
  const [search, setSearch] = useState('')
  const [editPage, setEditPage] = useState<DynamicPage | null>(null)
  const [createOpen, setCreateOpen] = useState(false)
  const [deletePage, setDeletePage] = useState<DynamicPage | null>(null)
  const [previewPage, setPreviewPage] = useState<DynamicPage | null>(null)

  const { data: pages, isLoading, refetch } = usePages()

  const filtered = pages?.filter(p =>
    p.title_ar.includes(search) || p.slug.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="page-enter">
      <Header
        title="إدارة الصفحات"
        subtitle={`${pages?.length || 0} صفحة ديناميكية`}
        onRefresh={() => refetch()}
      />

      <div className="p-6 space-y-6">
        {/* Actions Bar */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              placeholder="بحث في الصفحات..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pr-10"
            />
          </div>
          <Button onClick={() => setCreateOpen(true)} className="gap-2">
            <Plus className="w-4 h-4" />
            صفحة جديدة
          </Button>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-blue-50">
                <FileText className="w-5 h-5 text-blue-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold">{pages?.length || 0}</p>
                <p className="text-xs text-muted-foreground">إجمالي الصفحات</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-emerald-50">
                <CheckCircle2 className="w-5 h-5 text-emerald-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold">{pages?.filter(p => p.is_active).length || 0}</p>
                <p className="text-xs text-muted-foreground">نشطة</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-amber-50">
                <Globe className="w-5 h-5 text-amber-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold">{pages?.filter(p => p.show_in_nav).length || 0}</p>
                <p className="text-xs text-muted-foreground">في القائمة</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-purple-50">
                <Lock className="w-5 h-5 text-purple-600" />
              </div>
              <div>
                <p className="text-2xl font-heading font-bold">{pages?.filter(p => p.roles.includes('admin')).length || 0}</p>
                <p className="text-xs text-muted-foreground">للأدمن فقط</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Pages Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {isLoading
            ? Array.from({ length: 6 }).map((_, i) => (
                <Card key={i}><CardContent className="p-5"><Skeleton className="w-full h-36" /></CardContent></Card>
              ))
            : filtered?.map((page) => (
                <PageCard
                  key={page.id}
                  page={page}
                  onEdit={() => setEditPage(page)}
                  onDelete={() => setDeletePage(page)}
                  onPreview={() => setPreviewPage(page)}
                />
              ))
          }
        </div>

        {filtered?.length === 0 && !isLoading && (
          <div className="text-center py-16">
            <div className="w-20 h-20 rounded-2xl bg-muted flex items-center justify-center mx-auto mb-4">
              <FileText className="w-10 h-10 text-muted-foreground" />
            </div>
            <h3 className="text-lg font-heading font-bold">لا توجد صفحات</h3>
            <p className="text-sm text-muted-foreground mt-1">ابدأ بإنشاء أول صفحة ديناميكية</p>
            <Button onClick={() => setCreateOpen(true)} className="mt-4 gap-2">
              <Plus className="w-4 h-4" />
              إنشاء صفحة
            </Button>
          </div>
        )}
      </div>

      {/* Create Dialog */}
      <PageEditorDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        mode="create"
      />

      {/* Edit Dialog */}
      {editPage && (
        <PageEditorDialog
          open={!!editPage}
          onOpenChange={() => setEditPage(null)}
          mode="edit"
          page={editPage}
        />
      )}

      {/* Preview Dialog */}
      {previewPage && (
        <PagePreviewDialog
          page={previewPage}
          open={!!previewPage}
          onOpenChange={() => setPreviewPage(null)}
        />
      )}

      {/* Delete Dialog */}
      {deletePage && (
        <DeletePageDialog
          page={deletePage}
          open={!!deletePage}
          onOpenChange={() => setDeletePage(null)}
        />
      )}
    </div>
  )
}

// ═══════════════════════════════════════════════════════
// Page Card
// ═══════════════════════════════════════════════════════

function PageCard({ page, onEdit, onDelete, onPreview }: {
  page: DynamicPage
  onEdit: () => void
  onDelete: () => void
  onPreview: () => void
}) {
  const updatePage = useUpdatePage()
  const { toast } = useToast()

  const blocks = (page.content_ar as any)?.blocks || []
  const blockCount = blocks.length

  return (
    <Card className={cn(
      'group hover:shadow-lg transition-all duration-200 overflow-hidden relative',
      !page.is_active && 'opacity-60'
    )}>
      {/* Color bar */}
      <div className={cn(
        'absolute top-0 left-0 right-0 h-1',
        page.is_active ? 'bg-gradient-to-l from-primary to-purple-500' : 'bg-gray-300'
      )} />

      <CardContent className="p-5 pt-6">
        {/* Header */}
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-primary/10 to-purple-50 flex items-center justify-center text-2xl">
              {page.icon || '📄'}
            </div>
            <div className="min-w-0">
              <h3 className="font-heading font-bold truncate">{page.title_ar}</h3>
              <p className="text-xs text-muted-foreground font-mono" dir="ltr">/{page.slug}</p>
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
                <Edit className="w-4 h-4 ml-2" />تعديل المحتوى
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => {
                updatePage.mutate({ id: page.id, show_in_nav: !page.show_in_nav }, {
                  onSuccess: () => toast({ title: page.show_in_nav ? 'أُزيلت من القائمة' : 'أُضيفت للقائمة', variant: 'success' })
                })
              }}>
                <Globe className="w-4 h-4 ml-2" />
                {page.show_in_nav ? 'إخفاء من القائمة' : 'إظهار في القائمة'}
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={onDelete} className="text-red-600 focus:text-red-600">
                <Trash2 className="w-4 h-4 ml-2" />حذف
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>

        {/* Badges */}
        <div className="flex flex-wrap gap-1.5 mb-3">
          <Badge variant={page.is_active ? 'success' : 'secondary'} className="text-[10px]">
            {page.is_active ? 'نشطة' : 'معطلة'}
          </Badge>
          {page.show_in_nav && (
            <Badge variant="outline" className="text-[10px] gap-1">
              <Globe className="w-3 h-3" /> في القائمة
            </Badge>
          )}
          <Badge variant="outline" className="text-[10px]">
            {blockCount} مكوّن
          </Badge>
          <Badge variant="outline" className="text-[10px]">
            ترتيب: {page.nav_order}
          </Badge>
        </div>

        {/* Roles */}
        <div className="flex flex-wrap gap-1 mb-3">
          {page.roles.map((role) => (
            <Badge key={role} variant="secondary" className="text-[9px]">
              {ROLE_LABELS[role as UserRole] || role}
            </Badge>
          ))}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between pt-3 border-t text-xs text-muted-foreground">
          <span>{formatDate(page.updated_at)}</span>
          <div className="flex items-center gap-2">
            <span>{page.is_active ? 'نشطة' : 'معطلة'}</span>
            <Switch
              checked={page.is_active}
              onCheckedChange={(checked) => {
                updatePage.mutate({ id: page.id, is_active: checked }, {
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

// ═══════════════════════════════════════════════════════
// Page Editor Dialog (Rich Block Editor)
// ═══════════════════════════════════════════════════════

function PageEditorDialog({ open, onOpenChange, mode, page }: {
  open: boolean
  onOpenChange: (v: boolean) => void
  mode: 'create' | 'edit'
  page?: DynamicPage
}) {
  const { toast } = useToast()
  const createPage = useCreatePage()
  const updatePage = useUpdatePage()

  const [title, setTitle] = useState(page?.title_ar || '')
  const [slug, setSlug] = useState(page?.slug || '')
  const [icon, setIcon] = useState(page?.icon || '📄')
  const [showInNav, setShowInNav] = useState(page?.show_in_nav ?? true)
  const [navOrder, setNavOrder] = useState(page?.nav_order ?? 99)
  const [roles, setRoles] = useState<string[]>(page?.roles || ['admin'])
  const [isActive, setIsActive] = useState(page?.is_active ?? true)
  const [blocks, setBlocks] = useState<PageBlock[]>(
    ((page?.content_ar as any)?.blocks || []) as PageBlock[]
  )
  const [iconPickerOpen, setIconPickerOpen] = useState(false)

  const generateSlug = (t: string) => {
    return t.replace(/\s+/g, '-').replace(/[^\u0600-\u06FF\w-]/g, '').toLowerCase() || `page-${Date.now()}`
  }

  const addBlock = (type: string) => {
    const newBlock: PageBlock = {
      id: `block-${Date.now()}`,
      type: type as PageBlock['type'],
      content: type === 'heading' ? 'عنوان جديد' :
               type === 'divider' ? '' :
               type === 'alert' ? '⚠️ تنبيه مهم' :
               'اكتب هنا...',
      props: type === 'heading' ? { level: 2 } :
             type === 'alert' ? { variant: 'warning' } :
             type === 'list' ? { items: ['عنصر 1', 'عنصر 2', 'عنصر 3'] } :
             {},
    }
    setBlocks([...blocks, newBlock])
  }

  const updateBlock = (id: string, content: string) => {
    setBlocks(blocks.map(b => b.id === id ? { ...b, content } : b))
  }

  const removeBlock = (id: string) => {
    setBlocks(blocks.filter(b => b.id !== id))
  }

  const moveBlock = (id: string, direction: 'up' | 'down') => {
    const idx = blocks.findIndex(b => b.id === id)
    if (direction === 'up' && idx > 0) {
      const newBlocks = [...blocks]
      ;[newBlocks[idx - 1], newBlocks[idx]] = [newBlocks[idx], newBlocks[idx - 1]]
      setBlocks(newBlocks)
    } else if (direction === 'down' && idx < blocks.length - 1) {
      const newBlocks = [...blocks]
      ;[newBlocks[idx], newBlocks[idx + 1]] = [newBlocks[idx + 1], newBlocks[idx]]
      setBlocks(newBlocks)
    }
  }

  const handleSave = () => {
    if (!title.trim()) {
      toast({ title: 'العنوان مطلوب', variant: 'destructive' })
      return
    }

    const pageData = {
      title_ar: title,
      slug: slug || generateSlug(title),
      icon,
      content_ar: { blocks },
      show_in_nav: showInNav,
      nav_order: navOrder,
      roles,
      is_active: isActive,
    }

    if (mode === 'create') {
      createPage.mutate(pageData as any, {
        onSuccess: () => {
          toast({ title: 'تم إنشاء الصفحة', variant: 'success' })
          onOpenChange(false)
        },
        onError: (e: any) => toast({ title: `فشل: ${e.message}`, variant: 'destructive' }),
      })
    } else {
      updatePage.mutate({ id: page!.id, ...pageData } as any, {
        onSuccess: () => {
          toast({ title: 'تم حفظ التعديلات', variant: 'success' })
          onOpenChange(false)
        },
        onError: (e: any) => toast({ title: `فشل: ${e.message}`, variant: 'destructive' }),
      })
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-3xl max-h-[90vh] overflow-hidden flex flex-col">
        <DialogHeader>
          <DialogTitle className="font-heading flex items-center gap-2">
            <Layout className="w-5 h-5 text-primary" />
            {mode === 'create' ? 'إنشاء صفحة جديدة' : 'تعديل الصفحة'}
          </DialogTitle>
        </DialogHeader>

        <div className="flex-1 overflow-y-auto space-y-5 py-2">
          {/* Basic Info */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>عنوان الصفحة *</Label>
              <Input
                value={title}
                onChange={(e) => {
                  setTitle(e.target.value)
                  if (mode === 'create' && !slug) setSlug(generateSlug(e.target.value))
                }}
                placeholder="مثال: دليل التطعيم"
              />
            </div>
            <div className="space-y-2">
              <Label>الرابط (Slug) *</Label>
              <div className="flex gap-2">
                <span className="flex items-center text-xs text-muted-foreground px-2 bg-muted rounded-lg" dir="ltr">/pages/</span>
                <Input
                  value={slug}
                  onChange={(e) => setSlug(e.target.value)}
                  placeholder="vaccination-guide"
                  dir="ltr"
                  className="flex-1"
                />
              </div>
            </div>
          </div>

          {/* Icon Picker */}
          <div className="space-y-2">
            <Label>أيقونة الصفحة</Label>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setIconPickerOpen(!iconPickerOpen)}
                className="w-12 h-12 rounded-xl border-2 border-dashed hover:border-primary flex items-center justify-center text-2xl transition-colors"
              >
                {icon}
              </button>
              <Button variant="ghost" size="sm" onClick={() => setIconPickerOpen(!iconPickerOpen)}>
                تغيير الأيقونة
              </Button>
            </div>
            {iconPickerOpen && (
              <div className="flex flex-wrap gap-2 p-3 rounded-lg border bg-muted/30 animate-fade-in">
                {ICON_OPTIONS.map((ic) => (
                  <button
                    key={ic}
                    onClick={() => { setIcon(ic); setIconPickerOpen(false) }}
                    className={cn(
                      'w-10 h-10 rounded-lg flex items-center justify-center text-xl transition-all hover:scale-110',
                      icon === ic ? 'bg-primary/10 ring-2 ring-primary' : 'hover:bg-muted'
                    )}
                  >
                    {ic}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Settings Row */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="flex items-center justify-between p-3 rounded-lg border">
              <div>
                <p className="text-sm font-medium">إظهار في القائمة</p>
                <p className="text-xs text-muted-foreground">يظهر في شريط التنقل</p>
              </div>
              <Switch checked={showInNav} onCheckedChange={setShowInNav} />
            </div>
            <div className="space-y-2">
              <Label>ترتيب في القائمة</Label>
              <Input type="number" value={navOrder} onChange={(e) => setNavOrder(Number(e.target.value))} />
            </div>
            <div className="space-y-2">
              <Label>الصلاحيات</Label>
              <Select
                value={roles[0] || 'admin'}
                onValueChange={(v) => setRoles([v])}
              >
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {Object.entries(ROLE_LABELS).map(([key, label]) => (
                    <SelectItem key={key} value={key}>{label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <Separator />

          {/* Block Editor */}
          <div>
            <div className="flex items-center justify-between mb-3">
              <Label className="text-base font-heading">محرر المحتوى</Label>
              <span className="text-xs text-muted-foreground">{blocks.length} مكوّن</span>
            </div>

            {/* Add Block Buttons */}
            <div className="flex flex-wrap gap-2 mb-4">
              {BLOCK_TYPES.map((bt) => {
                const Icon = bt.icon
                return (
                  <button
                    key={bt.type}
                    onClick={() => addBlock(bt.type)}
                    className={cn(
                      'flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-xs font-medium transition-all hover:shadow-sm',
                      bt.bg, bt.color, 'border-transparent hover:border-current/20'
                    )}
                  >
                    <Icon className="w-3.5 h-3.5" />
                    {bt.label}
                  </button>
                )
              })}
            </div>

            {/* Blocks */}
            <div className="space-y-3">
              {blocks.length === 0 ? (
                <div className="text-center py-12 border-2 border-dashed rounded-xl">
                  <Layers className="w-10 h-10 text-muted-foreground mx-auto mb-3" />
                  <p className="text-sm text-muted-foreground">أضف مكوّنات لبناء محتوى الصفحة</p>
                </div>
              ) : (
                blocks.map((block, idx) => (
                  <BlockEditor
                    key={block.id}
                    block={block}
                    index={idx}
                    total={blocks.length}
                    onUpdate={(content) => updateBlock(block.id, content)}
                    onRemove={() => removeBlock(block.id)}
                    onMoveUp={() => moveBlock(block.id, 'up')}
                    onMoveDown={() => moveBlock(block.id, 'down')}
                  />
                ))
              )}
            </div>
          </div>
        </div>

        <DialogFooter className="border-t pt-4">
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button onClick={handleSave} className="gap-2" disabled={createPage.isPending || updatePage.isPending}>
            <Save className="w-4 h-4" />
            {mode === 'create' ? 'إنشاء الصفحة' : 'حفظ التعديلات'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ═══════════════════════════════════════════════════════
// Block Editor Component
// ═══════════════════════════════════════════════════════

function BlockEditor({ block, index, total, onUpdate, onRemove, onMoveUp, onMoveDown }: {
  block: PageBlock
  index: number
  total: number
  onUpdate: (content: string) => void
  onRemove: () => void
  onMoveUp: () => void
  onMoveDown: () => void
}) {
  const bt = BLOCK_TYPES.find(b => b.type === block.type) || BLOCK_TYPES[1]
  const Icon = bt.icon

  return (
    <div className={cn('group rounded-xl border p-3 transition-all hover:shadow-sm', bt.bg)}>
      <div className="flex items-start gap-3">
        {/* Drag handle + actions */}
        <div className="flex flex-col items-center gap-1 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
          <button onClick={onMoveUp} disabled={index === 0} className="p-0.5 rounded hover:bg-white/50 disabled:opacity-30">
            <ChevronUp className="w-3.5 h-3.5" />
          </button>
          <div className={cn('p-1.5 rounded-lg', bt.bg)}>
            <Icon className={cn('w-4 h-4', bt.color)} />
          </div>
          <button onClick={onMoveDown} disabled={index === total - 1} className="p-0.5 rounded hover:bg-white/50 disabled:opacity-30">
            <ChevronDown className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-2">
            <span className={cn('text-xs font-medium', bt.color)}>{bt.label}</span>
            <span className="text-[10px] text-muted-foreground">#{index + 1}</span>
          </div>
          {block.type === 'heading' ? (
            <Input
              value={block.content}
              onChange={(e) => onUpdate(e.target.value)}
              className="font-heading font-bold text-lg bg-white/50"
              placeholder="عنوان القسم..."
            />
          ) : block.type === 'divider' ? (
            <div className="py-2">
              <Separator />
            </div>
          ) : block.type === 'alert' ? (
            <div className="flex gap-2">
              <AlertCircle className="w-4 h-4 text-amber-600 shrink-0 mt-2.5" />
              <Input
                value={block.content}
                onChange={(e) => onUpdate(e.target.value)}
                className="bg-white/50"
                placeholder="نص التنبيه..."
              />
            </div>
          ) : block.type === 'quote' ? (
            <div className="border-r-4 border-primary/30 pr-3">
              <textarea
                value={block.content}
                onChange={(e) => onUpdate(e.target.value)}
                className="w-full bg-transparent resize-none text-sm italic focus:outline-none min-h-[60px]"
                placeholder="اكتب الاقتباس..."
                rows={3}
              />
            </div>
          ) : block.type === 'code' ? (
            <textarea
              value={block.content}
              onChange={(e) => onUpdate(e.target.value)}
              className="w-full bg-slate-900 text-green-400 font-mono text-xs p-3 rounded-lg resize-none focus:outline-none min-h-[80px]"
              placeholder="// اكتب الكود هنا..."
              rows={4}
              dir="ltr"
            />
          ) : (
            <textarea
              value={block.content}
              onChange={(e) => onUpdate(e.target.value)}
              className="w-full bg-white/50 rounded-lg p-3 text-sm resize-none focus:outline-none focus:ring-1 focus:ring-primary/30 min-h-[80px]"
              placeholder="اكتب المحتوى..."
              rows={3}
            />
          )}
        </div>

        {/* Delete */}
        <button
          onClick={onRemove}
          className="p-1.5 rounded-lg text-red-400 hover:text-red-600 hover:bg-red-50 opacity-0 group-hover:opacity-100 transition-all shrink-0"
        >
          <X className="w-4 h-4" />
        </button>
      </div>
    </div>
  )
}

// ═══════════════════════════════════════════════════════
// Page Preview Dialog
// ═══════════════════════════════════════════════════════

function PagePreviewDialog({ page, open, onOpenChange }: {
  page: DynamicPage
  open: boolean
  onOpenChange: (v: boolean) => void
}) {
  const blocks = ((page.content_ar as any)?.blocks || []) as PageBlock[]

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[85vh]">
        <DialogHeader>
          <DialogTitle className="font-heading flex items-center gap-2">
            <span className="text-2xl">{page.icon || '📄'}</span>
            {page.title_ar}
          </DialogTitle>
          <DialogDescription dir="ltr">/{page.slug}</DialogDescription>
        </DialogHeader>

        <ScrollArea className="max-h-[60vh]">
          <div className="space-y-4 py-4">
            {blocks.length === 0 ? (
              <p className="text-center text-muted-foreground py-8">لا يوجد محتوى</p>
            ) : (
              blocks.map((block) => {
                switch (block.type) {
                  case 'heading':
                    return <h2 key={block.id} className="text-2xl font-heading font-bold mt-6 mb-2">{block.content}</h2>
                  case 'paragraph':
                    return <p key={block.id} className="text-sm leading-relaxed text-muted-foreground">{block.content}</p>
                  case 'quote':
                    return (
                      <blockquote key={block.id} className="border-r-4 border-primary/30 pr-4 italic text-muted-foreground">
                        {block.content}
                      </blockquote>
                    )
                  case 'code':
                    return (
                      <pre key={block.id} className="bg-slate-900 text-green-400 font-mono text-xs p-4 rounded-lg overflow-x-auto" dir="ltr">
                        {block.content}
                      </pre>
                    )
                  case 'alert':
                    return (
                      <div key={block.id} className="p-4 rounded-lg bg-amber-50 border border-amber-200 text-amber-800 text-sm">
                        {block.content}
                      </div>
                    )
                  case 'divider':
                    return <Separator key={block.id} className="my-6" />
                  default:
                    return <p key={block.id} className="text-sm">{block.content}</p>
                }
              })
            )}
          </div>
        </ScrollArea>
      </DialogContent>
    </Dialog>
  )
}

// ═══════════════════════════════════════════════════════
// Delete Confirmation Dialog
// ═══════════════════════════════════════════════════════

function DeletePageDialog({ page, open, onOpenChange }: {
  page: DynamicPage
  open: boolean
  onOpenChange: (v: boolean) => void
}) {
  const deletePage = useDeletePage()
  const { toast } = useToast()

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="text-red-600">حذف الصفحة</DialogTitle>
          <DialogDescription>
            هل أنت متأكد من حذف "{page.title_ar}"؟ لا يمكن التراجع عن هذا الإجراء.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button variant="destructive" onClick={() => {
            deletePage.mutate(page.id, {
              onSuccess: () => {
                toast({ title: 'تم حذف الصفحة', variant: 'success' })
                onOpenChange(false)
              },
              onError: () => toast({ title: 'فشل الحذف', variant: 'destructive' }),
            })
          }} disabled={deletePage.isPending}>
            {deletePage.isPending ? 'جاري الحذف...' : 'حذف'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
