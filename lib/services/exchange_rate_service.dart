class ExchangeRateService {
  // Base currency = INR

  static const Map<String, double> _rates = {
    'INR': 1,
    'USD': 0.012,
    'EUR': 0.011,
    'GBP': 0.0095,
  };

  static double convertFromInr({
    required double amountInInr,
    required String targetCurrency,
  }) {
    final rate = _rates[targetCurrency.toUpperCase()] ?? 1;
    return amountInInr * rate;
  }
}
