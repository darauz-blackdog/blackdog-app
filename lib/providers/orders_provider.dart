import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import 'service_providers.dart';

/// Order list with optional status filter
class OrderListParams {
  final int page;
  final String? status;

  const OrderListParams({this.page = 1, this.status});

  @override
  bool operator ==(Object other) =>
      other is OrderListParams &&
      other.page == page &&
      other.status == status;

  @override
  int get hashCode => Object.hash(page, status);
}

final orderListProvider = FutureProvider.family<OrderListResult, OrderListParams>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getOrders(page: params.page, status: params.status);

  final orders = (result['data'] as List)
      .map((o) => Order.fromJson(o as Map<String, dynamic>))
      .toList();

  final pagination = result['pagination'] as Map<String, dynamic>;

  return OrderListResult(
    orders: orders,
    total: pagination['total'] as int,
    totalPages: pagination['total_pages'] as int,
    page: pagination['page'] as int,
  );
});

class OrderListResult {
  final List<Order> orders;
  final int total;
  final int totalPages;
  final int page;

  OrderListResult({
    required this.orders,
    required this.total,
    required this.totalPages,
    required this.page,
  });
}

/// Single order detail
final orderDetailProvider = FutureProvider.family<Order, String>((ref, orderId) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getOrder(orderId);
  return Order.fromJson(result);
});
