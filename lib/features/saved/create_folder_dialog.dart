import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/widgets/app_snack_bar.dart';

/// Shows the new-folder dialog and creates the board on confirm.
Future<void> showCreateFolderDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    animationStyle: AppMotion.surface,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New folder',
              style: Theme.of(ctx).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Name your folder, then bookmark patterns to add them here.',
              style: Theme.of(ctx).textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 40,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Folder name',
                      hintStyle: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Create'),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppColors.muted)),
            ),
          ],
        ),
      ),
    ),
  );
  if (name == null || name.isEmpty) return;
  if (name.toLowerCase() == kDefaultBoardName.toLowerCase()) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: '“$kDefaultBoardName” is reserved for your default folder.',
      );
    }
    return;
  }
  try {
    await ref.read(apiClientProvider).post('/boards', data: {'name': name});
    ref.invalidate(boardsWithPatternsProvider);
    ref.invalidate(boardsProvider);
    if (context.mounted) {
      showAppSnackBar(context, message: 'Created “$name”');
    }
  } on ApiException catch (e) {
    if (context.mounted) showAppSnackBar(context, message: e.message);
  }
}
