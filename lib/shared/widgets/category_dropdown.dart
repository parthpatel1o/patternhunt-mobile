import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/category_icons.dart';

/// Stadium category picker used on the rank board and hunt filters.
class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.value,
    required this.entries,
    required this.onChanged,
  });

  final String value;
  final List<({String value, String label})> entries;
  final ValueChanged<String> onChanged;

  String get _label =>
      entries.where((e) => e.value == value).map((e) => e.label).firstOrNull ??
      'All categories';

  @override
  Widget build(BuildContext context) {
    final selectedIcon = categoryIcon(value);
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = constraints.maxWidth;
        return MenuAnchor(
          crossAxisUnconstrained: false,
          style: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.card),
            elevation: const WidgetStatePropertyAll(10),
            shadowColor: const WidgetStatePropertyAll(Color(0x383D2F4A)),
            minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
            maximumSize: WidgetStatePropertyAll(
              Size(menuWidth, double.infinity),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          ),
          builder: (context, controller, child) {
            return SizedBox(
              width: menuWidth,
              child: Material(
                color: AppColors.card,
                elevation: 1.5,
                shadowColor: const Color(0x293D2F4A),
                shape: const StadiumBorder(
                  side: BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
                      child: Row(
                        children: [
                          Icon(
                            selectedIcon,
                            size: 16,
                            color: AppColors.foreground,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.foreground,
                                  ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: controller.isOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          menuChildren: [
            for (final entry in entries)
              MenuItemButton(
                onPressed: () => onChanged(entry.value),
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    entry.value == value
                        ? AppColors.primary
                        : Colors.transparent,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  overlayColor: WidgetStatePropertyAll(
                    AppColors.primary.withValues(alpha: 0.35),
                  ),
                  minimumSize: WidgetStatePropertyAll(Size(menuWidth - 12, 44)),
                ),
                child: Row(
                  children: [
                    Icon(
                      categoryIcon(entry.value),
                      size: 16,
                      color: entry.value == value
                          ? AppColors.primaryForeground
                          : AppColors.foreground,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: entry.value == value
                              ? AppColors.primaryForeground
                              : AppColors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
