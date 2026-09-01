import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';
import '../../shared/widgets/pattern_card_widget.dart';
import '../../shared/widgets/skeleton_loader.dart';

class CreatorScreen extends ConsumerWidget {
  const CreatorScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorAsync = ref.watch(creatorProvider(slug));

    return creatorAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [PatternCardSkeleton(), SizedBox(height: 12), PatternCardSkeleton()],
        ),
      ),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (creator) {
        if (creator.name == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Creator not found')));
        }
        return Scaffold(
          appBar: AppBar(title: Text(creator.name!)),
          body: creator.patterns.isEmpty
              ? const Center(child: Text('No patterns yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: creator.patterns.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PatternCardWidget(pattern: creator.patterns[index], rank: index + 1),
                  ),
                ),
        );
      },
    );
  }
}
