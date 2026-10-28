import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../features/auth/domain/entities/user.dart';
import '../router/route_access.dart';

typedef LocalizedLabel = String Function(AppLocalizations l10n);

class AppDestination {
  const AppDestination(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final LocalizedLabel label;
  final IconData icon;
  final IconData selectedIcon;

  /// `/` only matches itself; other paths also match their sub-routes.
  bool matches(String location) => path == homePath
      ? location == homePath
      : location == path || location.startsWith('$path/');
}

String _home(AppLocalizations l) => l.navHome;
String _checkIn(AppLocalizations l) => l.navCheckIn;
String _checkOut(AppLocalizations l) => l.navCheckOut;
String _vehicles(AppLocalizations l) => l.navVehicles;
String _tariffs(AppLocalizations l) => l.navTariffs;
String _categories(AppLocalizations l) => l.navCategories;
String _monthlyPasses(AppLocalizations l) => l.navMonthlyPasses;
String _users(AppLocalizations l) => l.navUsers;
String _reports(AppLocalizations l) => l.navReports;
String _settings(AppLocalizations l) => l.navSettings;
String _contact(AppLocalizations l) => l.navContact;
String _notifications(AppLocalizations l) => l.navNotifications;
String _reservations(AppLocalizations l) => l.navReservations;
String _lots(AppLocalizations l) => l.navLots;
String _records(AppLocalizations l) => l.navRecords;
String _audit(AppLocalizations l) => l.navAudit;
String _diagnostics(AppLocalizations l) => l.navDiagnostics;

const primaryDestinations = [
  AppDestination(homePath, _home, Icons.home_outlined, Icons.home),
  AppDestination('/check-in', _checkIn, Icons.login_outlined, Icons.login),
  AppDestination('/check-out', _checkOut, Icons.logout_outlined, Icons.logout),
  AppDestination(
    '/records',
    _records,
    Icons.receipt_long_outlined,
    Icons.receipt_long,
  ),
  AppDestination(
    '/notifications',
    _notifications,
    Icons.notifications_outlined,
    Icons.notifications,
  ),
  AppDestination(
    '/contact',
    _contact,
    Icons.contact_mail_outlined,
    Icons.contact_mail,
  ),
];

const managementDestinations = [
  AppDestination(
    '/vehicles',
    _vehicles,
    Icons.directions_car_outlined,
    Icons.directions_car,
  ),
  AppDestination(
    '/tariffs',
    _tariffs,
    Icons.payments_outlined,
    Icons.payments,
  ),
  AppDestination(
    '/categories',
    _categories,
    Icons.category_outlined,
    Icons.category,
  ),
  AppDestination(
    '/diagnostics',
    _diagnostics,
    Icons.monitor_heart_outlined,
    Icons.monitor_heart,
  ),
  AppDestination(
    '/audit',
    _audit,
    Icons.history_outlined,
    Icons.history,
  ),
  AppDestination(
    '/lots',
    _lots,
    Icons.location_city_outlined,
    Icons.location_city,
  ),
  AppDestination(
    '/reservations',
    _reservations,
    Icons.event_available_outlined,
    Icons.event_available,
  ),
  AppDestination(
    '/monthly-passes',
    _monthlyPasses,
    Icons.card_membership_outlined,
    Icons.card_membership,
  ),
  AppDestination('/users', _users, Icons.people_outline, Icons.people),
  AppDestination(
    '/reports',
    _reports,
    Icons.bar_chart_outlined,
    Icons.bar_chart,
  ),
  AppDestination(
    '/settings',
    _settings,
    Icons.settings_outlined,
    Icons.settings,
  ),
];

/// Destinations visible to [role], filtered by the same policy as the router.
List<AppDestination> destinationsFor(UserRole role, {bool management = true}) =>
    [
      ...primaryDestinations,
      if (management) ...managementDestinations,
    ].where((d) => canAccess(role, d.path)).toList();
