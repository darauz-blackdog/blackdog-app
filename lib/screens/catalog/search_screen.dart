import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_grid.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/product_card.dart';

/// Debounced search query provider
final _searchQueryProvider = StateProvider<String>((ref) => '');

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      ref.read(_searchQueryProvider.notifier).state = query.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Buscar productos...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                ref.read(_searchQueryProvider.notifier).state = '';
              },
            ),
        ],
      ),
      body: query.length < 2
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: AppColors.textLight),
                  const SizedBox(height: 16),
                  Text('Busca por nombre de producto',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          : ref.watch(productSearchProvider(query)).when(
              data: (result) {
                if (result.products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text('No se encontraron resultados para "$query"',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(Responsive.paddingSmall(context), 8, Responsive.paddingSmall(context), 8),
                      child: Text('${result.total} resultados',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.paddingSmall(context)),
                        gridDelegate: responsiveProductGrid(),
                        itemCount: result.products.length,
                        itemBuilder: (_, i) {
                          final product = result.products[i];
                          return ProductCard(
                            product: product,
                            isFavorite: ref.watch(favoritesProvider.select((f) => f.contains(product.id))),
                            onFavorite: () => ref.read(favoritesProvider.notifier).toggle(product.id),
                            onTap: () => context.push('/product/${product.id}'),
                            onAddToCart: () async {
                              try {
                                await ref.read(cartProvider.notifier).addItem(product.id);
                              } catch (e) {
                                if (context.mounted) {
                                  showAppSnackBar(const SnackBar(
                                    content: Text('Error al agregar'),
                                    duration: Duration(seconds: 3),
                                  ));
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
    );
  }
}
