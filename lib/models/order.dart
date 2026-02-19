class Order {
  final String id;
  final String? odooOrderName;
  final String status;
  final String deliveryType;
  final int? branchId;
  final String? addressId;
  final String paymentMethod;
  final String? paymentStatus;
  final String? paymentLink;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final List<OrderItem> items;
  final List<OrderTracking> tracking;
  final OrderBranch? branch;
  // Payment-related fields from create response
  final String? paymentUrl;
  final Map<String, dynamic>? yappyInstructions;

  Order({
    required this.id,
    this.odooOrderName,
    required this.status,
    required this.deliveryType,
    this.branchId,
    this.addressId,
    required this.paymentMethod,
    this.paymentStatus,
    this.paymentLink,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.tracking = const [],
    this.branch,
    this.paymentUrl,
    this.yappyInstructions,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // The create response nests order data inside 'order' key
    final orderData = json.containsKey('order')
        ? json['order'] as Map<String, dynamic>
        : json;

    return Order(
      id: orderData['id'] as String,
      odooOrderName: json['odoo_order_name'] as String? ?? orderData['odoo_order_name'] as String?,
      status: orderData['status'] as String? ?? 'pending_payment',
      deliveryType: orderData['delivery_type'] as String? ?? 'pickup',
      branchId: orderData['branch_id'] as int?,
      addressId: orderData['address_id'] as String?,
      paymentMethod: orderData['payment_method'] as String? ?? 'in_store',
      paymentStatus: orderData['payment_status'] as String?,
      paymentLink: orderData['payment_link'] as String?,
      subtotal: (orderData['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (orderData['delivery_fee'] as num?)?.toDouble() ?? 0,
      total: (orderData['total'] as num?)?.toDouble() ?? 0,
      notes: orderData['notes'] as String?,
      createdAt: orderData['created_at'] as String?,
      updatedAt: orderData['updated_at'] as String?,
      items: (json['items'] as List? ?? orderData['items'] as List? ?? [])
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      tracking: (json['tracking'] as List? ?? orderData['tracking'] as List? ?? [])
          .map((t) => OrderTracking.fromJson(t as Map<String, dynamic>))
          .toList(),
      branch: json['branch'] != null
          ? OrderBranch.fromJson(json['branch'] as Map<String, dynamic>)
          : (orderData['branch'] != null
              ? OrderBranch.fromJson(orderData['branch'] as Map<String, dynamic>)
              : null),
      paymentUrl: json['payment_url'] as String?,
      yappyInstructions: json['yappy'] as Map<String, dynamic>?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending_payment': return 'Pendiente de pago';
      case 'confirmed': return 'Confirmado';
      case 'preparing': return 'Preparando';
      case 'ready_pickup': return 'Listo para recoger';
      case 'shipping': return 'En camino';
      case 'delivered': return 'Entregado';
      case 'cancelled': return 'Cancelado';
      default: return status;
    }
  }

  bool get canCancel =>
      status == 'pending_payment' || status == 'confirmed';
}

class OrderItem {
  final String? id;
  final String orderId;
  final int productId;
  final String? productName;
  final int quantity;
  final double unitPrice;
  final double total;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String?,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as int,
      productName: json['product_name'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OrderTracking {
  final String? id;
  final String orderId;
  final String status;
  final String? message;
  final String? driverName;
  final String? driverPhone;
  final String? createdAt;

  OrderTracking({
    this.id,
    required this.orderId,
    required this.status,
    this.message,
    this.driverName,
    this.driverPhone,
    this.createdAt,
  });

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    return OrderTracking(
      id: json['id'] as String?,
      orderId: json['order_id'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class OrderBranch {
  final int id;
  final String name;
  final String? code;
  final String? address;
  final String? phone;

  OrderBranch({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.phone,
  });

  factory OrderBranch.fromJson(Map<String, dynamic> json) {
    return OrderBranch(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
    );
  }
}
