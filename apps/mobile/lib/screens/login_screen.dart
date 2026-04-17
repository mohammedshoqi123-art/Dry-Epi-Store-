import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dry_shared/dry_shared.dart';
import 'package:dry_core/dry_core.dart';

import '../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال البريد وكلمة المرور', style: TextStyle(fontFamily: 'Tajawal'))));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.signInWithEmail(_emailController.text.trim(), _passwordController.text);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تسجيل الدخول: $e', style: const TextStyle(fontFamily: 'Tajawal'))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.warehouse_rounded, size: 80, color: Color(0xFF0D7C66)),
        const SizedBox(height: 16),
        const Text('مخزن EPI الجاف', style: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0D7C66))),
        const SizedBox(height: 8),
        const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 32),
        TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        TextField(controller: _passwordController, obscureText: _obscurePassword,
          decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
            border: const OutlineInputBorder())),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton(onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)))),
      ]))),
    );
  }
}
