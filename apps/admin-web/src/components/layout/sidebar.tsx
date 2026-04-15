import { useState, useEffect } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { cn } from '@/lib/utils'
import {
  LayoutDashboard, Users, FileText, FileStack, BarChart3, ScrollText,
  MapPin, Shield, ChevronLeft, ChevronRight, Settings, LogOut,
  AlertTriangle, Bell, Moon, Sun, Menu, X, Sparkles, Layout, Clock,
  MessageSquare, Brain, BookOpen
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Separator } from '@/components/ui/separator'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { useTheme } from './theme-provider'
import { useSignOut, useDashboardStats } from '@/hooks/useApi'
import { ROLE_LABELS, type UserRole } from '@/types/database'
import { getInitials } from '@/lib/utils'

// Helper to get logo URL with base path support
function getLogoUrl(size: '64' | '128' | '256' = '128') {
  const base = import.meta.env.BASE_URL || '/'
  return `${base}logo-epi-${size}.png`.replace(/\/+/g, '/')
}

interface SidebarProps {
  user?: { full_name: string; email: string; role: UserRole } | null
  collapsed?: boolean
  onToggle?: () => void
}

interface NavItem {
  icon: React.ElementType
  label: string
  href: string
  badge?: number
  roles?: UserRole[]
}

const navItems: NavItem[] = [
  { icon: LayoutDashboard, label: 'لوحة التحكم', href: '/dashboard' },
  { icon: Sparkles, label: 'الرؤى الذكية AI', href: '/insights' },
  { icon: Brain, label: 'إعدادات الذكاء الاصطناعي', href: '/ai-settings', roles: ['admin'] },
  { icon: Users, label: 'المستخدمون', href: '/users' },
  { icon: FileText, label: 'النماذج', href: '/forms' },
  { icon: FileStack, label: 'الإرساليات', href: '/submissions' },
  { icon: BarChart3, label: 'التحليلات', href: '/analytics' },
  { icon: AlertTriangle, label: 'النواقص', href: '/shortages' },
  { icon: ScrollText, label: 'سجل التدقيق', href: '/audit', roles: ['admin', 'central'] },
  { icon: MapPin, label: 'المحافظات', href: '/governorates', roles: ['admin'] },
  { icon: Layout, label: 'إدارة الصفحات', href: '/pages', roles: ['admin'] },
  { icon: BookOpen, label: 'المراجع والكتب', href: '/references' },
  { icon: MessageSquare, label: 'الشات الداخلي', href: '/chat' },
  { icon: Bell, label: 'الإشعارات', href: '/notifications' },
  { icon: Settings, label: 'الإعدادات', href: '/settings', roles: ['admin'] },
]

function LiveClock({ collapsed }: { collapsed: boolean }) {
  const [time, setTime] = useState(new Date())
  useEffect(() => {
    const interval = setInterval(() => setTime(new Date()), 1000)
    return () => clearInterval(interval)
  }, [])

  const timeStr = time.toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true })
  const dateStr = time.toLocaleDateString('ar-SA', { weekday: 'short', day: 'numeric', month: 'short' })

  if (collapsed) return null

  return (
    <div className="px-4 py-2 text-center">
      <div className="flex items-center justify-center gap-1.5 text-xs text-muted-foreground">
        <Clock className="w-3 h-3" />
        <span className="font-mono tabular-nums">{timeStr}</span>
      </div>
      <p className="text-[10px] text-muted-foreground/60 mt-0.5">{dateStr}</p>
    </div>
  )
}

export function Sidebar({ user, collapsed = false, onToggle }: SidebarProps) {
  const location = useLocation()
  const { theme, setTheme } = useTheme()
  const signOut = useSignOut()
  const { data: stats } = useDashboardStats()

  const filteredItems = navItems.filter(item => {
    if (!item.roles) return true
    return user?.role && item.roles.includes(user.role)
  })

  // Add dynamic badges
  const itemsWithBadges = filteredItems.map(item => {
    if (item.href === '/submissions' && stats?.pending_submissions) {
      return { ...item, badge: stats.pending_submissions }
    }
    if (item.href === '/shortages' && stats?.critical_shortages) {
      return { ...item, badge: stats.critical_shortages }
    }
    return item
  })

  return (
    <aside
      className={cn(
        'flex flex-col h-screen border-l transition-all duration-300 relative z-30',
        collapsed ? 'w-[72px]' : 'w-[280px]'
      )}
      style={{
        background: 'linear-gradient(180deg, #1d4ed8 0%, #2563eb 40%, #1e40af 100%)',
        color: '#fff',
        borderColor: 'rgba(255,255,255,0.15)',
        backdropFilter: 'none',
      }}
    >
      {/* Header */}
      <div className="flex items-center gap-3 p-4 h-16">
        {!collapsed && (
          <>
            <div className="flex items-center justify-center w-10 h-10 rounded-xl bg-white shadow-sm overflow-hidden border border-blue-100/50">
              <img
                src={getLogoUrl('128')}
                alt="EPI"
                className="w-8 h-8 object-contain"
                onError={(e) => {
                  e.currentTarget.style.display = 'none'
                  const p = e.currentTarget.parentElement!
                  p.innerHTML = '<div class="w-8 h-8 rounded-lg bg-gradient-to-br from-blue-600 to-blue-800"></div>'
                }}
              />
            </div>
            <div className="flex-1 min-w-0">
              <h1 className="font-heading font-bold text-lg text-white truncate">EPI Supervisor's</h1>
              <p className="text-xs text-blue-100">المشرف — لوحة الإدارة</p>
            </div>
          </>
        )}
        {collapsed && (
          <div className="flex items-center justify-center w-10 h-10 rounded-xl bg-white shadow-sm overflow-hidden border border-blue-100/50 mx-auto">
            <img
              src={getLogoUrl('64')}
              alt="EPI"
              className="w-8 h-8 object-contain"
              onError={(e) => {
                e.currentTarget.style.display = 'none'
                const p = e.currentTarget.parentElement!
                p.innerHTML = '<div class="w-8 h-8 rounded-lg bg-gradient-to-br from-blue-600 to-blue-800"></div>'
              }}
            />
          </div>
        )}
        <Button
          variant="ghost"
          size="icon-sm"
          onClick={onToggle}
          className="hidden lg:flex text-blue-200 hover:text-white hover:bg-white/10"
        >
          {collapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
        </Button>
      </div>

      <Separator className="bg-white/10" />

      {/* Navigation */}
      <ScrollArea className="flex-1 py-2">
        <nav className="px-3 space-y-1">
          {itemsWithBadges.map((item) => {
            const isActive = location.pathname === item.href ||
              (item.href !== '/' && location.pathname.startsWith(item.href))
            const Icon = item.icon

            return (
              <Link
                key={item.href}
                to={item.href}
                className={cn(
                  'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-all duration-200 relative group',
                  isActive
                    ? 'bg-white/20 text-white shadow-md shadow-black/10'
                    : 'text-blue-100 hover:bg-white/10 hover:text-white',
                  collapsed && 'justify-center px-0'
                )}
              >
                {isActive && !collapsed && (
                  <div className="absolute right-0 top-1/2 -translate-y-1/2 w-1 h-6 bg-white rounded-l-full" />
                )}
                <Icon className={cn('w-5 h-5 shrink-0', collapsed && 'w-5 h-5')} />
                {!collapsed && <span className="flex-1">{item.label}</span>}
                {!collapsed && item.badge && item.badge > 0 && (
                  <Badge
                    variant={item.badge > 5 ? 'destructive' : 'warning'}
                    className="text-[10px] px-1.5 py-0"
                  >
                    {item.badge}
                  </Badge>
                )}
                {collapsed && item.badge && item.badge > 0 && (
                  <span className="absolute top-1 left-1 w-2 h-2 rounded-full bg-red-500" />
                )}
                {collapsed && (
                  <div className="absolute right-full ml-2 px-2 py-1 bg-white text-gray-900 text-xs rounded-md shadow-lg opacity-0 group-hover:opacity-100 pointer-events-none transition-opacity whitespace-nowrap z-50">
                    {item.label}
                  </div>
                )}
              </Link>
            )
          })}
        </nav>
      </ScrollArea>

      <Separator className="bg-white/10" />

      {/* Live Clock */}
      <LiveClock collapsed={collapsed} />

      <Separator className="bg-white/10" />

      {/* Theme Toggle */}
      <div className="px-3 py-2">
        <Button
          variant="ghost"
          size={collapsed ? 'icon' : 'default'}
          className={cn('w-full text-blue-100 hover:text-white hover:bg-white/10', collapsed ? '' : 'justify-start gap-3')}
          onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
        >
          {theme === 'dark' ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
          {!collapsed && <span>{theme === 'dark' ? 'الوضع الفاتح' : 'الوضع الداكن'}</span>}
        </Button>
      </div>

      {/* User Info / Login */}
      <div className="p-3 border-t border-white/10">
        {user ? (
          <div className={cn('flex items-center gap-3', collapsed && 'justify-center')}>
            <Avatar className="w-9 h-9">
              <AvatarFallback className="bg-white/20 text-white text-sm font-bold">
                {getInitials(user.full_name)}
              </AvatarFallback>
            </Avatar>
            {!collapsed && (
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate text-white">{user.full_name}</p>
                <p className="text-xs text-blue-200 truncate">
                  {ROLE_LABELS[user.role]}
                </p>
              </div>
            )}
            <Button
              variant="ghost"
              size={collapsed ? 'icon' : 'icon-sm'}
              onClick={() => signOut.mutate()}
              className="text-blue-200 hover:text-white hover:bg-white/10"
              title="تسجيل الخروج"
            >
              <LogOut className="w-4 h-4" />
            </Button>
          </div>
        ) : (
          <Link
            to="/login"
            className={cn(
              'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-blue-100 hover:bg-white/10 hover:text-white transition-colors',
              collapsed && 'justify-center px-0'
            )}
          >
            <LogOut className="w-5 h-5 rotate-180" />
            {!collapsed && <span>تسجيل الدخول</span>}
          </Link>
        )}
      </div>
    </aside>
  )
}

// Mobile sidebar (overlay)
export function MobileSidebar({ user }: { user?: { full_name: string; email: string; role: UserRole } | null }) {
  const [open, setOpen] = useState(false)
  const location = useLocation()

  // Close on route change
  useEffect(() => {
    setOpen(false)
  }, [location.pathname])

  const filteredItems = navItems.filter(item => {
    if (!item.roles) return true
    return user?.role && item.roles.includes(user.role)
  })

  return (
    <>
      <Button variant="ghost" size="icon" className="lg:hidden" onClick={() => setOpen(true)}>
        <Menu className="w-5 h-5" />
      </Button>

      {open && (
        <div className="mobile-sidebar-overlay lg:hidden">
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm" style={{ zIndex: 9998 }} onClick={() => setOpen(false)} />
          <div
            className="fixed inset-y-0 right-0 w-[280px] shadow-2xl animate-slide-in-right"
            style={{ background: 'linear-gradient(180deg, #1d4ed8 0%, #2563eb 40%, #1e40af 100%)', color: '#fff', zIndex: 9999 }}
          >
            <div className="flex items-center justify-between p-4">
              <div className="flex items-center gap-3">
                <div className="flex items-center justify-center w-10 h-10 rounded-xl bg-white shadow-sm overflow-hidden border border-blue-100/50">
                  <img src={getLogoUrl('64')} alt="EPI" className="w-8 h-8 object-contain"
                    onError={(e) => { e.currentTarget.style.display = 'none' }} />
                </div>
                <h1 className="font-heading font-bold text-lg text-white">EPI Supervisor's</h1>
              </div>
              <Button variant="ghost" size="icon-sm" onClick={() => setOpen(false)} className="text-blue-200 hover:text-white hover:bg-white/10">
                <X className="w-5 h-5" />
              </Button>
            </div>
            <Separator className="bg-white/10" />
            <nav className="px-3 py-4 space-y-1">
              {filteredItems.map((item) => {
                const isActive = location.pathname === item.href
                const Icon = item.icon
                return (
                  <Link
                    key={item.href}
                    to={item.href}
                    onClick={() => setOpen(false)}
                    className={cn(
                      'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
                      isActive ? 'bg-white/20 text-white shadow-md' : 'text-blue-100 hover:bg-white/10 hover:text-white'
                    )}
                  >
                    <Icon className="w-5 h-5" />
                    <span>{item.label}</span>
                    {item.badge && item.badge > 0 && (
                      <Badge variant="destructive" className="mr-auto text-[10px]">{item.badge}</Badge>
                    )}
                  </Link>
                )
              })}
            </nav>
          </div>
        </div>
      )}
    </>
  )
}
