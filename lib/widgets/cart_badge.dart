import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';

class CartBadge extends ConsumerStatefulWidget {
  const CartBadge({super.key});

  @override
  ConsumerState<CartBadge> createState() => _CartBadgeState();
}

class _CartBadgeState extends ConsumerState<CartBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _checkPulse(int count) {
    if (count != _lastCount && count > 0) {
      _pulseCtrl.forward(from: 0);
    }
    _lastCount = count;
  }

  @override
  Widget build(BuildContext context) {
    // Uses .select()-optimized provider — only rebuilds when count changes
    final count = ref.watch(cartItemCountProvider);
    _checkPulse(count);

    return IconButton(
      onPressed: () => context.go('/cart'),
      icon: count == 0
          ? const Icon(Icons.shopping_cart_outlined)
          : ScaleTransition(
              scale: _pulseScale,
              child: Badge.count(
                count: count,
                backgroundColor: AppColors.primary,
                textColor: AppColors.secondary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
    );
  }
}
