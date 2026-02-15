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
}
