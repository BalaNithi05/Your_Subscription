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

  int get activeCount => widget.subscriptions.where((s) => !s.isPaused).length;
  int get pausedCount => widget.subscriptions.where((s) => s.isPaused).length;

  List<DateTime> get lastMonths => _usecase.lastMonths(selectedMonths);

  Map<int, double> get monthlyTotals =>
      _usecase.monthlyTotals(widget.subscriptions, selectedMonths);

  double get currentMonthTotal => _usecase.currentMonthTotal(monthlyTotals);

  double get percentageChange => _usecase.percentageChange(monthlyTotals);

  double get maxY {
    if (monthlyTotals.isEmpty) return 100;

    final maxValue = monthlyTotals.values.fold(0.0, (a, b) => a > b ? a : b);
    final converted = CurrencyService.convert(maxValue);

    if (converted == 0) return 100;
    return converted * 1.4;
  }

  List<BarChartGroupData> get barGroups {
    final months = lastMonths;
    final currentMonth = DateTime.now().month;

    return List.generate(months.length, (i) {
      final monthNumber = months[i].month;
      final originalINR = monthlyTotals[monthNumber] ?? 0;
      final converted = CurrencyService.convert(originalINR);
      final isCurrent = monthNumber == currentMonth;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: converted,
            width: 22,
            borderRadius: BorderRadius.circular(8),
            gradient: isCurrent
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  )
                : LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.35),
                      const Color(0xFF6366F1).withOpacity(0.08),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final months = lastMonths;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      color: bgColor,
      child: ValueListenableBuilder(
        valueListenable: currencyNotifier,
        builder: (_, __, ___) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _summarySection(cardColor, textColor),
              const SizedBox(height: 28),
              _totalCard(),
              const SizedBox(height: 28),
              _chartSection(months, cardColor, textColor, isDark),
              const SizedBox(height: 28),
              _highestSpendSection(cardColor, textColor),
            ],
          );
        },
      ),
    );
  }

  // SUMMARY
  Widget _summarySection(Color cardColor, Color textColor) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            Icons.play_circle_fill,
            "Active",
            activeCount.toString(),
            const Color(0xFF22C55E),
            cardColor,
            textColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard(
            Icons.pause_circle_filled,
            "Paused",
            pausedCount.toString(),
            const Color(0xFFF59E0B),
            cardColor,
            textColor,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    IconData icon,
    String label,
    String value,
    Color color,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.08)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  // TOTAL CARD
  Widget _totalCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 82, 214, 208),
            Color.fromARGB(255, 137, 182, 237),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Month Spending',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyService.format(currentMonthTotal),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentageChange.toStringAsFixed(1)}% vs last month',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // CHART
  Widget _chartSection(
    List<DateTime> months,
    Color cardColor,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Spending Trends",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: textColor.withOpacity(0.15)),
                ),
                child: DropdownButton<int>(
                  value: selectedMonths,
                  dropdownColor: cardColor,
                  underline: const SizedBox(),
                  icon: Icon(Icons.keyboard_arrow_down, color: textColor),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),

                  items: const [
                    DropdownMenuItem(value: 3, child: Text("Last 3 Months")),
                    DropdownMenuItem(value: 6, child: Text("Last 6 Months")),
                    DropdownMenuItem(value: 12, child: Text("Last 12 Months")),
                  ],

                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedMonths = value;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: barGroups,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) =>
                        isDark ? Colors.white : Colors.black87,
                    getTooltipItem: (group, gi, rod, ri) {
                      final month = months[group.x.toInt()].month;
                      final value = monthlyTotals[month] ?? 0;
                      return BarTooltipItem(
                        CurrencyService.format(value),
                        TextStyle(
                          color: isDark ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index >= months.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            monthLabel(months[index]),
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // HIGHEST SPEND
  Widget _highestSpendSection(Color cardColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Highest Spend",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        ...highestSpend.map((sub) {
          final image = _getBrandImage(sub);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: image,
                  child: image == null ? Text(sub.name[0].toUpperCase()) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        sub.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyService.format(sub.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
