import '../../public_booking/domain/entities/public_booking.dart';
import '../domain/entities/waitlist_entry.dart';
import '../domain/entities/waitlist_settings.dart';
import '../domain/repositories/waitlist_repository.dart';
import 'waitlist_remote_data_source.dart';

class WaitlistRepositoryImpl implements WaitlistRepository {
  WaitlistRepositoryImpl(this._remote);

  final WaitlistRemoteDataSource _remote;

  @override
  Future<List<WaitlistEntry>> list() => _remote.list();

  @override
  Future<PublicReservation> claim(int id) => _remote.claim(id);

  @override
  Future<void> remove(int id) => _remote.remove(id);

  @override
  Future<WaitlistSettings> loadSettings() => _remote.loadSettings();

  @override
  Future<WaitlistSettings> saveSettings(WaitlistSettings settings) =>
      _remote.saveSettings(settings);
}
