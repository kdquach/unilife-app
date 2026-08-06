enum FoodKind { menuFood, alwaysAvailable }

enum FoodStatus { available, soldOut, comingSoon, outOfStock }

String _categoryNameFromRaw(dynamic categoryRaw) {
  if (categoryRaw is Map<String, dynamic>) {
    return categoryRaw['name'] as String? ?? '';
  }
  if (categoryRaw is String) return categoryRaw;
  return '';
}

String? _categoryIdFromRaw(dynamic categoryRaw) {
  if (categoryRaw is Map<String, dynamic>) {
    final id = categoryRaw['_id'] ??
        categoryRaw['categoryId'] ??
        categoryRaw['foodCategoryId'] ??
        categoryRaw['id'];
    final value = id?.toString();
    return value != null && value.isNotEmpty ? value : null;
  }
  return null;
}

class Food {
  final String id;
  final String? menuScheduleItemId;
  final String name;
  final String category;
  final String? categoryId;
  final String description;
  final int price;
  final FoodKind kind;
  final FoodStatus status;
  final int? remainingServings;
  final int? stockQuantity;
  final String? mealType;
  final String? menuDateLabel;
  final String? imageUrl;
  final String? createdAt;
  final double rating;

  const Food({
    required this.id,
    this.menuScheduleItemId,
    required this.name,
    required this.category,
    this.categoryId,
    required this.description,
    required this.price,
    required this.kind,
    required this.status,
    this.remainingServings,
    this.stockQuantity,
    this.mealType,
    this.menuDateLabel,
    this.imageUrl,
    this.createdAt,
    this.rating = 4.8,
  });

  Food copyWith({
    String? id,
    String? menuScheduleItemId,
    String? name,
    String? category,
    String? description,
    int? price,
    FoodKind? kind,
    FoodStatus? status,
    int? remainingServings,
    int? stockQuantity,
    String? mealType,
    String? menuDateLabel,
    String? imageUrl,
    double? rating,
  }) {
    return Food(
      id: id ?? this.id,
      menuScheduleItemId: menuScheduleItemId ?? this.menuScheduleItemId,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      remainingServings: remainingServings ?? this.remainingServings,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      mealType: mealType ?? this.mealType,
      menuDateLabel: menuDateLabel ?? this.menuDateLabel,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
    );
  }

  factory Food.fromJson(Map<String, dynamic> json) {
    final isMenuItem = json['isMenuItem'] as bool? ?? false;
    final isActive = json['isActive'] as bool? ?? true;
    final stockQty = (json['stockQuantity'] as num?)?.toInt();

    FoodStatus status;
    if (!isActive) {
      status = FoodStatus.outOfStock;
    } else if (!isMenuItem && stockQty != null && stockQty <= 0) {
      status = FoodStatus.outOfStock;
    } else {
      status = FoodStatus.available;
    }

    final categoryRaw = json['categoryId'] ?? json['category'];

    final parsedId = json['_id']?.toString() ?? 
                     json['foodId']?.toString() ?? 
                     json['dishId']?.toString() ?? 
                     json['id']?.toString() ?? 
                     '';

    return Food(
      id: parsedId,
      name: json['name'] as String? ?? '',
      category: _categoryNameFromRaw(categoryRaw),
      categoryId: _categoryIdFromRaw(categoryRaw),
      description: json['description'] as String? ?? '',
      price: ((json['price'] as num?) ?? 0).toInt(),
      kind: isMenuItem ? FoodKind.menuFood : FoodKind.alwaysAvailable,
      status: status,
      stockQuantity: stockQty,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt']?.toString(),
      rating: 4.8,
    );
  }

  factory Food.fromMenuScheduleItemJson(Map<String, dynamic> json) {
    final menuScheduleItemId =
        json['_id']?.toString() ?? json['menuScheduleItemId']?.toString() ?? json['id']?.toString() ?? '';
    final remainingRaw = json['remainingCount'] ??
        json['remainingServings'] ??
        json['remainingQuantity'] ??
        json['remaining'];
    final remainingCount = (remainingRaw as num?)?.toInt();
    final isActive = json['isActive'] as bool? ?? true;

    final foodMap = (json['foodId'] ?? json['food'] ?? json['dish'] ?? json['dishId']) as Map<String, dynamic>? ?? {};
    final foodId =
        foodMap['_id']?.toString() ?? foodMap['foodId']?.toString() ?? foodMap['dishId']?.toString() ?? foodMap['id']?.toString() ?? '';
    final name = foodMap['name'] as String? ?? '';
    final description = foodMap['description'] as String? ?? '';
    final price = ((foodMap['price'] as num?) ?? 0).toInt();

    final categoryRaw = foodMap['categoryId'] ?? foodMap['category'];

    FoodStatus status = FoodStatus.available;
    if (!isActive || (remainingCount != null && remainingCount <= 0)) {
      status = FoodStatus.soldOut;
    }

    return Food(
      id: foodId,
      menuScheduleItemId: menuScheduleItemId.isNotEmpty ? menuScheduleItemId : null,
      name: name,
      category: _categoryNameFromRaw(categoryRaw),
      categoryId: _categoryIdFromRaw(categoryRaw),
      description: description,
      price: price,
      kind: FoodKind.menuFood,
      status: status,
      remainingServings: remainingCount,
      mealType: json['mealType']?.toString() ?? 'Lunch',
      menuDateLabel: 'Today',
      imageUrl: foodMap['imageUrl'] as String?,
      createdAt: foodMap['createdAt']?.toString(),
    );
  }

  bool get isMenuFood => kind == FoodKind.menuFood;
  bool get isAlwaysAvailable => kind == FoodKind.alwaysAvailable;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get canAddToCart {
    if (status != FoodStatus.available) return false;
    if (isMenuFood) {
      return menuScheduleItemId != null &&
          menuScheduleItemId!.isNotEmpty &&
          (remainingServings == null || remainingServings! > 0);
    }
    return true;
  }

  Map<String, dynamic> toCartAddPayload(int quantity) {
    if (isMenuFood && menuScheduleItemId != null) {
      return {
        'menuScheduleItemId': menuScheduleItemId,
        'quantity': quantity,
      };
    }
    return {
      'foodId': id,
      'quantity': quantity,
    };
  }

  String get typeLabel => isMenuFood ? 'Menu Food' : 'Always Available';
  String get statusLabel {
    switch (status) {
      case FoodStatus.available:
        if (!isMenuFood) return 'In stock';
        if (remainingServings == null) return 'Available';
        return remainingServings! > 0 ? 'Remaining: $remainingServings' : 'Sold out';
      case FoodStatus.soldOut:
        return 'Sold out';
      case FoodStatus.comingSoon:
        return 'Coming soon';
      case FoodStatus.outOfStock:
        return 'Out of stock';
    }
  }
}
