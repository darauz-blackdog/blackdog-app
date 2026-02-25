import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/product.dart';
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
  late int _activeProductId;
  bool _addingToCart = false;

  @override
  void initState() {
    super.initState();
    _activeProductId = widget.productId;
  }

  @override
  void didUpdateWidget(ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _activeProductId = widget.productId;
      _currentImageIndex = 0;
    }
  }

  void _switchVariant(int variantId) {
    if (variantId == _activeProductId) return;
    setState(() {
      _activeProductId = variantId;
      _currentImageIndex = 0;
    });
  }

  Future<void> _addToCart(ProductDetail p) async {
    setState(() => _addingToCart = true);
    try {
      await ref.read(cartProvider.notifier).addItem(p.id);
      if (mounted) {
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al agregar al carrito')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productDetailProvider(_activeProductId));

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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: product.when(
          data: (p) => Column(
            key: ValueKey(p.id),
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageGallery(p),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTags(context, p),
                            const SizedBox(height: 12),
                            Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
                            if (p.defaultCode != null) ...[
                              const SizedBox(height: 4),
                              Text('SKU: ${p.defaultCode}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textLight,
                                      )),
                            ],
                            const SizedBox(height: 16),
                            if (p.variants.length > 1) ...[
                              _buildVariantChips(context, p),
                              const SizedBox(height: 16),
                            ],
                            _buildPrice(context, p),
                            const SizedBox(height: 20),
                            _buildStockDropdown(context, p),
                            if (_hasDescription(p)) ...[
                              const SizedBox(height: 12),
                              _buildDescriptionCard(context, p),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sticky bottom bar
              _buildBottomBar(context, p),
            ],
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
                  onPressed: () => ref.invalidate(productDetailProvider(_activeProductId)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom bar with add to cart ──────────────────────────────

  Widget _buildBottomBar(BuildContext context, ProductDetail p) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: p.inStock
          ? SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _addingToCart ? null : () => _addToCart(p),
                icon: _addingToCart
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_shopping_cart),
                label: Text(
                  _addingToCart
                      ? 'Agregando...'
                      : 'Agregar al carrito  \$${p.effectivePrice.toStringAsFixed(2)}',
                ),
              ),
            )
          : SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.remove_shopping_cart_outlined),
                label: const Text('Agotado'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  foregroundColor: AppColors.error,
                  disabledForegroundColor: AppColors.error.withValues(alpha: 0.5),
                ),
              ),
            ),
    );
  }

  // ── Tags ─────────────────────────────────────────────────────

  Widget _buildTags(BuildContext context, ProductDetail p) {
    return Wrap(
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
    );
  }

  // ── Variant chips ────────────────────────────────────────────

  Widget _buildVariantChips(BuildContext context, ProductDetail p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.variants.any((v) => v.variantLabel != null && RegExp(r'^\d').hasMatch(v.variantLabel!))
              ? 'Tamaño'
              : 'Variante',
          style: Theme.of(context).textTheme.titleSmall,
        ),
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
              onSelected: (_) => _switchVariant(v.id),
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

  // ── Price ────────────────────────────────────────────────────

  Widget _buildPrice(BuildContext context, ProductDetail p) {
    return Row(
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
    );
  }

  // ── Stock dropdown ───────────────────────────────────────────

  Widget _buildStockDropdown(BuildContext context, ProductDetail p) {
    if (!p.inStock) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Text('Agotado en todas las sucursales',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final branchCount = p.stockByBranch.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(Icons.check_circle, size: 18, color: AppColors.success),
          title: Text(
            'Disponible en $branchCount sucursal${branchCount > 1 ? 'es' : ''}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.success,
            ),
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.success,
          ),
          children: [
            ...p.stockByBranch.map((s) {
              final qty = s.qtyAvailable.toInt();
              final name = s.branch?.name ?? 'Sucursal';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.store_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (qty <= 50)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: qty <= 5
                              ? AppColors.warning.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$qty uds',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: qty <= 5 ? AppColors.warning : AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Description ──────────────────────────────────────────────

  bool _hasDescription(ProductDetail p) {
    return (p.descriptionPlain != null && p.descriptionPlain!.isNotEmpty) ||
        p.description != null;
  }

  Widget _buildDescriptionCard(BuildContext context, ProductDetail p) {
    final text = (p.descriptionPlain != null && p.descriptionPlain!.isNotEmpty)
        ? p.descriptionPlain!
        : p.description ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Descripción', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Image gallery ────────────────────────────────────────────

  Widget _buildImageGallery(ProductDetail p) {
    final images = p.imageUrls;

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
          placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
          errorWidget: (_, _, _) =>
              const Icon(Icons.image_outlined, size: 80, color: AppColors.textLight),
        ),
      );
    }

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
                placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                errorWidget: (_, _, _) =>
                    const Icon(Icons.image_outlined, size: 80, color: AppColors.textLight),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
