import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

class PatternCardWidget extends ConsumerStatefulWidget {
  const PatternCardWidget({super.key, required this.pattern, required this.rank});

  final PatternCard pattern;
  final int rank;

  @override
  ConsumerState<PatternCardWidget> createState() => _PatternCardWidgetState();
}

class _PatternCardWidgetState extends ConsumerState<PatternCardWidget> {
  bool _voting = false;

  (Color bg, Color border) _rankColors() {
    return switch (widget.rank) {
      1 => (AppColors.rank1Bg, AppColors.rank1Border),
      2 => (AppColors.rank2Bg, AppColors.rank2Border),
      3 => (AppColors.rank3Bg, AppColors.rank3Border),
      _ => (AppColors.card, AppColors.border),
    };
  }

  Future<void> _toggleVote() async {
    if (ref.read(sessionProvider) == null) {
      if (mounted) context.push('/login');
      return;
    }
    setState(() => _voting = true);
    HapticFeedback.lightImpact();
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/patterns/${widget.pattern.id}/vote');
      ref.invalidate(patternsProvider);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, border) = _rankColors();
    final pattern = widget.pattern;
    return Card(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: border, width: widget.rank <= 2 ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/pattern/${pattern.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: pattern.imageUrls.first,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: widget.rank <= 3 ? AppColors.primaryStrong : AppColors.card,
                      child: Text('${widget.rank}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pattern.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(pattern.designerName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(
                          label: Text(pattern.isFree ? 'Free' : 'Paid'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.35),
                        ),
                        const Spacer(),
                        FilledButton.tonal(
                          onPressed: _voting ? null : _toggleVote,
                          style: FilledButton.styleFrom(
                            backgroundColor: pattern.voted ? AppColors.accent : AppColors.card,
                            foregroundColor: pattern.voted ? AppColors.accentForeground : AppColors.accent,
                            shape: const StadiumBorder(),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_upward, size: 18, color: pattern.voted ? AppColors.accentForeground : AppColors.accent),
                              const SizedBox(width: 4),
                              Text('${pattern.voteCount}'),
                            ],
                          ),
                        ).animate(target: pattern.voted ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 280.ms),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }
}
