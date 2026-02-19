import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../usecases/summary_notification_usecase.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final SupabaseService _service = SupabaseService();

  bool _notificationsEnabled = true;
  bool _dailySummaryEnabled = false;
  bool _weeklySummaryEnabled = false;

  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  bool _loading = true;
  bool _saving = false;

  String _currencySymbol = '₹';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = await _client
        .from('profiles')
        .select(
          'notifications_enabled, daily_summary_enabled, weekly_summary_enabled, reminder_time, quiet_start_time, quiet_end_time, currency',
        )
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;

    if (data != null) {
      _notificationsEnabled = data['notifications_enabled'] ?? true;
      _dailySummaryEnabled = data['daily_summary_enabled'] ?? false;
      _weeklySummaryEnabled = data['weekly_summary_enabled'] ?? false;
      _currencySymbol = data['currency'] ?? '₹';

      if (data['reminder_time'] != null) {
        _reminderTime = _parseTime(data['reminder_time']);
      }
      if (data['quiet_start_time'] != null) {
        _quietStart = _parseTime(data['quiet_start_time']);
      }
      if (data['quiet_end_time'] != null) {
        _quietEnd = _parseTime(data['quiet_end_time']);
      }
    }

    setState(() => _loading = false);
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  Future<void> _saveSettings() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    await _client
        .from('profiles')
        .update({
          'notifications_enabled': _notificationsEnabled,
          'daily_summary_enabled': _dailySummaryEnabled,
          'weekly_summary_enabled': _weeklySummaryEnabled,
          'reminder_time': _formatTime(_reminderTime),
          'quiet_start_time': _formatTime(_quietStart),
          'quiet_end_time': _formatTime(_quietEnd),
        })
        .eq('id', user.id);

    final subs = await _service.fetchSubscriptions();

    if (!_notificationsEnabled) {
      for (final sub in subs) {
        await NotificationService.cancel(sub.id.hashCode);
      }
      await NotificationService.cancel(999999);
      await NotificationService.cancel(888888);
    } else {
      for (final sub in subs) {
        await _service.updateSubscription(sub);
      }

      final summaryTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        _reminderTime.hour,
        _reminderTime.minute,
      );

      if (_dailySummaryEnabled) {
        await SummaryNotificationUsecase.scheduleDailySummary(
          subscriptions: subs,
          summaryTime: summaryTime,
          notificationsEnabled: _notificationsEnabled,
          currencySymbol: _currencySymbol,
        );
      }

      if (_weeklySummaryEnabled) {
        await SummaryNotificationUsecase.scheduleWeeklySummary(
          subscriptions: subs,
          summaryTime: summaryTime,
          notificationsEnabled: _notificationsEnabled,
          currencySymbol: _currencySymbol,
        );
      }
    }

    if (!mounted) return;

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification settings updated')),
    );
  }

  Future<void> _sendTestNotification() async {
    if (!_notificationsEnabled) return;

    await NotificationService.requestPermission();

    final scheduled = DateTime.now().add(const Duration(seconds: 5));

    await NotificationService.schedule(
      id: 9999,
      title: 'Test Notification',
      body: 'This is a test reminder 🔔',
      scheduledDate: scheduled,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test notification scheduled (5 sec)')),
    );
  }

  Future<void> _pickTime(
    TimeOfDay initial,
    Function(TimeOfDay) onSelected,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // ===== NEW PREMIUM BACKGROUND =====
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4C1D95), // Deep purple
                  Color(0xFF1E1B4B), // Indigo
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  "Notifications",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),

                _glassCard(
                  child: SwitchListTile(
                    value: _notificationsEnabled,
                    activeColor: Colors.cyanAccent,
                    title: const Text(
                      "Enable Notifications",
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      "Turn off all reminders & summaries",
                      style: TextStyle(color: Colors.white70),
                    ),
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                ),

                const SizedBox(height: 20),

                if (_notificationsEnabled) ...[
                  _glassCard(
                    child: Column(
                      children: [
                        _timeTile(
                          "Reminder Time",
                          _reminderTime.format(context),
                          () {
                            _pickTime(
                              _reminderTime,
                              (val) => _reminderTime = val,
                            );
                          },
                        ),
                        const Divider(color: Colors.white24),
                        _timeTile(
                          "Quiet Start",
                          _quietStart.format(context),
                          () {
                            _pickTime(_quietStart, (val) => _quietStart = val);
                          },
                        ),
                        const Divider(color: Colors.white24),
                        _timeTile("Quiet End", _quietEnd.format(context), () {
                          _pickTime(_quietEnd, (val) => _quietEnd = val);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _glassCard(
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _dailySummaryEnabled,
                          activeColor: Colors.cyanAccent,
                          title: const Text(
                            "Daily Summary",
                            style: TextStyle(color: Colors.white),
                          ),
                          onChanged: (v) =>
                              setState(() => _dailySummaryEnabled = v),
                        ),
                        SwitchListTile(
                          value: _weeklySummaryEnabled,
                          activeColor: Colors.cyanAccent,
                          title: const Text(
                            "Weekly Summary",
                            style: TextStyle(color: Colors.white),
                          ),
                          onChanged: (v) =>
                              setState(() => _weeklySummaryEnabled = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _saving ? null : _saveSettings,
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Save Settings"),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _sendTestNotification,
                    child: const Text("Send Test Notification"),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _timeTile(String title, String value, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Text(
        value,
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
