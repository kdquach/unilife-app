import '../models/order.dart';
import 'api_client.dart';

class OrderService {
  OrderService(this._client);

  final ApiClient _client;

  Future<List<Order>> getOrders({String? status, String? token}) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status.toUpperCase();
    }
    
    final path = Uri(path: '/orders', queryParameters: queryParams).toString();
    final response = await _client.getJson(path, token: token);
    
    final data = response['data'];
    final items = data is Map ? data['items'] : null;
    if (items == null || items is! List) return [];
    
    return items
        .whereType<Map<String, dynamic>>()
        .map(Order.fromJson)
        .toList();
  }

  Future<Order> getOrderById(String id, {String? token}) async {
    final response = await _client.getJson('/orders/$id', token: token);
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(statusCode: 500, message: 'Invalid order detail data');
    }
    return Order.fromJson(data);
  }

  Future<void> cancelOrder(String id, {String? token}) async {
    await _client.patchJson('/orders/$id', {'status': 'CANCELLED'}, token: token);
  }
}
