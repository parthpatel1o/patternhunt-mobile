import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/providers.dart';
import '../../shared/widgets/skeleton_loader.dart';

class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(myPatternsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My patterns')),
      body: patternsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [PatternCardSkeleton(), SizedBox(height: 12), PatternCardSkeleton()],
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (patterns) {
          if (patterns.isEmpty) {
            return const Center(child: Text('You have not submitted any patterns yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myPatternsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: patterns.length,
              itemBuilder: (context, index) {
                final pattern = patterns[index];
                return Dismissible(
                  key: ValueKey(pattern.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.orange.shade100,
                    child: const Icon(Icons.archive_outlined),
                  ),
                  confirmDismiss: (_) async {
                    try {
                      await ref.read(apiClientProvider).patch('/me/patterns/${pattern.id}/archive', {'archived': true});
                      ref.invalidate(myPatternsProvider);
                      return true;
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                      return false;
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(pattern.title),
                      subtitle: Text(pattern.isArchived ? 'Archived' : '${pattern.voteCount} votes'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          final api = ref.read(apiClientProvider);
                          try {
                            if (value == 'archive') {
                              await api.patch('/me/patterns/${pattern.id}/archive', {'archived': !pattern.isArchived});
                            } else if (value == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete pattern?'),
                                  content: const Text('This cannot be undone.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirmed == true) await api.delete('/me/patterns/${pattern.id}');
                            }
                            ref.invalidate(myPatternsProvider);
                          } on ApiException catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'archive',
                            child: Text(pattern.isArchived ? 'Unarchive' : 'Archive'),
                          ),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                      onTap: () => context.push('/pattern/${pattern.id}'),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
