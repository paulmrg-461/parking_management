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
  String get actionClose => 'Close';

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
  String get themeMode => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

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
  String get syncNow => 'Retry now';

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
  String get entitySettings => 'Settings';

  @override
  String get categoryFullHint => 'Full categories are disabled.';

  @override
  String get navLots => 'Sites';

  @override
  String lotMembersTitle(String name) {
    return 'Members of $name';
  }

  @override
  String get lotMembersEmpty => 'This site has no users';

  @override
  String get userInactive => 'inactive';

  @override
  String get lotsTitle => 'Parking sites';

  @override
  String get navAudit => 'Audit log';

  @override
  String get navDiagnostics => 'Diagnostics';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagnosticsWhatsapp => 'WhatsApp';

  @override
  String get diagnosticsWhatsappPending => 'Queued';

  @override
  String get diagnosticsWhatsappFailedCount => 'Failed';

  @override
  String get diagnosticsWhatsappSent => 'Sent (24 h)';

  @override
  String get diagnosticsWhatsappEmpty => 'No WhatsApp messages in the period';

  @override
  String diagnosticsWhatsappAttempts(int count) {
    return '$count attempts';
  }

  @override
  String get diagnosticsSystem => 'System';

  @override
  String diagnosticsMigrations(int count) {
    return 'Applied migrations ($count)';
  }

  @override
  String diagnosticsLots(int active, int total) {
    return 'Active sites: $active of $total';
  }

  @override
  String get diagnosticsOpenSessions => 'Open sessions';

  @override
  String get diagnosticsStaleSessions => 'Sessions open +24 h';

  @override
  String get diagnosticsOpenShifts => 'Shifts open +12 h';

  @override
  String get diagnosticsPendingPayments => 'Pending pass payments';

  @override
  String get diagnosticsReservations => 'Active reservations';

  @override
  String get diagnosticsIdempotency => 'Idempotency keys';

  @override
  String get diagnosticsNotifications => 'Notifications';

  @override
  String get diagnosticsPendingPush => 'Pending push';

  @override
  String get diagnosticsDeadPush => 'Failed after 3 attempts';

  @override
  String get diagnosticsUnread => 'Unread / total';

  @override
  String get diagnosticsStorage => 'Storage';

  @override
  String diagnosticsErrors(int count) {
    return 'App errors ($count)';
  }

  @override
  String get diagnosticsErrorsEmpty => 'No errors reported in the last 7 days';

  @override
  String get diagnosticsErrorDetail => 'Error detail';

  @override
  String get auditExport => 'Export';

  @override
  String get auditExportPdf => 'Export PDF';

  @override
  String get auditExportCsv => 'Copy CSV';

  @override
  String get auditCopied => 'CSV copied to the clipboard';

  @override
  String get auditActor => 'Actor';

  @override
  String get auditAllActors => 'All';

  @override
  String get auditTitle => 'Audit log';

  @override
  String get auditTable => 'Table';

  @override
  String get auditAllTables => 'All';

  @override
  String get auditFilterDates => 'Filter by date';

  @override
  String get auditEmpty => 'No changes recorded';

  @override
  String get auditChangesTitle => 'Changes';

  @override
  String get lotAdd => 'New site';

  @override
  String get lotCode => 'Code (2-10 letters/digits)';

  @override
  String get lotLabel => 'Site';

  @override
  String get lotName => 'Site name';

  @override
  String get lotAddress => 'Address (optional)';

  @override
  String get lotsEmpty => 'No sites yet';

  @override
  String lotMembers(int count) {
    return '$count users';
  }

  @override
  String get navReservations => 'Reservations';

  @override
  String get reservationsTitle => 'Capacity reservations';

  @override
  String get reservationAdd => 'New reservation';

  @override
  String get reservationCreated => 'Reservation created';

  @override
  String get reservationCancelled => 'Reservation cancelled';

  @override
  String get reservationsEmpty => 'No active reservations';

  @override
  String reservationExpiresIn(String duration) {
    return 'Expires in $duration';
  }

  @override
  String get reservationQuick2h => '+2 h';

  @override
  String get reservationQuick4h => '+4 h';

  @override
  String get reservationEndOfDay => 'End of day';

  @override
  String reservationUntil(String when) {
    return 'Until $when';
  }

  @override
  String reservationUntilLabel(String when) {
    return 'Hold until $when';
  }

  @override
  String get reservationNotes => 'Notes (optional)';

  @override
  String get reservationCheckIn => 'Register entry';

  @override
  String get checkInHoldTitle => 'Active hold';

  @override
  String get reservationCancel => 'Cancel reservation';

  @override
  String get reservationCancelTitle => 'Cancel this reservation?';

  @override
  String reservationCancelBody(String plate) {
    return 'The slot held for $plate will be released.';
  }

  @override
  String get sidebarCollapse => 'Collapse menu';

  @override
  String get sidebarExpand => 'Expand menu';

  @override
  String get navGroupOperation => 'Operations';

  @override
  String get navGroupManagement => 'Management';

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
  String get navSettings => 'Settings';

  @override
  String get navContact => 'Contact';

  @override
  String get navNotifications => 'Alerts';

  @override
  String get webPushTitle => 'Browser notifications';

  @override
  String get webPushSubtitle => 'Get alerts even when the tab is closed.';

  @override
  String get webPushDenied =>
      'The browser did not grant notification permission';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get notificationsMarkAll => 'Mark all read';

  @override
  String get navHistory => 'History';

  @override
  String get homeShift => 'Shift / Cash';

  @override
  String get checkOutNoShift =>
      'No open shift: this payment will not be part of the cash reconciliation.';

  @override
  String get shiftUnavailable => 'Shift unavailable';

  @override
  String get shiftOffline =>
      'You need a connection to operate the cash drawer.';

  @override
  String get shiftHistoryFilter => 'Filter by date';

  @override
  String get shiftHistoryClearFilter => 'Clear filter';

  @override
  String get shiftHistoryEmpty => 'No shifts in the selected range';

  @override
  String get shiftCardSales => 'Card sales';

  @override
  String get shiftTransferSales => 'Transfer sales';

  @override
  String get shiftPassSales => 'Monthly passes';

  @override
  String get shiftSessionCount => 'Paid exits';

  @override
  String get shiftCashMovements => 'Cash movements';

  @override
  String get shiftReconciliation => 'Reconciliation';

  @override
  String get shiftNotesTitle => 'Notes';

  @override
  String get actionExportPdf => 'Export PDF';

  @override
  String get actionShare => 'Share';

  @override
  String get shiftTitle => 'Shift / Cash';

  @override
  String get shiftNoOpen => 'No open shift';

  @override
  String get shiftOpeningFloat => 'Opening float (COP)';

  @override
  String get shiftOpen => 'Open shift';

  @override
  String get shiftOpenTitle => 'Open shift';

  @override
  String get shiftOpenedDone => 'Shift opened successfully';

  @override
  String get shiftClosedDone => 'Shift closed successfully';

  @override
  String get shiftMovementDone => 'Cash movement recorded';

  @override
  String get shiftAdjustedDone => 'Shift close corrected';

  @override
  String shiftOpenedAt(String time) {
    return 'Opened: $time';
  }

  @override
  String get shiftSales => 'Sales';

  @override
  String get shiftCashSales => 'Cash sales';

  @override
  String get shiftWithdrawals => 'Withdrawals';

  @override
  String get shiftDeposits => 'Cash deposits';

  @override
  String get shiftDiscounts => 'Discounts';

  @override
  String get shiftPassPayments => 'Pass payments';

  @override
  String get shiftPassCash => 'Pass payments in cash';

  @override
  String get shiftExpectedCash => 'Expected cash';

  @override
  String get shiftSessions => 'Check-outs';

  @override
  String get shiftWithdraw => 'Withdraw cash';

  @override
  String get shiftDeposit => 'Deposit cash';

  @override
  String get shiftClose => 'Close shift';

  @override
  String get shiftDifferenceConfirmTitle => 'The cash count does not match';

  @override
  String shiftDifferenceConfirmBody(String amount) {
    return 'Difference of $amount against the expected cash. Close the shift anyway?';
  }

  @override
  String get shiftClosedTitle => 'Shift closed';

  @override
  String get shiftAdjust => 'Correct shift close';

  @override
  String get shiftCountedCash => 'Counted cash';

  @override
  String get shiftDifference => 'Difference';

  @override
  String get shiftNotes => 'Notes';

  @override
  String get shiftReason => 'Reason';

  @override
  String get shiftHistory => 'Recent shifts';

  @override
  String get errorShiftAlreadyOpen => 'You already have an open shift';

  @override
  String get errorNoOpenShift => 'There is no open shift';

  @override
  String get errorShiftNotFound => 'Shift not found';

  @override
  String get errorLastAdmin =>
      'You cannot leave the system without administrators';

  @override
  String get errorCannotDeleteSelf => 'You cannot delete your own account';

  @override
  String get errorPaymentNotFound => 'Payment not found';

  @override
  String get errorPaymentAlreadyProcessed =>
      'This payment was already processed';

  @override
  String get errorShiftStillOpen => 'The shift is still open';

  @override
  String get errorShiftAdjustReason => 'Enter the correction reason';

  @override
  String get errorInvalidOpeningFloat => 'The opening float is not valid';

  @override
  String get errorInvalidCountedCash => 'The counted cash is not valid';

  @override
  String get errorInvalidCashMovement => 'The cash movement is not valid';

  @override
  String get errorCashMovementReason => 'Enter the movement reason';

  @override
  String get errorInvalidDiscount => 'The discount is not valid';

  @override
  String get errorDiscountReason => 'Enter the discount reason';

  @override
  String get errorVehicleBlacklisted =>
      'This vehicle is blocked; an admin must unblock it';

  @override
  String get vehiclePhone => 'Customer phone';

  @override
  String get vehiclePhoneHint => '+57 300 111 2233';

  @override
  String get vehiclePhoneTitle => 'Notification phone';

  @override
  String get vehicleAddPhone => 'Add phone';

  @override
  String get vehicleEditPhone => 'Edit phone';

  @override
  String get vehicleSendWhatsapp => 'Send receipt via WhatsApp';

  @override
  String vehicleWhatsappReady(String plate) {
    return 'Hi, your vehicle $plate is ready for pickup.';
  }

  @override
  String get vehicleChargeAction => 'Charge at checkout';

  @override
  String get vehicleWhatsappReadyAction => 'Notify it is ready';

  @override
  String vehicleWhatsappReceipt(String plate) {
    return 'Hi, here is the receipt for plate $plate:';
  }

  @override
  String vehicleWhatsappHello(String plate) {
    return 'Hi, this is the parking lot writing about plate $plate.';
  }

  @override
  String get vehicleWhatsappThanks => 'Thanks for your visit!';

  @override
  String get errorInvalidPhone => 'Enter a valid phone (7 to 15 digits)';

  @override
  String get errorWhatsappUnavailable =>
      'WhatsApp could not be opened on this device';

  @override
  String get vehicleNotes => 'Vehicle notes';

  @override
  String get vehicleNotesHint => 'Scratches, incidents, agreements…';

  @override
  String get vehicleAddNotes => 'Add note';

  @override
  String get vehicleEditNotes => 'Edit note';

  @override
  String get vehicleBlacklist => 'Block vehicle';

  @override
  String get vehicleUnblock => 'Unblock';

  @override
  String get vehicleBlacklisted => 'Blocked';

  @override
  String get vehicleBlacklistTitle => 'Block this vehicle?';

  @override
  String vehicleBlacklistBody(String plate) {
    return '$plate will not be able to enter until an admin unblocks it.';
  }

  @override
  String get vehicleUnblockTitle => 'Unblock this vehicle?';

  @override
  String vehicleUnblockBody(String plate) {
    return '$plate will be able to enter the parking lot again.';
  }

  @override
  String get vehicleHistoryTitle => 'Vehicle history';

  @override
  String get vehicleHistoryPrompt =>
      'Search a plate to see its entries and exits';

  @override
  String get vehicleHistoryVisits => 'Visits';

  @override
  String get vehicleHistoryTotalSpent => 'Total paid';

  @override
  String get vehicleHistoryAllLots => 'All sites';

  @override
  String vehicleHistoryCurrentLotVisits(int count) {
    return 'At this site: $count';
  }

  @override
  String get actionReprintTicket => 'Reprint ticket';

  @override
  String get vehicleHistorySessions => 'Sessions';

  @override
  String get vehicleHistoryNoSessions => 'No sessions recorded';

  @override
  String vehicleHistoryDuration(String duration) {
    return 'Duration: $duration';
  }

  @override
  String get vehicleHistoryOpen => 'In progress';

  @override
  String get navMore => 'More';

  @override
  String get navMoreTooltip => 'More management sections';

  @override
  String get settingsDiscardTitle => 'Discard changes?';

  @override
  String get settingsDiscardBody => 'There are unsaved settings changes.';

  @override
  String get settingsDiscard => 'Discard';

  @override
  String get settingsTitle => 'Parking settings';

  @override
  String get settingsCarCapacity => 'Spaces for cars and pickups';

  @override
  String get settingsMotoCapacity => 'Spaces for motorcycles';

  @override
  String get settingsCarOutOfService => 'Cars out of service';

  @override
  String get settingsMotoOutOfService => 'Motorcycles out of service';

  @override
  String get settingsOutOfServiceHint => 'Subtracted from the available spots';

  @override
  String get settingsOutOfServiceTooMany =>
      'It cannot exceed the configured capacity';

  @override
  String capacityOutOfService(int count) {
    return '$count out of service';
  }

  @override
  String get slotMaintenance => 'Maintenance';

  @override
  String get slotMaintenanceShort => 'Maint.';

  @override
  String get settingsKeyCapacity => 'Maximum cars leaving keys';

  @override
  String get settingsCapacityHint => '0 = no limit';

  @override
  String get errorParkingFull => 'No spaces left for this vehicle type';

  @override
  String get errorKeysFull => 'The maximum of cars leaving keys was reached';

  @override
  String get settingsEvidenceRetention => 'Evidence retention (days)';

  @override
  String get settingsEvidenceRetentionHint =>
      '0 = keep forever. Older photos are deleted automatically.';

  @override
  String get settingsWhatsappAuto => 'Automated WhatsApp';

  @override
  String get settingsWhatsappAutoHint =>
      'Sends notices through the WhatsApp API (requires server credentials). When off, WhatsApp opens on the device.';

  @override
  String get whatsappQueued => 'Message queued for WhatsApp';

  @override
  String get errorWhatsappDisabled =>
      'Automated WhatsApp is disabled for this site';

  @override
  String get settingsName => 'Name';

  @override
  String get settingsAddress => 'Address';

  @override
  String get settingsSchedule => 'Schedule';

  @override
  String get settingsPhone => 'Phone';

  @override
  String get settingsWebsite => 'Website';

  @override
  String get settingsWhatsapp => 'WhatsApp number';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get settingsLogoSection => 'Logo';

  @override
  String get settingsLogoPick => 'Choose logo';

  @override
  String get settingsWebsiteInvalid => 'Enter a valid URL';

  @override
  String get contactTitle => 'Contact';

  @override
  String get contactWhatsApp => 'WhatsApp';

  @override
  String get whatsappTooltip => 'Chat on WhatsApp';

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
  String get homeTodayEmpty => 'No activity yet today';

  @override
  String get homeToday => 'Today';

  @override
  String get homeTodayEntries => 'Entries';

  @override
  String get homeTodayExits => 'Exits';

  @override
  String get homeTodayCash => 'Cash';

  @override
  String get homeTodayPasses => 'Monthly passes';

  @override
  String get homeCapacityTitle => 'Parking capacity';

  @override
  String get homeCapacityCars => 'Cars and pickups';

  @override
  String get homeCapacityMotos => 'Motorcycles';

  @override
  String get homeCapacityKeys => 'Cars with keys';

  @override
  String homeReservedCount(int count) {
    return '$count held';
  }

  @override
  String homeReservationsActive(int count) {
    return '$count active holds';
  }

  @override
  String homeReservationsExpiring(int count) {
    return '$count expiring soon';
  }

  @override
  String get homeSeeReservations => 'See holds';

  @override
  String get homeNoLimit => 'no limit';

  @override
  String get homeInsideSeeAll => 'See all';

  @override
  String get slotBoardTitle => 'Space map';

  @override
  String slotBoardFree(int count) {
    return '$count free';
  }

  @override
  String get slotBoardAll => 'All';

  @override
  String get slotBoardCars => 'Cars';

  @override
  String get slotBoardMotos => 'Motorcycles';

  @override
  String get slotBoardHolds => 'Holds';

  @override
  String get slotBoardHeavy => 'Heavy';

  @override
  String get slotEstimateUnavailable => 'The fare could not be calculated';

  @override
  String get slotBoardEmpty => 'Set the parking spaces in Settings';

  @override
  String get slotBoardConfigure => 'Configure';

  @override
  String get slotBoardNoHolds => 'No active holds';

  @override
  String get slotFree => 'Free';

  @override
  String get slotOccupied => 'Occupied';

  @override
  String get slotReserved => 'Reserved';

  @override
  String get slotEstimate => 'Estimated fare';

  @override
  String get homeSummary => 'Summary';

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
  String checkInRepeat(String plate) {
    return 'Repeat entry $plate';
  }

  @override
  String checkInAlreadyInside(String plate) {
    return 'This vehicle is already inside ($plate). Check before registering it again.';
  }

  @override
  String get checkInLeftKeys => 'Leaves the keys';

  @override
  String get checkInLeftKeysHint => 'Kept at the front desk';

  @override
  String get checkInLeftKeysShort => 'Keys';

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
  String get markExit => 'Mark exit';

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
  String get checkOutClearSearch => 'Clear search';

  @override
  String get scanExitTooltip => 'Scan a QR to check out';

  @override
  String get scanQrTitle => 'Scan receipt';

  @override
  String get scanQrHint => 'Point the camera at the receipt QR code';

  @override
  String get scanQrTorch => 'Flashlight';

  @override
  String get scanQrCameraError =>
      'The camera could not start. Check the permission.';

  @override
  String get checkOutScanQr => 'Scan the receipt QR';

  @override
  String get checkOutQrUnreadable => 'The QR code could not be read';

  @override
  String checkOutQrNoSession(String plate) {
    return 'No open session for $plate';
  }

  @override
  String checkOutNoMatch(String query) {
    return 'No plate matches “$query”';
  }

  @override
  String get checkOutLongStay => 'Over 24 h';

  @override
  String checkOutEstimate(String amount) {
    return 'Estimated total: $amount';
  }

  @override
  String get checkOutPassCovered => 'Active monthly pass: no charge';

  @override
  String get checkOutReprintTicket => 'Reprint entry receipt';

  @override
  String get checkOutCharge => 'Charge';

  @override
  String checkOutChargeTooltip(String plate) {
    return 'Charge check-out for $plate';
  }

  @override
  String checkOutConfirm(String plate) {
    return 'Charge the check-out for vehicle $plate?';
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
  String get receiptPayment => 'Payment';

  @override
  String get receiptDiscount => 'Discount';

  @override
  String get checkOutSettlement => 'Settlement';

  @override
  String fareTime(String duration) {
    return 'Time: $duration';
  }

  @override
  String fareDays(int days) {
    return '$days days';
  }

  @override
  String fareDayHours(int hours, String rate) {
    return '$hours h × $rate (day)';
  }

  @override
  String fareNightHours(int hours, String rate) {
    return '$hours h × $rate (night)';
  }

  @override
  String fareDailyCap(String amount) {
    return 'Daily cap applied ($amount)';
  }

  @override
  String get fareTotal => 'Total due';

  @override
  String get slotBoardError => 'The space map could not be loaded';

  @override
  String get slotBoardRetry => 'Retry';

  @override
  String get paymentMethodTitle => 'Payment method';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentCard => 'Card';

  @override
  String get paymentTransfer => 'Transfer';

  @override
  String get paymentMonthlyPass => 'Monthly pass';

  @override
  String get paymentExempt => 'Exempt';

  @override
  String get lostTicket => 'Lost ticket';

  @override
  String get lostTicketHint => 'The full daily rate is charged.';

  @override
  String get lostTicketReason => 'Reason (lost ticket)';

  @override
  String get lostTicketReasonRequired => 'Enter the lost ticket reason';

  @override
  String get discountAmount => 'Discount (COP)';

  @override
  String get discountReason => 'Discount reason';

  @override
  String get discountReasonRequired => 'Enter the discount reason';

  @override
  String get paymentUnknown => 'Other';

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
  String get receiptNewCharge => 'New charge';

  @override
  String get receiptQrHint => 'Show this code at the exit to check out';

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
  String categorySpotsLeft(int count) {
    return '$count left';
  }

  @override
  String get categoryNoSpots => 'no spaces';

  @override
  String get categoriesEmpty => 'No categories yet';

  @override
  String get categoryNew => 'New category';

  @override
  String get categoryRename => 'Rename category';

  @override
  String categoryCapacity(int count) {
    return 'Capacity: $count';
  }

  @override
  String get categoryCapacityUnlimited => 'No capacity limit';

  @override
  String categoryCapacityTitle(String name) {
    return 'Capacity for $name';
  }

  @override
  String get categoryCapacityLabel => 'Capacity';

  @override
  String get errorCategoryFull => 'This category is full';

  @override
  String get homeFull => 'Full';

  @override
  String homeFullCategories(String names) {
    return 'Full categories: $names';
  }

  @override
  String reportsOccupancyOf(int open, int capacity) {
    return 'Vehicles inside: $open / $capacity';
  }

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
  String get vehiclesSearch => 'Search plate';

  @override
  String vehiclesNoMatch(String query) {
    return 'No vehicles match \"$query\"';
  }

  @override
  String vehicleCreated(String plate) {
    return 'Vehicle created: $plate';
  }

  @override
  String get vehicleCheckInAction => 'Register entry';

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
  String get usersFilterAll => 'All';

  @override
  String get usersFilterEmpty => 'No users match this filter';

  @override
  String get usersEmpty => 'No users yet';

  @override
  String get userNew => 'New user';

  @override
  String get userAddTooltip => 'Add user';

  @override
  String get userActions => 'Actions';

  @override
  String get userResetPin => 'Reset PIN';

  @override
  String userResetPinTitle(String name) {
    return 'New PIN for $name';
  }

  @override
  String get userNewPin => 'New PIN (6 digits)';

  @override
  String get userDelete => 'Delete user';

  @override
  String get userDeleteTitle => 'Delete user?';

  @override
  String userDeleteBody(String name) {
    return '$name\'s account will be removed. This cannot be undone.';
  }

  @override
  String userActiveLabel(String name) {
    return 'User active: $name';
  }

  @override
  String userDeactivated(String name) {
    return 'User $name deactivated';
  }

  @override
  String get pinInvalid => 'The PIN must have 6 digits';

  @override
  String get monthlyPassPendingTitle => 'Pending payments';

  @override
  String monthlyPassDue(String date) {
    return 'Due: $date';
  }

  @override
  String get monthlyPassWhatsapp => 'Notify via WhatsApp';

  @override
  String monthlyPassWhatsappMessage(String plate, String date) {
    return 'Hi, a reminder that the monthly pass for plate $plate expires on $date.';
  }

  @override
  String get monthlyPassStatusActive => 'Active';

  @override
  String get monthlyPassStatusUpcoming => 'Upcoming';

  @override
  String get monthlyPassStatusExpired => 'Expired';

  @override
  String get monthlyPassCharge => 'Collect';

  @override
  String get monthlyPassRenewalMethod => 'Renewal payment method';

  @override
  String get monthlyPassAutoRenew => 'Auto-renew';

  @override
  String get monthlyPassAutoRenewHint =>
      'Renews for the same period and amount on expiry';

  @override
  String get monthlyPassesTitle => 'Monthly passes';

  @override
  String monthlyPassesNoMatch(String query) {
    return 'No monthly pass matches “$query”';
  }

  @override
  String get monthlyPassCreated => 'Monthly pass created';

  @override
  String get monthlyPassDeleted => 'Monthly pass deleted';

  @override
  String get monthlyPassPaymentDone => 'Monthly pass payment recorded';

  @override
  String get monthlyPassRenew => 'Renew 30 days';

  @override
  String get monthlyPassRenewTitle => 'Renew this monthly pass?';

  @override
  String monthlyPassRenewBody(String date) {
    return 'It will be extended until $date, keeping the current amount.';
  }

  @override
  String get monthlyPassRenewed => 'Monthly pass renewed for 30 days';

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
  String get reportsAllLots => 'All sites';

  @override
  String get reportsAllLotsHint => 'Adds up every site\'s revenue';

  @override
  String reportsLotTickets(int count) {
    return '$count exits';
  }

  @override
  String reportsLotAverage(String amount) {
    return 'average $amount';
  }

  @override
  String reportsLotShare(int percent) {
    return '$percent% of total';
  }

  @override
  String get reportsByLot => 'Revenue by site';

  @override
  String get reportsToday => 'Today';

  @override
  String get reportsLast7 => '7 days';

  @override
  String get reportsLast30 => '30 days';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get lotSwitchTitle => 'Switch site';

  @override
  String lotSwitchTooltip(String site) {
    return 'Current site: $site. Tap to switch.';
  }

  @override
  String get reportsRangeTooltip => 'Change date range';

  @override
  String reportsVsPrevious(String percent) {
    return '$percent% vs. previous period';
  }

  @override
  String reportsPreviousTotal(String amount) {
    return 'Before: $amount';
  }

  @override
  String get reportsVariationLabel => 'Change vs. previous period';

  @override
  String get reportsPreviousLabel => 'Previous period';

  @override
  String get reportsExportCsv => 'Copy CSV';

  @override
  String get reportsCsvCopied => 'CSV copied to the clipboard';

  @override
  String get reportsTotalRevenue => 'Total revenue';

  @override
  String get reportsRevenueByDay => 'Revenue by day';

  @override
  String get reportsPassRevenue => 'Monthly pass revenue';

  @override
  String get reportsRevenueByPayment => 'Revenue by payment method';

  @override
  String get reportsTotalDiscounts => 'Discounts applied';

  @override
  String get reportsDiscountLog => 'Discount details';

  @override
  String reportsDiscountBy(String admin) {
    return 'by $admin';
  }

  @override
  String reportsDiscountedSessions(int count) {
    return '$count discounted check-outs';
  }

  @override
  String get reportsRevenueByCategory => 'Revenue by category';

  @override
  String get reportsWhatsapp => 'WhatsApp';

  @override
  String get reportsWhatsappSent => 'Sent';

  @override
  String get reportsWhatsappFailed => 'Failed';

  @override
  String get reportsWhatsappPending => 'Queued';

  @override
  String reportsWhatsappDay(int sent, int failed) {
    return '$sent sent · $failed failed';
  }

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
