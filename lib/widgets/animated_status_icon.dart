import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated icon with bounce-in for payment status transitions
class AnimatedStatusIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool pulse;

  const AnimatedStatusIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 80,
    this.pulse = false,
  });

  /// Success checkmark
  factory AnimatedStatusIcon.success({Key? key, double size = 80}) =>
      AnimatedStatusIcon(
        key: key,
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        size: size,
      );

  /// Error X
  factory AnimatedStatusIcon.error({Key? key, double size = 80}) =>
      AnimatedStatusIcon(
        key: key,
        icon: Icons.cancel_rounded,
        color: AppColors.error,
        size: size,
      );

  /// Processing hourglass with pulse
  factory AnimatedStatusIcon.processing({Key? key, double size = 80}) =>
      AnimatedStatusIcon(
        key: key,
        icon: Icons.hourglass_top_rounded,
        color: AppColors.warning,
        size: size,
        pulse: true,
      );

  /// Pending payment
  factory AnimatedStatusIcon.pending({Key? key, double size = 80}) =>
      AnimatedStatusIcon(
        key: key,
        icon: Icons.payment_rounded,
        color: AppColors.info,
        size: size,
      );

  /// Expired timer
  factory AnimatedStatusIcon.expired({Key? key, double size = 80}) =>
      AnimatedStatusIcon(
        key: key,
        icon: Icons.timer_off_rounded,
        color: AppColors.error,
        size: size,
      );

  @override
  State<AnimatedStatusIcon> createState() => _AnimatedStatusIconState();
}

class _AnimatedStatusIconState extends State<AnimatedStatusIcon>
    with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceScale;
  AnimationController? _pulseCtrl;
  Animation<double>? _pulseScale;

  @override
  void initState() {
    super.initState();

    // Bounce-in animation
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOutCubic));
    _bounceCtrl.forward();

    // Pulse animation (for processing state)
    if (widget.pulse) {
      _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      );
      _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut),
      );
      _pulseCtrl!.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _pulseCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget icon = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(widget.icon, size: widget.size, color: widget.color),
    );

    // Wrap with pulse if needed
    if (_pulseCtrl != null && _pulseScale != null) {
      icon = AnimatedBuilder(
        animation: _pulseCtrl!,
        builder: (context, child) => Transform.scale(
          scale: _pulseScale!.value,
          child: child,
        ),
        child: icon,
      );
    }

    // Wrap with bounce-in
    return AnimatedBuilder(
      animation: _bounceCtrl,
      builder: (context, child) => Transform.scale(
        scale: _bounceScale.value,
        child: child,
      ),
      child: icon,
    );
  }
}
