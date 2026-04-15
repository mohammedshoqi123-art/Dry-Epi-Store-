import { lazy, Suspense } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import { TooltipProvider } from '@/components/ui/tooltip'
import { AppLayout } from '@/components/layout/app-layout'
import LoginPage from '@/pages/LoginPage'

// Lazy load pages for better performance
const DashboardPage = lazy(() => import('@/pages/DashboardPage'))
const UsersPage = lazy(() => import('@/pages/UsersPage'))
const FormsPage = lazy(() => import('@/pages/FormsPage'))
const SubmissionsPage = lazy(() => import('@/pages/SubmissionsPage'))
const AnalyticsPage = lazy(() => import('@/pages/AnalyticsPage'))
const AIInsightsPage = lazy(() => import('@/pages/AIInsightsPage'))
const AISettingsPage = lazy(() => import('@/pages/AISettingsPage'))
const AuditPage = lazy(() => import('@/pages/AuditPage'))
const ShortagesPage = lazy(() => import('@/pages/ShortagesPage'))
const GovernoratesPage = lazy(() => import('@/pages/GovernoratesPage'))
const PagesManagementPage = lazy(() => import('@/pages/PagesManagementPage'))
const SettingsPage = lazy(() => import('@/pages/SettingsPage'))
const ChatPage = lazy(() => import('@/pages/ChatPage'))
const NotificationsPage = lazy(() => import('@/pages/NotificationsPage'))

function PageLoader() {
  return (
    <div className="flex h-full items-center justify-center">
      <div className="flex flex-col items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-primary/10 animate-pulse flex items-center justify-center">
          <div className="w-5 h-5 rounded-md bg-primary/30" />
        </div>
        <p className="text-sm text-muted-foreground animate-pulse">جاري التحميل...</p>
      </div>
    </div>
  )
}

export default function App() {
  return (
    <TooltipProvider>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route element={<AppLayout />}>
          <Route index element={<Suspense fallback={<PageLoader />}><DashboardPage /></Suspense>} />
          <Route path="users" element={<Suspense fallback={<PageLoader />}><UsersPage /></Suspense>} />
          <Route path="forms" element={<Suspense fallback={<PageLoader />}><FormsPage /></Suspense>} />
          <Route path="submissions" element={<Suspense fallback={<PageLoader />}><SubmissionsPage /></Suspense>} />
          <Route path="analytics" element={<Suspense fallback={<PageLoader />}><AnalyticsPage /></Suspense>} />
          <Route path="insights" element={<Suspense fallback={<PageLoader />}><AIInsightsPage /></Suspense>} />
          <Route path="ai-settings" element={<Suspense fallback={<PageLoader />}><AISettingsPage /></Suspense>} />
          <Route path="audit" element={<Suspense fallback={<PageLoader />}><AuditPage /></Suspense>} />
          <Route path="shortages" element={<Suspense fallback={<PageLoader />}><ShortagesPage /></Suspense>} />
          <Route path="governorates" element={<Suspense fallback={<PageLoader />}><GovernoratesPage /></Suspense>} />
          <Route path="pages" element={<Suspense fallback={<PageLoader />}><PagesManagementPage /></Suspense>} />
          <Route path="settings" element={<Suspense fallback={<PageLoader />}><SettingsPage /></Suspense>} />
          <Route path="chat" element={<Suspense fallback={<PageLoader />}><ChatPage /></Suspense>} />
          <Route path="notifications" element={<Suspense fallback={<PageLoader />}><NotificationsPage /></Suspense>} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </TooltipProvider>
  )
}
