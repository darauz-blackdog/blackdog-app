import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import 'service_providers.dart';

/// Immutable state for the catalog with accumulated products
class CatalogState {
  final List<Product> products;
  final int currentPage;
  final int totalPages;
  final int total;
  final bool isLoadingMore;
  final bool hasMore;

  const CatalogState({
    this.products = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.total = 0,
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  CatalogState copyWith({
    List<Product>? products,
    int? currentPage,
    int? totalPages,
    int? total,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return CatalogState(
      products: products ?? this.products,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Params that define a catalog filter (without page)
class CatalogParams {
  final int? appCategoryId;
  final String? brand;
  final String sort;

  const CatalogParams({
    this.appCategoryId,
    this.brand,
    this.sort = 'name',
  });

  @override
  bool operator ==(Object other) =>
      other is CatalogParams &&
      other.appCategoryId == appCategoryId &&
      other.brand == brand &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(appCategoryId, brand, sort);
}

/// AsyncNotifier that manages paginated catalog with accumulated products
class CatalogNotifier extends FamilyAsyncNotifier<CatalogState, CatalogParams> {
  @override
  Future<CatalogState> build(CatalogParams arg) async {
    return _fetchPage(1);
  }

  Future<CatalogState> _fetchPage(int page) async {
    final api = ref.read(apiServiceProvider);
    final result = await api.getProducts(
      page: page,
      appCategoryId: arg.appCategoryId,
      brand: arg.brand,
      sort: arg.sort,
    );

    final products = (result['data'] as List)
        .map((p) => Product.fromJson(p as Map<String, dynamic>))
        .toList();
    final pagination = result['pagination'] as Map<String, dynamic>;
    final totalPages = pagination['total_pages'] as int;

    return CatalogState(
      products: products,
      currentPage: page,
      totalPages: totalPages,
      total: pagination['total'] as int,
      hasMore: page < totalPages,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    // Set loading flag
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final nextPage = current.currentPage + 1;
      final api = ref.read(apiServiceProvider);
      final result = await api.getProducts(
        page: nextPage,
        appCategoryId: arg.appCategoryId,
        brand: arg.brand,
        sort: arg.sort,
      );

      final newProducts = (result['data'] as List)
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList();
      final pagination = result['pagination'] as Map<String, dynamic>;
      final totalPages = pagination['total_pages'] as int;

      state = AsyncValue.data(CatalogState(
        products: [...current.products, ...newProducts],
        currentPage: nextPage,
        totalPages: totalPages,
        total: pagination['total'] as int,
        isLoadingMore: false,
        hasMore: nextPage < totalPages,
      ));
    } catch (_) {
      // Keep current products visible, just stop loading indicator
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final catalogProvider = AsyncNotifierProvider.family<CatalogNotifier, CatalogState, CatalogParams>(
  CatalogNotifier.new,
);

/// Search state with pagination
class SearchState {
  final List<Product> products;
  final int currentPage;
  final int totalPages;
  final int total;
  final bool isLoadingMore;
  final bool hasMore;

  const SearchState({
    this.products = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.total = 0,
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  SearchState copyWith({
    List<Product>? products,
    int? currentPage,
    int? totalPages,
    int? total,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return SearchState(
      products: products ?? this.products,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Search notifier with pagination support
class SearchNotifier extends FamilyAsyncNotifier<SearchState, String> {
  @override
  Future<SearchState> build(String arg) async {
    if (arg.length < 2) return const SearchState();
    return _fetchPage(1);
  }

  Future<SearchState> _fetchPage(int page) async {
    final api = ref.read(apiServiceProvider);
    final result = await api.searchProducts(arg, page: page, limit: 20);

    final products = (result['data'] as List)
        .map((p) => Product.fromJson(p as Map<String, dynamic>))
        .toList();
    final pagination = result['pagination'] as Map<String, dynamic>;
    final totalPages = pagination['total_pages'] as int;

    return SearchState(
      products: products,
      currentPage: page,
      totalPages: totalPages,
      total: pagination['total'] as int,
      hasMore: page < totalPages,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final nextPage = current.currentPage + 1;
      final api = ref.read(apiServiceProvider);
      final result = await api.searchProducts(arg, page: nextPage, limit: 20);

      final newProducts = (result['data'] as List)
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList();
      final pagination = result['pagination'] as Map<String, dynamic>;
      final totalPages = pagination['total_pages'] as int;

      state = AsyncValue.data(SearchState(
        products: [...current.products, ...newProducts],
        currentPage: nextPage,
        totalPages: totalPages,
        total: pagination['total'] as int,
        isLoadingMore: false,
        hasMore: nextPage < totalPages,
      ));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final searchProvider = AsyncNotifierProvider.family<SearchNotifier, SearchState, String>(
  SearchNotifier.new,
);
