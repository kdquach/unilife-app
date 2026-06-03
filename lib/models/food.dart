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
