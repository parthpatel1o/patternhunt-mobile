import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'search_overlay.dart';

/// Deep-link / fallback route for `/search` — same experience without expand-from-icon.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.card,
      body: SearchExperience(autofocus: true),
    );
  }
}
