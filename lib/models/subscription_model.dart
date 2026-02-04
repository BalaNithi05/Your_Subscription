class Subscription {
  final String id;
  final String name;
  final double amount;
  final String billingCycle;
  final String category;
  final DateTime startDate;

  final bool pushReminder;
  final int? reminderDays;

  final bool isPaused;

  final String? notes;
  final DateTime createdAt;

  // ✅ NEW
  final String? imageUrl;

  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.billingCycle,
    required this.category,
    required this.startDate,
    required this.pushReminder,
    this.reminderDays,
    required this.isPaused,
    this.notes,
    required this.createdAt,
    this.imageUrl, // ✅ NEW
  });

  Subscription copyWith({
    String? id,
    String? name,
    double? amount,
    String? billingCycle,
    String? category,
    DateTime? startDate,
    bool? pushReminder,
    int? reminderDays,
    bool? isPaused,
    String? notes,
    DateTime? createdAt,
    String? imageUrl, // ✅ NEW
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      billingCycle: billingCycle ?? this.billingCycle,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      pushReminder: pushReminder ?? this.pushReminder,
      reminderDays: reminderDays ?? this.reminderDays,
      isPaused: isPaused ?? this.isPaused,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl, // ✅ NEW
    );
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    DateTime safeStartDate;

    try {
      final rawDate = map['first_bill_date'] ?? map['start_date'];
      safeStartDate = rawDate != null
          ? DateTime.parse(rawDate)
          : DateTime.now();
    } catch (_) {
      safeStartDate = DateTime.now();
    }

    return Subscription(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      billingCycle: map['cycle'] ?? 'monthly',
      category: map['category'] ?? 'General',
      startDate: safeStartDate,
      pushReminder: map['reminder_enabled'] ?? false,
      reminderDays: map['reminder_days'],
      isPaused: map['is_paused'] ?? false,
      notes: map['notes'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : DateTime.now(),
      imageUrl: map['image_url'], // ✅ NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'cycle': billingCycle,
      'category': category,
      'first_bill_date': startDate.toIso8601String(),
      'reminder_enabled': pushReminder,
      'reminder_days': reminderDays,
      'is_paused': isPaused,
      'notes': notes,
      'image_url': imageUrl, // ✅ NEW
    };
  }
}
