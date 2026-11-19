import 'package:equatable/equatable.dart';

import 'merchant_portal.dart';

/// Outcome of `merchant_validate`. A wrong PIN and a lock are answers, not
/// errors (the server must commit the attempt counter).
sealed class MerchantValidationResult extends Equatable {
  const MerchantValidationResult();

  @override
  List<Object?> get props => const [];
}

final class ValidationRegistered extends MerchantValidationResult {
  const ValidationRegistered(this.summary);

  final MerchantPortal summary;

  @override
  List<Object?> get props => [summary];
}

final class ValidationInvalidPin extends MerchantValidationResult {
  const ValidationInvalidPin(this.attemptsLeft);

  final int attemptsLeft;

  @override
  List<Object?> get props => [attemptsLeft];
}

final class ValidationLocked extends MerchantValidationResult {
  const ValidationLocked(this.until);

  final DateTime until;

  @override
  List<Object?> get props => [until];
}
