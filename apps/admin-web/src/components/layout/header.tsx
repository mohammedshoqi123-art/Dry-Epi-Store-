import { useState, useEffect } from 'react'
import { Bell, Search, RefreshCw, Clock } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { useDashboardStats } from '@/hooks/useApi'

interface HeaderProps {
  title: string
  subtitle?: string
  onRefresh?: () => void
}

export function Header({ title, subtitle, onRefresh }: HeaderProps) {
  const { data: stats } = useDashboardStats()
  const [time, setTime] = useState(new Date())

  useEffect(() => {
    const interval = setInterval(() => setTime(new Date()), 60000)
    return () => clearInterval(interval)
  }, [])

  const timeStr = time.toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit', hour12: true })

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between gap-4 px-6 py-4 bg-background/80 backdrop-blur-xl border-b">
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-heading font-bold truncate">{title}</h1>
          <div className="hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-50 border border-emerald-200/60">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
            <span className="text-[10px] font-medium text-emerald-700">مباشر</span>
          </div>
        </div>
        {subtitle && <p className="text-sm text-muted-foreground mt-0.5">{subtitle}</p>}
      </div>

      <div className="flex items-center gap-3">
        {/* Clock */}
        <div className="hidden md:flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-muted/50 text-xs text-muted-foreground">
          <Clock className="w-3.5 h-3.5" />
          <span className="font-mono tabular-nums">{timeStr}</span>
        </div>

        {/* Search (desktop only) */}
        <div className="hidden md:block relative">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="بحث سريع..."
            className="w-64 pr-10 h-9 bg-muted/50 border-0 focus:bg-muted/80 transition-colors"
          />
        </div>

        {/* Refresh */}
        <Button variant="ghost" size="icon-sm" onClick={onRefresh} className="hover:bg-primary/10 hover:text-primary transition-colors">
          <RefreshCw className="w-4 h-4" />
        </Button>

        {/* Notifications */}
        <Button variant="ghost" size="icon-sm" className="relative hover:bg-primary/10 hover:text-primary transition-colors">
          <Bell className="w-4 h-4" />
          {stats?.unread_notifications ? (
            <span className="absolute -top-1 -left-1 w-4 h-4 rounded-full bg-red-500 text-white text-[9px] flex items-center justify-center font-bold animate-bounce">
              {stats.unread_notifications > 9 ? '9+' : stats.unread_notifications}
            </span>
          ) : null}
        </Button>
      </div>
    </header>
  )
}
