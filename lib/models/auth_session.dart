import 'user_profile.dart';

class AuthSession {
  const AuthSession({required this.user, required this.accessToken});

  final UserProfile user;
  final String accessToken;
}
