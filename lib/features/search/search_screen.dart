import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../shared/widgets/pattern_card_widget.dart';
import '../../shared/widgets/skeleton_loader.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = PatternQuery(q: _query);
    final patternsAsync = _query.isEmpty
        ? const AsyncValue<PatternsPage>.data(
            PatternsPage(patterns: [], hasMore: false, nextOffset: null),
          )
        : ref.watch(patternsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search patterns or designers', border: InputBorder.none),
          onChanged: _onChanged,
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: patternsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [PatternCardSkeleton(), SizedBox(height: 12), PatternCardSkeleton()],
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (page) {
          if (_query.isEmpty) {
            return const Center(child: Text('Search by pattern title or designer name'));
          }
          if (page.patterns.isEmpty) return const Center(child: Text('No results'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: page.patterns.length + (page.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= page.patterns.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: page.loadingMore
                        ? const CircularProgressIndicator()
                        : TextButton(
                            onPressed: () => ref.read(patternsProvider(query).notifier).loadMore(),
                            child: const Text('Load more'),
                          ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PatternCardWidget(pattern: page.patterns[index], rank: index + 1),
              );
            },
          );
        },
      ),
    );
  }
}
