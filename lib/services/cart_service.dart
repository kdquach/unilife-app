import '../models/cart_item.dart';
import 'api_client.dart';

class CartService {
  CartService(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getCart({String? token}) {
    return _apiClient.getJson('/carts/my', token: token);
  }

  Future<Map<String, dynamic>> addItem(Map<String, dynamic> payload, {String? token}) {
    return _apiClient.postJson('/carts/my/items', payload, token: token);
  }

  Future<Map<String, dynamic>> updateItemQuantity(String cartItemId, int quantity, {String? token}) {
    return _apiClient.patchJson('/carts/my/items/$cartItemId', {'quantity': quantity}, token: token);
  }

  Future<Map<String, dynamic>> removeItem(String cartItemId, {String? token}) {
    return _apiClient.deleteJson('/carts/my/items/$cartItemId', token: token);
  }

  Future<Map<String, dynamic>> checkout(List<CartItem> items, {String? token}) {
    return _apiClient.postJson('/orders', {
      'items': items.map((item) => item.toPayload()).toList(),
      'paymentMethod': 'SEPAY',
    }, token: token);
  }
}
