import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/login_redirect.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import 'app_snack_bar.dart';
import 'skeleton_loader.dart';

Future<void> showSaveBoardSheet(
  BuildContext context,
  WidgetRef ref,
  String patternId,
) async {
  final session = ref.read(sessionProvider);
  if (session == null) {
    if (context.mounted) context.go(loginLocationFor(context));
    return;
  }

  prefetchBoardSaveOptions(ref, patternId);

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _SaveBoardSheetBody(
        patternId: patternId,
        onChanged: () => invalidatePatternSaveState(ref, patternId),
      );
    },
  );
}

class _SaveBoardSheetBody extends ConsumerStatefulWidget {
  const _SaveBoardSheetBody({required this.patternId, required this.onChanged});

  final String patternId;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SaveBoardSheetBody> createState() =>
      _SaveBoardSheetBodyState();
}

class _SaveBoardSheetBodyState extends ConsumerState<_SaveBoardSheetBody> {
  final _newFolderController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  Future<void> _addToBoard(BoardSaveOption board) async {
    if (board.selected || _busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post(
        '/patterns/${widget.patternId}/save',
        data: {'boardId': board.id},
      );
      widget.onChanged();
      if (mounted) {
        final name = result['boardName'] as String? ?? board.name;
        showAppSnackBar(context, message: 'Added to $name');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createFolder() async {
    final name = _newFolderController.text.trim();
    if (name.isEmpty || _busy) return;
    if (name.toLowerCase() == kDefaultBoardName.toLowerCase()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '“$kDefaultBoardName” is reserved for your default folder.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final created = await api.post('/boards', data: {'name': name});
      final boardId = created['boardId'] as String?;
      if (boardId == null) throw ApiException('Could not create that folder.');
      final saved = await api.post(
        '/patterns/${widget.patternId}/save',
        data: {'boardId': boardId},
      );
      widget.onChanged();
      if (mounted) {
        _newFolderController.clear();
        final folderName = saved['boardName'] as String? ?? name;
        showAppSnackBar(context, message: 'Added to $folderName');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardsAsync = ref.watch(boardSaveOptionsProvider(widget.patternId));
    final boards = boardsAsync.value;
    final loading = boards == null;
    final createEnabled = !loading && !_busy;
    final media = MediaQuery.of(context);
    final maxHeight = (media.size.height - media.viewInsets.bottom) * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Add to folder',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Choose a folder to add this pattern to',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
              if (boardsAsync.isLoading && boards == null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    children: [
                      _FolderSkeleton(),
                      SizedBox(height: 8),
                      _FolderSkeleton(),
                      SizedBox(height: 8),
                      _FolderSkeleton(),
                    ],
                  ),
                )
              else if (boards == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    boardsAsync.hasError
                        ? '${boardsAsync.error}'
                        : 'Could not load folders.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: boards.length,
                    itemBuilder: (context, index) {
                      final board = boards[index];
                      return ListTile(
                        leading: Icon(
                          board.selected
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                        ),
                        title: Text(board.name),
                        trailing: Text(
                          board.selected ? 'Current' : 'Add',
                          style: TextStyle(
                            color: board.selected
                                ? AppColors.muted
                                : AppColors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        enabled: !board.selected && !_busy,
                        onTap: board.selected ? null : () => _addToBoard(board),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newFolderController,
                        enabled: createEnabled,
                        maxLength: 40,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.foreground,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: 'New folder name',
                          hintStyle: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _createFolder(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: createEnabled ? _createFolder : null,
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderSkeleton extends StatelessWidget {
  const _FolderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonBox(height: 44, borderRadius: 16);
  }
}
