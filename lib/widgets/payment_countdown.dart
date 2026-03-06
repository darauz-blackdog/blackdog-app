import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/payment_state.dart';
import '../theme/app_theme.dart';

/// Circular countdown timer ring inspired by pagos-app
class PaymentCountdown extends StatelessWidget {
  final PaymentSession session;
  final double size;

  const PaymentCountdown({
    super.key,
    required this.session,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    final progress = session.countdownSeconds / PaymentSession.countdownDuration;
    final isLow = session.countdownSeconds < 60;
    final color = isLow ? AppColors.error : AppColors.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              color: color.withValues(alpha: 0.15),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Progress ring
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: progress, end: progress),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) => Transform.rotate(
                angle: -math.pi / 2,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: value,
                    color: color,
                    strokeWidth: 6,
                  ),
                ),
              ),
            ),
          ),
          // Time display
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLow ? Icons.warning_amber_rounded : Icons.timer_outlined,
                size: 24,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                session.countdownDisplay,
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
