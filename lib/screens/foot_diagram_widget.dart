import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum MarkType { pressure, relief, missingToe, general }

class FootMark {
  final Offset position;
  final MarkType type;
  final double size;
  final String? note;
  FootMark({required this.position, required this.type,
            this.size = 12, this.note});

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

  Map<String, dynamic> toJson() => {
    'dx': position.dx,
    'dy': position.dy,
    'type': type.index,
    'size': size,
    'note': note,
  };

  factory FootMark.fromJson(Map<String, dynamic> j) => FootMark(
    position: Offset((j['dx'] as num).toDouble(), (j['dy'] as num).toDouble()),
    type: MarkType.values[j['type'] as int],
    size: (j['size'] as num).toDouble(),
    note: j['note'] as String?,
  );
}

class DrawPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  DrawPath({required this.points, required this.color, this.strokeWidth = 2.5});

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
    'color': color.value,
    'strokeWidth': strokeWidth,
  };

  factory DrawPath.fromJson(Map<String, dynamic> j) => DrawPath(
    points: (j['points'] as List)
        .map((p) => Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble()))
        .toList(),
    color: Color(j['color'] as int),
    strokeWidth: (j['strokeWidth'] as num).toDouble(),
  );
}

class DiagramData {
  final List<FootMark> leftMarks;
  final List<DrawPath> leftPaths;
  final List<FootMark> rightMarks;
  final List<DrawPath> rightPaths;

  DiagramData({
    required this.leftMarks,
    required this.leftPaths,
    required this.rightMarks,
    required this.rightPaths,
  });

  bool get isEmpty =>
      leftMarks.isEmpty && leftPaths.isEmpty &&
      rightMarks.isEmpty && rightPaths.isEmpty;

  String toJsonString() => jsonEncode({
    'leftMarks': leftMarks.map((m) => m.toJson()).toList(),
    'leftPaths': leftPaths.map((p) => p.toJson()).toList(),
    'rightMarks': rightMarks.map((m) => m.toJson()).toList(),
    'rightPaths': rightPaths.map((p) => p.toJson()).toList(),
  });

  factory DiagramData.fromJsonString(String jsonStr) {
    if (jsonStr.isEmpty) return DiagramData(
        leftMarks: [], leftPaths: [], rightMarks: [], rightPaths: []);
    try {
      final m = jsonDecode(jsonStr) as Map<String, dynamic>;
      return DiagramData(
        leftMarks: (m['leftMarks'] as List? ?? [])
            .map((e) => FootMark.fromJson(e as Map<String, dynamic>)).toList(),
        leftPaths: (m['leftPaths'] as List? ?? [])
            .map((e) => DrawPath.fromJson(e as Map<String, dynamic>)).toList(),
        rightMarks: (m['rightMarks'] as List? ?? [])
            .map((e) => FootMark.fromJson(e as Map<String, dynamic>)).toList(),
        rightPaths: (m['rightPaths'] as List? ?? [])
            .map((e) => DrawPath.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } catch (_) {
      return DiagramData(leftMarks: [], leftPaths: [], rightMarks: [], rightPaths: []);
    }
  }
}

enum DiagramMode { none, mark, draw }

class FootDiagramWidget extends StatefulWidget {
  final Function(bool)? onDrawModeChanged;
  final Function(DiagramData)? onDataChanged;
  final String initialData;
  final GlobalKey? leftRepaintKey;
  final GlobalKey? rightRepaintKey;

  const FootDiagramWidget({
    super.key,
    this.onDrawModeChanged,
    this.onDataChanged,
    this.initialData = '',
    this.leftRepaintKey,
    this.rightRepaintKey,
  });

  @override
  State<FootDiagramWidget> createState() => _FootDiagramWidgetState();
}

class _FootDiagramWidgetState extends State<FootDiagramWidget> {
  List<FootMark> _leftMarks = [];
  List<DrawPath> _leftPaths = [];
  List<FootMark> _rightMarks = [];
  List<DrawPath> _rightPaths = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialData.isNotEmpty) {
      final data = DiagramData.fromJsonString(widget.initialData);
      _leftMarks = List.from(data.leftMarks);
      _leftPaths = List.from(data.leftPaths);
      _rightMarks = List.from(data.rightMarks);
      _rightPaths = List.from(data.rightPaths);
    }
  }

  void _notifyDataChanged() {
    widget.onDataChanged?.call(DiagramData(
      leftMarks: List.from(_leftMarks),
      leftPaths: List.from(_leftPaths),
      rightMarks: List.from(_rightMarks),
      rightPaths: List.from(_rightPaths),
    ));
  }

  void _openFullScreen(BuildContext context, bool isLeft) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenFoot(
        label: isLeft ? 'Left' : 'Right',
        imagePath: isLeft ? 'assets/images/left_foot.png' : 'assets/images/right_foot.png',
        isLeft: isLeft,
        initialMarks: isLeft ? List.from(_leftMarks) : List.from(_rightMarks),
        initialPaths: isLeft ? List.from(_leftPaths) : List.from(_rightPaths),
        onSave: (marks, paths) {
          setState(() {
            if (isLeft) {
              _leftMarks = List.from(marks);
              _leftPaths = List.from(paths);
            } else {
              _rightMarks = List.from(marks);
              _rightPaths = List.from(paths);
            }
          });
          _notifyDataChanged();
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Right foot preview (shown on left side of screen)
            Expanded(child: _FootPreview(
              label: 'Right',
              imagePath: 'assets/images/right_foot.png',
              marks: _rightMarks,
              paths: _rightPaths,
              repaintKey: widget.rightRepaintKey,
              onTap: () => _openFullScreen(context, false),
            )),
            const SizedBox(width: 12),
            // Left foot preview (shown on right side of screen)
            Expanded(child: _FootPreview(
              label: 'Left',
              imagePath: 'assets/images/left_foot.png',
              marks: _leftMarks,
              paths: _leftPaths,
              repaintKey: widget.leftRepaintKey,
              onTap: () => _openFullScreen(context, true),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12, runSpacing: 4,
          children: MarkType.values.where((type) => type != MarkType.pressure).map((type) {
            final mark = FootMark(position: Offset.zero, type: type);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: mark.color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(mark.label,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]);
          }).toList(),
        ),
      ],
    );
  }
}

// Read-only preview of a foot diagram
class _FootPreview extends StatelessWidget {
  final String label;
  final String imagePath;
  final List<FootMark> marks;
  final List<DrawPath> paths;
  final GlobalKey? repaintKey;
  final VoidCallback onTap;

  const _FootPreview({
    required this.label,
    required this.imagePath,
    required this.marks,
    required this.paths,
    required this.onTap,
    this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label Foot',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            GestureDetector(
              onTap: onTap,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Color(0xFF4FC3F7), size: 16),
                  SizedBox(width: 4),
                  Text('Edit', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: RepaintBoundary(
            key: repaintKey,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          -1, 0, 0, 0, 255,
                           0,-1, 0, 0, 255,
                           0, 0,-1, 0, 255,
                           0, 0, 0, 1,   0,
                        ]),
                        child: Image.asset(imagePath, fit: BoxFit.contain),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _OverlayPainter(
                          marks: marks,
                          paths: paths,
                          currentPath: null,
                          drawColor: Colors.blue,
                          relative: true,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: marks.isEmpty && paths.isEmpty
                            ? const Center(
                                child: Text('Tap to add markings',
                                    style: TextStyle(color: Colors.white30, fontSize: 12)),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final List<FootMark> marks;
  final List<DrawPath> paths;
  final List<Offset>? currentPath;
  final Color drawColor;
  final bool relative;

  _OverlayPainter({
    required this.marks,
    required this.paths,
    required this.currentPath,
    required this.drawColor,
    this.relative = false,
  });

  Offset _scale(Offset p, Size size) =>
      relative ? Offset(p.dx * size.width, p.dy * size.height) : p;

  @override
  void paint(Canvas canvas, Size size) {
    for (final drawPath in paths) {
      if (drawPath.points.length < 2) continue;
      final paint = Paint()
        ..color = drawPath.color
        ..strokeWidth = drawPath.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      final first = _scale(drawPath.points.first, size);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < drawPath.points.length; i++) {
        final p = _scale(drawPath.points[i], size);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentPath != null && currentPath!.length >= 2) {
      final paint = Paint()
        ..color = drawColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      final first = _scale(currentPath!.first, size);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < currentPath!.length; i++) {
        final p = _scale(currentPath![i], size);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final mark in marks) {
      final pos = _scale(mark.position, size);
      final markSize = relative ? mark.size * (size.width / 300) : mark.size;
      canvas.drawCircle(pos, markSize / 2,
          Paint()..color = mark.color..style = PaintingStyle.fill);
      canvas.drawCircle(pos, markSize / 2,
          Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
      if (mark.note != null && mark.note!.isNotEmpty) {
        final tp = TextPainter(
          text: const TextSpan(text: '📝', style: TextStyle(fontSize: 10)),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, pos + Offset(markSize / 2, -markSize));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) => true;
}

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F3460) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF4FC3F7) : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: isSelected ? const Color(0xFF4FC3F7) : Colors.white54, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? Colors.white24 : Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: enabled ? Colors.white54 : Colors.white24, size: 16),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: enabled ? Colors.white54 : Colors.white24, fontSize: 12)),
        ]),
      ),
    );
  }
}

Future<ui.Image?> captureRepaintBoundary(GlobalKey key) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return await boundary.toImage(pixelRatio: 2.0);
  } catch (_) {
    return null;
  }
}

class _FullScreenFoot extends StatefulWidget {
  final String label;
  final String imagePath;
  final bool isLeft;
  final List<FootMark> initialMarks;
  final List<DrawPath> initialPaths;
  final Function(List<FootMark>, List<DrawPath>) onSave;

  const _FullScreenFoot({
    required this.label,
    required this.imagePath,
    required this.isLeft,
    required this.initialMarks,
    required this.initialPaths,
    required this.onSave,
  });

  @override
  State<_FullScreenFoot> createState() => _FullScreenFootState();
}

class _FullScreenFootState extends State<_FullScreenFoot> {
  late List<FootMark> _marks;
  late List<DrawPath> _paths;
  MarkType _selectedMarkType = MarkType.relief;
  Color _drawColor = Colors.blue;
  DiagramMode _mode = DiagramMode.mark;
  List<Offset>? _currentPath;
  List<dynamic> _history = [];
  List<dynamic> _redoStack = [];
  final _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _marks = List.from(widget.initialMarks);
    _paths = List.from(widget.initialPaths);
    _history = [..._marks, ..._paths];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final w = box.size.width;
        final h = box.size.height;
        setState(() {
          _marks = _marks.map((m) => FootMark(
            position: Offset(m.position.dx * w, m.position.dy * h),
            type: m.type, size: m.size, note: m.note)).toList();
          _paths = _paths.map((p) => DrawPath(
            points: p.points.map((pt) => Offset(pt.dx * w, pt.dy * h)).toList(),
            color: p.color, strokeWidth: p.strokeWidth)).toList();
          _history = [..._marks, ..._paths];
        });
      }
    });
  }

  Offset _getLocalPosition(Offset globalPosition) {
    final box = _canvasKey.currentContext!.findRenderObject() as RenderBox;
    return box.globalToLocal(globalPosition);
  }

  void _showNoteDialog(Offset position) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Add Note', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter note...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF4FC3F7))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final mark = FootMark(
                position: position,
                type: MarkType.general,
                note: controller.text.trim().isEmpty ? null : controller.text.trim(),
              );
              setState(() {
                _marks.add(mark);
                _history.add(mark);
                _redoStack.clear();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3460)),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text('${widget.label} Foot',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _marks.clear(); _paths.clear();
                _history.clear(); _redoStack.clear();
              });
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null) {
                final w = box.size.width;
                final h = box.size.height;
                final normMarks = _marks.map((m) => FootMark(
                  position: Offset(m.position.dx / w, m.position.dy / h),
                  type: m.type, size: m.size, note: m.note)).toList();
                final normPaths = _paths.map((p) => DrawPath(
                  points: p.points.map((pt) => Offset(pt.dx / w, pt.dy / h)).toList(),
                  color: p.color, strokeWidth: p.strokeWidth)).toList();
                widget.onSave(normMarks, normPaths);
              } else {
                widget.onSave(_marks, _paths);
              }
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(color: Color(0xFF4FC3F7))),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(children: [
                  _ModeButton(
                    label: 'Mark', icon: Icons.location_on,
                    isSelected: _mode == DiagramMode.mark,
                    onTap: () => setState(() => _mode = _mode == DiagramMode.mark ? DiagramMode.none : DiagramMode.mark),
                  ),
                  const SizedBox(width: 8),
                  _ModeButton(
                    label: 'Draw', icon: Icons.draw,
                    isSelected: _mode == DiagramMode.draw,
                    onTap: () => setState(() => _mode = _mode == DiagramMode.draw ? DiagramMode.none : DiagramMode.draw),
                  ),
                ]),
                if (_mode == DiagramMode.mark) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: MarkType.values.where((t) => t != MarkType.pressure).map((type) {
                      final mark = FootMark(position: Offset.zero, type: type);
                      final isSelected = _selectedMarkType == type;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMarkType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? mark.color.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? mark.color : Colors.white24),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 10, height: 10,
                                decoration: BoxDecoration(color: mark.color, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(mark.label,
                                style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white54, fontSize: 12)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (_mode == DiagramMode.draw) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Color:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(width: 8),
                    ...[Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.white].map((color) {
                      final isSelected = _drawColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _drawColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle,
                            border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent, width: 2),
                          ),
                        ),
                      );
                    }),
                  ]),
                ],
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.4)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Listener(
                    onPointerDown: _mode != DiagramMode.none ? (event) {
                      final local = _getLocalPosition(event.position);
                      if (_mode == DiagramMode.mark) {
                        if (_selectedMarkType == MarkType.general) {
                          _showNoteDialog(local);
                        } else {
                          setState(() {
                            final mark = FootMark(position: local, type: _selectedMarkType);
                            _marks.add(mark);
                            _history.add(mark);
                            _redoStack.clear();
                          });
                        }
                      } else if (_mode == DiagramMode.draw) {
                        setState(() => _currentPath = [local]);
                      }
                    } : null,
                    onPointerMove: _mode == DiagramMode.draw ? (event) {
                      final local = _getLocalPosition(event.position);
                      if (_currentPath != null) {
                        setState(() => _currentPath = [..._currentPath!, local]);
                      }
                    } : null,
                    onPointerUp: _mode == DiagramMode.draw ? (event) {
                      if (_currentPath != null) {
                        final dp = DrawPath(points: List.from(_currentPath!), color: _drawColor);
                        setState(() {
                          _paths.add(dp);
                          _history.add(dp);
                          _redoStack.clear();
                          _currentPath = null;
                        });
                      }
                    } : null,
                    child: Stack(
                      key: _canvasKey,
                      children: [
                        Positioned.fill(
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              -1, 0, 0, 0, 255,
                               0,-1, 0, 0, 255,
                               0, 0,-1, 0, 255,
                               0, 0, 0, 1,   0,
                            ]),
                            child: Image.asset(widget.imagePath, fit: BoxFit.contain),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _OverlayPainter(
                              marks: _marks,
                              paths: _paths,
                              currentPath: _currentPath,
                              drawColor: _drawColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _UndoRedoButton(
                  icon: Icons.undo, label: 'Undo',
                  enabled: _history.isNotEmpty,
                  onTap: () {
                    if (_history.isEmpty) return;
                    setState(() {
                      final last = _history.removeLast();
                      _redoStack.add(last);
                      if (last is FootMark) _marks.remove(last);
                      else if (last is DrawPath) _paths.remove(last);
                    });
                  },
                ),
                const SizedBox(width: 16),
                _UndoRedoButton(
                  icon: Icons.redo, label: 'Redo',
                  enabled: _redoStack.isNotEmpty,
                  onTap: () {
                    if (_redoStack.isEmpty) return;
                    setState(() {
                      final item = _redoStack.removeLast();
                      _history.add(item);
                      if (item is FootMark) _marks.add(item);
                      else if (item is DrawPath) _paths.add(item);
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


