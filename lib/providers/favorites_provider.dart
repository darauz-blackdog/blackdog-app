import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFavoritesKey = 'favorite_product_ids';

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<int>>(FavoritesNotifier.new);

class FavoritesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFavoritesKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<int>();
      state = list.toSet();
    }
  }

  Future<void> toggle(int productId) async {
    final updated = Set<int>.from(state);
    if (updated.contains(productId)) {
      updated.remove(productId);
    } else {
      updated.add(productId);
    }
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFavoritesKey, jsonEncode(updated.toList()));
  }

  bool isFavorite(int productId) => state.contains(productId);
}
