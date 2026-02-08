import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/ironsource_service.dart';
import '../widgets/stat_card.dart';
import '../utils/formatters.dart';
import '../models/dashboard_stats.dart';
import '../charts/revenue_chart.dart';
import '../sections/stats_section.dart';
import '../models/dashboard_filters.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final IronSourceService service = IronSourceService();

  late Future<DashboardStats> future;
  late List<FlSpot> revenueChartData;
  late DashboardFilters filters;

  @override
  void initState() {
    super.initState();
    filters = DashboardFilters.last7Days();
    future = service.fetchDashboardData(filters);
    final points = service.getRevenueChartData();
    revenueChartData = points
        .map((p) => FlSpot(p.day.toDouble(), p.value))
        .toList();
  }

  Future<void> refresh() async {
    setState(() {
      future = service.fetchDashboardData(filters);

      final points = service.getRevenueChartData();
      revenueChartData = points
          .map((p) => FlSpot(p.day.toDouble(), p.value))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<DashboardStats>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('Error loading data'));
            }

            final data = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StatsSection(data: data),   // ← aquí viven tus 3 stats (o 10 después)
                const SizedBox(height: 24),
                RevenueChart(spots: revenueChartData),
              ]
            );
          },
        ),
      ),
    );
  }
}