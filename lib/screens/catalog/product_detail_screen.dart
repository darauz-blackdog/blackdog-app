import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_badge.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productDetailProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          const CartBadge(),
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: product.when(
        data: (p) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image gallery
              _buildImageGallery(p),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category + Tags row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
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
                        ...p.tags.take(5).map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tag,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.secondary,
                                      fontSize: 11,
                                    ),
                              ),
                            )),
                      ],
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

                    // Variant selector chips
                    if (p.variants.length > 1) ...[
                      _buildVariantChips(context, p),
                      const SizedBox(height: 16),
                    ],

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

                    // Description (prefer Shopify HTML → plain text, fallback to Odoo description)
                    if (p.descriptionPlain != null && p.descriptionPlain!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(p.descriptionPlain!, style: Theme.of(context).textTheme.bodyMedium),
                    ] else if (p.description != null) ...[
                      const SizedBox(height: 24),
                      Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
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
                onPressed: () => ref.invalidate(productDetailProvider(widget.productId)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: product.whenOrNull(
        data: (p) => p.inStock
            ? FloatingActionButton.extended(
                onPressed: () async {
                  try {
                    await ref.read(cartProvider.notifier).addItem(p.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Agregado al carrito'),
                          action: SnackBarAction(
                            label: 'Ver carrito',
                            textColor: AppColors.primary,
                            onPressed: () => context.go('/cart'),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error al agregar al carrito')),
                      );
                    }
                  }
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

  Widget _buildVariantChips(BuildContext context, dynamic p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tamaño', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: p.variants.map<Widget>((v) {
            final isSelected = v.id == p.id;
            final hasStock = v.inStock;
            return ChoiceChip(
              label: Text(v.variantLabel ?? ''),
              selected: isSelected,
              onSelected: (_) {
                if (v.id != p.id) {
                  context.push('/product/${v.id}');
                }
              },
              backgroundColor: hasStock
                  ? null
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? AppColors.secondary
                    : hasStock
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).hintColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                decoration: hasStock ? null : TextDecoration.lineThrough,
              ),
              side: isSelected
                  ? BorderSide.none
                  : BorderSide(
                      color: hasStock
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImageGallery(dynamic p) {
    final images = p.imageUrls as List<String>;

    if (images.isEmpty) {
      return Container(
        width: double.infinity,
        height: 300,
        color: AppColors.divider,
        child: const Icon(Icons.image_outlined, size: 80, color: AppColors.textLight),
      );
    }

    if (images.length == 1) {
      return Container(
        width: double.infinity,
        height: 300,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: CachedNetworkImage(
          imageUrl: images.first,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.image_outlined, size: 80, color: AppColors.textLight),
        ),
      );
    }

    // Multiple images: PageView with indicators
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) => Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.contain,
                alignment: Alignment.center,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.image_outlined, size: 80, color: AppColors.textLight),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            images.length,
            (i) => Container(
              width: i == _currentImageIndex ? 20 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == _currentImageIndex ? AppColors.primary : AppColors.textLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
