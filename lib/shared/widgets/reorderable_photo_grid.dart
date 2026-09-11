import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// Wrap grid with immediate drag-handle reordering and between-image drop slots.
///
/// Each tile’s left/right halves are insert targets so users can drop *between*
/// photos (not only onto another tile). Drag starts from the handle immediately
/// (no long-press delay).
class ReorderablePhotoGrid extends StatefulWidget {
  const ReorderablePhotoGrid({
    super.key,
    required this.itemCount,
    required this.tileBuilder,
    required this.feedbackBuilder,
    required this.onReorder,
    this.trailing,
    this.enabled = true,
    this.tileSize = 112,
    this.spacing = 12,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) tileBuilder;
  final Widget Function(BuildContext context, int index) feedbackBuilder;
  final void Function(int from, int to) onReorder;
  final Widget? trailing;
  final bool enabled;
  final double tileSize;
  final double spacing;

  @override
  State<ReorderablePhotoGrid> createState() => _ReorderablePhotoGridState();
}

class _ReorderablePhotoGridState extends State<ReorderablePhotoGrid> {
  int? _draggingIndex;

  void _acceptInsert(int from, int insertBefore) {
    var to = insertBefore;
    if (from < insertBefore) to = insertBefore - 1;
    if (to < 0 || to >= widget.itemCount || from == to) return;
    HapticFeedback.selectionClick();
    widget.onReorder(from, to);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.spacing,
      children: [
        for (var i = 0; i < widget.itemCount; i++) _buildTile(context, i),
        if (widget.trailing != null) widget.trailing!,
      ],
    );
  }

  Widget _buildTile(BuildContext context, int index) {
    final tile = widget.tileBuilder(context, index);
    if (!widget.enabled) return tile;

    final dragging = _draggingIndex == index;

    return SizedBox(
      width: widget.tileSize,
      height: widget.tileSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 90),
              opacity: dragging ? 0.28 : 1,
              child: tile,
            ),
          ),
          // Left half → insert before this tile.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: widget.tileSize * 0.5,
            child: _InsertTarget(
              active: _draggingIndex != null && _draggingIndex != index,
              onWillAccept: (from) => from != index,
              onAccept: (from) => _acceptInsert(from, index),
              edge: _InsertEdge.before,
            ),
          ),
          // Right half → insert after this tile.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: widget.tileSize * 0.5,
            child: _InsertTarget(
              active: _draggingIndex != null && _draggingIndex != index,
              onWillAccept: (from) => from != index,
              onAccept: (from) => _acceptInsert(from, index + 1),
              edge: _InsertEdge.after,
            ),
          ),
          // Immediate drag handle — starts drag without long-press.
          Positioned(
            right: 2,
            bottom: 2,
            child: Draggable<int>(
              data: index,
              maxSimultaneousDrags: 1,
              onDragStarted: () => setState(() => _draggingIndex = index),
              onDragEnd: (_) {
                if (mounted) setState(() => _draggingIndex = null);
              },
              onDraggableCanceled: (_, __) {
                if (mounted) setState(() => _draggingIndex = null);
              },
              feedback: Material(
                elevation: 8,
                shadowColor: const Color(0x663D2F4A),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: widget.tileSize,
                  height: widget.tileSize,
                  child: widget.feedbackBuilder(context, index),
                ),
              ),
              childWhenDragging: const SizedBox.shrink(),
              child: Material(
                color: AppColors.card.withValues(alpha: 0.95),
                shape: const CircleBorder(),
                elevation: 1,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(Icons.drag_indicator_rounded, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _InsertEdge { before, after }

class _InsertTarget extends StatelessWidget {
  const _InsertTarget({
    required this.active,
    required this.onWillAccept,
    required this.onAccept,
    required this.edge,
  });

  final bool active;
  final bool Function(int from) onWillAccept;
  final void Function(int from) onAccept;
  final _InsertEdge edge;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => onWillAccept(details.data),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        // When idle, ignore pointer so crop/remove/tap still work.
        return IgnorePointer(
          ignoring: !active && !hovering,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutCubic,
            alignment: edge == _InsertEdge.before
                ? Alignment.centerLeft
                : Alignment.centerRight,
            color: Colors.transparent,
            child: hovering
                ? Container(
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.expand(),
          ),
        );
      },
    );
  }
}
