import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/providers.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(boardsWithPatternsProvider);

    return boardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (groups) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(boardsWithPatternsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _createBoard(context, ref),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('New folder'),
              ),
              const SizedBox(height: 16),
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: Text('No saved folders yet')),
                )
              else
                ...groups.map((group) {
                  final thumb = group.patterns.isNotEmpty ? group.patterns.first.imageUrls.first : null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: thumb != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(thumb, width: 48, height: 48, fit: BoxFit.cover),
                            )
                          : const Icon(Icons.folder_outlined),
                      title: Text(group.board.name),
                      subtitle: Text('${group.patterns.length} patterns'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/saved/${group.board.id}'),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createBoard(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/boards', data: {'name': name});
      ref.invalidate(boardsWithPatternsProvider);
      ref.invalidate(boardsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
