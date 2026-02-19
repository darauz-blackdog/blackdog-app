import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_card.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/cart_badge.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  final int? categoryId;
  const CatalogScreen({super.key, this.categoryId});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  int? _selectedCategoryId;
  String _sort = 'name';

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categoryId;
  }

  @override
  Widget build(BuildContext context) {
    final params = ProductListParams(
      categoryId: _selectedCategoryId,
      sort: _sort,
    );
    final products = ref.watch(productListProvider(params));
    final categories = ref.watch(categoriesProvider);

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
            onSelected: (v) => setState(() => _sort = v),
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
          // Category filter chips
          SizedBox(
            height: 52,
            child: categories.when(
              data: (cats) => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: cats.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return CategoryChip(
                      label: 'Todos',
                      isSelected: _selectedCategoryId == null,
                      onTap: () => setState(() => _selectedCategoryId = null),
                    );
                  }
                  final cat = cats[i - 1];
                  return CategoryChip(
                    label: cat.name,
                    isSelected: _selectedCategoryId == cat.id,
                    onTap: () => setState(() => _selectedCategoryId = cat.id),
                  );
                },
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ),

          // Product grid
          Expanded(
            child: products.when(
              data: (result) {
                if (result.products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text('No se encontraron productos',
                            style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: result.products.length,
                  itemBuilder: (_, i) => ProductCard(
                    product: result.products[i],
                    onTap: () => context.push('/product/${result.products[i].id}'),
                  ),
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
                      onPressed: () => ref.invalidate(productListProvider(params)),
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
