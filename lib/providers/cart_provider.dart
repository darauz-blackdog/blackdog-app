import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart.dart';
import 'service_providers.dart';

/// Cart state notifier — manages the server-side cart with optimistic updates
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
    final previous = state.valueOrNull;

    // Optimistic: increment count immediately if cart exists
    if (previous != null) {
      final existingIdx = previous.items.indexWhere((i) => i.productId == productId);
      List<CartItem> optimisticItems;
      if (existingIdx >= 0) {
        optimisticItems = [...previous.items];
        final old = optimisticItems[existingIdx];
        optimisticItems[existingIdx] = CartItem(
          id: old.id,
          cartId: old.cartId,
          productId: old.productId,
          productName: old.productName,
          productPrice: old.productPrice,
          imageUrl: old.imageUrl,
          quantity: old.quantity + quantity,
        );
      } else {
        optimisticItems = [
          ...previous.items,
          CartItem(
            id: 'temp_$productId',
            cartId: previous.id,
            productId: productId,
            quantity: quantity,
          ),
        ];
      }
      final optimistic = Cart(
        id: previous.id,
        status: previous.status,
        items: optimisticItems,
        subtotal: optimisticItems.fold(0.0, (sum, i) => sum + i.lineTotal),
      );
      state = AsyncValue.data(optimistic);
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.addToCart(productId: productId, quantity: quantity);
      // Sync with server to get correct data
      state = AsyncValue.data(await _fetchCart());
    } catch (e) {
      // Rollback on failure
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<void> updateItemQuantity(String itemId, int quantity) async {
    final previous = state.valueOrNull;

    // Optimistic update
    if (previous != null) {
      final items = previous.items.map((i) {
        if (i.id == itemId) {
          return CartItem(
            id: i.id,
            cartId: i.cartId,
            productId: i.productId,
            productName: i.productName,
            productPrice: i.productPrice,
            imageUrl: i.imageUrl,
            quantity: quantity,
          );
        }
        return i;
      }).toList();
      state = AsyncValue.data(Cart(
        id: previous.id,
        status: previous.status,
        items: items,
        subtotal: items.fold(0.0, (sum, i) => sum + i.lineTotal),
      ));
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateCartItem(itemId, quantity);
      state = AsyncValue.data(await _fetchCart());
    } catch (e) {
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<void> removeItem(String itemId) async {
    final previous = state.valueOrNull;

    // Optimistic: remove item immediately
    if (previous != null) {
      final items = previous.items.where((i) => i.id != itemId).toList();
      state = AsyncValue.data(Cart(
        id: previous.id,
        status: previous.status,
        items: items,
        subtotal: items.fold(0.0, (sum, i) => sum + i.lineTotal),
      ));
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.removeCartItem(itemId);
      state = AsyncValue.data(await _fetchCart());
    } catch (e) {
      state = AsyncValue.data(previous);
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
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  void refresh() {
    ref.invalidateSelf();
  }
}

/// Cart item count for badge — uses .select() to only rebuild on count change
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider.select((asyncCart) =>
    asyncCart.valueOrNull?.itemCount ?? 0,
  ));
});
