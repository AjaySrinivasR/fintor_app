import 'package:flutter/material.dart';

class CompassIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CompassIcon({
    super.key,
    this.size = 22,
    this.color = const Color(0xFF1E3A8A),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CompassPainter(color: color),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final Color color;

  _CompassPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // SVG: <circle cx="12" cy="12" r="10"></circle>
    canvas.drawCircle(Offset(12 * scale, 12 * scale), 10 * scale, paint);

    // SVG: <polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"></polygon>
    final path = Path()
      ..moveTo(16.24 * scale, 7.76 * scale)
      ..lineTo(14.12 * scale, 14.12 * scale)
      ..lineTo(7.76 * scale, 16.24 * scale)
      ..lineTo(9.88 * scale, 9.88 * scale)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.color != color;
}
