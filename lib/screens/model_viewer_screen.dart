import 'dart:math' as math;
import 'package:flutter/material.dart';

class ModelViewerScreen extends StatefulWidget {
  final List<double> points; // flat [x,y,z, x,y,z, ...]
  final String patientName;
  final VoidCallback onFinish;

  const ModelViewerScreen({
    super.key,
    required this.points,
    required this.patientName,
    required this.onFinish,
  });

  @override
  State<ModelViewerScreen> createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends State<ModelViewerScreen> {
  double _rotationX = -0.3;
  double _rotationY = 0.0;
  double _zoom = 1.0;
  double _baseZoom = 1.0;
  Offset _lastFocal = Offset.zero;

  // Normalized points centered at origin
  late List<List<double>> _normalizedPoints;
  double _modelScale = 1.0;

  @override
  void initState() {
    super.initState();
    _normalizePoints();
  }

  void _normalizePoints() {
    final pts = widget.points;
    _normalizedPoints = [];
    if (pts.length < 3) return;

    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    double minZ = double.infinity, maxZ = double.negativeInfinity;

    for (int i = 0; i < pts.length - 2; i += 3) {
      final x = pts[i], y = pts[i + 1], z = pts[i + 2];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      if (z < minZ) minZ = z;
      if (z > maxZ) maxZ = z;
    }

    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final cz = (minZ + maxZ) / 2;

    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    final rangeZ = maxZ - minZ;
    final maxRange = [rangeX, rangeY, rangeZ]
        .reduce((a, b) => a > b ? a : b)
        .abs();
    _modelScale = maxRange == 0 ? 1.0 : 1.0 / maxRange;

    for (int i = 0; i < pts.length - 2; i += 3) {
      _normalizedPoints.add([
        (pts[i] - cx) * _modelScale,
        (pts[i + 1] - cy) * _modelScale,
        (pts[i + 2] - cz) * _modelScale,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointCount = _normalizedPoints.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('3D Scan Preview',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Info bar
          Container(
            color: const Color(0xFF16213E),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.patientName,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                Text('$pointCount points',
                    style: const TextStyle(
                        color: Color(0xFF4FC3F7),
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // 3D viewer
          Expanded(
            child: GestureDetector(
              onScaleStart: (details) {
                _baseZoom = _zoom;
                _lastFocal = details.focalPoint;
              },
              onScaleUpdate: (details) {
                setState(() {
                  // Zoom
                  _zoom = (_baseZoom * details.scale)
                      .clamp(0.3, 5.0);
                  // Rotate via drag
                  final delta = details.focalPoint - _lastFocal;
                  _lastFocal = details.focalPoint;
                  _rotationY += delta.dx * 0.01;
                  _rotationX += delta.dy * 0.01;
                  _rotationX = _rotationX.clamp(-math.pi / 2, math.pi / 2);
                });
              },
              child: Container(
                color: const Color(0xFF0A0A14),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PointCloud3DPainter(
                    points: _normalizedPoints,
                    rotationX: _rotationX,
                    rotationY: _rotationY,
                    zoom: _zoom,
                  ),
                ),
              ),
            ),
          ),

          // Hint
          Container(
            color: const Color(0xFF0A0A14),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text(
              'Drag to rotate · Pinch to zoom',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),

          // Controls
          Container(
            color: const Color(0xFF16213E),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh,
                    color: Colors.white54, size: 20),
                label: const Text('Rescan',
                    style: TextStyle(color: Colors.white54)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onFinish,
                  icon: const Icon(Icons.check_circle,
                      color: Colors.white, size: 24),
                  label: const Text('Finish & Save',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PointCloud3DPainter extends CustomPainter {
  final List<List<double>> points;
  final double rotationX;
  final double rotationY;
  final double zoom;

  _PointCloud3DPainter({
    required this.points,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = math.min(size.width, size.height) * 0.6 * zoom;

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);

    // Project all points, keep depth for coloring + sorting
    final projected = <List<double>>[];
    for (final p in points) {
      var x = p[0], y = p[1], z = p[2];

      // Rotate around Y
      final x1 = x * cosY - z * sinY;
      final z1 = x * sinY + z * cosY;
      // Rotate around X
      final y2 = y * cosX - z1 * sinX;
      final z2 = y * sinX + z1 * cosX;

      final screenX = cx + x1 * scale;
      final screenY = cy + y2 * scale;
      projected.add([screenX, screenY, z2]);
    }

    // Sort back-to-front so near points draw on top
    projected.sort((a, b) => a[2].compareTo(b[2]));

    double minZ = projected.first[2];
    double maxZ = projected.last[2];
    final rangeZ = (maxZ - minZ).abs() < 1e-6 ? 1.0 : (maxZ - minZ);

    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in projected) {
      final t = (p[2] - minZ) / rangeZ; // 0 near .. 1 far
      paint.color = _depthColor(1.0 - t);
      canvas.drawCircle(Offset(p[0], p[1]), 2.2, paint);
    }
  }

  Color _depthColor(double t) {
    // t=1 near (warm), t=0 far (cool)
    if (t > 0.66) {
      return Color.lerp(Colors.orange, Colors.red, (t - 0.66) * 3)!;
    } else if (t > 0.33) {
      return Color.lerp(Colors.yellow, Colors.orange, (t - 0.33) * 3)!;
    } else {
      return Color.lerp(Colors.blue, Colors.yellow, t * 3)!;
    }
  }

  @override
  bool shouldRepaint(covariant _PointCloud3DPainter old) =>
      old.rotationX != rotationX ||
      old.rotationY != rotationY ||
      old.zoom != zoom;
}