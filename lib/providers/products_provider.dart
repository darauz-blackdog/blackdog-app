import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../models/category.dart';
import 'service_providers.dart';

/// Brands that should appear first in all listings
const _priorityBrands = ['Natural Greatness'];

bool _isPriorityBrand(String name) =>
    _priorityBrands.any((p) => name.toLowerCase().contains(p.toLowerCase()));

/// Paginated product list with optional category/brand filter
class ProductListParams {
  final int? categoryId;
  final int? appCategoryId;
  final String? brand;
  final String sort;
  final int page;

  const ProductListParams({
    this.categoryId,
    this.appCategoryId,
    this.brand,
    this.sort = 'name',
    this.page = 1,
  });

  @override
  bool operator ==(Object other) =>
      other is ProductListParams &&
      other.categoryId == categoryId &&
      other.appCategoryId == appCategoryId &&
      other.brand == brand &&
      other.sort == sort &&
      other.page == page;

  @override
  int get hashCode => Object.hash(categoryId, appCategoryId, brand, sort, page);
}

final productListProvider = FutureProvider.family.autoDispose<ProductListResult, ProductListParams>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final result = await api.getProducts(
    page: params.page,
    categoryId: params.categoryId,
    appCategoryId: params.appCategoryId,
    brand: params.brand,
    sort: params.sort,
    cancelToken: cancelToken,
  );

  final products = (result['data'] as List)
      .map((p) => Product.fromJson(p as Map<String, dynamic>))
      .toList();

  final pagination = result['pagination'] as Map<String, dynamic>;

  return ProductListResult(
    products: products,
    total: pagination['total'] as int,
    totalPages: pagination['total_pages'] as int,
    page: pagination['page'] as int,
  );
});

class ProductListResult {
  final List<Product> products;
  final int total;
  final int totalPages;
  final int page;

  ProductListResult({
    required this.products,
    required this.total,
    required this.totalPages,
    required this.page,
  });
}

/// Single product detail
final productDetailProvider = FutureProvider.autoDispose.family<ProductDetail, int>((ref, productId) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getProduct(productId);
  return ProductDetail.fromJson(result);
});

/// Product search with automatic cancellation of previous requests
final productSearchProvider = FutureProvider.family.autoDispose<ProductListResult, String>((ref, query) async {
  final api = ref.read(apiServiceProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final result = await api.searchProducts(query, cancelToken: cancelToken);

  final products = (result['data'] as List)
      .map((p) => Product.fromJson(p as Map<String, dynamic>))
      .toList();

  final pagination = result['pagination'] as Map<String, dynamic>;

  return ProductListResult(
    products: products,
    total: pagination['total'] as int,
    totalPages: pagination['total_pages'] as int,
    page: pagination['page'] as int,
  );
});

/// Promotional banners always shown in the carousel
const _promotionalBanners = [
  HomeBanner(
    id: -1,
    title: 'Natural Greatness',
    subtitle: 'Alimentaci\u00f3n natural premium para tu mascota',
    linkType: 'brand',
    linkValue: 'Natural Greatness',
    gradientStart: '#1B5E20',
    gradientEnd: '#4CAF50',
  ),
  HomeBanner(
    id: -2,
    title: 'Delivery con ASAP',
    subtitle: 'Recibe tus pedidos r\u00e1pido y seguro',
    linkType: 'none',
    gradientStart: '#1A1A2E',
    gradientEnd: '#F7B104',
  ),
];

/// Home banners
final homeBannersProvider = FutureProvider<List<HomeBanner>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getHomeBanners();
  final apiBanners = result.map((b) => HomeBanner.fromJson(b as Map<String, dynamic>)).toList();
  return [..._promotionalBanners, ...apiBanners];
});

/// Home screen sections (brands + categories with products)
/// Natural Greatness brand sections are moved to the front.
final homeSectionsProvider = FutureProvider<List<HomeSection>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getHomeSections();
  final sections = result.map((s) => HomeSection.fromJson(s as Map<String, dynamic>)).toList();
  // Move priority brands to the front, preserve original order otherwise
  sections.sort((a, b) {
    final aP = a.type == 'brand' && _isPriorityBrand(a.filter['brand'] as String? ?? '');
    final bP = b.type == 'brand' && _isPriorityBrand(b.filter['brand'] as String? ?? '');
    if (aP && !bP) return -1;
    if (!aP && bP) return 1;
    return 0;
  });
  return sections;
});

/// Featured products
final featuredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getFeaturedProducts();
  return result.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
});

/// Category tree — extracts direct children of the root category (e.g. "Vendibles")
const _hiddenCategories = {'humano', 'servicios'};

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getCategories();
  final roots = result.map((c) => Category.fromJson(c as Map<String, dynamic>)).toList();
  // The API returns a single root ("Vendibles") — show its children
  List<Category> categories = roots;
  if (roots.length == 1 && roots.first.children.isNotEmpty) {
    categories = roots.first.children;
  }
  return categories.where((c) => !_hiddenCategories.contains(c.name.toLowerCase())).toList();
});

/// Simplified app categories (14 categories)
final appCategoriesProvider = FutureProvider<List<AppCategory>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getAppCategories();
  return result.map((c) => AppCategory.fromJson(c as Map<String, dynamic>)).toList();
});

/// Brands for a specific app category
/// Natural Greatness always appears first in the list.
final brandsProvider = FutureProvider.family.autoDispose<List<String>, int?>((ref, appCategoryId) async {
  final api = ref.read(apiServiceProvider);
  final brands = await api.getBrands(appCategoryId: appCategoryId);
  brands.sort((a, b) {
    final aP = _isPriorityBrand(a);
    final bP = _isPriorityBrand(b);
    if (aP && !bP) return -1;
    if (!aP && bP) return 1;
    return a.compareTo(b);
  });
  return brands;
});
