import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/l10n.dart';
import '../domain/entities/parking_settings.dart';
import '../domain/repositories/parking_settings_repository.dart';

sealed class BrandingState extends Equatable {
  const BrandingState();

  /// Settings to render, or `null` before anything has synced: callers fall
  /// back to the localized default / generic icon.
  ParkingSettings? get settingsOrNull => null;

  /// Cached logo bytes for the current [ParkingSettings.logoVersion].
  Uint8List? get logoOrNull => null;

  /// The configured parking name, or [l10n]'s default while unconfigured.
  String titleFor(AppLocalizations l10n) {
    final name = settingsOrNull?.name.trim() ?? '';
    final unset =
        settingsOrNull == null || settingsOrNull == ParkingSettings.defaults();
    return unset || name.isEmpty ? l10n.appTitle : name;
  }

  @override
  List<Object?> get props => const [];
}

final class BrandingInitial extends BrandingState {
  const BrandingInitial();
}

final class BrandingLoaded extends BrandingState {
  const BrandingLoaded(this.settings, {this.logo});

  final ParkingSettings settings;
  final Uint8List? logo;

  @override
  ParkingSettings get settingsOrNull => settings;

  @override
  Uint8List? get logoOrNull => logo;

  @override
  List<Object?> get props => [settings, logo];
}

/// Root-level branding state: seeded from Hive at startup, refreshed from
/// the backend when online. Never fails: a broken refresh keeps whatever is
/// already on screen. An all-defaults record behaves like "unconfigured"
/// so first runs keep rendering the localized fallback.
class BrandingCubit extends Cubit<BrandingState> {
  BrandingCubit(this._repository) : super(const BrandingInitial());

  final ParkingSettingsRepository _repository;

  Future<void> load() async {
    final cached = await _repository.loadCached();
    if (cached != null && cached != ParkingSettings.defaults()) {
      emit(
        BrandingLoaded(cached, logo: await _repository.loadLogo(cached.logoVersion)),
      );
    }
    try {
      final fresh = await _repository.load();
      if (fresh != ParkingSettings.defaults()) {
        emit(
          BrandingLoaded(fresh, logo: await _repository.loadLogo(fresh.logoVersion)),
        );
      }
    } on Failure {
      // Keep whatever is on screen (seed or the initial state).
    }
  }
}
