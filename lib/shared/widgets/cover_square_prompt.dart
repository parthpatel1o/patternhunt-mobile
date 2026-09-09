import 'package:flutter/material.dart';

/// Matches web [CoverSquarePromptModal]: prompt to crop a non-square cover.
Future<bool> showCoverSquarePrompt(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Cover needs to be square'),
        content: const Text('Your cover image needs to be a square image.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Crop this image'),
          ),
        ],
      );
    },
  );
  return result == true;
}
