import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_grid.dart';
import '../../widgets/cart_badge.dart';
import '../../widgets/category_icon_box.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/product_card.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  final int? categoryId;
  final int? appCategoryId;
  final String? brand;
  const CatalogScreen({super.key, this.categoryId, this.appCategoryId, this.brand});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  int? _selectedAppCategoryId;
  String? _selectedBrand;
  String _sort = 'name';
  int _currentPage = 1;
  final List<Product> _allProducts = [];
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedAppCategoryId = widget.appCategoryId;
    _selectedBrand = widget.brand;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _resetAndReload() {
    setState(() {
      _currentPage = 1;
      _allProducts.clear();
      _hasMore = true;
      _isLoadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.getProducts(
        page: _currentPage + 1,
        appCategoryId: _selectedAppCategoryId,
        brand: _selectedBrand,
        sort: _sort,
      );

      final products = (result['data'] as List)
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList();
      final pagination = result['pagination'] as Map<String, dynamic>;

      setState(() {
        _allProducts.addAll(products);
        _currentPage++;
        _hasMore = _currentPage < (pagination['total_pages'] as int);
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  ProductListParams get _params => ProductListParams(
    appCategoryId: _selectedAppCategoryId,
    brand: _selectedBrand,
    sort: _sort,
  );

  @override
  Widget build(BuildContext context) {
    final firstPage = ref.watch(productListProvider(_params));
    final appCategories = ref.watch(appCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset('assets/icons/Black_Dog_Logo_V.png'),
        ),
        title: const Text('Catalogo'),
        actions: const [
          CartBadge(),
          SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.grayMedium,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: AppColors.textLight,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Buscar productos...',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Category cards
          SliverToBoxAdapter(
            child: SizedBox(
              height: 120,
              child: appCategories.when(
                data: (cats) => ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final cat = cats[i];
                    final style = CategoryStyle.forAppCategory(cat.icon);
                    final isSelected = _selectedAppCategoryId == cat.id;
                    return _CategoryCard(
                      label: cat.shortName,
                      icon: style.icon,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedAppCategoryId = null;
                          } else {
                            _selectedAppCategoryId = cat.id;
                          }
                          _selectedBrand = null;
                        });
                        _resetAndReload();
                      },
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox(),
              ),
            ),
          ),

          // Brand chips (only when a category is selected)
          if (_selectedAppCategoryId != null)
            SliverToBoxAdapter(
              child: _BrandChipsRow(
                appCategoryId: _selectedAppCategoryId!,
                selectedBrand: _selectedBrand,
                onBrandSelected: (brand) {
                  setState(() {
                    _selectedBrand = _selectedBrand == brand ? null : brand;
                  });
                  _resetAndReload();
                },
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Product grid
          firstPage.when(
            data: (result) {
              final products = [...result.products, ..._allProducts];

              if (_hasMore && _currentPage == 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _currentPage == 1) {
                    setState(() {
                      _hasMore = result.totalPages > 1;
                    });
                  }
                });
              }

              if (products.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text('No se encontraron productos',
                            style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                );
              }

              final itemCount = products.length + (_hasMore ? 1 : 0);

              return SliverPadding(
                padding: EdgeInsets.all(Responsive.paddingSmall(context)),
                sliver: SliverGrid(
                  gridDelegate: responsiveProductGrid(),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (i >= products.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final product = products[i];
                      return FadeInUp(
                        key: ValueKey(product.id),
                        delay: (i % 6) * 60,
                        duration: const Duration(milliseconds: 400),
                        offset: 20,
                        child: ProductCard(
                          product: product,
                          isFavorite: ref.watch(favoritesProvider.select((f) => f.contains(product.id))),
                          onFavorite: () => ref.read(favoritesProvider.notifier).toggle(product.id),
                          onTap: () => context.push('/product/${product.id}'),
                          onAddToCart: () async {
                            try {
                              await ref.read(cartProvider.notifier).addItem(product.id);
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
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Error al agregar'), duration: Duration(seconds: 3)),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                    childCount: itemCount,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text('Error: $err'),
                    TextButton(
                      onPressed: () {
                        _resetAndReload();
                        ref.invalidate(productListProvider(_params));
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandChipsRow extends ConsumerWidget {
  final int appCategoryId;
  final String? selectedBrand;
  final ValueChanged<String> onBrandSelected;

  const _BrandChipsRow({
    required this.appCategoryId,
    required this.selectedBrand,
    required this.onBrandSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(brandsProvider(appCategoryId));

    return brandsAsync.when(
      data: (brands) {
        if (brands.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: brands.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final brand = brands[i];
              final isSelected = selectedBrand == brand;
              return ChoiceChip(
                label: Text(brand),
                selected: isSelected,
                onSelected: (_) => onBrandSelected(brand),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.outline,
                ),
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : Theme.of(context).textTheme.bodyMedium?.color,
                ),
                backgroundColor: Colors.transparent,
                showCheckmark: false,
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCard : AppColors.divider;
    final fgColor = isDark ? AppColors.primary : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 2.5)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(icon, color: fgColor, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
