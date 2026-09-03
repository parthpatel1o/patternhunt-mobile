import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

class BoardDetailScreen extends ConsumerWidget {
  const BoardDetailScreen({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(boardsWithPatternsProvider);

    return boardsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (groups) {
        BoardWithPatterns? group;
        for (final g in groups) {
          if (g.board.id == boardId) {
            group = g;
            break;
          }
        }
        if (group == null) {
          return const Scaffold(body: Center(child: Text('Folder not found')));
        }
        return Scaffold(
          appBar: AppBar(title: Text(group.board.name)),
          body: group.patterns.isEmpty
              ? const Center(child: Text('No patterns in this folder'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: group.patterns.length,
                  itemBuilder: (context, index) {
                    final pattern = group!.patterns[index];
                    return Dismissible(
                      key: ValueKey(pattern.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red.shade100,
                        child: const Icon(Icons.delete_outline),
                      ),
                      confirmDismiss: (_) async {
                        try {
                          await ref.read(apiClientProvider).delete('/patterns/${pattern.id}/save');
                          ref.invalidate(boardsWithPatternsProvider);
                          invalidatePatternSaveState(ref, pattern.id);
                          return true;
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                          }
                          return false;
                        }
                      },
                      child: InkWell(
                        onTap: () => context.push('/pattern/${pattern.id}'),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: ColoredBox(
                                  color: AppColors.card,
                                  child: CachedNetworkImage(
                                    imageUrl: pattern.imageUrls.first,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(pattern.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
