import '../models/subscription_model.dart';

class AnalyticsUsecase {
  // =========================
  // LAST N MONTHS
  // =========================
  List<DateTime> lastMonths(int count) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      return DateTime(now.year, now.month - (count - 1 - i), 1);
    });
  }

  // =========================
  // MONTHLY TOTALS
  // =========================
  Map<int, double> monthlyTotals(List<Subscription> subscriptions, int months) {
    final Map<int, double> totals = {};
    final monthList = lastMonths(months);

    for (final month in monthList) {
      double total = 0;

      for (final sub in subscriptions) {
        if (sub.isPaused) continue;
        if (sub.startDate.isAfter(month)) continue;

        final monthlyAmount = sub.billingCycle == 'yearly'
            ? sub.amount / 12
            : sub.amount;

        total += monthlyAmount;
      }

      totals[month.month] = total;
    }

    return totals;
  }

  // =========================
  // CURRENT MONTH TOTAL
  // =========================
  double currentMonthTotal(Map<int, double> monthlyTotals) {
    final now = DateTime.now();
    return monthlyTotals[now.month] ?? 0;
  }

  // =========================
  // PERCENTAGE CHANGE
  // =========================
  double percentageChange(Map<int, double> monthlyTotals) {
    final now = DateTime.now();
    final current = monthlyTotals[now.month] ?? 0;
    final prev = monthlyTotals[now.month - 1] ?? 0;

    if (prev == 0) return 0;
    return ((current - prev) / prev) * 100;
  }

  // =========================
  // HIGHEST SPEND
  // =========================
  List<Subscription> highestSpend(List<Subscription> subscriptions) {
    final list = [...subscriptions];
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list.take(3).toList();
  }
}
