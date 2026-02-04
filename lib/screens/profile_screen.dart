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

  // =========================
  // LOAD PROFILE
  // =========================
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

    // Apply theme globally
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

  // =========================
  // UPDATE THEME
  // =========================
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
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ================= PREMIUM HEADER =================
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),

                          // AVATAR
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
                                        size: 45,
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
                                        builder: (_) =>
                                            const EditProfileScreen(),
                                      ),
                                    );
                                    if (updated == true) {
                                      _loadProfile();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
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

                          const SizedBox(height: 12),

                          // NAME
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          // EMAIL
                          Text(
                            email,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // PLAN BADGE
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: plan == 'pro'
                                  ? Colors.green
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              plan.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: plan == 'pro'
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ================= BODY =================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _infoCard(),
                        const SizedBox(height: 20),

                        // ================= THEME MODE =================
                        _settingsCard(
                          DropdownButtonFormField<String>(
                            value: _themeMode,
                            items: const [
                              DropdownMenuItem(
                                value: 'light',
                                child: Text('Light'),
                              ),
                              DropdownMenuItem(
                                value: 'dark',
                                child: Text('Dark'),
                              ),
                              DropdownMenuItem(
                                value: 'system',
                                child: Text('System'),
                              ),
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
                        ),

                        const SizedBox(height: 20),

                        // ================= SETTINGS =================
                        _settingsCard(
                          Column(
                            children: [
                              _tile(
                                Icons.lock_outline,
                                'Security & Privacy',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SecurityPrivacyScreen(),
                                    ),
                                  );
                                },
                              ),
                              const Divider(),
                              _tile(
                                Icons.notifications_none,
                                'Notifications',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const NotificationSettingsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // ================= LOGOUT =================
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            await _client.auth.signOut();
                            if (!mounted) return;

                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                              (_) => false,
                            );
                          },
                          child: const Text(
                            'Logout',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ================= INFO CARD =================
  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.05)),
        ],
      ),
      child: Column(
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

  Widget _settingsCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.05)),
        ],
      ),
      child: child,
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
