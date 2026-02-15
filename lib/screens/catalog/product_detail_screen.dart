import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';

class ProductDetailScreen extends ConsumerWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: product.when(
        data: (p) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image placeholder
              Container(
                width: double.infinity,
                height: 300,
                color: AppColors.divider,
                child: p.imageUrl != null
                    ? Image.network(p.imageUrl!, fit: BoxFit.contain)
                    : const Icon(Icons.image_outlined, size: 80, color: AppColors.textLight),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category
                    if (p.categoryName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.categoryName!.split(' / ').last,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Name
                    Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),

                    // SKU
                    if (p.defaultCode != null)
                      Text('SKU: ${p.defaultCode}',
                          style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),

                    // Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${p.effectivePrice.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (p.hasDiscount) ...[
                          const SizedBox(width: 12),
                          Text(
                            '\$${p.listPrice.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textLight,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('-${p.discountPercent.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stock availability
                    Text('Disponibilidad', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (p.inStock)
                      ...p.stockByBranch.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, size: 18, color: AppColors.success),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(s.branch?.name ?? 'Sucursal',
                                      style: Theme.of(context).textTheme.bodyMedium),
                                ),
                                Text('${s.qtyAvailable.toInt()} unid.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        )),
                              ],
                            ),
                          ))
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.error),
                            const SizedBox(width: 12),
                            Text('Sin stock disponible',
                                style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),

                    // Description
                    if (p.description != null) ...[
                      const SizedBox(height: 24),
                      Text('Descripcion', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(p.description!, style: Theme.of(context).textTheme.bodyMedium),
                    ],

                    const SizedBox(height: 100), // space for FAB
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Error al cargar producto'),
              TextButton(
                onPressed: () => ref.invalidate(productDetailProvider(productId)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: product.whenOrNull(
        data: (p) => p.inStock
            ? FloatingActionButton.extended(
                onPressed: () {
                  // TODO: Add to cart
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Agregado al carrito')),
                  );
                },
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.secondary,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text('Agregar \$${p.effectivePrice.toStringAsFixed(2)}'),
              )
            : null,
      ),
    );
  }
}
