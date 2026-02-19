import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          Supabase.instance.client.auth.signOut();
        }
        handler.next(error);
      },
    ));
  }

  // Products
  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int limit = 20,
    int? categoryId,
    String sort = 'name',
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sort': sort,
    };
    if (categoryId != null) params['category_id'] = categoryId;

    final response = await _dio.get('/products', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProduct(int id) async {
    final response = await _dio.get('/products/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> searchProducts(String query, {int page = 1, int limit = 20}) async {
    final response = await _dio.get('/products/search', queryParameters: {
      'q': query,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getFeaturedProducts({int limit = 12}) async {
    final response = await _dio.get('/products/featured', queryParameters: {'limit': limit});
    return (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
  }

  // Categories
  Future<List<dynamic>> getCategories({bool flat = false}) async {
    final response = await _dio.get('/categories', queryParameters: {'flat': flat.toString()});
    return (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
  }

  // Branches
  Future<List<dynamic>> getBranches() async {
    final response = await _dio.get('/branches');
    return (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
  }

  // Auth
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'full_name': fullName,
      'phone': phone,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeProfile({String? fullName, String? phone}) async {
    final response = await _dio.post('/auth/complete-profile', data: {
      'full_name': fullName,
      'phone': phone,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/auth/profile');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({String? fullName, String? phone}) async {
    final response = await _dio.put('/auth/profile', data: {
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── Cart ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCart() async {
    final response = await _dio.get('/cart');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addToCart({required int productId, int quantity = 1}) async {
    final response = await _dio.post('/cart/items', data: {
      'product_id': productId,
      'quantity': quantity,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCartItem(String itemId, int quantity) async {
    final response = await _dio.put('/cart/items/$itemId', data: {
      'quantity': quantity,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> removeCartItem(String itemId) async {
    await _dio.delete('/cart/items/$itemId');
  }

  Future<void> clearCart() async {
    await _dio.delete('/cart');
  }

  // ── Orders ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createOrder({
    required String deliveryType,
    required int branchId,
    required String paymentMethod,
    String? addressId,
    String? notes,
  }) async {
    final response = await _dio.post('/orders', data: {
      'delivery_type': deliveryType,
      'branch_id': branchId,
      'payment_method': paymentMethod,
      if (addressId != null) 'address_id': addressId,
      if (notes != null) 'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOrders({int page = 1, int limit = 10, String? status}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null) params['status'] = status;
    final response = await _dio.get('/orders', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOrder(String id) async {
    final response = await _dio.get('/orders/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<void> cancelOrder(String id) async {
    await _dio.post('/orders/$id/cancel');
  }

  // ── Payments ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> checkTilopayStatus(String orderId) async {
    final response = await _dio.get('/payments/tilopay/status/$orderId');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getYappyInstructions(String orderId) async {
    final response = await _dio.get('/payments/yappy/instructions/$orderId');
    return response.data as Map<String, dynamic>;
  }

  // ── Addresses ─────────────────────────────────────────────────

  Future<List<dynamic>> getAddresses() async {
    final response = await _dio.get('/addresses');
    return (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createAddress({
    required String label,
    required String addressLine,
    String? city,
    String? zone,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.post('/addresses', data: {
      'label': label,
      'address_line': addressLine,
      if (city != null) 'city': city,
      if (zone != null) 'zone': zone,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteAddress(String id) async {
    await _dio.delete('/addresses/$id');
  }
}
