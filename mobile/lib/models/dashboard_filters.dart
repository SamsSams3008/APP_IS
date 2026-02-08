class DashboardFilters {
  final DateTime from;
  final DateTime to;

  const DashboardFilters({
    required this.from,
    required this.to,
  });

  factory DashboardFilters.last7Days() {
    final now = DateTime.now();
    return DashboardFilters(
      from: now.subtract(const Duration(days: 7)),
      to: now,
    );
  }
}