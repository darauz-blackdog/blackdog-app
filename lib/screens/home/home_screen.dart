import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_card.dart';
import '../../widgets/category_icon_box.dart';

import '../../widgets/cart_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredProductsProvider);
    final categories = ref.watch(categoriesProvider);


    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Glassmorphism header
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Colors.white.withOpacity(0.85), // Changed withValues to withOpacity
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.transparent),
              ),
            ),
            title: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 28,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'BLACK DOG',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {
                  // TODO: Notifications
                },
                icon: const Icon(Icons.notifications_outlined),
                color: AppColors.secondary,
              ),
              const CartBadge(),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: GestureDetector(
                onTap: () => context.go('/search'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.grayMedium,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: AppColors.textLight, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Buscar comida, juguetes, accesorios...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Categories section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Categorías',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                        GestureDetector(
                          onTap: () => context.go('/catalog'),
                          child: Text('Ver todo',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 110,
                    child: categories.when(
                      data: (cats) => ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: cats.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final style = CategoryStyle.forCategory(cats[i].name);
                          return CategoryIconBox(
                            label: cats[i].name.split(' / ').last,
                            icon: style.icon,
                            backgroundColor: style.backgroundColor,
                            iconColor: style.iconColor,
                            onTap: () =>
                                context.go('/catalog?category_id=${cats[i].id}'),
                          );
                        },
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Popular Products header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Productos Populares',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  GestureDetector(
                    onTap: () => context.go('/catalog'),
                    child: Text('Ver todo',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        )),
                  ),
                ],
              ),
            ),
          ),

          // Product grid
          featured.when(
            data: (products) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => ProductCard(
                    product: products[i],
                    onTap: () => context.push('/product/${products[i].id}'),
                    onAddToCart: () async {
                      try {
                        await ref.read(cartProvider.notifier).addItem(products[i].id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${products[i].name} agregado al carrito'),
                              duration: const Duration(seconds: 1),
                              action: SnackBarAction(
                                label: 'Ver',
                                textColor: AppColors.primary,
                                onPressed: () => context.go('/cart'),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error al agregar')),
                          );
                        }
                      }
                    },
                  ),
                  childCount: products.length,
                ),
              ),
            ),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48,
                        color: AppColors.textLight),
                    const SizedBox(height: 16),
                    Text('Error al cargar productos',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(featuredProductsProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}
