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
      id: json['_id']?.toString() ??
          json['categoryId']?.toString() ??
          json['foodCategoryId']?.toString() ??
          '',
      name: json['name'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  String get emoji {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('rice')) {
      return 'RICE';
    }
    if (lowerName.contains('noodle')) {
      return 'NOODLE';
    }
    if (lowerName.contains('drink') ||
        lowerName.contains('tea') ||
        lowerName.contains('water')) {
      return 'DRINK';
    }
    if (lowerName.contains('snack') ||
        lowerName.contains('popcorn') ||
        lowerName.contains('fastfood')) {
      return 'SNACK';
    }
    if (lowerName.contains('cake') ||
        lowerName.contains('sweet') ||
        lowerName.contains('dessert')) {
      return 'SWEET';
    }
    if (lowerName.contains('vegetarian') ||
        lowerName.contains('vegan') ||
        lowerName.contains('salad')) {
      return 'VEG';
    }
    return 'FOOD';
  }
}
