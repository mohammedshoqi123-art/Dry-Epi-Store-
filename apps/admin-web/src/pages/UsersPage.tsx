import { useState } from 'react'
import {
  Search, Plus, Filter, MoreVertical, UserCheck, UserX, Trash2,
  Edit, Eye, Download, ChevronDown, Mail, MapPin, AlertTriangle, RefreshCw
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Skeleton } from '@/components/ui/skeleton'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator } from '@/components/ui/dropdown-menu'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Header } from '@/components/layout/header'
import { useUsers, useCreateUser, useUpdateUserRole, useToggleUserActive, useDeleteUser, useGovernorates, useDistricts } from '@/hooks/useApi'
import { ROLE_LABELS, ROLE_COLORS, type UserRole, type UserProfile } from '@/types/database'
import { formatRelativeTime, getInitials, cn } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'

export default function UsersPage() {
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState<string>('all')
  const [createDialogOpen, setCreateDialogOpen] = useState(false)
  const [editUser, setEditUser] = useState<UserProfile | null>(null)
  const [deleteUser, setDeleteUser] = useState<UserProfile | null>(null)

  const { data: users, isLoading, isError, error, refetch } = useUsers({
    role: roleFilter !== 'all' ? (roleFilter as UserRole) : undefined,
    search: search || undefined,
  })

  return (
    <div className="page-enter">
      <Header title="إدارة المستخدمين" subtitle={`${users?.length || 0} مستخدم`} onRefresh={() => refetch()} />

      <div className="p-6 space-y-6">
        {/* Error State */}
        {isError && (
          <Card className="border-red-200 bg-red-50/50">
            <CardContent className="p-6 text-center">
              <AlertTriangle className="w-10 h-10 text-red-500 mx-auto mb-3" />
              <h3 className="font-bold text-red-700 mb-1">حدث خطأ في تحميل المستخدمين</h3>
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
            <Input
              placeholder="بحث بالاسم أو البريد..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pr-10"
            />
          </div>
          <Select value={roleFilter} onValueChange={setRoleFilter}>
            <SelectTrigger className="w-full sm:w-48">
              <SelectValue placeholder="كل الأدوار" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">كل الأدوار</SelectItem>
              {Object.entries(ROLE_LABELS).map(([key, label]) => (
                <SelectItem key={key} value={key}>{label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button onClick={() => setCreateDialogOpen(true)} className="gap-2">
            <Plus className="w-4 h-4" />
            إضافة مستخدم
          </Button>
        </div>

        {/* Users Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {isLoading
            ? Array.from({ length: 6 }).map((_, i) => (
                <Card key={i}><CardContent className="p-5"><Skeleton className="w-full h-32" /></CardContent></Card>
              ))
            : users?.map((user) => (
                <UserCard
                  key={user.id}
                  user={user}
                  onEdit={() => setEditUser(user)}
                  onDelete={() => setDeleteUser(user)}
                />
              ))
          }
        </div>

        {users?.length === 0 && !isLoading && (
          <div className="text-center py-12">
            <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center mx-auto mb-4">
              <Search className="w-8 h-8 text-muted-foreground" />
            </div>
            <p className="text-lg font-medium">لا توجد نتائج</p>
            <p className="text-sm text-muted-foreground mt-1">جرّب تغيير الفلاتر أو البحث</p>
          </div>
        )}
      </div>

      {/* Create User Dialog */}
      <CreateUserDialog open={createDialogOpen} onOpenChange={setCreateDialogOpen} />

      {/* Edit User Dialog */}
      {editUser && (
        <EditUserDialog user={editUser} open={!!editUser} onOpenChange={() => setEditUser(null)} />
      )}

      {/* Delete Confirmation */}
      {deleteUser && (
        <DeleteUserDialog user={deleteUser} open={!!deleteUser} onOpenChange={() => setDeleteUser(null)} />
      )}
    </div>
  )
}

function UserCard({ user, onEdit, onDelete }: { user: UserProfile; onEdit: () => void; onDelete: () => void }) {
  const toggleActive = useToggleUserActive()
  const { toast } = useToast()

  return (
    <Card className={cn(
      'group hover:shadow-card-hover transition-all duration-200',
      !user.is_active && 'opacity-60'
    )}>
      <CardContent className="p-5">
        <div className="flex items-start gap-4">
          <Avatar className="w-12 h-12">
            <AvatarFallback className={cn(
              'text-sm font-bold',
              user.is_active ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground'
            )}>
              {getInitials(user.full_name)}
            </AvatarFallback>
          </Avatar>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <h3 className="font-semibold truncate">{user.full_name}</h3>
              {!user.is_active && <Badge variant="outline" className="text-[10px]">معطّل</Badge>}
            </div>
            <p className="text-sm text-muted-foreground truncate flex items-center gap-1 mt-0.5">
              <Mail className="w-3 h-3" />
              {user.email}
            </p>
            {(user.governorates?.name_ar || user.districts?.name_ar) && (
              <p className="text-xs text-muted-foreground flex items-center gap-1 mt-0.5">
                <MapPin className="w-3 h-3" />
                {[user.governorates?.name_ar, user.districts?.name_ar].filter(Boolean).join(' - ')}
              </p>
            )}
          </div>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100">
                <MoreVertical className="w-4 h-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={onEdit}>
                <Edit className="w-4 h-4 ml-2" />
                تعديل
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => {
                toggleActive.mutate({ userId: user.id, isActive: !user.is_active }, {
                  onSuccess: () => toast({ title: user.is_active ? 'تم تعطيل الحساب' : 'تم تفعيل الحساب', variant: 'success' })
                })
              }}>
                {user.is_active ? <UserX className="w-4 h-4 ml-2" /> : <UserCheck className="w-4 h-4 ml-2" />}
                {user.is_active ? 'تعطيل' : 'تفعيل'}
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={onDelete} className="text-red-600 focus:text-red-600">
                <Trash2 className="w-4 h-4 ml-2" />
                حذف
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        <div className="mt-4 flex items-center justify-between">
          <Badge className={cn('text-xs border', ROLE_COLORS[user.role])}>
            {ROLE_LABELS[user.role]}
          </Badge>
          <span className="text-xs text-muted-foreground">
            {formatRelativeTime(user.created_at)}
          </span>
        </div>
      </CardContent>
    </Card>
  )
}

function CreateUserDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const [form, setForm] = useState({
    full_name: '', email: '', password: '', role: 'data_entry' as UserRole,
    governorate_id: '', district_id: '',
  })
  const createUser = useCreateUser()
  const { data: governorates } = useGovernorates()
  const { data: districts } = useDistricts(form.governorate_id)
  const { toast } = useToast()

  const handleSubmit = () => {
    if (!form.full_name || !form.email || !form.password) {
      toast({ title: 'جميع الحقول مطلوبة', variant: 'destructive' })
      return
    }
    createUser.mutate(form, {
      onSuccess: () => {
        toast({ title: 'تم إضافة المستخدم بنجاح', variant: 'success' })
        onOpenChange(false)
        setForm({ full_name: '', email: '', password: '', role: 'data_entry', governorate_id: '', district_id: '' })
      },
      onError: () => toast({ title: 'فشل إضافة المستخدم', variant: 'destructive' }),
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>إضافة مستخدم جديد</DialogTitle>
          <DialogDescription>أدخل بيانات المستخدم الجديد</DialogDescription>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-2">
            <Label>الاسم الكامل</Label>
            <Input value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} />
          </div>
          <div className="space-y-2">
            <Label>البريد الإلكتروني</Label>
            <Input type="email" dir="ltr" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
          </div>
          <div className="space-y-2">
            <Label>كلمة المرور</Label>
            <Input type="password" dir="ltr" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} />
          </div>
          <div className="space-y-2">
            <Label>الدور</Label>
            <Select value={form.role} onValueChange={(v) => setForm({ ...form, role: v as UserRole, governorate_id: '', district_id: '' })}>
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                {Object.entries(ROLE_LABELS).map(([key, label]) => (
                  <SelectItem key={key} value={key}>{label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          {form.role !== 'admin' && form.role !== 'central' && (
            <div className="space-y-2">
              <Label>المحافظة</Label>
              <Select value={form.governorate_id} onValueChange={(v) => setForm({ ...form, governorate_id: v, district_id: '' })}>
                <SelectTrigger><SelectValue placeholder="اختر المحافظة" /></SelectTrigger>
                <SelectContent>
                  {governorates?.map((g) => <SelectItem key={g.id} value={g.id}>{g.name_ar}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          )}
          {(form.role === 'district' || form.role === 'data_entry') && form.governorate_id && (
            <div className="space-y-2">
              <Label>المديرية</Label>
              <Select value={form.district_id} onValueChange={(v) => setForm({ ...form, district_id: v })}>
                <SelectTrigger><SelectValue placeholder="اختر المديرية" /></SelectTrigger>
                <SelectContent>
                  {districts?.map((d) => <SelectItem key={d.id} value={d.id}>{d.name_ar}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button onClick={handleSubmit} disabled={createUser.isPending}>
            {createUser.isPending ? 'جاري الإضافة...' : 'إضافة'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function EditUserDialog({ user, open, onOpenChange }: { user: UserProfile; open: boolean; onOpenChange: (v: boolean) => void }) {
  const [role, setRole] = useState<UserRole>(user.role)
  const [govId, setGovId] = useState(user.governorate_id || '')
  const [districtId, setDistrictId] = useState(user.district_id || '')
  const updateRole = useUpdateUserRole()
  const { data: governorates } = useGovernorates()
  const { data: districts } = useDistricts(govId)
  const { toast } = useToast()

  const handleSave = () => {
    updateRole.mutate({ userId: user.id, role, governorate_id: govId, district_id: districtId }, {
      onSuccess: () => {
        toast({ title: 'تم تحديث المستخدم', variant: 'success' })
        onOpenChange(false)
      },
      onError: () => toast({ title: 'فشل التحديث', variant: 'destructive' }),
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>تعديل: {user.full_name}</DialogTitle>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-2">
            <Label>الدور</Label>
            <Select value={role} onValueChange={(v) => { setRole(v as UserRole); setGovId(''); setDistrictId('') }}>
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                {Object.entries(ROLE_LABELS).map(([key, label]) => (
                  <SelectItem key={key} value={key}>{label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          {role !== 'admin' && role !== 'central' && (
            <div className="space-y-2">
              <Label>المحافظة</Label>
              <Select value={govId} onValueChange={(v) => { setGovId(v === 'none' ? '' : v); setDistrictId('') }}>
                <SelectTrigger><SelectValue placeholder="اختر" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">بدون</SelectItem>
                  {governorates?.map((g) => <SelectItem key={g.id} value={g.id}>{g.name_ar}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          )}
          {(role === 'district' || role === 'data_entry') && govId && (
            <div className="space-y-2">
              <Label>المديرية</Label>
              <Select value={districtId} onValueChange={(v) => setDistrictId(v === 'none' ? '' : v)}>
                <SelectTrigger><SelectValue placeholder="اختر" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">بدون</SelectItem>
                  {districts?.map((d) => <SelectItem key={d.id} value={d.id}>{d.name_ar}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button onClick={handleSave} disabled={updateRole.isPending}>
            {updateRole.isPending ? 'جاري الحفظ...' : 'حفظ'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function DeleteUserDialog({ user, open, onOpenChange }: { user: UserProfile; open: boolean; onOpenChange: (v: boolean) => void }) {
  const deleteUser = useDeleteUser()
  const { toast } = useToast()

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="text-red-600">حذف المستخدم</DialogTitle>
          <DialogDescription>
            هل أنت متأكد من حذف "{user.full_name}"؟ هذا الإجراء لا يمكن التراجع عنه.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>إلغاء</Button>
          <Button variant="destructive" onClick={() => {
            deleteUser.mutate(user.id, {
              onSuccess: () => {
                toast({ title: 'تم حذف المستخدم', variant: 'success' })
                onOpenChange(false)
              },
              onError: () => toast({ title: 'فشل الحذف', variant: 'destructive' }),
            })
          }} disabled={deleteUser.isPending}>
            {deleteUser.isPending ? 'جاري الحذف...' : 'حذف'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
