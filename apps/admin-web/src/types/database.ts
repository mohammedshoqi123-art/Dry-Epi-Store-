export type UserRole = 'admin' | 'central' | 'governorate' | 'district' | 'data_entry'

export const ROLE_HIERARCHY: Record<UserRole, number> = {
  admin: 5,
  central: 4,
  governorate: 3,
  district: 2,
  data_entry: 1,
}

export const ROLE_LABELS: Record<UserRole, string> = {
  admin: 'مدير النظام',
  central: 'مركزي',
  governorate: 'محافظة',
  district: 'قضاء',
  data_entry: 'إدخال بيانات',
}

export const ROLE_COLORS: Record<UserRole, string> = {
  admin: 'bg-purple-100 text-purple-800 border-purple-200',
  central: 'bg-blue-100 text-blue-800 border-blue-200',
  governorate: 'bg-emerald-100 text-emerald-800 border-emerald-200',
  district: 'bg-amber-100 text-amber-800 border-amber-200',
  data_entry: 'bg-gray-100 text-gray-800 border-gray-200',
}

export type SubmissionStatus = 'draft' | 'submitted' | 'reviewed' | 'approved' | 'rejected'

export const STATUS_LABELS: Record<SubmissionStatus, string> = {
  draft: 'مسودة',
  submitted: 'مرسلة',
  reviewed: 'تمت المراجعة',
  approved: 'معتمدة',
  rejected: 'مرفوضة',
}

export const STATUS_COLORS: Record<SubmissionStatus, string> = {
  draft: 'bg-gray-100 text-gray-700',
  submitted: 'bg-blue-100 text-blue-700',
  reviewed: 'bg-yellow-100 text-yellow-700',
  approved: 'bg-emerald-100 text-emerald-700',
  rejected: 'bg-red-100 text-red-700',
}

export type ShortageSeverity = 'critical' | 'high' | 'medium' | 'low'

export const SEVERITY_LABELS: Record<ShortageSeverity, string> = {
  critical: 'حرج',
  high: 'عالي',
  medium: 'متوسط',
  low: 'منخفض',
}

export const SEVERITY_COLORS: Record<ShortageSeverity, string> = {
  critical: 'bg-red-100 text-red-800 border-red-200',
  high: 'bg-orange-100 text-orange-800 border-orange-200',
  medium: 'bg-yellow-100 text-yellow-800 border-yellow-200',
  low: 'bg-green-100 text-green-800 border-green-200',
}

export interface UserProfile {
  id: string
  email: string
  full_name: string
  phone?: string
  role: UserRole
  governorate_id?: string
  district_id?: string
  avatar_url?: string
  is_active: boolean
  last_login?: string
  created_at: string
  updated_at: string
  governorates?: { name_ar: string; name_en: string }
  districts?: { name_ar: string; name_en: string }
}

export interface Governorate {
  id: string
  name_ar: string
  name_en: string
  code: string
  center_lat?: number
  center_lng?: number
  population?: number
  is_active: boolean
}

export interface District {
  id: string
  governorate_id: string
  name_ar: string
  name_en: string
  code: string
  center_lat?: number
  center_lng?: number
  population?: number
  is_active: boolean
}

export interface Form {
  id: string
  title_ar: string
  title_en: string
  description_ar?: string
  description_en?: string
  schema: Record<string, unknown>
  version: number
  is_active: boolean
  requires_gps: boolean
  requires_photo: boolean
  max_photos: number
  allowed_roles: UserRole[]
  campaign_type: string
  created_by?: string
  created_at: string
  updated_at: string
}

export interface FormSubmission {
  id: string
  form_id: string
  submitted_by: string
  governorate_id?: string
  district_id?: string
  status: SubmissionStatus
  data: Record<string, unknown>
  gps_lat?: number
  gps_lng?: number
  photos: string[]
  notes?: string
  reviewed_by?: string
  reviewed_at?: string
  review_notes?: string
  submitted_at?: string
  created_at: string
  updated_at: string
  forms?: { title_ar: string }
  profiles?: { full_name: string; email: string }
}

export interface DashboardStats {
  role: UserRole
  total_users: number
  active_users: number
  total_submissions: number
  pending_submissions: number
  approved_submissions: number
  rejected_submissions: number
  draft_submissions: number
  total_forms: number
  active_forms: number
  total_shortages: number
  critical_shortages: number
  unread_notifications: number
  submissions_today: number
  submissions_this_week: number
  submissions_trend: number
  approval_rate: number
}

export interface AuditLog {
  id: string
  user_id: string
  action: string
  table_name: string
  record_id?: string
  old_data?: Record<string, unknown>
  new_data?: Record<string, unknown>
  ip_address?: string
  user_agent?: string
  created_at: string
  profiles?: { full_name: string; email: string }
}

export interface ChatMessage {
  id: string
  sender_id: string
  sender_name: string
  content: string
  room: string
  created_at: string
}

export interface Notification {
  id: string
  recipient_id: string
  title: string
  body: string
  type: string
  category: string
  data: Record<string, unknown>
  is_read: boolean
  read_at?: string
  created_at: string
}

export interface SupplyShortage {
  id: string
  submission_id?: string
  reported_by: string
  governorate_id?: string
  district_id?: string
  item_name: string
  item_category?: string
  quantity_needed?: number
  quantity_available: number
  unit: string
  severity: ShortageSeverity
  notes?: string
  is_resolved: boolean
  resolved_at?: string
  created_at: string
  governorates?: { name_ar: string }
  districts?: { name_ar: string }
  profiles?: { full_name: string }
}

// Database type for Supabase client
export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: UserProfile
        Insert: Partial<UserProfile>
        Update: Partial<UserProfile>
      }
      governorates: {
        Row: Governorate
        Insert: Partial<Governorate>
        Update: Partial<Governorate>
      }
      districts: {
        Row: District
        Insert: Partial<District>
        Update: Partial<District>
      }
      forms: {
        Row: Form
        Insert: Partial<Form>
        Update: Partial<Form>
      }
      form_submissions: {
        Row: FormSubmission
        Insert: Partial<FormSubmission>
        Update: Partial<FormSubmission>
      }
      supply_shortages: {
        Row: SupplyShortage
        Insert: Partial<SupplyShortage>
        Update: Partial<SupplyShortage>
      }
      audit_logs: {
        Row: AuditLog
        Insert: Partial<AuditLog>
        Update: Partial<AuditLog>
      }
      chat_messages: {
        Row: ChatMessage
        Insert: Partial<ChatMessage>
        Update: Partial<ChatMessage>
      }
      notifications: {
        Row: Notification
        Insert: Partial<Notification>
        Update: Partial<Notification>
      }
    }
  }
}
