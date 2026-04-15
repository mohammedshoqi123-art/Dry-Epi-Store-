import { useState, useRef, useEffect } from 'react'
import { Send, MessageSquare, Hash } from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Skeleton } from '@/components/ui/skeleton'
import { Header } from '@/components/layout/header'
import { useChatMessages, useSendChatMessage } from '@/hooks/useApi'
import { getInitials, formatRelativeTime } from '@/lib/utils'
import { supabase } from '@/lib/supabase'
import type { ChatMessage } from '@/types/database'

export default function ChatPage() {
  const [message, setMessage] = useState('')
  const [room, setRoom] = useState('general')
  const scrollRef = useRef<HTMLDivElement>(null)
  const { data: messages, isLoading, refetch } = useChatMessages(room)
  const sendMutation = useSendChatMessage()

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
        () => {
          refetch()
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [room, refetch])

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [messages])

  const handleSend = () => {
    const text = message.trim()
    if (!text) return
    sendMutation.mutate({ message: text, room }, {
      onSuccess: () => setMessage(''),
    })
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  return (
    <div className="page-enter flex flex-col h-[calc(100vh-4rem)]">
      <Header title="الشات الداخلي" subtitle={`غرفة: ${room}`} onRefresh={() => refetch()} />

      <div className="flex-1 p-6 flex flex-col min-h-0">
        {/* Room selector */}
        <div className="flex gap-2 mb-4">
          {['general', 'admin', 'reports'].map((r) => (
            <Badge
              key={r}
              variant={room === r ? 'default' : 'outline'}
              className="cursor-pointer gap-1 px-3 py-1.5"
              onClick={() => setRoom(r)}
            >
              <Hash className="w-3 h-3" />
              {r === 'general' ? 'عام' : r === 'admin' ? 'الإدارة' : 'التقارير'}
            </Badge>
          ))}
        </div>

        {/* Messages */}
        <Card className="flex-1 flex flex-col min-h-0">
          <ScrollArea className="flex-1 p-4" ref={scrollRef}>
            {isLoading ? (
              <div className="space-y-4">
                {Array.from({ length: 5 }).map((_, i) => (
                  <div key={i} className="flex gap-3">
                    <Skeleton className="w-9 h-9 rounded-full shrink-0" />
                    <div className="space-y-2 flex-1">
                      <Skeleton className="w-24 h-3" />
                      <Skeleton className="w-full h-10" />
                    </div>
                  </div>
                ))}
              </div>
            ) : messages?.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full text-muted-foreground">
                <MessageSquare className="w-12 h-12 mb-3 opacity-30" />
                <p className="text-sm">لا توجد رسائل بعد</p>
                <p className="text-xs mt-1">ابدأ المحادثة الآن!</p>
              </div>
            ) : (
              <div className="space-y-4">
                {messages?.map((msg: ChatMessage) => (
                  <div key={msg.id} className="flex gap-3 group">
                    <Avatar className="w-9 h-9 shrink-0">
                      <AvatarFallback className="bg-primary/10 text-primary text-xs font-bold">
                        {getInitials(msg.sender_name)}
                      </AvatarFallback>
                    </Avatar>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <span className="text-sm font-bold">{msg.sender_name}</span>
                        <span className="text-[10px] text-muted-foreground">
                          {formatRelativeTime(msg.created_at)}
                        </span>
                      </div>
                      <div className="bg-muted/50 rounded-lg rounded-tr-none px-3 py-2 text-sm leading-relaxed">
                        {msg.content}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </ScrollArea>

          {/* Input */}
          <div className="border-t p-4">
            <div className="flex gap-2">
              <Input
                placeholder="اكتب رسالتك..."
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
              >
                <Send className="w-4 h-4" />
              </Button>
            </div>
          </div>
        </Card>
      </div>
    </div>
  )
}
