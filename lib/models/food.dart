enum FoodKind { menuFood, alwaysAvailable }

enum FoodStatus { available, soldOut, comingSoon, outOfStock }

class Food {
  final String id;
  final String? menuScheduleItemId;
  final String name;
  final String category;
  final String description;
  final int price;
  final FoodKind kind;
  final FoodStatus status;
  final int? remainingServings;
  final int? stockQuantity;
  final String? mealType;
  final String? menuDateLabel;
  final double rating;

  const Food({
    required this.id,
    this.menuScheduleItemId,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.kind,
    required this.status,
    this.remainingServings,
    this.stockQuantity,
    this.mealType,
    this.menuDateLabel,
    this.rating = 4.8,
  });

  /// Parse từ JSON trả về của API Backend
  factory Food.fromJson(Map<String, dynamic> json) {
    final isMenuItem = json['isMenuItem'] as bool? ?? false;
    final isActive = json['isActive'] as bool? ?? true;
    final stockQty = json['stockQuantity'] as int?;

    // Xác định status từ isActive và stockQuantity
    FoodStatus status;
    if (!isActive) {
      status = FoodStatus.outOfStock;
    } else if (!isMenuItem && stockQty != null && stockQty <= 0) {
      status = FoodStatus.outOfStock;
    } else {
      status = FoodStatus.available;
    }

    // Lấy tên danh mục từ populate (categoryId có thể là object hoặc null)
    final categoryRaw = json['categoryId'];
    final categoryName = categoryRaw is Map<String, dynamic>
        ? (categoryRaw['name'] as String? ?? '')
        : '';

    return Food(
      id: json['_id']?.toString() ?? json['foodId']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      category: categoryName,
      description: json['description'] as String? ?? '',
      price: ((json['price'] as num?) ?? 0).toInt(),
      kind: isMenuItem ? FoodKind.menuFood : FoodKind.alwaysAvailable,
      status: status,
      stockQuantity: stockQty,
      rating: 4.8,
    );
  }

  bool get isMenuFood => kind == FoodKind.menuFood;
  bool get isAlwaysAvailable => kind == FoodKind.alwaysAvailable;
  bool get canAddToCart =>
      status == FoodStatus.available &&
      ((isMenuFood && (remainingServings ?? 0) > 0) ||
          (isAlwaysAvailable && (stockQuantity ?? 0) > 0));

  String get typeLabel => isMenuFood ? 'Menu Food' : 'Always Available';
  String get statusLabel {
    switch (status) {
      case FoodStatus.available:
        return isMenuFood ? 'Remaining: ${remainingServings ?? 0}' : 'In stock';
      case FoodStatus.soldOut:
        return 'Sold out';
      case FoodStatus.comingSoon:
        return 'Coming soon';
      case FoodStatus.outOfStock:
        return 'Out of stock';
    }
  }
}
