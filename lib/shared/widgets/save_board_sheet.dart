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
    isScrollControlled: true,
    builder: (sheetContext) {
      return _SaveBoardSheetBody(
        patternId: patternId,
        initialBoards: boards,
        onChanged: () => invalidatePatternSaveState(ref, patternId),
      );
    },
  );
}

class _SaveBoardSheetBody extends ConsumerStatefulWidget {
  const _SaveBoardSheetBody({
    required this.patternId,
    required this.initialBoards,
    required this.onChanged,
  });

  final String patternId;
  final List<BoardSaveOption> initialBoards;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SaveBoardSheetBody> createState() => _SaveBoardSheetBodyState();
}

class _SaveBoardSheetBodyState extends ConsumerState<_SaveBoardSheetBody> {
  late List<BoardSaveOption> _boards;
  final _newFolderController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _boards = widget.initialBoards;
  }

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  Future<void> _moveToBoard(BoardSaveOption board) async {
    if (board.selected || _busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/patterns/${widget.patternId}/save', data: {'boardId': board.id});
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${board.name}')),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createFolder() async {
    final name = _newFolderController.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final created = await api.post('/boards', data: {'name': name});
      final boardId = created['boardId'] as String?;
      if (boardId == null) throw ApiException('Could not create that folder.');
      await api.post('/patterns/${widget.patternId}/save', data: {'boardId': boardId});
      widget.onChanged();
      if (mounted) {
        _newFolderController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $name')),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Save to folder', style: Theme.of(context).textTheme.titleMedium),
            ),
            ..._boards.map(
              (board) => ListTile(
                leading: Icon(board.selected ? Icons.bookmark : Icons.bookmark_outline),
                title: Text(board.name),
                trailing: board.selected ? const Text('Current') : null,
                enabled: !board.selected && !_busy,
                onTap: board.selected ? null : () => _moveToBoard(board),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newFolderController,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'New folder',
                        hintText: 'Folder name',
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _createFolder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _createFolder,
                    child: const Text('Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
