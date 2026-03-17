import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart.dart';
import 'service_providers.dart';

/// Cart state notifier — manages the server-side cart with optimistic UI
final cartProvider = AsyncNotifierProvider<CartNotifier, Cart?>(CartNotifier.new);

class CartNotifier extends AsyncNotifier<Cart?> {
  @override
  Future<Cart?> build() async {
    return _fetchCart();
  }

  Future<Cart?> _fetchCart() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;
    final api = ref.read(apiServiceProvider);
    final data = await api.getCart();
    return Cart.fromJson(data);
  }

  Future<void> addItem(int productId, {int quantity = 1}) async {
    final previous = state.valueOrNull;

    // Optimistic update: increment item count immediately
    if (previous != null) {
      final existingIndex = previous.items.indexWhere((i) => i.productId == productId);
      final updatedItems = List<CartItem>.from(previous.items);
      if (existingIndex >= 0) {
        final existing = updatedItems[existingIndex];
        updatedItems[existingIndex] = CartItem(
          id: existing.id,
          cartId: existing.cartId,
          productId: existing.productId,
          productName: existing.productName,
          productPrice: existing.productPrice,
          imageUrl: existing.imageUrl,
          quantity: existing.quantity + quantity,
        );
      } else {
        updatedItems.add(CartItem(
          id: 'optimistic_$productId',
          cartId: previous.id,
          productId: productId,
          quantity: quantity,
        ));
      }
      state = AsyncValue.data(Cart(
        id: previous.id,
        status: previous.status,
        items: updatedItems,
        subtotal: updatedItems.fold(0.0, (sum, item) => sum + item.lineTotal),
      ));
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.addToCart(productId: productId, quantity: quantity);
      // Sync with server in background
      state = AsyncValue.data(await _fetchCart());
    } catch (e) {
      // Revert to previous state on failure
      if (previous != null) {
        state = AsyncValue.data(previous);
      }
      rethrow;
    }
  }

  Future<void> updateItemQuantity(String itemId, int quantity) async {
    final previous = state.valueOrNull;

    // Optimistic update
    if (previous != null) {
      final updatedItems = previous.items.map((item) {
        if (item.id == itemId) {
          return CartItem(
            id: item.id,
            cartId: item.cartId,
            productId: item.productId,
            productName: item.productName,
            productPrice: item.productPrice,
            imageUrl: item.imageUrl,
            quantity: quantity,
          );
        }
        return item;
      }).toList();
      state = AsyncValue.data(Cart(
        id: previous.id,
        status: previous.status,
        items: updatedItems,
        subtotal: updatedItems.fold(0.0, (sum, item) => sum + item.lineTotal),
      ));
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateCartItem(itemId, quantity);
      state = AsyncValue.data(await _fetchCart());
    } catch (e) {
      if (previous != null) state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<void> removeItem(String itemId) async {
    final previous = state.valueOrNull;

    // Optimistic update: remove item immediately
    if (previous != null) {
      final updatedItems = previous.items.where((i) => i.id != itemId).toList();
      state = AsyncValue.data(Cart(
        id: previous.id,
        status: previous.status,
        items: updatedItems,
        subtotal: updatedItems.fold(0.0, (sum, item) => sum + item.lineTotal),
      ));
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.removeCartItem(itemId);
      state = AsyncValue.data(await _fetchCart());
    } catch (e) {
      if (previous != null) state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<void> clear() async {
    final previous = state.valueOrNull;

    // Optimistic: clear immediately
    if (previous != null) {
      state = AsyncValue.data(Cart(
        id: previous.id,
        status: previous.status,
        items: [],
        subtotal: 0,
      ));
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.clearCart();
      state = AsyncValue.data(await _fetchCart());
    } catch (e) {
      if (previous != null) state = AsyncValue.data(previous);
      rethrow;
    }
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
