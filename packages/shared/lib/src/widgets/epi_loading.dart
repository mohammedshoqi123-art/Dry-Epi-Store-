import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class EpiLoading extends StatelessWidget {
  final String? message;
  final bool useShimmer;

  const EpiLoading({super.key, this.message, this.useShimmer = false});

  const EpiLoading.shimmer({super.key, this.message}) : useShimmer = true;

  @override
  Widget build(BuildContext context) {
    if (useShimmer) {
      return _buildShimmerList();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class EpiLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const EpiLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black26,
            child: EpiLoading(message: message),
          ),
      ],
    );
  }
}
