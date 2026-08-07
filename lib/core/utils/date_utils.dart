bool isSameLocalDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

bool isBeforeLocalDay(DateTime date, DateTime reference) {
  final localDate = date.toLocal();
  final localRef = reference.toLocal();
  if (localDate.year != localRef.year) {
    return localDate.year < localRef.year;
  }
  if (localDate.month != localRef.month) {
    return localDate.month < localRef.month;
  }
  return localDate.day < localRef.day;
}
