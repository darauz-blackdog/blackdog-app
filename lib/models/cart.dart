class CartItem {
  final String id;
  final String cartId;
  final int productId;
  final String? productName;
  final double? productPrice;
  final String? imageUrl;
  final int quantity;

  CartItem({
    required this.id,
    required this.cartId,
    required this.productId,
    this.productName,
    this.productPrice,
    this.imageUrl,
    required this.quantity,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      cartId: json['cart_id'] as String,
      productId: json['product_id'] as int,
      productName: json['product_name'] as String?,
      productPrice: json['product_price'] != null
          ? (json['product_price'] as num).toDouble()
          : null,
      imageUrl: json['image_url'] as String?,
      quantity: json['quantity'] as int? ?? 1,
    );
  }

  double get lineTotal => (productPrice ?? 0) * quantity;
}

class Cart {
  final String id;
  final String status;
  final List<CartItem> items;
  final double subtotal;

  Cart({
    required this.id,
    required this.status,
    required this.items,
    required this.subtotal,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List? ?? [])
        .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return Cart(
      id: json['cart']?['id'] as String? ?? json['id'] as String? ?? '',
      status: json['cart']?['status'] as String? ?? json['status'] as String? ?? 'active',
      items: itemsList,
      subtotal: json['subtotal'] != null
          ? (json['subtotal'] as num).toDouble()
          : itemsList.fold(0.0, (sum, item) => sum + item.lineTotal),
    );
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;
}
