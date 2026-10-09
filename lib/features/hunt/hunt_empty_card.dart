import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';

/// Mobile counterpart of the web HuntEmptyCard, using the Hunt card chrome.
class HuntEmptyCard extends StatelessWidget {
  const HuntEmptyCard({super.key, required this.onChangeFilters});

  final VoidCallback onChangeFilters;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Container(
      key: const ValueKey('hunt-empty-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Match the progress slot and photo spacing of a Hunt card.
                  const SizedBox(height: 18),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Center(
                      heightFactor: 1,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CustomPaint(
                            painter: _EmptyHuntBackdrop(),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                      boxShadow: AppShadows.card,
                                    ),
                                    child: const Icon(
                                      LucideIcons.slidersHorizontal,
                                      size: 40,
                                      color: AppColors.accentForeground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nothing to hunt here',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Try changing changing your filters or choose another category',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onChangeFilters,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentForeground,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Change filters'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyHuntBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.primary,
    );
    final shortest = math.min(size.width, size.height);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.25),
      shortest * 0.28,
      Paint()..color = AppColors.accent.withValues(alpha: 0.22 * 0.35),
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.70),
      shortest * 0.22,
      Paint()..color = AppColors.accent.withValues(alpha: 0.16 * 0.35),
    );
  }

  @override
  bool shouldRepaint(_EmptyHuntBackdrop oldDelegate) => false;
}
