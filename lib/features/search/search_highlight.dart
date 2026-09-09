import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Builds [InlineSpan]s with case-insensitive match highlighting.
List<InlineSpan> highlightQuerySpans(
  String text,
  String query, {
  TextStyle? style,
  TextStyle? highlightStyle,
}) {
  final base = style ?? const TextStyle(color: AppColors.foreground);
  final hi = highlightStyle ??
      base.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.accent,
        backgroundColor: AppColors.primary.withValues(alpha: 0.55),
      );

  final q = query.trim();
  if (q.isEmpty || text.isEmpty) {
    return [TextSpan(text: text, style: base)];
  }

  final lowerText = text.toLowerCase();
  final lowerQ = q.toLowerCase();
  final spans = <InlineSpan>[];
  var start = 0;

  while (true) {
    final index = lowerText.indexOf(lowerQ, start);
    if (index < 0) {
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: base));
      }
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: base));
    }
    spans.add(TextSpan(text: text.substring(index, index + q.length), style: hi));
    start = index + q.length;
  }

  return spans.isEmpty ? [TextSpan(text: text, style: base)] : spans;
}
