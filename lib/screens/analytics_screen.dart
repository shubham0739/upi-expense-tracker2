import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/month_selector.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final monthExpenses = state.expensesForMonth(_month);
    final total =
        monthExpenses.fold(0.0, (s, e) => s + e.amount);
    final byCat = state.spentByCategory(_month);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            MonthSelector(
              month: _month,
              onChanged: (m) => setState(() => _month = m),
            ),
            const SizedBox(height: 8),
            if (monthExpenses.isEmpty)
              const EmptyState(
                icon: Icons.bar_chart,
                title: 'No data for this month',
                subtitle: 'Log an expense and charts will appear here.',
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(
                        label: 'Total spent',
                        value:
                            formatMoney(total, symbol: state.currencySymbol),
                      ),
                      _Stat(label: 'Entries', value: '${monthExpenses.length}'),
                      _Stat(
                        label: 'Daily avg',
                        value: formatMoney(
                            total / DateTime.now().day,
                            symbol: state.currencySymbol),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('By category', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: PieChart(PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          sections: byCat.entries.map((e) {
                            final info = state.categoryInfo(e.key);
                            final pct = total == 0 ? 0.0 : e.value / total * 100;
                            return PieChartSectionData(
                              value: e.value,
                              color: info.color,
                              title: pct >= 8 ? '${pct.round()}%' : '',
                              radius: 42,
                              titleStyle: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            );
                          }).toList(),
                        )),
                      ),
                      const SizedBox(height: 12),
                      ...byCat.entries.map((e) {
                        final info = state.categoryInfo(e.key);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(info.icon, size: 16, color: info.color),
                              const SizedBox(width: 8),
                              Expanded(child: Text(e.key)),
                              Text(
                                formatMoney(e.value,
                                    symbol: state.currencySymbol),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Day by day', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 180,
                    child: _DailyBarChart(
                        byDay: state.spentByDay(_month), month: _month, scheme: scheme),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('6-month trend',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 180,
                    child: _TrendLineChart(
                      totals: state.monthlyTotals(6), scheme: scheme),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Top payees', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _TopPayees(
                      payees: state.topPayees(_month).take(5).toList(),
                      symbol: state.currencySymbol,
                      scheme: scheme),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  final Map<String, double> byDay;
  final DateTime month;
  final ColorScheme scheme;

  const _DailyBarChart(
      {required this.byDay, required this.month, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    double maxV = 0;
    for (final v in byDay.values) {
      if (v > maxV) maxV = v;
    }
    return BarChart(BarChartData(
      maxY: maxV * 1.25,
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      barGroups: List.generate(daysInMonth, (i) {
        final day = i + 1;
        final v = byDay['${monthKey(month)}-${day.toString().padLeft(2, '0')}'] ?? 0.0;
        return BarChartGroupData(
          x: day,
          barRods: [
            BarChartRodData(
              toY: v,
              color: scheme.primary,
              width: 7,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        );
      }),
      titlesData: FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (value, meta) => value == 0
                ? const SizedBox.shrink()
                : Text(value.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (value, meta) {
              final d = value.toInt();
              return (d == 1 || d % 5 == 0)
                  ? Text('$d', style: Theme.of(context).textTheme.bodySmall)
                  : const SizedBox.shrink();
            },
          ),
        ),
      ),
    ));
  }
}

class _TrendLineChart extends StatelessWidget {
  final Map<String, double> totals;
  final ColorScheme scheme;

  const _TrendLineChart({required this.totals, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final months = totals.keys.toList();
    double maxV = 0;
    for (final v in totals.values) {
      if (v > maxV) maxV = v;
    }
    final spots = <FlSpot>[
      for (var i = 0; i < months.length; i++)
        FlSpot(i.toDouble(), totals[months[i]] ?? 0),
    ];
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxV == 0 ? 100 : maxV * 1.25,
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: scheme.primary,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData:
              BarAreaData(show: true, color: scheme.primary.withOpacity(0.12)),
        ),
      ],
      titlesData: FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (value, meta) => value == 0
                ? const SizedBox.shrink()
                : Text(value.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= months.length) return const SizedBox.shrink();
              return Text(shortMonth(DateTime.parse('${months[i]}-01')),
                  style: Theme.of(context).textTheme.bodySmall);
            },
          ),
        ),
      ),
    ));
  }
}

class _TopPayees extends StatelessWidget {
  final List<MapEntry<String, double>> payees;
  final String symbol;
  final ColorScheme scheme;

  const _TopPayees(
      {required this.payees, required this.symbol, required this.scheme});

  @override
  Widget build(BuildContext context) {
    if (payees.isEmpty) {
      return const Text('No payees this month.');
    }
    final max = payees.first.value;
    return Column(
      children: payees.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(e.key,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : e.value / max,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(formatMoney(e.value, symbol: symbol),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
