import 'package:flutter/material.dart';

/// Matches the web board's max-w-6xl while preserving the phone viewport.
class RankBoardViewport extends StatelessWidget {
  const RankBoardViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).shortestSide < 600) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1152),
        child: child,
      ),
    );
  }
}
