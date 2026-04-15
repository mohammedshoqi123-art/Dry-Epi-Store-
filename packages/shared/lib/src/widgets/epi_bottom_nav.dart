import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EpiBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const EpiBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: onTap,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: AppTheme.textHint,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'النماذج'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'الخريطة'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_rounded), label: 'الشات'),
        BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'المساعد'),
      ],
    );
  }
}
