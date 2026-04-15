import { useState } from 'react'
import { Navigate } from 'react-router-dom'
import { Eye, EyeOff, AlertCircle, Shield, Lock, Sparkles } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { useSignIn, useAuth } from '@/hooks/useApi'
import { isConfigured } from '@/lib/supabase'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const signIn = useSignIn()
  const { data: authData } = useAuth()

  if (authData?.session) {
    return <Navigate to="/" replace />
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    signIn.mutate({ email, password })
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-50 via-blue-50 to-indigo-50 p-4 relative overflow-hidden">
      {/* Animated background elements */}
      <div className="absolute inset-0 overflow-hidden">
        {/* Grid pattern */}
        <div className="absolute inset-0 opacity-[0.03]" style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%231d4ed8' fill-opacity='1'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`,
        }} />

        {/* Floating orbs */}
        <div className="absolute top-[10%] right-[15%] w-[400px] h-[400px] rounded-full bg-blue-200/30 blur-3xl animate-pulse-slow" />
        <div className="absolute bottom-[15%] left-[10%] w-[500px] h-[500px] rounded-full bg-indigo-200/20 blur-3xl animate-pulse-slow" style={{ animationDelay: '2s' }} />
        <div className="absolute top-[50%] left-[50%] w-[300px] h-[300px] rounded-full bg-purple-200/15 blur-3xl animate-pulse-slow" style={{ animationDelay: '4s' }} />
      </div>

      <div className="relative w-full max-w-md">
        {/* ═══════════════════════════════════════
            LOGO SECTION — Official EPI Branding
        ═══════════════════════════════════════ */}
        <div className="text-center mb-8 animate-fade-in">
          {/* Main EPI Shield Logo */}
          <div className="relative inline-block mb-6">
            <div className="w-32 h-32 rounded-3xl bg-white shadow-2xl shadow-blue-500/10 flex items-center justify-center overflow-hidden border border-blue-100/50 mx-auto relative">
              <img
                src="./logo-epi-256.png"
                alt="شعار برنامج التطعيم الموسع"
                className="w-24 h-24 object-contain relative z-10"
                onError={(e) => {
                  e.currentTarget.style.display = 'none'
                  e.currentTarget.parentElement!.innerHTML = `
                    <div class="w-20 h-20 rounded-2xl bg-gradient-to-br from-blue-600 to-blue-800 flex items-center justify-center">
                      <svg class="w-12 h-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                      </svg>
                    </div>
                  `
                }}
              />
            </div>
            {/* Glow effect */}
            <div className="absolute inset-0 rounded-3xl bg-blue-400/20 blur-2xl -z-10 scale-125" />
          </div>

          {/* App Title */}
          <h1 className="text-4xl font-heading font-bold text-gray-900 mb-2">
            <span className="bg-gradient-to-r from-blue-600 to-indigo-600 bg-clip-text text-transparent">EPI</span>{' '}
            Supervisor's
          </h1>
          <p className="text-gray-500 text-sm font-medium">
            المشرف — منصة الإشراف الميداني لحملات التطعيم
          </p>

          {/* Security badge */}
          <div className="inline-flex items-center gap-1.5 mt-4 px-3 py-1.5 rounded-full bg-emerald-50 border border-emerald-200/60">
            <Shield className="w-3.5 h-3.5 text-emerald-600" />
            <span className="text-xs font-medium text-emerald-700">اتصال آمن ومشفّر</span>
          </div>

          {/* Partner logos */}
          <div className="flex items-center justify-center gap-6 mt-5 opacity-50">
            <img
              src="./header-partners.png"
              alt="وزارة الصحة العامة والسكان — اليونيسف"
              className="h-12 object-contain"
              onError={(e) => { e.currentTarget.style.display = 'none' }}
            />
          </div>
        </div>

        {/* ═══════════════════════════════════════
            LOGIN CARD
        ═══════════════════════════════════════ */}
        <Card className="shadow-2xl shadow-blue-500/5 border-0 bg-white/90 backdrop-blur-xl animate-fade-in overflow-hidden" style={{ animationDelay: '0.1s' }}>
          {/* Subtle top gradient */}
          <div className="h-1 bg-gradient-to-r from-blue-500 via-indigo-500 to-purple-500" />

          <CardHeader className="text-center pb-4 pt-6">
            <CardTitle className="text-xl font-heading text-gray-900 flex items-center justify-center gap-2">
              <Lock className="w-5 h-5 text-blue-500" />
              تسجيل الدخول
            </CardTitle>
            <CardDescription className="text-gray-500">
              أدخل بيانات حساب المسؤول للوصول إلى لوحة التحكم
            </CardDescription>
          </CardHeader>
          <CardContent className="px-6 pb-6">
            {!isConfigured && (
              <div className="mb-5 p-4 rounded-xl bg-amber-50 border border-amber-200/60 text-amber-800 text-sm flex items-start gap-2.5">
                <AlertCircle className="w-5 h-5 mt-0.5 shrink-0" />
                <div>
                  <p className="font-semibold">Supabase غير مُعدّ</p>
                  <p className="text-xs mt-1 opacity-80">يرجى تعيين متغيرات البيئة VITE_SUPABASE_URL و VITE_SUPABASE_ANON_KEY</p>
                </div>
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-5">
              <div className="space-y-2">
                <Label htmlFor="email" className="text-gray-700 font-medium text-sm">البريد الإلكتروني</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="admin@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  dir="ltr"
                  className="text-left h-12 bg-gray-50/80 border-gray-200 focus:bg-white focus:border-blue-300 focus:ring-blue-200 transition-all rounded-xl"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="password" className="text-gray-700 font-medium text-sm">كلمة المرور</Label>
                <div className="relative">
                  <Input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    dir="ltr"
                    className="text-left pl-10 h-12 bg-gray-50/80 border-gray-200 focus:bg-white focus:border-blue-300 focus:ring-blue-200 transition-all rounded-xl"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors p-1"
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {signIn.isError && (
                <div className="p-3.5 rounded-xl bg-red-50 border border-red-200/60 text-red-700 text-sm flex items-center gap-2 animate-fade-in">
                  <AlertCircle className="w-4.5 h-4.5 shrink-0" />
                  فشل تسجيل الدخول. تحقق من البريد الإلكتروني وكلمة المرور.
                </div>
              )}

              <Button
                type="submit"
                className="w-full h-12 bg-gradient-to-l from-blue-600 via-blue-700 to-indigo-700 hover:from-blue-700 hover:via-blue-800 hover:to-indigo-800 shadow-lg shadow-blue-500/25 hover:shadow-xl hover:shadow-blue-500/30 transition-all text-base font-medium rounded-xl"
                disabled={signIn.isPending || !isConfigured}
              >
                {signIn.isPending ? (
                  <div className="flex items-center gap-2">
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    جاري تسجيل الدخول...
                  </div>
                ) : (
                  <div className="flex items-center gap-2">
                    <Sparkles className="w-4 h-4" />
                    تسجيل الدخول
                  </div>
                )}
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* Footer */}
        <div className="text-center mt-8 animate-fade-in" style={{ animationDelay: '0.2s' }}>
          <p className="text-xs text-gray-400 font-medium">
            منصة EPI Supervisor's v1.0.0
          </p>
          <p className="text-[10px] text-gray-300 mt-1.5">
            وزارة الصحة العامة والسكان — برنامج التطعيم الموسع
          </p>
        </div>
      </div>
    </div>
  )
}
