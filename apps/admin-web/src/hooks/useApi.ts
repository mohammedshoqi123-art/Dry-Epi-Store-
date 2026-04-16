import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase, isConfigured } from '@/lib/supabase'
import type { UserRole, SubmissionStatus } from '@/types/database'

// ═══ CAMPAIGN HELPER ═══
// form_submissions doesn't have campaign_type — it's on the forms table.
// To filter submissions by campaign, we first resolve form IDs.

/**
 * Get form IDs that belong to a specific campaign type.
 * Returns null if no campaign filter (meaning "all").
 */
async function getCampaignFormIds(campaignType?: string): Promise<string[] | null> {
  if (!campaignType || campaignType === 'all') return null

  const { data, error } = await supabase
    .from('forms')
    .select('id')
    .eq('campaign_type', campaignType)
    .is('deleted_at', null)

  if (error || !data) return null
  return data.map(f => f.id)
}

/**
 * Apply campaign filter to a Supabase query on form_submissions.
 * Uses the form_id foreign key to filter by campaign.
 */
async function applyCampaignFilter(
  query: any,
  campaignType?: string
): Promise<{ query: any; formIds: string[] | null }> {
  const formIds = await getCampaignFormIds(campaignType)
  if (formIds && formIds.length > 0) {
    return { query: query.in('form_id', formIds), formIds }
  }
  return { query, formIds: null }
}

/**
 * Apply campaign filter to supply_shortages via form_submissions → forms.
 * shortages link to submissions, which link to forms with campaign_type.
 */
async function applyShortageCampaignFilter(
  query: any,
  campaignType?: string
): Promise<any> {
  if (!campaignType || campaignType === 'all') return query

  // Get submission IDs that belong to the campaign
  const formIds = await getCampaignFormIds(campaignType)
  if (!formIds || formIds.length === 0) return query

  const { data: submissions } = await supabase
    .from('form_submissions')
    .select('id')
    .in('form_id', formIds)
    .is('deleted_at', null)
    .limit(10000)

  if (!submissions || submissions.length === 0) {
    // No submissions for this campaign → return empty result
    return query.eq('id', '00000000-0000-0000-0000-000000000000')
  }

  const submissionIds = submissions.map(s => s.id)
  return query.in('submission_id', submissionIds)
}

// ==================== AUTH ====================

export function useAuth() {
  return useQuery({
    queryKey: ['auth'],
    queryFn: async () => {
      if (!isConfigured) return null
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) return null

      const { data: profile } = await supabase
        .from('profiles')
        .select('*, governorates(name_ar), districts(name_ar)')
        .eq('id', session.user.id)
        .single()

      return { session, profile }
    },
    retry: 0,
    staleTime: 30000,
    enabled: isConfigured,
  })
}

export function useSignIn() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async ({ email, password }: { email: string; password: string }) => {
      const { data, error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) throw error
      return data
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['auth'] })
    },
  })
}

export function useSignOut() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async () => {
      await supabase.auth.signOut()
    },
    onSuccess: () => {
      queryClient.clear()
    },
  })
}

// ==================== DASHBOARD ====================

export function useDashboardStats(campaignType?: string) {
  return useQuery({
    queryKey: ['dashboard-stats', campaignType],
    queryFn: async () => {
      if (!isConfigured) return null

      // Resolve form IDs for campaign filtering
      const formIds = await getCampaignFormIds(campaignType)

      // Helper to apply campaign filter to form_submissions queries
      const applyFormFilter = (q: any) => {
        if (formIds && formIds.length > 0) return q.in('form_id', formIds)
        return q
      }

      // Helper to apply campaign filter to forms queries
      const applyFormsFilter = (q: any) => {
        if (campaignType && campaignType !== 'all') return q.eq('campaign_type', campaignType)
        return q
      }

      // Helper for shortages — filter via submission_id
      const applyShortageFilter = async (baseQuery: any) => {
        if (!formIds || formIds.length === 0) return baseQuery

        const { data: submissions } = await supabase
          .from('form_submissions')
          .select('id')
          .in('form_id', formIds)
          .is('deleted_at', null)
          .limit(10000)

        if (!submissions || submissions.length === 0) {
          return baseQuery.eq('id', '00000000-0000-0000-0000-000000000000')
        }

        return baseQuery.in('submission_id', submissions.map(s => s.id))
      }

      // Use Promise.allSettled to handle individual failures gracefully
      const [usersRes, submissionsRes, formsRes, shortagesRes] = await Promise.allSettled([
        supabase.from('profiles').select('id, is_active, role, created_at', { count: 'exact' }),
        applyFormFilter(
          supabase.from('form_submissions').select('id, status, created_at', { count: 'exact' })
        ),
        applyFormsFilter(
          supabase.from('forms').select('id, is_active', { count: 'exact' })
        ),
        (async () => {
          let q = supabase.from('supply_shortages').select('id, severity, is_resolved', { count: 'exact' })
          return applyShortageFilter(q)
        })(),
      ])

      const users = usersRes.status === 'fulfilled' ? (usersRes.value.data || []) : []
      const submissions = submissionsRes.status === 'fulfilled' ? (submissionsRes.value.data || []) : []
      const forms = formsRes.status === 'fulfilled' ? (formsRes.value.data || []) : []
      const shortages = shortagesRes.status === 'fulfilled' ? (shortagesRes.value.data || []) : []

      const now = new Date()
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
      const weekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000)

      const submissionsToday = submissions.filter((s: any) => new Date(s.created_at) >= today).length
      const submissionsThisWeek = submissions.filter((s: any) => new Date(s.created_at) >= weekAgo).length
      const approved = submissions.filter((s: any) => s.status === 'approved').length
      const pending = submissions.filter((s: any) => s.status === 'submitted' || s.status === 'reviewed').length

      return {
        total_users: users.length,
        active_users: users.filter((u: any) => u.is_active).length,
        total_submissions: submissions.length,
        pending_submissions: pending,
        approved_submissions: approved,
        rejected_submissions: submissions.filter((s: any) => s.status === 'rejected').length,
        draft_submissions: submissions.filter((s: any) => s.status === 'draft').length,
        total_forms: forms.length,
        active_forms: forms.filter((f: any) => f.is_active).length,
        total_shortages: shortages.length,
        critical_shortages: shortages.filter((s: any) => s.severity === 'critical' && !s.is_resolved).length,
        submissions_today: submissionsToday,
        submissions_this_week: submissionsThisWeek,
        submissions_trend: 12.5,
        approval_rate: submissions.length > 0 ? (approved / submissions.length) * 100 : 0,
        unread_notifications: 0,
      }
    },
    refetchInterval: isConfigured ? 30000 : false,
    enabled: isConfigured,
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
    staleTime: 15000,
  })
}

export function useSubmissionsChart(campaignType?: string) {
  return useQuery({
    queryKey: ['submissions-chart', campaignType],
    queryFn: async () => {
      let query = supabase
        .from('form_submissions')
        .select('status, created_at')
        .order('created_at', { ascending: true })

      // Apply campaign filter
      const formIds = await getCampaignFormIds(campaignType)
      if (formIds && formIds.length > 0) {
        query = query.in('form_id', formIds)
      }

      const { data } = await query

      if (!data) return []

      const grouped: Record<string, { date: string; approved: number; rejected: number; pending: number }> = {}
      const now = new Date()

      for (let i = 29; i >= 0; i--) {
        const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000)
        const key = d.toISOString().split('T')[0]
        grouped[key] = { date: key, approved: 0, rejected: 0, pending: 0 }
      }

      data.forEach((s) => {
        const key = s.created_at.split('T')[0]
        if (grouped[key]) {
          if (s.status === 'approved') grouped[key].approved++
          else if (s.status === 'rejected') grouped[key].rejected++
          else grouped[key].pending++
        }
      })

      return Object.values(grouped)
    },
    enabled: isConfigured,
  })
}

export function useGovernorateStats(campaignType?: string) {
  return useQuery({
    queryKey: ['governorate-stats', campaignType],
    queryFn: async () => {
      const { data: governorates } = await supabase
        .from('governorates')
        .select('id, name_ar')
        .eq('is_active', true)
        .order('name_ar')

      if (!governorates) return []

      // Resolve form IDs for campaign filtering
      const formIds = await getCampaignFormIds(campaignType)

      const stats = await Promise.all(
        governorates.map(async (gov) => {
          let query = supabase
            .from('form_submissions')
            .select('id', { count: 'exact', head: true })
            .eq('governorate_id', gov.id)

          if (formIds && formIds.length > 0) {
            query = query.in('form_id', formIds)
          }

          const { count } = await query

          return {
            name: gov.name_ar,
            submissions: count || 0,
          }
        })
      )

      return stats.sort((a, b) => b.submissions - a.submissions)
    },
    enabled: isConfigured,
  })
}

// ==================== USERS ====================

export function useUsers(filters?: { role?: UserRole; search?: string }) {
  return useQuery({
    queryKey: ['users', filters],
    queryFn: async () => {
      let query = supabase
        .from('profiles')
        .select('*, governorates(name_ar), districts(name_ar)')
        .is('deleted_at', null)
        .order('created_at', { ascending: false })

      if (filters?.role) {
        query = query.eq('role', filters.role)
      }
      if (filters?.search) {
        query = query.or(`full_name.ilike.%${filters.search}%,email.ilike.%${filters.search}%`)
      }

      const { data, error } = await query
      if (error) throw error
      return data
    },
    enabled: isConfigured,
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
    staleTime: 10000,
  })
}

export function useCreateUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (userData: {
      email: string; password: string; full_name: string; role: UserRole
      governorate_id?: string; district_id?: string
    }) => {
      const { data, error } = await supabase.functions.invoke('create-admin', {
        body: userData,
      })
      if (error) throw error
      return data
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
  })
}

export function useUpdateUserRole() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async ({ userId, role, governorate_id, district_id }: {
      userId: string; role: UserRole; governorate_id?: string; district_id?: string
    }) => {
      const { data, error } = await supabase.functions.invoke('admin-actions', {
        body: { action: 'update_role', user_id: userId, role, governorate_id, district_id },
      })
      if (error) throw error
      return data
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
  })
}

export function useToggleUserActive() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async ({ userId, isActive }: { userId: string; isActive: boolean }) => {
      const { data, error } = await supabase.functions.invoke('admin-actions', {
        body: { action: 'toggle_active', user_id: userId, is_active: isActive },
      })
      if (error) throw error
      return data
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
  })
}

export function useDeleteUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (userId: string) => {
      const { data, error } = await supabase.functions.invoke('admin-actions', {
        body: { action: 'delete_user', user_id: userId },
      })
      if (error) throw error
      return data
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
  })
}

// ==================== FORMS ====================

export function useForms(filters?: { search?: string; page?: number; pageSize?: number; campaignType?: string }) {
  return useQuery({
    queryKey: ['forms', filters],
    queryFn: async () => {
      const page = filters?.page || 1
      const pageSize = filters?.pageSize || 50

      let query = supabase
        .from('forms')
        .select('*', { count: 'exact' })
        .is('deleted_at', null)
        .order('created_at', { ascending: false })
        .range((page - 1) * pageSize, page * pageSize - 1)

      if (filters?.search) {
        query = query.or(`title_ar.ilike.%${filters.search}%,title_en.ilike.%${filters.search}%`)
      }
      if (filters?.campaignType && filters.campaignType !== 'all') {
        query = query.eq('campaign_type', filters.campaignType)
      }

      const { data, error, count } = await query
      if (error) throw error
      return { data: data || [], count: count || 0 }
    },
    enabled: isConfigured,
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
    staleTime: 10000,
  })
}

export function useFormSubmissionCounts(campaignType?: string) {
  return useQuery({
    queryKey: ['form-submission-counts', campaignType],
    queryFn: async () => {
      let query = supabase
        .from('form_submissions')
        .select('form_id, status')
        .is('deleted_at', null)

      // Apply campaign filter
      const formIds = await getCampaignFormIds(campaignType)
      if (formIds && formIds.length > 0) {
        query = query.in('form_id', formIds)
      }

      const { data, error } = await query
      if (error) throw error

      const counts: Record<string, { total: number; approved: number; pending: number; rejected: number }> = {}
      for (const row of data || []) {
        if (!counts[row.form_id]) {
          counts[row.form_id] = { total: 0, approved: 0, pending: 0, rejected: 0 }
        }
        counts[row.form_id].total++
        if (row.status === 'approved') counts[row.form_id].approved++
        else if (row.status === 'rejected') counts[row.form_id].rejected++
        else if (row.status === 'submitted' || row.status === 'reviewed') counts[row.form_id].pending++
      }
      return counts
    },
    enabled: isConfigured,
    staleTime: 30000,
  })
}

export function useCreateForm() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (form: {
      title_ar: string; title_en: string; description_ar?: string; description_en?: string
      schema: Record<string, unknown>; requires_gps?: boolean; requires_photo?: boolean
      max_photos?: number; allowed_roles?: UserRole[]; campaign_type?: string; is_active?: boolean
    }) => {
      const { data: { session } } = await supabase.auth.getSession()
      const { data, error } = await supabase
        .from('forms')
        .insert({ ...form, created_by: session?.user.id })
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['forms'] })
      queryClient.invalidateQueries({ queryKey: ['form-submission-counts'] })
    },
  })
}

export function useUpdateForm() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, ...updates }: { id: string } & Partial<{
      title_ar: string; title_en: string; description_ar: string; description_en: string
      schema: Record<string, unknown>; is_active: boolean
      requires_gps: boolean; requires_photo: boolean; max_photos: number
      allowed_roles: UserRole[]; campaign_type: string
    }>) => {
      const { data, error } = await supabase
        .from('forms')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['forms'] })
      queryClient.invalidateQueries({ queryKey: ['form-submission-counts'] })
    },
  })
}

export function useDeleteForm() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (formId: string) => {
      const { error } = await supabase
        .from('forms')
        .update({ deleted_at: new Date().toISOString() })
        .eq('id', formId)
      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['forms'] })
      queryClient.invalidateQueries({ queryKey: ['form-submission-counts'] })
    },
  })
}

// ==================== SUBMISSIONS ====================

export function useSubmissions(filters?: {
  status?: SubmissionStatus; formId?: string; governorateId?: string; search?: string
  page?: number; pageSize?: number; campaignType?: string
}) {
  return useQuery({
    queryKey: ['submissions', filters],
    queryFn: async () => {
      const page = filters?.page || 1
      const pageSize = filters?.pageSize || 20

      let query = supabase
        .from('form_submissions')
        .select('*, forms(title_ar, campaign_type), profiles(full_name, email)', { count: 'exact' })
        .is('deleted_at', null)
        .order('created_at', { ascending: false })
        .range((page - 1) * pageSize, page * pageSize - 1)

      if (filters?.status) query = query.eq('status', filters.status)
      if (filters?.formId) query = query.eq('form_id', filters.formId)
      if (filters?.governorateId) query = query.eq('governorate_id', filters.governorateId)

      // Campaign filter via form_id
      if (filters?.campaignType && filters.campaignType !== 'all') {
        const formIds = await getCampaignFormIds(filters.campaignType)
        if (formIds && formIds.length > 0) {
          query = query.in('form_id', formIds)
        } else {
          // No forms for this campaign → return empty
          return { data: [], count: 0 }
        }
      }

      const { data, error, count } = await query
      if (error) throw error
      return { data: data || [], count: count || 0 }
    },
    enabled: isConfigured,
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
    staleTime: 10000,
  })
}

export function useUpdateSubmissionStatus() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, status, review_notes }: {
      id: string; status: SubmissionStatus; review_notes?: string
    }) => {
      const { data: { session } } = await supabase.auth.getSession()
      const { data, error } = await supabase
        .from('form_submissions')
        .update({
          status,
          review_notes,
          reviewed_by: session?.user.id,
          reviewed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['submissions'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard-stats'] })
    },
  })
}

// ==================== GOVERNORATES & DISTRICTS ====================

export function useGovernorates() {
  return useQuery({
    queryKey: ['governorates'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('governorates')
        .select('*')
        .eq('is_active', true)
        .order('name_ar')
      if (error) throw error
      return data
    },
    enabled: isConfigured,
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
    staleTime: 60000,
  })
}

export function useDistricts(governorateId?: string) {
  return useQuery({
    queryKey: ['districts', governorateId],
    queryFn: async () => {
      let query = supabase.from('districts').select('*').eq('is_active', true).order('name_ar')
      if (governorateId) query = query.eq('governorate_id', governorateId)
      const { data, error } = await query
      if (error) throw error
      return data
    },
    enabled: !!governorateId,
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
  })
}

// ==================== AUDIT LOGS ====================

export function useAuditLogs(filters?: { userId?: string; action?: string; page?: number }) {
  return useQuery({
    queryKey: ['audit-logs', filters],
    queryFn: async () => {
      const page = filters?.page || 1
      const pageSize = 50

      let query = supabase
        .from('audit_logs')
        .select('*, profiles(full_name, email)', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range((page - 1) * pageSize, page * pageSize - 1)

      if (filters?.userId) query = query.eq('user_id', filters.userId)
      if (filters?.action) query = query.eq('action', filters.action)

      const { data, error, count } = await query
      if (error) throw error
      return { data: data || [], count: count || 0 }
    },
    enabled: isConfigured,
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
    staleTime: 10000,
  })
}

// ==================== SHORTAGES ====================

export function useShortages(campaignType?: string) {
  return useQuery({
    queryKey: ['shortages', campaignType],
    queryFn: async () => {
      let query = supabase
        .from('supply_shortages')
        .select('*, governorates(name_ar), districts(name_ar), profiles(full_name), form_submissions(form_id, forms(title_ar))')
        .is('deleted_at', null)
        .order('created_at', { ascending: false })

      // Campaign filter via submission_id → form_submissions → forms
      query = await applyShortageCampaignFilter(query, campaignType)
      const { data, error } = await query
      if (error) throw error
      return data
    },
    enabled: isConfigured,
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
    staleTime: 10000,
  })
}

// ==================== CHAT ====================

export function useChatMessages(room = 'general') {
  return useQuery({
    queryKey: ['chat-messages', room],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('chat_messages')
        .select('*')
        .eq('room', room)
        .order('created_at', { ascending: true })
        .limit(100)
      if (error) throw error
      return data
    },
    enabled: isConfigured,
    refetchInterval: isConfigured ? 5000 : false,
  })
}

export function useSendChatMessage() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ message, room = 'general' }: { message: string; room?: string }) => {
      const { data: { session } } = await supabase.auth.getSession()
      const { data: profile } = await supabase.from('profiles').select('full_name').eq('id', session?.user.id).single()
      const { data, error } = await supabase
        .from('chat_messages')
        .insert({
          sender_id: session?.user.id,
          sender_name: profile?.full_name || 'مستخدم',
          content: message,
          room,
        })
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['chat-messages'] }),
  })
}

// ==================== SHORTAGES (resolve) ====================

export function useResolveShortage() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (shortageId: string) => {
      const { data: { session } } = await supabase.auth.getSession()
      const { data, error } = await supabase
        .from('supply_shortages')
        .update({
          is_resolved: true,
          resolved_at: new Date().toISOString(),
          resolved_by: session?.user.id,
        })
        .eq('id', shortageId)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['shortages'] })
      qc.invalidateQueries({ queryKey: ['dashboard-stats'] })
    },
  })
}

// ==================== NOTIFICATIONS ====================

export function useNotifications() {
  return useQuery({
    queryKey: ['notifications'],
    queryFn: async () => {
      const { data: { session } } = await supabase.auth.getSession()
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('recipient_id', session?.user?.id || '00000000-0000-0000-0000-000000000000')
        .order('created_at', { ascending: false })
        .limit(50)
      if (error) throw error
      return data
    },
    enabled: isConfigured,
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
    staleTime: 10000,
  })
}

export function useMarkNotificationRead() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (notificationId: string) => {
      const { data, error } = await supabase
        .from('notifications')
        .update({ is_read: true, read_at: new Date().toISOString() })
        .eq('id', notificationId)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notifications'] }),
  })
}

export function useMarkAllNotificationsRead() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async () => {
      const { data: { session } } = await supabase.auth.getSession()
      const { error } = await supabase
        .from('notifications')
        .update({ is_read: true, read_at: new Date().toISOString() })
        .eq('recipient_id', session?.user.id)
        .eq('is_read', false)
      if (error) throw error
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notifications'] }),
  })
}

export function useDeleteNotification() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (notificationId: string) => {
      const { error } = await supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId)
      if (error) throw error
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notifications'] }),
  })
}

export function useDeleteAllNotifications() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async () => {
      const { data: { session } } = await supabase.auth.getSession()
      const { error } = await supabase
        .from('notifications')
        .delete()
        .eq('recipient_id', session?.user.id || '00000000-0000-0000-0000-000000000000')
      if (error) throw error
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notifications'] }),
  })
}

export function useToggleNotificationRead() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, isRead }: { id: string; isRead: boolean }) => {
      const { data, error } = await supabase
        .from('notifications')
        .update({
          is_read: !isRead,
          read_at: !isRead ? new Date().toISOString() : null,
        })
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notifications'] }),
  })
}

export function useSendNotification() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (params: {
      title: string
      body: string
      type?: string
      category?: string
      target: 'all' | 'admin' | 'field' | 'governorate'
      governorate_id?: string
    }) => {
      const { data: { session } } = await supabase.auth.getSession()
      // Get recipients based on target
      let recipientQuery = supabase
        .from('profiles')
        .select('id')
        .eq('is_active', true)
        .is('deleted_at', null)

      if (params.target === 'admin') {
        recipientQuery = recipientQuery.in('role', ['admin', 'central'])
      } else if (params.target === 'field') {
        recipientQuery = recipientQuery.in('role', ['governorate', 'district', 'data_entry'])
      } else if (params.target === 'governorate' && params.governorate_id) {
        recipientQuery = recipientQuery.eq('governorate_id', params.governorate_id)
      }

      const { data: recipients, error: recError } = await recipientQuery
      if (recError) throw recError
      if (!recipients || recipients.length === 0) throw new Error('لا يوجد مستلمين')

      // Batch insert
      const notifications = recipients.map(r => ({
        recipient_id: r.id,
        title: params.title,
        body: params.body,
        type: params.type || 'info',
        category: params.category || 'system',
        data: {},
      }))

      for (let i = 0; i < notifications.length; i += 100) {
        const batch = notifications.slice(i, i + 100)
        const { error } = await supabase.from('notifications').insert(batch)
        if (error) throw error
      }

      return { sent_count: notifications.length }
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notifications'] }),
  })
}

// ==================== ROLE DISTRIBUTION ====================

export function useRoleDistribution() {
  return useQuery({
    queryKey: ['role-distribution'],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('role')
        .is('deleted_at', null)

      if (!data) return []

      const counts: Record<string, number> = {}
      data.forEach((u) => {
        counts[u.role] = (counts[u.role] || 0) + 1
      })

      const labels: Record<string, string> = {
        admin: 'مدير النظام',
        central: 'مركزي',
        governorate: 'محافظة',
        district: 'قضاء',
        data_entry: 'إدخال بيانات',
      }

      return Object.entries(counts).map(([role, count]) => ({
        name: labels[role] || role,
        value: count,
        role,
      }))
    },
    enabled: isConfigured,
  })
}
