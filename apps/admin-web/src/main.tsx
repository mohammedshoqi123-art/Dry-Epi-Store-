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

// Dynamic basename for GitHub Pages deployment
const getBasename = () => {
  const path = window.location.pathname
  if (path.includes('/EPI-Supervisor/')) {
    const match = path.match(/^(\/EPI-Supervisor)/)
    return match ? match[1] : ''
  }
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
