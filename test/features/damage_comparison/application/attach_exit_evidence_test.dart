import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/damage_comparison/application/attach_exit_evidence.dart';
import 'package:parking_management/features/damage_comparison/infrastructure/exit_evidence_remote_data_source.dart';

class _FakeRemote implements ExitEvidenceRemoteDataSource {
  int calls = 0;
  int? count = 2;
  Failure? error;

  @override
  Future<int> attach({
    required int sessionId,
    required List<XFile> photos,
    required String clientRef,
  }) async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return count!;
  }
}

void main() {
  final photos = [
    XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg', path: 'a.jpg'),
  ];

  test('attaches and returns the count', () async {
    final remote = _FakeRemote();
    expect(
      await AttachExitEvidence(remote)(
        sessionId: 1,
        photos: photos,
        clientRef: 'ref',
      ),
      2,
    );
    expect(remote.calls, 1);
  });

  test('no photos does nothing', () async {
    final remote = _FakeRemote();
    expect(
      await AttachExitEvidence(remote)(
        sessionId: 1,
        photos: const [],
        clientRef: 'ref',
      ),
      isNull,
    );
    expect(remote.calls, 0);
  });

  test('over five photos is rejected', () async {
    final remote = _FakeRemote();
    expect(
      () => AttachExitEvidence(remote)(
        sessionId: 1,
        photos: List.filled(6, photos.first),
        clientRef: 'ref',
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('a repository failure returns null', () async {
    final remote = _FakeRemote()..error = const NetworkFailure('offline');
    expect(
      await AttachExitEvidence(remote)(
        sessionId: 1,
        photos: photos,
        clientRef: 'ref',
      ),
      isNull,
    );
  });
}
