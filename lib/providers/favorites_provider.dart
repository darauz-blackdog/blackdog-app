import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kFavoritesKey = 'favorite_product_ids';

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<int>>(FavoritesNotifier.new);

class FavoritesNotifier extends Notifier<Set<int>> {
  SupabaseClient get _sb => Supabase.instance.client;
  User? get _user => _sb.auth.currentUser;

  @override
  Set<int> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    if (_user != null) {
      await _loadFromSupabase();
    } else {
      await _loadFromLocal();
    }
  }

  Future<void> _loadFromSupabase() async {
    try {
      final data = await _sb
          .from('favorites')
          .select('product_id')
          .eq('user_id', _user!.id);
      final ids = (data as List).map((r) => r['product_id'] as int).toSet();
      state = ids;
      // Sync to local as cache
      await _saveToLocal(ids);
      // Migrate any local-only favorites to Supabase
      await _migrateLocalToSupabase(ids);
    } catch (_) {
      // Fallback to local if network fails
      await _loadFromLocal();
    }
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFavoritesKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<int>();
      state = list.toSet();
    }
  }

  /// Migrate favorites saved locally before login to Supabase.
  Future<void> _migrateLocalToSupabase(Set<int> remoteIds) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFavoritesKey);
    if (raw == null) return;

    final localIds = (jsonDecode(raw) as List).cast<int>().toSet();
    final toMigrate = localIds.difference(remoteIds);
    if (toMigrate.isEmpty) return;

    final rows = toMigrate
        .map((id) => {'user_id': _user!.id, 'product_id': id})
        .toList();
    try {
      await _sb.from('favorites').upsert(rows, onConflict: 'user_id,product_id');
      state = {...state, ...toMigrate};
    } catch (_) {
      // Non-critical, will retry next load
    }
  }

  Future<void> toggle(int productId) async {
    final updated = Set<int>.from(state);
    final adding = !updated.contains(productId);

    if (adding) {
      updated.add(productId);
    } else {
      updated.remove(productId);
    }
    state = updated;

    if (_user != null) {
      try {
        if (adding) {
          await _sb.from('favorites').upsert(
            {'user_id': _user!.id, 'product_id': productId},
            onConflict: 'user_id,product_id',
          );
        } else {
          await _sb
              .from('favorites')
              .delete()
              .eq('user_id', _user!.id)
              .eq('product_id', productId);
        }
      } catch (_) {
        // Revert on error
        if (adding) {
          updated.remove(productId);
        } else {
          updated.add(productId);
        }
        state = updated;
        return;
      }
    }

    await _saveToLocal(updated);
  }

  Future<void> _saveToLocal(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFavoritesKey, jsonEncode(ids.toList()));
  }

  bool isFavorite(int productId) => state.contains(productId);
}
