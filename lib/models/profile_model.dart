class Profile {
  final String id;
  final String name;
  final String email;
  final String plan;
  final String? phone;
  final String? currency;
  final String? bio;
  final String? themeMode;
  final String? avatarUrl;
  final String? fcmToken;
  final DateTime? createdAt;

  Profile({
    required this.id,
    required this.name,
    required this.email,
    required this.plan,
    this.phone,
    this.currency,
    this.bio,
    this.themeMode,
    this.avatarUrl,
    this.fcmToken,
    this.createdAt,
  });

  // =========================
  // FROM MAP
  // =========================
  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      plan: map['plan'] ?? 'free',
      phone: map['phone'],
      currency: map['currency'],
      bio: map['bio'],
      themeMode: map['theme_mode'],
      avatarUrl: map['avatar_url'],
      fcmToken: map['fcm_token'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
    );
  }

  // =========================
  // TO MAP (for update)
  // =========================
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'plan': plan,
      'phone': phone,
      'currency': currency,
      'bio': bio,
      'theme_mode': themeMode,
      'avatar_url': avatarUrl,
      'fcm_token': fcmToken,
    };
  }

  // =========================
  // COPY WITH
  // =========================
  Profile copyWith({
    String? id,
    String? name,
    String? email,
    String? plan,
    String? phone,
    String? currency,
    String? bio,
    String? themeMode,
    String? avatarUrl,
    String? fcmToken,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      plan: plan ?? this.plan,
      phone: phone ?? this.phone,
      currency: currency ?? this.currency,
      bio: bio ?? this.bio,
      themeMode: themeMode ?? this.themeMode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
