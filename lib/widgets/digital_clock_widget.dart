import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// A widget that displays the time in a retro, 7-segment digital format
/// with a refined neon glow effect, matching the application's theme.
class DigitalClockWidget extends StatefulWidget {
  final double height;
  final double width;

  const DigitalClockWidget({
    super.key,
    this.height = 35.0,
    this.width = 180.0,
  });

  @override
  _DigitalClockWidgetState createState() => _DigitalClockWidgetState();
}

class _DigitalClockWidgetState extends State<DigitalClockWidget> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: CustomPaint(
        painter: _DigitalClockPainter(
          time: _currentTime,
          themeColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

class _DigitalClockPainter extends CustomPainter {
  final DateTime time;
  final Color themeColor;

  _DigitalClockPainter({required this.time, required this.themeColor});

  static const Map<int, List<bool>> _digitSegments = {
    0: [true, true, true, false, true, true, true],
    1: [false, false, true, false, false, true, false],
    2: [true, false, true, true, true, false, true],
    3: [true, false, true, true, false, true, true],
    4: [false, true, true, true, false, true, false],
    5: [true, true, false, true, false, true, true],
    6: [true, true, false, true, true, true, true],
    7: [true, false, true, false, false, true, false],
    8: [true, true, true, true, true, true, true],
    9: [true, true, true, true, false, true, true],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final timeStr = intl.DateFormat('HHmmss').format(time);
    final showColon = time.second % 2 == 0;

    // --- Refined Layout (Grid System) & Glow ---
    final Paint activePaint = Paint()..color = themeColor;
    final Paint inactivePaint = Paint()
      ..color = themeColor.withOpacity(0.05); // Further dimmed inactive segments
    final Paint glowPaint = Paint()
      ..color = themeColor.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal, 3.0); // Reduced blur for a tighter glow

    // Grid system: 8 slots for HH:mm:ss
    final double slotWidth = size.width / 8;
    final double digitWidth =
        slotWidth * 0.7; // Use 70% of slot for the digit to create padding
    final double digitHeight = size.height;

    final List<String> timeChars = [
      timeStr[0],
      timeStr[1],
      ':',
      timeStr[2],
      timeStr[3],
      ':',
      timeStr[4],
      timeStr[5]
    ];

    for (int i = 0; i < timeChars.length; i++) {
      // Center each character within its slot for uniform spacing
      final double slotX = i * slotWidth;
      final double drawX = slotX + (slotWidth - digitWidth) / 2;

      final char = timeChars[i];
      if (char == ':') {
        _drawColon(canvas, drawX, digitHeight, showColon, activePaint,
            inactivePaint, glowPaint, digitWidth);
      } else {
        int digit = int.parse(char);
        _drawDigit(canvas, digit, drawX, digitWidth, digitHeight, activePaint,
            inactivePaint, glowPaint);
      }
    }
  }

  void _drawDigit(Canvas canvas, int digit, double x, double width,
      double height, Paint activePaint, Paint inactivePaint, Paint glowPaint) {
    final List<bool> segments = _digitSegments[digit]!;
    final double segThickness = width * 0.18;
    final double hSegWidth = width * 0.7;
    final double vSegHeight = height * 0.4;
    final double hPadding = (width - hSegWidth) / 2;
    final double vPadding = segThickness * 0.5;

    final List<Rect> rects = [
      Rect.fromLTWH(x + hPadding, 0, hSegWidth, segThickness),
      Rect.fromLTWH(x, vPadding, segThickness, vSegHeight),
      Rect.fromLTWH(
          x + width - segThickness, vPadding, segThickness, vSegHeight),
      Rect.fromLTWH(
          x + hPadding, (height - segThickness) / 2, hSegWidth, segThickness),
      Rect.fromLTWH(x, height / 2 + vPadding, segThickness, vSegHeight),
      Rect.fromLTWH(x + width - segThickness, height / 2 + vPadding,
          segThickness, vSegHeight),
      Rect.fromLTWH(
          x + hPadding, height - segThickness, hSegWidth, segThickness),
    ];

    for (int i = 0; i < 7; i++) {
      final paintToUse = segments[i] ? activePaint : inactivePaint;
      if (segments[i]) {
        canvas.drawRect(rects[i].inflate(segThickness * 0.3),
            glowPaint); // Reduced glow inflation
      }
      canvas.drawRect(rects[i], paintToUse);
    }
  }

  void _drawColon(Canvas canvas, double x, double height, bool isVisible,
      Paint activePaint, Paint inactivePaint, Paint glowPaint, double width) {
    final double dotSize = height * 0.1;
    final double centerX = x + width / 2;

    final Rect topDot =
    Rect.fromCenter(center: Offset(centerX, height * 0.25), width: dotSize, height: dotSize);
    final Rect bottomDot =
    Rect.fromCenter(center: Offset(centerX, height * 0.75), width: dotSize, height: dotSize);

    final paintToUse = isVisible ? activePaint : inactivePaint;
    if (isVisible) {
      canvas.drawRect(topDot.inflate(dotSize * 1.5), glowPaint);
      canvas.drawRect(bottomDot.inflate(dotSize * 1.5), glowPaint);
    }
    canvas.drawRect(topDot, paintToUse);
    canvas.drawRect(bottomDot, paintToUse);
  }

  @override
  bool shouldRepaint(covariant _DigitalClockPainter oldDelegate) {
    return time.second != oldDelegate.time.second ||
        themeColor != oldDelegate.themeColor;
  }
}