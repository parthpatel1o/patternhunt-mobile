import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/photo_viewer.dart';
import '../../shared/widgets/save_board_sheet.dart';
import '../../shared/widgets/skeleton_loader.dart';

String slugifyDesigner(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

class PatternDetailScreen extends ConsumerStatefulWidget {
  const PatternDetailScreen({super.key, required this.patternId});

  final String patternId;

  @override
  ConsumerState<PatternDetailScreen> createState() => _PatternDetailScreenState();
}

class _PatternDetailScreenState extends ConsumerState<PatternDetailScreen> {
  bool _savePending = false;

  Future<void> _toggleSave(PatternCard pattern) async {
    if (ref.read(sessionProvider) == null) {
      if (mounted) context.push('/login');
      return;
    }
    setState(() => _savePending = true);
    try {
      final api = ref.read(apiClientProvider);
      if (pattern.saved) {
        await api.delete('/patterns/${pattern.id}/save');
      } else {
        await api.post('/patterns/${pattern.id}/save');
      }
      invalidatePatternSaveState(ref, pattern.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _savePending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patternAsync = ref.watch(patternDetailProvider(widget.patternId));

    return patternAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [SkeletonBox(width: double.infinity, height: 320, borderRadius: 20)],
        ),
      ),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (pattern) {
        return Scaffold(
          appBar: AppBar(title: Text(pattern.title)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 320,
                child: PageView.builder(
                  itemCount: pattern.imageUrls.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => showNetworkPhotoViewer(
                      context,
                      imageUrls: pattern.imageUrls,
                      initialIndex: index,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ColoredBox(
                        color: AppColors.card,
                        child: CachedNetworkImage(
                          imageUrl: pattern.imageUrls[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => context.push('/creator/${slugifyDesigner(pattern.designerName)}'),
                child: Text(pattern.designerName, style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(
                    onPressed: () async {
                      if (ref.read(sessionProvider) == null) {
                        if (context.mounted) context.push('/login');
                        return;
                      }
                      HapticFeedback.lightImpact();
                      try {
                        await ref.read(apiClientProvider).post('/patterns/${pattern.id}/vote');
                        ref.invalidate(patternDetailProvider(widget.patternId));
                        ref.invalidate(patternsProvider);
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    },
                    child: Text('Vote · ${pattern.voteCount}'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _savePending ? null : () => _toggleSave(pattern),
                    onLongPress: _savePending ? null : () => showSaveBoardSheet(context, ref, pattern.id),
                    child: Text(pattern.saved ? 'Saved' : 'Save'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (pattern.patternUrl != null)
                FilledButton.tonal(
                  onPressed: () => launchUrl(Uri.parse(pattern.patternUrl!)),
                  child: const Text('Open pattern link'),
                ),
              if (pattern.hasPdf) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      final data = await ref.read(apiClientProvider).getData(
                            '/patterns/${pattern.id}/pdf',
                            map: (j) => j as Map<String, dynamic>,
                          );
                      final url = data['url'] as String?;
                      if (url != null) await launchUrl(Uri.parse(url));
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                  child: const Text('Download PDF'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
