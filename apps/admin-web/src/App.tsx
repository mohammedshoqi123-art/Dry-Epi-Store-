import { Routes, Route, Navigate } from 'react-router-dom'
import { TooltipProvider } from '@/components/ui/tooltip'
import { AppLayout } from '@/components/layout/app-layout'
import { AIChatWidget } from '@/components/ai/AIChatWidget'
import LoginPage from '@/pages/LoginPage'
import DashboardPage from '@/pages/DashboardPage'
import UsersPage from '@/pages/UsersPage'
import FormsPage from '@/pages/FormsPage'
import SubmissionsPage from '@/pages/SubmissionsPage'
import AnalyticsPage from '@/pages/AnalyticsPage'
import AIInsightsPage from '@/pages/AIInsightsPage'
import AuditPage from '@/pages/AuditPage'
import ShortagesPage from '@/pages/ShortagesPage'
import GovernoratesPage from '@/pages/GovernoratesPage'
import PagesManagementPage from '@/pages/PagesManagementPage'
import SettingsPage from '@/pages/SettingsPage'

export default function App() {
  return (
    <TooltipProvider>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route element={<AppLayoutWithAI />}>
          <Route index element={<DashboardPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="forms" element={<FormsPage />} />
          <Route path="submissions" element={<SubmissionsPage />} />
          <Route path="analytics" element={<AnalyticsPage />} />
          <Route path="insights" element={<AIInsightsPage />} />
          <Route path="audit" element={<AuditPage />} />
          <Route path="shortages" element={<ShortagesPage />} />
          <Route path="governorates" element={<GovernoratesPage />} />
          <Route path="pages" element={<PagesManagementPage />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </TooltipProvider>
  )
}

// Layout with AI Chat Widget
import { Outlet, Navigate as Nav } from 'react-router-dom'
import { useState } from 'react'
import { Sidebar, MobileSidebar } from '@/components/layout/sidebar'
import { useAuth } from '@/hooks/useApi'
import { Skeleton } from '@/components/ui/skeleton'
import { isConfigured } from '@/lib/supabase'

function AppLayoutWithAI() {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const { data: authData, isLoading } = useAuth()

  if (!isConfigured) {
    return <Nav to="/login" replace />
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
    return <Nav to="/login" replace />
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
          <h1 className="font-heading font-bold text-lg">EPI Supervisor's <span className="text-xs text-muted-foreground font-normal">المشرف</span></h1>
        </div>

        {/* Page Content */}
        <main className="flex-1 overflow-auto">
          <Outlet />
        </main>
      </div>

      {/* AI Chat Widget */}
      <AIChatWidget />
    </div>
  )
}
