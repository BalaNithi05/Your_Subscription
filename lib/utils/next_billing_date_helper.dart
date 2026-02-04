class NextBillingDateHelper {
  /// 📅 Calculate next billing date
  ///
  /// startDate = first bill date
  /// billingCycle = 'monthly' or 'yearly'
  static DateTime calculate({
    required DateTime startDate,
    required String billingCycle,
  }) {
    final now = DateTime.now();

    if (billingCycle == 'yearly') {
      var next = DateTime(startDate.year, startDate.month, startDate.day);

      while (!next.isAfter(now)) {
        next = DateTime(next.year + 1, next.month, next.day);
      }
      return next;
    }

    // default = monthly
    var next = DateTime(startDate.year, startDate.month, startDate.day);

    while (!next.isAfter(now)) {
      next = DateTime(next.year, next.month + 1, next.day);
    }

    return next;
  }
}
