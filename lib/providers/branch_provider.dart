import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'address_provider.dart';

class SelectedBranch {
  final int id;
  final String name;

  const SelectedBranch({required this.id, required this.name});
}

class SelectedBranchNotifier extends AsyncNotifier<SelectedBranch?> {
  static const _keyId = 'selected_branch_id';
  static const _keyName = 'selected_branch_name';

  @override
  Future<SelectedBranch?> build() async {
    // Auto-sync with nearest branch when address changes
    final nearest = ref.watch(nearestBranchProvider);
    if (nearest != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyId, nearest.branch.id);
      await prefs.setString(_keyName, nearest.branch.name);
      return SelectedBranch(id: nearest.branch.id, name: nearest.branch.name);
    }

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_keyId);
    final name = prefs.getString(_keyName);
    if (id != null && name != null) {
      return SelectedBranch(id: id, name: name);
    }
    return null;
  }

  Future<void> selectBranch(int id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyId, id);
    await prefs.setString(_keyName, name);
    state = AsyncData(SelectedBranch(id: id, name: name));
  }

  Future<void> clearBranch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyId);
    await prefs.remove(_keyName);
    state = const AsyncData(null);
  }
}

final selectedBranchProvider =
    AsyncNotifierProvider<SelectedBranchNotifier, SelectedBranch?>(
  SelectedBranchNotifier.new,
);
