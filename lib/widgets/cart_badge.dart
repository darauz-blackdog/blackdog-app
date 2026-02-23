import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';

class CartBadge extends ConsumerWidget {
  const CartBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return IconButton(
      onPressed: () => context.go('/cart'),
      icon: cartAsync.when(
        data: (cart) {
          final count = cart?.items.fold(0, (sum, item) => sum + item.quantity) ?? 0;
          if (count == 0) {
            return const Icon(Icons.shopping_cart_outlined);
          }
          return Badge.count(
            count: count,
            backgroundColor: AppColors.primary,
            textColor: AppColors.secondary,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            child: const Icon(Icons.shopping_cart_outlined),
          );
        },
        loading: () => const Icon(Icons.shopping_cart_outlined),
        error: (_, __) => const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}
