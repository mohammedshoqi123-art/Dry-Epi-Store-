import { useState } from 'react'
import { Navigate } from 'react-router-dom'
import { Eye, EyeOff, AlertCircle, Shield } from 'lucide-react'
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
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 via-white to-blue-50 p-4 relative overflow-hidden">
      {/* Background pattern */}
      <div className="absolute inset-0 opacity-[0.03]" style={{
        backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%231d4ed8' fill-opacity='1'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`,
      }} />

      {/* Decorative circles */}
      <div className="absolute top-20 right-20 w-72 h-72 rounded-full bg-blue-100/40 blur-3xl" />
      <div className="absolute bottom-20 left-20 w-96 h-96 rounded-full bg-blue-50/60 blur-3xl" />

      <div className="relative w-full max-w-md">
        {/* ═══════════════════════════════════════════
            LOGO SECTION — Official EPI Branding
        ═══════════════════════════════════════════ */}
        <div className="text-center mb-8 animate-fade-in">
          {/* Main EPI Shield Logo */}
          <div className="relative inline-block mb-5">
            <div className="w-28 h-28 rounded-3xl bg-white shadow-xl shadow-blue-500/10 flex items-center justify-center overflow-hidden border border-blue-100/50 mx-auto">
              <img
                src="/logo-epi-256.png"
                alt="شعار برنامج التطعيم الموسع"
                className="w-24 h-24 object-contain"
                onError={(e) => {
                  // Fallback to SVG if image fails
                  e.currentTarget.style.display = 'none'
                  e.currentTarget.parentElement!.innerHTML = `
                    <div class="w-20 h-20 rounded-2xl bg-gradient-to-br from-blue-600 to-blue-800 flex items-center justify-center">
                      <svg class="w-12 h-12 text-white" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
                      </svg>
                    </div>
                  `
                }}
              />
            </div>
            {/* Glow effect */}
            <div className="absolute inset-0 rounded-3xl bg-blue-400/20 blur-xl -z-10 scale-110" />
          </div>

          {/* App Title */}
          <h1 className="text-3xl font-heading font-bold text-gray-900 mb-1">
            مشرف <span className="text-blue-600">EPI</span>
          </h1>
          <p className="text-gray-500 text-sm">
            منصة الإشراف الميداني لحملات التطعيم
          </p>

          {/* Partner logos */}
          <div className="flex items-center justify-center gap-6 mt-5 opacity-60">
            <img
              src="/header-partners.png"
              alt="وزارة الصحة العامة والسكان — اليونيسف"
              className="h-12 object-contain"
              onError={(e) => { e.currentTarget.style.display = 'none' }}
            />
          </div>
        </div>

        {/* ═══════════════════════════════════════════
            LOGIN CARD
        ═══════════════════════════════════════════ */}
        <Card className="shadow-2xl shadow-blue-500/5 border-0 bg-white/80 backdrop-blur-xl animate-fade-in" style={{ animationDelay: '0.1s' }}>
          <CardHeader className="text-center pb-4 pt-6">
            <CardTitle className="text-xl font-heading text-gray-900">تسجيل الدخول</CardTitle>
            <CardDescription className="text-gray-500">
              أدخل بيانات حساب المسؤول للوصول إلى لوحة التحكم
            </CardDescription>
          </CardHeader>
          <CardContent className="px-6 pb-6">
            {!isConfigured && (
              <div className="mb-5 p-3.5 rounded-xl bg-amber-50 border border-amber-200/60 text-amber-800 text-sm flex items-start gap-2.5">
                <AlertCircle className="w-4.5 h-4.5 mt-0.5 shrink-0" />
                <div>
                  <p className="font-semibold">Supabase غير مُعدّ</p>
                  <p className="text-xs mt-1 opacity-80">يرجى تعيين متغيرات البيئة VITE_SUPABASE_URL و VITE_SUPABASE_ANON_KEY</p>
                </div>
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="email" className="text-gray-700 font-medium">البريد الإلكتروني</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="admin@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  dir="ltr"
                  className="text-left h-11 bg-gray-50/80 border-gray-200 focus:bg-white transition-colors"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="password" className="text-gray-700 font-medium">كلمة المرور</Label>
                <div className="relative">
                  <Input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    dir="ltr"
                    className="text-left pl-10 h-11 bg-gray-50/80 border-gray-200 focus:bg-white transition-colors"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {signIn.isError && (
                <div className="p-3 rounded-xl bg-red-50 border border-red-200/60 text-red-700 text-sm flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 shrink-0" />
                  فشل تسجيل الدخول. تحقق من البريد الإلكتروني وكلمة المرور.
                </div>
              )}

              <Button
                type="submit"
                className="w-full h-11 bg-gradient-to-l from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 shadow-lg shadow-blue-500/20 hover:shadow-xl hover:shadow-blue-500/30 transition-all text-base font-medium"
                disabled={signIn.isPending || !isConfigured}
              >
                {signIn.isPending ? (
                  <div className="flex items-center gap-2">
                    <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    جاري تسجيل الدخول...
                  </div>
                ) : (
                  'تسجيل الدخول'
                )}
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* Footer */}
        <div className="text-center mt-6 animate-fade-in" style={{ animationDelay: '0.2s' }}>
          <p className="text-xs text-gray-400">
            منصة مشرف EPI v1.0.0
          </p>
          <p className="text-[10px] text-gray-300 mt-1">
            وزارة الصحة العامة والسكان — برنامج التطعيم الموسع
          </p>
        </div>
      </div>
    </div>
  )
}
