import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/fiscal_customer.dart';
import '../domain/entities/fiscal_document.dart';
import '../domain/entities/fiscal_resolution.dart';
import '../domain/entities/fiscal_settings.dart';
import '../domain/repositories/invoicing_repository.dart';

sealed class InvoicingState extends Equatable {
  const InvoicingState();

  @override
  List<Object?> get props => const [];
}

final class InvoicingInitial extends InvoicingState {
  const InvoicingInitial();
}

final class InvoicingLoading extends InvoicingState {
  const InvoicingLoading();
}

final class InvoicingLoaded extends InvoicingState {
  const InvoicingLoaded({
    required this.settings,
    required this.resolutions,
    required this.documents,
    this.total = 0,
    this.statusFilter,
    this.submission = const SubmissionIdle(),
  });

  final FiscalSettings settings;
  final List<FiscalResolution> resolutions;
  final List<FiscalDocument> documents;
  final int total;
  final FiscalStatus? statusFilter;
  final Submission submission;

  bool get hasMore => documents.length < total;

  InvoicingLoaded copyWith({
    FiscalSettings? settings,
    List<FiscalResolution>? resolutions,
    List<FiscalDocument>? documents,
    int? total,
    FiscalStatus? statusFilter,
    bool clearFilter = false,
    Submission? submission,
  }) => InvoicingLoaded(
    settings: settings ?? this.settings,
    resolutions: resolutions ?? this.resolutions,
    documents: documents ?? this.documents,
    total: total ?? this.total,
    statusFilter: clearFilter ? null : (statusFilter ?? this.statusFilter),
    submission: submission ?? this.submission,
  );

  @override
  List<Object?> get props => [
    settings,
    resolutions,
    documents,
    total,
    statusFilter,
    submission,
  ];
}

final class InvoicingFailure extends InvoicingState {
  const InvoicingFailure(this.message, {this.failure});

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

/// Admin screen: issuer data, resolutions and the outbox list.
class InvoicingCubit extends ResilientCubit<InvoicingState> {
  InvoicingCubit(this._repository) : super(const InvoicingInitial());

  static const pageSize = 50;

  final InvoicingRepository _repository;

  Future<void> load() async {
    emit(const InvoicingLoading());
    try {
      final settings = await _repository.settings();
      final resolutions = await _repository.resolutions();
      final page = await _repository.documents(limit: pageSize);
      emit(
        InvoicingLoaded(
          settings: settings,
          resolutions: resolutions,
          documents: page.items,
          total: page.total ?? page.items.length,
        ),
      );
    } on Failure catch (failure) {
      emit(InvoicingFailure(failure.message, failure: failure));
    }
  }

  Future<void> filterBy(FiscalStatus? status) async {
    final current = state;
    if (current is! InvoicingLoaded) {
      return;
    }
    try {
      final page = await _repository.documents(status: status, limit: pageSize);
      emit(
        current.copyWith(
          documents: page.items,
          total: page.total ?? page.items.length,
          statusFilter: status,
          clearFilter: status == null,
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! InvoicingLoaded || !current.hasMore) {
      return;
    }
    try {
      final page = await _repository.documents(
        status: current.statusFilter,
        limit: pageSize,
        offset: current.documents.length,
      );
      emit(
        current.copyWith(
          documents: [...current.documents, ...page.items],
          total: page.total ?? current.total,
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> saveSettings(FiscalSettings settings) async {
    final current = state;
    if (current is! InvoicingLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final saved = await _repository.saveSettings(settings);
      emit(
        current.copyWith(
          settings: saved,
          submission: SubmissionSucceeded<FiscalSettings>(saved),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> saveResolution(FiscalResolution resolution) async {
    final current = state;
    if (current is! InvoicingLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final saved = await _repository.saveResolution(resolution);
      final resolutions = await _repository.resolutions();
      emit(
        current.copyWith(
          resolutions: resolutions,
          submission: SubmissionSucceeded<FiscalResolution>(saved),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> retry(int id, {FiscalCustomer? customer}) async {
    final current = state;
    if (current is! InvoicingLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final summary = await _repository.retry(id, customer: customer);
      await _refreshDocuments(current, SubmissionSucceeded<FiscalDocSummary>(summary));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> requestCreditNote(int id, String reason) async {
    final current = state;
    if (current is! InvoicingLoaded) {
      return;
    }
    if (reason.trim().length < 3) {
      emit(
        current.copyWith(
          submission: const SubmissionFailed('Invoicing reason required'),
        ),
      );
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final summary = await _repository.requestCreditNote(id, reason.trim());
      await _refreshDocuments(current, SubmissionSucceeded<FiscalDocSummary>(summary));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> _refreshDocuments(
    InvoicingLoaded current,
    Submission submission,
  ) async {
    final page = await _repository.documents(
      status: current.statusFilter,
      limit: pageSize,
    );
    emit(
      current.copyWith(
        documents: page.items,
        total: page.total ?? page.items.length,
        submission: submission,
      ),
    );
  }
}
