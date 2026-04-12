import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:epi_shared/epi_shared.dart';
import 'package:epi_core/epi_core.dart';

import '../providers/app_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasNavigated = false;
  String _status = 'جاري التحميل...';

  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Show splash for at least 1.5 seconds
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _hasNavigated) return;

    // Check if Supabase is properly configured
    if (!SupabaseConfig.isConfigured) {
      setState(() => _status = 'Supabase غير مُعدّ — الانتقال لتسجيل الدخول');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || _hasNavigated) return;
      _hasNavigated = true;
      context.go('/login');
      return;
    }

    // Check if Supabase was initialized
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;

      if (session != null) {
        setState(() => _status = 'تم العثور على جلسة — جاري التحميل...');
        // Try to load profile with timeout
        try {
          await ref.read(authStateProvider.future).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              // Profile load timed out — go to dashboard anyway
              throw TimeoutException('Profile load timed out');
            },
          );
        } catch (_) {
          // Profile failed but user is authenticated — go to dashboard
        }
        if (!mounted || _hasNavigated) return;
        _hasNavigated = true;
        context.go('/dashboard');
      } else {
        setState(() => _status = 'الانتقال لتسجيل الدخول...');
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted || _hasNavigated) return;
        _hasNavigated = true;
        context.go('/login');
      }
    } catch (e) {
      // Supabase not initialized — go to login
      setState(() => _status = 'الانتقال لتسجيل الدخول...');
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted || _hasNavigated) return;
      _hasNavigated = true;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'EPI Supervisor Platform',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
