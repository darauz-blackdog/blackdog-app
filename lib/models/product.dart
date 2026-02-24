class HomeSection {
  final String id;
  final String title;
  final String type; // "brand" or "category"
  final Map<String, dynamic> filter;
  final List<Product> products;

  HomeSection({
    required this.id,
    required this.title,
    required this.type,
    required this.filter,
    required this.products,
  });

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    return HomeSection(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      filter: Map<String, dynamic>.from(json['filter'] as Map),
      products: (json['products'] as List)
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Product {
  final int id;
  final String name;
  final double listPrice;
  final double? salePrice;
  final int? categoryId;
  final String? categoryName;
  final int? appCategoryId;
  final String? brand;
  final String? productType;
  final String? defaultCode;
  final String? description;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? descriptionHtml;
  final List<String> tags;
  final String? handle;
  final bool isPublished;
  final double totalStock;
  final String? variantGroup;
  final String? variantLabel;

  Product({
    required this.id,
    required this.name,
    required this.listPrice,
    this.salePrice,
    this.categoryId,
    this.categoryName,
    this.appCategoryId,
    this.brand,
    this.productType,
    this.defaultCode,
    this.description,
    this.imageUrl,
    this.imageUrls = const [],
    this.descriptionHtml,
    this.tags = const [],
    this.handle,
    this.isPublished = true,
    this.totalStock = 0,
    this.variantGroup,
    this.variantLabel,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final urls = (json['image_urls'] as List?)?.cast<String>() ?? [];
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      listPrice: (json['list_price'] as num).toDouble(),
      salePrice: json['sale_price'] != null
          ? (json['sale_price'] as num).toDouble()
          : null,
      categoryId: json['category_id'] as int?,
      categoryName: json['category_name'] as String?,
      appCategoryId: json['app_category_id'] as int?,
      brand: json['brand'] as String?,
      productType: json['product_type'] as String?,
      defaultCode: json['default_code'] as String?,
      description: json['description'] as String?,
      imageUrl:
          json['image_url'] as String? ?? (urls.isNotEmpty ? urls.first : null),
      imageUrls: urls,
      descriptionHtml: json['description_html'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      handle: json['handle'] as String?,
      isPublished: json['is_published'] as bool? ?? true,
      totalStock: (json['total_stock'] as num?)?.toDouble() ?? 0,
      variantGroup: json['variant_group'] as String?,
      variantLabel: json['variant_label'] as String?,
    );
  }

  double get effectivePrice => salePrice ?? listPrice;
  bool get hasDiscount => salePrice != null && salePrice! < listPrice;
  bool get inStock => totalStock > 0;

  double get discountPercent =>
      hasDiscount ? ((listPrice - salePrice!) / listPrice * 100) : 0;

  /// Strip HTML tags from descriptionHtml for plain text display
  String? get descriptionPlain {
    if (descriptionHtml == null) return description;
    return descriptionHtml!
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</p>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;'), "'")
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

class ProductDetail extends Product {
  final List<StockByBranch> stockByBranch;
  final List<ProductVariant> variants;

  ProductDetail({
    required super.id,
    required super.name,
    required super.listPrice,
    super.salePrice,
    super.categoryId,
    super.categoryName,
    super.appCategoryId,
    super.brand,
    super.productType,
    super.defaultCode,
    super.description,
    super.imageUrl,
    super.imageUrls,
    super.descriptionHtml,
    super.tags,
    super.handle,
    super.isPublished,
    super.variantGroup,
    super.variantLabel,
    required this.stockByBranch,
    required super.totalStock,
    this.variants = const [],
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final urls = (json['image_urls'] as List?)?.cast<String>() ?? [];
    return ProductDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      listPrice: (json['list_price'] as num).toDouble(),
      salePrice: json['sale_price'] != null
          ? (json['sale_price'] as num).toDouble()
          : null,
      categoryId: json['category_id'] as int?,
      categoryName: json['category_name'] as String?,
      appCategoryId: json['app_category_id'] as int?,
      brand: json['brand'] as String?,
      productType: json['product_type'] as String?,
      defaultCode: json['default_code'] as String?,
      description: json['description'] as String?,
      imageUrl:
          json['image_url'] as String? ?? (urls.isNotEmpty ? urls.first : null),
      imageUrls: urls,
      descriptionHtml: json['description_html'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      handle: json['handle'] as String?,
      isPublished: json['is_published'] as bool? ?? true,
      variantGroup: json['variant_group'] as String?,
      variantLabel: json['variant_label'] as String?,
      stockByBranch: (json['stock_by_branch'] as List? ?? [])
          .map((s) => StockByBranch.fromJson(s as Map<String, dynamic>))
          .toList(),
      totalStock: (json['total_stock'] as num?)?.toDouble() ?? 0,
      variants: (json['variants'] as List? ?? [])
          .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProductVariant {
  final int id;
  final String? variantLabel;
  final double listPrice;
  final double? salePrice;
  final double totalStock;
  final String? imageUrl;

  ProductVariant({
    required this.id,
    this.variantLabel,
    required this.listPrice,
    this.salePrice,
    this.totalStock = 0,
    this.imageUrl,
  });

  bool get inStock => totalStock > 0;
  double get effectivePrice => salePrice ?? listPrice;

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as int,
      variantLabel: json['variant_label'] as String?,
      listPrice: (json['list_price'] as num).toDouble(),
      salePrice: json['sale_price'] != null
          ? (json['sale_price'] as num).toDouble()
          : null,
      totalStock: (json['total_stock'] as num?)?.toDouble() ?? 0,
      imageUrl: json['image_url'] as String?,
    );
  }
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
