import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart.dart';
import '../models/food.dart';
import '../services/api_client.dart';
import '../services/auth_storage.dart';
import '../services/cart_service.dart';

class CartNotifier extends AsyncNotifier<Cart?> {
  final _cartService = CartService(ApiClient());

  @override
  Future<Cart?> build() async {
    return _fetchCart();
  }

  Future<Cart?> _fetchCart() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      throw Exception('No access token found. Please login again.');
    }
    final response = await _cartService.getCart(token: token);
    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      return Cart.fromJson(data);
    } else {
      throw ApiException(
        statusCode: 400,
        message: response['message']?.toString() ?? 'Failed to load cart',
      );
    }
  }

  Future<void> refreshCart() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCart());
  }

  Future<void> addItem(Food food, {int quantity = 1}) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      throw Exception('No access token found. Please login again.');
    }
    
    final payload = food.toCartAddPayload(quantity);

    final response = await _cartService.addItem(payload, token: token);
    
    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      state = AsyncValue.data(Cart.fromJson(data));
    } else {
      throw Exception(response['message']?.toString() ?? 'Failed to add item');
    }
  }

  Future<void> updateItemQuantity(String cartItemId, int quantity) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      throw Exception('No access token found. Please login again.');
    }
    
    final response = await _cartService.updateItemQuantity(cartItemId, quantity, token: token);
    
    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      state = AsyncValue.data(Cart.fromJson(data));
    } else {
      throw Exception(response['message']?.toString() ?? 'Failed to update item quantity');
    }
  }

  Future<void> removeItem(String cartItemId) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      throw Exception('No access token found. Please login again.');
    }
    
    // Optimistic Update
    final previousState = state;
    if (state.hasValue && state.value != null) {
      final currentCart = state.value!;
      final newItems = currentCart.items.where((i) => i.cartItemId != cartItemId).toList();
      try {
        final removedItem = currentCart.items.firstWhere((i) => i.cartItemId == cartItemId);
        final newTotalPrice = currentCart.totalPrice - removedItem.subtotal;
        final newTotalItems = currentCart.totalItems - 1;
        
        state = AsyncValue.data(currentCart.copyWith(
          items: newItems,
          totalPrice: newTotalPrice,
          totalItems: newTotalItems,
        ));
      } catch (e) {
        // Item not found in current state, ignore optimistic update
      }
    }

    try {
      final response = await _cartService.removeItem(cartItemId, token: token);
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        state = AsyncValue.data(Cart.fromJson(data));
      } else {
        throw Exception(response['message']?.toString() ?? 'Failed to remove item');
      }
    } catch (e) {
      // Rollback on failure
      state = previousState;
      rethrow;
    }
  }
}

final cartProvider = AsyncNotifierProvider<CartNotifier, Cart?>(() {
  return CartNotifier();
});
