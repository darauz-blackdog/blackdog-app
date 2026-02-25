import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service_providers.dart';

/// User profile fetched from the API (includes Odoo-synced data)
final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getProfile();
  return (response['data'] as Map<String, dynamic>?) ?? response;
});

/// User addresses
final addressesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getAddresses();
});
