import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../data/backend/backend_stats_repository.dart';
import '../../../../data/credentials/credentials_repository.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../auth/presentation/auth_state.dart';
import '../../domain/dashboard_filters.dart';
import '../../domain/dashboard_stats.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BackendStatsRepository _backend = BackendStatsRepository();
  final CredentialsRepository _credentials = CredentialsRepository();

  DashboardFilters _filters = DashboardFilters.last7Days();
  DashboardStats? _stats;
  List<BackendStatsRow> _rawRows = [];
  List<BackendApp> _apps = [];
  bool _loading = true;
  String? _error;

  // Cache: datos del backend por rango de fechas; filtros se aplican en memoria
  List<BackendStatsRow> _cachedRawRows = [];
  String? _cachedStartDate;
  String? _cachedEndDate;

  @override
  void initState() {
    super.initState();
    _checkCredentials();
  }

  Future<void> _checkCredentials() async {
    final hasCredentials = await _credentials.hasCredentials();
    if (!mounted) return;
    if (!hasCredentials) {
      context.push('/credentials');
      return;
    }
    _load();
  }

  bool get _isCacheValid =>
      _cachedStartDate == _filters.startDateStr &&
      _cachedEndDate == _filters.endDateStr &&
      _cachedRawRows.isNotEmpty;

  /// Filtra en memoria los datos cacheados según app, ad unit, país, plataforma.
  void _applyFiltersFromCache() {
    if (_cachedRawRows.isEmpty) return;
    final filtered = _cachedRawRows.where((row) {
      if (_filters.appKey != null && row.appKey != _filters.appKey) return false;
      if (_filters.adUnits != null && !_adUnitMatches(row.adUnits, _filters.adUnits!)) return false;
      if (_filters.country != null && row.country != _filters.country) return false;
      if (_filters.platform != null && row.platform != _filters.platform) return false;
      return true;
    }).toList();
    _rawRows = filtered;
    _stats = BackendStatsRepository.statsFromRows(filtered);
    setState(() {});
  }

  bool _adUnitMatches(String? rowAdUnit, String filterAdUnit) {
    if (rowAdUnit == null) return false;
    // La API puede devolver "Rewarded Video"; el filtro usa "rewardedVideo"
    final normalized = rowAdUnit.toLowerCase().replaceAll(' ', '');
    final f = filterAdUnit.toLowerCase();
    return normalized.contains(f) || f.contains(normalized) ||
        (filterAdUnit == 'rewardedVideo' && normalized.contains('rewarded'));
  }

  Future<void> _load() async {
    if (_isCacheValid) {
      _applyFiltersFromCache();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _backend.requestSync();
      final result = await _backend.getStats(
        startDate: _filters.startDateStr,
        endDate: _filters.endDateStr,
      );
      if (_apps.isEmpty) {
        try {
          _apps = await _backend.getApplications();
        } catch (_) {}
      }
      if (!mounted) return;
      _cachedRawRows = result.tableRows;
      _cachedStartDate = _filters.startDateStr;
      _cachedEndDate = _filters.endDateStr;
      _applyFiltersFromCache();
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _filters.startDate,
        end: _filters.endDate,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _filters = _filters.copyWith(
          startDate: DateTime(picked.start.year, picked.start.month, picked.start.day),
          endDate: DateTime(picked.end.year, picked.end.month, picked.end.day),
          datePreset: DateRangePreset.custom,
        );
      });
      _load();
    }
  }

  void _applyPreset(DateRangePreset preset) {
    final now = DateTime.now();
    DateTime start;
    switch (preset) {
      case DateRangePreset.today:
      case DateRangePreset.yesterday:
        start = DateTime(now.year, now.month, now.day).subtract(preset == DateRangePreset.yesterday ? const Duration(days: 1) : Duration.zero);
        break;
      case DateRangePreset.last7:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        break;
      case DateRangePreset.last30:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        break;
      case DateRangePreset.last90:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 89));
        break;
      case DateRangePreset.custom:
        _pickDateRange();
        return;
    }
    final end = preset == DateRangePreset.yesterday
        ? start
        : DateTime(now.year, now.month, now.day);
    setState(() {
      _filters = _filters.copyWith(
        startDate: start,
        endDate: end,
        datePreset: preset,
      );
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/credentials'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await context.read<AuthState>().signOut();
                if (context.mounted) context.go('/login');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          _cachedRawRows = [];
          _cachedStartDate = null;
          _cachedEndDate = null;
          return _load();
        },
        child: _loading && _stats == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _stats == null
                ? _ErrorBody(message: _error!, onRetry: _load)
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDateFilters(),
                        const SizedBox(height: 16),
                        if (_stats != null) ...[
                          _buildStatsGrid(_stats!),
                          const SizedBox(height: 24),
                          _buildRevenueChart(),
                          const SizedBox(height: 24),
                          _buildFiltersSection(),
                          const SizedBox(height: 16),
                          _buildDataTable(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildDateFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _presetChip('Hoy', DateRangePreset.today),
          const SizedBox(width: 8),
          _presetChip('Ayer', DateRangePreset.yesterday),
          const SizedBox(width: 8),
          _presetChip('7 días', DateRangePreset.last7),
          const SizedBox(width: 8),
          _presetChip('30 días', DateRangePreset.last30),
          const SizedBox(width: 8),
          _presetChip('90 días', DateRangePreset.last90),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('Personalizado'),
            onPressed: _pickDateRange,
            avatar: const Icon(Icons.calendar_today, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, DateRangePreset preset) {
    final selected = _filters.datePreset == preset;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _applyPreset(preset),
    );
  }

  Widget _buildStatsGrid(DashboardStats s) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            StatCard(
              title: 'Ingresos',
              value: formatMoney(s.revenue),
              icon: Icons.attach_money,
            ),
            StatCard(
              title: 'Impresiones',
              value: formatNumber(s.impressions),
              icon: Icons.visibility,
            ),
            StatCard(
              title: 'eCPM',
              value: formatMoney(s.ecpm),
              icon: Icons.trending_up,
            ),
            if (s.clicks != null)
              StatCard(
                title: 'Clicks',
                value: formatNumber(s.clicks!),
                icon: Icons.touch_app,
              ),
            if (s.completions != null)
              StatCard(
                title: 'Completados',
                value: formatNumber(s.completions!),
                icon: Icons.check_circle,
              ),
          ],
        );
      },
    );
  }

  Widget _buildRevenueChart() {
    final byDate = <String, double>{};
    for (final row in _rawRows) {
      final date = row.date ?? '';
      byDate[date] = (byDate[date] ?? 0) + row.revenue;
    }
    final entries = byDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Sin datos para el gráfico')),
        ),
      );
    }
    final spots = entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingresos por fecha',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) => Text(
                          formatMoney(value),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < entries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                entries[i].key.length >= 10
                                    ? entries[i].key.substring(5, 10)
                                    : entries[i].key,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                      dotData: FlDotData(show: spots.length <= 14),
                      belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_apps.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _filters.appKey,
                decoration: const InputDecoration(
                  labelText: 'App',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ..._apps.map((a) => DropdownMenuItem<String>(
                        value: a.appKey,
                        child: Text('${a.appName ?? a.appKey} (${a.platform ?? ''})'),
                      )),
                ],
                onChanged: (v) {
                  setState(() => _filters = _filters.copyWith(appKey: v));
                  _applyFiltersFromCache();
                },
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              value: _filters.adUnits,
              decoration: const InputDecoration(
                labelText: 'Tipo de anuncio',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todos')),
                DropdownMenuItem(value: 'rewardedVideo', child: Text('Rewarded Video')),
                DropdownMenuItem(value: 'interstitial', child: Text('Interstitial')),
                DropdownMenuItem(value: 'banner', child: Text('Banner')),
                DropdownMenuItem(value: 'offerWall', child: Text('Offerwall')),
              ],
              onChanged: (v) {
                setState(() => _filters = _filters.copyWith(adUnits: v));
                _applyFiltersFromCache();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _filters.platform,
              decoration: const InputDecoration(
                labelText: 'Plataforma',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todas')),
                DropdownMenuItem(value: 'Android', child: Text('Android')),
                DropdownMenuItem(value: 'iOS', child: Text('iOS')),
              ],
              onChanged: (v) {
                setState(() => _filters = _filters.copyWith(platform: v));
                _applyFiltersFromCache();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_rawRows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Sin datos para la tabla')),
        ),
      );
    }
    final rows = <List<String>>[];
    for (final row in _rawRows) {
      rows.add([
        row.date ?? '-',
        row.adUnits ?? '-',
        row.platform ?? '-',
        row.country ?? '-',
        formatMoney(row.revenue),
        row.impressions.toString(),
        formatMoney(row.eCPM),
      ]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datos detallados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Ad Unit')),
                  DataColumn(label: Text('Plataforma')),
                  DataColumn(label: Text('País')),
                  DataColumn(label: Text('Ingresos')),
                  DataColumn(label: Text('Impresiones')),
                  DataColumn(label: Text('eCPM')),
                ],
                rows: rows.map((r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList())).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
