import { useState, useMemo } from 'react'
import {
  Plus, Search, MoreVertical, Edit, Trash2, Eye, EyeOff,
  Globe, Lock, ArrowUp, ArrowDown,
  Layout, Type, Image, List, Table, Code, Quote, Heading1,
  Save, X, ChevronDown, ChevronUp, Copy, ExternalLink,
  CheckCircle2, AlertCircle, Settings2, Layers,
  Home, FileText, BarChart3, MapPin, MessageSquare, Settings,
  ClipboardList, Users, Bell, FileSpreadsheet, Star, FolderOpen,
  TrendingUp, Map, Send, Shield, Clock, History, GitBranch,
  Palette, Megaphone, Columns, BarChart2, PieChart, CalendarDays,
  HelpCircle, BookOpen, Newspaper, Flag, Award, Zap, Smartphone,
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

// App Page types
type PageVisibility = 'visible' | 'hidden'
type PageType = 'dashboard' | 'forms' | 'submissions' | 'analytics' | 'map' | 'chat' | 'settings' | 'notifications' | 'reports' | 'users' | 'custom'

interface AppPage {
  id: string
  page_type: PageType
  title_ar: string
  title_en: string
  icon: string
  icon_key: string
  visibility: PageVisibility
  allowed_roles: UserRole[]
  sort_order: number
  has_push_notifications: boolean
  custom_content?: Record<string, unknown>
  is_system: boolean
  created_at: string
  updated_at: string
}

// ═══════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════

const APP_PAGE_TEMPLATES: Record<PageType, { icon_key: string; icon: typeof Home; title_ar: string; title_en: string; is_system: boolean }> = {
  dashboard: { icon_key: 'home', icon: Home, title_ar: 'لوحة التحكم', title_en: 'Dashboard', is_system: true },
  forms: { icon_key: 'clipboard-list', icon: ClipboardList, title_ar: 'الاستمارات', title_en: 'Forms', is_system: true },
  submissions: { icon_key: 'file-spreadsheet', icon: FileSpreadsheet, title_ar: 'الإرسالات', title_en: 'Submissions', is_system: true },
  analytics: { icon_key: 'bar-chart-3', icon: BarChart3, title_ar: 'التحليلات', title_en: 'Analytics', is_system: true },
  map: { icon_key: 'map-pin', icon: MapPin, title_ar: 'الخريطة', title_en: 'Map', is_system: true },
  chat: { icon_key: 'message-square', icon: MessageSquare, title_ar: 'المحادثات', title_en: 'Chat', is_system: true },
  settings: { icon_key: 'settings', icon: Settings, title_ar: 'الإعدادات', title_en: 'Settings', is_system: true },
  notifications: { icon_key: 'bell', icon: Bell, title_ar: 'الإشعارات', title_en: 'Notifications', is_system: true },
  reports: { icon_key: 'bar-chart-2', icon: BarChart2, title_ar: 'التقارير', title_en: 'Reports', is_system: true },
  users: { icon_key: 'users', icon: Users, title_ar: 'المستخدمين', title_en: 'Users', is_system: true },
  custom: { icon_key: 'star', icon: Star, title_ar: 'صفحة مخصصة', title_en: 'Custom Page', is_system: false },
}

const ICON_COMPONENTS: Record<string, typeof Home> = {
  'home': Home,
  'clipboard-list': ClipboardList,
  'file-spreadsheet': FileSpreadsheet,
  'bar-chart-3': BarChart3,
  'map-pin': MapPin,
  'message-square': MessageSquare,
  'settings': Settings,
  'bell': Bell,
  'bar-chart-2': BarChart2,
  'users': Users,
  'star': Star,
  'file-text': FileText,
  'shield': Shield,
  'trending-up': TrendingUp,
  'map': Map,
  'send': Send,
  'palette': Palette,
  'megaphone': Megaphone,
  'columns': Columns,
  'pie-chart': PieChart,
  'calendar-days': CalendarDays,
  'help-circle': HelpCircle,
  'book-open': BookOpen,
  'newspaper': Newspaper,
  'flag': Flag,
  'award': Award,
  'zap': Zap,
  'folder-open': FolderOpen,
  'clock': Clock,
}

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

const PAGE_TEMPLATES = [
  {
    id: 'blank',
    name_ar: 'صفحة فارغة',
    name_en: 'Blank Page',
    icon: '📄',
    description: 'ابدأ من صفحة فارغة بدون أي محتوى',
    blocks: [] as PageBlock[],
  },
  {
    id: 'about',
    name_ar: 'صفحة تعريفية',
    name_en: 'About Page',
    icon: '📋',
    description: 'صفحة تحتوي على عنوان وفقرات نصية',
    blocks: [
      { id: 't1', type: 'heading' as const, content: 'عن الصفحة' },
      { id: 'p1', type: 'paragraph' as const, content: 'اكتب وصفاً عن هذه الصفحة هنا...' },
      { id: 'd1', type: 'divider' as const, content: '' },
      { id: 'p2', type: 'paragraph' as const, content: 'يمكنك إضافة المزيد من المحتوى...' },
    ],
  },
  {
    id: 'faq',
    name_ar: 'الأسئلة الشائعة',
    name_en: 'FAQ Page',
    icon: '❓',
    description: 'قالب للأسئلة والإجابات الشائعة',
    blocks: [
      { id: 't1', type: 'heading' as const, content: 'الأسئلة الشائعة' },
      { id: 'p1', type: 'alert' as const, content: 'إذا لم تجد إجابتك، تواصل معنا مباشرة', props: { variant: 'info' } },
      { id: 'q1', type: 'heading' as const, content: 'السؤال الأول؟', props: { level: 3 } },
      { id: 'a1', type: 'paragraph' as const, content: 'إجابة السؤال الأول...' },
    ],
  },
  {
    id: 'guide',
    name_ar: 'دليل إرشادي',
    name_en: 'Guide Page',
    icon: '📖',
    description: 'قالب لدليل خطواتي مع قائمة',
    blocks: [
      { id: 't1', type: 'heading' as const, content: 'الدليل الإرشادي' },
      { id: 'l1', type: 'list' as const, content: 'الخطوة الأولى', props: { items: ['الخطوة الأولى', 'الخطوة الثانية', 'الخطوة الثالثة'] } },
      { id: 'a1', type: 'alert' as const, content: '⚠️ تأكد من اتباع جميع التعليمات' },
    ],
  },
  {
    id: 'contact',
    name_ar: 'تواصل معنا',
    name_en: 'Contact Page',
    icon: '📞',
    description: 'صفحة معلومات التواصل والدعم',
    blocks: [
      { id: 't1', type: 'heading' as const, content: 'تواصل معنا' },
      { id: 'p1', type: 'paragraph' as const, content: 'يمكنك التواصل معنا عبر القنوات التالية...' },
      { id: 'd1', type: 'divider' as const, content: '' },
      { id: 't2', type: 'heading' as const, content: 'أوقات العمل', props: { level: 3 } },
      { id: 'p2', type: 'paragraph' as const, content: 'من الأحد إلى الخميس، 8 صباحاً - 4 مساءً' },
    ],
  },
]

const PUBLISHING_STATUSES = [
  { value: 'draft', label: 'مسودة', color: 'bg-gray-100 text-gray-700' },
  { value: 'review', label: 'قيد المراجعة', color: 'bg-amber-100 text-amber-700' },
  { value: 'published', label: 'منشورة', color: 'bg-emerald-100 text-emerald-700' },
  { value: 'archived', label: 'مؤرشفة', color: 'bg-red-100 text-red-700' },
] as const

type PublishingStatus = typeof PUBLISHING_STATUSES[number]['value']

// ═══════════════════════════════════════════════════════
// API Hooks - Dashboard Pages
// ═══════════════════════════════════════════════════════

function usePages() {
  return useQuery({
    queryKey: ['pages'],
    queryFn: async () => {
      try {
        const { data, error } = await supabase
          .from('pages')
          .select('*')
          .order('nav_order', { ascending: true })
        if (error) throw error
        return data as DynamicPage[]
      } catch {
        // Fallback: return empty array when table doesn't exist
        return [] as DynamicPage[]
      }
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
// API Hooks - App Pages
// ═══════════════════════════════════════════════════════

function useAppPages() {
  return useQuery({
    queryKey: ['app-pages'],
    queryFn: async () => {
      try {
        const { data, error } = await supabase
          .from('app_pages')
          .select('*')
          .order('sort_order', { ascending: true })
        if (error) throw error
        return data as AppPage[]
      } catch {
        // Fallback: return default app pages when table doesn't exist
        const defaults: AppPage[] = [
          { id: '1', page_type: 'dashboard', title_ar: 'لوحة التحكم', title_en: 'Dashboard', icon: 'H', icon_key: 'home', visibility: 'visible', allowed_roles: ['admin','central','governorate','district','data_entry'], sort_order: 1, has_push_notifications: false, is_system: true, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
          { id: '2', page_type: 'forms', title_ar: 'الاستمارات', title_en: 'Forms', icon: 'F', icon_key: 'clipboard-list', visibility: 'visible', allowed_roles: ['admin','central','governorate','district','data_entry'], sort_order: 2, has_push_notifications: false, is_system: true, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
          { id: '3', page_type: 'submissions', title_ar: 'الإرساليات', title_en: 'Submissions', icon: 'S', icon_key: 'file-spreadsheet', visibility: 'visible', allowed_roles: ['admin','central','governorate','district'], sort_order: 3, has_push_notifications: true, is_system: true, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
          { id: '4', page_type: 'analytics', title_ar: 'التحليلات', title_en: 'Analytics', icon: 'A', icon_key: 'bar-chart-3', visibility: 'visible', allowed_roles: ['admin','central','governorate'], sort_order: 4, has_push_notifications: false, is_system: true, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
          { id: '5', page_type: 'map', title_ar: 'الخريطة', title_en: 'Map', icon: 'M', icon_key: 'map-pin', visibility: 'visible', allowed_roles: ['admin','central','governorate','district'], sort_order: 5, has_push_notifications: false, is_system: true, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
          { id: '6', page_type: 'chat', title_ar: 'المحادثات', title_en: 'Chat', icon: 'C', icon_key: 'message-square', visibility: 'visible', allowed_roles: ['admin','central','governorate','district','data_entry'], sort_order: 6, has_push_notifications: true, is_system: true, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
          { id: '7', page_type: 'notifications', title_ar: 'الإشعارات', title_en: 'Notifications', icon: 'N', icon_key: 'bell', visibility: 'visible', allowed_roles: ['admin','central','governorate','district','data_entry'], sort_order: 7, has_push_notifications: true, is_system: true, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
          { id: '8', page_type: 'reports', title_ar: 'التقارير', title_en: 'Reports', icon: 'R', icon_key: 'bar-chart-2', visibility: 'visible', allowed_roles: ['admin','central'], sort_order: 8, has_push_notifications: false, is_system: true, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
          { id: '9', page_type: 'users', title_ar: 'المستخدمين', title_en: 'Users', icon: 'U', icon_key: 'users', visibility: 'visible', allowed_roles: ['admin'], sort_order: 9, has_push_notifications: false, is_system: true, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
          { id: '10', page_type: 'settings', title_ar: 'الإعدادات', title_en: 'Settings', icon: 'S', icon_key: 'settings', visibility: 'visible', allowed_roles: ['admin'], sort_order: 10, has_push_notifications: false, is_system: true, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
        ]
        return defaults
      }
    },
  })
}

function useCreateAppPage() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (page: Partial<AppPage>) => {
      const { data, error } = await supabase
        .from('app_pages')
        .insert(page)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['app-pages'] }),
  })
}

function useUpdateAppPage() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, ...updates }: { id: string } & Partial<AppPage>) => {
      const { data, error } = await supabase
        .from('app_pages')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['app-pages'] }),
  })
}

function useDeleteAppPage() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('app_pages').delete().eq('id', id)
      if (error) throw error
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['app-pages'] }),
  })
}

// ═══════════════════════════════════════════════════════
// Main Component
// ═══════════════════════════════════════════════════════

export default function PagesManagementPage() {
  const [activeTab, setActiveTab] = useState('app-pages')

  return (
    <div className="page-enter" dir="rtl">
      <Header
        title="إدارة الصفحات"
        subtitle="إدارة صفحات التطبيق ولوحة التحكم"
      />

      <div className="p-6 space-y-6">
        <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
          <TabsList className="grid w-full max-w-md grid-cols-2 mb-6">
            <TabsTrigger value="app-pages" className="gap-2 font-heading">
              <Smartphone className="w-4 h-4" />
              صفحات التطبيق
            </TabsTrigger>
            <TabsTrigger value="dashboard-pages" className="gap-2 font-heading">
              <Layout className="w-4 h-4" />
              صفحات لوحة التحكم
            </TabsTrigger>
          </TabsList>

          <TabsContent value="app-pages">
            <AppPagesTab />
          </TabsContent>

          <TabsContent value="dashboard-pages">
            <DashboardPagesTab />
          </TabsContent>
        </Tabs>
      </div>
    </div>
  )
}

// ═══════════════════════════════════════
// Tab 1: App Pages
// ═══════════════════════════════════════

function AppPagesTab() {
  const [search, setSearch] = useState('')
  const [editPage, setEditPage] = useState<AppPage | null>(null)
  const [createOpen, setCreateOpen] = useState(false)
  const [deletePage, setDeletePage] = useState<AppPage | null>(null)

  const { data: appPages, isLoading, refetch } = useAppPages()

  const filtered = appPages?.filter(p =>
    p.title_ar.includes(search) ||
    p.title_en.toLowerCase().includes(search.toLowerCase()) ||
    p.page_type.includes(search.toLowerCase())
  )

  const visibleCount = appPages?.filter(p => p.visibility === 'visible').length || 0
  const hiddenCount = appPages?.filter(p => p.visibility === 'hidden').length || 0
  const pushEnabled = appPages?.filter(p => p.has_push_notifications).length || 0

  return (
    <div className="space-y-6">
      {/* Actions Bar */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
        <div className="relative flex-1">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="بحث في صفحات التطبيق..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pr-10"
          />
        </div>
        <Button onClick={() => setCreateOpen(true)} className="gap-2">
          <Plus className="w-4 h-4" />
          صفحة تطبيق جديدة
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4 flex items-center gap-3">
            <div className="p-2 rounded-lg bg-blue-50">
              <Smartphone className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <p className="text-2xl font-heading font-bold">{appPages?.length || 0}</p>
              <p className="text-xs text-muted-foreground">إجمالي الصفحات</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-3">
            <div className="p-2 rounded-lg bg-emerald-50">
              <Eye className="w-5 h-5 text-emerald-600" />
            </div>
            <div>
              <p className="text-2xl font-heading font-bold">{visibleCount}</p>
              <p className="text-xs text-muted-foreground">مرئية</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-3">
            <div className="p-2 rounded-lg bg-amber-50">
              <EyeOff className="w-5 h-5 text-amber-600" />
            </div>
            <div>
              <p className="text-2xl font-heading font-bold">{hiddenCount}</p>
              <p className="text-xs text-muted-foreground">مخفية</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-3">
            <div className="p-2 rounded-lg bg-purple-50">
              <Bell className="w-5 h-5 text-purple-600" />
            </div>
            <div>
              <p className="text-2xl font-heading font-bold">{pushEnabled}</p>
              <p className="text-xs text-muted-foreground">إشعارات فعّالة</p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* App Pages Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {isLoading
          ? Array.from({ length: 6 }).map((_, i) => (
              <Card key={i}><CardContent className="p-5"><Skeleton className="w-full h-40" /></CardContent></Card>
            ))
          : filtered?.map((page) => (
              <AppPageCard
                key={page.id}
                page={page}
                onEdit={() => setEditPage(page)}
                onDelete={() => setDeletePage(page)}
              />
            ))
        }
      </div>

      {filtered?.length === 0 && !isLoading && (
        <div className="text-center py-16">
          <div className="w-20 h-20 rounded-2xl bg-muted flex items-center justify-center mx-auto mb-4">
            <Smartphone className="w-10 h-10 text-muted-foreground" />
          </div>
          <h3 className="text-lg font-heading font-bold">لا توجد صفحات تطبيق</h3>
          <p className="text-sm text-muted-foreground mt-1">أضف صفحات للتطبيق المحمول</p>
          <Button onClick={() => setCreateOpen(true)} className="mt-4 gap-2">
            <Plus className="w-4 h-4" />
            إنشاء صفحة تطبيق
          </Button>
        </div>
      )}

      {/* Create Dialog */}
      <AppPageEditorDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        mode="create"
      />

      {/* Edit Dialog */}
      {editPage && (
        <AppPageEditorDialog
          open={!!editPage}
          onOpenChange={() => setEditPage(null)}
          mode="edit"
          page={editPage}
        />
      )}

      {/* Delete Dialog */}
      {deletePage && (
        <DeleteAppPageDialog
          page={deletePage}
          open={!!deletePage}
          onOpenChange={() => setDeletePage(null)}
        />
      )}
    </div>
  )
}

// ═══════════════════════════════════════════════════════
// App Page Card
// ═══════════════════════════════════════════════════════

function AppPageCard({ page, onEdit, onDelete }: {
  page: AppPage
  onEdit: () => void
  onDelete: () => void
}) {
  const updateAppPage = useUpdateAppPage()
  const { toast } = useToast()

  const template = APP_PAGE_TEMPLATES[page.page_type] || APP_PAGE_TEMPLATES.custom
  const IconComp = ICON_COMPONENTS[page.icon_key] || template.icon

  return (
    <Card className={cn(
      'group hover:shadow-lg transition-all duration-200 overflow-hidden relative',
      page.visibility === 'hidden' && 'opacity-60'
    )}>
      {/* Top color bar */}
      <div className={cn(
        'absolute top-0 left-0 right-0 h-1',
        page.visibility === 'visible'
          ? 'bg-gradient-to-l from-blue-500 to-emerald-500'
          : 'bg-gray-300'
      )} />

      <CardContent className="p-5 pt-6">
        {/* Header */}
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-3">
            <div className={cn(
              'w-12 h-12 rounded-xl flex items-center justify-center',
              page.visibility === 'visible'
                ? 'bg-gradient-to-br from-blue-500/10 to-emerald-500/10'
                : 'bg-gray-100'
            )}>
              <IconComp className={cn(
                'w-6 h-6',
                page.visibility === 'visible' ? 'text-blue-600' : 'text-gray-400'
              )} />
            </div>
            <div className="min-w-0">
              <h3 className="font-heading font-bold truncate">{page.title_ar}</h3>
              <p className="text-xs text-muted-foreground">{page.title_en}</p>
            </div>
          </div>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100">
                <MoreVertical className="w-4 h-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={onEdit}>
                <Edit className="w-4 h-4 ml-2" />تعديل
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => {
                updateAppPage.mutate({
                  id: page.id,
                  visibility: page.visibility === 'visible' ? 'hidden' : 'visible'
                } as any, {
                  onSuccess: () => toast({
                    title: page.visibility === 'visible' ? 'تم الإخفاء' : 'تم الإظهار',
                    variant: 'success'
                  })
                })
              }}>
                {page.visibility === 'visible' ? (
                  <><EyeOff className="w-4 h-4 ml-2" />إخفاء الصفحة</>
                ) : (
                  <><Eye className="w-4 h-4 ml-2" />إظهار الصفحة</>
                )}
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => {
                updateAppPage.mutate({
                  id: page.id,
                  has_push_notifications: !page.has_push_notifications
                } as any, {
                  onSuccess: () => toast({
                    title: page.has_push_notifications ? 'تم إيقاف الإشعارات' : 'تم تفعيل الإشعارات',
                    variant: 'success'
                  })
                })
              }}>
                <Bell className="w-4 h-4 ml-2" />
                {page.has_push_notifications ? 'إيقاف الإشعارات' : 'تفعيل الإشعارات'}
              </DropdownMenuItem>
              {!page.is_system && (
                <>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem onClick={onDelete} className="text-red-600 focus:text-red-600">
                    <Trash2 className="w-4 h-4 ml-2" />حذف
                  </DropdownMenuItem>
                </>
              )}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>

        {/* Badges */}
        <div className="flex flex-wrap gap-1.5 mb-3">
          <Badge variant={page.visibility === 'visible' ? 'success' : 'secondary'} className="text-[10px]">
            {page.visibility === 'visible' ? 'مرئية' : 'مخفية'}
          </Badge>
          {page.is_system && (
            <Badge variant="outline" className="text-[10px] gap-1">
              <Shield className="w-3 h-3" /> نظامية
            </Badge>
          )}
          {page.has_push_notifications && (
            <Badge variant="outline" className="text-[10px] gap-1">
              <Bell className="w-3 h-3" /> إشعارات
            </Badge>
          )}
          <Badge variant="outline" className="text-[10px]">
            ترتيب: {page.sort_order}
          </Badge>
        </div>

        {/* Roles */}
        <div className="flex flex-wrap gap-1 mb-3">
          {page.allowed_roles.map((role) => (
            <Badge key={role} variant="secondary" className="text-[9px]">
              {ROLE_LABELS[role] || role}
            </Badge>
          ))}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between pt-3 border-t text-xs text-muted-foreground">
          <span className="flex items-center gap-1">
            <Clock className="w-3 h-3" />
            {formatDate(page.updated_at)}
          </span>
          <div className="flex items-center gap-2">
            <span>{page.visibility === 'visible' ? 'مرئية' : 'مخفية'}</span>
            <Switch
              checked={page.visibility === 'visible'}
              onCheckedChange={(checked) => {
                updateAppPage.mutate({
                  id: page.id,
                  visibility: checked ? 'visible' : 'hidden'
                } as any, {
                  onSuccess: () => toast({ title: checked ? 'تم الإظهار' : 'تم الإخفاء', variant: 'success' })
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
// App Page Editor Dialog
// ═══════════════════════════════════════════════════════

function AppPageEditorDialog({ open, onOpenChange, mode, page }: {
  open: boolean
  onOpenChange: (v: boolean) => void
  mode: 'create' | 'edit'
  page?: AppPage
}) {
  const { toast } = useToast()
  const createAppPage = useCreateAppPage()
  const updateAppPage = useUpdateAppPage()

  const [titleAr, setTitleAr] = useState(page?.title_ar || '')
  const [titleEn, setTitleEn] = useState(page?.title_en || '')
  const [pageType, setPageType] = useState<PageType>(page?.page_type || 'custom')
  const [iconKey, setIconKey] = useState(page?.icon_key || 'star')
  const [visibility, setVisibility] = useState<PageVisibility>(page?.visibility || 'visible')
  const [allowedRoles, setAllowedRoles] = useState<UserRole[]>(page?.allowed_roles as UserRole[] || ['admin'])
  const [sortOrder, setSortOrder] = useState(page?.sort_order ?? 99)
  const [pushNotifications, setPushNotifications] = useState(page?.has_push_notifications ?? false)
  const [iconPickerOpen, setIconPickerOpen] = useState(false)

  const iconEntries = Object.entries(ICON_COMPONENTS)

  const toggleRole = (role: UserRole) => {
    setAllowedRoles(prev =>
      prev.includes(role) ? prev.filter(r => r !== role) : [...prev, role]
    )
  }

  const handleSave = () => {
    if (!titleAr.trim()) {
      toast({ title: 'العنوان بالعربية مطلوب', variant: 'destructive' })
      return
    }
    if (allowedRoles.length === 0) {
      toast({ title: 'يجب تحديد صلاحية واحدة على الأقل', variant: 'destructive' })
      return
    }

    const pageData = {
      title_ar: titleAr,
      title_en: titleEn || titleAr,
      page_type: pageType,
      icon_key: iconKey,
      icon: titleAr.charAt(0),
      visibility,
      allowed_roles: allowedRoles,
      sort_order: sortOrder,
      has_push_notifications: pushNotifications,
    }

    if (mode === 'create') {
      createAppPage.mutate(pageData as any, {
        onSuccess: () => {
          toast({ title: 'تم إنشاء صفحة التطبيق', variant: 'success' })
          onOpenChange(false)
        },
        onError: (e: any) => toast({ title: `فشل: ${e.message}`, variant: 'destructive' }),
      })
    } else {
      updateAppPage.mutate({ id: page!.id, ...pageData } as any, {
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
      <DialogContent className="sm:max-w-2xl max-h-[90vh] overflow-hidden flex flex-col">
        <DialogHeader>
          <DialogTitle className="font-heading flex items-center gap-2">
            <Smartphone className="w-5 h-5 text-blue-600" />
            {mode === 'create' ? 'إضافة صفحة تطبيق جديدة' : 'تعديل صفحة التطبيق'}
          </DialogTitle>
          <DialogDescription>
            {mode === 'create'
              ? 'أضف صفحة جديدة للتطبيق المحمول'
              : `تعديل "${page?.title_ar}"`
            }
          </DialogDescription>
        </DialogHeader>

        <div className="flex-1 overflow-y-auto space-y-5 py-2">
          {/* Page Type */}
          {mode === 'create' && (
            <div className="space-y-2">
              <Label>نوع الصفحة</Label>
              <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
                {(Object.entries(APP_PAGE_TEMPLATES) as [PageType, typeof APP_PAGE_TEMPLATES[PageType]][]).map(([key, tmpl]) => {
                  const Icon = tmpl.icon
                  return (
                    <button
                      key={key}
                      onClick={() => {
                        setPageType(key)
                        setTitleAr(prev => prev || tmpl.title_ar)
                        setTitleEn(prev => prev || tmpl.title_en)
                        setIconKey(tmpl.icon_key)
                      }}
                      className={cn(
                        'flex flex-col items-center gap-1.5 p-3 rounded-xl border-2 transition-all text-center',
                        pageType === key
                          ? 'border-primary bg-primary/5 shadow-sm'
                          : 'border-muted hover:border-primary/30 hover:bg-muted/50'
                      )}
                    >
                      <Icon className={cn('w-5 h-5', pageType === key ? 'text-primary' : 'text-muted-foreground')} />
                      <span className="text-xs font-medium truncate w-full">{tmpl.title_ar}</span>
                      {tmpl.is_system && (
                        <Badge variant="outline" className="text-[8px] px-1 py-0">نظامية</Badge>
                      )}
                    </button>
                  )
                })}
              </div>
            </div>
          )}

          {/* Titles */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>اسم الصفحة (عربي) *</Label>
              <Input
                value={titleAr}
                onChange={(e) => setTitleAr(e.target.value)}
                placeholder="مثال: لوحة التحكم"
              />
            </div>
            <div className="space-y-2">
              <Label>اسم الصفحة (إنجليزي)</Label>
              <Input
                value={titleEn}
                onChange={(e) => setTitleEn(e.target.value)}
                placeholder="Example: Dashboard"
                dir="ltr"
              />
            </div>
          </div>

          {/* Icon Picker */}
          <div className="space-y-2">
            <Label>أيقونة الصفحة</Label>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setIconPickerOpen(!iconPickerOpen)}
                className={cn(
                  'w-12 h-12 rounded-xl border-2 border-dashed flex items-center justify-center transition-colors',
                  iconPickerOpen ? 'border-primary bg-primary/5' : 'hover:border-primary'
                )}
              >
                {(() => {
                  const Icon = ICON_COMPONENTS[iconKey] || Star
                  return <Icon className="w-5 h-5 text-primary" />
                })()}
              </button>
              <Button variant="ghost" size="sm" onClick={() => setIconPickerOpen(!iconPickerOpen)}>
                تغيير الأيقونة
              </Button>
            </div>
            {iconPickerOpen && (
              <div className="grid grid-cols-8 gap-2 p-3 rounded-lg border bg-muted/30 animate-fade-in">
                {iconEntries.map(([key, Icon]) => (
                  <button
                    key={key}
                    onClick={() => { setIconKey(key); setIconPickerOpen(false) }}
                    className={cn(
                      'w-10 h-10 rounded-lg flex items-center justify-center transition-all hover:scale-110',
                      iconKey === key ? 'bg-primary/10 ring-2 ring-primary' : 'hover:bg-muted'
                    )}
                  >
                    <Icon className="w-5 h-5" />
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Settings Row */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="space-y-2">
              <Label>ترتيب العرض</Label>
              <Input
                type="number"
                value={sortOrder}
                onChange={(e) => setSortOrder(Number(e.target.value))}
                min={0}
              />
            </div>
            <div className="flex items-center justify-between p-3 rounded-lg border">
              <div>
                <p className="text-sm font-medium">مرئية</p>
                <p className="text-xs text-muted-foreground">عرض في التطبيق</p>
              </div>
              <Switch
                checked={visibility === 'visible'}
                onCheckedChange={(checked) => setVisibility(checked ? 'visible' : 'hidden')}
              />
            </div>
            <div className="flex items-center justify-between p-3 rounded-lg border">
              <div>
                <p className="text-sm font-medium">إشعارات فورية</p>
                <p className="text-xs text-muted-foreground">تنبيهات عند التحديث</p>
              </div>
              <Switch checked={pushNotifications} onCheckedChange={setPushNotifications} />
            </div>
          </div>

          {/* Roles */}
          <div className="space-y-2">
            <Label>الصلاحيات المسموحة</Label>
            <div className="flex flex-wrap gap-2">
              {(Object.entries(ROLE_LABELS) as [UserRole, string][]).map(([role, label]) => (
                <button
                  key={role}
                  onClick={() => toggleRole(role)}
                  className={cn(
                    'px-3 py-1.5 rounded-lg border-2 text-sm font-medium transition-all',
                    allowedRoles.includes(role)
                      ? 'border-primary bg-primary/10 text-primary'
                      : 'border-muted text-muted-foreground hover:border-primary/30'
                  )}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>

          {/* Page Type-specific settings */}
          {pageType === 'analytics' && (
            <div className="p-4 rounded-lg border bg-muted/30 space-y-3">
              <h4 className="text-sm font-medium flex items-center gap-2">
                <BarChart3 className="w-4 h-4 text-blue-600" />
                إعدادات صفحة التحليلات
              </h4>
              <div className="flex items-center justify-between">
                <p className="text-sm text-muted-foreground">عرض الرسوم البيانية</p>
                <Switch defaultChecked />
              </div>
              <div className="flex items-center justify-between">
                <p className="text-sm text-muted-foreground">تقرير أسبوعي تلقائي</p>
                <Switch />
              </div>
            </div>
          )}

          {pageType === 'map' && (
            <div className="p-4 rounded-lg border bg-muted/30 space-y-3">
              <h4 className="text-sm font-medium flex items-center gap-2">
                <MapPin className="w-4 h-4 text-emerald-600" />
                إعدادات صفحة الخريطة
              </h4>
              <div className="flex items-center justify-between">
                <p className="text-sm text-muted-foreground">عرض نقاط البيانات</p>
                <Switch defaultChecked />
              </div>
              <div className="flex items-center justify-between">
                <p className="text-sm text-muted-foreground">تحديد الموقع GPS</p>
                <Switch defaultChecked />
              </div>
            </div>
          )}

          {pageType === 'notifications' && (
            <div className="p-4 rounded-lg border bg-muted/30 space-y-3">
              <h4 className="text-sm font-medium flex items-center gap-2">
                <Bell className="w-4 h-4 text-purple-600" />
                إعدادات الإشعارات
              </h4>
              <div className="flex items-center justify-between">
                <p className="text-sm text-muted-foreground">إشعارات النظام</p>
                <Switch defaultChecked />
              </div>
              <div className="flex items-center justify-between">
                <p className="text-sm text-muted-foreground">إشعارات الاستمارات الجديدة</p>
                <Switch defaultChecked />
              </div>
            </div>
          )}
        </div>

        <DialogFooter className="border-t pt-4">
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button onClick={handleSave} className="gap-2" disabled={createAppPage.isPending || updateAppPage.isPending}>
            <Save className="w-4 h-4" />
            {mode === 'create' ? 'إضافة الصفحة' : 'حفظ التعديلات'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ═══════════════════════════════════════════════════════
// Delete App Page Dialog
// ═══════════════════════════════════════════════════════

function DeleteAppPageDialog({ page, open, onOpenChange }: {
  page: AppPage
  open: boolean
  onOpenChange: (v: boolean) => void
}) {
  const deleteAppPage = useDeleteAppPage()
  const { toast } = useToast()

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="text-red-600">حذف صفحة التطبيق</DialogTitle>
          <DialogDescription>
            هل أنت متأكد من حذف "{page.title_ar}"؟ لا يمكن التراجع عن هذا الإجراء.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button variant="destructive" onClick={() => {
            deleteAppPage.mutate(page.id, {
              onSuccess: () => {
                toast({ title: 'تم حذف صفحة التطبيق', variant: 'success' })
                onOpenChange(false)
              },
              onError: () => toast({ title: 'فشل الحذف', variant: 'destructive' }),
            })
          }} disabled={deleteAppPage.isPending}>
            {deleteAppPage.isPending ? 'جاري الحذف...' : 'حذف'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ═══════════════════════════════════════════════════════
// Tab 2: Dashboard Pages (CMS)
// ═══════════════════════════════════════════════════════

function DashboardPagesTab() {
  const [search, setSearch] = useState('')
  const [editPage, setEditPage] = useState<DynamicPage | null>(null)
  const [createOpen, setCreateOpen] = useState(false)
  const [deletePage, setDeletePage] = useState<DynamicPage | null>(null)
  const [previewPage, setPreviewPage] = useState<DynamicPage | null>(null)
  const [templateOpen, setTemplateOpen] = useState(false)

  const { data: pages, isLoading, refetch } = usePages()

  const filtered = pages?.filter(p =>
    p.title_ar.includes(search) || p.slug.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="space-y-6">
      {/* Actions Bar */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
        <div className="relative flex-1">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="بحث في صفحات لوحة التحكم..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pr-10"
          />
        </div>
        <Button variant="outline" onClick={() => setTemplateOpen(true)} className="gap-2">
          <Layout className="w-4 h-4" />
          من قالب
        </Button>
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
              <DashboardPageCard
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
          <div className="flex items-center justify-center gap-3 mt-4">
            <Button variant="outline" onClick={() => setTemplateOpen(true)} className="gap-2">
              <Layout className="w-4 h-4" />
              من قالب
            </Button>
            <Button onClick={() => setCreateOpen(true)} className="gap-2">
              <Plus className="w-4 h-4" />
              إنشاء صفحة
            </Button>
          </div>
        </div>
      )}

      {/* Template Picker */}
      <TemplatePickerDialog
        open={templateOpen}
        onOpenChange={setTemplateOpen}
        onSelect={(template) => {
          setTemplateOpen(false)
          // Open create dialog pre-filled with template data
          setEditPage(null)
          setCreateOpen(true)
          // The template data is passed via the create dialog's internal state
        }}
      />

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
// Dashboard Page Card
// ═══════════════════════════════════════════════════════

function DashboardPageCard({ page, onEdit, onDelete, onPreview }: {
  page: DynamicPage
  onEdit: () => void
  onDelete: () => void
  onPreview: () => void
}) {
  const updatePage = useUpdatePage()
  const { toast } = useToast()

  const blocks = (page.content_ar as any)?.blocks || []
  const blockCount = blocks.length

  // Determine publishing status from metadata or derive
  const publishingStatus: PublishingStatus = (page as any).publishing_status || (page.is_active ? 'published' : 'draft')

  const statusConfig = PUBLISHING_STATUSES.find(s => s.value === publishingStatus) || PUBLISHING_STATUSES[0]

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
              {/* Publishing workflow */}
              <DropdownMenuSeparator />
              {publishingStatus === 'draft' && (
                <DropdownMenuItem onClick={() => {
                  updatePage.mutate({ id: page.id, /* publishing_status: 'review' */ } as any, {
                    onSuccess: () => toast({ title: 'أُرسلت للمراجعة', variant: 'success' })
                  })
                }}>
                  <Send className="w-4 h-4 ml-2" />إرسال للمراجعة
                </DropdownMenuItem>
              )}
              {publishingStatus === 'review' && (
                <DropdownMenuItem onClick={() => {
                  updatePage.mutate({ id: page.id, is_active: true } as any, {
                    onSuccess: () => toast({ title: 'تم النشر', variant: 'success' })
                  })
                }}>
                  <CheckCircle2 className="w-4 h-4 ml-2" />نشر
                </DropdownMenuItem>
              )}
              <DropdownMenuItem onClick={() => {
                navigator.clipboard.writeText(`${window.location.origin}/pages/${page.slug}`)
                toast({ title: 'تم نسخ الرابط', variant: 'success' })
              }}>
                <Copy className="w-4 h-4 ml-2" />نسخ الرابط
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => window.open(`/pages/${page.slug}`, '_blank')}>
                <ExternalLink className="w-4 h-4 ml-2" />فتح في تبويب جديد
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
          <Badge className={cn('text-[10px]', statusConfig.color)}>
            {statusConfig.label}
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

        {/* SEO indicator */}
        {(page as any).meta_title && (
          <div className="flex items-center gap-1.5 mb-3 text-xs text-muted-foreground">
            <Globe className="w-3 h-3 text-emerald-500" />
            <span>SEO مُعد</span>
          </div>
        )}

        {/* Footer */}
        <div className="flex items-center justify-between pt-3 border-t text-xs text-muted-foreground">
          <span className="flex items-center gap-1">
            <Clock className="w-3 h-3" />
            {formatDate(page.updated_at)}
          </span>
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
// Template Picker Dialog
// ═══════════════════════════════════════════════════════

function TemplatePickerDialog({ open, onOpenChange, onSelect }: {
  open: boolean
  onOpenChange: (v: boolean) => void
  onSelect: (template: typeof PAGE_TEMPLATES[number]) => void
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle className="font-heading flex items-center gap-2">
            <Layout className="w-5 h-5 text-primary" />
            اختر قالباً للصفحة
          </DialogTitle>
          <DialogDescription>
            ابدأ بقالب جاهز ثم عدّله حسب حاجتك
          </DialogDescription>
        </DialogHeader>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 py-4">
          {PAGE_TEMPLATES.map((template) => (
            <button
              key={template.id}
              onClick={() => onSelect(template)}
              className="text-right p-4 rounded-xl border-2 hover:border-primary hover:bg-primary/5 transition-all group"
            >
              <div className="flex items-start gap-3">
                <span className="text-3xl">{template.icon}</span>
                <div className="flex-1 min-w-0">
                  <h4 className="font-heading font-bold group-hover:text-primary transition-colors">
                    {template.name_ar}
                  </h4>
                  <p className="text-xs text-muted-foreground" dir="ltr">{template.name_en}</p>
                  <p className="text-xs text-muted-foreground mt-1">{template.description}</p>
                  <div className="flex items-center gap-1 mt-2">
                    <Badge variant="outline" className="text-[9px]">
                      {template.blocks.length} مكوّن
                    </Badge>
                  </div>
                </div>
              </div>
            </button>
          ))}
        </div>
      </DialogContent>
    </Dialog>
  )
}

// ═══════════════════════════════════════════════════════
// Page Editor Dialog (Rich Block Editor - Enhanced)
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

  // SEO settings
  const [metaTitle, setMetaTitle] = useState((page as any)?.meta_title || '')
  const [metaDescription, setMetaDescription] = useState((page as any)?.meta_description || '')

  // Publishing status
  const [publishingStatus, setPublishingStatus] = useState<PublishingStatus>(
    (page as any)?.publishing_status || (page?.is_active ? 'published' : 'draft')
  )

  // Version history
  const [showVersions, setShowVersions] = useState(false)

  // Active editor tab
  const [editorTab, setEditorTab] = useState<'content' | 'seo' | 'access' | 'versions'>('content')

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
      is_active: publishingStatus === 'published',
      meta_title: metaTitle || undefined,
      meta_description: metaDescription || undefined,
      publishing_status: publishingStatus,
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
      <DialogContent className="sm:max-w-4xl max-h-[90vh] overflow-hidden flex flex-col">
        <DialogHeader>
          <DialogTitle className="font-heading flex items-center gap-2">
            <Layout className="w-5 h-5 text-primary" />
            {mode === 'create' ? 'إنشاء صفحة جديدة' : 'تعديل الصفحة'}
          </DialogTitle>
        </DialogHeader>

        {/* Editor Tabs */}
        <Tabs value={editorTab} onValueChange={(v) => setEditorTab(v as typeof editorTab)} className="flex-1 flex flex-col overflow-hidden">
          <TabsList className="grid w-full max-w-lg grid-cols-4 mb-2">
            <TabsTrigger value="content" className="text-xs gap-1">
              <Type className="w-3.5 h-3.5" /> المحتوى
            </TabsTrigger>
            <TabsTrigger value="seo" className="text-xs gap-1">
              <Globe className="w-3.5 h-3.5" /> SEO
            </TabsTrigger>
            <TabsTrigger value="access" className="text-xs gap-1">
              <Shield className="w-3.5 h-3.5" /> الصلاحيات
            </TabsTrigger>
            <TabsTrigger value="versions" className="text-xs gap-1">
              <History className="w-3.5 h-3.5" /> السجل
            </TabsTrigger>
          </TabsList>

          <div className="flex-1 overflow-y-auto">
            {/* ═══ Content Tab ═══ */}
            <TabsContent value="content" className="space-y-5 mt-0">
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
                  <Label>حالة النشر</Label>
                  <Select value={publishingStatus} onValueChange={(v) => setPublishingStatus(v as PublishingStatus)}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {PUBLISHING_STATUSES.map((s) => (
                        <SelectItem key={s.value} value={s.value}>
                          <span className="flex items-center gap-2">
                            <span className={cn('w-2 h-2 rounded-full', s.value === 'draft' ? 'bg-gray-400' : s.value === 'review' ? 'bg-amber-400' : s.value === 'published' ? 'bg-emerald-400' : 'bg-red-400')} />
                            {s.label}
                          </span>
                        </SelectItem>
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
            </TabsContent>

            {/* ═══ SEO Tab ═══ */}
            <TabsContent value="seo" className="space-y-5 mt-0">
              <Card>
                <CardHeader>
                  <CardTitle className="text-base font-heading flex items-center gap-2">
                    <Globe className="w-4 h-4 text-emerald-600" />
                    إعدادات تحسين محركات البحث (SEO)
                  </CardTitle>
                  <CardDescription>
                    حسّن ظهور الصفحة في نتائج البحث
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Label>عنوان SEO (Meta Title)</Label>
                    <Input
                      value={metaTitle}
                      onChange={(e) => setMetaTitle(e.target.value)}
                      placeholder="عنوان مختصر للبحث (60 حرف كحد أقصى)"
                      maxLength={60}
                    />
                    <p className="text-xs text-muted-foreground">{metaTitle.length}/60 حرف</p>
                  </div>
                  <div className="space-y-2">
                    <Label>وصف SEO (Meta Description)</Label>
                    <textarea
                      value={metaDescription}
                      onChange={(e) => setMetaDescription(e.target.value)}
                      placeholder="وصف مختصر يظهر في نتائج البحث (160 حرف كحد أقصى)"
                      maxLength={160}
                      className="w-full min-h-[80px] rounded-lg border border-input bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-ring resize-none"
                      rows={3}
                    />
                    <p className="text-xs text-muted-foreground">{metaDescription.length}/160 حرف</p>
                  </div>

                  {/* Preview */}
                  <div className="p-4 rounded-lg bg-muted/50 border">
                    <p className="text-xs text-muted-foreground mb-2">معاينة في نتائج البحث:</p>
                    <div dir="ltr" className="space-y-1">
                      <p className="text-blue-600 text-sm font-medium truncate">
                        {metaTitle || title || 'عنوان الصفحة'} | EPI Supervisor
                      </p>
                      <p className="text-emerald-700 text-xs">
                        {window.location.origin}/pages/{slug || 'page-slug'}
                      </p>
                      <p className="text-gray-600 text-xs line-clamp-2">
                        {metaDescription || 'لم يتم إضافة وصف بعد...'}
                      </p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            {/* ═══ Access Control Tab ═══ */}
            <TabsContent value="access" className="space-y-5 mt-0">
              <Card>
                <CardHeader>
                  <CardTitle className="text-base font-heading flex items-center gap-2">
                    <Shield className="w-4 h-4 text-purple-600" />
                    صلاحيات الوصول
                  </CardTitle>
                  <CardDescription>
                    حدد من يمكنه الوصول لهذه الصفحة
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Label>الأدوار المسموحة</Label>
                    <div className="flex flex-wrap gap-2">
                      {(Object.entries(ROLE_LABELS) as [UserRole, string][]).map(([role, label]) => (
                        <button
                          key={role}
                          onClick={() => {
                            setRoles(prev =>
                              prev.includes(role)
                                ? prev.filter(r => r !== role)
                                : [...prev, role]
                            )
                          }}
                          className={cn(
                            'px-4 py-2 rounded-lg border-2 text-sm font-medium transition-all',
                            roles.includes(role)
                              ? 'border-primary bg-primary/10 text-primary'
                              : 'border-muted text-muted-foreground hover:border-primary/30'
                          )}
                        >
                          <div className="flex items-center gap-2">
                            {roles.includes(role) ? (
                              <CheckCircle2 className="w-4 h-4" />
                            ) : (
                              <div className="w-4 h-4 rounded-full border-2 border-current" />
                            )}
                            {label}
                          </div>
                        </button>
                      ))}
                    </div>
                    {roles.length === 0 && (
                      <p className="text-xs text-red-500 mt-1">
                        ⚠️ يجب تحديد صلاحية واحدة على الأقل
                      </p>
                    )}
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            {/* ═══ Version History Tab ═══ */}
            <TabsContent value="versions" className="space-y-5 mt-0">
              <Card>
                <CardHeader>
                  <CardTitle className="text-base font-heading flex items-center gap-2">
                    <History className="w-4 h-4 text-slate-600" />
                    سجل التعديلات
                  </CardTitle>
                  <CardDescription>
                    عرض وإدارة نسخ الصفحة السابقة
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  {/* Version history - mock for now, would connect to a versions table */}
                  <div className="space-y-3">
                    {[
                      { version: '3.0', date: new Date().toISOString(), author: 'النظام', status: 'current' as const },
                      { version: '2.1', date: new Date(Date.now() - 86400000 * 2).toISOString(), author: 'أحمد محمد', status: 'archived' as const },
                      { version: '2.0', date: new Date(Date.now() - 86400000 * 7).toISOString(), author: 'أحمد محمد', status: 'archived' as const },
                      { version: '1.0', date: new Date(Date.now() - 86400000 * 30).toISOString(), author: 'النظام', status: 'initial' as const },
                    ].map((ver, idx) => (
                      <div
                        key={ver.version}
                        className={cn(
                          'flex items-center justify-between p-3 rounded-lg border transition-colors',
                          ver.status === 'current' ? 'bg-primary/5 border-primary/20' : 'hover:bg-muted/50'
                        )}
                      >
                        <div className="flex items-center gap-3">
                          <div className={cn(
                            'w-8 h-8 rounded-lg flex items-center justify-center text-xs font-bold',
                            ver.status === 'current' ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground'
                          )}>
                            v{ver.version}
                          </div>
                          <div>
                            <p className="text-sm font-medium">
                              الإصدار {ver.version}
                              {ver.status === 'current' && (
                                <Badge variant="outline" className="text-[9px] mr-2">حالي</Badge>
                              )}
                            </p>
                            <p className="text-xs text-muted-foreground">
                              {formatDate(ver.date)} — {ver.author}
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center gap-1">
                          {ver.status !== 'current' && (
                            <Button variant="ghost" size="sm" className="text-xs gap-1">
                              <GitBranch className="w-3 h-3" />
                              استعادة
                            </Button>
                          )}
                          <Button variant="ghost" size="sm" className="text-xs">
                            <Eye className="w-3 h-3" />
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </TabsContent>
          </div>
        </Tabs>

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
