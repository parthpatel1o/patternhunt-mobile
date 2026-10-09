import 'package:flutter/material.dart';

// Includes an iPad's 512px half-width landscape window, above phone widths.
const huntWideLayoutBreakpoint = 500.0;

/// Keeps the phone deck unchanged and gives tablets a bounded card and coach.
class HuntDeckLayout extends StatelessWidget {
  const HuntDeckLayout({super.key, required this.cards, this.coach});

  final List<Widget> cards;
  final Widget? coach;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < huntWideLayoutBreakpoint) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              ...cards,
              if (coach != null)
                Positioned(left: 12, right: 12, bottom: 12, child: coach!),
            ],
          ),
        );
      }

      final deck = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            key: const ValueKey('tablet-hunt-deck'),
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: cards,
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: coach == null
            ? deck
            : constraints.maxWidth >= 900
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: deck,
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(width: 300, child: coach),
                ],
              )
            : Column(
                children: [
                  Expanded(child: deck),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: coach,
                  ),
                ],
              ),
      );
    },
  );
}
