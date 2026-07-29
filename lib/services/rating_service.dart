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
    int page = 1,
    int limit = 20,
  }) async {
    final result = await getRatingsPage(
      token: token,
      orderId: orderId,
      foodId: foodId,
      ratingType: ratingType,
      page: page,
      limit: limit,
    );
    return result.items;
  }

  Future<RatingPage> getRatingsPage({
    String? token,
    String? orderId,
    String? foodId,
    String? ratingType,
    int page = 1,
    int limit = 20,
  }) async {
    final path = Uri(
      path: '/ratings',
      queryParameters: {
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        if (foodId != null && foodId.isNotEmpty) 'foodId': foodId,
        if (ratingType != null && ratingType.isNotEmpty)
          'ratingType': ratingType,
        if (ratingType != null && ratingType.isNotEmpty) 'type': ratingType,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    ).toString();

    final response = await _apiClient.getJson(path, token: token);
    return _parseRatingPage(response);
  }

  Future<List<CustomerRating>> getMyRatings({
    String? token,
    String? orderId,
    String? foodId,
    String? ratingType,
    int page = 1,
    int limit = 20,
  }) async {
    final result = await getMyRatingsPage(
      token: token,
      orderId: orderId,
      foodId: foodId,
      ratingType: ratingType,
      page: page,
      limit: limit,
    );
    return result.items;
  }

  Future<RatingPage> getMyRatingsPage({
    String? token,
    String? orderId,
    String? foodId,
    String? ratingType,
    int page = 1,
    int limit = 20,
  }) async {
    final path = Uri(
      path: '/ratings/me',
      queryParameters: {
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        if (foodId != null && foodId.isNotEmpty) 'foodId': foodId,
        if (ratingType != null && ratingType.isNotEmpty)
          'ratingType': ratingType,
        if (ratingType != null && ratingType.isNotEmpty) 'type': ratingType,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    ).toString();

    final response = await _apiClient.getJson(path, token: token);
    return _parseRatingPage(response);
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

  RatingPage _parseRatingPage(Map<String, dynamic> response) {
    final data = response['data'];
    final items = data is Map ? data['items'] : null;
    final parsedItems = items is List
        ? items
            .whereType<Map<String, dynamic>>()
            .map(CustomerRating.fromJson)
            .toList()
        : <CustomerRating>[];
    final pagination = data is Map ? data['pagination'] : null;
    if (pagination is! Map) {
      return RatingPage(
        items: parsedItems,
        page: 1,
        limit: parsedItems.length,
        total: parsedItems.length,
        totalPages: parsedItems.isEmpty ? 0 : 1,
      );
    }

    return RatingPage(
      items: parsedItems,
      page: ((pagination['page'] as num?) ?? 1).toInt(),
      limit: ((pagination['limit'] as num?) ?? parsedItems.length).toInt(),
      total: ((pagination['total'] as num?) ?? parsedItems.length).toInt(),
      totalPages:
          ((pagination['totalPages'] as num?) ?? (parsedItems.isEmpty ? 0 : 1))
              .toInt(),
    );
  }

  CustomerRating _parseRatingItem(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return CustomerRating.fromJson(data);
    }
    throw ApiException(statusCode: 500, message: 'Invalid rating data');
  }
}

class RatingPage {
  final List<CustomerRating> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const RatingPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}
