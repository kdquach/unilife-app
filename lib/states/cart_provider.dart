import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart.dart';
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
}

final cartProvider = AsyncNotifierProvider<CartNotifier, Cart?>(() {
  return CartNotifier();
});
