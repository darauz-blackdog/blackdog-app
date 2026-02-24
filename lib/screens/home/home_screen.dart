import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_icon_box.dart';
import '../../widgets/cart_badge.dart';
import '../../widgets/product_carousel_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(appCategoriesProvider);
    final sections = ref.watch(homeSectionsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Glassmorphism header
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.85),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.transparent),
              ),
            ),
            title: Image.asset(
              'assets/images/logo_dark.png',
              height: 32,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            actions: [
              IconButton(
                onPressed: () {
                  // TODO: Notifications
                },
                icon: Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const CartBadge(),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: Theme.of(context).hintColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Buscar comida, juguetes, accesorios...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: Theme.of(context).colorScheme.surface,
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
                        Text(
                          'Categorías',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/catalog'),
                          child: Text(
                            'Ver todo',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
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
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final style = CategoryStyle.forAppCategory(
                            cats[i].icon,
                          );
                          return CategoryIconBox(
                            label: cats[i].name,
                            icon: style.icon,
                            backgroundColor: style.backgroundColor,
                            iconColor: style.iconColor,
                            onTap: () => context.go(
                              '/catalog?app_category_id=${cats[i].id}',
                            ),
                          );
                        },
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Brand/category sections
          sections.when(
            data: (sectionList) => SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final section = sectionList[i];
                return ProductCarouselSection(
                  title: section.title,
                  products: section.products,
                  onViewAll: () {
                    if (section.type == 'brand') {
                      final brand = Uri.encodeComponent(
                        section.filter['brand'] as String,
                      );
                      context.go('/catalog?brand=$brand');
                    } else {
                      context.go(
                        '/catalog?app_category_id=${section.filter['app_category_id']}',
                      );
                    }
                  },
                  onTap: (product) => context.push('/product/${product.id}'),
                  onAddToCart: (product) async {
                    try {
                      await ref.read(cartProvider.notifier).addItem(product.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${product.name} agregado al carrito',
                            ),
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
                );
              }, childCount: sectionList.length),
            ),
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar secciones',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(homeSectionsProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
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
