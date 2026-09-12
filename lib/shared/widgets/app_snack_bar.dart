import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Shows a floating snack bar styled to match Pattern Hunt cards.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Color? actionColor,
  Duration duration = const Duration(seconds: 4),
}) {
  assert(
    (actionLabel == null) == (onAction == null),
    'actionLabel and onAction must both be set or both be null',
  );

  final hasAction = actionLabel != null && onAction != null;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.card,
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      duration: duration,
      // Vertical dismiss fights taps on the action. Swipe sideways to dismiss.
      dismissDirection: hasAction
          ? DismissDirection.horizontal
          : DismissDirection.down,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: hasAction
          ? const EdgeInsets.fromLTRB(16, 4, 4, 4)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      content: Row(
        children: [
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: AppColors.foreground,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (hasAction)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  onAction();
                },
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        actionLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: actionColor ?? AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                          decorationColor: actionColor ?? AppColors.accent,
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
  );
}

/// Web `showSavedToast`: “Saved!” on the left, underlined “Add to folder” on the right.
void showSavedSnackBar(
  BuildContext context, {
  required VoidCallback onAddToFolder,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  showAppSnackBar(
    context,
    message: 'Saved!',
    actionLabel: 'Add to folder',
    onAction: onAddToFolder,
    actionColor: AppColors.foreground,
  );
}
