import { useState } from 'react'
import { Outlet, Navigate } from 'react-router-dom'
import { Sidebar, MobileSidebar } from './sidebar'
import { useAuth } from '@/hooks/useApi'
import { Skeleton } from '@/components/ui/skeleton'
import { isConfigured } from '@/lib/supabase'
import { AIChatWidget } from '@/components/ai/AIChatWidget'

export function AppLayout() {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const { data: authData, isLoading } = useAuth()

  if (!isConfigured) {
    return <Navigate to="/login" replace />
  }

  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center bg-gradient-to-br from-blue-50 via-white to-indigo-50">
        <div className="flex flex-col items-center gap-5">
          <div className="relative">
            <div className="w-20 h-20 rounded-2xl bg-white shadow-xl shadow-blue-500/10 flex items-center justify-center animate-pulse border border-blue-100/50">
              <img
                src={`${import.meta.env.BASE_URL}logo-epi-256.png`.replace(/\/+/g, '/')}
                alt="EPI"
                className="w-14 h-14 object-contain"
                onError={(e) => {
                  e.currentTarget.style.display = 'none'
                  e.currentTarget.parentElement!.innerHTML = '<div class="w-14 h-14 rounded-xl bg-gradient-to-br from-blue-600 to-blue-800 animate-pulse"></div>'
                }}
              />
            </div>
            <div className="absolute inset-0 rounded-2xl bg-blue-400/20 blur-xl -z-10 scale-110" />
          </div>
          <div className="text-center space-y-2">
            <Skeleton className="w-40 h-5 mx-auto" />
            <Skeleton className="w-24 h-3 mx-auto" />
          </div>
          <div className="flex items-center gap-1.5">
            <div className="w-2 h-2 rounded-full bg-blue-500 animate-bounce" style={{ animationDelay: '0ms' }} />
            <div className="w-2 h-2 rounded-full bg-blue-400 animate-bounce" style={{ animationDelay: '150ms' }} />
            <div className="w-2 h-2 rounded-full bg-blue-300 animate-bounce" style={{ animationDelay: '300ms' }} />
          </div>
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
        <div className="lg:hidden flex items-center gap-3 px-4 py-3 border-b bg-background/80 backdrop-blur-md sticky top-0 z-40">
          <MobileSidebar user={user} />
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-white shadow-sm overflow-hidden border border-blue-100/50 flex items-center justify-center">
              <img
                src={`${import.meta.env.BASE_URL}logo-epi-64.png`.replace(/\/+/g, '/')}
                alt="EPI"
                className="w-6 h-6 object-contain"
                onError={(e) => { e.currentTarget.style.display = 'none' }}
              />
            </div>
            <h1 className="font-heading font-bold text-lg">
              <span className="text-blue-600">EPI</span> Supervisor's
            </h1>
          </div>
        </div>

        {/* Page Content */}
        <main className="flex-1 overflow-auto scroll-smooth">
          <Outlet />
        </main>
      </div>

      {/* AI Chat Widget */}
      <AIChatWidget />
    </div>
  )
}
