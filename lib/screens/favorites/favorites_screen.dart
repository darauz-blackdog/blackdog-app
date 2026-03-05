import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_grid.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/product_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: favoriteIds.isEmpty
          ? _buildEmptyState(context)
          : _buildGrid(context, ref, favoriteIds.toList()),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 72,
              color: AppColors.textLight.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no tienes favoritos',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca el corazón en cualquier producto para guardarlo aquí.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/catalog'),
              child: const Text('Explorar catálogo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<int> ids) {
    return GridView.builder(
      padding: EdgeInsets.all(Responsive.paddingSmall(context)),
      gridDelegate: responsiveProductGrid(),
      itemCount: ids.length,
      itemBuilder: (context, index) {
        final productId = ids[index];
        final productAsync = ref.watch(productDetailProvider(productId));

        return productAsync.when(
          data: (product) => FadeInUp(
            delay: (index % 6) * 60,
            duration: const Duration(milliseconds: 400),
            offset: 20,
            child: ProductCard(
              product: product,
              isFavorite: true,
              onFavorite: () =>
                  ref.read(favoritesProvider.notifier).toggle(productId),
              onTap: () => context.push('/product/$productId'),
              onAddToCart: () async {
                try {
                  await ref.read(cartProvider.notifier).addItem(productId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} agregado al carrito'),
                        duration: const Duration(seconds: 1),
                        action: SnackBarAction(
                          label: 'Ver',
                          textColor: AppColors.primary,
                          onPressed: () => context.go('/cart'),
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error al agregar')),
                    );
                  }
                }
              },
            ),
          ),
          loading: () => const Card(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
    );
  }
}
