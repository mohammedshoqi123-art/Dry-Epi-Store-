import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 120, height: 120,
            decoration: BoxDecoration(color: const Color(0xFF0D7C66).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(30)),
            child: const Icon(Icons.warehouse_rounded, size: 64, color: Color(0xFF0D7C66)),
          ),
          const SizedBox(height: 24),
          const Text('مخزن EPI الجاف', style: TextStyle(fontFamily: 'Cairo', fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF0D7C66))),
          const SizedBox(height: 8),
          const Text('إدارة المخازن الجافة للتطعيم', style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 48),
          const CircularProgressIndicator(color: Color(0xFF0D7C66)),
        ]),
      ),
    );
  }
}
