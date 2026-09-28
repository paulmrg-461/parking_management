import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../../application/vehicle_lookup_cubit.dart';

/// Renders the outcome of the plate lookup: progress, an error, the
/// registered vehicle (read-only), or the fields to register a new one.
class VehicleLookupSection extends StatelessWidget {
  const VehicleLookupSection({
    super.key,
    required this.state,
    required this.registration,
  });

  final VehicleLookupState state;

  /// Built only when the plate is unknown ([VehicleLookupNotFound]).
  final Widget Function(VehicleLookupNotFound state) registration;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (state) {
      VehicleLookupIdle() => const SizedBox.shrink(),
      VehicleLookupLoading() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(semanticsLabel: l10n.lookupLoading),
      ),
      VehicleLookupFailure(:final message) => Text(
        l10n.lookupError(message),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      VehicleLookupFound(:final vehicle, :final categoryName) =>
        FoundVehicleCard(vehicle: vehicle, categoryName: categoryName),
      final VehicleLookupNotFound notFound => registration(notFound),
    };
  }
}

/// Read-only summary of an already registered vehicle.
class FoundVehicleCard extends StatelessWidget {
  const FoundVehicleCard({super.key, required this.vehicle, this.categoryName});

  final Vehicle vehicle;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.registeredVehicle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(label: l10n.plateLabel, value: vehicle.plate),
            _InfoRow(
              label: l10n.fieldCategory,
              value: categoryName ?? '#${vehicle.categoryId}',
            ),
            _InfoRow(label: l10n.fieldColor, value: vehicle.color ?? l10n.notAvailable),
            _InfoRow(label: l10n.fieldBrand, value: vehicle.brand ?? l10n.notAvailable),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      ),
    );
  }
}
