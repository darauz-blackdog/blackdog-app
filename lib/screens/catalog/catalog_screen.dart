import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_grid.dart';
import '../../widgets/product_card.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/cart_badge.dart';

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
    final brands = ref.watch(brandsProvider(_selectedAppCategoryId));

    return Scaffold(
      appBar: AppBar(
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
            onSelected: (v) {
              setState(() => _sort = v);
              _resetAndReload();
            },
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
          SizedBox(
            height: 52,
            child: appCategories.when(
              data: (cats) => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: cats.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return CategoryChip(
                      label: 'Todos',
                      isSelected: _selectedAppCategoryId == null,
                      onTap: () {
                        setState(() {
                          _selectedAppCategoryId = null;
                          _selectedBrand = null;
                        });
                        _resetAndReload();
                      },
                    );
                  }
                  final cat = cats[i - 1];
                  return CategoryChip(
                    label: cat.name,
                    isSelected: _selectedAppCategoryId == cat.id,
                    onTap: () {
                      setState(() {
                        _selectedAppCategoryId = cat.id;
                        _selectedBrand = null;
                      });
                      _resetAndReload();
                    },
                  );
                },
              ),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
          ),

          // Brand filter chips (only when a category is selected)
          if (_selectedAppCategoryId != null)
            SizedBox(
              height: 44,
              child: brands.when(
                data: (brandList) {
                  if (brandList.isEmpty) return const SizedBox();
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    scrollDirection: Axis.horizontal,
                    itemCount: brandList.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return CategoryChip(
                          label: 'Todas las marcas',
                          isSelected: _selectedBrand == null,
                          onTap: () {
                            setState(() => _selectedBrand = null);
                            _resetAndReload();
                          },
                        );
                      }
                      final brand = brandList[i - 1];
                      return CategoryChip(
                        label: brand,
                        isSelected: _selectedBrand == brand,
                        onTap: () {
                          setState(() => _selectedBrand = brand);
                          _resetAndReload();
                        },
                      );
                    },
                  );
                },
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),
            ),

          // Product grid with infinite scroll
          Expanded(
            child: firstPage.when(
              data: (result) {
                // Merge first page + loaded pages
                final products = [...result.products, ..._allProducts];

                if (_hasMore && _currentPage == 1) {
                  // Initialize hasMore from first page result
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _currentPage == 1) {
                      setState(() {
                        _hasMore = result.totalPages > 1;
                      });
                    }
                  });
                }

                if (products.isEmpty) {
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

                final itemCount = products.length + (_hasMore ? 1 : 0);

                return GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: responsiveProductGrid(),
                  itemCount: itemCount,
                  itemBuilder: (_, i) {
                    if (i >= products.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final product = products[i];
                    return ProductCard(
                      product: product,
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
                              const SnackBar(content: Text('Error al agregar')),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
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
