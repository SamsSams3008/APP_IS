import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';
import '../utils/formatters.dart';
import '../models/dashboard_stats.dart';

class StatsSection extends StatelessWidget {
  final DashboardStats data;

  const StatsSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatCard(
          title: 'Revenue',
          value: formatMoney(data.revenue),
        ),
        const SizedBox(height: 12),
        StatCard(
          title: 'Impressions',
          value: data.impressions.toString(),
        ),
        const SizedBox(height: 12),
        StatCard(
          title: 'eCPM',
          value: formatMoney(data.ecpm),
        ),
      ],
    );
  }
}