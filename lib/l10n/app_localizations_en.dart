// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Parking';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCreate => 'Create';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionDone => 'Done';

  @override
  String get actionLoadMore => 'Load more';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionLogout => 'Log out';

  @override
  String get loading => 'Loading';

  @override
  String get fieldRequired => 'Required field';

  @override
  String get notAvailable => '—';

  @override
  String get errorNetwork => 'Unable to reach the server';

  @override
  String get errorServer => 'Server temporarily unavailable. Try again shortly';

  @override
  String get errorAuth => 'Wrong username or PIN';

  @override
  String get errorForbidden => 'You are not allowed to do this';

  @override
  String get errorSessionExpired =>
      'Your session expired. Please sign in again';

  @override
  String get errorStorage => 'Could not save data on this device';

  @override
  String get errorUnknown => 'Something went wrong';

  @override
  String errorRateLimited(int minutes) {
    return 'Too many attempts. Try again in $minutes min';
  }

  @override
  String get errorTooManyAttempts => 'Too many attempts, try later';

  @override
  String get errorNotFound => 'Record not found';

  @override
  String get errorConflict => 'The operation conflicts with the current data';

  @override
  String get errorInvalidData => 'The submitted data is not valid';

  @override
  String get errorVehicleNotFound => 'Vehicle not found';

  @override
  String get errorCategoryNotFound => 'Category not found';

  @override
  String get errorTariffNotFound => 'Tariff not found';

  @override
  String get errorUserNotFound => 'User not found';

  @override
  String get errorMonthlyPassNotFound => 'Monthly pass not found';

  @override
  String get errorSessionNotFound => 'Session not found';

  @override
  String get errorMissingHourlyTariff =>
      'Hourly tariff not configured for this category';

  @override
  String get errorDuplicateOpenSession => 'This vehicle is already parked';

  @override
  String get errorDuplicatePlate => 'A vehicle with that plate already exists';

  @override
  String get errorDuplicateCategory =>
      'A category with that name already exists';

  @override
  String get errorDuplicateUsername => 'That username already exists';

  @override
  String get errorSessionAlreadyClosed => 'Session already closed';

  @override
  String get errorVehicleNotRegistered => 'New vehicle: pick a category';

  @override
  String get errorInvalidPhoto => 'Photos must be JPEG or PNG images';

  @override
  String get errorPhotoTooLarge => 'Each photo must be 5 MB or smaller';

  @override
  String get errorTooManyPhotos => 'Too many photos for one check-in';

  @override
  String get errorAdminRequired => 'Admin required';

  @override
  String get errorIdempotency => 'This operation was already sent';

  @override
  String get errorEmptyPlate => 'Enter the plate';

  @override
  String get errorOcrNoText => 'Could not read the plate from the photo';

  @override
  String get errorScanUnavailable => 'Plate scanning is not available here';

  @override
  String get errorPendingSyncCheckOut =>
      'This check-in is still waiting to sync; try again once online';

  @override
  String get errorMissingPendingPhoto => 'A queued evidence photo is missing';

  @override
  String get deferredLoadError => 'Could not load this section';

  @override
  String get offlineBanner =>
      'Offline. Changes are saved and will sync when you reconnect';

  @override
  String syncPendingTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync',
      one: '1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String syncPendingWithErrors(String base, int errors) {
    return '$base ($errors failed)';
  }

  @override
  String get syncSheetTitle => 'Unsynced changes';

  @override
  String syncQueued(int count) {
    return '$count queued, retried automatically.';
  }

  @override
  String get syncDiscard => 'Discard change';

  @override
  String get syncUnknownError => 'Unknown error';

  @override
  String get entityVehicle => 'Vehicle';

  @override
  String get entityTariff => 'Tariff';

  @override
  String get entityCategory => 'Category';

  @override
  String get entityCheckIn => 'Check-in';

  @override
  String get entityCheckOut => 'Check-out';

  @override
  String get navHome => 'Home';

  @override
  String get navCheckIn => 'Check-in';

  @override
  String get navCheckOut => 'Check-out';

  @override
  String get navVehicles => 'Vehicles';

  @override
  String get navTariffs => 'Tariffs';

  @override
  String get navCategories => 'Categories';

  @override
  String get navMonthlyPasses => 'Monthly passes';

  @override
  String get navUsers => 'Users';

  @override
  String get navReports => 'Reports';

  @override
  String get navMore => 'More';

  @override
  String get navMoreTooltip => 'More management sections';

  @override
  String get loginSubtitle => 'Sign in to continue';

  @override
  String get loginUsername => 'Username';

  @override
  String get loginPin => 'PIN';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginFailed => 'Login failed';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleOperator => 'Operator';

  @override
  String get homeOccupancy => 'Vehicles parked';

  @override
  String get homeOccupancyUnavailable => 'Occupancy unavailable';

  @override
  String get homeEntryHint => 'Register an arriving vehicle';

  @override
  String get homeExitHint => 'Charge and close a stay';

  @override
  String get homeManagement => 'Management';

  @override
  String get homeRefreshTooltip => 'Refresh occupancy';

  @override
  String get plateLabel => 'Plate';

  @override
  String get plateHint => 'ABC123';

  @override
  String get plateScanTooltip => 'Scan plate with the camera';

  @override
  String plateDetected(String plate) {
    return 'Plate detected: $plate';
  }

  @override
  String get checkInTitle => 'Check-in';

  @override
  String get lookupLoading => 'Looking up vehicle';

  @override
  String lookupError(String message) {
    return 'Could not look up vehicle: $message';
  }

  @override
  String get registeredVehicle => 'Registered vehicle';

  @override
  String get newVehicle => 'New vehicle';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldColor => 'Color';

  @override
  String get fieldBrand => 'Brand';

  @override
  String get fieldPlate => 'Plate';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldVehicle => 'Vehicle';

  @override
  String get fieldAmount => 'Amount (COP)';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldStartDate => 'Start date';

  @override
  String get fieldEndDate => 'End date';

  @override
  String get fieldDisplayName => 'Display name';

  @override
  String get fieldRole => 'Role';

  @override
  String get categoryRequiredHelper => 'Required to register this plate';

  @override
  String get colorOptional => 'Color (optional)';

  @override
  String get brandOptional => 'Brand (optional)';

  @override
  String photosTitle(int count, int max) {
    return 'Evidence photos ($count/$max)';
  }

  @override
  String get addPhoto => 'Add photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String photoLabel(int index) {
    return 'Photo $index';
  }

  @override
  String photosMaxReached(int max) {
    return 'Maximum $max photos per check-in';
  }

  @override
  String get checkInSubmit => 'Register check-in';

  @override
  String checkInSuccess(String plate) {
    return 'Check-in created for $plate';
  }

  @override
  String checkInQueued(String plate) {
    return 'Check-in saved offline: $plate';
  }

  @override
  String get openSessionsTitle => 'Parked vehicles';

  @override
  String get openSessionsEmpty => 'No vehicles parked';

  @override
  String sessionEntry(String time) {
    return 'Entry: $time';
  }

  @override
  String sessionPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
      zero: 'no photos',
    );
    return '$_temp0';
  }

  @override
  String get statusOpen => 'Parked';

  @override
  String get statusPendingSync => 'Pending sync';

  @override
  String get statusClosed => 'Closed';

  @override
  String get checkOutTitle => 'Check-out';

  @override
  String get searchPlate => 'Search by plate';

  @override
  String checkOutNoMatch(String query) {
    return 'No plate matches “$query”';
  }

  @override
  String get checkOutCharge => 'Charge';

  @override
  String checkOutChargeTooltip(String plate) {
    return 'Charge check-out for $plate';
  }

  @override
  String unknownVehicle(int id) {
    return 'Vehicle #$id';
  }

  @override
  String receiptTitle(String plate) {
    return 'Check-out $plate';
  }

  @override
  String get receiptEntry => 'Entry';

  @override
  String get receiptExit => 'Exit';

  @override
  String get receiptDuration => 'Duration';

  @override
  String get receiptEstimated => 'Estimated amount';

  @override
  String get receiptEstimateUnavailable => 'Computed on close';

  @override
  String get receiptAmount => 'Amount charged';

  @override
  String get receiptTicket => 'Ticket';

  @override
  String get receiptConfirm => 'Charge and close';

  @override
  String get receiptDoneTitle => 'Check-out complete';

  @override
  String get receiptQueued =>
      'Check-out saved offline. The amount will be computed on sync';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get receiptGenerate => 'Generate receipt';

  @override
  String get receiptView => 'View receipt';

  @override
  String get receiptClose => 'Close';

  @override
  String get printReceipt => 'Print';

  @override
  String get printSystem => 'System printer (PDF)';

  @override
  String get printBluetooth => 'Bluetooth printers';

  @override
  String get printScan => 'Search for printers';

  @override
  String get printScanning => 'Searching for printers...';

  @override
  String get printNoPrinters => 'No Bluetooth printers found';

  @override
  String get printSuccess => 'Receipt sent to the printer';

  @override
  String get printError => 'Could not print';

  @override
  String get receiptPhotos => 'Evidence photos';

  @override
  String get checkInReceiptTitle => 'Check-in complete';

  @override
  String receiptGeneratedAt(String time) {
    return 'Generated at $time';
  }

  @override
  String get scanTitle => 'Scan plate';

  @override
  String get scanCapture => 'Capture plate';

  @override
  String get scanManualHint => 'Enter the plate manually';

  @override
  String get scanManual => 'Enter manually';

  @override
  String get scanEmpty => 'Enter a plate before confirming';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesEmpty => 'No categories yet';

  @override
  String get categoryNew => 'New category';

  @override
  String get categoryRename => 'Rename category';

  @override
  String categoryDeleteTooltip(String name) {
    return 'Delete category $name';
  }

  @override
  String get categoryDeleteTitle => 'Delete category?';

  @override
  String categoryDeleteBody(String name) {
    return '“$name” will be deleted. This cannot be undone.';
  }

  @override
  String get categoryAddTooltip => 'Add category';

  @override
  String categoryFallback(int id) {
    return 'Category $id';
  }

  @override
  String get vehiclesTitle => 'Vehicles';

  @override
  String get vehiclesEmpty => 'No vehicles registered yet';

  @override
  String get vehicleNew => 'New vehicle';

  @override
  String get vehicleAddTooltip => 'Add vehicle';

  @override
  String vehicleDeleteTooltip(String plate) {
    return 'Delete vehicle $plate';
  }

  @override
  String get vehicleDeleteTitle => 'Delete vehicle?';

  @override
  String vehicleDeleteBody(String plate) {
    return 'Vehicle $plate will be deleted. This cannot be undone.';
  }

  @override
  String get tariffsTitle => 'Tariffs';

  @override
  String get tariffsEmpty => 'No tariffs yet';

  @override
  String get tariffNew => 'New tariff';

  @override
  String get tariffAddTooltip => 'Add tariff';

  @override
  String get tariffTypeHourly => 'Hourly';

  @override
  String get tariffTypeDaily => 'Daily';

  @override
  String get tariffTypeNightly => 'Nightly';

  @override
  String get tariffTypeMonthly => 'Monthly';

  @override
  String get tariffStart => 'Start (HH:MM)';

  @override
  String get tariffEnd => 'End (HH:MM)';

  @override
  String get tariffActiveLabel => 'Tariff active';

  @override
  String get tariffDeleteTooltip => 'Delete tariff';

  @override
  String get tariffDeleteTitle => 'Delete tariff?';

  @override
  String tariffDeleteBody(String label) {
    return 'Tariff $label will be deleted. This cannot be undone.';
  }

  @override
  String get tariffDeactivated => 'Tariff deactivated';

  @override
  String get invalidTime => 'Use HH:MM (24 h)';

  @override
  String get invalidAmount => 'Enter an amount greater than 0';

  @override
  String get usersTitle => 'Users';

  @override
  String get usersEmpty => 'No users yet';

  @override
  String get userNew => 'New user';

  @override
  String get userAddTooltip => 'Add user';

  @override
  String userActiveLabel(String name) {
    return 'User active: $name';
  }

  @override
  String userDeactivated(String name) {
    return 'User $name deactivated';
  }

  @override
  String get pinInvalid => 'The PIN must have 4 to 6 digits';

  @override
  String get monthlyPassesTitle => 'Monthly passes';

  @override
  String get monthlyPassesEmpty => 'No monthly passes yet';

  @override
  String get monthlyPassNew => 'New monthly pass';

  @override
  String get monthlyPassEdit => 'Edit monthly pass';

  @override
  String get monthlyPassAddTooltip => 'Add monthly pass';

  @override
  String monthlyPassEditTooltip(String plate) {
    return 'Edit monthly pass for $plate';
  }

  @override
  String monthlyPassDeleteTooltip(String plate) {
    return 'Delete monthly pass for $plate';
  }

  @override
  String get monthlyPassDeleteTitle => 'Delete monthly pass?';

  @override
  String monthlyPassDeleteBody(String plate) {
    return 'The monthly pass for $plate will be deleted. This cannot be undone.';
  }

  @override
  String monthlyPassActiveLabel(String plate) {
    return 'Monthly pass active: $plate';
  }

  @override
  String monthlyPassDeactivated(String plate) {
    return 'Monthly pass for $plate deactivated';
  }

  @override
  String monthlyPassPeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String get selectDate => 'Select date';

  @override
  String get dateRangeInvalid => 'The end date must be after the start date';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsRangeTooltip => 'Change date range';

  @override
  String get reportsTotalRevenue => 'Total revenue';

  @override
  String get reportsRevenueByDay => 'Revenue by day';

  @override
  String get reportsRevenueByCategory => 'Revenue by category';

  @override
  String get reportsOccupancy => 'Occupancy';

  @override
  String reportsOpenSessions(int count) {
    return 'Vehicles parked: $count';
  }

  @override
  String get reportsNoCategoryData => 'No category data';

  @override
  String get reportsNoRevenue => 'No revenue for this range';
}
