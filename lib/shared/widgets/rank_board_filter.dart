import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';

/// Quiet filter control for the rank board — matches web `RankBoardFilter`.
///
/// Icon-only with an accent dot when Free only is on. Opens a small menu
/// with a single "Free only" checkbox so the board chrome stays light.
class RankBoardFilter extends StatelessWidget {
  const RankBoardFilter({
    super.key,
    required this.freeOnly,
    required this.onFreeOnlyChanged,
  });

  final bool freeOnly;
  final ValueChanged<bool> onFreeOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.card),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(
          AppColors.foreground.withValues(alpha: 0.12),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
      ),
      menuChildren: [
        MenuItemButton(
          closeOnActivate: true,
          onPressed: () => onFreeOnlyChanged(!freeOnly),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed)) {
                return AppColors.primary.withValues(alpha: 0.35);
              }
              return Colors.transparent;
            }),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          leadingIcon: IgnorePointer(
            child: SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: freeOnly,
                onChanged: (_) {},
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: AppColors.border, width: 1.5),
                activeColor: AppColors.accent,
                checkColor: AppColors.accentForeground,
              ),
            ),
          ),
          child: const Text(
            'Free only',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
      builder: (context, controller, _) {
        return AppPressable(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          haptic: true,
          scale: AppMotion.pressScaleSmall,
          child: Semantics(
            button: true,
            label: freeOnly ? 'Filters, free only on' : 'Filters',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 18,
                    color: controller.isOpen || freeOnly
                        ? AppColors.foreground.withValues(alpha: 0.7)
                        : AppColors.muted,
                  ),
                  if (freeOnly)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
