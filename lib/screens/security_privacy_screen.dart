import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../login/login_screen.dart';
import '../services/app_lock_service.dart';

class SecurityPrivacyScreen extends StatefulWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  State<SecurityPrivacyScreen> createState() => _SecurityPrivacyScreenState();
}

class _SecurityPrivacyScreenState extends State<SecurityPrivacyScreen> {
  bool _appLockEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppLockStatus();
  }

  Future<void> _loadAppLockStatus() async {
    final enabled = await AppLockService.isEnabled();
    if (!mounted) return;
    setState(() {
      _appLockEnabled = enabled;
      _loading = false;
    });
  }

  // ================= DELETE ACCOUNT =================
  Future<void> _deleteAccount(BuildContext context) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.from('profiles').delete().eq('id', user.id);
      await client.from('subscriptions').delete().eq('user_id', user.id);
      await client.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  // ================= TOGGLE APP LOCK =================
  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      // 🔐 ENABLE → biometric required
      final success = await AppLockService.authenticate();
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication failed')),
        );
        return;
      }
    }

    await AppLockService.setEnabled(value);

    if (!mounted) return;
    setState(() {
      _appLockEnabled = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'App Lock enabled' : 'App Lock disabled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Privacy'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Account Security'),

          // 🔐 APP LOCK SWITCH
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
              ],
            ),
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint, color: Colors.blue),
              title: const Text('App Lock'),
              subtitle: const Text('Use fingerprint or face lock'),
              value: _appLockEnabled,
              onChanged: _toggleAppLock,
            ),
          ),

          const SizedBox(height: 24),
          _sectionTitle('Danger Zone'),

          _dangerTile(
            context,
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _dangerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.red),
        title: Text(title, style: const TextStyle(color: Colors.red)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent. All your subscriptions and data will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
