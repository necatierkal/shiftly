import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class ShiftlyLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? textColor;

  const ShiftlyLogo({
    super.key,
    this.size = 80,
    this.showText = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget icon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _ShiftlyLogoPainter(),
      ),
    );

    if (!showText) return icon;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(height: size * 0.16),
        Text(
          'SHIFTLY',
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: textColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          'Vardiyan. Takvimin. Ekibin.',
          style: TextStyle(
            fontSize: size * 0.15,
            fontWeight: FontWeight.w500,
            color:
                textColor?.withValues(alpha: 0.8) ??
                AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

class _ShiftlyLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Calendar Sheet (White with subtle shadow)
    final calRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.25, w * 0.56, h * 0.52),
      Radius.circular(w * 0.08),
    );
    final sheetPaint = Paint()..color = Colors.white;
    canvas.drawRRect(calRect, sheetPaint);

    // Calendar Header Stripe (Dark primary accent)
    final headerPath = Path();
    headerPath.moveTo(w * 0.22, h * 0.32);
    headerPath.arcToPoint(
      Offset(w * 0.30, h * 0.25),
      radius: Radius.circular(w * 0.08),
    );
    headerPath.lineTo(w * 0.70, h * 0.25);
    headerPath.arcToPoint(
      Offset(w * 0.78, h * 0.32),
      radius: Radius.circular(w * 0.08),
    );
    headerPath.lineTo(w * 0.78, h * 0.38);
    headerPath.lineTo(w * 0.22, h * 0.38);
    headerPath.close();

    final headerPaint = Paint()..color = AppColors.primaryDark;
    canvas.drawPath(headerPath, headerPaint);

    // 2. Calendar Binder Rings
    final ringPaint = Paint()..color = Colors.white;
    final ringStroke = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.015;

    final ring1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.20, w * 0.05, h * 0.10),
      Radius.circular(w * 0.025),
    );
    final ring2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.61, h * 0.20, w * 0.05, h * 0.10),
      Radius.circular(w * 0.025),
    );
    canvas.drawRRect(ring1, ringPaint);
    canvas.drawRRect(ring1, ringStroke);
    canvas.drawRRect(ring2, ringPaint);
    canvas.drawRRect(ring2, ringStroke);

    // 3. Shift Cycle Ring (Green/Teal arc)
    final center = Offset(w * 0.50, h * 0.58);
    final radius = w * 0.14;

    final cycleTrackPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035;
    canvas.drawCircle(center, radius, cycleTrackPaint);

    final cycleArcPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.04;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.4,
      false,
      cycleArcPaint,
    );

    // Arrow Head for cycle
    final arrowPaint = Paint()..color = AppColors.secondary;
    final arrowPath = Path();
    final arrowX = center.dx - radius * 0.85;
    final arrowY = center.dy - radius * 0.55;
    arrowPath.moveTo(arrowX, arrowY);
    arrowPath.lineTo(arrowX + w * 0.045, arrowY + h * 0.045);
    arrowPath.lineTo(arrowX + w * 0.05, arrowY - h * 0.015);
    arrowPath.close();
    canvas.drawPath(arrowPath, arrowPaint);

    // 4. Center Clock Hands (Blue & Amber)
    final hubPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(center, w * 0.022, hubPaint);

    final hourHandPaint = Paint()
      ..color = AppColors.primary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.024;
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - radius * 0.62),
      hourHandPaint,
    );

    final minuteHandPaint = Paint()
      ..color = AppColors.accent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.018;
    canvas.drawLine(
      center,
      Offset(center.dx + radius * 0.65, center.dy),
      minuteHandPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
