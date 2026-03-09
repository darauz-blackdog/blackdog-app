import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/branch.dart';
import 'service_providers.dart';

// ── Selected address ─────────────────────────────────────────────

class SelectedAddress {
  final String id;
  final String label;
  final String addressLine;
  final double latitude;
  final double longitude;

  const SelectedAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'address_line': addressLine,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory SelectedAddress.fromJson(Map<String, dynamic> json) {
    return SelectedAddress(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      addressLine: json['address_line'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class SelectedAddressNotifier extends AsyncNotifier<SelectedAddress?> {
  static const _key = 'selected_address';

  @override
  Future<SelectedAddress?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      return SelectedAddress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
    return null;
  }

  Future<void> selectAddress(SelectedAddress address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(address.toJson()));
    state = AsyncData(address);
  }

  Future<void> clearAddress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncData(null);
  }
}

final selectedAddressProvider =
    AsyncNotifierProvider<SelectedAddressNotifier, SelectedAddress?>(
  SelectedAddressNotifier.new,
);

// ── Nearest branch calculation ───────────────────────────────────

class NearestBranchResult {
  final Branch branch;
  final double distanceKm;
  final bool isDeliveryAvailable;

  const NearestBranchResult({
    required this.branch,
    required this.distanceKm,
    required this.isDeliveryAvailable,
  });
}

/// Fetches branches typed as Branch models (shared across the app).
/// Filters out inactive branches.
final branchListProvider = FutureProvider<List<Branch>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getBranches();
  return data
      .map((b) => Branch.fromJson(b as Map<String, dynamic>))
      .where((b) => b.isActive)
      .toList();
});

/// Derives the nearest branch from the selected address.
final nearestBranchProvider = Provider<NearestBranchResult?>((ref) {
  final address = ref.watch(selectedAddressProvider).valueOrNull;
  final branches = ref.watch(branchListProvider).valueOrNull;
  if (address == null || branches == null || branches.isEmpty) return null;

  Branch? closest;
  double minDist = double.infinity;

  for (final b in branches) {
    if (b.latitude == null || b.longitude == null) continue;
    final d = _haversineKm(
      address.latitude,
      address.longitude,
      b.latitude!,
      b.longitude!,
    );
    if (d < minDist) {
      minDist = d;
      closest = b;
    }
  }

  if (closest == null) return null;

  return NearestBranchResult(
    branch: closest,
    distanceKm: minDist,
    isDeliveryAvailable: minDist <= 2.0 && closest.isDeliveryEnabled,
  );
});

/// Haversine formula — returns distance in km.
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0; // Earth radius in km
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _deg2rad(double deg) => deg * (pi / 180);
