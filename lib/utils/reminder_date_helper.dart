class ReminderDateHelper {
  /// 📅 Calculate next reminder date
  ///
  /// billingDate = next billing date
  /// reminderDays = days before billing (0 = same day)
  static DateTime calculate({
    required DateTime billingDate,
    required int reminderDays,
  }) {
    return billingDate.subtract(Duration(days: reminderDays));
  }
}
