class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.darkMode,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool darkMode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    bool? darkMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      darkMode: darkMode ?? this.darkMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    darkMode: json['darkMode'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
  );
}
