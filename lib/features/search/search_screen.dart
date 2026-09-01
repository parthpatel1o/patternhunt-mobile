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
    final patternsAsync = _query.isEmpty
        ? const AsyncValue<List<PatternCard>>.data([])
        : ref.watch(patternsProvider(PatternQuery(q: _query)));

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
        data: (patterns) {
          if (_query.isEmpty) {
            return const Center(child: Text('Search by pattern title or designer name'));
          }
          if (patterns.isEmpty) return const Center(child: Text('No results'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: patterns.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PatternCardWidget(pattern: patterns[index], rank: index + 1),
            ),
          );
        },
      ),
    );
  }
}
