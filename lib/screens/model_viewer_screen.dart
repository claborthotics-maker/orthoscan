import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ModelViewerScreen extends StatefulWidget {
  final List<double> points; // flat [x,y,z,...]
  final List<double> mesh;   // flat triangle verts [x,y,z, x,y,z, x,y,z, ...]
  final String patientName;
  final VoidCallback onFinish;

  const ModelViewerScreen({
    super.key,
    required this.points,
    this.mesh = const [],
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

  late List<List<double>> _verts; // normalized vertices (points or mesh verts)
  bool _isMesh = false;

  @override
  void initState() {
    super.initState();
    _isMesh = widget.mesh.length >= 9;
    _normalize();
  }

  void _normalize() {
    final src = _isMesh ? widget.mesh : widget.points;
    _verts = [];
    if (src.length < 3) return;

    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    double minZ = double.infinity, maxZ = double.negativeInfinity;

    for (int i = 0; i < src.length - 2; i += 3) {
      final x = src[i], y = src[i + 1], z = src[i + 2];
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
    final maxRange = [maxX - minX, maxY - minY, maxZ - minZ]
        .reduce((a, b) => a > b ? a : b)
        .abs();
    final scale = maxRange == 0 ? 1.0 : 1.0 / maxRange;

    for (int i = 0; i < src.length - 2; i += 3) {
      _verts.add([
        (src[i] - cx) * scale,
        (src[i + 1] - cy) * scale,
        (src[i + 2] - cz) * scale,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _isMesh ? _verts.length ~/ 3 : _verts.length;

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
          Container(
            color: const Color(0xFF16213E),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.patientName,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                Text(_isMesh ? '$count triangles' : '$count points',
                    style: const TextStyle(
                        color: Color(0xFF4FC3F7),
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onScaleStart: (d) {
                _baseZoom = _zoom;
                _lastFocal = d.focalPoint;
              },
              onScaleUpdate: (d) {
                setState(() {
                  _zoom = (_baseZoom * d.scale).clamp(0.3, 5.0);
                  final delta = d.focalPoint - _lastFocal;
                  _lastFocal = d.focalPoint;
                  _rotationY += delta.dx * 0.01;
                  _rotationX += delta.dy * 0.01;
                  _rotationX = _rotationX.clamp(-math.pi / 2, math.pi / 2);
                });
              },
              child: Container(
                color: const Color(0xFF0A0A14),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _isMesh
                      ? _MeshPainter(
                          verts: _verts,
                          rotationX: _rotationX,
                          rotationY: _rotationY,
                          zoom: _zoom,
                        )
                      : _PointPainter(
                          verts: _verts,
                          rotationX: _rotationX,
                          rotationY: _rotationY,
                          zoom: _zoom,
                        ),
                ),
              ),
            ),
          ),
          Container(
            color: const Color(0xFF0A0A14),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text('Drag to rotate Â· Pinch to zoom',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
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

// Rotates a vertex by X then Y, returns [x, y, z]
List<double> _rotate(
    List<double> p, double cosX, double sinX, double cosY, double sinY) {
  final x = p[0], y = p[1], z = p[2];
  final x1 = x * cosY - z * sinY;
  final z1 = x * sinY + z * cosY;
  final y2 = y * cosX - z1 * sinX;
  final z2 = y * sinX + z1 * cosX;
  return [x1, y2, z2];
}

class _MeshPainter extends CustomPainter {
  final List<List<double>> verts; // 3 per triangle
  final double rotationX, rotationY, zoom;

  _MeshPainter({
    required this.verts,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (verts.length < 3) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = math.min(size.width, size.height) * 0.6 * zoom;

    final cosX = math.cos(rotationX), sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY), sinY = math.sin(rotationY);

    final triCount = verts.length ~/ 3;
    final tris = <_Tri>[];

    for (int t = 0; t < triCount; t++) {
      final a = _rotate(verts[t * 3], cosX, sinX, cosY, sinY);
      final b = _rotate(verts[t * 3 + 1], cosX, sinX, cosY, sinY);
      final c = _rotate(verts[t * 3 + 2], cosX, sinX, cosY, sinY);

      // Normal via cross product
      final e1x = b[0] - a[0], e1y = b[1] - a[1], e1z = b[2] - a[2];
      final e2x = c[0] - a[0], e2y = c[1] - a[1], e2z = c[2] - a[2];
      final nx = e1y * e2z - e1z * e2y;
      final ny = e1z * e2x - e1x * e2z;
      final nz = e1x * e2y - e1y * e2x;
      final nlen = math.sqrt(nx * nx + ny * ny + nz * nz);
      final shade = nlen == 0 ? 0.5 : (0.25 + 0.75 * (nz / nlen).abs());

      final avgZ = (a[2] + b[2] + c[2]) / 3;
      final p0 = Offset(cx + a[0] * scale, cy + a[1] * scale);
      final p1 = Offset(cx + b[0] * scale, cy + b[1] * scale);
      final p2 = Offset(cx + c[0] * scale, cy + c[1] * scale);
      tris.add(_Tri(p0, p1, p2, avgZ, shade.clamp(0.0, 1.0)));
    }

    // Back-to-front
    tris.sort((a, b) => a.z.compareTo(b.z));

    final positions = <Offset>[];
    final colors = <Color>[];
    for (final tri in tris) {
      final g = (tri.shade * 255).round();
      // slight cool tint
      final color = Color.fromARGB(255, (g * 0.85).round(),
          (g * 0.92).round(), g);
      positions.add(tri.p0);
      positions.add(tri.p1);
      positions.add(tri.p2);
      colors.add(color);
      colors.add(color);
      colors.add(color);
    }

    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
    );
    canvas.drawVertices(vertices, ui.BlendMode.srcOver, Paint());
  }

  @override
  bool shouldRepaint(covariant _MeshPainter old) =>
      old.rotationX != rotationX ||
      old.rotationY != rotationY ||
      old.zoom != zoom;
}

class _Tri {
  final Offset p0, p1, p2;
  final double z;
  final double shade;
  _Tri(this.p0, this.p1, this.p2, this.z, this.shade);
}

class _PointPainter extends CustomPainter {
  final List<List<double>> verts;
  final double rotationX, rotationY, zoom;

  _PointPainter({
    required this.verts,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (verts.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = math.min(size.width, size.height) * 0.6 * zoom;
    final cosX = math.cos(rotationX), sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY), sinY = math.sin(rotationY);

    final projected = <List<double>>[];
    for (final p in verts) {
      final r = _rotate(p, cosX, sinX, cosY, sinY);
      projected.add([cx + r[0] * scale, cy + r[1] * scale, r[2]]);
    }
    projected.sort((a, b) => a[2].compareTo(b[2]));
    final minZ = projected.first[2];
    final maxZ = projected.last[2];
    final rangeZ = (maxZ - minZ).abs() < 1e-6 ? 1.0 : (maxZ - minZ);

    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in projected) {
      final t = 1.0 - (p[2] - minZ) / rangeZ; // near = 1, far = 0
      paint.color = _shadeColor(t);
      canvas.drawCircle(Offset(p[0], p[1]), 2.6, paint);
    }
  }

  Color _shadeColor(double t) {
    // Single cool-grey tone, brighter when nearer
    final v = (50 + 190 * t).round().clamp(0, 255);
    return Color.fromARGB(
        255, (v * 0.82).round(), (v * 0.9).round(), v);
  }

  @override
  bool shouldRepaint(covariant _PointPainter old) =>
      old.rotationX != rotationX ||
      old.rotationY != rotationY ||
      old.zoom != zoom;
}
