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

// Use Vite base URL for GitHub Pages deployment
const getBasename = () => {
  // import.meta.env.BASE_URL is '/' in dev, '/EPI-Supervisor/' in prod
  const base = import.meta.env.BASE_URL
  // Remove trailing slash for react-router
  return base === '/' ? '' : base.replace(/\/$/, '')
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
