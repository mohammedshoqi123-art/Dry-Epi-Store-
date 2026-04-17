import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dry_core/dry_core.dart';
import 'package:dry_shared/dry_shared.dart';

import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF5F5F5),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('حدث خطأ في عرض الصفحة',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              const SizedBox(height: 8),
              Text(details.exceptionAsString(), textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFF666666)),
                  maxLines: 5, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  };

  final dotenv = await EnvLoader.load();
  if (dotenv.isNotEmpty) {
    SupabaseConfig.setFromEnv(
      url: dotenv['SUPABASE_URL'] ?? '',
      anonKey: dotenv['SUPABASE_ANON_KEY'] ?? '',
    );
  }

  try { EnvValidator.validate(); } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        const Text('خطأ في الإعدادات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        const SizedBox(height: 8),
        Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Tajawal')),
      ]))))));
    return;
  }

  try { await ConnectivityUtils.initialize(); } catch (e) { debugPrint('ConnectivityUtils init failed: $e'); }

  if (!EnvValidator.isOfflineMode) {
    try {
      SupabaseConfig.validate();
      await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey, debug: AppConfig.isDevelopment);
    } catch (e) {
      runApp(MaterialApp(home: Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('خطأ في إعدادات Supabase', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Tajawal')),
        ]))))));
      return;
    }
  }

  try { if (SupabaseConfig.isConfigured) NotificationService.init(ApiClient()); } catch (e) { debugPrint('NotificationService init failed: $e'); }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));

  try {
    await SentryConfig.init(appRunner: () async => runApp(const ProviderScope(child: DryEpiStoreApp())))
        .timeout(const Duration(seconds: 10), onTimeout: () { runApp(const ProviderScope(child: DryEpiStoreApp())); });
  } catch (e) {
    runApp(const ProviderScope(child: DryEpiStoreApp()));
  }
}

class DryEpiStoreApp extends ConsumerWidget {
  const DryEpiStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConfig.appNameAr,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: const Locale('ar', 'YE'),
      supportedLocales: const [Locale('ar', 'YE'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}
