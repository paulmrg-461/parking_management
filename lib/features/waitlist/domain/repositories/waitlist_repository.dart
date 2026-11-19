import '../../../public_booking/domain/entities/public_booking.dart';
import '../entities/waitlist_entry.dart';
import '../entities/waitlist_settings.dart';

/// Desk side of the waitlist (authenticated, own lot only).
abstract class WaitlistRepository {
  Future<List<WaitlistEntry>> list();

  /// Gives the space to the customer on their behalf.
  Future<PublicReservation> claim(int id);

  /// Removes the turn and releases its offer, if any.
  Future<void> remove(int id);

  Future<WaitlistSettings> loadSettings();

  Future<WaitlistSettings> saveSettings(WaitlistSettings settings);
}
