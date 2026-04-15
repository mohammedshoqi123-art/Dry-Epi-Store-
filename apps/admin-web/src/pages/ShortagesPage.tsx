import { useState } from 'react'
import { Search, AlertTriangle, CheckCircle2, MapPin, Calendar, User, Package } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Header } from '@/components/layout/header'
import { useShortages, useResolveShortage } from '@/hooks/useApi'
import { SEVERITY_LABELS, SEVERITY_COLORS, type ShortageSeverity } from '@/types/database'
import { formatRelativeTime, cn } from '@/lib/utils'
import { useToast } from '@/hooks/useToast'

export default function ShortagesPage() {
  const [severityFilter, setSeverityFilter] = useState<string>('')
  const [resolvedFilter, setResolvedFilter] = useState<string>('')
  const { data: shortages, isLoading, refetch } = useShortages()
  const resolveShortage = useResolveShortage()
  const { toast } = useToast()

  const filtered = shortages?.filter(s => {
    if (severityFilter && s.severity !== severityFilter) return false
    if (resolvedFilter === 'resolved' && !s.is_resolved) return false
    if (resolvedFilter === 'pending' && s.is_resolved) return false
    return true
  })

  const criticalCount = shortages?.filter(s => s.severity === 'critical' && !s.is_resolved).length || 0

  return (
    <div className="page-enter">
      <Header title="تتبع النواقص" subtitle={`${criticalCount} نقص حرج`} onRefresh={() => refetch()} />

      <div className="p-6 space-y-6">
        {/* Filters */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <Select value={severityFilter} onValueChange={setSeverityFilter}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="كل الشدات" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="">كل الشدات</SelectItem>
              {Object.entries(SEVERITY_LABELS).map(([key, label]) => (
                <SelectItem key={key} value={key}>{label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select value={resolvedFilter} onValueChange={setResolvedFilter}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="كل الحالات" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="">كل الحالات</SelectItem>
              <SelectItem value="pending">قيد الانتظار</SelectItem>
              <SelectItem value="resolved">تم الحل</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {/* Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {isLoading
            ? Array.from({ length: 6 }).map((_, i) => (
                <Card key={i}><CardContent className="p-5"><Skeleton className="w-full h-36" /></CardContent></Card>
              ))
            : filtered?.map((shortage) => (
                <Card key={shortage.id} className={cn(
                  'hover:shadow-card-hover transition-all',
                  shortage.is_resolved && 'opacity-60'
                )}>
                  <CardContent className="p-5">
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <div className={cn(
                          'p-2 rounded-lg',
                          shortage.severity === 'critical' ? 'bg-red-100' :
                          shortage.severity === 'high' ? 'bg-orange-100' :
                          shortage.severity === 'medium' ? 'bg-yellow-100' : 'bg-green-100'
                        )}>
                          <AlertTriangle className={cn(
                            'w-5 h-5',
                            shortage.severity === 'critical' ? 'text-red-600' :
                            shortage.severity === 'high' ? 'text-orange-600' :
                            shortage.severity === 'medium' ? 'text-yellow-600' : 'text-green-600'
                          )} />
                        </div>
                        <div>
                          <h3 className="font-bold text-sm">{shortage.item_name}</h3>
                          {shortage.item_category && (
                            <p className="text-xs text-muted-foreground">{shortage.item_category}</p>
                          )}
                        </div>
                      </div>
                      <Badge className={cn('text-xs border', SEVERITY_COLORS[shortage.severity as ShortageSeverity] || 'bg-gray-100 text-gray-700')}>
                        {SEVERITY_LABELS[shortage.severity as ShortageSeverity] || shortage.severity}
                      </Badge>
                    </div>

                    <div className="space-y-2 text-sm">
                      {shortage.quantity_needed !== undefined && (
                        <div className="flex items-center gap-2 text-muted-foreground">
                          <Package className="w-3.5 h-3.5" />
                          <span>مطلوب: {shortage.quantity_needed} {shortage.unit} | متوفر: {shortage.quantity_available}</span>
                        </div>
                      )}
                      {(shortage.governorates?.name_ar || shortage.districts?.name_ar) && (
                        <div className="flex items-center gap-2 text-muted-foreground">
                          <MapPin className="w-3.5 h-3.5" />
                          <span>{[shortage.governorates?.name_ar, shortage.districts?.name_ar].filter(Boolean).join(' - ')}</span>
                        </div>
                      )}
                      <div className="flex items-center gap-2 text-muted-foreground">
                        <Calendar className="w-3.5 h-3.5" />
                        <span>{formatRelativeTime(shortage.created_at)}</span>
                      </div>
                    </div>

                    {shortage.notes && (
                      <p className="text-xs text-muted-foreground mt-3 p-2 bg-muted rounded-md">{shortage.notes}</p>
                    )}

                    <div className="flex items-center justify-between mt-4 pt-3 border-t">
                      <span className="text-xs text-muted-foreground">
                        {shortage.profiles?.full_name || '—'}
                      </span>
                      {shortage.is_resolved ? (
                        <Badge variant="success" className="text-[10px] gap-1">
                          <CheckCircle2 className="w-3 h-3" /> تم الحل
                        </Badge>
                      ) : (
                        <Button
                          variant="outline"
                          size="sm"
                          className="text-xs h-7"
                          onClick={() => resolveShortage.mutate(shortage.id, {
                            onSuccess: () => toast({ title: 'تم تحديد النقص كمحلول', variant: 'success' }),
                          })}
                          disabled={resolveShortage.isPending}
                        >
                          تحديد كمحلول
                        </Button>
                      )}
                    </div>
                  </CardContent>
                </Card>
              ))
          }
        </div>
      </div>
    </div>
  )
}
