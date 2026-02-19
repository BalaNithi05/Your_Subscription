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

  DateTime get _nextBillingDate {
    final start = widget.subscription.startDate;
    return widget.subscription.billingCycle == 'monthly'
        ? DateTime(start.year, start.month + 1, start.day)
        : DateTime(start.year + 1, start.month, start.day);
  }

  ImageProvider? _getBrandImage(String name) {
    final lower = name.toLowerCase();
    for (final entry in brandLogos.entries) {
      if (lower.contains(entry.key)) {
        return AssetImage(entry.value);
      }
    }
    return null;
  }

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

  Future<void> _deleteSubscription() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Subscription Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: accent),
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
        padding: const EdgeInsets.all(20),
        children: [
          // ================= HEADER CARD =================
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: accent.withOpacity(0.15), blurRadius: 30),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade200,
                  backgroundImage: sub.imageUrl != null
                      ? NetworkImage(sub.imageUrl!)
                      : brandImage,
                  child: sub.imageUrl == null && brandImage == null
                      ? Text(
                          sub.name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(sub.category, style: TextStyle(color: subTextColor)),
                      const SizedBox(height: 14),
                      Text(
                        '$_currencySymbol${sub.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        sub.billingCycle.toUpperCase(),
                        style: TextStyle(color: subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ================= BILLING CARD =================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Billing Information',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 18),
                _row(
                  'First Bill',
                  sub.startDate.toString().split(' ')[0],
                  subTextColor,
                  textColor,
                ),
                _row(
                  'Next Billing',
                  _paused
                      ? 'Paused'
                      : _nextBillingDate.toString().split(' ')[0],
                  _paused ? Colors.orange : accent,
                  textColor,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: bgColor,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent),
                  foregroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                label: Text(_paused ? 'Resume' : 'Pause'),
                onPressed: _togglePause,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                onPressed: _deleteSubscription,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color valueColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: labelColor.withOpacity(0.6))),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }
}
