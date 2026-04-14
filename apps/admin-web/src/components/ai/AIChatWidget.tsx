import { useState, useRef, useEffect } from 'react'
import { Send, Sparkles, Bot, User, Loader2, Copy, Check, FileText, BarChart3, AlertTriangle, MapPin, TrendingUp, ChevronDown, X, Maximize2, Minimize2 } from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Skeleton } from '@/components/ui/skeleton'
import { supabase } from '@/lib/supabase'
import { cn } from '@/lib/utils'

interface Message {
  id: string
  role: 'user' | 'assistant'
  content: string
  timestamp: Date
  isStreaming?: boolean
}

interface Suggestion {
  text: string
  icon: string
}

const QUICK_TEMPLATES = [
  { id: 'daily', label: 'التقرير اليومي', icon: '📅', color: 'bg-blue-50 text-blue-700 border-blue-200' },
  { id: 'governorate', label: 'أداء المحافظات', icon: '🗺️', color: 'bg-emerald-50 text-emerald-700 border-emerald-200' },
  { id: 'shortages', label: 'تحليل النواقص', icon: '⚠️', color: 'bg-amber-50 text-amber-700 border-amber-200' },
  { id: 'quality', label: 'جودة البيانات', icon: '✅', color: 'bg-purple-50 text-purple-700 border-purple-200' },
  { id: 'coverage', label: 'تغطية التطعيم', icon: '💉', color: 'bg-cyan-50 text-cyan-700 border-cyan-200' },
  { id: 'weekly', label: 'اتجاه الأسبوع', icon: '📈', color: 'bg-rose-50 text-rose-700 border-rose-200' },
]

export function AIChatWidget() {
  const [isOpen, setIsOpen] = useState(false)
  const [isExpanded, setIsExpanded] = useState(false)
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [suggestions, setSuggestions] = useState<string[]>([])
  const [copiedId, setCopiedId] = useState<string | null>(null)
  const scrollRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (isOpen && messages.length === 0) {
      loadSuggestions()
    }
  }, [isOpen])

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [messages])

  const loadSuggestions = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) return
      const { data } = await supabase.functions.invoke('ai-chat', {
        body: { message: '', mode: 'suggestions', history: [] },
      })
      if (data?.suggestions) setSuggestions(data.suggestions)
    } catch { setSuggestions([]) }
  }

  const sendMessage = async (text: string, template?: string) => {
    if (!text.trim() && !template) return
    const userMsg: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: template ? QUICK_TEMPLATES.find(t => t.id === template)?.label || text : text,
      timestamp: new Date(),
    }
    setMessages(prev => [...prev, userMsg])
    setInput('')
    setSuggestions([])
    setIsLoading(true)

    const assistantMsg: Message = {
      id: (Date.now() + 1).toString(),
      role: 'assistant',
      content: '',
      timestamp: new Date(),
      isStreaming: true,
    }
    setMessages(prev => [...prev, assistantMsg])

    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) throw new Error('Not authenticated')

      const history = messages.slice(-10).map(m => ({
        role: m.role,
        content: m.content,
      }))

      const { data, error } = await supabase.functions.invoke('ai-chat', {
        body: {
          message: text || '',
          template: template || undefined,
          history,
          stream: false,
        },
      })

      if (error) throw error

      const reply = data?.reply || data?.text || 'عذراً، لم أتمكن من المعالجة.'

      // Simulate streaming effect
      let current = ''
      const chars = reply.split('')
      for (let i = 0; i < chars.length; i++) {
        current += chars[i]
        setMessages(prev => prev.map(m =>
          m.id === assistantMsg.id ? { ...m, content: current } : m
        ))
        if (i % 3 === 0) await new Promise(r => setTimeout(r, 10))
      }

      setMessages(prev => prev.map(m =>
        m.id === assistantMsg.id ? { ...m, isStreaming: false } : m
      ))
    } catch (err) {
      setMessages(prev => prev.map(m =>
        m.id === assistantMsg.id
          ? { ...m, content: '⚠️ حدث خطأ في الاتصال بخدمة الذكاء الاصطناعي. تأكد من إعداد MIMO_API_KEY.', isStreaming: false }
          : m
      ))
    } finally {
      setIsLoading(false)
    }
  }

  const handleCopy = (id: string, text: string) => {
    navigator.clipboard.writeText(text)
    setCopiedId(id)
    setTimeout(() => setCopiedId(null), 2000)
  }

  const handleTemplate = (templateId: string) => {
    sendMessage('', templateId)
  }

  // Floating button
  if (!isOpen) {
    return (
      <div className="fixed bottom-6 left-6 z-50">
        <button
          onClick={() => setIsOpen(true)}
          className="group relative w-14 h-14 rounded-2xl bg-gradient-to-br from-primary via-primary to-purple-600 text-white shadow-lg hover:shadow-xl hover:shadow-primary/30 transition-all duration-300 hover:scale-105 active:scale-95"
        >
          <Sparkles className="w-6 h-6 mx-auto group-hover:animate-pulse" />
          <span className="absolute -top-1 -right-1 w-4 h-4 bg-emerald-500 rounded-full border-2 border-white animate-pulse" />
        </button>
        {/* Tooltip */}
        <div className="absolute bottom-full left-0 mb-2 px-3 py-1.5 bg-foreground text-background text-xs rounded-lg opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none">
          مساعد EPI الذكي
        </div>
      </div>
    )
  }

  return (
    <div className={cn(
      'fixed bottom-6 left-6 z-50 transition-all duration-300',
      isExpanded ? 'w-[600px] h-[80vh]' : 'w-[420px] h-[560px]'
    )}>
      <Card className="h-full flex flex-col shadow-2xl border-primary/20 overflow-hidden">
        {/* Header */}
        <CardHeader className="flex flex-row items-center justify-between py-3 px-4 bg-gradient-to-l from-primary/5 to-transparent border-b">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-primary to-purple-600 flex items-center justify-center shadow-md">
              <Sparkles className="w-5 h-5 text-white" />
            </div>
            <div>
              <CardTitle className="text-sm font-heading">مساعد EPI الذكي</CardTitle>
              <p className="text-[11px] text-muted-foreground flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                مدعوم بـ MiMo AI
              </p>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="ghost" size="icon-sm" onClick={() => setIsExpanded(!isExpanded)}>
              {isExpanded ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
            </Button>
            <Button variant="ghost" size="icon-sm" onClick={() => setIsOpen(false)}>
              <X className="w-4 h-4" />
            </Button>
          </div>
        </CardHeader>

        {/* Messages */}
        <ScrollArea className="flex-1 p-4" ref={scrollRef}>
          {messages.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center gap-6 py-4">
              {/* Welcome */}
              <div className="text-center space-y-2">
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-primary/10 to-purple-100 flex items-center justify-center mx-auto mb-3">
                  <Sparkles className="w-8 h-8 text-primary" />
                </div>
                <h3 className="font-heading font-bold text-lg">مرحباً! 👋</h3>
                <p className="text-sm text-muted-foreground max-w-[280px]">
                  أنا مساعدك الذكي لمنصة مشرف EPI. اسألني عن أي شيء!
                </p>
              </div>

              {/* Quick Templates */}
              <div className="w-full space-y-2">
                <p className="text-xs text-muted-foreground text-center">تقارير سريعة</p>
                <div className="grid grid-cols-2 gap-2">
                  {QUICK_TEMPLATES.map((t) => (
                    <button
                      key={t.id}
                      onClick={() => handleTemplate(t.id)}
                      className={cn(
                        'flex items-center gap-2 px-3 py-2.5 rounded-xl border text-xs font-medium transition-all hover:shadow-md hover:scale-[1.02] active:scale-[0.98]',
                        t.color
                      )}
                    >
                      <span className="text-base">{t.icon}</span>
                      {t.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Suggestions */}
              {suggestions.length > 0 && (
                <div className="w-full space-y-2">
                  <p className="text-xs text-muted-foreground text-center">اقتراحات</p>
                  {suggestions.map((s, i) => (
                    <button
                      key={i}
                      onClick={() => sendMessage(s)}
                      className="w-full text-right px-3 py-2 rounded-lg bg-muted/50 hover:bg-muted text-sm transition-colors border border-transparent hover:border-primary/20"
                    >
                      {s}
                    </button>
                  ))}
                </div>
              )}
            </div>
          ) : (
            <div className="space-y-4">
              {messages.map((msg) => (
                <div key={msg.id} className={cn(
                  'flex gap-3',
                  msg.role === 'user' ? 'flex-row-reverse' : 'flex-row'
                )}>
                  <Avatar className="w-8 h-8 shrink-0">
                    <AvatarFallback className={cn(
                      'text-xs',
                      msg.role === 'user' ? 'bg-primary/10 text-primary' : 'bg-gradient-to-br from-purple-100 to-primary/10 text-purple-700'
                    )}>
                      {msg.role === 'user' ? <User className="w-4 h-4" /> : <Bot className="w-4 h-4" />}
                    </AvatarFallback>
                  </Avatar>
                  <div className={cn(
                    'max-w-[85%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed',
                    msg.role === 'user'
                      ? 'bg-primary text-primary-foreground rounded-br-md'
                      : 'bg-muted/80 rounded-bl-md'
                  )}>
                    {msg.content ? (
                      <div className="whitespace-pre-wrap">{msg.content}</div>
                    ) : msg.isStreaming ? (
                      <div className="flex items-center gap-1">
                        <span className="w-2 h-2 rounded-full bg-primary animate-bounce" style={{ animationDelay: '0ms' }} />
                        <span className="w-2 h-2 rounded-full bg-primary animate-bounce" style={{ animationDelay: '150ms' }} />
                        <span className="w-2 h-2 rounded-full bg-primary animate-bounce" style={{ animationDelay: '300ms' }} />
                      </div>
                    ) : null}
                    {msg.role === 'assistant' && msg.content && !msg.isStreaming && (
                      <button
                        onClick={() => handleCopy(msg.id, msg.content)}
                        className="mt-2 flex items-center gap-1 text-[10px] text-muted-foreground hover:text-foreground transition-colors"
                      >
                        {copiedId === msg.id ? <Check className="w-3 h-3" /> : <Copy className="w-3 h-3" />}
                        {copiedId === msg.id ? 'تم النسخ' : 'نسخ'}
                      </button>
                    )}
                  </div>
                </div>
              ))}
              {isLoading && messages[messages.length - 1]?.content === '' && (
                <div className="flex gap-3">
                  <Avatar className="w-8 h-8">
                    <AvatarFallback className="bg-gradient-to-br from-purple-100 to-primary/10 text-purple-700 text-xs">
                      <Bot className="w-4 h-4" />
                    </AvatarFallback>
                  </Avatar>
                  <div className="bg-muted/80 rounded-2xl rounded-bl-md px-4 py-3">
                    <div className="flex items-center gap-1.5">
                      <div className="w-2 h-2 rounded-full bg-primary animate-bounce" style={{ animationDelay: '0ms' }} />
                      <div className="w-2 h-2 rounded-full bg-primary animate-bounce" style={{ animationDelay: '150ms' }} />
                      <div className="w-2 h-2 rounded-full bg-primary animate-bounce" style={{ animationDelay: '300ms' }} />
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}
        </ScrollArea>

        {/* Input */}
        <div className="p-3 border-t bg-background">
          <form onSubmit={(e) => { e.preventDefault(); sendMessage(input) }} className="flex gap-2">
            <Input
              ref={inputRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              placeholder="اسأل مساعد EPI..."
              disabled={isLoading}
              className="flex-1 h-10 rounded-xl bg-muted/50 border-0"
            />
            <Button
              type="submit"
              size="icon"
              disabled={isLoading || !input.trim()}
              className="h-10 w-10 rounded-xl bg-gradient-to-br from-primary to-purple-600 hover:shadow-lg"
            >
              {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
            </Button>
          </form>
        </div>
      </Card>
    </div>
  )
}
