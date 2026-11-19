import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/merchant.dart';
import '../domain/repositories/merchant_repository.dart';

sealed class MerchantsState extends Equatable {
  const MerchantsState();

  @override
  List<Object?> get props => const [];
}

final class MerchantsInitial extends MerchantsState {
  const MerchantsInitial();
}

final class MerchantsLoading extends MerchantsState {
  const MerchantsLoading();
}

final class MerchantsLoaded extends MerchantsState {
  const MerchantsLoaded(
    this.merchants,
    this.maxPerSession, {
    this.submission = const SubmissionIdle(),
    this.justCreated,
  });

  final List<Merchant> merchants;
  final int maxPerSession;
  final Submission submission;

  /// Credentials returned exactly once by a create or a reset.
  final MerchantCredentials? justCreated;

  MerchantsLoaded copyWith({
    List<Merchant>? merchants,
    int? maxPerSession,
    Submission? submission,
    MerchantCredentials? justCreated,
    bool clearCredentials = false,
  }) => MerchantsLoaded(
    merchants ?? this.merchants,
    maxPerSession ?? this.maxPerSession,
    submission: submission ?? this.submission,
    justCreated: clearCredentials ? null : (justCreated ?? this.justCreated),
  );

  @override
  List<Object?> get props => [
    merchants,
    maxPerSession,
    submission,
    justCreated,
  ];
}

final class MerchantsFailure extends MerchantsState {
  const MerchantsFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure.message, failure.code];
}

/// Admin list: CRUD, credentials, the per-vehicle policy and the desk helpers.
class MerchantsCubit extends ResilientCubit<MerchantsState> {
  MerchantsCubit(this._repository) : super(const MerchantsInitial());

  final MerchantRepository _repository;

  Future<void> load() async {
    emit(const MerchantsLoading());
    try {
      final results = await Future.wait<Object>([
        _repository.list(),
        _repository.loadPolicy(),
      ]);
      emit(
        MerchantsLoaded(
          results[0] as List<Merchant>,
          results[1] as int,
        ),
      );
    } on Failure catch (failure) {
      emit(MerchantsFailure(failure));
    }
  }

  Future<void> save(MerchantDraft draft) async {
    final current = state;
    if (current is! MerchantsLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final result = await _repository.save(draft);
      emit(
        current.copyWith(
          submission: SubmissionSucceeded<Merchant>(result.merchant),
          justCreated: result.credentials,
        ),
      );
      await _refresh();
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> resetCredentials(int merchantId, {bool rotateToken = false}) async {
    final current = state;
    if (current is! MerchantsLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final credentials = await _repository.resetCredentials(
        merchantId,
        rotateToken: rotateToken,
      );
      emit(
        current.copyWith(
          submission: SubmissionSucceeded<MerchantCredentials>(credentials),
          justCreated: credentials,
        ),
      );
      await _refresh();
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> delete(int merchantId) async {
    final current = state;
    if (current is! MerchantsLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      await _repository.delete(merchantId);
      emit(
        current.copyWith(
          submission: const SubmissionSucceeded<Object?>(null),
        ),
      );
      await _refresh();
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> savePolicy(int maxPerSession) async {
    final current = state;
    if (current is! MerchantsLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final value = await _repository.savePolicy(maxPerSession);
      emit(
        current.copyWith(
          maxPerSession: value,
          submission: SubmissionSucceeded<int>(value),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  void dismissCredentials() {
    final current = state;
    if (current is MerchantsLoaded) {
      emit(current.copyWith(clearCredentials: true));
    }
  }

  Future<void> _refresh() async {
    try {
      final merchants = await _repository.list();
      final latest = state;
      if (latest is MerchantsLoaded) {
        emit(latest.copyWith(merchants: merchants));
      }
    } on Failure {
      // Keep the list already on screen.
    }
  }
}
