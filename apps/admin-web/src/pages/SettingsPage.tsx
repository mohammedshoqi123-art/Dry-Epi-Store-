import { useState, useRef, useCallback, useEffect } from 'react'
import {
  Settings, Shield, Database, Bell, Palette, Globe, Lock,
  Server, Clock, Mail, Save, RefreshCw, Download, Upload,
  AlertTriangle, CheckCircle2, Key, Eye, EyeOff, Trash2,
  FileText, HardDrive, Wifi, ChevronDown, ChevronUp,
  X, Loader2, Image, Monitor, Sun, Moon, Volume2,
  VolumeX, RotateCcw, FileUp, FileDown, Archive, SlidersHorizontal,
  ListChecks, Users, ClipboardList, PackageX, Info,
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Progress } from '@/components/ui/progress'
import {
  Dialog, DialogContent, DialogHeader, DialogFooter, DialogTitle, DialogDescription,
} from '@/components/ui/dialog'
import { Header } from '@/components/layout/header'
import { useTheme } from '@/components/layout/theme-provider'
import { supabase, isConfigured } from '@/lib/supabase'
import { cn } from '@/lib/utils'

// ─── Types ──────────────────────────────────────────────────────────────────

interface SettingSection {
  id: string
  icon: React.ElementType
  title: string
  description: string
}

interface ExportState {
  loading: boolean
  progress: number
  table: string
  format: 'csv' | 'json'
}

interface ImportState {
  loading: boolean
  progress: number
  table: string
  preview: Record<string, unknown>[]
  conflictStrategy: 'skip' | 'overwrite'
}

interface BackupState {
  loading: boolean
  progress: number
  phase: string
}

interface ClearState {
  loading: boolean
  table: string
  progress: number
}

interface IPEntry {
  id: string
  address: string
  label: string
}

interface SMTPConfig {
  host: string
  port: string
  user: string
  pass: string
  fromAddress: string
  fromName: string
}

// ─── Constants ──────────────────────────────────────────────────────────────

const sections: SettingSection[] = [
  { id: 'general', icon: Settings, title: 'عام', description: 'الإعدادات الأساسية للنظام' },
  { id: 'security', icon: Shield, title: 'الأمان', description: 'إعدادات الحماية والصلاحيات' },
  { id: 'notifications', icon: Bell, title: 'الإشعارات', description: 'إدارة التنبيهات والتنبيهات' },
  { id: 'appearance', icon: Palette, title: 'المظهر', description: 'تخصيص واجهة النظام' },
  { id: 'data', icon: Database, title: 'البيانات', description: 'إدارة النسخ الاحتياطي والتصدير' },
  { id: 'system', icon: Server, title: 'النظام', description: 'معلومات النظام والحالة' },
]

const TIMEZONES = [
  { value: 'Asia/Aden', label: 'Asia/Aden (UTC+3)' },
  { value: 'Asia/Riyadh', label: 'Asia/Riyadh (UTC+3)' },
  { value: 'Asia/Baghdad', label: 'Asia/Baghdad (UTC+3)' },
  { value: 'Asia/Dubai', label: 'Asia/Dubai (UTC+4)' },
  { value: 'Africa/Cairo', label: 'Africa/Cairo (UTC+2)' },
  { value: 'Europe/London', label: 'Europe/London (UTC+0)' },
  { value: 'UTC', label: 'UTC (UTC+0)' },
]

const DATE_FORMATS = [
  { value: 'dd/MM/yyyy', label: '25/12/2024' },
  { value: 'yyyy-MM-dd', label: '2024-12-25' },
  { value: 'MM/dd/yyyy', label: '12/25/2024' },
  { value: 'dd-MM-yyyy', label: '25-12-2024' },
]

const EXPORTABLE_TABLES = [
  { key: 'profiles', label: 'المستخدمين', icon: Users },
  { key: 'forms', label: 'النماذج', icon: FileText },
  { key: 'form_submissions', label: 'إرساليات النماذج', icon: ClipboardList },
  { key: 'supply_shortages', label: 'النواقص', icon: PackageX },
  { key: 'governorates', label: 'المحافظات', icon: Globe },
  { key: 'districts', label: 'الأقضية', icon: Globe },
]

const PASSWORD_MIN_LENGTHS = ['6', '8', '10', '12', '14']

const PRIMARY_COLORS = [
  { value: '#3b82f6', label: 'أزرق' },
  { value: '#8b5cf6', label: 'بنفسجي' },
  { value: '#06b6d4', label: 'سماوي' },
  { value: '#10b981', label: 'أخضر' },
  { value: '#f59e0b', label: 'برتقالي' },
  { value: '#ef4444', label: 'أحمر' },
  { value: '#ec4899', label: 'وردي' },
  { value: '#6366f1', label: 'نيلي' },
]

// ─── Helpers ────────────────────────────────────────────────────────────────

function dataToCSV(data: Record<string, unknown>[]): string {
  if (!data.length) return ''
  const headers = Object.keys(data[0])
  const rows = data.map(row =>
    headers.map(h => {
      const val = row[h]
      if (val === null || val === undefined) return ''
      const str = typeof val === 'object' ? JSON.stringify(val) : String(val)
      return `"${str.replace(/"/g, '""')}"`
    }).join(',')
  )
  return [headers.join(','), ...rows].join('\n')
}

function downloadFile(content: string, filename: string, mimeType: string) {
  const blob = new Blob([content], { type: mimeType })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

function generateId(): string {
  return crypto.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
}

// ─── Component ──────────────────────────────────────────────────────────────

export default function SettingsPage() {
  const { theme, setTheme } = useTheme()
  const [activeSection, setActiveSection] = useState('general')
  const fileInputRef = useRef<HTMLInputElement>(null)
  const restoreInputRef = useRef<HTMLInputElement>(null)
  const logoInputRef = useRef<HTMLInputElement>(null)

  // ── General Settings ──────────────────────────────────────────────────────
  const [appName, setAppName] = useState('EPI Pulse')
  const [language, setLanguage] = useState('ar')
  const [timezone, setTimezone] = useState('Asia/Aden')
  const [syncInterval, setSyncInterval] = useState('5')
  const [dateFormat, setDateFormat] = useState('dd/MM/yyyy')
  const [defaultSubmissionStatus, setDefaultSubmissionStatus] = useState('draft')
  const [autoSaveInterval, setAutoSaveInterval] = useState('30')

  // ── Security Settings ─────────────────────────────────────────────────────
  const [sessionTimeout, setSessionTimeout] = useState(60)
  const [rateLimit, setRateLimit] = useState('10')
  const [twoFactor, setTwoFactor] = useState(false)
  const [minPasswordLength, setMinPasswordLength] = useState('8')
  const [requireSpecialChars, setRequireSpecialChars] = useState(true)
  const [requireNumbers, setRequireNumbers] = useState(true)
  const [maxLoginAttempts, setMaxLoginAttempts] = useState('5')
  const [ipWhitelist, setIpWhitelist] = useState<IPEntry[]>([])
  const [newIP, setNewIP] = useState('')
  const [newIPLabel, setNewIPLabel] = useState('')
  const [showPassword, setShowPassword] = useState(false)

  // ── Notification Settings ─────────────────────────────────────────────────
  const [emailNotifs, setEmailNotifs] = useState(true)
  const [pushNotifs, setPushNotifs] = useState(true)
  const [criticalAlerts, setCriticalAlerts] = useState(true)
  const [lowSubmissionAlerts, setLowSubmissionAlerts] = useState(false)
  const [dailyReport, setDailyReport] = useState(false)
  const [weeklyReport, setWeeklyReport] = useState(false)
  const [notificationSound, setNotificationSound] = useState(true)
  const [criticalThreshold, setCriticalThreshold] = useState('3')
  const [lowSubmissionThreshold, setLowSubmissionThreshold] = useState('10')

  // SMTP
  const [smtpConfig, setSmtpConfig] = useState<SMTPConfig>({
    host: '', port: '587', user: '', pass: '', fromAddress: '', fromName: 'EPI Pulse',
  })
  const [showSmtpPass, setShowSmtpPass] = useState(false)

  // ── Appearance Settings ───────────────────────────────────────────────────
  const [primaryColor, setPrimaryColor] = useState('#3b82f6')
  const [fontSize, setFontSize] = useState(14)
  const [density, setDensity] = useState<'compact' | 'comfortable' | 'spacious'>('comfortable')
  const [sidebarPosition, setSidebarPosition] = useState<'right' | 'left'>('right')
  const [logoUrl, setLogoUrl] = useState('')

  // ── Data Management ───────────────────────────────────────────────────────
  const [exportState, setExportState] = useState<ExportState>({
    loading: false, progress: 0, table: '', format: 'json',
  })
  const [importState, setImportState] = useState<ImportState>({
    loading: false, progress: 0, table: '', preview: [], conflictStrategy: 'skip',
  })
  const [backupState, setBackupState] = useState<BackupState>({
    loading: false, progress: 0, phase: '',
  })
  const [clearState, setClearState] = useState<ClearState>({
    loading: false, table: '', progress: 0,
  })
  const [showClearDialog, setShowClearDialog] = useState(false)
  const [clearTableTarget, setClearTableTarget] = useState('')
  const [clearConfirmText, setClearConfirmText] = useState('')

  // ── System Info ───────────────────────────────────────────────────────────
  const [systemInfo, setSystemInfo] = useState({
    version: '1.0.0',
    uptime: '',
    storageUsed: '0 KB',
    apiStatus: 'checking' as 'online' | 'offline' | 'checking',
    dbStats: { profiles: 0, submissions: 0, forms: 0, shortages: 0 },
  })

  // ── UI State ──────────────────────────────────────────────────────────────
  const [saved, setSaved] = useState(false)
  const [activeDataTab, setActiveDataTab] = useState<'export' | 'import' | 'backup' | 'clear'>('export')
  const [expandedSmtp, setExpandedSmtp] = useState(false)

  // ── System Info Loader ────────────────────────────────────────────────────
  const loadSystemInfo = useCallback(async () => {
    if (!isConfigured) {
      setSystemInfo(prev => ({ ...prev, apiStatus: 'offline' }))
      return
    }

    try {
      setSystemInfo(prev => ({ ...prev, apiStatus: 'checking' }))
      const startTime = performance.now()

      const [usersRes, subsRes, formsRes, shortagesRes] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }),
        supabase.from('form_submissions').select('id', { count: 'exact', head: true }),
        supabase.from('forms').select('id', { count: 'exact', head: true }),
        supabase.from('supply_shortages').select('id', { count: 'exact', head: true }),
      ])

      const elapsed = Math.round(performance.now() - startTime)
      // Browser-based uptime approximation
      const uptimeSeconds = Math.floor(performance.now() / 1000)
      const hours = Math.floor(uptimeSeconds / 3600)
      const minutes = Math.floor((uptimeSeconds % 3600) / 60)

      setSystemInfo({
        version: '1.0.0',
        uptime: `${hours}س ${minutes}د`,
        storageUsed: '~-- MB',
        apiStatus: elapsed < 5000 ? 'online' : 'offline',
        dbStats: {
          profiles: usersRes.count || 0,
          submissions: subsRes.count || 0,
          forms: formsRes.count || 0,
          shortages: shortagesRes.count || 0,
        },
      })
    } catch {
      setSystemInfo(prev => ({ ...prev, apiStatus: 'offline' }))
    }
  }, [])

  useEffect(() => {
    loadSystemInfo()
  }, [loadSystemInfo])

  // ── Save Handler ──────────────────────────────────────────────────────────
  const handleSave = () => {
    const allSettings = {
      general: { appName, language, timezone, syncInterval, dateFormat, defaultSubmissionStatus, autoSaveInterval },
      security: { sessionTimeout, rateLimit, twoFactor, minPasswordLength, requireSpecialChars, requireNumbers, maxLoginAttempts, ipWhitelist },
      notifications: { emailNotifs, pushNotifs, criticalAlerts, lowSubmissionAlerts, dailyReport, weeklyReport, notificationSound, criticalThreshold, lowSubmissionThreshold, smtpConfig },
      appearance: { theme, primaryColor, fontSize, density, sidebarPosition, logoUrl },
    }
    localStorage.setItem('epi-settings', JSON.stringify(allSettings))
    setSaved(true)
    setTimeout(() => setSaved(false), 3000)
  }

  // Load settings from localStorage
  useEffect(() => {
    try {
      const raw = localStorage.getItem('epi-settings')
      if (!raw) return
      const s = JSON.parse(raw)
      if (s.general) {
        s.general.appName && setAppName(s.general.appName)
        s.general.language && setLanguage(s.general.language)
        s.general.timezone && setTimezone(s.general.timezone)
        s.general.syncInterval && setSyncInterval(s.general.syncInterval)
        s.general.dateFormat && setDateFormat(s.general.dateFormat)
        s.general.defaultSubmissionStatus && setDefaultSubmissionStatus(s.general.defaultSubmissionStatus)
        s.general.autoSaveInterval && setAutoSaveInterval(s.general.autoSaveInterval)
      }
      if (s.security) {
        s.security.sessionTimeout != null && setSessionTimeout(s.security.sessionTimeout)
        s.security.rateLimit && setRateLimit(s.security.rateLimit)
        s.security.twoFactor != null && setTwoFactor(s.security.twoFactor)
        s.security.minPasswordLength && setMinPasswordLength(s.security.minPasswordLength)
        s.security.requireSpecialChars != null && setRequireSpecialChars(s.security.requireSpecialChars)
        s.security.requireNumbers != null && setRequireNumbers(s.security.requireNumbers)
        s.security.maxLoginAttempts && setMaxLoginAttempts(s.security.maxLoginAttempts)
        s.security.ipWhitelist && setIpWhitelist(s.security.ipWhitelist)
      }
      if (s.notifications) {
        s.notifications.emailNotifs != null && setEmailNotifs(s.notifications.emailNotifs)
        s.notifications.pushNotifs != null && setPushNotifs(s.notifications.pushNotifs)
        s.notifications.criticalAlerts != null && setCriticalAlerts(s.notifications.criticalAlerts)
        s.notifications.lowSubmissionAlerts != null && setLowSubmissionAlerts(s.notifications.lowSubmissionAlerts)
        s.notifications.dailyReport != null && setDailyReport(s.notifications.dailyReport)
        s.notifications.weeklyReport != null && setWeeklyReport(s.notifications.weeklyReport)
        s.notifications.notificationSound != null && setNotificationSound(s.notifications.notificationSound)
        s.notifications.criticalThreshold && setCriticalThreshold(s.notifications.criticalThreshold)
        s.notifications.lowSubmissionThreshold && setLowSubmissionThreshold(s.notifications.lowSubmissionThreshold)
        s.notifications.smtpConfig && setSmtpConfig(s.notifications.smtpConfig)
      }
      if (s.appearance) {
        s.appearance.primaryColor && setPrimaryColor(s.appearance.primaryColor)
        s.appearance.fontSize && setFontSize(s.appearance.fontSize)
        s.appearance.density && setDensity(s.appearance.density)
        s.appearance.sidebarPosition && setSidebarPosition(s.appearance.sidebarPosition)
        s.appearance.logoUrl && setLogoUrl(s.appearance.logoUrl)
      }
    } catch {
      // ignore malformed settings
    }
  }, [])

  // ── Export Functions ───────────────────────────────────────────────────────

  const handleExport = async (table: string, format: 'csv' | 'json') => {
    if (!isConfigured) return
    setExportState({ loading: true, progress: 10, table, format })

    try {
      setExportState(s => ({ ...s, progress: 30 }))
      const { data, error } = await supabase
        .from(table as 'profiles')
        .select('*')
        .limit(10000)

      if (error) throw error
      if (!data || data.length === 0) {
        throw new Error('لا توجد بيانات للتصدير')
      }

      setExportState(s => ({ ...s, progress: 70 }))

      const ts = new Date().toISOString().split('T')[0]
      const cleanTable = table.replace(/[^a-zA-Z_]/g, '')

      if (format === 'json') {
        const json = JSON.stringify(data, null, 2)
        setExportState(s => ({ ...s, progress: 90 }))
        downloadFile(json, `${cleanTable}-${ts}.json`, 'application/json')
      } else {
        const csv = dataToCSV(data)
        setExportState(s => ({ ...s, progress: 90 }))
        downloadFile(csv, `${cleanTable}-${ts}.csv`, 'text/csv')
      }

      setExportState(s => ({ ...s, progress: 100 }))
      setTimeout(() => setExportState({ loading: false, progress: 0, table: '', format: 'json' }), 1500)
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'فشل التصدير'
      alert(message)
      setExportState({ loading: false, progress: 0, table: '', format: 'json' })
    }
  }

  const handleExportAll = async (format: 'csv' | 'json') => {
    if (!isConfigured) return
    setExportState({ loading: true, progress: 5, table: 'all', format })

    try {
      const allData: Record<string, unknown[]> = {}
      const tables = EXPORTABLE_TABLES.map(t => t.key)

      for (let i = 0; i < tables.length; i++) {
        const table = tables[i]
        setExportState(s => ({ ...s, progress: 5 + Math.round((i / tables.length) * 80), table }))
        const { data } = await supabase.from(table as 'profiles').select('*').limit(10000)
        allData[table] = data || []
      }

      setExportState(s => ({ ...s, progress: 90 }))
      const ts = new Date().toISOString().split('T')[0]
      const json = JSON.stringify(allData, null, 2)

      if (format === 'json') {
        downloadFile(json, `epi-backup-all-${ts}.json`, 'application/json')
      } else {
        // Export each table as separate CSV inside a single download isn't practical,
        // so we export the combined JSON and also offer per-table CSV downloads.
        // For "export all CSV", we zip them conceptually — here we download as JSON with a note.
        downloadFile(json, `epi-export-all-${ts}.json`, 'application/json')
      }

      setExportState(s => ({ ...s, progress: 100 }))
      setTimeout(() => setExportState({ loading: false, progress: 0, table: '', format: 'json' }), 1500)
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'فشل التصدير الشامل'
      alert(message)
      setExportState({ loading: false, progress: 0, table: '', format: 'json' })
    }
  }

  // ── Import Functions ───────────────────────────────────────────────────────

  const handleImportFileSelect = async (table: string, file: File) => {
    setImportState(s => ({ ...s, loading: true, progress: 10, table, preview: [] }))

    try {
      const text = await file.text()
      let parsed: Record<string, unknown>[] = []

      if (file.name.endsWith('.json')) {
        const raw = JSON.parse(text)
        parsed = Array.isArray(raw) ? raw : [raw]
      } else if (file.name.endsWith('.csv')) {
        const lines = text.trim().split('\n')
        if (lines.length < 2) throw new Error('ملف CSV فارغ أو غير صالح')
        const headers = lines[0].split(',').map(h => h.trim().replace(/^"|"$/g, ''))
        parsed = lines.slice(1).map(line => {
          const values = line.match(/("([^"]|"")*"|[^,]*)/g) || []
          const obj: Record<string, unknown> = {}
          headers.forEach((h, i) => {
            let val = (values[i] || '').trim()
            if (val.startsWith('"') && val.endsWith('"')) val = val.slice(1, -1).replace(/""/g, '"')
            obj[h] = val === '' ? null : val
          })
          return obj
        })
      } else {
        throw new Error('صيغة الملف غير مدعومة. استخدم JSON أو CSV')
      }

      if (!parsed.length) throw new Error('لا توجد بيانات في الملف')

      setImportState(s => ({
        ...s, progress: 50, preview: parsed.slice(0, 10), loading: false,
      }))
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'فشل قراءة الملف'
      alert(message)
      setImportState({ loading: false, progress: 0, table: '', preview: [], conflictStrategy: 'skip' })
    }
  }

  const handleImportConfirm = async () => {
    const { table, preview, conflictStrategy } = importState
    if (!table || !preview.length || !isConfigured) return

    setImportState(s => ({ ...s, loading: true, progress: 60 }))

    try {
      // Re-read full data from the preview ref (we stored only preview, but we need full)
      // In a real scenario, we'd store the full parsed data. For now, import preview + extend.
      // Actually let's store full data in a ref
      const fullData = importFullDataRef.current
      if (!fullData?.length) throw new Error('لا توجد بيانات للاستيراد')

      setImportState(s => ({ ...s, progress: 70 }))

      if (conflictStrategy === 'overwrite') {
        // Upsert in batches of 100
        const batchSize = 100
        for (let i = 0; i < fullData.length; i += batchSize) {
          const batch = fullData.slice(i, i + batchSize)
          const { error } = await supabase.from(table as 'profiles').upsert(batch, { onConflict: 'id' })
          if (error) throw error
          setImportState(s => ({ ...s, progress: 70 + Math.round(((i + batch.length) / fullData.length) * 25) }))
        }
      } else {
        // Skip conflicts — insert one by one (skip errors for duplicates)
        let imported = 0
        for (const row of fullData) {
          try {
            await supabase.from(table as 'profiles').insert(row)
            imported++
          } catch {
            // skip duplicates
          }
          setImportState(s => ({
            ...s, progress: 70 + Math.round((imported / fullData.length) * 25),
          }))
        }
      }

      setImportState(s => ({ ...s, progress: 100, loading: false }))
      alert(`تم استيراد البيانات بنجاح`)
      setTimeout(() => {
        setImportState({ loading: false, progress: 0, table: '', preview: [], conflictStrategy: 'skip' })
        importFullDataRef.current = []
      }, 2000)
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'فشل الاستيراد'
      alert(message)
      setImportState(s => ({ ...s, loading: false, progress: 0 }))
    }
  }

  const importFullDataRef = useRef<Record<string, unknown>[]>([])

  // Override the import file handler to also store full data
  const handleImportFile = async (table: string, file: File) => {
    setImportState(s => ({ ...s, loading: true, progress: 10, table, preview: [] }))

    try {
      const text = await file.text()
      let parsed: Record<string, unknown>[] = []

      if (file.name.endsWith('.json')) {
        const raw = JSON.parse(text)
        parsed = Array.isArray(raw) ? raw : [raw]
      } else if (file.name.endsWith('.csv')) {
        const lines = text.trim().split('\n')
        if (lines.length < 2) throw new Error('ملف CSV فارغ أو غير صالح')
        const headers = lines[0].split(',').map(h => h.trim().replace(/^"|"$/g, ''))
        parsed = lines.slice(1).map(line => {
          const values = line.match(/("([^"]|"")*"|[^,]*)/g) || []
          const obj: Record<string, unknown> = {}
          headers.forEach((h, i) => {
            let val = (values[i] || '').trim()
            if (val.startsWith('"') && val.endsWith('"')) val = val.slice(1, -1).replace(/""/g, '"')
            obj[h] = val === '' ? null : val
          })
          return obj
        })
      } else {
        throw new Error('صيغة الملف غير مدعومة. استخدم JSON أو CSV')
      }

      if (!parsed.length) throw new Error('لا توجد بيانات في الملف')

      importFullDataRef.current = parsed
      setImportState(s => ({
        ...s, progress: 50, preview: parsed.slice(0, 5), loading: false,
      }))
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'فشل قراءة الملف'
      alert(message)
      setImportState({ loading: false, progress: 0, table: '', preview: [], conflictStrategy: 'skip' })
      importFullDataRef.current = []
    }
  }

  // ── Backup Functions ───────────────────────────────────────────────────────

  const handleCreateBackup = async () => {
    if (!isConfigured) return
    setBackupState({ loading: true, progress: 5, phase: 'جاري تجهيز النسخة الاحتياطية...' })

    try {
      const tables = ['profiles', 'forms', 'form_submissions', 'supply_shortages', 'governorates', 'districts', 'notifications', 'audit_logs']
      const snapshot: Record<string, unknown[]> = {}
      const meta = {
        version: systemInfo.version,
        created_at: new Date().toISOString(),
        tables: tables,
        app_name: appName,
      }

      for (let i = 0; i < tables.length; i++) {
        const table = tables[i]
        setBackupState({
          loading: true,
          progress: 5 + Math.round((i / tables.length) * 85),
          phase: `جاري تصدير: ${table}`,
        })
        const { data } = await supabase.from(table as 'profiles').select('*').limit(50000)
        snapshot[table] = data || []
      }

      setBackupState({ loading: true, progress: 95, phase: 'جاري حفظ الملف...' })

      const backup = { meta, data: snapshot }
      const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)
      downloadFile(JSON.stringify(backup, null, 2), `epi-backup-${ts}.json`, 'application/json')

      setBackupState({ loading: false, progress: 100, phase: 'تم إنشاء النسخة الاحتياطية بنجاح' })
      setTimeout(() => setBackupState({ loading: false, progress: 0, phase: '' }), 3000)
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'فشل إنشاء النسخة الاحتياطية'
      alert(message)
      setBackupState({ loading: false, progress: 0, phase: '' })
    }
  }

  const handleRestoreBackup = async (file: File) => {
    if (!isConfigured) return

    try {
      const text = await file.text()
      const backup = JSON.parse(text)

      if (!backup.data || typeof backup.data !== 'object') {
        throw new Error('ملف النسخة الاحتياطية غير صالح')
      }

      const confirmMsg = `هل أنت متأكد من استعادة هذه النسخة الاحتياطية؟\n\nتاريخ الإنشاء: ${backup.meta?.created_at || 'غير معروف'}\nالجداول: ${Object.keys(backup.data).join(', ')}\n\nسيتم استبدال البيانات الحالية.`
      if (!window.confirm(confirmMsg)) return

      setBackupState({ loading: true, progress: 5, phase: 'جاري استعادة النسخة الاحتياطية...' })

      const tables = Object.keys(backup.data)
      for (let i = 0; i < tables.length; i++) {
        const table = tables[i]
        const rows = backup.data[table]
        if (!Array.isArray(rows) || rows.length === 0) continue

        setBackupState({
          loading: true,
          progress: 5 + Math.round((i / tables.length) * 90),
          phase: `جاري استعادة: ${table} (${rows.length} سجل)`,
        })

        // Insert in batches
        const batchSize = 100
        for (let j = 0; j < rows.length; j += batchSize) {
          const batch = rows.slice(j, j + batchSize)
          const { error } = await supabase.from(table as 'profiles').upsert(batch, { onConflict: 'id' })
          if (error) console.warn(`Restore warning for ${table}:`, error.message)
        }
      }

      setBackupState({ loading: false, progress: 100, phase: 'تمت الاستعادة بنجاح' })
      loadSystemInfo()
      setTimeout(() => setBackupState({ loading: false, progress: 0, phase: '' }), 3000)
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'فشل استعادة النسخة الاحتياطية'
      alert(message)
      setBackupState({ loading: false, progress: 0, phase: '' })
    }
  }

  // ── Clear Data Functions ───────────────────────────────────────────────────

  const handleClearData = async () => {
    if (!isConfigured || clearConfirmText !== 'تأكيد') return

    const table = clearTableTarget
    setClearState({ loading: true, table, progress: 10 })
    setShowClearDialog(false)
    setClearConfirmText('')

    try {
      setClearState(s => ({ ...s, progress: 30 }))
      const { error } = await supabase.from(table as 'profiles').delete().neq('id', '00000000-0000-0000-0000-000000000000')
      if (error) throw error

      setClearState(s => ({ ...s, progress: 90 }))
      setClearState({ loading: false, table: '', progress: 100 })
      loadSystemInfo()
      setTimeout(() => setClearState({ loading: false, table: '', progress: 0 }), 2000)
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'فشل مسح البيانات'
      alert(message)
      setClearState({ loading: false, table: '', progress: 0 })
    }
  }

  // ── IP Whitelist ──────────────────────────────────────────────────────────

  const handleAddIP = () => {
    if (!newIP.trim()) return
    setIpWhitelist(prev => [...prev, { id: generateId(), address: newIP.trim(), label: newIPLabel.trim() || newIP.trim() }])
    setNewIP('')
    setNewIPLabel('')
  }

  const handleRemoveIP = (id: string) => {
    setIpWhitelist(prev => prev.filter(ip => ip.id !== id))
  }

  // ── Logo Upload ───────────────────────────────────────────────────────────

  const handleLogoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (!file.type.startsWith('image/')) {
      alert('يرفق صورة فقط')
      return
    }
    if (file.size > 2 * 1024 * 1024) {
      alert('حجم الصورة يجب أن يكون أقل من 2 ميجا')
      return
    }
    const reader = new FileReader()
    reader.onload = () => setLogoUrl(reader.result as string)
    reader.readAsDataURL(file)
  }

  // ─── Render ───────────────────────────────────────────────────────────────

  return (
    <div className="page-enter">
      <Header title="الإعدادات" subtitle="تكوين النظام والخصوصية" />

      <div className="p-6">
        <div className="flex flex-col lg:flex-row gap-6">
          {/* ═══ Sidebar Navigation ═══ */}
          <div className="lg:w-64 shrink-0">
            <Card>
              <CardContent className="p-2">
                <nav className="space-y-1">
                  {sections.map((s) => {
                    const Icon = s.icon
                    return (
                      <button
                        key={s.id}
                        onClick={() => setActiveSection(s.id)}
                        className={cn(
                          'w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all text-right',
                          activeSection === s.id
                            ? 'bg-primary text-primary-foreground shadow-md'
                            : 'hover:bg-muted text-muted-foreground hover:text-foreground'
                        )}
                      >
                        <Icon className="w-4 h-4 shrink-0" />
                        <div className="min-w-0">
                          <span className="font-medium block">{s.title}</span>
                          <span className={cn(
                            'text-[11px] block truncate',
                            activeSection === s.id ? 'text-primary-foreground/80' : 'text-muted-foreground'
                          )}>{s.description}</span>
                        </div>
                      </button>
                    )
                  })}
                </nav>
              </CardContent>
            </Card>

            {/* System Status Card */}
            <Card className="mt-4">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-heading">حالة النظام</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">Supabase</span>
                  <Badge variant={isConfigured ? 'default' : 'destructive'} className="text-[10px]">
                    {isConfigured ? 'متصل' : 'غير مُعدّ'}
                  </Badge>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">الإصدار</span>
                  <span className="font-mono text-xs">{systemInfo.version}</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">الحالة</span>
                  <Badge
                    variant="outline"
                    className={cn('text-[10px]', {
                      'border-emerald-500 text-emerald-600': systemInfo.apiStatus === 'online',
                      'border-red-500 text-red-600': systemInfo.apiStatus === 'offline',
                      'border-amber-500 text-amber-600': systemInfo.apiStatus === 'checking',
                    })}
                  >
                    {systemInfo.apiStatus === 'online' ? 'يعمل' : systemInfo.apiStatus === 'checking' ? '...' : 'متوقف'}
                  </Badge>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* ═══ Main Content ═══ */}
          <div className="flex-1 space-y-6 min-w-0">

            {/* ─── General Settings ────────────────────────────────────────────── */}
            {activeSection === 'general' && (
              <div className="space-y-6 animate-fade-in">
                <Card>
                  <CardHeader>
                    <CardTitle className="font-heading flex items-center gap-2">
                      <Settings className="w-5 h-5" />
                      الإعدادات العامة
                    </CardTitle>
                    <CardDescription>الإعدادات الأساسية للتطبيق</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-5">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label>اسم التطبيق</Label>
                        <Input value={appName} onChange={(e) => setAppName(e.target.value)} placeholder="اسم التطبيق" />
                      </div>
                      <div className="space-y-2">
                        <Label>اللغة</Label>
                        <Select value={language} onValueChange={setLanguage}>
                          <SelectTrigger><SelectValue /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value="ar">العربية</SelectItem>
                            <SelectItem value="en">English</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="space-y-2">
                        <Label>المنطقة الزمنية</Label>
                        <Select value={timezone} onValueChange={setTimezone}>
                          <SelectTrigger><SelectValue /></SelectTrigger>
                          <SelectContent>
                            {TIMEZONES.map(tz => (
                              <SelectItem key={tz.value} value={tz.value}>{tz.label}</SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="space-y-2">
                        <Label>تنسيق التاريخ</Label>
                        <Select value={dateFormat} onValueChange={setDateFormat}>
                          <SelectTrigger><SelectValue /></SelectTrigger>
                          <SelectContent>
                            {DATE_FORMATS.map(f => (
                              <SelectItem key={f.value} value={f.value}>{f.label}</SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="space-y-2">
                        <Label>فترة المزامنة (دقائق)</Label>
                        <Input type="number" min="1" max="120" value={syncInterval} onChange={(e) => setSyncInterval(e.target.value)} />
                      </div>
                      <div className="space-y-2">
                        <Label>فترة الحفظ التلقائي (ثانية)</Label>
                        <Input type="number" min="5" max="300" value={autoSaveInterval} onChange={(e) => setAutoSaveInterval(e.target.value)} />
                      </div>
                    </div>

                    <Separator />

                    <div className="space-y-4">
                      <h4 className="text-sm font-medium flex items-center gap-2">
                        <ClipboardList className="w-4 h-4" />
                        إعدادات النماذج
                      </h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label>الحالة الافتراضية للإرساليات</Label>
                          <Select value={defaultSubmissionStatus} onValueChange={setDefaultSubmissionStatus}>
                            <SelectTrigger><SelectValue /></SelectTrigger>
                            <SelectContent>
                              <SelectItem value="draft">مسودة</SelectItem>
                              <SelectItem value="submitted">مرسلة</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}

            {/* ─── Security Settings ───────────────────────────────────────────── */}
            {activeSection === 'security' && (
              <div className="space-y-6 animate-fade-in">
                <Card>
                  <CardHeader>
                    <CardTitle className="font-heading flex items-center gap-2">
                      <Shield className="w-5 h-5" />
                      الأمان والحماية
                    </CardTitle>
                    <CardDescription>إعدادات الحماية والصلاحيات</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-6">
                    {/* Session & Rate Limiting */}
                    <div className="space-y-4">
                      <h4 className="text-sm font-medium flex items-center gap-2">
                        <Clock className="w-4 h-4" />
                        الجلسة والتحكم بالطلبات
                      </h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <div className="space-y-3">
                          <div className="flex items-center justify-between">
                            <Label>مهلة الجلسة</Label>
                            <span className="text-sm font-mono text-primary">{sessionTimeout} دقيقة</span>
                          </div>
                          <input
                            type="range"
                            min={5}
                            max={480}
                            step={5}
                            value={sessionTimeout}
                            onChange={(e) => setSessionTimeout(Number(e.target.value))}
                            className="w-full h-2 rounded-lg appearance-none cursor-pointer bg-muted accent-primary"
                          />
                          <div className="flex justify-between text-[10px] text-muted-foreground">
                            <span>5 د</span><span>4 ساعات</span><span>8 ساعات</span>
                          </div>
                        </div>
                        <div className="space-y-2">
                          <Label>حد الطلبات (لكل دقيقة)</Label>
                          <Input type="number" min="1" max="1000" value={rateLimit} onChange={(e) => setRateLimit(e.target.value)} />
                        </div>
                        <div className="space-y-2">
                          <Label>الحد الأقصى لمحاولات تسجيل الدخول</Label>
                          <Input type="number" min="3" max="20" value={maxLoginAttempts} onChange={(e) => setMaxLoginAttempts(e.target.value)} />
                        </div>
                      </div>
                    </div>

                    <Separator />

                    {/* 2FA */}
                    <div className="flex items-center justify-between p-3 rounded-lg border">
                      <div className="flex items-center gap-3">
                        <Lock className="w-5 h-5 text-muted-foreground" />
                        <div>
                          <p className="text-sm font-medium">المصادقة الثنائية (2FA)</p>
                          <p className="text-xs text-muted-foreground">تطلب رمز إضافي عند تسجيل الدخول</p>
                        </div>
                      </div>
                      <Switch checked={twoFactor} onCheckedChange={setTwoFactor} />
                    </div>

                    <Separator />

                    {/* Password Policy */}
                    <div className="space-y-4">
                      <h4 className="text-sm font-medium flex items-center gap-2">
                        <Key className="w-4 h-4" />
                        سياسة كلمة المرور
                      </h4>
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div className="space-y-2">
                          <Label>الحد الأدنى لطول كلمة المرور</Label>
                          <Select value={minPasswordLength} onValueChange={setMinPasswordLength}>
                            <SelectTrigger><SelectValue /></SelectTrigger>
                            <SelectContent>
                              {PASSWORD_MIN_LENGTHS.map(l => (
                                <SelectItem key={l} value={l}>{l} حرف</SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="flex items-center justify-between p-3 rounded-lg border">
                          <div>
                            <p className="text-sm font-medium">تطلب رموز خاصة</p>
                            <p className="text-xs text-muted-foreground">!@#$%^&amp;*</p>
                          </div>
                          <Switch checked={requireSpecialChars} onCheckedChange={setRequireSpecialChars} />
                        </div>
                        <div className="flex items-center justify-between p-3 rounded-lg border">
                          <div>
                            <p className="text-sm font-medium">تطلب أرقام</p>
                            <p className="text-xs text-muted-foreground">0-9</p>
                          </div>
                          <Switch checked={requireNumbers} onCheckedChange={setRequireNumbers} />
                        </div>
                      </div>
                    </div>

                    <Separator />

                    {/* IP Whitelist */}
                    <div className="space-y-4">
                      <h4 className="text-sm font-medium flex items-center gap-2">
                        <Wifi className="w-4 h-4" />
                        قائمة IPs المسموحة
                      </h4>
                      <div className="flex gap-2">
                        <Input
                          placeholder="عنوان IP"
                          value={newIP}
                          onChange={(e) => setNewIP(e.target.value)}
                          className="flex-1"
                        />
                        <Input
                          placeholder="الوصف (اختياري)"
                          value={newIPLabel}
                          onChange={(e) => setNewIPLabel(e.target.value)}
                          className="flex-1"
                        />
                        <Button variant="outline" onClick={handleAddIP} disabled={!newIP.trim()}>
                          إضافة
                        </Button>
                      </div>
                      {ipWhitelist.length > 0 && (
                        <div className="space-y-2">
                          {ipWhitelist.map(ip => (
                            <div key={ip.id} className="flex items-center justify-between p-2 rounded-lg bg-muted/50">
                              <div className="flex items-center gap-2">
                                <Badge variant="outline" className="font-mono text-[10px]">{ip.address}</Badge>
                                <span className="text-xs text-muted-foreground">{ip.label}</span>
                              </div>
                              <Button variant="ghost" size="sm" onClick={() => handleRemoveIP(ip.id)}>
                                <X className="w-3 h-3" />
                              </Button>
                            </div>
                          ))}
                        </div>
                      )}
                      {ipWhitelist.length === 0 && (
                        <p className="text-xs text-muted-foreground text-center py-4">
                          لا توجد عناوين IP مقيدة — الجميع مسموح بالوصول
                        </p>
                      )}
                    </div>

                    <div className="p-4 rounded-lg bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800">
                      <div className="flex items-start gap-2">
                        <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
                        <div>
                          <p className="text-sm font-medium text-amber-800 dark:text-amber-300">إعدادات متقدمة</p>
                          <p className="text-xs text-amber-700 dark:text-amber-400 mt-1">
                            تغيير إعدادات الأمان قد يؤثر على جميع المستخدمين. تأكد من إخطار الفريق قبل التعديل.
                          </p>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}

            {/* ─── Notification Settings ───────────────────────────────────────── */}
            {activeSection === 'notifications' && (
              <div className="space-y-6 animate-fade-in">
                <Card>
                  <CardHeader>
                    <CardTitle className="font-heading flex items-center gap-2">
                      <Bell className="w-5 h-5" />
                      الإشعارات
                    </CardTitle>
                    <CardDescription>إدارة التنبيهات والتنبيهات التلقائية</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    {/* Toggle Notifications */}
                    {[
                      { label: 'إشعارات البريد', desc: 'إرسال إشعارات عبر البريد الإلكتروني', icon: Mail, checked: emailNotifs, onChange: setEmailNotifs },
                      { label: 'الإشعارات الفورية', desc: 'تنبيهات فورية في المتصفح', icon: Bell, checked: pushNotifs, onChange: setPushNotifs },
                      { label: 'تنبيهات النواقص الحرجة', desc: 'تنبيه فوري عند وجود نقص حرج', icon: AlertTriangle, checked: criticalAlerts, onChange: setCriticalAlerts },
                      { label: 'تنبيهات قلة الإرساليات', desc: 'تنبيه عند انخفاض عدد الإرساليات', icon: ClipboardList, checked: lowSubmissionAlerts, onChange: setLowSubmissionAlerts },
                      { label: 'التقرير اليومي', desc: 'إرسال ملخص يومي تلقائي', icon: Clock, checked: dailyReport, onChange: setDailyReport },
                      { label: 'التقرير الأسبوعي', desc: 'إرسال ملخص أسبوعي تلقائي', icon: Clock, checked: weeklyReport, onChange: setWeeklyReport },
                      { label: 'صوت الإشعار', desc: 'تشغيل صوت عند وصول إشعار', icon: notificationSound ? Volume2 : VolumeX, checked: notificationSound, onChange: setNotificationSound },
                    ].map((item, i) => {
                      const Icon = item.icon
                      return (
                        <div key={i} className="flex items-center justify-between p-3 rounded-lg border">
                          <div className="flex items-center gap-3">
                            <Icon className="w-5 h-5 text-muted-foreground shrink-0" />
                            <div>
                              <p className="text-sm font-medium">{item.label}</p>
                              <p className="text-xs text-muted-foreground">{item.desc}</p>
                            </div>
                          </div>
                          <Switch checked={item.checked} onCheckedChange={item.onChange} />
                        </div>
                      )
                    })}

                    <Separator />

                    {/* Alert Thresholds */}
                    <div className="space-y-4">
                      <h4 className="text-sm font-medium flex items-center gap-2">
                        <SlidersHorizontal className="w-4 h-4" />
                        عتبات التنبيه
                      </h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label>عتبة النواقص الحرجة (عدد)</Label>
                          <Input type="number" min="1" max="100" value={criticalThreshold} onChange={(e) => setCriticalThreshold(e.target.value)} />
                          <p className="text-[10px] text-muted-foreground">تنبيه عند وصول عدد النواقص الحرجة لهذا الحد</p>
                        </div>
                        <div className="space-y-2">
                          <Label>عتبة قلة الإرساليات (عدد/يوم)</Label>
                          <Input type="number" min="1" max="500" value={lowSubmissionThreshold} onChange={(e) => setLowSubmissionThreshold(e.target.value)} />
                          <p className="text-[10px] text-muted-foreground">تنبيه عند انخفاض الإرساليات اليومية عن هذا الحد</p>
                        </div>
                      </div>
                    </div>

                    <Separator />

                    {/* SMTP Config */}
                    <div className="space-y-4">
                      <button
                        onClick={() => setExpandedSmtp(!expandedSmtp)}
                        className="flex items-center justify-between w-full text-sm font-medium hover:text-primary transition-colors"
                      >
                        <span className="flex items-center gap-2">
                          <Mail className="w-4 h-4" />
                          إعدادات SMTP للبريد
                        </span>
                        {expandedSmtp ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                      </button>

                      {expandedSmtp && (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 rounded-lg bg-muted/30 animate-fade-in">
                          <div className="space-y-2">
                            <Label>خادم SMTP</Label>
                            <Input
                              value={smtpConfig.host}
                              onChange={(e) => setSmtpConfig(p => ({ ...p, host: e.target.value }))}
                              placeholder="smtp.example.com"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label>المنفذ</Label>
                            <Input
                              type="number"
                              value={smtpConfig.port}
                              onChange={(e) => setSmtpConfig(p => ({ ...p, port: e.target.value }))}
                              placeholder="587"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label>اسم المستخدم</Label>
                            <Input
                              value={smtpConfig.user}
                              onChange={(e) => setSmtpConfig(p => ({ ...p, user: e.target.value }))}
                              placeholder="user@example.com"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label>كلمة المرور</Label>
                            <div className="relative">
                              <Input
                                type={showSmtpPass ? 'text' : 'password'}
                                value={smtpConfig.pass}
                                onChange={(e) => setSmtpConfig(p => ({ ...p, pass: e.target.value }))}
                                placeholder="••••••••"
                              />
                              <button
                                type="button"
                                onClick={() => setShowSmtpPass(!showSmtpPass)}
                                className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                              >
                                {showSmtpPass ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                              </button>
                            </div>
                          </div>
                          <div className="space-y-2">
                            <Label>بريد المرسل</Label>
                            <Input
                              type="email"
                              value={smtpConfig.fromAddress}
                              onChange={(e) => setSmtpConfig(p => ({ ...p, fromAddress: e.target.value }))}
                              placeholder="noreply@example.com"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label>اسم المرسل</Label>
                            <Input
                              value={smtpConfig.fromName}
                              onChange={(e) => setSmtpConfig(p => ({ ...p, fromName: e.target.value }))}
                              placeholder="EPI Pulse"
                            />
                          </div>
                        </div>
                      )}
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}

            {/* ─── Appearance Settings ─────────────────────────────────────────── */}
            {activeSection === 'appearance' && (
              <div className="space-y-6 animate-fade-in">
                <Card>
                  <CardHeader>
                    <CardTitle className="font-heading flex items-center gap-2">
                      <Palette className="w-5 h-5" />
                      المظهر
                    </CardTitle>
                    <CardDescription>تخصيص شكل واجهة النظام</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-6">
                    {/* Theme */}
                    <div className="space-y-3">
                      <Label>السمة</Label>
                      <div className="grid grid-cols-3 gap-3">
                        {[
                          { value: 'light' as const, label: 'فاتح', icon: Sun },
                          { value: 'dark' as const, label: 'داكن', icon: Moon },
                          { value: 'system' as const, label: 'النظام', icon: Monitor },
                        ].map((t) => {
                          const Icon = t.icon
                          return (
                            <button
                              key={t.value}
                              onClick={() => setTheme(t.value as 'light' | 'dark' | 'system')}
                              className={cn(
                                'p-4 rounded-xl border-2 text-center transition-all',
                                theme === t.value
                                  ? 'border-primary bg-primary/5 shadow-md'
                                  : 'border-border hover:border-primary/30'
                              )}
                            >
                              <Icon className="w-6 h-6 mx-auto mb-2" />
                              <span className="text-sm font-medium">{t.label}</span>
                            </button>
                          )
                        })}
                      </div>
                    </div>

                    <Separator />

                    {/* Primary Color */}
                    <div className="space-y-3">
                      <Label>اللون الأساسي</Label>
                      <div className="flex flex-wrap gap-3">
                        {PRIMARY_COLORS.map(c => (
                          <button
                            key={c.value}
                            onClick={() => setPrimaryColor(c.value)}
                            className={cn(
                              'w-10 h-10 rounded-full border-2 transition-all hover:scale-110',
                              primaryColor === c.value ? 'border-foreground ring-2 ring-ring ring-offset-2' : 'border-transparent'
                            )}
                            style={{ backgroundColor: c.value }}
                            title={c.label}
                          />
                        ))}
                        <div className="relative w-10 h-10">
                          <input
                            type="color"
                            value={primaryColor}
                            onChange={(e) => setPrimaryColor(e.target.value)}
                            className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                          />
                          <div
                            className="w-10 h-10 rounded-full border-2 border-dashed border-muted-foreground/30 flex items-center justify-center"
                            style={{ backgroundColor: primaryColor }}
                          >
                            <Palette className="w-4 h-4 text-white drop-shadow" />
                          </div>
                        </div>
                      </div>
                    </div>

                    <Separator />

                    {/* Font Size */}
                    <div className="space-y-3">
                      <div className="flex items-center justify-between">
                        <Label>حجم الخط</Label>
                        <span className="text-sm font-mono text-primary">{fontSize}px</span>
                      </div>
                      <input
                        type="range"
                        min={10}
                        max={22}
                        step={1}
                        value={fontSize}
                        onChange={(e) => setFontSize(Number(e.target.value))}
                        className="w-full h-2 rounded-lg appearance-none cursor-pointer bg-muted accent-primary"
                      />
                      <div className="flex justify-between text-[10px] text-muted-foreground">
                        <span>صغير</span><span>متوسط</span><span>كبير</span>
                      </div>
                    </div>

                    <Separator />

                    {/* Density */}
                    <div className="space-y-3">
                      <Label>كثافة العرض</Label>
                      <div className="grid grid-cols-3 gap-3">
                        {[
                          { value: 'compact' as const, label: 'مضغوط', desc: 'عناصر أصغر' },
                          { value: 'comfortable' as const, label: 'مريح', desc: 'متوازن' },
                          { value: 'spacious' as const, label: 'واسع', desc: 'مساحات أكبر' },
                        ].map(d => (
                          <button
                            key={d.value}
                            onClick={() => setDensity(d.value)}
                            className={cn(
                              'p-4 rounded-xl border-2 text-center transition-all',
                              density === d.value
                                ? 'border-primary bg-primary/5 shadow-md'
                                : 'border-border hover:border-primary/30'
                            )}
                          >
                            <span className="text-sm font-medium block">{d.label}</span>
                            <span className="text-[10px] text-muted-foreground">{d.desc}</span>
                          </button>
                        ))}
                      </div>
                    </div>

                    <Separator />

                    {/* Sidebar Position */}
                    <div className="space-y-3">
                      <Label>موضع الشريط الجانبي</Label>
                      <div className="grid grid-cols-2 gap-3">
                        {[
                          { value: 'right' as const, label: 'يمين (الافتراضي)' },
                          { value: 'left' as const, label: 'يسار' },
                        ].map(pos => (
                          <button
                            key={pos.value}
                            onClick={() => setSidebarPosition(pos.value)}
                            className={cn(
                              'p-3 rounded-xl border-2 text-center transition-all text-sm',
                              sidebarPosition === pos.value
                                ? 'border-primary bg-primary/5 shadow-md font-medium'
                                : 'border-border hover:border-primary/30'
                            )}
                          >
                            {pos.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    <Separator />

                    {/* Logo Upload */}
                    <div className="space-y-3">
                      <Label>شعار النظام</Label>
                      <div className="flex items-center gap-4">
                        {logoUrl ? (
                          <div className="relative w-16 h-16 rounded-xl border overflow-hidden">
                            <img src={logoUrl} alt="Logo" className="w-full h-full object-contain" />
                            <button
                              onClick={() => setLogoUrl('')}
                              className="absolute top-0.5 left-0.5 w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center text-[10px] hover:bg-red-600"
                            >
                              <X className="w-3 h-3" />
                            </button>
                          </div>
                        ) : (
                          <div className="w-16 h-16 rounded-xl border-2 border-dashed border-muted-foreground/20 flex items-center justify-center">
                            <Image className="w-6 h-6 text-muted-foreground/40" />
                          </div>
                        )}
                        <div>
                          <input
                            ref={logoInputRef}
                            type="file"
                            accept="image/*"
                            className="hidden"
                            onChange={handleLogoUpload}
                          />
                          <Button variant="outline" size="sm" onClick={() => logoInputRef.current?.click()}>
                            <Upload className="w-4 h-4 mr-2" />
                            رفع شعار
                          </Button>
                          <p className="text-[10px] text-muted-foreground mt-1">PNG, JPG — حد أقصى 2MB</p>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}

            {/* ─── Data Management ─────────────────────────────────────────────── */}
            {activeSection === 'data' && (
              <div className="space-y-6 animate-fade-in">
                <Card>
                  <CardHeader>
                    <CardTitle className="font-heading flex items-center gap-2">
                      <Database className="w-5 h-5" />
                      إدارة البيانات
                    </CardTitle>
                    <CardDescription>النسخ الاحتياطي والتصدير والاستيراد</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-6">
                    {/* Data sub-tabs */}
                    <div className="flex gap-2 flex-wrap">
                      {([
                        { key: 'export', label: 'تصدير', icon: Download },
                        { key: 'import', label: 'استيراد', icon: Upload },
                        { key: 'backup', label: 'نسخ احتياطي', icon: Archive },
                        { key: 'clear', label: 'مسح', icon: Trash2 },
                      ] as const).map(tab => {
                        const Icon = tab.icon
                        return (
                          <button
                            key={tab.key}
                            onClick={() => setActiveDataTab(tab.key)}
                            className={cn(
                              'flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all',
                              activeDataTab === tab.key
                                ? 'bg-primary text-primary-foreground shadow'
                                : 'bg-muted text-muted-foreground hover:bg-muted/80 hover:text-foreground'
                            )}
                          >
                            <Icon className="w-4 h-4" />
                            {tab.label}
                          </button>
                        )
                      })}
                    </div>

                    <Separator />

                    {/* ── Export Tab ─────────────────────────────────────────────── */}
                    {activeDataTab === 'export' && (
                      <div className="space-y-4 animate-fade-in">
                        <div className="flex items-center justify-between">
                          <p className="text-sm text-muted-foreground">تصدير الجداول كملفات JSON أو CSV</p>
                          <div className="flex gap-2">
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleExportAll('json')}
                              disabled={exportState.loading || !isConfigured}
                            >
                              <FileDown className="w-4 h-4 mr-2" />
                              تصدير الكل (JSON)
                            </Button>
                          </div>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                          {EXPORTABLE_TABLES.map(table => {
                            const Icon = table.icon
                            const isExporting = exportState.loading && exportState.table === table.key
                            return (
                              <div key={table.key} className="p-4 rounded-lg border hover:border-primary/30 transition-colors">
                                <div className="flex items-center gap-2 mb-3">
                                  <Icon className="w-5 h-5 text-primary" />
                                  <span className="text-sm font-medium">{table.label}</span>
                                </div>
                                {isExporting && (
                                  <div className="mb-3">
                                    <Progress value={exportState.progress} className="h-1.5" />
                                    <p className="text-[10px] text-muted-foreground mt-1 text-center">
                                      {exportState.progress}%
                                    </p>
                                  </div>
                                )}
                                <div className="flex gap-2">
                                  <Button
                                    variant="outline"
                                    size="sm"
                                    className="flex-1"
                                    onClick={() => handleExport(table.key, 'json')}
                                    disabled={exportState.loading || !isConfigured}
                                  >
                                    {isExporting && exportState.format === 'json'
                                      ? <Loader2 className="w-3 h-3 animate-spin" />
                                      : <FileText className="w-3 h-3 mr-1" />}
                                    JSON
                                  </Button>
                                  <Button
                                    variant="outline"
                                    size="sm"
                                    className="flex-1"
                                    onClick={() => handleExport(table.key, 'csv')}
                                    disabled={exportState.loading || !isConfigured}
                                  >
                                    {isExporting && exportState.format === 'csv'
                                      ? <Loader2 className="w-3 h-3 animate-spin" />
                                      : <FileText className="w-3 h-3 mr-1" />}
                                    CSV
                                  </Button>
                                </div>
                              </div>
                            )
                          })}
                        </div>

                        {exportState.loading && exportState.table === 'all' && (
                          <div className="p-4 rounded-lg bg-primary/5 border border-primary/20">
                            <div className="flex items-center gap-3 mb-2">
                              <Loader2 className="w-4 h-4 animate-spin text-primary" />
                              <span className="text-sm font-medium">جاري التصدير الشامل...</span>
                            </div>
                            <Progress value={exportState.progress} className="h-2" />
                            <p className="text-xs text-muted-foreground mt-1">{exportState.progress}%</p>
                          </div>
                        )}
                      </div>
                    )}

                    {/* ── Import Tab ────────────────────────────────────────────── */}
                    {activeDataTab === 'import' && (
                      <div className="space-y-4 animate-fade-in">
                        {!isConfigured ? (
                          <div className="text-center py-8 text-muted-foreground">
                            <p className="text-sm">يرجى إعداد Supabase أولاً</p>
                          </div>
                        ) : (
                          <>
                            <div className="flex items-center justify-between">
                              <p className="text-sm text-muted-foreground">استيراد البيانات من ملفات JSON أو CSV</p>
                              <Select
                                value={importState.conflictStrategy}
                                onValueChange={(v) => setImportState(s => ({ ...s, conflictStrategy: v as 'skip' | 'overwrite' }))}
                              >
                                <SelectTrigger className="w-40">
                                  <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                  <SelectItem value="skip">تخطي المكررات</SelectItem>
                                  <SelectItem value="overwrite">استبدال المكررات</SelectItem>
                                </SelectContent>
                              </Select>
                            </div>

                            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                              {EXPORTABLE_TABLES.map(table => {
                                const Icon = table.icon
                                const isActive = importState.table === table.key && importState.preview.length > 0
                                return (
                                  <div key={table.key} className="p-4 rounded-lg border hover:border-primary/30 transition-colors">
                                    <div className="flex items-center gap-2 mb-3">
                                      <Icon className="w-5 h-5 text-emerald-600" />
                                      <span className="text-sm font-medium">{table.label}</span>
                                    </div>
                                    <input
                                      ref={isActive ? fileInputRef : undefined}
                                      type="file"
                                      accept=".json,.csv"
                                      className="hidden"
                                      onChange={(e) => {
                                        const file = e.target.files?.[0]
                                        if (file) handleImportFile(table.key, file)
                                        e.target.value = ''
                                      }}
                                      id={`import-${table.key}`}
                                    />
                                    <label htmlFor={`import-${table.key}`}>
                                      <Button
                                        variant="outline"
                                        size="sm"
                                        className="w-full cursor-pointer"
                                        asChild
                                      >
                                        <span>
                                          <Upload className="w-3 h-3 mr-1" />
                                          اختيار ملف
                                        </span>
                                      </Button>
                                    </label>
                                  </div>
                                )
                              })}
                            </div>

                            {/* Import Preview */}
                            {importState.preview.length > 0 && (
                              <div className="space-y-3 animate-fade-in">
                                <div className="flex items-center justify-between">
                                  <h4 className="text-sm font-medium flex items-center gap-2">
                                    <ListChecks className="w-4 h-4 text-emerald-600" />
                                    معاينة ({importState.preview.length} من {importFullDataRef.current.length} سجل)
                                  </h4>
                                  <div className="flex gap-2">
                                    <Button
                                      variant="outline"
                                      size="sm"
                                      onClick={() => setImportState(s => ({ ...s, preview: [], table: '' }))}
                                    >
                                      <X className="w-3 h-3 mr-1" />
                                      إلغاء
                                    </Button>
                                    <Button
                                      size="sm"
                                      onClick={handleImportConfirm}
                                      disabled={importState.loading}
                                      className="bg-emerald-600 hover:bg-emerald-700"
                                    >
                                      {importState.loading
                                        ? <Loader2 className="w-3 h-3 mr-1 animate-spin" />
                                        : <CheckCircle2 className="w-3 h-3 mr-1" />}
                                      استيراد ({importFullDataRef.current.length} سجل)
                                    </Button>
                                  </div>
                                </div>

                                {importState.loading && importState.progress > 0 && (
                                  <Progress value={importState.progress} className="h-2" />
                                )}

                                <div className="overflow-x-auto rounded-lg border">
                                  <table className="w-full text-xs">
                                    <thead>
                                      <tr className="bg-muted/50">
                                        {Object.keys(importState.preview[0]).slice(0, 6).map(key => (
                                          <th key={key} className="px-3 py-2 text-right font-medium">{key}</th>
                                        ))}
                                      </tr>
                                    </thead>
                                    <tbody>
                                      {importState.preview.map((row, i) => (
                                        <tr key={i} className="border-t">
                                          {Object.values(row).slice(0, 6).map((val, j) => (
                                            <td key={j} className="px-3 py-2 max-w-[200px] truncate">
                                              {val === null ? <span className="text-muted-foreground">null</span> : String(val)}
                                            </td>
                                          ))}
                                        </tr>
                                      ))}
                                    </tbody>
                                  </table>
                                </div>
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    )}

                    {/* ── Backup Tab ────────────────────────────────────────────── */}
                    {activeDataTab === 'backup' && (
                      <div className="space-y-4 animate-fade-in">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                          {/* Create Backup */}
                          <div className="p-6 rounded-lg border text-center space-y-3">
                            <Archive className="w-10 h-10 mx-auto text-amber-600" />
                            <h4 className="font-medium">إنشاء نسخة احتياطية</h4>
                            <p className="text-xs text-muted-foreground">
                              إنشاء نسخة JSON شاملة من جميع البيانات
                            </p>
                            <Button
                              onClick={handleCreateBackup}
                              disabled={backupState.loading || !isConfigured}
                              className="w-full"
                            >
                              {backupState.loading
                                ? <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                                : <Download className="w-4 h-4 mr-2" />}
                              إنشاء نسخة احتياطية
                            </Button>
                          </div>

                          {/* Restore Backup */}
                          <div className="p-6 rounded-lg border text-center space-y-3">
                            <RotateCcw className="w-10 h-10 mx-auto text-blue-600" />
                            <h4 className="font-medium">استعادة نسخة احتياطية</h4>
                            <p className="text-xs text-muted-foreground">
                              رفع ملف نسخة احتياطية واستعادة البيانات
                            </p>
                            <input
                              ref={restoreInputRef}
                              type="file"
                              accept=".json"
                              className="hidden"
                              onChange={(e) => {
                                const file = e.target.files?.[0]
                                if (file) handleRestoreBackup(file)
                                e.target.value = ''
                              }}
                              id="restore-file"
                            />
                            <label htmlFor="restore-file" className="block">
                              <Button
                                variant="outline"
                                className="w-full cursor-pointer"
                                disabled={backupState.loading || !isConfigured}
                                asChild
                              >
                                <span>
                                  <FileUp className="w-4 h-4 mr-2" />
                                  اختيار ملف النسخة الاحتياطية
                                </span>
                              </Button>
                            </label>
                          </div>
                        </div>

                        {/* Backup Progress */}
                        {backupState.loading && (
                          <div className="p-4 rounded-lg bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800">
                            <div className="flex items-center gap-3 mb-2">
                              <Loader2 className="w-4 h-4 animate-spin text-amber-600" />
                              <span className="text-sm font-medium text-amber-800 dark:text-amber-300">
                                {backupState.phase}
                              </span>
                            </div>
                            <Progress value={backupState.progress} className="h-2" indicatorClassName="bg-amber-500" />
                            <p className="text-xs text-amber-700 dark:text-amber-400 mt-1">{backupState.progress}%</p>
                          </div>
                        )}

                        {backupState.phase && !backupState.loading && backupState.progress === 100 && (
                          <div className="p-4 rounded-lg bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800">
                            <div className="flex items-center gap-2">
                              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                              <span className="text-sm text-emerald-800 dark:text-emerald-300">{backupState.phase}</span>
                            </div>
                          </div>
                        )}
                      </div>
                    )}

                    {/* ── Clear Tab ─────────────────────────────────────────────── */}
                    {activeDataTab === 'clear' && (
                      <div className="space-y-4 animate-fade-in">
                        <div className="p-4 rounded-lg bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800">
                          <div className="flex items-start gap-2">
                            <AlertTriangle className="w-5 h-5 text-red-600 shrink-0 mt-0.5" />
                            <div>
                              <p className="text-sm font-medium text-red-800 dark:text-red-300">منطقة الخطر</p>
                              <p className="text-xs text-red-700 dark:text-red-400 mt-1">
                                مسح البيانات عملية لا يمكن التراجع عنها. تأكد من أخذ نسخة احتياطية قبل المتابعة.
                              </p>
                            </div>
                          </div>
                        </div>

                        {clearState.progress === 100 && (
                          <div className="p-4 rounded-lg bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800">
                            <div className="flex items-center gap-2">
                              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                              <span className="text-sm text-emerald-800 dark:text-emerald-300">تم مسح البيانات بنجاح</span>
                            </div>
                          </div>
                        )}

                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                          {EXPORTABLE_TABLES.map(table => {
                            const Icon = table.icon
                            const isClearing = clearState.loading && clearState.table === table.key
                            return (
                              <div key={table.key} className="p-4 rounded-lg border border-red-200/50 dark:border-red-800/50">
                                <div className="flex items-center gap-2 mb-3">
                                  <Icon className="w-5 h-5 text-red-500" />
                                  <span className="text-sm font-medium">{table.label}</span>
                                </div>
                                <Button
                                  variant="destructive"
                                  size="sm"
                                  className="w-full"
                                  disabled={clearState.loading || !isConfigured}
                                  onClick={() => {
                                    setClearTableTarget(table.key)
                                    setShowClearDialog(true)
                                  }}
                                >
                                  {isClearing
                                    ? <Loader2 className="w-3 h-3 mr-1 animate-spin" />
                                    : <Trash2 className="w-3 h-3 mr-1" />}
                                  مسح {table.label}
                                </Button>
                              </div>
                            )
                          })}
                        </div>
                      </div>
                    )}
                  </CardContent>
                </Card>
              </div>
            )}

            {/* ─── System Info ─────────────────────────────────────────────────── */}
            {activeSection === 'system' && (
              <div className="space-y-6 animate-fade-in">
                <Card>
                  <CardHeader>
                    <CardTitle className="font-heading flex items-center gap-2">
                      <Server className="w-5 h-5" />
                      معلومات النظام
                    </CardTitle>
                    <CardDescription>حالة النظام والإحصائيات</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-6">
                    {/* System Overview */}
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                      {[
                        { label: 'الإصدار', value: systemInfo.version, icon: Info },
                        { label: 'وقت التشغيل', value: systemInfo.uptime || '--', icon: Clock },
                        { label: 'التخزين', value: systemInfo.storageUsed, icon: HardDrive },
                        {
                          label: 'حالة API',
                          value: systemInfo.apiStatus === 'online' ? 'متصل' : systemInfo.apiStatus === 'checking' ? 'جاري الفحص...' : 'غير متصل',
                          icon: Wifi,
                          color: systemInfo.apiStatus === 'online' ? 'text-emerald-600' : systemInfo.apiStatus === 'checking' ? 'text-amber-600' : 'text-red-600',
                        },
                      ].map((item, i) => {
                        const Icon = item.icon
                        return (
                          <div key={i} className="p-4 rounded-lg border bg-card">
                            <Icon className={cn('w-5 h-5 mb-2', item.color || 'text-muted-foreground')} />
                            <p className="text-xs text-muted-foreground">{item.label}</p>
                            <p className={cn('text-lg font-semibold mt-1', item.color)}>{item.value}</p>
                          </div>
                        )
                      })}
                    </div>

                    <Separator />

                    {/* Database Stats */}
                    <div className="space-y-3">
                      <h4 className="text-sm font-medium flex items-center gap-2">
                        <Database className="w-4 h-4" />
                        إحصائيات قاعدة البيانات
                      </h4>
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                        {[
                          { label: 'المستخدمين', count: systemInfo.dbStats.profiles, icon: Users, color: 'bg-blue-500' },
                          { label: 'إرساليات النماذج', count: systemInfo.dbStats.submissions, icon: ClipboardList, color: 'bg-emerald-500' },
                          { label: 'النماذج', count: systemInfo.dbStats.forms, icon: FileText, color: 'bg-purple-500' },
                          { label: 'النواقص', count: systemInfo.dbStats.shortages, icon: PackageX, color: 'bg-amber-500' },
                        ].map((stat, i) => {
                          const Icon = stat.icon
                          return (
                            <div key={i} className="flex items-center gap-3 p-3 rounded-lg border">
                              <div className={cn('w-10 h-10 rounded-lg flex items-center justify-center', stat.color)}>
                                <Icon className="w-5 h-5 text-white" />
                              </div>
                              <div>
                                <p className="text-lg font-bold">{stat.count.toLocaleString()}</p>
                                <p className="text-xs text-muted-foreground">{stat.label}</p>
                              </div>
                            </div>
                          )
                        })}
                      </div>
                    </div>

                    <Separator />

                    {/* Refresh Button */}
                    <div className="flex justify-end">
                      <Button variant="outline" size="sm" onClick={loadSystemInfo}>
                        <RefreshCw className="w-4 h-4 mr-2" />
                        تحديث المعلومات
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}

            {/* ═══ Save Button ═══ */}
            <div className="flex items-center justify-end gap-3 sticky bottom-4">
              <div className={cn(
                'flex items-center gap-2 px-4 py-2 rounded-lg bg-background border shadow-lg transition-all',
                saved ? 'opacity-100' : 'opacity-0'
              )}>
                <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                <span className="text-sm text-emerald-600 font-medium">تم الحفظ بنجاح</span>
              </div>
              <Button onClick={handleSave} className="gap-2 shadow-lg">
                <Save className="w-4 h-4" />
                حفظ الإعدادات
              </Button>
            </div>
          </div>
        </div>
      </div>

      {/* ═══ Clear Data Confirmation Dialog ═══ */}
      <Dialog open={showClearDialog} onOpenChange={setShowClearDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="text-red-600 flex items-center gap-2">
              <AlertTriangle className="w-5 h-5" />
              تأكيد مسح البيانات
            </DialogTitle>
            <DialogDescription>
              أنت على وشك مسح جميع سجلات جدول <strong>{EXPORTABLE_TABLES.find(t => t.key === clearTableTarget)?.label}</strong>.
              هذا الإجراء لا يمكن التراجع عنه.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-3 py-4">
            <p className="text-sm text-muted-foreground">
              اكتب <strong className="text-foreground font-mono bg-muted px-1.5 py-0.5 rounded">تأكيد</strong> في الحقل أدناه للمتابعة:
            </p>
            <Input
              value={clearConfirmText}
              onChange={(e) => setClearConfirmText(e.target.value)}
              placeholder="تأكيد"
              className="text-center"
              dir="rtl"
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => { setShowClearDialog(false); setClearConfirmText('') }}>
              إلغاء
            </Button>
            <Button
              variant="destructive"
              onClick={handleClearData}
              disabled={clearConfirmText !== 'تأكيد'}
            >
              <Trash2 className="w-4 h-4 mr-2" />
              مسح البيانات
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
