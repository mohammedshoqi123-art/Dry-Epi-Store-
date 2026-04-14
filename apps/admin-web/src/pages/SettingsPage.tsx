import { useState } from 'react'
import {
  Settings, Shield, Database, Bell, Palette, Globe, Key,
  Server, Clock, Mail, Save, RefreshCw, Download, Upload,
  AlertTriangle, CheckCircle2, Info, Lock, Eye, EyeOff
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs'
import { Header } from '@/components/layout/header'
import { useTheme } from '@/components/layout/theme-provider'
import { isConfigured } from '@/lib/supabase'
import { cn } from '@/lib/utils'

interface SettingSection {
  id: string
  icon: React.ElementType
  title: string
  description: string
}

const sections: SettingSection[] = [
  { id: 'general', icon: Settings, title: 'عام', description: 'الإعدادات الأساسية للنظام' },
  { id: 'security', icon: Shield, title: 'الأمان', description: 'إعدادات الحماية والصلاحيات' },
  { id: 'notifications', icon: Bell, title: 'الإشعارات', description: 'إدارة التنبيهات والتنبيهات' },
  { id: 'appearance', icon: Palette, title: 'المظهر', description: 'تخصيص واجهة النظام' },
  { id: 'data', icon: Database, title: 'البيانات', description: 'إدارة النسخ الاحتياطي والتصدير' },
]

export default function SettingsPage() {
  const { theme, setTheme } = useTheme()
  const [activeSection, setActiveSection] = useState('general')

  // Form states
  const [appName, setAppName] = useState('مشرف EPI')
  const [appVersion, setAppVersion] = useState('1.0.0')
  const [language, setLanguage] = useState('ar')
  const [timezone, setTimezone] = useState('Asia/Aden')
  const [syncInterval, setSyncInterval] = useState('5')
  const [maxPhotos, setMaxPhotos] = useState('5')
  const [requireGPS, setRequireGPS] = useState(true)
  const [autoApprove, setAutoApprove] = useState(false)
  const [twoFactor, setTwoFactor] = useState(false)
  const [sessionTimeout, setSessionTimeout] = useState('60')
  const [rateLimit, setRateLimit] = useState('10')
  const [emailNotifs, setEmailNotifs] = useState(true)
  const [pushNotifs, setPushNotifs] = useState(true)
  const [criticalAlerts, setCriticalAlerts] = useState(true)
  const [dailyReport, setDailyReport] = useState(false)
  const [saved, setSaved] = useState(false)

  const handleSave = () => {
    setSaved(true)
    setTimeout(() => setSaved(false), 3000)
  }

  return (
    <div className="page-enter">
      <Header title="الإعدادات" subtitle="تكوين النظام والخصوصية" />

      <div className="p-6">
        <div className="flex flex-col lg:flex-row gap-6">
          {/* Sidebar Navigation */}
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
                        <Icon className="w-4 h-4" />
                        <span className="font-medium">{s.title}</span>
                      </button>
                    )
                  })}
                </nav>
              </CardContent>
            </Card>

            {/* System Status */}
            <Card className="mt-4">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-heading">حالة النظام</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">Supabase</span>
                  <Badge variant={isConfigured ? 'success' : 'destructive'} className="text-[10px]">
                    {isConfigured ? 'متصل' : 'غير مُعدّ'}
                  </Badge>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">الإصدار</span>
                  <span className="font-mono text-xs">{appVersion}</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">البيئة</span>
                  <Badge variant="outline" className="text-[10px]">إنتاج</Badge>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Main Content */}
          <div className="flex-1 space-y-6">
            {/* General Settings */}
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
                        <Input value={appName} onChange={(e) => setAppName(e.target.value)} />
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
                            <SelectItem value="Asia/Aden">Asia/Aden (UTC+3)</SelectItem>
                            <SelectItem value="Asia/Riyadh">Asia/Riyadh (UTC+3)</SelectItem>
                            <SelectItem value="UTC">UTC</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="space-y-2">
                        <Label>فترة المزامنة (دقائق)</Label>
                        <Input type="number" value={syncInterval} onChange={(e) => setSyncInterval(e.target.value)} />
                      </div>
                    </div>

                    <Separator />

                    <div className="space-y-4">
                      <h4 className="text-sm font-medium">إعدادات النماذج</h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label>الحد الأقصى للصور</Label>
                          <Input type="number" value={maxPhotos} onChange={(e) => setMaxPhotos(e.target.value)} />
                        </div>
                        <div className="flex items-center justify-between p-3 rounded-lg border">
                          <div>
                            <p className="text-sm font-medium">تطلب GPS</p>
                            <p className="text-xs text-muted-foreground">إلزام تحديد الموقع للإرساليات</p>
                          </div>
                          <Switch checked={requireGPS} onCheckedChange={setRequireGPS} />
                        </div>
                        <div className="flex items-center justify-between p-3 rounded-lg border">
                          <div>
                            <p className="text-sm font-medium">اعتماد تلقائي</p>
                            <p className="text-xs text-muted-foreground">اعتماد الإرساليات بدون مراجعة</p>
                          </div>
                          <Switch checked={autoApprove} onCheckedChange={setAutoApprove} />
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}

            {/* Security Settings */}
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
                  <CardContent className="space-y-5">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label>مهلة الجلسة (دقائق)</Label>
                        <Input type="number" value={sessionTimeout} onChange={(e) => setSessionTimeout(e.target.value)} />
                      </div>
                      <div className="space-y-2">
                        <Label>حد الطلبات (لكل دقيقة)</Label>
                        <Input type="number" value={rateLimit} onChange={(e) => setRateLimit(e.target.value)} />
                      </div>
                    </div>

                    <Separator />

                    <div className="space-y-4">
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
                    </div>

                    <div className="p-4 rounded-lg bg-amber-50 border border-amber-200">
                      <div className="flex items-start gap-2">
                        <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
                        <div>
                          <p className="text-sm font-medium text-amber-800">إعدادات متقدمة</p>
                          <p className="text-xs text-amber-700 mt-1">
                            تغيير إعدادات الأمان قد يؤثر على جميع المستخدمين. تأكد من إخطار الفريق قبل التعديل.
                          </p>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}

            {/* Notifications Settings */}
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
                    {[
                      { label: 'إشعارات البريد', desc: 'إرسال إشعارات عبر البريد الإلكتروني', checked: emailNotifs, onChange: setEmailNotifs },
                      { label: 'إشعارات الفورية', desc: 'تنبيهات فورية في المتصفح', checked: pushNotifs, onChange: setPushNotifs },
                      { label: 'تنبيهات النواقص الحرجة', desc: 'تنبيه فوري عند وجود نقص حرج', checked: criticalAlerts, onChange: setCriticalAlerts },
                      { label: 'التقرير اليومي', desc: 'إرسال ملخص يومي تلقائي', checked: dailyReport, onChange: setDailyReport },
                    ].map((item, i) => (
                      <div key={i} className="flex items-center justify-between p-3 rounded-lg border">
                        <div className="flex items-center gap-3">
                          <Bell className="w-5 h-5 text-muted-foreground" />
                          <div>
                            <p className="text-sm font-medium">{item.label}</p>
                            <p className="text-xs text-muted-foreground">{item.desc}</p>
                          </div>
                        </div>
                        <Switch checked={item.checked} onCheckedChange={item.onChange} />
                      </div>
                    ))}
                  </CardContent>
                </Card>
              </div>
            )}

            {/* Appearance Settings */}
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
                  <CardContent className="space-y-5">
                    <div className="space-y-3">
                      <Label>السمة</Label>
                      <div className="grid grid-cols-3 gap-3">
                        {[
                          { value: 'light', label: 'فاتح', icon: '☀️' },
                          { value: 'dark', label: 'داكن', icon: '🌙' },
                          { value: 'system', label: 'النظام', icon: '💻' },
                        ].map((t) => (
                          <button
                            key={t.value}
                            onClick={() => setTheme(t.value as any)}
                            className={cn(
                              'p-4 rounded-xl border-2 text-center transition-all',
                              theme === t.value
                                ? 'border-primary bg-primary/5 shadow-md'
                                : 'border-border hover:border-primary/30'
                            )}
                          >
                            <span className="text-2xl block mb-2">{t.icon}</span>
                            <span className="text-sm font-medium">{t.label}</span>
                          </button>
                        ))}
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}

            {/* Data Settings */}
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
                  <CardContent className="space-y-4">
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                      <Button variant="outline" className="h-auto py-4 flex flex-col gap-2">
                        <Download className="w-6 h-6 text-primary" />
                        <span className="font-medium">تصدير البيانات</span>
                        <span className="text-[10px] text-muted-foreground">CSV / JSON</span>
                      </Button>
                      <Button variant="outline" className="h-auto py-4 flex flex-col gap-2">
                        <Upload className="w-6 h-6 text-emerald-600" />
                        <span className="font-medium">استيراد البيانات</span>
                        <span className="text-[10px] text-muted-foreground">من ملف</span>
                      </Button>
                      <Button variant="outline" className="h-auto py-4 flex flex-col gap-2">
                        <RefreshCw className="w-6 h-6 text-amber-600" />
                        <span className="font-medium">نسخة احتياطية</span>
                        <span className="text-[10px] text-muted-foreground">إنشاء نسخة يدوية</span>
                      </Button>
                    </div>

                    <div className="p-4 rounded-lg bg-red-50 border border-red-200">
                      <div className="flex items-start gap-2">
                        <AlertTriangle className="w-5 h-5 text-red-600 shrink-0 mt-0.5" />
                        <div>
                          <p className="text-sm font-medium text-red-800">منطقة الخطر</p>
                          <p className="text-xs text-red-700 mt-1">
                            هذه العمليات لا يمكن التراجع عنها. تأكد من أخذ نسخة احتياطية قبل المتابعة.
                          </p>
                          <Button variant="destructive" size="sm" className="mt-3">
                            مسح البيانات القديمة
                          </Button>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}

            {/* Save Button */}
            <div className="flex items-center justify-end gap-3">
              {saved && (
                <div className="flex items-center gap-2 text-emerald-600 animate-fade-in">
                  <CheckCircle2 className="w-4 h-4" />
                  <span className="text-sm">تم الحفظ بنجاح</span>
                </div>
              )}
              <Button onClick={handleSave} className="gap-2">
                <Save className="w-4 h-4" />
                حفظ الإعدادات
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
