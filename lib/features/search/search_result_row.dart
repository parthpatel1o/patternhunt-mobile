import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'search_highlight.dart';

/// Compact typeahead row — thumb + highlighted title/designer + price pill.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.pattern,
    required this.query,
    required this.onTap,
  });

  final PatternCard pattern;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = pattern.imageUrls.isNotEmpty ? pattern.imageUrls.first : null;
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          height: 1.25,
          color: AppColors.foreground,
        );
    final designerStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.2,
          color: AppColors.muted,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: thumb != null
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const ColoredBox(color: AppColors.background),
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: AppColors.background,
                            child: Icon(Icons.image_not_supported_outlined, size: 18, color: AppColors.muted),
                          ),
                        )
                      : const ColoredBox(
                          color: AppColors.background,
                          child: Icon(Icons.image_outlined, size: 18, color: AppColors.muted),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: highlightQuerySpans(pattern.title, query, style: titleStyle)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: highlightQuerySpans(pattern.designerName, query, style: designerStyle),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _PricePill(isFree: pattern.isFree),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchResultRowSkeleton extends StatelessWidget {
  const SearchResultRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          SkeletonBox(width: 52, height: 52, borderRadius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 14, borderRadius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 96, height: 12, borderRadius: 6),
              ],
            ),
          ),
          SizedBox(width: 10),
          SkeletonBox(width: 44, height: 22, borderRadius: 999),
        ],
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.isFree});

  final bool isFree;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isFree ? 0.2 : 0.3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isFree ? 'Free' : 'Paid',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isFree ? AppColors.accent : AppColors.foreground,
          height: 1,
        ),
      ),
    );
  }
}
