import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/catalog_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_grid.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton_loaders.dart';

/// Debounced search query provider
final _searchQueryProvider = StateProvider<String>((ref) => '');

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(_searchQueryProvider.notifier).state = query.trim();
    });
  }

  void _onScroll() {
    final query = ref.read(_searchQueryProvider);
    if (query.length < 2) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(searchProvider(query).notifier).loadMore();
    }
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
          : ref.watch(searchProvider(query)).when(
              data: (searchState) {
                if (searchState.products.isEmpty) {
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

                final itemCount = searchState.products.length +
                    (searchState.hasMore ? 1 : 0);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text('${searchState.total} resultados',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Expanded(
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: responsiveProductGrid(),
                        itemCount: itemCount,
                        itemBuilder: (_, i) {
                          if (i >= searchState.products.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return ProductCard(
                            product: searchState.products[i],
                            onTap: () => context.push(
                              '/product/${searchState.products[i].id}',
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const ProductGridSkeleton(itemCount: 4),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
    );
  }
}
