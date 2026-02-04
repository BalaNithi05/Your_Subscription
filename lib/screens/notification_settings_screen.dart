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

  // =========================
  // LOAD SETTINGS
  // =========================
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

  // =========================
  // SAVE SETTINGS
  // =========================
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

    // =============================
    // MASTER SWITCH OFF
    // =============================
    if (!_notificationsEnabled) {
      for (final sub in subs) {
        await NotificationService.cancel(sub.id.hashCode);
      }

      await NotificationService.cancel(999999);
      await NotificationService.cancel(888888);
    }
    // =============================
    // MASTER SWITCH ON
    // =============================
    else {
      for (final sub in subs) {
        await _service.updateSubscription(sub);
      }

      await NotificationService.cancel(999999);
      await NotificationService.cancel(888888);

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

  // =========================
  // TEST NOTIFICATION
  // =========================
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
      appBar: AppBar(title: const Text('Notification Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text('Turn off all reminders & summaries'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
              },
            ),

            const SizedBox(height: 20),

            if (_notificationsEnabled) ...[
              _timeTile(
                icon: Icons.access_time,
                title: 'Reminder Time',
                value: _reminderTime.format(context),
                onTap: () =>
                    _pickTime(_reminderTime, (val) => _reminderTime = val),
              ),
              const SizedBox(height: 16),
              _timeTile(
                icon: Icons.nightlight_round,
                title: 'Quiet Start Time',
                value: _quietStart.format(context),
                onTap: () => _pickTime(_quietStart, (val) => _quietStart = val),
              ),
              const SizedBox(height: 16),
              _timeTile(
                icon: Icons.wb_sunny_outlined,
                title: 'Quiet End Time',
                value: _quietEnd.format(context),
                onTap: () => _pickTime(_quietEnd, (val) => _quietEnd = val),
              ),
              const SizedBox(height: 20),

              SwitchListTile(
                title: const Text('Daily Summary'),
                value: _dailySummaryEnabled,
                onChanged: (v) => setState(() => _dailySummaryEnabled = v),
              ),

              SwitchListTile(
                title: const Text('Weekly Summary'),
                value: _weeklySummaryEnabled,
                onChanged: (v) => setState(() => _weeklySummaryEnabled = v),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _saving ? null : _saveSettings,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Settings'),
              ),

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: _sendTestNotification,
                child: const Text('Send Test Notification'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      trailing: Text(value),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: Theme.of(context).cardColor,
    );
  }
}
