import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:moto_ride_os/widgets/digital_clock_widget.dart';

class SpeedometerWidget extends StatelessWidget {
  final double speed;
  final double maxSpeed;

  const SpeedometerWidget({
    super.key,
    required this.speed,
    this.maxSpeed = 240,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SpeedometerPainter(
        speed: speed,
        maxSpeed: maxSpeed,
        context: context,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Text(
              speed.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
                shadows: [
                  Shadow(
                      blurRadius: 20.0, color: Theme.of(context).primaryColor),
                ],
              ),
            ),
            // Replaced the old KM/H Text with the new DigitalClockWidget
            const DigitalClockWidget(),
          ],
        ),
      ),
    );
  }
}

class SpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final BuildContext context;

  SpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const sweepAngle = 3.14159 * 5 / 4; // 225 degrees
    const startAngle = 3.14159 * 3.5 / 4; // 157.5 degrees

    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final tickColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey;
    final majorTickColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    // Background Arc
    final backgroundPaint = Paint()
      ..color = theme.colorScheme.surfaceVariant.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Speed Arc
    final speedRatio = (speed / maxSpeed).clamp(0.0, 1.0);
    final speedAngle = sweepAngle * speedRatio;

    // Ensure the arc is at least minimally visible to show the 'dot'
    final effectiveSpeedAngle = speedAngle <= 0.001 ? 0.001 : speedAngle;

    final speedPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor.withOpacity(0.7), primaryColor],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      effectiveSpeedAngle, // Use the corrected angle here
      false,
      speedPaint,
    );

    // Ticks and Labels
    const majorTickInterval = 20;
    const minorTickInterval = 5;
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 2;
    final majorTickPaint = Paint()
      ..color = majorTickColor
      ..strokeWidth = 4;

    for (int i = 0; i <= maxSpeed; i += minorTickInterval) {
      final isMajorTick = i % majorTickInterval == 0;
      final angle = startAngle + (i / maxSpeed) * sweepAngle;
      final tickLength = isMajorTick ? 15.0 : 8.0;
      final innerRadius = radius - (isMajorTick ? 28 : 25);
      final outerRadius = innerRadius + tickLength;

      final startPoint = center + Offset(math.cos(angle) * innerRadius, math.sin(angle) * innerRadius);
      final endPoint = center + Offset(math.cos(angle) * outerRadius, math.sin(angle) * outerRadius);
      canvas.drawLine(startPoint, endPoint, isMajorTick ? majorTickPaint : tickPaint);

      if (isMajorTick) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: i.toString(),
            style: TextStyle(
              color: majorTickColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final textRadius = radius - 45;
        final textAngle = startAngle + (i / maxSpeed) * sweepAngle;
        final textOffset = Offset(
          center.dx + math.cos(textAngle) * textRadius - textPainter.width / 2,
          center.dy + math.sin(textAngle) * textRadius - textPainter.height / 2,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpeedometerPainter oldDelegate) {
    return speed != oldDelegate.speed ||
        maxSpeed != oldDelegate.maxSpeed ||
        context != oldDelegate.context;
  }
}
