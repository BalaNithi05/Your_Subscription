import '../models/subscription_model.dart';
import '../services/notification_service.dart';
import '../utils/next_billing_date_helper.dart';

class SummaryNotificationUsecase {
  static const int _dailySummaryId = 999999;
  static const int _weeklySummaryId = 888888;

  // 🔥 Developer Test Mode
  static const bool developerTestMode = false;

  // =========================
  // DAILY SUMMARY
  // =========================
  static Future<void> scheduleDailySummary({
    required List<Subscription> subscriptions,
    required DateTime summaryTime,
    required bool notificationsEnabled,
    required String currencySymbol,
  }) async {
    // ❌ Master switch OFF
    if (!notificationsEnabled) {
      await NotificationService.cancel(_dailySummaryId);
      return;
    }

    // =====================================
    // 🔥 DEV TEST MODE
    // =====================================
    if (developerTestMode) {
      await NotificationService.cancel(_dailySummaryId);

      await NotificationService.schedule(
        id: _dailySummaryId,
        title: '🧪 Daily Summary (Test)',
        body: 'Developer test daily summary',
        scheduledDate: DateTime.now().add(const Duration(seconds: 45)),
      );
      return;
    }

    // =====================================
    // 🧠 PRODUCTION LOGIC
    // =====================================
    final now = DateTime.now();

    // Safer tomorrow calculation
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    final dueTomorrow = subscriptions.where((sub) {
      if (sub.isPaused) return false;

      final nextBilling = NextBillingDateHelper.calculate(
        startDate: sub.startDate,
        billingCycle: sub.billingCycle,
      );

      return nextBilling.year == tomorrow.year &&
          nextBilling.month == tomorrow.month &&
          nextBilling.day == tomorrow.day;
    }).toList();

    if (dueTomorrow.isEmpty) {
      await NotificationService.cancel(_dailySummaryId);
      return;
    }

    final totalAmount = dueTomorrow.fold<double>(
      0,
      (sum, sub) => sum + sub.amount,
    );

    final scheduledDate = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      summaryTime.hour,
      summaryTime.minute,
    );

    // ❌ Safety check
    if (scheduledDate.isBefore(now)) {
      await NotificationService.cancel(_dailySummaryId);
      return;
    }

    await NotificationService.cancel(_dailySummaryId);

    await NotificationService.schedule(
      id: _dailySummaryId,
      title: 'Tomorrow’s Subscriptions',
      body:
          '${dueTomorrow.length} payments due • Total $currencySymbol${totalAmount.toStringAsFixed(2)}',
      scheduledDate: scheduledDate,
    );
  }

  // =========================
  // WEEKLY SUMMARY
  // =========================
  static Future<void> scheduleWeeklySummary({
    required List<Subscription> subscriptions,
    required DateTime summaryTime,
    required bool notificationsEnabled,
    required String currencySymbol,
  }) async {
    // ❌ Master switch OFF
    if (!notificationsEnabled) {
      await NotificationService.cancel(_weeklySummaryId);
      return;
    }

    // =====================================
    // 🔥 DEV TEST MODE
    // =====================================
    if (developerTestMode) {
      await NotificationService.cancel(_weeklySummaryId);

      await NotificationService.schedule(
        id: _weeklySummaryId,
        title: '🧪 Weekly Summary (Test)',
        body: 'Developer test weekly summary',
        scheduledDate: DateTime.now().add(const Duration(seconds: 60)),
      );
      return;
    }

    // =====================================
    // 🧠 PRODUCTION LOGIC
    // =====================================
    final now = DateTime.now();
    final weekLater = now.add(const Duration(days: 7));

    final dueThisWeek = subscriptions.where((sub) {
      if (sub.isPaused) return false;

      final nextBilling = NextBillingDateHelper.calculate(
        startDate: sub.startDate,
        billingCycle: sub.billingCycle,
      );

      return nextBilling.isAfter(now.subtract(const Duration(seconds: 1))) &&
          nextBilling.isBefore(weekLater);
    }).toList();

    if (dueThisWeek.isEmpty) {
      await NotificationService.cancel(_weeklySummaryId);
      return;
    }

    final totalAmount = dueThisWeek.fold<double>(
      0,
      (sum, sub) => sum + sub.amount,
    );

    // Always schedule for upcoming Sunday
    int daysUntilSunday = DateTime.sunday - now.weekday;
    if (daysUntilSunday <= 0) {
      daysUntilSunday += 7;
    }

    final nextSunday = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysUntilSunday));

    final scheduledDate = DateTime(
      nextSunday.year,
      nextSunday.month,
      nextSunday.day,
      summaryTime.hour,
      summaryTime.minute,
    );

    // ❌ Safety check
    if (scheduledDate.isBefore(now)) {
      await NotificationService.cancel(_weeklySummaryId);
      return;
    }

    await NotificationService.cancel(_weeklySummaryId);

    await NotificationService.schedule(
      id: _weeklySummaryId,
      title: 'This Week’s Subscriptions',
      body:
          '${dueThisWeek.length} payments coming • Total $currencySymbol${totalAmount.toStringAsFixed(2)}',
      scheduledDate: scheduledDate,
    );
  }
}
