import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';

/// Builds the floating card-styled snack bar used everywhere in the app.
SnackBar buildAppSnackBar({
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

  return SnackBar(
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
          Builder(
            builder: (context) => Material(
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
          ),
      ],
    ),
  );
}

/// Shows a floating snack bar styled to match Pattern Hunt cards.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Color? actionColor,
  Duration duration = const Duration(seconds: 4),
}) {
  showAppSnackBarOn(
    ScaffoldMessenger.of(context),
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
    actionColor: actionColor,
    duration: duration,
  );
}

/// Same snack bar for callers that only hold a messenger — e.g. the global
/// `scaffoldMessengerKey` used for app-level events.
void showAppSnackBarOn(
  ScaffoldMessengerState? messenger, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Color? actionColor,
  Duration duration = const Duration(seconds: 4),
}) {
  messenger?.showSnackBar(
    buildAppSnackBar(
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      actionColor: actionColor,
      duration: duration,
    ),
    // The floating snack bar already rises from the bottom; this only retimes
    // it onto the shared tokens instead of stacking a second animation.
    snackBarAnimationStyle: AppMotion.surface,
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
