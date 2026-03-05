import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/branch_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_circle.dart';
import '../../widgets/cart_badge.dart';
import '../../widgets/category_icon_box.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/hero_banner_carousel.dart';
import '../../widgets/product_carousel_section.dart';
import '../../widgets/skeleton_loaders.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            centerTitle: false,
            titleSpacing: 0,
            title: const _BranchSelectorHeader(),
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

          // ── Featured categories ──
          const SliverToBoxAdapter(child: _CategoriesSection()),

          // ── Brand logos row ──
          const SliverToBoxAdapter(child: _BrandLogosSection()),

          // ── Product sections ──
          const _ProductSectionsSliver(),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

/// Extracted categories section — only rebuilds when categories change
class _CategoriesSection extends ConsumerWidget {
  const _CategoriesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(appCategoriesProvider);

    return Padding(
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
              const SizedBox(height: 14),
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
                    final style = CategoryStyle.forAppCategory(cat.icon, Theme.of(context).brightness);
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
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: rest.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final cat = rest[i];
                      final style = CategoryStyle.forAppCategory(cat.icon, Theme.of(context).brightness);
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
        loading: () => const HomeCategoriesSkeleton(),
        error: (_, _) => const SizedBox(),
      ),
    );
  }
}

/// Extracted brand logos — only rebuilds when sections change
class _BrandLogosSection extends ConsumerWidget {
  const _BrandLogosSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(homeSectionsProvider);

    return sections.when(
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
    );
  }
}

/// Extracted product sections sliver — only rebuilds when sections change
class _ProductSectionsSliver extends ConsumerWidget {
  const _ProductSectionsSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(homeSectionsProvider);

    return sections.when(
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
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, _) => const ProductCarouselSkeleton(),
          childCount: 3,
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
    );
  }
}

/// Header widget showing branch selector with dropdown bottom sheet
class _BranchSelectorHeader extends ConsumerWidget {
  const _BranchSelectorHeader();

  void _showBranchPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (sheetCtx, scrollController) => Consumer(
          builder: (consumerCtx, sheetRef, _) {
            final branchesAsync = sheetRef.watch(branchesProvider);
            final selectedId = sheetRef.watch(selectedBranchProvider).valueOrNull?.id;

            return Column(
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetCtx).colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Selecciona sucursal',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(sheetCtx).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          context.push('/branches');
                        },
                        child: Text(
                          'Ver mapa',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Branch list
                Expanded(
                  child: branchesAsync.when(
                    data: (branches) => ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: branches.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 60),
                      itemBuilder: (_, i) {
                        final b = branches[i] as Map<String, dynamic>;
                        final id = b['id'] as int;
                        final name = b['name'] as String? ?? 'Sucursal';
                        final city = b['city'] as String?;
                        final isActive = selectedId == id;

                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.store_rounded,
                              color: isActive ? AppColors.primary : AppColors.textLight,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              color: Theme.of(sheetCtx).colorScheme.onSurface,
                            ),
                          ),
                          subtitle: city != null && city.isNotEmpty
                              ? Text(
                                  city.replaceAll('.', ''),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                )
                              : null,
                          trailing: isActive
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                              : null,
                          onTap: () {
                            sheetRef.read(selectedBranchProvider.notifier).selectBranch(id, name);
                            Navigator.pop(sheetCtx);
                          },
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: Text('Error al cargar sucursales',
                          style: Theme.of(sheetCtx).textTheme.bodyMedium),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchName = ref.watch(selectedBranchProvider.select(
      (asyncBranch) => asyncBranch.valueOrNull?.name,
    ));

    return GestureDetector(
      onTap: () => _showBranchPicker(context, ref),
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/Black_Dog_Logo_V.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Entregar en',
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
                          branchName ?? 'Selecciona sucursal',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
