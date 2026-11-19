import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/price_quote.dart';
import '../domain/repositories/price_quote_repository.dart';

sealed class PriceQuoteState extends Equatable {
  const PriceQuoteState();

  @override
  List<Object?> get props => const [];
}

final class PriceQuoteHidden extends PriceQuoteState {
  const PriceQuoteHidden({this.offline = false});

  /// The device is offline: the check-in page shows the offline note.
  final bool offline;

  @override
  List<Object?> get props => [offline];
}

final class PriceQuoteLoading extends PriceQuoteState {
  const PriceQuoteLoading();
}

final class PriceQuoteReady extends PriceQuoteState {
  const PriceQuoteReady(this.quote);

  final PriceQuote quote;

  @override
  List<Object?> get props => [quote];
}

final class PriceQuoteFailure extends PriceQuoteState {
  const PriceQuoteFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure.message, failure.code];
}

/// Price chip of the check-in page: reloads on category change and every
/// minute while the screen is open. It never blocks check-in.
class PriceQuoteCubit extends ResilientCubit<PriceQuoteState> {
  PriceQuoteCubit(
    this._repository, {
    this.refreshInterval = const Duration(seconds: 60),
  }) : super(const PriceQuoteHidden());

  final PriceQuoteRepository _repository;
  final Duration refreshInterval;

  Timer? _timer;
  int? _categoryId;

  Future<void> load(int categoryId) async {
    _categoryId = categoryId;
    _cancelTimer();
    try {
      final quote = await _repository.quote(categoryId);
      emit(
        quote.enabled && quote.hourlyCurrent > 0
            ? PriceQuoteReady(quote)
            : const PriceQuoteHidden(),
      );
      _timer = Timer.periodic(refreshInterval, (_) => _refresh());
    } on NetworkFailure {
      emit(const PriceQuoteHidden(offline: true));
      _timer = Timer.periodic(refreshInterval, (_) => _refresh());
    } on Failure catch (failure) {
      emit(PriceQuoteFailure(failure));
      _timer = Timer.periodic(refreshInterval, (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    final category = _categoryId;
    if (category == null) {
      return;
    }
    try {
      final quote = await _repository.quote(category);
      emit(
        quote.enabled && quote.hourlyCurrent > 0
            ? PriceQuoteReady(quote)
            : const PriceQuoteHidden(),
      );
    } on Failure {
      // Keep the last state; the next tick retries.
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    _cancelTimer();
    return super.close();
  }
}
