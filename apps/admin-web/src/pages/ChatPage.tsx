import { useState, useRef, useEffect, useCallback } from 'react'
import { Send, MessageSquare, Hash, Users, Smile, Paperclip, MoreVertical, Trash2, Reply, Check, CheckCheck } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Skeleton } from '@/components/ui/skeleton'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from '@/components/ui/dropdown-menu'
import { Header } from '@/components/layout/header'
import { useChatMessages, useSendChatMessage } from '@/hooks/useApi'
import { getInitials, formatRelativeTime, cn } from '@/lib/utils'
import { supabase } from '@/lib/supabase'
import { useToast } from '@/hooks/useToast'
import type { ChatMessage } from '@/types/database'

interface ChatRoom {
  id: string
  label: string
  icon: string
  description: string
}

const chatRooms: ChatRoom[] = [
  { id: 'general', label: 'عام', icon: '💬', description: 'محادثات عامة للفريق' },
  { id: 'admin', label: 'الإدارة', icon: '🛡️', description: 'مناقشة قرارات إدارية' },
  { id: 'reports', label: 'التقارير', icon: '📊', description: 'مراجعة وتحليل التقارير' },
  { id: 'field', label: 'الميدان', icon: '🏥', description: 'تحديثات من الميدان' },
  { id: 'urgent', label: 'عاجل', icon: '🚨', description: 'مواضيع عاجلة تحتاج تدخل فوري' },
]

const QUICK_REACTIONS = ['👍', '✅', '❤️', '😂', '🤔', '👏']

export default function ChatPage() {
  const [message, setMessage] = useState('')
  const [room, setRoom] = useState('general')
  const [replyTo, setReplyTo] = useState<ChatMessage | null>(null)
  const scrollRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const { data: messages, isLoading, refetch } = useChatMessages(room)
  const sendMutation = useSendChatMessage()
  const { toast } = useToast()

  // Auto-scroll to bottom on new messages
  const scrollToBottom = useCallback(() => {
    if (scrollRef.current) {
      const scrollContainer = scrollRef.current.querySelector('[data-radix-scroll-area-viewport]')
      if (scrollContainer) {
        scrollContainer.scrollTop = scrollContainer.scrollHeight
      }
    }
  }, [])

  useEffect(() => {
    const timer = setTimeout(scrollToBottom, 100)
    return () => clearTimeout(timer)
  }, [messages, scrollToBottom])

  // Realtime subscription
  useEffect(() => {
    const channel = supabase
      .channel(`chat-${room}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'chat_messages',
          filter: `room=eq.${room}`,
        },
        (payload) => {
          refetch()
          // Show toast for new messages from others
          if (payload.new && (payload.new as any).sender_id !== undefined) {
            // Could add notification sound here
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [room, refetch])

  const handleSend = () => {
    const text = message.trim()
    if (!text) return

    const finalMessage = replyTo
      ? `↩️ رد على: "${replyTo.content.slice(0, 50)}..."\n\n${text}`
      : text

    sendMutation.mutate({ message: finalMessage, room }, {
      onSuccess: () => {
        setMessage('')
        setReplyTo(null)
        setTimeout(scrollToBottom, 100)
      },
      onError: () => {
        toast({ title: 'فشل إرسال الرسالة', variant: 'destructive' })
      },
    })
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  const insertQuickReaction = (emoji: string) => {
    setMessage(prev => prev + emoji)
    inputRef.current?.focus()
  }

  // Group messages by date
  const groupedMessages = (messages as ChatMessage[] | undefined)?.reduce((groups: Record<string, ChatMessage[]>, msg: ChatMessage) => {
    const date = new Date(msg.created_at).toLocaleDateString('ar-SA', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
    })
    if (!groups[date]) groups[date] = []
    groups[date].push(msg)
    return groups
  }, {}) || {}

  const currentRoom = chatRooms.find(r => r.id === room)

  return (
    <div className="page-enter flex flex-col h-[calc(100vh-4rem)]">
      <Header
        title="الشات الداخلي"
        subtitle={currentRoom ? `${currentRoom.icon} ${currentRoom.label} — ${currentRoom.description}` : ''}
        onRefresh={() => refetch()}
      />

      <div className="flex-1 p-4 lg:p-6 flex flex-col min-h-0">
        {/* Room selector */}
        <div className="flex gap-2 mb-4 overflow-x-auto pb-2 scrollbar-none">
          {chatRooms.map((r) => (
            <button
              key={r.id}
              onClick={() => { setRoom(r.id); setReplyTo(null) }}
              className={cn(
                'flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all whitespace-nowrap',
                room === r.id
                  ? 'bg-primary text-primary-foreground shadow-md shadow-primary/20'
                  : 'bg-muted/50 text-muted-foreground hover:bg-muted hover:text-foreground'
              )}
            >
              <span>{r.icon}</span>
              <span>{r.label}</span>
            </button>
          ))}
        </div>

        {/* Chat Area */}
        <Card className="flex-1 flex flex-col min-h-0 overflow-hidden">
          {/* Messages */}
          <div className="flex-1 min-h-0" ref={scrollRef}>
            <ScrollArea className="h-full">
              <div className="p-4 lg:p-6">
                {isLoading ? (
                  <div className="space-y-6">
                    {Array.from({ length: 5 }).map((_, i) => (
                      <div key={i} className={cn('flex gap-3', i % 2 === 0 ? '' : 'flex-row-reverse')}>
                        <Skeleton className="w-10 h-10 rounded-full shrink-0" />
                        <div className="space-y-2 flex-1 max-w-[70%]">
                          <Skeleton className="w-24 h-3" />
                          <Skeleton className={cn('h-12 rounded-2xl', i % 2 === 0 ? 'w-full' : 'w-3/4')} />
                        </div>
                      </div>
                    ))}
                  </div>
                ) : messages?.length === 0 ? (
                  <div className="flex flex-col items-center justify-center h-64 text-muted-foreground">
                    <div className="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mb-4">
                      <MessageSquare className="w-10 h-10 text-primary/40" />
                    </div>
                    <p className="font-heading font-bold text-lg">لا توجد رسائل بعد</p>
                    <p className="text-sm mt-1">كن أول من يبدأ المحادثة في غرفة {currentRoom?.label}!</p>
                  </div>
                ) : (
                  <div className="space-y-6">
                    {(Object.entries(groupedMessages) as [string, ChatMessage[]][]).map(([date, dateMessages]) => (
                      <div key={date}>
                        {/* Date separator */}
                        <div className="flex items-center gap-3 my-4">
                          <div className="flex-1 h-px bg-border" />
                          <span className="text-xs text-muted-foreground px-3 py-1 bg-muted/50 rounded-full">{date}</span>
                          <div className="flex-1 h-px bg-border" />
                        </div>

                        {/* Messages for this date */}
                        <div className="space-y-3">
                          {dateMessages.map((msg: ChatMessage, idx: number) => {
                            const isConsecutive = idx > 0 &&
                              dateMessages[idx - 1].sender_id === msg.sender_id &&
                              new Date(msg.created_at).getTime() - new Date(dateMessages[idx - 1].created_at).getTime() < 300000

                            return (
                              <div
                                key={msg.id}
                                className={cn(
                                  'flex gap-3 group',
                                  isConsecutive && 'mt-1'
                                )}
                              >
                                {isConsecutive ? (
                                  <div className="w-10 shrink-0" />
                                ) : (
                                  <Avatar className="w-10 h-10 shrink-0 ring-2 ring-background shadow-sm">
                                    <AvatarFallback className="bg-gradient-to-br from-primary/20 to-primary/10 text-primary text-xs font-bold">
                                      {getInitials(msg.sender_name)}
                                    </AvatarFallback>
                                  </Avatar>
                                )}
                                <div className="flex-1 min-w-0 max-w-[80%] lg:max-w-[70%]">
                                  {!isConsecutive && (
                                    <div className="flex items-center gap-2 mb-1.5">
                                      <span className="text-sm font-bold text-foreground">{msg.sender_name}</span>
                                      <span className="text-[10px] text-muted-foreground">
                                        {new Date(msg.created_at).toLocaleTimeString('ar-SA', {
                                          hour: '2-digit',
                                          minute: '2-digit',
                                          hour12: true,
                                        })}
                                      </span>
                                    </div>
                                  )}
                                  <div className="relative">
                                    <div className="bg-muted/60 rounded-2xl rounded-tl-md px-4 py-2.5 text-sm leading-relaxed whitespace-pre-wrap break-words">
                                      {msg.content}
                                    </div>
                                    {/* Message actions */}
                                    <div className="absolute top-0 left-0 -translate-x-full opacity-0 group-hover:opacity-100 transition-opacity flex items-center gap-1 px-2">
                                      <button
                                        onClick={() => setReplyTo(msg)}
                                        className="p-1 rounded-md hover:bg-muted text-muted-foreground"
                                        title="رد"
                                      >
                                        <Reply className="w-3.5 h-3.5" />
                                      </button>
                                      <DropdownMenu>
                                        <DropdownMenuTrigger asChild>
                                          <button className="p-1 rounded-md hover:bg-muted text-muted-foreground">
                                            <Smile className="w-3.5 h-3.5" />
                                          </button>
                                        </DropdownMenuTrigger>
                                        <DropdownMenuContent align="end" className="flex gap-1 p-2">
                                          {QUICK_REACTIONS.map((emoji) => (
                                            <button
                                              key={emoji}
                                              onClick={() => {
                                                sendMutation.mutate({ message: emoji, room })
                                              }}
                                              className="text-lg hover:scale-125 transition-transform p-1"
                                            >
                                              {emoji}
                                            </button>
                                          ))}
                                        </DropdownMenuContent>
                                      </DropdownMenu>
                                    </div>
                                  </div>
                                </div>
                              </div>
                            )
                          })}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </ScrollArea>
          </div>

          {/* Reply indicator */}
          {replyTo && (
            <div className="border-t bg-muted/30 px-4 py-2 flex items-center gap-3 animate-fade-in">
              <Reply className="w-4 h-4 text-primary shrink-0" />
              <div className="flex-1 min-w-0">
                <p className="text-xs font-medium text-primary">الرد على {replyTo.sender_name}</p>
                <p className="text-xs text-muted-foreground truncate">{replyTo.content}</p>
              </div>
              <Button variant="ghost" size="icon-sm" onClick={() => setReplyTo(null)}>
                <span className="text-muted-foreground">✕</span>
              </Button>
            </div>
          )}

          {/* Input */}
          <div className="border-t p-4 bg-background">
            {/* Quick reactions */}
            <div className="flex gap-1 mb-2">
              {QUICK_REACTIONS.map((emoji) => (
                <button
                  key={emoji}
                  onClick={() => insertQuickReaction(emoji)}
                  className="text-lg hover:scale-110 transition-transform p-1 rounded hover:bg-muted"
                >
                  {emoji}
                </button>
              ))}
            </div>

            <div className="flex gap-2">
              <Button variant="ghost" size="icon" className="shrink-0 text-muted-foreground">
                <Paperclip className="w-4 h-4" />
              </Button>
              <Input
                ref={inputRef}
                placeholder={`اكتب رسالتك في غرفة ${currentRoom?.label || ''}...`}
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                onKeyDown={handleKeyDown}
                className="flex-1"
                disabled={sendMutation.isPending}
              />
              <Button
                onClick={handleSend}
                disabled={!message.trim() || sendMutation.isPending}
                size="icon"
                className="shrink-0"
              >
                {sendMutation.isPending ? (
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : (
                  <Send className="w-4 h-4" />
                )}
              </Button>
            </div>
            <p className="text-[10px] text-muted-foreground mt-2 text-center">
              اضغط Enter للإرسال • Shift+Enter لسطر جديد
            </p>
          </div>
        </Card>
      </div>
    </div>
  )
}
