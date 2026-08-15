import '../core/utils/date_utils.dart';
import '../models/order.dart';
import 'api_client.dart';

bool isActiveOrderStatus(String status) {
  final s = status.toUpperCase();
  return s != 'COMPLETED' && s != 'CANCELLED' && s != 'EXPIRED';
}

bool isStaleActiveOrder(Order order) {
  if (!isActiveOrderStatus(order.status)) return false;
  if (order.createdAt == null) return false;
  return isBeforeLocalDay(order.createdAt!, DateTime.now());
}

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

  Future<Order> syncStaleActiveOrder(Order order, {String? token}) async {
    if (!isStaleActiveOrder(order)) return order;

    try {
      await cancelOrder(order.id, token: token);
    } catch (_) {
      return order;
    }

    return order.copyWith(status: 'CANCELLED');
  }

  Future<List<Order>> syncStaleActiveOrders(
    List<Order> orders, {
    String? token,
  }) async {
    final staleOrders =
        orders.where(isStaleActiveOrder).map((order) => order.id).toSet();
    if (staleOrders.isEmpty) return orders;

    await Future.wait(
      staleOrders.map((id) async {
        try {
          await cancelOrder(id, token: token);
        } catch (_) {}
      }),
    );

    return orders
        .map(
          (order) => staleOrders.contains(order.id)
              ? order.copyWith(status: 'CANCELLED')
              : order,
        )
        .toList();
  }

  Future<Order> checkout({String? token}) async {
    final response = await _client.postJson('/orders/checkout', {}, token: token);
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(statusCode: 500, message: 'Invalid checkout response data');
    }
    return Order.fromJson(data);
  }

  Future<void> triggerExpiredOrderCheck({String? token}) async {
    try {
      await _client.postJson('/orders/check-expired', {}, token: token);
    } catch (_) {
      // Silently fail - this is just a trigger attempt
    }
  }
}
