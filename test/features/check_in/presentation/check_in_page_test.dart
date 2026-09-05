import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parking_management/features/check_in/application/check_in_cubit.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:parking_management/features/check_in/presentation/check_in_page.dart';
import 'package:parking_management/features/plate_scanning/infrastructure/image_picker_plate_capture.dart';

class _FakeCheckInRepository implements CheckInRepository {
  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<File> photos,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async => [
        ParkingSession(
          id: 1,
          plate: 'ABC123',
          status: ParkingSessionStatus.open,
          entryTime: DateTime(2026, 1, 1),
          photoCount: 2,
        ),
      ];
}

class _FakeCapture implements PlateImageCapture {
  @override
  Future<XFile?> capture() async => null;
}

void main() {
  testWidgets(
    'Success: renders the open sessions list and the check-in form',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<CheckInCubit>(
            create: (_) => CheckInCubit(_FakeCheckInRepository()),
            child: CheckInPage(capture: _FakeCapture()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scan plate'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Submit check-in'), findsOneWidget);
      expect(find.text('Open sessions'), findsOneWidget);
      expect(find.text('ABC123'), findsOneWidget);
    },
  );
}
