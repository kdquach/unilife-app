import 'food.dart';

class MenuSchedule {
  final String id;
  final DateTime date;
  final String status;
  final List<Food> items;

  const MenuSchedule({
    required this.id,
    required this.date,
    required this.status,
    required this.items,
  });

  factory MenuSchedule.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String?;
    final date =
        rawDate != null ? DateTime.parse(rawDate).toLocal() : DateTime.now();

    final itemsRaw = json['items'] as List? ?? [];
    final items = itemsRaw
        .whereType<Map<String, dynamic>>()
        .map((item) => Food.fromMenuScheduleItemJson(item))
        .toList();

    return MenuSchedule(
      id: json['_id']?.toString() ?? json['menuScheduleId']?.toString() ?? '',
      date: date,
      status: json['status'] as String? ?? 'DRAFT',
      items: items,
    );
  }
}
