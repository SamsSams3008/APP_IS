import 'package:flutter/material.dart';
import '../services/ironsource_service.dart';
import '../widgets/stat_card.dart';
import '../utils/formatters.dart';
import '../charts/revenue_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final service = IronSourceService();
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = service.fetchDashboardData();
  }

  Future<void> refresh() async {
    setState(() {
      future = service.fetchDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('Error loading data'));
            }

            final data = snapshot.data as Map<String, dynamic>;

            return ListView(
              padding: const EdgeInsets.all(16),
             children: [
                StatCard(
                  title: 'Revenue',
                  value: formatMoney(data['revenue']),
                ),
                const SizedBox(height: 12),
                StatCard(
                  title: 'Impressions',
                  value: data['impressions'].toString(),
                ),
                const SizedBox(height: 12),
                StatCard(
                  title: 'eCPM',
                  value: formatMoney(data['ecpm']),
                ),
                const SizedBox(height: 24),
                const RevenueChart(),
              ],
            );
          },
        ),
      ),
    );
  }
}