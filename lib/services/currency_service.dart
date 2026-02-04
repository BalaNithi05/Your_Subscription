import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart'; // currencyNotifier

class CurrencyService {
  static final SupabaseClient _client = Supabase.instance.client;

  static String _currencyCode = 'INR';
  static String _currencySymbol = '₹';

  static Map<String, dynamic> _rates = {};
  static DateTime? _lastFetched;

  static String get symbol => _currencySymbol;
  static String get code => _currencyCode;

  // ===============================
  // LOAD USER CURRENCY
  // ===============================
  static Future<void> loadUserCurrency() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = await _client
        .from('profiles')
        .select('currency')
        .eq('id', user.id)
        .maybeSingle();

    final dbCurrency = data?['currency'] ?? 'INR';

    _currencyCode = dbCurrency;
    _currencySymbol = _mapSymbol(dbCurrency);

    // 🔥 UPDATE GLOBAL NOTIFIER
    currencyNotifier.value = _currencySymbol;

    await _fetchRatesIfNeeded();
  }

  // ===============================
  // FETCH RATES (WITH CACHE)
  // ===============================
  static Future<void> _fetchRatesIfNeeded() async {
    if (_currencyCode == 'INR') return;

    if (_lastFetched != null &&
        DateTime.now().difference(_lastFetched!).inHours < 6) {
      return;
    }

    final apiKey = dotenv.env['EXCHANGE_API_KEY'];
    if (apiKey == null) return;

    final response = await http.get(
      Uri.parse('https://v6.exchangerate-api.com/v6/$apiKey/latest/INR'),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      _rates = json['conversion_rates'];
      _lastFetched = DateTime.now();
    }
  }

  // ===============================
  // CONVERT AMOUNT
  // ===============================
  static double convert(double amountInINR) {
    if (_currencyCode == 'INR') return amountInINR;

    final rate = _rates[_currencyCode];
    if (rate == null) return amountInINR;

    return amountInINR * rate;
  }

  // ===============================
  // FORMAT (ONLY PLACE TO CONVERT)
  // ===============================
  static String format(double amountInINR) {
    final converted = convert(amountInINR);
    return '$_currencySymbol${converted.toStringAsFixed(2)}';
  }

  // ===============================
  // SYMBOL MAP
  // ===============================
  static String _mapSymbol(String code) {
    switch (code) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '₹';
    }
  }
}
