class Product {
  final int id;
  final String name;
  final double listPrice;
  final double? salePrice;
  final int? categoryId;
  final String? categoryName;
  final String? productType;
  final String? defaultCode;
  final String? description;
  final String? imageUrl;
  final bool isPublished;

  Product({
    required this.id,
    required this.name,
    required this.listPrice,
    this.salePrice,
    this.categoryId,
    this.categoryName,
    this.productType,
    this.defaultCode,
    this.description,
    this.imageUrl,
    this.isPublished = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      listPrice: (json['list_price'] as num).toDouble(),
      salePrice: json['sale_price'] != null ? (json['sale_price'] as num).toDouble() : null,
      categoryId: json['category_id'] as int?,
      categoryName: json['category_name'] as String?,
      productType: json['product_type'] as String?,
      defaultCode: json['default_code'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      isPublished: json['is_published'] as bool? ?? true,
    );
  }

  double get effectivePrice => salePrice ?? listPrice;
  bool get hasDiscount => salePrice != null && salePrice! < listPrice;
  double get discountPercent =>
      hasDiscount ? ((listPrice - salePrice!) / listPrice * 100) : 0;
}

class ProductDetail extends Product {
  final List<StockByBranch> stockByBranch;
  final double totalStock;

  ProductDetail({
    required super.id,
    required super.name,
    required super.listPrice,
    super.salePrice,
    super.categoryId,
    super.categoryName,
    super.productType,
    super.defaultCode,
    super.description,
    super.imageUrl,
    super.isPublished,
    required this.stockByBranch,
    required this.totalStock,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    return ProductDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      listPrice: (json['list_price'] as num).toDouble(),
      salePrice: json['sale_price'] != null ? (json['sale_price'] as num).toDouble() : null,
      categoryId: json['category_id'] as int?,
      categoryName: json['category_name'] as String?,
      productType: json['product_type'] as String?,
      defaultCode: json['default_code'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      isPublished: json['is_published'] as bool? ?? true,
      stockByBranch: (json['stock_by_branch'] as List? ?? [])
          .map((s) => StockByBranch.fromJson(s as Map<String, dynamic>))
          .toList(),
      totalStock: (json['total_stock'] as num?)?.toDouble() ?? 0,
    );
  }

  bool get inStock => totalStock > 0;
}

class StockByBranch {
  final double qtyAvailable;
  final BranchInfo? branch;

  StockByBranch({required this.qtyAvailable, this.branch});

  factory StockByBranch.fromJson(Map<String, dynamic> json) {
    return StockByBranch(
      qtyAvailable: (json['qty_available'] as num).toDouble(),
      branch: json['branch'] != null
          ? BranchInfo.fromJson(json['branch'] as Map<String, dynamic>)
          : null,
    );
  }
}

class BranchInfo {
  final int id;
  final String name;
  final String? code;
  final String? city;
  final bool isPickupEnabled;

  BranchInfo({
    required this.id,
    required this.name,
    this.code,
    this.city,
    this.isPickupEnabled = true,
  });

  factory BranchInfo.fromJson(Map<String, dynamic> json) {
    return BranchInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String?,
      city: json['city'] as String?,
      isPickupEnabled: json['is_pickup_enabled'] as bool? ?? true,
    );
  }
}
