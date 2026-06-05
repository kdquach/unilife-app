class FoodCategory {
  final String id;
  final String name;
  final bool isActive;

  const FoodCategory({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  factory FoodCategory.fromJson(Map<String, dynamic> json) {
    return FoodCategory(
      id: json['_id']?.toString() ?? json['foodCategoryId']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  /// Trả về emoji đại diện dựa vào tên danh mục để UI hiển thị sinh động
  String get emoji {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('rice')) return '🍚';
    if (lowerName.contains('noodle')) return '🍜';
    if (lowerName.contains('drink') || lowerName.contains('tea') || lowerName.contains('water')) return '🥤';
    if (lowerName.contains('snack') || lowerName.contains('popcorn') || lowerName.contains('fastfood')) return '🍿';
    if (lowerName.contains('cake') || lowerName.contains('sweet') || lowerName.contains('dessert')) return '🍰';
    if (lowerName.contains('vegetarian') || lowerName.contains('vegan') || lowerName.contains('salad')) return '🥗';
    return '🍽️'; // default emoji
  }
}
