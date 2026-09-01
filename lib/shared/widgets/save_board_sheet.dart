import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';

Future<void> showSaveBoardSheet(BuildContext context, WidgetRef ref, String patternId) async {
  final session = ref.read(sessionProvider);
  if (session == null) {
    if (context.mounted) context.push('/login');
    return;
  }

  final api = ref.read(apiClientProvider);
  List<BoardSaveOption> boards;
  try {
    boards = await api.getData(
      '/patterns/$patternId/save',
      map: (json) => (json as List<dynamic>)
          .map((e) => BoardSaveOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return;
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Save to folder', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...boards.map((board) => ListTile(
                  leading: Icon(board.selected ? Icons.bookmark : Icons.bookmark_outline),
                  title: Text(board.name),
                  onTap: () async {
                    try {
                      if (board.selected) {
                        await api.delete('/patterns/$patternId/save');
                      } else {
                        await api.post('/patterns/$patternId/save', data: {'boardId': board.id});
                      }
                      ref.invalidate(boardsWithPatternsProvider);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(board.selected ? 'Removed from ${board.name}' : 'Saved to ${board.name}')),
                        );
                      }
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
