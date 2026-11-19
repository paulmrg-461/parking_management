import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/public_booking/domain/entities/public_booking.dart';
import 'package:parking_management/features/waitlist/domain/entities/waitlist_entry.dart';
import 'package:parking_management/features/waitlist/domain/entities/waitlist_settings.dart';
import 'package:parking_management/features/waitlist/domain/repositories/waitlist_repository.dart';

/// Desk repository double: records calls and answers with [entries].
class FakeWaitlistRepository implements WaitlistRepository {
  List<WaitlistEntry> entries = [];
  WaitlistSettings settings = WaitlistSettings.defaults;
  Failure? listError;
  Failure? actionError;
  final List<int> claimed = [];
  final List<int> removed = [];
  final List<WaitlistSettings> saved = [];

  @override
  Future<List<WaitlistEntry>> list() async {
    final error = listError;
    if (error != null) {
      throw error;
    }
    return entries;
  }

  @override
  Future<PublicReservation> claim(int id) async {
    claimed.add(id);
    final error = actionError;
    if (error != null) {
      throw error;
    }
    return PublicReservation(
      id: 900 + id,
      plate: entries.firstWhere((entry) => entry.id == id).plate,
      categoryName: 'car',
      reservedUntil: DateTime.utc(2026, 1, 1, 12),
    );
  }

  @override
  Future<void> remove(int id) async {
    removed.add(id);
    final error = actionError;
    if (error != null) {
      throw error;
    }
    entries = [...entries.where((entry) => entry.id != id)];
  }

  @override
  Future<WaitlistSettings> loadSettings() async => settings;

  @override
  Future<WaitlistSettings> saveSettings(WaitlistSettings value) async {
    saved.add(value);
    final error = actionError;
    if (error != null) {
      throw error;
    }
    settings = value;
    return value;
  }
}
