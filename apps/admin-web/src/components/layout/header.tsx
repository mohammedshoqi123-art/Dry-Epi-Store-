import { Bell, Search, RefreshCw } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { useDashboardStats } from '@/hooks/useApi'

interface HeaderProps {
  title: string
  subtitle?: string
  onRefresh?: () => void
}

export function Header({ title, subtitle, onRefresh }: HeaderProps) {
  const { data: stats } = useDashboardStats()

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between gap-4 px-6 py-4 bg-background/80 backdrop-blur-md border-b">
      <div className="flex-1 min-w-0">
        <h1 className="text-2xl font-heading font-bold truncate">{title}</h1>
        {subtitle && <p className="text-sm text-muted-foreground mt-0.5">{subtitle}</p>}
      </div>

      <div className="flex items-center gap-3">
        {/* Search (desktop only) */}
        <div className="hidden md:block relative">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="بحث سريع..."
            className="w-64 pr-10 h-9 bg-muted/50 border-0"
          />
        </div>

        {/* Refresh */}
        <Button variant="ghost" size="icon-sm" onClick={onRefresh}>
          <RefreshCw className="w-4 h-4" />
        </Button>

        {/* Notifications */}
        <Button variant="ghost" size="icon-sm" className="relative">
          <Bell className="w-4 h-4" />
          {stats?.unread_notifications ? (
            <span className="absolute -top-1 -left-1 w-4 h-4 rounded-full bg-red-500 text-white text-[9px] flex items-center justify-center font-bold">
              {stats.unread_notifications > 9 ? '9+' : stats.unread_notifications}
            </span>
          ) : null}
        </Button>
      </div>
    </header>
  )
}
