import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/pricing/application/price_quote_cubit.dart';
import 'package:parking_management/features/pricing/domain/entities/price_quote.dart';

import '../../../helpers/fake_pricing_repository.dart';

void main() {
  test('Success: load emits ready with the quote', () async {
    final repository = FakePriceQuoteRepository();
    final cubit = PriceQuoteCubit(
      repository,
      refreshInterval: const Duration(minutes: 5),
    );
    final states = <PriceQuoteState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load(1);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<PriceQuoteReady>());
    expect((cubit.state as PriceQuoteReady).quote.isSurge, isTrue);
    expect(states, isNotEmpty);
    await subscription.cancel();
    await cubit.close();
  });

  test('Success: a disabled lot hides the chip', () async {
    final cubit = PriceQuoteCubit(
      FakePriceQuoteRepository(
        quoteResult: const PriceQuote(enabled: false, hourlyCurrent: 0),
      ),
      refreshInterval: const Duration(minutes: 5),
    );
    await cubit.load(1);
    expect(cubit.state, isA<PriceQuoteHidden>());
    await cubit.close();
  });

  test('Failure: a network error hides the chip with the offline note', () async {
    final cubit = PriceQuoteCubit(
      FakePriceQuoteRepository(failure: const NetworkFailure('offline')),
      refreshInterval: const Duration(minutes: 5),
    );
    await cubit.load(1);
    expect(cubit.state, isA<PriceQuoteHidden>());
    expect((cubit.state as PriceQuoteHidden).offline, isTrue);
    await cubit.close();
  });

  test('Failure: a server error emits Failure without blocking check-in', () async {
    final cubit = PriceQuoteCubit(
      FakePriceQuoteRepository(
        failure: const ValidationFailure('CategoryNotFoundError', 'CategoryNotFoundError'),
      ),
      refreshInterval: const Duration(minutes: 5),
    );
    await cubit.load(99);
    expect(cubit.state, isA<PriceQuoteFailure>());
    await cubit.close();
  });

  test('Success: the timer refreshes and close cancels it', () {
    fakeAsync((async) {
      final repository = FakePriceQuoteRepository();
      final cubit = PriceQuoteCubit(
        repository,
        refreshInterval: const Duration(seconds: 60),
      );
      cubit.load(1);
      async.elapse(const Duration(minutes: 3));
      expect(repository.quoteCalls, greaterThanOrEqualTo(3));
      cubit.close();
      final calls = repository.quoteCalls;
      async.elapse(const Duration(minutes: 5));
      expect(repository.quoteCalls, calls);
    });
  });
}
