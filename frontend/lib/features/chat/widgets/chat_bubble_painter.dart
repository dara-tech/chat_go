import 'package:flutter/material.dart';

class TelegramBubblePainter extends CustomPainter {
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final bool isMe;
  final double radius;
  final double tailWidth;

  const TelegramBubblePainter({
    required this.color,
    this.borderColor,
    this.borderWidth = 0.8,
    required this.isMe,
    this.radius = 18.0,
    this.tailWidth = 7.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    if (borderColor != null && borderWidth > 0) {
      final borderPaint = Paint()
        ..color = borderColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawPath(path, borderPaint);
    }
  }

  Path _buildPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final r = radius;
    final tw = tailWidth;

    if (isMe) {
      // Outgoing bubble: rounded pill, smooth curved beak tail at bottom-right
      path.moveTo(r, 0);
      path.lineTo(w - tw - r, 0);
      path.arcToPoint(Offset(w - tw, r), radius: Radius.circular(r));
      path.lineTo(w - tw, h - 14);
      // Curve out to tail point at (w, h)
      path.cubicTo(
        w - tw + 1.0,
        h - 6.0,
        w - 1.0,
        h - 1.5,
        w,
        h,
      );
      // Curve back into bottom edge
      path.cubicTo(
        w - 2.5,
        h,
        w - tw,
        h,
        w - tw - 8.0,
        h,
      );
      path.lineTo(r, h);
      path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
      path.lineTo(0, r);
      path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    } else {
      // Incoming bubble: rounded pill, smooth curved beak tail at bottom-left
      path.moveTo(tw + r, 0);
      path.lineTo(w - r, 0);
      path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
      path.lineTo(w, h - r);
      path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));
      path.lineTo(tw + 8.0, h);
      // Curve back into tail point at (0, h)
      path.cubicTo(
        tw,
        h,
        2.5,
        h,
        0,
        h,
      );
      // Curve up into left edge
      path.cubicTo(
        1.0,
        h - 1.5,
        tw - 1.0,
        h - 6.0,
        tw,
        h - 14,
      );
      path.lineTo(tw, r);
      path.arcToPoint(Offset(tw + r, 0), radius: Radius.circular(r));
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant TelegramBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.isMe != isMe ||
        oldDelegate.radius != radius ||
        oldDelegate.tailWidth != tailWidth;
  }
}
