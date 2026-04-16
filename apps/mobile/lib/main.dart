import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:epi_core/epi_core.dart';
import 'package:epi_shared/epi_shared.dart';

import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler for uncaught Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
  };

  // Set error widget builder BEFORE runApp — catches build errors gracefully
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
              const Text(
                'حدث خطأ في عرض الصفحة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFF666666)),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // ─── Load .env file BEFORE any validation ────────────────────
  final dotenv = await EnvLoader.load();
  if (dotenv.isNotEmpty) {
    SupabaseConfig.setFromEnv(
      url: dotenv['SUPABASE_URL'] ?? '',
      anonKey: dotenv['SUPABASE_ANON_KEY'] ?? '',
    );
  }

  // Validate all environment variables first
  try {
    EnvValidator.validate();
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'خطأ في الإعدادات',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }

  // Initialize connectivity monitoring
  try {
    await ConnectivityUtils.initialize();
  } catch (e) {
    debugPrint('ConnectivityUtils init failed: $e');
  }

  // Initialize Supabase only if online mode is available
  if (!EnvValidator.isOfflineMode) {
    try {
      SupabaseConfig.validate();
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        debug: AppConfig.isDevelopment,
      );
    } catch (e) {
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'خطأ في إعدادات Supabase',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Tajawal'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      return;
    }
  }

  // Initialize Notification Service with API client
  try {
    if (SupabaseConfig.isConfigured) {
      NotificationService.init(ApiClient());
    }
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }

  // Lock to portrait on mobile
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Sentry with centralized config — with timeout to prevent blocking
  try {
    await SentryConfig.init(
      appRunner: () async => runApp(const ProviderScope(child: EpiSupervisorApp())),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[SentryConfig] Init timed out, running app without Sentry');
        runApp(const ProviderScope(child: EpiSupervisorApp()));
      },
    );
  } catch (e) {
    debugPrint('[SentryConfig] Init failed: $e, running app without Sentry');
    runApp(const ProviderScope(child: EpiSupervisorApp()));
  }
}

class EpiSupervisorApp extends ConsumerWidget {
  const EpiSupervisorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConfig.appNameAr,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [
        Locale('ar', 'IQ'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // RTL + ensure text direction throughout the app
        Widget content = Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            // Allow accessibility text scaling up to 1.3x for readability
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaler.scale(1.0) > 2.0
                  ? 2.0
                  : MediaQuery.of(context).textScaler.scale(1.0)
              ),
            ),
            child: child!,
          ),
        );

        return content;
      },
    );
  }
}
