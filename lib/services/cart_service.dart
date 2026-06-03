import '../models/cart_item.dart';
import 'api_client.dart';

class CartService {
  CartService(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> addItem(CartItem item, {String? token}) {
    return _apiClient.postJson('/cart/items', item.toPayload(), token: token);
  }

  Future<Map<String, dynamic>> checkout(List<CartItem> items, {String? token}) {
    return _apiClient.postJson('/orders', {
      'items': items.map((item) => item.toPayload()).toList(),
      'paymentMethod': 'SEPAY',
    }, token: token);
  }
}
