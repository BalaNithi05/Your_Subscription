import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _lockKey = 'app_lock_enabled';

  // 🔐 Authenticate user directly (NO pre-checks → NO crashes)
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to unlock the app',
      );
    } catch (e) {
      return false;
    }
  }

  // 💾 Enable / Disable app lock
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockKey, value);
  }

  // 📌 Check if app lock is enabled
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockKey) ?? false;
  }
}
