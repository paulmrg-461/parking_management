import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure([this.message = '']);

  final String message;

  @override
  List<Object?> get props => [message];
}

class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Storage operation failed']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network operation failed']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation failed']);
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure([super.message = 'Authentication failed']);
}
