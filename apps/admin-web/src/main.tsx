import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Toaster } from '@/components/ui/toaster'
import { ThemeProvider } from '@/components/layout/theme-provider'
import App from './App'
import './index.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,
      refetchOnWindowFocus: false,
      retry: 2,
    },
  },
})

// Dynamically detect base path for GitHub Pages deployment
// Supports: / (root), /EPI-Supervisor/, /EPI-Supervisor/admin/
const getBasename = () => {
  const path = window.location.pathname
  // If deployed under a subdirectory, extract the base
  if (path.startsWith('/EPI-Supervisor/admin/')) return '/EPI-Supervisor/admin'
  if (path.startsWith('/EPI-Supervisor/')) return '/EPI-Supervisor'
  return ''
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter basename={getBasename()}>
        <ThemeProvider defaultTheme="light" storageKey="epi-admin-theme">
          <App />
          <Toaster />
        </ThemeProvider>
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>,
)
