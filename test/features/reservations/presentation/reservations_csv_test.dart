import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reservations/domain/entities/reservation.dart';
import 'package:parking_management/features/reservations/presentation/reservations_csv.dart';

Reservation _hold({
  int id = 7,
  String plate = 'ABC123',
  String category = 'car',
  String? name,
  String? phone,
  String source = 'public',
  bool inGrace = false,
  String? notes,
}) => Reservation(
  id: id,
  plate: plate,
  categoryId: 2,
  categoryName: category,
  reservedUntil: DateTime.utc(2026, 11, 10, 20, 30),
  customerName: name,
  customerPhone: phone,
  source: source,
  inGrace: inGrace,
  notes: notes,
);

void main() {
  test('Success: the CSV carries the code, contact and source', () {
    final csv = reservationsCsv([
      _hold(name: 'Ana Perez', phone: '3009998877', inGrace: true),
      _hold(id: 9, plate: 'XYZ999', source: 'app'),
    ]);

    final lines = csv.split('\n');
    expect(lines.first, startsWith('code,plate,category,reserved_until'));
    expect(lines[1], contains('7,ABC123,car,2026-11-10T20:30:00.000Z'));
    expect(lines[1], contains('Ana Perez'));
    expect(lines[1], contains('3009998877,public,active,yes'));
    expect(lines[2], contains('9,XYZ999,car'));
    expect(lines[2], contains(',app,active,no'));
  });

  test('Security: a comma or a quote does not break the columns', () {
    final csv = reservationsCsv([
      _hold(name: 'Perez, Ana "Anita"', notes: 'llega; 8pm'),
    ]);

    expect(csv, contains('"Perez, Ana ""Anita"""'));
    expect(csv, contains('"llega; 8pm"'));
  });

  test('Success: the file name is dated', () {
    expect(
      reservationsCsvFileName(DateTime(2026, 11, 9)),
      'reservas-2026-11-09.csv',
    );
  });
}
