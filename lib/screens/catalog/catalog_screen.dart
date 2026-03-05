import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_grid.dart';
import '../../widgets/cart_badge.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton_loaders.dart';

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

  CatalogParams get _params => CatalogParams(
    appCategoryId: _selectedAppCategoryId,
    brand: _selectedBrand,
    sort: _sort,
  );

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(catalogProvider(_params).notifier).loadMore();
    }
  }

  void _changeFilter({int? appCategoryId, String? brand, String? sort}) {
    setState(() {
      if (sort != null) _sort = sort;
      if (appCategoryId != null || brand != null) {
        _selectedAppCategoryId = appCategoryId;
        _selectedBrand = brand;
      }
    });
    // Scroll to top on filter change
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(catalogProvider(_params));
    final appCategories = ref.watch(appCategoriesProvider);
    final brands = ref.watch(brandsProvider(_selectedAppCategoryId));

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset('assets/icons/Black_Dog_Logo_V.png'),
        ),
        title: const Text('Catálogo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          const CartBadge(),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => _changeFilter(sort: v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'name', child: Text('Nombre A-Z')),
              const PopupMenuItem(value: 'price_asc', child: Text('Precio menor')),
              const PopupMenuItem(value: 'price_desc', child: Text('Precio mayor')),
              const PopupMenuItem(value: 'newest', child: Text('Más recientes')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // App category filter chips
          appCategories.when(
            data: (cats) => SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: cats.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return CategoryChip(
                      label: 'Todos',
                      isSelected: _selectedAppCategoryId == null,
                      onTap: () => _changeFilter(appCategoryId: null, brand: null),
                    );
                  }
                  final cat = cats[i - 1];
                  return CategoryChip(
                    label: cat.shortName,
                    isSelected: _selectedAppCategoryId == cat.id,
                    onTap: () => _changeFilter(appCategoryId: cat.id, brand: null),
                  );
                },
              ),
            ),
            loading: () => const CategoryChipsSkeleton(),
            error: (_, _) => const SizedBox(height: 52),
          ),

          // Brand filter chips
          if (_selectedAppCategoryId != null)
            brands.when(
              data: (brandList) {
                if (brandList.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    scrollDirection: Axis.horizontal,
                    itemCount: brandList.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return CategoryChip(
                          label: 'Todas las marcas',
                          isSelected: _selectedBrand == null,
                          onTap: () => _changeFilter(
                            appCategoryId: _selectedAppCategoryId,
                            brand: null,
                          ),
                        );
                      }
                      final brand = brandList[i - 1];
                      return CategoryChip(
                        label: brand,
                        isSelected: _selectedBrand == brand,
                        onTap: () => _changeFilter(
                          appCategoryId: _selectedAppCategoryId,
                          brand: brand,
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox(height: 44),
              error: (_, _) => const SizedBox.shrink(),
            ),

          // Product grid
          Expanded(
            child: catalogState.when(
              data: (catalog) {
                if (catalog.products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text('No se encontraron productos',
                            style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  );
                }

                final itemCount = catalog.products.length + (catalog.hasMore ? 1 : 0);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(catalogProvider(_params));
                  },
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: responsiveProductGrid(),
                    itemCount: itemCount,
                    itemBuilder: (_, i) {
                      if (i >= catalog.products.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final product = catalog.products[i];
                      return FadeInUp(
                        delay: (i % 6) * 60,
                        duration: const Duration(milliseconds: 400),
                        offset: 20,
                        child: ProductCard(
                          product: product,
                          onTap: () => context.push('/product/${product.id}'),
                          onAddToCart: () => _addToCart(product),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const ProductGridSkeleton(),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text('Error: $err'),
                    TextButton(
                      onPressed: () => ref.invalidate(catalogProvider(_params)),
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

  Future<void> _addToCart(Product product) async {
    try {
      await ref.read(cartProvider.notifier).addItem(product.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al agregar')),
        );
      }
    }
  }
}
