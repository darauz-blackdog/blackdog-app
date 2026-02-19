import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/cart.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito'),
        actions: [
          cartAsync.whenOrNull(
                data: (cart) => cart != null && cart.items.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Vaciar carrito',
                        onPressed: () => _confirmClear(context, ref),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart == null || cart.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildCartContent(context, ref, cart);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.textLight),
              const SizedBox(height: 16),
              const Text('Error al cargar el carrito'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(cartProvider.notifier).refresh(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('Tu carrito esta vacio',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Explora nuestros productos y agrega tus favoritos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/catalog'),
              icon: const Icon(Icons.storefront_rounded),
              label: const Text('Ver productos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(BuildContext context, WidgetRef ref, Cart cart) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cart.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _CartItemCard(item: cart.items[index]);
            },
          ),
        ),
        // Bottom summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal',
                        style: Theme.of(context).textTheme.bodyLarge),
                    Text('\$${cart.subtotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            )),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Delivery',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text('Calculado en checkout',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push('/checkout'),
                    child: Text(
                        'Proceder al Checkout  •  \$${cart.subtotal.toStringAsFixed(2)}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar carrito'),
        content: const Text('¿Estas seguro de vaciar tu carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cartProvider.notifier).clear();
            },
            child: const Text('Vaciar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  final CartItem item;
  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: item.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.divider),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.divider,
                        child: const Icon(Icons.image_outlined,
                            color: AppColors.textLight),
                      ),
                    )
                  : Container(
                      color: AppColors.divider,
                      child: const Icon(Icons.image_outlined,
                          size: 32, color: AppColors.textLight),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName ?? 'Producto',
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${(item.productPrice ?? 0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Quantity selector
                    _QuantitySelector(
                      quantity: item.quantity,
                      onDecrement: () {
                        if (item.quantity > 1) {
                          ref
                              .read(cartProvider.notifier)
                              .updateItemQuantity(item.id, item.quantity - 1);
                        }
                      },
                      onIncrement: () {
                        ref
                            .read(cartProvider.notifier)
                            .updateItemQuantity(item.id, item.quantity + 1);
                      },
                    ),
                    const Spacer(),
                    // Line total
                    Text(
                      '\$${item.lineTotal.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Remove button
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textLight,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () =>
                ref.read(cartProvider.notifier).removeItem(item.id),
          ),
        ],
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantitySelector({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyButton(Icons.remove, onDecrement, quantity <= 1),
          Container(
            constraints: const BoxConstraints(minWidth: 36),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _qtyButton(Icons.add, onIncrement, false),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 18,
          color: disabled ? AppColors.textLight : AppColors.textPrimary,
        ),
      ),
    );
  }
}
