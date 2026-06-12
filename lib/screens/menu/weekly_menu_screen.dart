import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/food.dart';
import '../../models/menu_schedule.dart';
import '../../services/api_client.dart';
import '../../states/cart_provider.dart';
import '../../services/food_service.dart';
import '../../widgets/food_cards.dart';
import '../food/food_detail_screen.dart';

class WeeklyMenuScreen extends ConsumerStatefulWidget {
  static const String routeName = '/weekly-menu';

  const WeeklyMenuScreen({super.key});

  @override
  ConsumerState<WeeklyMenuScreen> createState() => _WeeklyMenuScreenState();
}

class _WeeklyMenuScreenState extends ConsumerState<WeeklyMenuScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<MenuSchedule> _schedules = [];
  bool _isLoading = true;
  String? _error;

  late List<DateTime> _weekDays;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _computeWeekDays();
    _loadWeeklySchedules();
  }

  void _computeWeekDays() {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Mon, 7 = Sun
    _selectedDay = DateTime(now.year, now.month, now.day);

    _weekDays = List.generate(7, (index) {
      final diff = index + 1 - currentWeekday;
      final day = now.add(Duration(days: diff));
      return DateTime(day.year, day.month, day.day);
    });
  }

  Future<void> _loadWeeklySchedules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final monday = _weekDays.first;
    final sunday = _weekDays.last;

    final formattedStart =
        "${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
    final formattedEnd =
        "${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')} 23:59:59";

    try {
      final schedules = await _foodService.getWeeklyMenuSchedules(
        dateFrom: formattedStart,
        dateTo: formattedEnd,
      );
      if (mounted) setState(() => _schedules = schedules);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _open(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  Future<void> _add(Food food) async {
    try {
      await ref.read(cartProvider.notifier).addItem(food);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tìm schedule khớp với ngày đang chọn và phải có status là PUBLISHED
    final activeSchedule = _schedules.firstWhere(
      (s) =>
          s.date.year == _selectedDay.year &&
          s.date.month == _selectedDay.month &&
          s.date.day == _selectedDay.day &&
          s.status == 'PUBLISHED',
      orElse: () => MenuSchedule(
          id: '',
          date: DateTime.now(),
          status: 'DRAFT',
          items: const []), // fallback
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Menu')),
      body: RefreshIndicator(
        onRefresh: _loadWeeklySchedules,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorView()
                : _buildBody(activeSchedule.items),
      ),
    );
  }

  Widget _buildErrorView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 150,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppColors.subText),
            const SizedBox(height: 16),
            const Text(
              'Could not load weekly menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subText)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadWeeklySchedules,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Food> foods) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Weekly meal planning schedule',
            style: TextStyle(color: AppColors.subText)),
        const SizedBox(height: 16),
        _buildCalendarRow(),
        const SizedBox(height: 24),
        Text(
          DateFormat('EEEE, d MMMM yyyy').format(_selectedDay),
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        if (foods.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_meals_outlined,
                    size: 56, color: AppColors.subText),
                const SizedBox(height: 16),
                const Text(
                  'No menu scheduled for this day',
                  style: TextStyle(color: AppColors.subText),
                ),
                const SizedBox(height: 4),
                Text(
                  'Menus are draft or not published yet.',
                  style: TextStyle(
                      color: AppColors.subText.withValues(alpha: 0.6),
                      fontSize: 12),
                ),
              ],
            ),
          )
        else
          ...foods.map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MenuFoodCard(
                food: food,
                onTap: () => _open(food),
                onAdd: food.canAddToCart ? () => _add(food) : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalendarRow() {
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = _weekDays[index];
        final isSelected = day.year == _selectedDay.year &&
            day.month == _selectedDay.month &&
            day.day == _selectedDay.day;

        final isToday = day.year == DateTime.now().year &&
            day.month == DateTime.now().month &&
            day.day == DateTime.now().day;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedDay = day;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primarySoft.withValues(alpha: 0.3)
                      : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primarySoft
                        : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  dayNames[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.subText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  day.day.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
