import 'package:equatable/equatable.dart';

import 'user.dart';

class AuthSession extends Equatable {
  const AuthSession({required this.user, required this.token});

  final User user;
  final String token;

  @override
  List<Object?> get props => [user, token];
}
