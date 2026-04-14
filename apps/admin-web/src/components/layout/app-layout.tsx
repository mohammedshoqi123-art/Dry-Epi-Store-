import { useState } from 'react'
import { Outlet, Navigate } from 'react-router-dom'
import { Sidebar, MobileSidebar } from './sidebar'
import { Header } from './header'
import { useAuth } from '@/hooks/useApi'
import { Skeleton } from '@/components/ui/skeleton'
import { isConfigured } from '@/lib/supabase'

export function AppLayout() {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const { data: authData, isLoading } = useAuth()

  if (!isConfigured) {
    return <Navigate to="/login" replace />
  }

  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center bg-background">
        <div className="flex flex-col items-center gap-4">
          <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center animate-pulse">
            <div className="w-8 h-8 rounded-lg bg-primary/30" />
          </div>
          <Skeleton className="w-32 h-4" />
        </div>
      </div>
    )
  }

  if (!authData?.session) {
    return <Navigate to="/login" replace />
  }

  const user = authData.profile

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      {/* Desktop Sidebar */}
      <div className="hidden lg:block">
        <Sidebar
          user={user}
          collapsed={sidebarCollapsed}
          onToggle={() => setSidebarCollapsed(!sidebarCollapsed)}
        />
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Mobile Header */}
        <div className="lg:hidden flex items-center gap-3 px-4 py-3 border-b bg-background/80 backdrop-blur-md">
          <MobileSidebar user={user} />
          <h1 className="font-heading font-bold text-lg">مشرف EPI</h1>
        </div>

        {/* Page Content */}
        <main className="flex-1 overflow-auto">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
