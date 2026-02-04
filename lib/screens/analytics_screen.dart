import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/subscription_model.dart';
import '../usecases/analytics_usecase.dart';
import '../services/currency_service.dart';
import '../main.dart';

const Map<String, String> brandLogos = {
  'netflix': 'assets/brands/netflix.png',
  'spotify': 'assets/brands/spotify.png',
  'amazon': 'assets/brands/amazon.png',
  'prime': 'assets/brands/prime.png',
  'youtube': 'assets/brands/youtube.png',
  'disney': 'assets/brands/disney.png',
};

class AnalyticsScreen extends StatefulWidget {
  final List<Subscription> subscriptions;

  const AnalyticsScreen({super.key, required this.subscriptions});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int selectedMonths = 6;
  final AnalyticsUsecase _usecase = AnalyticsUsecase();

  // ================= ACTIVE & PAUSED =================
  int get activeCount => widget.subscriptions.where((s) => !s.isPaused).length;

  int get pausedCount => widget.subscriptions.where((s) => s.isPaused).length;

  // ================= MONTH LOGIC (INR ONLY) =================
  List<DateTime> get lastMonths => _usecase.lastMonths(selectedMonths);

  Map<int, double> get monthlyTotals =>
      _usecase.monthlyTotals(widget.subscriptions, selectedMonths);

  double get currentMonthTotal => _usecase.currentMonthTotal(monthlyTotals);

  double get percentageChange => _usecase.percentageChange(monthlyTotals);

  // ================= CHART MAX =================
  double get maxY {
    if (monthlyTotals.values.isEmpty) return 100;

    final maxInINR = monthlyTotals.values.reduce((a, b) => a > b ? a : b);

    final converted = CurrencyService.convert(maxInINR);

    return converted + 50;
  }

  // ================= BAR GROUPS =================
  List<BarChartGroupData> get barGroups {
    final months = lastMonths;
    final currentMonth = DateTime.now().month;

    return List.generate(months.length, (i) {
      final originalINR = monthlyTotals[months[i].month] ?? 0;

      final converted = CurrencyService.convert(originalINR);

      final isCurrent = months[i].month == currentMonth;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: converted,
            width: 18,
            borderRadius: BorderRadius.circular(8),
            color: isCurrent ? Colors.blue : Colors.blue.withOpacity(0.3),
          ),
        ],
      );
    });
  }

  String monthLabel(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[date.month - 1];
  }

  // ================= BRAND IMAGE =================
  ImageProvider? _getBrandImage(Subscription sub) {
    if (sub.imageUrl != null && sub.imageUrl!.isNotEmpty) {
      return NetworkImage(sub.imageUrl!);
    }

    final text = sub.name.toLowerCase();

    for (final entry in brandLogos.entries) {
      if (text.contains(entry.key)) {
        return AssetImage(entry.value);
      }
    }

    return null;
  }

  List<Subscription> get highestSpend =>
      _usecase.highestSpend(widget.subscriptions);

  @override
  Widget build(BuildContext context) {
    final months = lastMonths;

    return ValueListenableBuilder(
      valueListenable: currencyNotifier,
      builder: (_, __, ___) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ================= ACTIVE / PAUSED =================
            Row(
              children: [
                Expanded(
                  child: _summaryBox(
                    icon: Icons.play_circle_fill,
                    color: Colors.green,
                    count: activeCount,
                    label: "Active",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryBox(
                    icon: Icons.pause_circle_filled,
                    color: Colors.orange,
                    count: pausedCount,
                    label: "Paused",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ================= TOTAL CARD =================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Monthly Spending',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyService.format(currentMonthTotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${percentageChange.toStringAsFixed(1)}% vs last month',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ================= HEADER =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Spending Trends',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                DropdownButton<int>(
                  value: selectedMonths,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('Last 3 Months')),
                    DropdownMenuItem(value: 6, child: Text('Last 6 Months')),
                    DropdownMenuItem(value: 12, child: Text('Last 12 Months')),
                  ],
                  onChanged: (v) => setState(() => selectedMonths = v!),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ================= BAR CHART =================
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barGroups: barGroups,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(monthLabel(months[value.toInt()])),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ================= HIGHEST SPEND =================
            const Text(
              'Highest Spend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...highestSpend.map((sub) {
              final image = _getBrandImage(sub);

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: image,
                    child: image == null
                        ? Text(sub.name[0].toUpperCase())
                        : null,
                  ),
                  title: Text(sub.name),
                  subtitle: Text(sub.category),
                  trailing: Text(
                    CurrencyService.format(sub.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _summaryBox({
    required IconData icon,
    required Color color,
    required int count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
