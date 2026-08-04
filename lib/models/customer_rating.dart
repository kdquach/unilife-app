class CustomerRating {
  final String id;
  final String ratingType;
  final int stars;
  final String? comment;
  final String? staffReply;
  final RatingUser? user;
  final RatingOrder? order;
  final RatingFood? food;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerRating({
    required this.id,
    required this.ratingType,
    required this.stars,
    this.comment,
    this.staffReply,
    this.user,
    this.order,
    this.food,
    this.createdAt,
    this.updatedAt,
  });

  String get targetLabel {
    if (ratingType.toUpperCase() == 'FOOD') {
      final foodName = food?.name.trim() ?? '';
      if (foodName.isNotEmpty) return foodName;
    }
    final code = order?.code.trim() ?? '';
    if (code.isNotEmpty) return 'Order #$code';
    final foodName = food?.name.trim() ?? '';
    if (foodName.isNotEmpty) return foodName;
    return 'Rating';
  }

  factory CustomerRating.fromJson(Map<String, dynamic> json) {
    final orderRaw = json['orderId'];
    final foodRaw = json['foodId'];
    final userRaw = json['userId'];

    return CustomerRating(
      id: _readId(json, virtualKey: 'ratingId'),
      ratingType: json['ratingType']?.toString() ?? 'ORDER',
      stars: ((json['stars'] as num?) ?? 0).toInt(),
      comment: _nullableText(json['comment']),
      staffReply: _nullableText(json['staffReply']),
      user:
          userRaw is Map<String, dynamic> ? RatingUser.fromJson(userRaw) : null,
      order: orderRaw is Map<String, dynamic>
          ? RatingOrder.fromJson(orderRaw)
          : null,
      food:
          foodRaw is Map<String, dynamic> ? RatingFood.fromJson(foodRaw) : null,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class RatingUser {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;

  const RatingUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
  });

  factory RatingUser.fromJson(Map<String, dynamic> json) {
    return RatingUser(
      id: _readId(json),
      fullName: json['fullName']?.toString() ?? 'Customer',
      email: json['email']?.toString() ?? '',
      avatarUrl: _nullableText(json['avatarUrl']),
    );
  }
}

class RatingOrder {
  final String id;
  final String code;
  final String status;
  final String paymentStatus;
  final DateTime? createdAt;

  const RatingOrder({
    required this.id,
    required this.code,
    required this.status,
    required this.paymentStatus,
    this.createdAt,
  });

  factory RatingOrder.fromJson(Map<String, dynamic> json) {
    return RatingOrder(
      id: _readId(json),
      code: json['orderCode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentStatus: json['paymentStatus']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']),
    );
  }
}

class RatingFood {
  final String id;
  final String name;
  final String? imageUrl;
  final int price;

  const RatingFood({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.price,
  });

  factory RatingFood.fromJson(Map<String, dynamic> json) {
    return RatingFood(
      id: _readId(json),
      name: json['name']?.toString() ?? 'Food',
      imageUrl: _nullableText(json['imageUrl']),
      price: ((json['price'] as num?) ?? 0).toInt(),
    );
  }
}

String _readId(Map<String, dynamic> json, {String? virtualKey}) {
  if (virtualKey != null && json[virtualKey] != null) {
    return json[virtualKey].toString();
  }
  return json['_id']?.toString() ??
      json['id']?.toString() ??
      json['ratingId']?.toString() ??
      json['orderId']?.toString() ??
      json['foodId']?.toString() ??
      '';
}

String? _nullableText(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
