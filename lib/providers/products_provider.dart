import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../models/category.dart';
import 'service_providers.dart';

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

final productListProvider = FutureProvider.family<ProductListResult, ProductListParams>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getProducts(
    page: params.page,
    categoryId: params.categoryId,
    appCategoryId: params.appCategoryId,
    brand: params.brand,
    sort: params.sort,
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
final productDetailProvider = FutureProvider.family<ProductDetail, int>((ref, productId) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getProduct(productId);
  return ProductDetail.fromJson(result);
});

/// Product search
final productSearchProvider = FutureProvider.family<ProductListResult, String>((ref, query) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.searchProducts(query);

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
final brandsProvider = FutureProvider.family<List<String>, int?>((ref, appCategoryId) async {
  final api = ref.read(apiServiceProvider);
  return api.getBrands(appCategoryId: appCategoryId);
});
