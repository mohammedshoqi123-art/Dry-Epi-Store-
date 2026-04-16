import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react'

// ═══ Campaign Types ═══
export type CampaignType = 'polio_campaign' | 'integrated_activity' | 'all'

export interface CampaignOption {
  id: CampaignType
  labelAr: string
  labelEn: string
  icon: string
  color: string
}

export const CAMPAIGN_OPTIONS: CampaignOption[] = [
  {
    id: 'polio_campaign',
    labelAr: 'حملة شلل الأطفال',
    labelEn: 'Polio Campaign',
    icon: '💉',
    color: 'from-blue-500 to-blue-600',
  },
  {
    id: 'integrated_activity',
    labelAr: 'النشاط الإيصالي التكاملي',
    labelEn: 'Integrated Activity',
    icon: '🏥',
    color: 'from-emerald-500 to-emerald-600',
  },
  {
    id: 'all',
    labelAr: 'جميع الأنشطة',
    labelEn: 'All Activities',
    icon: '📋',
    color: 'from-gray-500 to-gray-600',
  },
]

const STORAGE_KEY = 'epi-admin-active-campaign'

// ═══ Context ═══
interface CampaignContextValue {
  /** Current selected campaign */
  campaign: CampaignType
  /** Set the active campaign */
  setCampaign: (campaign: CampaignType) => void
  /** Get the current campaign option details */
  currentOption: CampaignOption
  /** Whether the filter is active (not 'all') */
  isFiltered: boolean
  /** Get campaign label in Arabic */
  labelAr: string
}

const CampaignContext = createContext<CampaignContextValue | null>(null)

export function CampaignProvider({ children }: { children: ReactNode }) {
  const [campaign, setCampaignState] = useState<CampaignType>(() => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem(STORAGE_KEY)
      if (stored && ['polio_campaign', 'integrated_activity', 'all'].includes(stored)) {
        return stored as CampaignType
      }
    }
    return 'polio_campaign' // Default to polio campaign
  })

  const setCampaign = useCallback((newCampaign: CampaignType) => {
    setCampaignState(newCampaign)
    if (typeof window !== 'undefined') {
      localStorage.setItem(STORAGE_KEY, newCampaign)
    }
  }, [])

  // Persist to localStorage on change
  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, campaign)
  }, [campaign])

  const currentOption = CAMPAIGN_OPTIONS.find(o => o.id === campaign) ?? CAMPAIGN_OPTIONS[0]

  const value: CampaignContextValue = {
    campaign,
    setCampaign,
    currentOption,
    isFiltered: campaign !== 'all',
    labelAr: currentOption.labelAr,
  }

  return (
    <CampaignContext.Provider value={value}>
      {children}
    </CampaignContext.Provider>
  )
}

export function useCampaign(): CampaignContextValue {
  const ctx = useContext(CampaignContext)
  if (!ctx) throw new Error('useCampaign must be used within CampaignProvider')
  return ctx
}
