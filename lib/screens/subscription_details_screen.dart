import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_model.dart';
import '../repositories/subscription_repository.dart';
import '../services/notification_service.dart';
import '../usecases/reminder_usecase.dart';
import '../utils/notification_id_helper.dart';
import 'add_subscription_screen.dart';

const Map<String, String> brandLogos = {
  'netflix': 'assets/brands/netflix.png',
  'spotify': 'assets/brands/spotify.png',
  'amazon': 'assets/brands/amazon.png',
  'prime': 'assets/brands/prime.png',
  'youtube': 'assets/brands/youtube.png',
  'disney': 'assets/brands/disney.png',
};

class SubscriptionDetailsScreen extends StatefulWidget {
  final Subscription subscription;

  const SubscriptionDetailsScreen({super.key, required this.subscription});

  @override
  State<SubscriptionDetailsScreen> createState() =>
      _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  final SubscriptionRepository _repository = SubscriptionRepository();
  final SupabaseClient _client = Supabase.instance.client;

  late bool _paused;
  String _currencySymbol = '₹';

  @override
  void initState() {
    super.initState();
    _paused = widget.subscription.isPaused;
    _loadCurrency();
  }

  // =========================
  // LOAD CURRENCY
  // =========================
  Future<void> _loadCurrency() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = await _client
        .from('profiles')
        .select('currency')
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;

    setState(() {
      _currencySymbol = data?['currency'] ?? '₹';
    });
  }

  // =========================
  // NEXT BILLING DATE
  // =========================
  DateTime get _nextBillingDate {
    final start = widget.subscription.startDate;
    return widget.subscription.billingCycle == 'monthly'
        ? DateTime(start.year, start.month + 1, start.day)
        : DateTime(start.year + 1, start.month, start.day);
  }

  // =========================
  // BRAND IMAGE (Fallback)
  // =========================
  ImageProvider? _getBrandImage(String name) {
    final lower = name.toLowerCase();
    for (final entry in brandLogos.entries) {
      if (lower.contains(entry.key)) {
        return AssetImage(entry.value);
      }
    }
    return null;
  }

  // =========================
  // PAUSE / RESUME
  // =========================
  Future<void> _togglePause() async {
    final newState = !_paused;
    final sub = widget.subscription;

    await _repository.pause(sub.id, newState);

    final notificationId = NotificationIdHelper.fromSubscription(sub);

    if (newState) {
      await NotificationService.cancel(notificationId);
    } else {
      final resumedSub = sub.copyWith(isPaused: false);

      final reminderDate = ReminderUsecase.getReminderDate(resumedSub);

      if (reminderDate != null) {
        await NotificationService.schedule(
          id: notificationId,
          title: 'Subscription Reminder',
          body: '${sub.name} billing is coming up',
          scheduledDate: reminderDate,
        );
      }
    }

    if (!mounted) return;
    setState(() => _paused = newState);
    Navigator.pop(context, true);
  }

  // =========================
  // DELETE
  // =========================
  Future<void> _deleteSubscription() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Text(
          'Are you sure you want to delete "${widget.subscription.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final notificationId = NotificationIdHelper.fromSubscription(
        widget.subscription,
      );

      await NotificationService.cancel(notificationId);
      await _repository.delete(widget.subscription.id);

      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;
    final brandImage = _getBrandImage(sub.name);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddSubscriptionScreen(subscription: sub),
                ),
              );
              if (updated == true && mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  backgroundImage: sub.imageUrl != null
                      ? NetworkImage(sub.imageUrl!)
                      : brandImage,
                  child: sub.imageUrl == null && brandImage == null
                      ? Text(
                          sub.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        sub.category,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_currencySymbol${sub.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        sub.billingCycle.toUpperCase(),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _section(
            title: 'Billing',
            children: [
              _row('First Bill', sub.startDate.toString().split(' ')[0]),
              _row(
                'Next Billing',
                _paused ? 'Paused' : _nextBillingDate.toString().split(' ')[0],
                valueColor: _paused ? Colors.orange : Colors.black,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                label: Text(_paused ? 'Resume' : 'Pause'),
                onPressed: _togglePause,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _deleteSubscription,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HELPERS =================

  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color valueColor = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }
}
