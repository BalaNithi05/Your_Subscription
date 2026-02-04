import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class ThemeService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<void> loadUserTheme() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = await _client
        .from('profiles')
        .select('theme_mode')
        .eq('id', user.id)
        .maybeSingle();

    final themeString = data?['theme_mode'] ?? 'system';

    themeNotifier.value = _mapToThemeMode(themeString);
  }

  static Future<void> updateTheme(String themeString) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('profiles')
        .update({'theme_mode': themeString})
        .eq('id', user.id);

    themeNotifier.value = _mapToThemeMode(themeString);
  }

  static ThemeMode _mapToThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
