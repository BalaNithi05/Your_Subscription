import '../models/subscription_model.dart';

class AnalyticsUsecase {
  // =========================================================
  // LAST N MONTHS (YEAR SAFE)
  // ex: Dec 2025, Jan 2026, Feb 2026
  // =========================================================
  List<DateTime> lastMonths(int count) {
    final now = DateTime.now();

    return List.generate(count, (i) {
      return DateTime(now.year, now.month - (count - 1 - i), 1);
    });
  }

  // =========================================================
  // CHECK IF SUBSCRIPTION BILL HAPPENS IN GIVEN MONTH
  // =========================================================
  bool _occursInMonth(Subscription sub, DateTime month) {
    if (sub.isPaused) return false;

    final start = sub.startDate;
    final year = month.year;
    final m = month.month;

    // Month end date
    final monthEnd = DateTime(year, m + 1, 0);

    // If subscription not started yet
    if (monthEnd.isBefore(start)) return false;

    // ---------------- MONTHLY ----------------
    if (sub.billingCycle == 'monthly') {
      final billDate = DateTime(year, m, start.day);

      if (billDate.isBefore(start)) return false;
      return true;
    }

    // ---------------- YEARLY ----------------
    if (sub.billingCycle == 'yearly') {
      if (start.month != m) return false;

      final billDate = DateTime(year, m, start.day);
      if (billDate.isBefore(start)) return false;

      return true;
    }

    return false;
  }

  // =========================================================
  // MONTHLY TOTALS (REAL BILLING HISTORY)
  // =========================================================
  Map<int, double> monthlyTotals(List<Subscription> subs, int months) {
    final Map<int, double> totals = {};
    final monthList = lastMonths(months);

    for (final month in monthList) {
      double total = 0;

      for (final sub in subs) {
        if (!_occursInMonth(sub, month)) continue;

        total += sub.amount;
      }

      totals[month.month] = total;
    }

    return totals;
  }

  // =========================================================
  // CURRENT MONTH TOTAL
  // =========================================================
  double currentMonthTotal(Map<int, double> totals) {
    final now = DateTime.now();
    return totals[now.month] ?? 0;
  }

  // =========================================================
  // PERCENTAGE CHANGE (YEAR SAFE)
  // =========================================================
  double percentageChange(Map<int, double> totals) {
    final now = DateTime.now();

    int prevMonth = now.month - 1;
    if (prevMonth == 0) prevMonth = 12;

    final current = totals[now.month] ?? 0;
    final prev = totals[prevMonth] ?? 0;

    if (prev == 0 && current == 0) return 0;
    if (prev == 0) return 100;

    return ((current - prev) / prev) * 100;
  }

  // =========================================================
  // HIGHEST SPEND (ONLY ACTIVE)
  // =========================================================
  List<Subscription> highestSpend(List<Subscription> subscriptions) {
    final list = subscriptions.where((s) => !s.isPaused).toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list.take(3).toList();
  }
}
