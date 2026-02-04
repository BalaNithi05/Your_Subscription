import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // =========================
  // FETCH PROFILE
  // =========================
  Future<Profile?> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;

    return Profile.fromMap(data);
  }

  // =========================
  // UPDATE FULL PROFILE
  // =========================
  Future<void> updateProfile(Profile profile) async {
    await _client.from('profiles').update(profile.toMap()).eq('id', profile.id);
  }

  // =========================
  // UPDATE NAME + AVATAR (Backward compatible)
  // =========================
  Future<void> updateBasicProfile({
    required String userId,
    required String name,
    String? avatarUrl,
  }) async {
    await _client
        .from('profiles')
        .update({'name': name, if (avatarUrl != null) 'avatar_url': avatarUrl})
        .eq('id', userId);
  }

  // =========================
  // UPDATE CURRENCY
  // =========================
  Future<void> updateCurrency(String userId, String currency) async {
    await _client
        .from('profiles')
        .update({'currency': currency})
        .eq('id', userId);
  }

  // =========================
  // UPDATE THEME MODE
  // =========================
  Future<void> updateThemeMode(String userId, String themeMode) async {
    await _client
        .from('profiles')
        .update({'theme_mode': themeMode})
        .eq('id', userId);
  }

  // =========================
  // UPDATE FCM TOKEN
  // =========================
  Future<void> updateFcmToken(String userId, String token) async {
    await _client
        .from('profiles')
        .update({'fcm_token': token})
        .eq('id', userId);
  }

  // =========================
  // DELETE PROFILE
  // =========================
  Future<void> deleteProfile(String userId) async {
    await _client.from('profiles').delete().eq('id', userId);
  }
}
