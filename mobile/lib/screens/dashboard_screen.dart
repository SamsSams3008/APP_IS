import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/ironsource_service.dart';
import '../widgets/stat_card.dart';
import '../utils/formatters.dart';
import '../models/dashboard_stats.dart';
import '../charts/revenue_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final IronSourceService service = IronSourceService();

  late Future<DashboardStats> future;
  late List<FlSpot> revenueChartData;

  @override
  void initState() {
    super.initState();
    future = service.fetchDashboardData();

    final points = service.getRevenueChartData();
    revenueChartData = points
        .map((p) => FlSpot(p.day.toDouble(), p.value))
        .toList();
  }

  Future<void> refresh() async {
    setState(() {
      future = service.fetchDashboardData();

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
                const SizedBox(height: 24),
                RevenueChart(
                  spots: revenueChartData,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}