import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_model.dart';
import '../services/notification_service.dart';
import '../usecases/reminder_usecase.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  // =========================
  // 🔔 SCHEDULE / CANCEL PUSH REMINDER
  // =========================
  Future<void> _scheduleReminder(Subscription sub) async {
    final notificationId = sub.id.hashCode;

    final profile = await _client
        .from('profiles')
        .select('''
          notifications_enabled,
          daily_summary_enabled,
          weekly_summary_enabled,
          reminder_time,
          quiet_start_time,
          quiet_end_time
          ''')
        .eq('id', _userId)
        .maybeSingle();

    // ❌ No profile → cancel
    if (profile == null) {
      await NotificationService.cancel(notificationId);
      return;
    }

    // ❌ Master OFF → cancel
    if (profile['notifications_enabled'] == false) {
      await NotificationService.cancel(notificationId);
      return;
    }

    // 🔥 SMART OVERRIDE (Summary replaces individual reminders)
    if (profile['daily_summary_enabled'] == true ||
        profile['weekly_summary_enabled'] == true) {
      await NotificationService.cancel(notificationId);
      return;
    }

    DateTime? reminderTime;
    DateTime? quietStart;
    DateTime? quietEnd;

    // Parse reminder_time
    if (profile['reminder_time'] != null) {
      final parts = profile['reminder_time'].toString().split(':');
      reminderTime = DateTime(
        0,
        1,
        1,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    // Parse quiet_start_time
    if (profile['quiet_start_time'] != null) {
      final parts = profile['quiet_start_time'].toString().split(':');
      quietStart = DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    }

    // Parse quiet_end_time
    if (profile['quiet_end_time'] != null) {
      final parts = profile['quiet_end_time'].toString().split(':');
      quietEnd = DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    }

    final reminderDate = ReminderUsecase.getReminderDate(
      sub,
      reminderTime: reminderTime,
      quietStart: quietStart,
      quietEnd: quietEnd,
    );

    if (reminderDate == null) {
      await NotificationService.cancel(notificationId);
      return;
    }

    await NotificationService.schedule(
      id: notificationId,
      title: 'Subscription Reminder',
      body: '${sub.name} bill is coming up',
      scheduledDate: reminderDate,
    );
  }

  // =========================
  // ADD SUBSCRIPTION
  // =========================
  Future<void> addSubscription(Subscription sub) async {
    final response = await _client
        .from('subscriptions')
        .insert({
          'user_id': _userId,
          'name': sub.name,
          'amount': sub.amount,
          'cycle': sub.billingCycle,
          'category': sub.category,
          'first_bill_date': sub.startDate.toIso8601String(),
          'reminder_enabled': sub.pushReminder,
          'reminder_days': sub.reminderDays,
          'is_paused': sub.isPaused,
          'notes': sub.notes,
          'image_url': sub.imageUrl,
        })
        .select()
        .single();

    final createdSub = Subscription.fromMap(response);
    await _scheduleReminder(createdSub);
  }

  // =========================
  // FETCH SUBSCRIPTIONS
  // =========================
  Future<List<Subscription>> fetchSubscriptions() async {
    final data = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => Subscription.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // =========================
  // UPDATE SUBSCRIPTION
  // =========================
  Future<void> updateSubscription(Subscription sub) async {
    await _client
        .from('subscriptions')
        .update({
          'name': sub.name,
          'amount': sub.amount,
          'cycle': sub.billingCycle,
          'category': sub.category,
          'first_bill_date': sub.startDate.toIso8601String(),
          'reminder_enabled': sub.pushReminder,
          'reminder_days': sub.reminderDays,
          'is_paused': sub.isPaused,
          'notes': sub.notes,
          'image_url': sub.imageUrl,
        })
        .eq('id', sub.id)
        .eq('user_id', _userId);

    await _scheduleReminder(sub);
  }

  // =========================
  // ⏸️ PAUSE / RESUME
  // =========================
  Future<void> setPause(String id, bool pause) async {
    await _client
        .from('subscriptions')
        .update({'is_paused': pause})
        .eq('id', id)
        .eq('user_id', _userId);

    final data = await _client
        .from('subscriptions')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data != null) {
      final sub = Subscription.fromMap(data);
      await _scheduleReminder(sub);
    }
  }

  // =========================
  // DELETE SUBSCRIPTION
  // =========================
  Future<void> deleteSubscription(String id) async {
    await _client
        .from('subscriptions')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);

    await NotificationService.cancel(id.hashCode);
  }

  // =========================
  // COUNT
  // =========================
  Future<int> subscriptionCount() async {
    final data = await _client
        .from('subscriptions')
        .select('id')
        .eq('user_id', _userId);

    return data.length;
  }

  // =========================
  // CATEGORY FEATURES
  // =========================
  Future<List<String>> fetchCategories() async {
    final data = await _client
        .from('categories')
        .select('name')
        .eq('user_id', _userId)
        .order('name');

    return (data as List).map((e) => e['name'] as String).toList();
  }

  Future<void> addCategory(String name) async {
    final existing = await _client
        .from('categories')
        .select('id')
        .eq('user_id', _userId)
        .eq('name', name)
        .maybeSingle();

    if (existing != null) return;

    await _client.from('categories').insert({'user_id': _userId, 'name': name});
  }
}
