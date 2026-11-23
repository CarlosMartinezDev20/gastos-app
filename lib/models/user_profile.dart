class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.darkMode,
    this.themeMode = 'LIGHT',
    this.accent = 'LIME',
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool darkMode;

  /// `LIGHT`, `DARK` or `SYSTEM` (API `User.themeMode`).
  final String themeMode;

  /// The accent's API value (`LIME`, `MINT`, `SKY`, `VIOLET`, `AMBER`).
  final String accent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    bool? darkMode,
    String? themeMode,
    String? accent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      darkMode: darkMode ?? this.darkMode,
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final darkMode = json['darkMode'] as bool? ?? false;
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      darkMode: darkMode,
      // An API without themeMode (older deploy) only knows darkMode.
      themeMode: json['themeMode'] as String? ?? (darkMode ? 'DARK' : 'LIGHT'),
      accent: json['accent'] as String? ?? 'LIME',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}
