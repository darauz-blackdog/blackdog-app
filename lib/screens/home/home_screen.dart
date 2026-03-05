import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/address_selector_sheet.dart';
import '../../widgets/brand_circle.dart';
import '../../widgets/cart_badge.dart';
import '../../widgets/category_icon_box.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/hero_banner_carousel.dart';
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
          // ── Header with branch selector ──
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leadingWidth: 180,
            leading: const _BranchSelectorHeader(),
            title: Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/logo.png'
                  : 'assets/images/logo_dark.png',
              height: 28,
              fit: BoxFit.contain,
            ),
            actions: [
              Builder(builder: (ctx) {
                final unread = ref.watch(unreadCountProvider);
                return Stack(
                  children: [
                    IconButton(
                      onPressed: () => context.push('/notifications'),
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            '$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              }),
              const CartBadge(),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.15),
              ),
            ),
          ),

          // ── Search bar ──
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: 0,
              offset: 15,
              duration: const Duration(milliseconds: 400),
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
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
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
          ),

          // ── Hero Banner Carousel ──
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: 100,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: const Padding(
                padding: EdgeInsets.only(top: 20),
                child: HeroBannerCarousel(),
              ),
            ),
          ),

          // ── Featured categories (grid 2 cols, first 4) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: categories.when(
                data: (cats) {
                  final featured = cats.take(4).toList();
                  final rest = cats.length > 4 ? cats.sublist(4) : <dynamic>[];
                  return Column(
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
                                color:
                                    Theme.of(context).colorScheme.onSurface,
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
                      const SizedBox(height: 14),
                      // Grid of top 4 categories
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.45,
                          children: featured.map((cat) {
                            final style =
                                CategoryStyle.forAppCategory(cat.icon);
                            return FadeInUp(
                              delay: featured.indexOf(cat) * 80,
                              offset: 15,
                              duration: const Duration(milliseconds: 400),
                              child: CategoryIconBox(
                                label: cat.shortName,
                                icon: style.icon,
                                backgroundColor: style.backgroundColor,
                                iconColor: style.iconColor,
                                large: true,
                                productCount: cat.productCount > 0
                                    ? cat.productCount
                                    : null,
                                onTap: () => context.go(
                                  '/catalog?app_category_id=${cat.id}',
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Horizontal scroll for remaining categories
                      if (rest.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: rest.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final cat = rest[i];
                              final style =
                                  CategoryStyle.forAppCategory(cat.icon);
                              return CategoryIconBox(
                                label: cat.shortName,
                                icon: style.icon,
                                backgroundColor: style.backgroundColor,
                                iconColor: style.iconColor,
                                onTap: () => context.go(
                                  '/catalog?app_category_id=${cat.id}',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox(),
              ),
            ),
          ),

          // ── Brand logos row ──
          SliverToBoxAdapter(
            child: sections.when(
              data: (sectionList) {
                final brands = sectionList
                    .where((s) => s.type == 'brand')
                    .toList();
                if (brands.isEmpty) return const SizedBox.shrink();
                return FadeInUp(
                  delay: 200,
                  offset: 15,
                  duration: const Duration(milliseconds: 400),
                  child: BrandLogosRow(
                    brandSections: brands,
                    onTap: (brand) {
                      final encoded = Uri.encodeComponent(brand);
                      context.go('/catalog?brand=$encoded');
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),

          // ── Product sections ──
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
                      await ref
                          .read(cartProvider.notifier)
                          .addItem(product.id);
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
                          const SnackBar(
                            content: Text('Error al agregar'),
                          ),
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
                        onPressed: () =>
                            ref.invalidate(homeSectionsProvider),
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

/// Header widget showing address selector with nearest branch info
class _BranchSelectorHeader extends ConsumerWidget {
  const _BranchSelectorHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(selectedAddressProvider).valueOrNull;
    final nearest = ref.watch(nearestBranchProvider);

    return GestureDetector(
      onTap: () => showAddressSelectorSheet(context),
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    address != null ? 'Entregar en' : 'Enviar a',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          address?.label ?? 'Selecciona tu dirección',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  ),
                  if (nearest != null)
                    Text(
                      nearest.branch.name,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: nearest.isDeliveryAvailable
                            ? AppColors.primary
                            : Theme.of(context).hintColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
