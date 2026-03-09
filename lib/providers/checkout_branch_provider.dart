import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/branch.dart';
import '../models/cart.dart';
import 'address_provider.dart';
import 'cart_provider.dart';
import 'location_provider.dart';
import 'service_providers.dart';

const _deliveryRadiusKm = 2.0;

/// Stock data per branch: { branchId: { productId: qty } }
final _stockByBranchProvider =
    FutureProvider.autoDispose<Map<int, Map<int, double>>>((ref) async {
  final cart = ref.watch(cartProvider).valueOrNull;
  if (cart == null || cart.isEmpty) return {};

  final api = ref.read(apiServiceProvider);
  final productIds = cart.items.map((i) => i.productId).toSet().toList();
  final raw = await api.checkStock(productIds);

  // Parse: { "branchId": { "productId": qty } }
  final result = <int, Map<int, double>>{};
  for (final entry in raw.entries) {
    final branchId = int.tryParse(entry.key);
    if (branchId == null) continue;
    final products = entry.value as Map<String, dynamic>;
    result[branchId] = {};
    for (final p in products.entries) {
      final pid = int.tryParse(p.key);
      if (pid != null) result[branchId]![pid] = (p.value as num).toDouble();
    }
  }
  return result;
});

/// Branch with computed delivery/stock info for checkout.
class RankedBranch {
  final Branch branch;
  final double distanceKm;
  final bool inDeliveryRange;
  final int itemsInStock;
  final int totalItems;
  final List<String> missingProducts; // names of products not in stock

  RankedBranch({
    required this.branch,
    required this.distanceKm,
    required this.inDeliveryRange,
    required this.itemsInStock,
    required this.totalItems,
    required this.missingProducts,
  });

  bool get hasFullStock => itemsInStock >= totalItems;
  bool get canDeliver => inDeliveryRange && branch.isDeliveryEnabled;
}

/// All branches ranked by stock + distance, with delivery eligibility.
final rankedBranchesProvider =
    Provider.autoDispose<AsyncValue<List<RankedBranch>>>((ref) {
  final branchesAsync = ref.watch(branchListProvider);
  final stockAsync = ref.watch(_stockByBranchProvider);
  final cart = ref.watch(cartProvider).valueOrNull;
  final address = ref.watch(selectedAddressProvider).valueOrNull;
  final userPos = ref.watch(userLocationProvider).valueOrNull;

  // Need both branches and stock to be loaded
  if (stockAsync is AsyncLoading || branchesAsync is AsyncLoading) {
    return const AsyncLoading();
  }
  if (stockAsync is AsyncError) {
    return AsyncError(
      (stockAsync as AsyncError).error,
      (stockAsync as AsyncError).stackTrace,
    );
  }
  if (branchesAsync is AsyncError) {
    return AsyncError(
      (branchesAsync as AsyncError).error,
      (branchesAsync as AsyncError).stackTrace,
    );
  }

  final branches = branchesAsync.valueOrNull ?? [];
  final stockMap = stockAsync.valueOrNull ?? {};
  final cartItems = cart?.items ?? [];

  // User location
  double? userLat;
  double? userLng;
  if (address != null) {
    userLat = address.latitude;
    userLng = address.longitude;
  } else if (userPos != null) {
    userLat = userPos.latitude;
    userLng = userPos.longitude;
  }

  final ranked = branches.map((b) {
    // Distance
    double dist = double.infinity;
    if (userLat != null && userLng != null && b.latitude != null && b.longitude != null) {
      dist = _haversineKm(userLat, userLng, b.latitude!, b.longitude!);
    }

    // Stock check
    final branchStock = stockMap[b.id] ?? {};
    int inStock = 0;
    final missing = <String>[];
    for (final item in cartItems) {
      final qty = branchStock[item.productId] ?? 0;
      if (qty >= item.quantity) {
        inStock++;
      } else {
        missing.add(item.productName ?? 'Producto #${item.productId}');
      }
    }

    return RankedBranch(
      branch: b,
      distanceKm: dist,
      inDeliveryRange: dist <= _deliveryRadiusKm,
      itemsInStock: inStock,
      totalItems: cartItems.length,
      missingProducts: missing,
    );
  }).toList();

  // Sort: full stock first, then by distance
  ranked.sort((a, b) {
    // Full stock branches first
    if (a.hasFullStock && !b.hasFullStock) return -1;
    if (!a.hasFullStock && b.hasFullStock) return 1;
    // Then by items in stock (more is better)
    if (a.itemsInStock != b.itemsInStock) return b.itemsInStock.compareTo(a.itemsInStock);
    // Then by distance
    return a.distanceKm.compareTo(b.distanceKm);
  });

  return AsyncData(ranked);
});

/// Best branch for delivery (auto-assigned).
final bestDeliveryBranchProvider = Provider.autoDispose<RankedBranch?>((ref) {
  final ranked = ref.watch(rankedBranchesProvider).valueOrNull;
  if (ranked == null) return null;

  // Find best branch that can deliver (in range + delivery enabled)
  final deliverable = ranked.where((r) => r.canDeliver).toList();
  if (deliverable.isEmpty) return null;

  // Already sorted by stock then distance — first is best
  return deliverable.first;
});

/// Whether delivery is available at all.
final deliveryAvailableProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(bestDeliveryBranchProvider) != null;
});

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _deg2rad(double deg) => deg * (pi / 180);
