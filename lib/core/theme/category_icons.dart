import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Lucide icons matching the web CategoryBar / SelectDropdown set:
/// LayoutGrid / Rabbit / Shirt / Gem / Shapes.
IconData categoryIcon(String? slug) {
  return switch (slug) {
    null || 'all' => LucideIcons.layoutGrid,
    'amigurumi' => LucideIcons.rabbit,
    'wearables' => LucideIcons.shirt,
    'accessories' => LucideIcons.gem,
    'other' => LucideIcons.shapes,
    _ => LucideIcons.shapes,
  };
}
