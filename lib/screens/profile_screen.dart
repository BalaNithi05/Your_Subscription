import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../login/login_screen.dart';
import 'edit_profile_screen.dart';
import '../main.dart';
import 'security_privacy_screen.dart';
import 'notification_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  String name = '';
  String email = '';
  String? avatarUrl;

  String plan = 'free';
  String? phone;
  String? bio;
  String? currency;
  String _themeMode = 'system';

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ================= LOAD PROFILE =================
  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    email = user.email ?? '';

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;

    final themeString = data?['theme_mode'] ?? 'system';
    themeNotifier.value = _mapToThemeMode(themeString);

    setState(() {
      name = data?['name'] ?? 'User';
      avatarUrl = data?['avatar_url'];
      plan = data?['plan'] ?? 'free';
      phone = data?['phone'];
      bio = data?['bio'];
      currency = data?['currency'];
      _themeMode = themeString;
      loading = false;
    });
  }

  // ================= UPDATE THEME =================
  Future<void> _updateTheme(String value) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('profiles')
        .update({'theme_mode': value})
        .eq('id', user.id);

    themeNotifier.value = _mapToThemeMode(value);

    setState(() {
      _themeMode = value;
    });
  }

  ThemeMode _mapToThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B1220)
          : const Color(0xFFF1F5F9),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ===== BACKGROUND GRADIENT =====
                Container(
                  height: 320,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

                // ===== CONTENT =====
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 80),

                          // ===== GLASS PROFILE CARD =====
                          _glassProfileCard(),

                          const SizedBox(height: 30),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                _infoCard(),
                                const SizedBox(height: 24),
                                _themeCard(),
                                const SizedBox(height: 24),
                                _settingsCard(),
                                const SizedBox(height: 30),
                                _logoutButton(),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // ================= GLASS PROFILE CARD =================
  Widget _glassProfileCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl!)
                          : null,
                      child: avatarUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.black,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                          if (updated == true) {
                            _loadProfile();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                _planBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _planBadge() {
    final isPro = plan == 'pro';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: isPro
            ? const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
              )
            : null,
        color: isPro ? null : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        plan.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isPro ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  // ================= INFO CARD =================
  Widget _infoCard() {
    return _cardContainer(
      Column(
        children: [
          if (bio != null && bio!.isNotEmpty)
            _infoRow(Icons.info_outline, bio!),
          if (phone != null && phone!.isNotEmpty)
            _infoRow(Icons.phone_outlined, phone!),
          if (currency != null)
            _infoRow(
              Icons.attach_money_outlined,
              'Default Currency: $currency',
            ),
        ],
      ),
    );
  }

  Widget _themeCard() {
    return _cardContainer(
      DropdownButtonFormField<String>(
        value: _themeMode,
        borderRadius: BorderRadius.circular(16),
        items: const [
          DropdownMenuItem(value: 'light', child: Text('Light')),
          DropdownMenuItem(value: 'dark', child: Text('Dark')),
          DropdownMenuItem(value: 'system', child: Text('System')),
        ],
        onChanged: (value) async {
          if (value != null) {
            await _updateTheme(value);
          }
        },
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.color_lens_outlined),
          labelText: 'Theme Mode',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _settingsCard() {
    return _cardContainer(
      Column(
        children: [
          _tile(Icons.lock_outline, 'Security & Privacy', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SecurityPrivacyScreen()),
            );
          }),
          const Divider(),
          _tile(Icons.notifications_none, 'Notifications', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDC2626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
        ),
        onPressed: () async {
          await _client.auth.signOut();
          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        },
        child: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  // ================= HELPERS =================
  Widget _cardContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.05)),
        ],
      ),
      child: child,
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF3B82F6)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
