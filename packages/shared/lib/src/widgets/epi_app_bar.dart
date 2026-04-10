import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EpiAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Widget? leading;
  final VoidCallback? onBackPressed;
  final bool centerTitle;

  const EpiAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.leading,
    this.onBackPressed,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      leading: leading ??
          (showBackButton && Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                )
              : null),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
