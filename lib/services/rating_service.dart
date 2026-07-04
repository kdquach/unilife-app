import '../models/customer_rating.dart';
import 'api_client.dart';

class RatingService {
  RatingService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CustomerRating>> getRatings({
    String? token,
    String? orderId,
    String? foodId,
    String? ratingType,
  }) async {
    final path = Uri(
      path: '/ratings',
      queryParameters: {
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        if (foodId != null && foodId.isNotEmpty) 'foodId': foodId,
        if (ratingType != null && ratingType.isNotEmpty)
          'ratingType': ratingType,
      },
    ).toString();

    final response = await _apiClient.getJson(path, token: token);
    return _parseRatingItems(response);
  }

  Future<List<CustomerRating>> getMyRatings({
    String? token,
    String? orderId,
    String? foodId,
    String? ratingType,
  }) async {
    final path = Uri(
      path: '/ratings/me',
      queryParameters: {
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        if (foodId != null && foodId.isNotEmpty) 'foodId': foodId,
        if (ratingType != null && ratingType.isNotEmpty)
          'ratingType': ratingType,
      },
    ).toString();

    final response = await _apiClient.getJson(path, token: token);
    return _parseRatingItems(response);
  }

  Future<CustomerRating> createRating({
    required String orderId,
    required String ratingType,
    required int stars,
    String? token,
    String? foodId,
    String? comment,
  }) async {
    final payload = <String, dynamic>{
      'orderId': orderId,
      'ratingType': ratingType,
      'stars': stars,
      if (foodId != null && foodId.isNotEmpty) 'foodId': foodId,
      if (comment != null) 'comment': comment,
    };

    final response =
        await _apiClient.postJson('/ratings', payload, token: token);
    return _parseRatingItem(response);
  }

  Future<CustomerRating> updateRating({
    required String ratingId,
    required int stars,
    String? token,
    String? comment,
  }) async {
    final response = await _apiClient.patchJson(
      '/ratings/$ratingId',
      {
        'stars': stars,
        if (comment != null) 'comment': comment,
      },
      token: token,
    );
    return _parseRatingItem(response);
  }

  Future<void> deleteRating(String ratingId, {String? token}) async {
    await _apiClient.deleteJson('/ratings/$ratingId', token: token);
  }

  List<CustomerRating> _parseRatingItems(Map<String, dynamic> response) {
    final data = response['data'];
    final items = data is Map ? data['items'] : null;
    if (items is! List) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CustomerRating.fromJson)
        .toList();
  }

  CustomerRating _parseRatingItem(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return CustomerRating.fromJson(data);
    }
    throw ApiException(statusCode: 500, message: 'Invalid rating data');
  }
}
