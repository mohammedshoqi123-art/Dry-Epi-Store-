import { useState } from 'react'
import {
  Search, Plus, MoreVertical, Edit, Eye, ToggleLeft, ToggleRight,
  FileText, Users, MapPin, Globe, Smartphone, Shield
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Switch } from '@/components/ui/switch'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from '@/components/ui/dropdown-menu'
import { Header } from '@/components/layout/header'
import { useForms, useUpdateForm } from '@/hooks/useApi'
import { ROLE_LABELS, type Form } from '@/types/database'
import { formatDate, cn } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'

export default function FormsPage() {
  const [search, setSearch] = useState('')
  const { data: forms, isLoading, refetch } = useForms()
  const { toast } = useToast()

  const filteredForms = forms?.filter(f =>
    f.title_ar.includes(search) || f.title_en.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="page-enter">
      <Header title="إدارة النماذج" subtitle={`${forms?.length || 0} نموذج`} onRefresh={() => refetch()} />

      <div className="p-6 space-y-6">
        {/* Actions Bar */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input placeholder="بحث في النماذج..." value={search} onChange={(e) => setSearch(e.target.value)} className="pr-10" />
          </div>
          <Button className="gap-2">
            <Plus className="w-4 h-4" />
            نموذج جديد
          </Button>
        </div>

        {/* Forms Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {isLoading
            ? Array.from({ length: 6 }).map((_, i) => (
                <Card key={i}><CardContent className="p-5"><Skeleton className="w-full h-40" /></CardContent></Card>
              ))
            : filteredForms?.map((form) => <FormCard key={form.id} form={form} />)
          }
        </div>
      </div>
    </div>
  )
}

function FormCard({ form }: { form: Form }) {
  const updateForm = useUpdateForm()
  const { toast } = useToast()

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
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-primary/10">
              <FileText className="w-6 h-6 text-primary" />
            </div>
            <div>
              <h3 className="font-bold font-heading">{form.title_ar}</h3>
              <p className="text-xs text-muted-foreground">{form.title_en}</p>
            </div>
          </div>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100">
                <MoreVertical className="w-4 h-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem><Eye className="w-4 h-4 ml-2" />عرض</DropdownMenuItem>
              <DropdownMenuItem><Edit className="w-4 h-4 ml-2" />تعديل</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>

        {form.description_ar && (
          <p className="text-sm text-muted-foreground mb-4 line-clamp-2">{form.description_ar}</p>
        )}

        {/* Tags */}
        <div className="flex flex-wrap gap-1.5 mb-4">
          {form.requires_gps && (
            <Badge variant="outline" className="text-[10px] gap-1">
              <MapPin className="w-3 h-3" /> GPS
            </Badge>
          )}
          {form.requires_photo && (
            <Badge variant="outline" className="text-[10px] gap-1">
              <Smartphone className="w-3 h-3" /> صور
            </Badge>
          )}
          <Badge variant="outline" className="text-[10px] gap-1">
            v{form.version}
          </Badge>
        </div>

        {/* Allowed Roles */}
        <div className="mb-4">
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
