import 'package:flutter/material.dart';

enum MarkType { pressure, relief, missingToe, general }

class FootMark {
  final Offset position;
  final MarkType type;
  final double size;
  FootMark({required this.position, required this.type, this.size = 12});

  Color get color {
    switch (type) {
      case MarkType.pressure: return Colors.red;
      case MarkType.relief: return Colors.green;
      case MarkType.missingToe: return Colors.orange;
      case MarkType.general: return Colors.white;
    }
  }

  String get label {
    switch (type) {
      case MarkType.pressure: return 'Pressure';
      case MarkType.relief: return 'Relief';
      case MarkType.missingToe: return 'Missing Toe';
      case MarkType.general: return 'Note';
    }
  }
}

class DrawPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  DrawPath({required this.points, required this.color, this.strokeWidth = 2.5});
}

enum DiagramMode { mark, draw }

class FootDiagramWidget extends StatefulWidget {
  final Function(bool)? onDrawModeChanged;
  const FootDiagramWidget({super.key, this.onDrawModeChanged});

  @override
  State<FootDiagramWidget> createState() => _FootDiagramWidgetState();
}

class _FootDiagramWidgetState extends State<FootDiagramWidget> {
  DiagramMode _mode = DiagramMode.mark;
  MarkType _selectedMarkType = MarkType.pressure;
  Color _drawColor = Colors.blue;

  List<FootMark> _leftMarks = [];
  List<DrawPath> _leftPaths = [];
  List<dynamic> _leftHistory = [];
  List<dynamic> _leftRedoStack = [];

  List<FootMark> _rightMarks = [];
  List<DrawPath> _rightPaths = [];
  List<dynamic> _rightHistory = [];
  List<dynamic> _rightRedoStack = [];

  List<Offset>? _currentLeftPath;
  List<Offset>? _currentRightPath;

  void _setMode(DiagramMode mode) {
    setState(() => _mode = mode);
    widget.onDrawModeChanged?.call(mode == DiagramMode.draw);
  }

  void _undoLeft() {
    if (_leftHistory.isEmpty) return;
    setState(() {
      final last = _leftHistory.removeLast();
      _leftRedoStack.add(last);
      if (last is FootMark) _leftMarks.remove(last);
      else if (last is DrawPath) _leftPaths.remove(last);
    });
  }

  void _redoLeft() {
    if (_leftRedoStack.isEmpty) return;
    setState(() {
      final item = _leftRedoStack.removeLast();
      _leftHistory.add(item);
      if (item is FootMark) _leftMarks.add(item);
      else if (item is DrawPath) _leftPaths.add(item);
    });
  }

  void _undoRight() {
    if (_rightHistory.isEmpty) return;
    setState(() {
      final last = _rightHistory.removeLast();
      _rightRedoStack.add(last);
      if (last is FootMark) _rightMarks.remove(last);
      else if (last is DrawPath) _rightPaths.remove(last);
    });
  }

  void _redoRight() {
    if (_rightRedoStack.isEmpty) return;
    setState(() {
      final item = _rightRedoStack.removeLast();
      _rightHistory.add(item);
      if (item is FootMark) _rightMarks.add(item);
      else if (item is DrawPath) _rightPaths.add(item);
    });
  }

  void _clearLeft() {
    setState(() {
      _leftMarks.clear(); _leftPaths.clear();
      _leftHistory.clear(); _leftRedoStack.clear();
    });
  }

  void _clearRight() {
    setState(() {
      _rightMarks.clear(); _rightPaths.clear();
      _rightHistory.clear(); _rightRedoStack.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode switcher
        Row(children: [
          _ModeButton(label: 'Mark', icon: Icons.location_on,
              isSelected: _mode == DiagramMode.mark,
              onTap: () => _setMode(DiagramMode.mark)),
          const SizedBox(width: 8),
          _ModeButton(label: 'Draw', icon: Icons.draw,
              isSelected: _mode == DiagramMode.draw,
              onTap: () => _setMode(DiagramMode.draw)),
          if (_mode == DiagramMode.draw) ...[
            const SizedBox(width: 12),
            const Text('✏️ Scroll locked',
                style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 12)),
          ],
        ]),

        const SizedBox(height: 12),

        // Mark type selector
        if (_mode == DiagramMode.mark)
          Wrap(
            spacing: 6, runSpacing: 6,
            children: MarkType.values.map((type) {
              final mark = FootMark(position: Offset.zero, type: type);
              final isSelected = _selectedMarkType == type;
              return GestureDetector(
                onTap: () => setState(() => _selectedMarkType = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? mark.color.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isSelected ? mark.color : Colors.white24),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: mark.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(mark.label, style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 12)),
                  ]),
                ),
              );
            }).toList(),
          ),

        // Draw color selector
        if (_mode == DiagramMode.draw)
          Row(children: [
            const Text('Color:',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(width: 8),
            ...[Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.white]
                .map((color) {
              final isSelected = _drawColor == color;
              return GestureDetector(
                onTap: () => setState(() => _drawColor = color),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle,
                    border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2),
                  ),
                ),
              );
            }),
          ]),

        const SizedBox(height: 12),

        // Foot canvases
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _FootCanvas(
              label: 'Left',
              imagePath: 'assets/images/left_foot.png',
              mode: _mode,
              selectedMarkType: _selectedMarkType,
              drawColor: _drawColor,
              marks: _leftMarks,
              paths: _leftPaths,
              currentPath: _currentLeftPath,
              canUndo: _leftHistory.isNotEmpty,
              canRedo: _leftRedoStack.isNotEmpty,
              onMarkAdded: (mark) => setState(() {
                _leftMarks.add(mark);
                _leftHistory.add(mark);
                _leftRedoStack.clear();
              }),
              onPathStarted: (p) => setState(() => _currentLeftPath = p),
              onPathUpdated: (p) => setState(() => _currentLeftPath = p),
              onPathCompleted: (p) {
                final dp = DrawPath(points: List.from(p), color: _drawColor);
                setState(() {
                  _leftPaths.add(dp); _leftHistory.add(dp);
                  _leftRedoStack.clear(); _currentLeftPath = null;
                });
              },
              onUndo: _undoLeft, onRedo: _redoLeft, onClear: _clearLeft,
            )),
            const SizedBox(width: 12),
            Expanded(child: _FootCanvas(
              label: 'Right',
              imagePath: 'assets/images/right_foot.png',
              mode: _mode,
              selectedMarkType: _selectedMarkType,
              drawColor: _drawColor,
              marks: _rightMarks,
              paths: _rightPaths,
              currentPath: _currentRightPath,
              canUndo: _rightHistory.isNotEmpty,
              canRedo: _rightRedoStack.isNotEmpty,
              onMarkAdded: (mark) => setState(() {
                _rightMarks.add(mark);
                _rightHistory.add(mark);
                _rightRedoStack.clear();
              }),
              onPathStarted: (p) => setState(() => _currentRightPath = p),
              onPathUpdated: (p) => setState(() => _currentRightPath = p),
              onPathCompleted: (p) {
                final dp = DrawPath(points: List.from(p), color: _drawColor);
                setState(() {
                  _rightPaths.add(dp); _rightHistory.add(dp);
                  _rightRedoStack.clear(); _currentRightPath = null;
                });
              },
              onUndo: _undoRight, onRedo: _redoRight, onClear: _clearRight,
            )),
          ],
        ),

        const SizedBox(height: 12),

        // Legend
        Wrap(
          spacing: 12, runSpacing: 4,
          children: MarkType.values.map((type) {
            final mark = FootMark(position: Offset.zero, type: type);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: mark.color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(mark.label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ]);
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Foot Canvas ──────────────────────────────────────────────────────────────
class _FootCanvas extends StatelessWidget {
  final String label;
  final String imagePath;
  final DiagramMode mode;
  final MarkType selectedMarkType;
  final Color drawColor;
  final List<FootMark> marks;
  final List<DrawPath> paths;
  final List<Offset>? currentPath;
  final bool canUndo;
  final bool canRedo;
  final Function(FootMark) onMarkAdded;
  final Function(List<Offset>) onPathStarted;
  final Function(List<Offset>) onPathUpdated;
  final Function(List<Offset>) onPathCompleted;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;

  const _FootCanvas({
    required this.label,
    required this.imagePath,
    required this.mode,
    required this.selectedMarkType,
    required this.drawColor,
    required this.marks,
    required this.paths,
    required this.currentPath,
    required this.canUndo,
    required this.canRedo,
    required this.onMarkAdded,
    required this.onPathStarted,
    required this.onPathUpdated,
    required this.onPathCompleted,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Label + clear
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label Foot',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          GestureDetector(
            onTap: onClear,
            child: const Text('Clear',
                style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
        ],
      ),
      const SizedBox(height: 6),

      // Canvas with image background
      Container(
        height: 320,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Listener(
            onPointerDown: (event) {
              final box = context.findRenderObject() as RenderBox;
              final local = box.globalToLocal(event.position);
              if (mode == DiagramMode.mark) {
                onMarkAdded(FootMark(
                    position: local, type: selectedMarkType));
              } else {
                onPathStarted([local]);
              }
            },
            onPointerMove: (event) {
              if (mode == DiagramMode.draw) {
                final box = context.findRenderObject() as RenderBox;
                final local = box.globalToLocal(event.position);
                if (currentPath != null) {
                  onPathUpdated([...currentPath!, local]);
                }
              }
            },
            onPointerUp: (event) {
              if (mode == DiagramMode.draw && currentPath != null) {
                onPathCompleted(currentPath!);
              }
            },
            child: Stack(
              children: [
                // Foot image with color filter to match dark theme
       Positioned.fill(
  child: ColorFiltered(
  colorFilter: const ColorFilter.matrix([
    -1,  0,  0, 0, 255,
     0, -1,  0, 0, 255,
     0,  0, -1, 0, 255,
     0,  0,  0, 1,   0,
  ]),
  child: Image.asset(
    imagePath,
    fit: BoxFit.contain,
  ),
),
),
                // Drawing layer on top
                Positioned.fill(
                  child: CustomPaint(
                    painter: _OverlayPainter(
                      marks: marks,
                      paths: paths,
                      currentPath: currentPath,
                      drawColor: drawColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      const SizedBox(height: 6),

      // Undo/Redo
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _UndoRedoButton(
              icon: Icons.undo, label: 'Undo',
              enabled: canUndo, onTap: onUndo),
          const SizedBox(width: 16),
          _UndoRedoButton(
              icon: Icons.redo, label: 'Redo',
              enabled: canRedo, onTap: onRedo),
        ],
      ),
    ]);
  }
}

// ─── Overlay Painter (marks and drawings only) ────────────────────────────────
class _OverlayPainter extends CustomPainter {
  final List<FootMark> marks;
  final List<DrawPath> paths;
  final List<Offset>? currentPath;
  final Color drawColor;

  _OverlayPainter({
    required this.marks,
    required this.paths,
    required this.currentPath,
    required this.drawColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed paths
    for (final drawPath in paths) {
      if (drawPath.points.length < 2) continue;
      final paint = Paint()
        ..color = drawPath.color
        ..strokeWidth = drawPath.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      path.moveTo(drawPath.points.first.dx, drawPath.points.first.dy);
      for (int i = 1; i < drawPath.points.length; i++) {
        path.lineTo(drawPath.points[i].dx, drawPath.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Current path being drawn
    if (currentPath != null && currentPath!.length >= 2) {
      final paint = Paint()
        ..color = drawColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      path.moveTo(currentPath!.first.dx, currentPath!.first.dy);
      for (int i = 1; i < currentPath!.length; i++) {
        path.lineTo(currentPath![i].dx, currentPath![i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Marks
    for (final mark in marks) {
      canvas.drawCircle(mark.position, mark.size / 2,
          Paint()..color = mark.color..style = PaintingStyle.fill);
      canvas.drawCircle(mark.position, mark.size / 2,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) => true;
}

// ─── Mode Button ──────────────────────────────────────────────────────────────
class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label, required this.icon,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F3460)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF4FC3F7)
                  : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: isSelected
                  ? const Color(0xFF4FC3F7)
                  : Colors.white54,
              size: 18),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected
                  ? FontWeight.bold
                  : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// ─── Undo Redo Button ─────────────────────────────────────────────────────────
class _UndoRedoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _UndoRedoButton({
    required this.icon, required this.label,
    required this.enabled, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled ? Colors.white24 : Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: enabled ? Colors.white54 : Colors.white24,
              size: 16),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
              color: enabled ? Colors.white54 : Colors.white24,
              fontSize: 12)),
        ]),
      ),
    );
  }
}