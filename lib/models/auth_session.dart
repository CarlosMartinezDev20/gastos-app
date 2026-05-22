import 'user_profile.dart';

class AuthSession {
  const AuthSession({required this.user, required this.accessToken});

  final UserProfile user;
  final String accessToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    accessToken: json['accessToken'] as String,
  );
}
