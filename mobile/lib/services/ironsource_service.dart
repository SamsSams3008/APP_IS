class IronSourceService {
  Future<Map<String, dynamic>> fetchDashboardData() async {
    await Future.delayed(const Duration(seconds: 1));

    return {
      'revenue': 123.45,
      'impressions': 9876,
      'ecpm': 12.34,
    };
  }
}