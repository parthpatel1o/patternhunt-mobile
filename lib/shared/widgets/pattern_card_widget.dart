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
import 'save_board_sheet.dart';

class PatternCardWidget extends ConsumerStatefulWidget {
  const PatternCardWidget({
    super.key,
    required this.pattern,
    required this.rank,
    this.rankPeriod = 'all',
  });

  final PatternCard pattern;
  final int rank;
  final String rankPeriod;

  @override
  ConsumerState<PatternCardWidget> createState() => _PatternCardWidgetState();
}

class _PatternCardWidgetState extends ConsumerState<PatternCardWidget> {
  bool _voting = false;
  bool _saving = false;
  late bool _saved;
  late bool _voted;
  late int _voteCount;

  @override
  void initState() {
    super.initState();
    _syncFromPattern();
  }

  @override
  void didUpdateWidget(PatternCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pattern.id != widget.pattern.id ||
        oldWidget.pattern.saved != widget.pattern.saved ||
        oldWidget.pattern.voted != widget.pattern.voted ||
        oldWidget.pattern.voteCount != widget.pattern.voteCount) {
      _syncFromPattern();
    }
  }

  void _syncFromPattern() {
    _saved = widget.pattern.saved;
    _voted = widget.pattern.voted;
    _voteCount = widget.pattern.voteCount;
  }

  Map<String, dynamic>? get _voteQuery =>
      widget.rankPeriod == 'all' ? null : {'period': widget.rankPeriod};

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
    final previousVoted = _voted;
    final previousCount = _voteCount;
    setState(() {
      _voted = !_voted;
      _voteCount = (_voteCount + (_voted ? 1 : -1)).clamp(0, 1 << 30);
    });
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post('/patterns/${widget.pattern.id}/vote', query: _voteQuery);
      final voted = result['voted'] as bool?;
      final voteCount = result['voteCount'] as num?;
      if (voted != null && voteCount != null && mounted) {
        setState(() {
          _voted = voted;
          _voteCount = voteCount.toInt();
        });
      }
      ref.invalidate(patternsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _voted = previousVoted;
          _voteCount = previousCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _toggleSave() async {
    if (ref.read(sessionProvider) == null) {
      if (mounted) context.push('/login');
      return;
    }
    setState(() => _saving = true);
    final previous = _saved;
    try {
      final api = ref.read(apiClientProvider);
      if (_saved) {
        setState(() => _saved = false);
        await api.delete('/patterns/${widget.pattern.id}/save');
      } else {
        setState(() => _saved = true);
        await api.post('/patterns/${widget.pattern.id}/save');
      }
      invalidatePatternSaveState(ref, widget.pattern.id);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saved = previous);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSaveSheet() async {
    await showSaveBoardSheet(context, ref, widget.pattern.id);
    invalidatePatternSaveState(ref, widget.pattern.id);
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
                        IconButton(
                          onPressed: _saving ? null : _toggleSave,
                          onLongPress: _saving ? null : _openSaveSheet,
                          icon: Icon(
                            _saved ? Icons.bookmark : Icons.bookmark_outline,
                            color: _saved ? AppColors.accent : AppColors.muted,
                          ),
                          tooltip: _saved ? 'Saved' : 'Save',
                        ),
                        FilledButton.tonal(
                          onPressed: _voting ? null : _toggleVote,
                          style: FilledButton.styleFrom(
                            backgroundColor: _voted ? AppColors.accent : AppColors.card,
                            foregroundColor: _voted ? AppColors.accentForeground : AppColors.accent,
                            shape: const StadiumBorder(),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_upward, size: 18, color: _voted ? AppColors.accentForeground : AppColors.accent),
                              const SizedBox(width: 4),
                              Text('$_voteCount'),
                            ],
                          ),
                        ).animate(target: _voted ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 280.ms),
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
