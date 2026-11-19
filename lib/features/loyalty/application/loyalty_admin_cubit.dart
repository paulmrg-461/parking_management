import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/loyalty_account.dart';
import '../domain/entities/loyalty_report.dart';
import '../domain/entities/loyalty_settings.dart';
import '../domain/repositories/loyalty_repository.dart';

sealed class LoyaltyAdminState extends Equatable {
  const LoyaltyAdminState();

  @override
  List<Object?> get props => const [];
}

final class LoyaltyAdminInitial extends LoyaltyAdminState {
  const LoyaltyAdminInitial();
}

final class LoyaltyAdminLoading extends LoyaltyAdminState {
  const LoyaltyAdminLoading();
}

final class LoyaltyAdminLoaded extends LoyaltyAdminState {
  const LoyaltyAdminLoaded(
    this.settings,
    this.accounts, {
    this.report,
    this.submission = const SubmissionIdle(),
  });

  final LoyaltySettings settings;
  final List<LoyaltyAccount> accounts;
  final LoyaltyReport? report;
  final Submission submission;

  LoyaltyAdminLoaded copyWith({
    LoyaltySettings? settings,
    List<LoyaltyAccount>? accounts,
    LoyaltyReport? report,
    Submission? submission,
  }) => LoyaltyAdminLoaded(
    settings ?? this.settings,
    accounts ?? this.accounts,
    report: report ?? this.report,
    submission: submission ?? this.submission,
  );

  @override
  List<Object?> get props => [settings, accounts, report, submission];
}

final class LoyaltyAdminFailure extends LoyaltyAdminState {
  const LoyaltyAdminFailure(this.message, {this.failure});

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

/// Admin screen: program settings, members and the impact report.
class LoyaltyAdminCubit extends ResilientCubit<LoyaltyAdminState> {
  LoyaltyAdminCubit(this._repository) : super(const LoyaltyAdminInitial());

  final LoyaltyRepository _repository;
  String? _search;

  Future<void> load() async {
    emit(const LoyaltyAdminLoading());
    try {
      final settings = await _repository.loadSettings();
      final accounts = await _repository.accounts(search: _search);
      emit(LoyaltyAdminLoaded(settings, accounts));
    } on Failure catch (failure) {
      emit(LoyaltyAdminFailure(failure.message, failure: failure));
    }
  }

  Future<void> save(LoyaltySettings settings) async {
    final current = state;
    if (current is! LoyaltyAdminLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final saved = await _repository.saveSettings(settings);
      emit(
        current.copyWith(
          settings: saved,
          submission: SubmissionSucceeded<LoyaltySettings>(saved),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> search(String value) async {
    final current = state;
    if (current is! LoyaltyAdminLoaded) {
      return;
    }
    _search = value.trim().isEmpty ? null : value.trim();
    try {
      final accounts = await _repository.accounts(search: _search);
      emit(current.copyWith(accounts: accounts));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> adjust({
    required String plate,
    required int delta,
    required String reason,
  }) async {
    final current = state;
    if (current is! LoyaltyAdminLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final result = await _repository.adjust(
        plate: plate,
        delta: delta,
        reason: reason,
      );
      final accounts = await _repository.accounts(search: _search);
      emit(
        current.copyWith(
          accounts: accounts,
          submission: SubmissionSucceeded<LoyaltyAdjustResult>(result),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> loadReport(DateTime start, DateTime end) async {
    final current = state;
    if (current is! LoyaltyAdminLoaded) {
      return;
    }
    try {
      final report = await _repository.report(start: start, end: end);
      emit(current.copyWith(report: report));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }
}
