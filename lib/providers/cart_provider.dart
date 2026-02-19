import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart.dart';
import 'service_providers.dart';

/// Cart state notifier — manages the server-side cart
final cartProvider = AsyncNotifierProvider<CartNotifier, Cart?>(CartNotifier.new);

class CartNotifier extends AsyncNotifier<Cart?> {
  @override
  Future<Cart?> build() async {
    return _fetchCart();
  }

  Future<Cart?> _fetchCart() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getCart();
      return Cart.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> addItem(int productId, {int quantity = 1}) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.addToCart(productId: productId, quantity: quantity);
      // Refresh cart from server
      state = AsyncValue.data(await _fetchCart());
    } catch (e) {
      // Re-throw to be caught by the UI
      rethrow;
    }
  }

  Future<void> updateItemQuantity(String itemId, int quantity) async {
    final api = ref.read(apiServiceProvider);
    await api.updateCartItem(itemId, quantity);
    state = AsyncValue.data(await _fetchCart());
  }

  Future<void> removeItem(String itemId) async {
    final api = ref.read(apiServiceProvider);
    await api.removeCartItem(itemId);
    state = AsyncValue.data(await _fetchCart());
  }

  Future<void> clear() async {
    final api = ref.read(apiServiceProvider);
    await api.clearCart();
    state = AsyncValue.data(await _fetchCart());
  }

  void refresh() {
    ref.invalidateSelf();
  }
}

/// Cart item count for badge
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider).valueOrNull;
  return cart?.itemCount ?? 0;
});
