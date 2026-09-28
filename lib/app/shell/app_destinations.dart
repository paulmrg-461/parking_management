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

const primaryDestinations = [
  AppDestination(homePath, _home, Icons.home_outlined, Icons.home),
  AppDestination('/check-in', _checkIn, Icons.login_outlined, Icons.login),
  AppDestination('/check-out', _checkOut, Icons.logout_outlined, Icons.logout),
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
];

/// Destinations visible to [role], filtered by the same policy as the router.
List<AppDestination> destinationsFor(UserRole role, {bool management = true}) =>
    [
      ...primaryDestinations,
      if (management) ...managementDestinations,
    ].where((d) => canAccess(role, d.path)).toList();
