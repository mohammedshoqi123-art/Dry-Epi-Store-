// EPI Features Package
// Feature modules live in apps/mobile/lib/screens/
// This package re-exports shared feature types and helpers

/// Feature module metadata
class FeatureInfo {
  final String id;
  final String nameAr;
  final String nameEn;
  final String description;
  final int minRoleLevel;

  const FeatureInfo({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    this.minRoleLevel = 1,
  });
}

/// Available feature modules
class EpiFeatures {
  EpiFeatures._();

  static const dashboard = FeatureInfo(
    id: 'dashboard',
    nameAr: 'لوحة التحكم',
    nameEn: 'Dashboard',
    description: 'Overview of submissions, shortages, and KPIs',
    minRoleLevel: 1,
  );

  static const forms = FeatureInfo(
    id: 'forms',
    nameAr: 'النماذج',
    nameEn: 'Forms',
    description: 'Dynamic form filling and submission',
    minRoleLevel: 1,
  );

  static const submissions = FeatureInfo(
    id: 'submissions',
    nameAr: 'الإرساليات',
    nameEn: 'Submissions',
    description: 'View and manage form submissions',
    minRoleLevel: 1,
  );

  static const map = FeatureInfo(
    id: 'map',
    nameAr: 'الخريطة',
    nameEn: 'Map',
    description: 'Interactive map with submission locations',
    minRoleLevel: 1,
  );

  static const analytics = FeatureInfo(
    id: 'analytics',
    nameAr: 'التحليلات',
    nameEn: 'Analytics',
    description: 'KPI charts and export',
    minRoleLevel: 3,
  );

  static const aiChat = FeatureInfo(
    id: 'ai_chat',
    nameAr: 'المساعد الذكي',
    nameEn: 'AI Assistant',
    description: 'AI-powered data analysis',
    minRoleLevel: 3,
  );

  static const userManagement = FeatureInfo(
    id: 'user_management',
    nameAr: 'إدارة المستخدمين',
    nameEn: 'User Management',
    description: 'Create and manage user accounts',
    minRoleLevel: 4,
  );

  static const auditLogs = FeatureInfo(
    id: 'audit_logs',
    nameAr: 'سجل التدقيق',
    nameEn: 'Audit Logs',
    description: 'System audit trail',
    minRoleLevel: 4,
  );

  /// All features
  static const List<FeatureInfo> all = [
    dashboard, forms, submissions, map,
    analytics, aiChat, userManagement, auditLogs,
  ];

  /// Get features accessible to a role level
  static List<FeatureInfo> forRoleLevel(int level) {
    return all.where((f) => f.minRoleLevel <= level).toList();
  }
}
