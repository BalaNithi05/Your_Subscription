import '../models/subscription_model.dart';
import '../utils/next_billing_date_helper.dart';
import '../utils/reminder_date_helper.dart';

class ReminderUsecase {
  // =====================================
  // 🔥 DEVELOPER TEST MODE
  // =====================================
  // true  → reminder in 30 seconds
  // false → real production billing logic
  static const bool developerTestMode = false;

  // =========================
  // VALIDATE REMINDER DAYS
  // =========================
  static bool validateReminderDays(int days) {
    return days >= 0 && days <= 7;
  }

  // =========================
  // CHECK IF TIME IS INSIDE QUIET HOURS
  // =========================
  static bool _isInsideQuietHours(
    DateTime date,
    DateTime quietStart,
    DateTime quietEnd,
  ) {
    final reminderMinutes = date.hour * 60 + date.minute;
    final startMinutes = quietStart.hour * 60 + quietStart.minute;
    final endMinutes = quietEnd.hour * 60 + quietEnd.minute;

    // 🌙 Cross midnight case (e.g., 22:00 → 07:00)
    if (startMinutes > endMinutes) {
      return reminderMinutes >= startMinutes || reminderMinutes < endMinutes;
    }

    // Normal case
    return reminderMinutes >= startMinutes && reminderMinutes < endMinutes;
  }

  // =========================
  // GET REMINDER DATE
  // =========================
  static DateTime? getReminderDate(
    Subscription sub, {
    DateTime? reminderTime,
    DateTime? quietStart,
    DateTime? quietEnd,
  }) {
    // ❌ Push disabled
    if (!sub.pushReminder) return null;

    // ❌ Paused subscription
    if (sub.isPaused) return null;

    final reminderDays = sub.reminderDays ?? 0;

    // ❌ Invalid reminder range
    if (!validateReminderDays(reminderDays)) return null;

    // =====================================
    // 🔥 DEVELOPER TEST MODE
    // =====================================
    if (developerTestMode) {
      return DateTime.now().add(const Duration(seconds: 30));
    }

    // =====================================
    // 🧠 REAL BILLING LOGIC
    // =====================================
    final nextBillingDate = NextBillingDateHelper.calculate(
      startDate: sub.startDate,
      billingCycle: sub.billingCycle,
    );

    DateTime reminderDate = ReminderDateHelper.calculate(
      billingDate: nextBillingDate,
      reminderDays: reminderDays,
    );

    // =========================
    // APPLY USER REMINDER TIME
    // =========================
    if (reminderTime != null) {
      reminderDate = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        reminderTime.hour,
        reminderTime.minute,
      );
    }

    // =========================
    // QUIET HOURS ADJUSTMENT
    // =========================
    if (quietStart != null && quietEnd != null) {
      if (_isInsideQuietHours(reminderDate, quietStart, quietEnd)) {
        reminderDate = DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          quietEnd.hour,
          quietEnd.minute,
        );
      }
    }

    // ❌ Final safety check (avoid scheduling past notifications)
    if (reminderDate.isBefore(DateTime.now())) {
      return null;
    }

    return reminderDate;
  }
}
