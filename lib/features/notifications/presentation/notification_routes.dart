import '../domain/entities/app_notification.dart';

/// Where a notification should take the user when tapped.
String? routeForNotification(AppNotification notification) {
  final plate = notification.data['plate'];
  final historyRoute = plate is String && plate.isNotEmpty
      ? '/history?plate=${Uri.encodeQueryComponent(plate)}'
      : null;
  return switch (notification.type) {
    'shift_closed' => '/shift',
    'monthly_pass_expiring' || 'monthly_pass_renewed' => '/monthly-passes',
    'check_in' || 'check_out' || 'overstay' => historyRoute,
    _ => null,
  };
}
