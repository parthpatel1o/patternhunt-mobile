import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key, this.categoryName});

  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final categoryLabel = categoryName ?? 'this category';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.layers_outlined, size: 40, color: AppColors.accent),
          ),
          const SizedBox(height: 24),
          Text(
            'No patterns yet',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.foreground),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing ranked in $categoryLabel for this time period.\nTry another filter or check back soon.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.muted, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
