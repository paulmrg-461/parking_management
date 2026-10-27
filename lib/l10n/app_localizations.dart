import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Application name shown in the task switcher and login.
  ///
  /// In es, this message translates to:
  /// **'Parqueadero'**
  String get appTitle;

  /// No description provided for @actionClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get actionClose;

  /// No description provided for @actionCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get actionSave;

  /// No description provided for @actionCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get actionCreate;

  /// No description provided for @actionDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get actionDelete;

  /// No description provided for @actionRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get actionRetry;

  /// No description provided for @actionUndo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get actionUndo;

  /// No description provided for @actionDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get actionDone;

  /// No description provided for @actionLoadMore.
  ///
  /// In es, this message translates to:
  /// **'Cargar más'**
  String get actionLoadMore;

  /// No description provided for @actionConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get actionConfirm;

  /// No description provided for @actionEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get actionEdit;

  /// No description provided for @themeMode.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @actionLogout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get actionLogout;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando'**
  String get loading;

  /// No description provided for @fieldRequired.
  ///
  /// In es, this message translates to:
  /// **'Campo obligatorio'**
  String get fieldRequired;

  /// No description provided for @notAvailable.
  ///
  /// In es, this message translates to:
  /// **'—'**
  String get notAvailable;

  /// No description provided for @errorNetwork.
  ///
  /// In es, this message translates to:
  /// **'No hay conexión con el servidor'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In es, this message translates to:
  /// **'El servidor no está disponible. Intenta de nuevo en un momento'**
  String get errorServer;

  /// No description provided for @errorAuth.
  ///
  /// In es, this message translates to:
  /// **'Usuario o PIN incorrectos'**
  String get errorAuth;

  /// No description provided for @errorForbidden.
  ///
  /// In es, this message translates to:
  /// **'No tienes permiso para realizar esta acción'**
  String get errorForbidden;

  /// No description provided for @errorSessionExpired.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión expiró. Vuelve a iniciar sesión'**
  String get errorSessionExpired;

  /// No description provided for @errorStorage.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la información en el dispositivo'**
  String get errorStorage;

  /// No description provided for @errorUnknown.
  ///
  /// In es, this message translates to:
  /// **'Ocurrió un error inesperado'**
  String get errorUnknown;

  /// No description provided for @errorRateLimited.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Intenta de nuevo en {minutes} min'**
  String errorRateLimited(int minutes);

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Intenta más tarde'**
  String get errorTooManyAttempts;

  /// No description provided for @errorNotFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontró el registro'**
  String get errorNotFound;

  /// No description provided for @errorConflict.
  ///
  /// In es, this message translates to:
  /// **'La operación entra en conflicto con los datos actuales'**
  String get errorConflict;

  /// No description provided for @errorInvalidData.
  ///
  /// In es, this message translates to:
  /// **'Los datos enviados no son válidos'**
  String get errorInvalidData;

  /// No description provided for @errorVehicleNotFound.
  ///
  /// In es, this message translates to:
  /// **'Vehículo no encontrado'**
  String get errorVehicleNotFound;

  /// No description provided for @errorCategoryNotFound.
  ///
  /// In es, this message translates to:
  /// **'Categoría no encontrada'**
  String get errorCategoryNotFound;

  /// No description provided for @errorTariffNotFound.
  ///
  /// In es, this message translates to:
  /// **'Tarifa no encontrada'**
  String get errorTariffNotFound;

  /// No description provided for @errorUserNotFound.
  ///
  /// In es, this message translates to:
  /// **'Usuario no encontrado'**
  String get errorUserNotFound;

  /// No description provided for @errorMonthlyPassNotFound.
  ///
  /// In es, this message translates to:
  /// **'Mensualidad no encontrada'**
  String get errorMonthlyPassNotFound;

  /// No description provided for @errorSessionNotFound.
  ///
  /// In es, this message translates to:
  /// **'La entrada ya no existe'**
  String get errorSessionNotFound;

  /// No description provided for @errorMissingHourlyTariff.
  ///
  /// In es, this message translates to:
  /// **'La categoría no tiene tarifa por hora configurada'**
  String get errorMissingHourlyTariff;

  /// No description provided for @errorDuplicateOpenSession.
  ///
  /// In es, this message translates to:
  /// **'Este vehículo ya está dentro del parqueadero'**
  String get errorDuplicateOpenSession;

  /// No description provided for @errorDuplicatePlate.
  ///
  /// In es, this message translates to:
  /// **'Ya existe un vehículo con esa placa'**
  String get errorDuplicatePlate;

  /// No description provided for @errorDuplicateCategory.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una categoría con ese nombre'**
  String get errorDuplicateCategory;

  /// No description provided for @errorDuplicateUsername.
  ///
  /// In es, this message translates to:
  /// **'Ese nombre de usuario ya existe'**
  String get errorDuplicateUsername;

  /// No description provided for @errorSessionAlreadyClosed.
  ///
  /// In es, this message translates to:
  /// **'Esta salida ya fue registrada'**
  String get errorSessionAlreadyClosed;

  /// No description provided for @errorVehicleNotRegistered.
  ///
  /// In es, this message translates to:
  /// **'Vehículo nuevo: selecciona una categoría'**
  String get errorVehicleNotRegistered;

  /// No description provided for @errorInvalidPhoto.
  ///
  /// In es, this message translates to:
  /// **'Las fotos deben ser imágenes JPEG o PNG'**
  String get errorInvalidPhoto;

  /// No description provided for @errorPhotoTooLarge.
  ///
  /// In es, this message translates to:
  /// **'Cada foto debe pesar 5 MB o menos'**
  String get errorPhotoTooLarge;

  /// No description provided for @errorTooManyPhotos.
  ///
  /// In es, this message translates to:
  /// **'Superaste el máximo de fotos por entrada'**
  String get errorTooManyPhotos;

  /// No description provided for @errorAdminRequired.
  ///
  /// In es, this message translates to:
  /// **'Solo un administrador puede hacer esto'**
  String get errorAdminRequired;

  /// No description provided for @errorIdempotency.
  ///
  /// In es, this message translates to:
  /// **'Esta operación ya se había enviado'**
  String get errorIdempotency;

  /// No description provided for @errorEmptyPlate.
  ///
  /// In es, this message translates to:
  /// **'Ingresa la placa'**
  String get errorEmptyPlate;

  /// No description provided for @errorOcrNoText.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la placa en la foto'**
  String get errorOcrNoText;

  /// No description provided for @errorScanUnavailable.
  ///
  /// In es, this message translates to:
  /// **'El escaneo de placas no está disponible aquí'**
  String get errorScanUnavailable;

  /// No description provided for @errorPendingSyncCheckOut.
  ///
  /// In es, this message translates to:
  /// **'Esta entrada aún no se ha sincronizado. Intenta cuando haya conexión'**
  String get errorPendingSyncCheckOut;

  /// No description provided for @errorMissingPendingPhoto.
  ///
  /// In es, this message translates to:
  /// **'Falta una foto de evidencia en cola'**
  String get errorMissingPendingPhoto;

  /// No description provided for @deferredLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar esta sección'**
  String get deferredLoadError;

  /// No description provided for @offlineBanner.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Los cambios se guardan y se sincronizarán al reconectar'**
  String get offlineBanner;

  /// No description provided for @syncPendingTooltip.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 cambio pendiente de sincronizar} other{{count} cambios pendientes de sincronizar}}'**
  String syncPendingTooltip(int count);

  /// No description provided for @syncPendingWithErrors.
  ///
  /// In es, this message translates to:
  /// **'{base} ({errors} con error)'**
  String syncPendingWithErrors(String base, int errors);

  /// No description provided for @syncSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambios sin sincronizar'**
  String get syncSheetTitle;

  /// No description provided for @syncNow.
  ///
  /// In es, this message translates to:
  /// **'Reintentar ahora'**
  String get syncNow;

  /// No description provided for @syncQueued.
  ///
  /// In es, this message translates to:
  /// **'{count} en cola, se reintentarán solos.'**
  String syncQueued(int count);

  /// No description provided for @syncDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar cambio'**
  String get syncDiscard;

  /// No description provided for @syncUnknownError.
  ///
  /// In es, this message translates to:
  /// **'Error desconocido'**
  String get syncUnknownError;

  /// No description provided for @entityVehicle.
  ///
  /// In es, this message translates to:
  /// **'Vehículo'**
  String get entityVehicle;

  /// No description provided for @entityTariff.
  ///
  /// In es, this message translates to:
  /// **'Tarifa'**
  String get entityTariff;

  /// No description provided for @entityCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get entityCategory;

  /// No description provided for @entityCheckIn.
  ///
  /// In es, this message translates to:
  /// **'Entrada'**
  String get entityCheckIn;

  /// No description provided for @entityCheckOut.
  ///
  /// In es, this message translates to:
  /// **'Salida'**
  String get entityCheckOut;

  /// No description provided for @entitySettings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get entitySettings;

  /// No description provided for @categoryFullHint.
  ///
  /// In es, this message translates to:
  /// **'Las categorías llenas aparecen deshabilitadas.'**
  String get categoryFullHint;

  /// No description provided for @navLots.
  ///
  /// In es, this message translates to:
  /// **'Sedes'**
  String get navLots;

  /// No description provided for @lotMembersTitle.
  ///
  /// In es, this message translates to:
  /// **'Miembros de {name}'**
  String lotMembersTitle(String name);

  /// No description provided for @lotMembersEmpty.
  ///
  /// In es, this message translates to:
  /// **'Esta sede no tiene usuarios'**
  String get lotMembersEmpty;

  /// No description provided for @userInactive.
  ///
  /// In es, this message translates to:
  /// **'inactivo'**
  String get userInactive;

  /// No description provided for @lotsTitle.
  ///
  /// In es, this message translates to:
  /// **'Sedes del parqueadero'**
  String get lotsTitle;

  /// No description provided for @navAudit.
  ///
  /// In es, this message translates to:
  /// **'Auditoría'**
  String get navAudit;

  /// No description provided for @navDiagnostics.
  ///
  /// In es, this message translates to:
  /// **'Diagnóstico'**
  String get navDiagnostics;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In es, this message translates to:
  /// **'Diagnóstico'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsWhatsapp.
  ///
  /// In es, this message translates to:
  /// **'WhatsApp'**
  String get diagnosticsWhatsapp;

  /// No description provided for @diagnosticsWhatsappPending.
  ///
  /// In es, this message translates to:
  /// **'En cola'**
  String get diagnosticsWhatsappPending;

  /// No description provided for @diagnosticsWhatsappFailedCount.
  ///
  /// In es, this message translates to:
  /// **'Fallidos'**
  String get diagnosticsWhatsappFailedCount;

  /// No description provided for @diagnosticsWhatsappSent.
  ///
  /// In es, this message translates to:
  /// **'Enviados (24 h)'**
  String get diagnosticsWhatsappSent;

  /// No description provided for @diagnosticsWhatsappEmpty.
  ///
  /// In es, this message translates to:
  /// **'Sin mensajes de WhatsApp en el periodo'**
  String get diagnosticsWhatsappEmpty;

  /// No description provided for @diagnosticsWhatsappAttempts.
  ///
  /// In es, this message translates to:
  /// **'{count} intentos'**
  String diagnosticsWhatsappAttempts(int count);

  /// No description provided for @diagnosticsSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get diagnosticsSystem;

  /// No description provided for @diagnosticsMigrations.
  ///
  /// In es, this message translates to:
  /// **'Migraciones aplicadas ({count})'**
  String diagnosticsMigrations(int count);

  /// No description provided for @diagnosticsLots.
  ///
  /// In es, this message translates to:
  /// **'Sedes activas: {active} de {total}'**
  String diagnosticsLots(int active, int total);

  /// No description provided for @diagnosticsOpenSessions.
  ///
  /// In es, this message translates to:
  /// **'Sesiones abiertas'**
  String get diagnosticsOpenSessions;

  /// No description provided for @diagnosticsStaleSessions.
  ///
  /// In es, this message translates to:
  /// **'Sesiones abiertas +24 h'**
  String get diagnosticsStaleSessions;

  /// No description provided for @diagnosticsOpenShifts.
  ///
  /// In es, this message translates to:
  /// **'Turnos abiertos +12 h'**
  String get diagnosticsOpenShifts;

  /// No description provided for @diagnosticsPendingPayments.
  ///
  /// In es, this message translates to:
  /// **'Pagos de mensualidad pendientes'**
  String get diagnosticsPendingPayments;

  /// No description provided for @diagnosticsReservations.
  ///
  /// In es, this message translates to:
  /// **'Reservas activas'**
  String get diagnosticsReservations;

  /// No description provided for @diagnosticsIdempotency.
  ///
  /// In es, this message translates to:
  /// **'Claves de idempotencia'**
  String get diagnosticsIdempotency;

  /// No description provided for @diagnosticsNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get diagnosticsNotifications;

  /// No description provided for @diagnosticsPendingPush.
  ///
  /// In es, this message translates to:
  /// **'Pendientes de push'**
  String get diagnosticsPendingPush;

  /// No description provided for @diagnosticsDeadPush.
  ///
  /// In es, this message translates to:
  /// **'Fallidas tras 3 intentos'**
  String get diagnosticsDeadPush;

  /// No description provided for @diagnosticsUnread.
  ///
  /// In es, this message translates to:
  /// **'Sin leer / total'**
  String get diagnosticsUnread;

  /// No description provided for @diagnosticsStorage.
  ///
  /// In es, this message translates to:
  /// **'Almacenamiento'**
  String get diagnosticsStorage;

  /// No description provided for @diagnosticsErrors.
  ///
  /// In es, this message translates to:
  /// **'Errores de la app ({count})'**
  String diagnosticsErrors(int count);

  /// No description provided for @diagnosticsErrorsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Sin errores reportados en los últimos 7 días'**
  String get diagnosticsErrorsEmpty;

  /// No description provided for @diagnosticsErrorDetail.
  ///
  /// In es, this message translates to:
  /// **'Detalle del error'**
  String get diagnosticsErrorDetail;

  /// No description provided for @auditExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get auditExport;

  /// No description provided for @auditExportPdf.
  ///
  /// In es, this message translates to:
  /// **'Exportar PDF'**
  String get auditExportPdf;

  /// No description provided for @auditExportCsv.
  ///
  /// In es, this message translates to:
  /// **'Copiar CSV'**
  String get auditExportCsv;

  /// No description provided for @auditCopied.
  ///
  /// In es, this message translates to:
  /// **'CSV copiado al portapapeles'**
  String get auditCopied;

  /// No description provided for @auditActor.
  ///
  /// In es, this message translates to:
  /// **'Actor'**
  String get auditActor;

  /// No description provided for @auditAllActors.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get auditAllActors;

  /// No description provided for @auditTitle.
  ///
  /// In es, this message translates to:
  /// **'Auditoría'**
  String get auditTitle;

  /// No description provided for @auditTable.
  ///
  /// In es, this message translates to:
  /// **'Tabla'**
  String get auditTable;

  /// No description provided for @auditAllTables.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get auditAllTables;

  /// No description provided for @auditFilterDates.
  ///
  /// In es, this message translates to:
  /// **'Filtrar por fecha'**
  String get auditFilterDates;

  /// No description provided for @auditEmpty.
  ///
  /// In es, this message translates to:
  /// **'Sin cambios registrados'**
  String get auditEmpty;

  /// No description provided for @auditChangesTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambios'**
  String get auditChangesTitle;

  /// No description provided for @lotAdd.
  ///
  /// In es, this message translates to:
  /// **'Nueva sede'**
  String get lotAdd;

  /// No description provided for @lotCode.
  ///
  /// In es, this message translates to:
  /// **'Código (2-10 letras/números)'**
  String get lotCode;

  /// No description provided for @lotLabel.
  ///
  /// In es, this message translates to:
  /// **'Sede'**
  String get lotLabel;

  /// No description provided for @lotName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la sede'**
  String get lotName;

  /// No description provided for @lotAddress.
  ///
  /// In es, this message translates to:
  /// **'Dirección (opcional)'**
  String get lotAddress;

  /// No description provided for @lotsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay sedes'**
  String get lotsEmpty;

  /// No description provided for @lotMembers.
  ///
  /// In es, this message translates to:
  /// **'{count} usuarios'**
  String lotMembers(int count);

  /// No description provided for @navReservations.
  ///
  /// In es, this message translates to:
  /// **'Reservas'**
  String get navReservations;

  /// No description provided for @reservationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Reservas de cupo'**
  String get reservationsTitle;

  /// No description provided for @reservationAdd.
  ///
  /// In es, this message translates to:
  /// **'Nueva reserva'**
  String get reservationAdd;

  /// No description provided for @reservationCreated.
  ///
  /// In es, this message translates to:
  /// **'Reserva creada'**
  String get reservationCreated;

  /// No description provided for @reservationCancelled.
  ///
  /// In es, this message translates to:
  /// **'Reserva cancelada'**
  String get reservationCancelled;

  /// No description provided for @reservationsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay reservas activas'**
  String get reservationsEmpty;

  /// No description provided for @reservationExpiresIn.
  ///
  /// In es, this message translates to:
  /// **'Vence en {duration}'**
  String reservationExpiresIn(String duration);

  /// No description provided for @reservationQuick2h.
  ///
  /// In es, this message translates to:
  /// **'+2 h'**
  String get reservationQuick2h;

  /// No description provided for @reservationQuick4h.
  ///
  /// In es, this message translates to:
  /// **'+4 h'**
  String get reservationQuick4h;

  /// No description provided for @reservationEndOfDay.
  ///
  /// In es, this message translates to:
  /// **'Fin del día'**
  String get reservationEndOfDay;

  /// No description provided for @reservationUntil.
  ///
  /// In es, this message translates to:
  /// **'Hasta {when}'**
  String reservationUntil(String when);

  /// No description provided for @reservationUntilLabel.
  ///
  /// In es, this message translates to:
  /// **'Reservar hasta {when}'**
  String reservationUntilLabel(String when);

  /// No description provided for @reservationNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas (opcional)'**
  String get reservationNotes;

  /// No description provided for @reservationCheckIn.
  ///
  /// In es, this message translates to:
  /// **'Registrar entrada'**
  String get reservationCheckIn;

  /// No description provided for @reservationCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar reserva'**
  String get reservationCancel;

  /// No description provided for @reservationCancelTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cancelar la reserva?'**
  String get reservationCancelTitle;

  /// No description provided for @reservationCancelBody.
  ///
  /// In es, this message translates to:
  /// **'Se liberará el cupo reservado para {plate}.'**
  String reservationCancelBody(String plate);

  /// No description provided for @sidebarCollapse.
  ///
  /// In es, this message translates to:
  /// **'Contraer menú'**
  String get sidebarCollapse;

  /// No description provided for @sidebarExpand.
  ///
  /// In es, this message translates to:
  /// **'Expandir menú'**
  String get sidebarExpand;

  /// No description provided for @navGroupOperation.
  ///
  /// In es, this message translates to:
  /// **'Operación'**
  String get navGroupOperation;

  /// No description provided for @navGroupManagement.
  ///
  /// In es, this message translates to:
  /// **'Gestión'**
  String get navGroupManagement;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navCheckIn.
  ///
  /// In es, this message translates to:
  /// **'Entrada'**
  String get navCheckIn;

  /// No description provided for @navCheckOut.
  ///
  /// In es, this message translates to:
  /// **'Salida'**
  String get navCheckOut;

  /// No description provided for @navVehicles.
  ///
  /// In es, this message translates to:
  /// **'Vehículos'**
  String get navVehicles;

  /// No description provided for @navTariffs.
  ///
  /// In es, this message translates to:
  /// **'Tarifas'**
  String get navTariffs;

  /// No description provided for @navCategories.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get navCategories;

  /// No description provided for @navMonthlyPasses.
  ///
  /// In es, this message translates to:
  /// **'Mensualidades'**
  String get navMonthlyPasses;

  /// No description provided for @navUsers.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get navUsers;

  /// No description provided for @navReports.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get navReports;

  /// No description provided for @navSettings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get navSettings;

  /// No description provided for @navContact.
  ///
  /// In es, this message translates to:
  /// **'Contacto'**
  String get navContact;

  /// No description provided for @navNotifications.
  ///
  /// In es, this message translates to:
  /// **'Avisos'**
  String get navNotifications;

  /// No description provided for @webPushTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones del navegador'**
  String get webPushTitle;

  /// No description provided for @webPushSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Recibe avisos aunque la pestaña esté cerrada.'**
  String get webPushSubtitle;

  /// No description provided for @webPushDenied.
  ///
  /// In es, this message translates to:
  /// **'El navegador no dio permiso para las notificaciones'**
  String get webPushDenied;

  /// No description provided for @notificationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay notificaciones'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMarkAll.
  ///
  /// In es, this message translates to:
  /// **'Marcar todo leído'**
  String get notificationsMarkAll;

  /// No description provided for @navHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get navHistory;

  /// No description provided for @homeShift.
  ///
  /// In es, this message translates to:
  /// **'Turno / Caja'**
  String get homeShift;

  /// No description provided for @checkOutNoShift.
  ///
  /// In es, this message translates to:
  /// **'No hay turno abierto: este cobro no entrará en el arqueo.'**
  String get checkOutNoShift;

  /// No description provided for @shiftUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Turno no disponible'**
  String get shiftUnavailable;

  /// No description provided for @shiftOffline.
  ///
  /// In es, this message translates to:
  /// **'Necesitas conexión para operar la caja y el arqueo.'**
  String get shiftOffline;

  /// No description provided for @shiftHistoryFilter.
  ///
  /// In es, this message translates to:
  /// **'Filtrar por fecha'**
  String get shiftHistoryFilter;

  /// No description provided for @shiftHistoryClearFilter.
  ///
  /// In es, this message translates to:
  /// **'Quitar filtro'**
  String get shiftHistoryClearFilter;

  /// No description provided for @shiftHistoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay turnos en el rango seleccionado'**
  String get shiftHistoryEmpty;

  /// No description provided for @shiftCardSales.
  ///
  /// In es, this message translates to:
  /// **'Ventas con tarjeta'**
  String get shiftCardSales;

  /// No description provided for @shiftTransferSales.
  ///
  /// In es, this message translates to:
  /// **'Ventas por transferencia'**
  String get shiftTransferSales;

  /// No description provided for @shiftPassSales.
  ///
  /// In es, this message translates to:
  /// **'Mensualidades'**
  String get shiftPassSales;

  /// No description provided for @shiftSessionCount.
  ///
  /// In es, this message translates to:
  /// **'Salidas cobradas'**
  String get shiftSessionCount;

  /// No description provided for @shiftCashMovements.
  ///
  /// In es, this message translates to:
  /// **'Movimientos de caja'**
  String get shiftCashMovements;

  /// No description provided for @shiftReconciliation.
  ///
  /// In es, this message translates to:
  /// **'Arqueo'**
  String get shiftReconciliation;

  /// No description provided for @shiftNotesTitle.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get shiftNotesTitle;

  /// No description provided for @actionExportPdf.
  ///
  /// In es, this message translates to:
  /// **'Exportar PDF'**
  String get actionExportPdf;

  /// No description provided for @actionShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get actionShare;

  /// No description provided for @shiftTitle.
  ///
  /// In es, this message translates to:
  /// **'Turno / Caja'**
  String get shiftTitle;

  /// No description provided for @shiftNoOpen.
  ///
  /// In es, this message translates to:
  /// **'No hay turno abierto'**
  String get shiftNoOpen;

  /// No description provided for @shiftOpeningFloat.
  ///
  /// In es, this message translates to:
  /// **'Base inicial (COP)'**
  String get shiftOpeningFloat;

  /// No description provided for @shiftOpen.
  ///
  /// In es, this message translates to:
  /// **'Abrir turno'**
  String get shiftOpen;

  /// No description provided for @shiftOpenTitle.
  ///
  /// In es, this message translates to:
  /// **'Turno abierto'**
  String get shiftOpenTitle;

  /// No description provided for @shiftOpenedDone.
  ///
  /// In es, this message translates to:
  /// **'Turno abierto correctamente'**
  String get shiftOpenedDone;

  /// No description provided for @shiftClosedDone.
  ///
  /// In es, this message translates to:
  /// **'Turno cerrado correctamente'**
  String get shiftClosedDone;

  /// No description provided for @shiftMovementDone.
  ///
  /// In es, this message translates to:
  /// **'Movimiento de caja registrado'**
  String get shiftMovementDone;

  /// No description provided for @shiftAdjustedDone.
  ///
  /// In es, this message translates to:
  /// **'Cierre del turno corregido'**
  String get shiftAdjustedDone;

  /// No description provided for @shiftOpenedAt.
  ///
  /// In es, this message translates to:
  /// **'Abierto: {time}'**
  String shiftOpenedAt(String time);

  /// No description provided for @shiftSales.
  ///
  /// In es, this message translates to:
  /// **'Ventas'**
  String get shiftSales;

  /// No description provided for @shiftCashSales.
  ///
  /// In es, this message translates to:
  /// **'Ventas en efectivo'**
  String get shiftCashSales;

  /// No description provided for @shiftWithdrawals.
  ///
  /// In es, this message translates to:
  /// **'Retiros'**
  String get shiftWithdrawals;

  /// No description provided for @shiftDeposits.
  ///
  /// In es, this message translates to:
  /// **'Ingresos de efectivo'**
  String get shiftDeposits;

  /// No description provided for @shiftDiscounts.
  ///
  /// In es, this message translates to:
  /// **'Descuentos'**
  String get shiftDiscounts;

  /// No description provided for @shiftPassPayments.
  ///
  /// In es, this message translates to:
  /// **'Mensualidades cobradas'**
  String get shiftPassPayments;

  /// No description provided for @shiftPassCash.
  ///
  /// In es, this message translates to:
  /// **'Mensualidades en efectivo'**
  String get shiftPassCash;

  /// No description provided for @shiftExpectedCash.
  ///
  /// In es, this message translates to:
  /// **'Efectivo esperado'**
  String get shiftExpectedCash;

  /// No description provided for @shiftSessions.
  ///
  /// In es, this message translates to:
  /// **'Salidas'**
  String get shiftSessions;

  /// No description provided for @shiftWithdraw.
  ///
  /// In es, this message translates to:
  /// **'Retirar efectivo'**
  String get shiftWithdraw;

  /// No description provided for @shiftDeposit.
  ///
  /// In es, this message translates to:
  /// **'Ingresar efectivo'**
  String get shiftDeposit;

  /// No description provided for @shiftClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar turno'**
  String get shiftClose;

  /// No description provided for @shiftDifferenceConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'El arqueo no cuadra'**
  String get shiftDifferenceConfirmTitle;

  /// No description provided for @shiftDifferenceConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Diferencia de {amount} frente al efectivo esperado. ¿Cerrar el turno igualmente?'**
  String shiftDifferenceConfirmBody(String amount);

  /// No description provided for @shiftClosedTitle.
  ///
  /// In es, this message translates to:
  /// **'Turno cerrado'**
  String get shiftClosedTitle;

  /// No description provided for @shiftAdjust.
  ///
  /// In es, this message translates to:
  /// **'Corregir cierre de turno'**
  String get shiftAdjust;

  /// No description provided for @shiftCountedCash.
  ///
  /// In es, this message translates to:
  /// **'Efectivo contado'**
  String get shiftCountedCash;

  /// No description provided for @shiftDifference.
  ///
  /// In es, this message translates to:
  /// **'Diferencia'**
  String get shiftDifference;

  /// No description provided for @shiftNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get shiftNotes;

  /// No description provided for @shiftReason.
  ///
  /// In es, this message translates to:
  /// **'Motivo'**
  String get shiftReason;

  /// No description provided for @shiftHistory.
  ///
  /// In es, this message translates to:
  /// **'Turnos recientes'**
  String get shiftHistory;

  /// No description provided for @errorShiftAlreadyOpen.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes un turno abierto'**
  String get errorShiftAlreadyOpen;

  /// No description provided for @errorNoOpenShift.
  ///
  /// In es, this message translates to:
  /// **'No hay un turno abierto'**
  String get errorNoOpenShift;

  /// No description provided for @errorShiftNotFound.
  ///
  /// In es, this message translates to:
  /// **'Turno no encontrado'**
  String get errorShiftNotFound;

  /// No description provided for @errorLastAdmin.
  ///
  /// In es, this message translates to:
  /// **'No puedes dejar el sistema sin administradores'**
  String get errorLastAdmin;

  /// No description provided for @errorCannotDeleteSelf.
  ///
  /// In es, this message translates to:
  /// **'No puedes eliminar tu propia cuenta'**
  String get errorCannotDeleteSelf;

  /// No description provided for @errorPaymentNotFound.
  ///
  /// In es, this message translates to:
  /// **'Pago no encontrado'**
  String get errorPaymentNotFound;

  /// No description provided for @errorPaymentAlreadyProcessed.
  ///
  /// In es, this message translates to:
  /// **'Este pago ya fue procesado'**
  String get errorPaymentAlreadyProcessed;

  /// No description provided for @errorShiftStillOpen.
  ///
  /// In es, this message translates to:
  /// **'El turno sigue abierto'**
  String get errorShiftStillOpen;

  /// No description provided for @errorShiftAdjustReason.
  ///
  /// In es, this message translates to:
  /// **'Indica el motivo de la corrección'**
  String get errorShiftAdjustReason;

  /// No description provided for @errorInvalidOpeningFloat.
  ///
  /// In es, this message translates to:
  /// **'La base inicial no es válida'**
  String get errorInvalidOpeningFloat;

  /// No description provided for @errorInvalidCountedCash.
  ///
  /// In es, this message translates to:
  /// **'El efectivo contado no es válido'**
  String get errorInvalidCountedCash;

  /// No description provided for @errorInvalidCashMovement.
  ///
  /// In es, this message translates to:
  /// **'El movimiento de caja no es válido'**
  String get errorInvalidCashMovement;

  /// No description provided for @errorCashMovementReason.
  ///
  /// In es, this message translates to:
  /// **'Indica el motivo del movimiento'**
  String get errorCashMovementReason;

  /// No description provided for @errorInvalidDiscount.
  ///
  /// In es, this message translates to:
  /// **'El descuento no es válido'**
  String get errorInvalidDiscount;

  /// No description provided for @errorDiscountReason.
  ///
  /// In es, this message translates to:
  /// **'Indica el motivo del descuento'**
  String get errorDiscountReason;

  /// No description provided for @errorVehicleBlacklisted.
  ///
  /// In es, this message translates to:
  /// **'Este vehículo está bloqueado; un administrador debe desbloquearlo'**
  String get errorVehicleBlacklisted;

  /// No description provided for @vehiclePhone.
  ///
  /// In es, this message translates to:
  /// **'Teléfono del cliente'**
  String get vehiclePhone;

  /// No description provided for @vehiclePhoneHint.
  ///
  /// In es, this message translates to:
  /// **'+57 300 111 2233'**
  String get vehiclePhoneHint;

  /// No description provided for @vehiclePhoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Teléfono para avisos'**
  String get vehiclePhoneTitle;

  /// No description provided for @vehicleAddPhone.
  ///
  /// In es, this message translates to:
  /// **'Agregar teléfono'**
  String get vehicleAddPhone;

  /// No description provided for @vehicleEditPhone.
  ///
  /// In es, this message translates to:
  /// **'Editar teléfono'**
  String get vehicleEditPhone;

  /// No description provided for @vehicleSendWhatsapp.
  ///
  /// In es, this message translates to:
  /// **'Enviar recibo por WhatsApp'**
  String get vehicleSendWhatsapp;

  /// No description provided for @vehicleWhatsappReady.
  ///
  /// In es, this message translates to:
  /// **'Hola, tu vehículo {plate} está listo para retirar.'**
  String vehicleWhatsappReady(String plate);

  /// No description provided for @vehicleChargeAction.
  ///
  /// In es, this message translates to:
  /// **'Cobrar en caja'**
  String get vehicleChargeAction;

  /// No description provided for @vehicleWhatsappReadyAction.
  ///
  /// In es, this message translates to:
  /// **'Avisar que está listo'**
  String get vehicleWhatsappReadyAction;

  /// No description provided for @vehicleWhatsappReceipt.
  ///
  /// In es, this message translates to:
  /// **'Hola, te compartimos el recibo del vehículo {plate}:'**
  String vehicleWhatsappReceipt(String plate);

  /// No description provided for @vehicleWhatsappHello.
  ///
  /// In es, this message translates to:
  /// **'Hola, te escribimos del parqueadero por el vehículo {plate}.'**
  String vehicleWhatsappHello(String plate);

  /// No description provided for @vehicleWhatsappThanks.
  ///
  /// In es, this message translates to:
  /// **'¡Gracias por tu visita!'**
  String get vehicleWhatsappThanks;

  /// No description provided for @errorInvalidPhone.
  ///
  /// In es, this message translates to:
  /// **'Escribe un teléfono válido (7 a 15 dígitos)'**
  String get errorInvalidPhone;

  /// No description provided for @errorWhatsappUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir WhatsApp en este dispositivo'**
  String get errorWhatsappUnavailable;

  /// No description provided for @vehicleNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas del vehículo'**
  String get vehicleNotes;

  /// No description provided for @vehicleNotesHint.
  ///
  /// In es, this message translates to:
  /// **'Rayones, incidentes, acuerdos…'**
  String get vehicleNotesHint;

  /// No description provided for @vehicleAddNotes.
  ///
  /// In es, this message translates to:
  /// **'Agregar nota'**
  String get vehicleAddNotes;

  /// No description provided for @vehicleEditNotes.
  ///
  /// In es, this message translates to:
  /// **'Editar nota'**
  String get vehicleEditNotes;

  /// No description provided for @vehicleBlacklist.
  ///
  /// In es, this message translates to:
  /// **'Bloquear vehículo'**
  String get vehicleBlacklist;

  /// No description provided for @vehicleUnblock.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get vehicleUnblock;

  /// No description provided for @vehicleBlacklisted.
  ///
  /// In es, this message translates to:
  /// **'Bloqueado'**
  String get vehicleBlacklisted;

  /// No description provided for @vehicleBlacklistTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Bloquear vehículo?'**
  String get vehicleBlacklistTitle;

  /// No description provided for @vehicleBlacklistBody.
  ///
  /// In es, this message translates to:
  /// **'{plate} no podrá ingresar hasta que un administrador lo desbloquee.'**
  String vehicleBlacklistBody(String plate);

  /// No description provided for @vehicleUnblockTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Desbloquear vehículo?'**
  String get vehicleUnblockTitle;

  /// No description provided for @vehicleUnblockBody.
  ///
  /// In es, this message translates to:
  /// **'{plate} podrá volver a ingresar al parqueadero.'**
  String vehicleUnblockBody(String plate);

  /// No description provided for @vehicleHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de vehículo'**
  String get vehicleHistoryTitle;

  /// No description provided for @vehicleHistoryPrompt.
  ///
  /// In es, this message translates to:
  /// **'Busca una placa para ver sus entradas y salidas'**
  String get vehicleHistoryPrompt;

  /// No description provided for @vehicleHistoryVisits.
  ///
  /// In es, this message translates to:
  /// **'Visitas'**
  String get vehicleHistoryVisits;

  /// No description provided for @vehicleHistoryTotalSpent.
  ///
  /// In es, this message translates to:
  /// **'Total pagado'**
  String get vehicleHistoryTotalSpent;

  /// No description provided for @vehicleHistoryAllLots.
  ///
  /// In es, this message translates to:
  /// **'Todas las sedes'**
  String get vehicleHistoryAllLots;

  /// No description provided for @vehicleHistoryCurrentLotVisits.
  ///
  /// In es, this message translates to:
  /// **'En esta sede: {count}'**
  String vehicleHistoryCurrentLotVisits(int count);

  /// No description provided for @actionReprintTicket.
  ///
  /// In es, this message translates to:
  /// **'Reimprimir ticket'**
  String get actionReprintTicket;

  /// No description provided for @vehicleHistorySessions.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get vehicleHistorySessions;

  /// No description provided for @vehicleHistoryNoSessions.
  ///
  /// In es, this message translates to:
  /// **'Sin movimientos registrados'**
  String get vehicleHistoryNoSessions;

  /// No description provided for @vehicleHistoryDuration.
  ///
  /// In es, this message translates to:
  /// **'Duración: {duration}'**
  String vehicleHistoryDuration(String duration);

  /// No description provided for @vehicleHistoryOpen.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get vehicleHistoryOpen;

  /// No description provided for @navMore.
  ///
  /// In es, this message translates to:
  /// **'Más'**
  String get navMore;

  /// No description provided for @navMoreTooltip.
  ///
  /// In es, this message translates to:
  /// **'Más secciones de gestión'**
  String get navMoreTooltip;

  /// No description provided for @settingsDiscardTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar cambios?'**
  String get settingsDiscardTitle;

  /// No description provided for @settingsDiscardBody.
  ///
  /// In es, this message translates to:
  /// **'Hay cambios sin guardar en la configuración.'**
  String get settingsDiscardBody;

  /// No description provided for @settingsDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get settingsDiscard;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuración del parqueadero'**
  String get settingsTitle;

  /// No description provided for @settingsCarCapacity.
  ///
  /// In es, this message translates to:
  /// **'Espacios para carros y camionetas'**
  String get settingsCarCapacity;

  /// No description provided for @settingsMotoCapacity.
  ///
  /// In es, this message translates to:
  /// **'Espacios para motos'**
  String get settingsMotoCapacity;

  /// No description provided for @settingsKeyCapacity.
  ///
  /// In es, this message translates to:
  /// **'Máximo de vehículos con llaves'**
  String get settingsKeyCapacity;

  /// No description provided for @settingsCapacityHint.
  ///
  /// In es, this message translates to:
  /// **'0 = sin límite'**
  String get settingsCapacityHint;

  /// No description provided for @errorParkingFull.
  ///
  /// In es, this message translates to:
  /// **'No hay espacios disponibles para este tipo de vehículo'**
  String get errorParkingFull;

  /// No description provided for @errorKeysFull.
  ///
  /// In es, this message translates to:
  /// **'Se alcanzó el máximo de vehículos que pueden dejar las llaves'**
  String get errorKeysFull;

  /// No description provided for @settingsEvidenceRetention.
  ///
  /// In es, this message translates to:
  /// **'Retención de evidencias (días)'**
  String get settingsEvidenceRetention;

  /// No description provided for @settingsEvidenceRetentionHint.
  ///
  /// In es, this message translates to:
  /// **'0 = conservar siempre. Las fotos más antiguas se borran automáticamente.'**
  String get settingsEvidenceRetentionHint;

  /// No description provided for @settingsWhatsappAuto.
  ///
  /// In es, this message translates to:
  /// **'WhatsApp automático'**
  String get settingsWhatsappAuto;

  /// No description provided for @settingsWhatsappAutoHint.
  ///
  /// In es, this message translates to:
  /// **'Envía los avisos por la API de WhatsApp (requiere credenciales en el servidor). Si está apagado, se abre WhatsApp en el teléfono.'**
  String get settingsWhatsappAutoHint;

  /// No description provided for @whatsappQueued.
  ///
  /// In es, this message translates to:
  /// **'Mensaje en cola de WhatsApp'**
  String get whatsappQueued;

  /// No description provided for @errorWhatsappDisabled.
  ///
  /// In es, this message translates to:
  /// **'El WhatsApp automático está desactivado en esta sede'**
  String get errorWhatsappDisabled;

  /// No description provided for @settingsName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get settingsName;

  /// No description provided for @settingsAddress.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get settingsAddress;

  /// No description provided for @settingsSchedule.
  ///
  /// In es, this message translates to:
  /// **'Horario'**
  String get settingsSchedule;

  /// No description provided for @settingsPhone.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get settingsPhone;

  /// No description provided for @settingsWebsite.
  ///
  /// In es, this message translates to:
  /// **'Sitio web'**
  String get settingsWebsite;

  /// No description provided for @settingsWhatsapp.
  ///
  /// In es, this message translates to:
  /// **'Número de WhatsApp'**
  String get settingsWhatsapp;

  /// No description provided for @settingsSaved.
  ///
  /// In es, this message translates to:
  /// **'Configuración guardada'**
  String get settingsSaved;

  /// No description provided for @settingsLogoSection.
  ///
  /// In es, this message translates to:
  /// **'Logo'**
  String get settingsLogoSection;

  /// No description provided for @settingsLogoPick.
  ///
  /// In es, this message translates to:
  /// **'Elegir logo'**
  String get settingsLogoPick;

  /// No description provided for @settingsWebsiteInvalid.
  ///
  /// In es, this message translates to:
  /// **'Ingresa una URL válida'**
  String get settingsWebsiteInvalid;

  /// No description provided for @contactTitle.
  ///
  /// In es, this message translates to:
  /// **'Contacto'**
  String get contactTitle;

  /// No description provided for @contactWhatsApp.
  ///
  /// In es, this message translates to:
  /// **'WhatsApp'**
  String get contactWhatsApp;

  /// No description provided for @whatsappTooltip.
  ///
  /// In es, this message translates to:
  /// **'Escribir por WhatsApp'**
  String get whatsappTooltip;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para continuar'**
  String get loginSubtitle;

  /// No description provided for @loginUsername.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get loginUsername;

  /// No description provided for @loginPin.
  ///
  /// In es, this message translates to:
  /// **'PIN'**
  String get loginPin;

  /// No description provided for @loginSubmit.
  ///
  /// In es, this message translates to:
  /// **'Ingresar'**
  String get loginSubmit;

  /// No description provided for @loginFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión'**
  String get loginFailed;

  /// No description provided for @homeGreeting.
  ///
  /// In es, this message translates to:
  /// **'Hola, {name}'**
  String homeGreeting(String name);

  /// No description provided for @roleAdmin.
  ///
  /// In es, this message translates to:
  /// **'Administrador'**
  String get roleAdmin;

  /// No description provided for @roleOperator.
  ///
  /// In es, this message translates to:
  /// **'Operador'**
  String get roleOperator;

  /// No description provided for @homeTodayEmpty.
  ///
  /// In es, this message translates to:
  /// **'Sin movimientos hoy'**
  String get homeTodayEmpty;

  /// No description provided for @homeToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get homeToday;

  /// No description provided for @homeTodayEntries.
  ///
  /// In es, this message translates to:
  /// **'Entradas'**
  String get homeTodayEntries;

  /// No description provided for @homeTodayExits.
  ///
  /// In es, this message translates to:
  /// **'Salidas'**
  String get homeTodayExits;

  /// No description provided for @homeTodayCash.
  ///
  /// In es, this message translates to:
  /// **'Efectivo'**
  String get homeTodayCash;

  /// No description provided for @homeTodayPasses.
  ///
  /// In es, this message translates to:
  /// **'Mensualidades'**
  String get homeTodayPasses;

  /// No description provided for @homeCapacityTitle.
  ///
  /// In es, this message translates to:
  /// **'Capacidad del parqueadero'**
  String get homeCapacityTitle;

  /// No description provided for @homeCapacityCars.
  ///
  /// In es, this message translates to:
  /// **'Carros y camionetas'**
  String get homeCapacityCars;

  /// No description provided for @homeCapacityMotos.
  ///
  /// In es, this message translates to:
  /// **'Motos'**
  String get homeCapacityMotos;

  /// No description provided for @homeCapacityKeys.
  ///
  /// In es, this message translates to:
  /// **'Vehículos con llaves'**
  String get homeCapacityKeys;

  /// No description provided for @homeReservedCount.
  ///
  /// In es, this message translates to:
  /// **'{count} reservados'**
  String homeReservedCount(int count);

  /// No description provided for @homeNoLimit.
  ///
  /// In es, this message translates to:
  /// **'sin límite'**
  String get homeNoLimit;

  /// No description provided for @homeInsideSeeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get homeInsideSeeAll;

  /// No description provided for @homeSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get homeSummary;

  /// No description provided for @homeOccupancy.
  ///
  /// In es, this message translates to:
  /// **'Vehículos dentro'**
  String get homeOccupancy;

  /// No description provided for @homeOccupancyUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Ocupación no disponible'**
  String get homeOccupancyUnavailable;

  /// No description provided for @homeEntryHint.
  ///
  /// In es, this message translates to:
  /// **'Registrar un vehículo que llega'**
  String get homeEntryHint;

  /// No description provided for @homeExitHint.
  ///
  /// In es, this message translates to:
  /// **'Cobrar y cerrar una estadía'**
  String get homeExitHint;

  /// No description provided for @homeManagement.
  ///
  /// In es, this message translates to:
  /// **'Gestión'**
  String get homeManagement;

  /// No description provided for @homeRefreshTooltip.
  ///
  /// In es, this message translates to:
  /// **'Actualizar ocupación'**
  String get homeRefreshTooltip;

  /// No description provided for @plateLabel.
  ///
  /// In es, this message translates to:
  /// **'Placa'**
  String get plateLabel;

  /// No description provided for @plateHint.
  ///
  /// In es, this message translates to:
  /// **'ABC123'**
  String get plateHint;

  /// No description provided for @plateScanTooltip.
  ///
  /// In es, this message translates to:
  /// **'Escanear placa con la cámara'**
  String get plateScanTooltip;

  /// No description provided for @plateDetected.
  ///
  /// In es, this message translates to:
  /// **'Placa detectada: {plate}'**
  String plateDetected(String plate);

  /// No description provided for @checkInTitle.
  ///
  /// In es, this message translates to:
  /// **'Registrar entrada'**
  String get checkInTitle;

  /// No description provided for @lookupLoading.
  ///
  /// In es, this message translates to:
  /// **'Buscando vehículo'**
  String get lookupLoading;

  /// No description provided for @lookupError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo consultar el vehículo: {message}'**
  String lookupError(String message);

  /// No description provided for @registeredVehicle.
  ///
  /// In es, this message translates to:
  /// **'Vehículo registrado'**
  String get registeredVehicle;

  /// No description provided for @newVehicle.
  ///
  /// In es, this message translates to:
  /// **'Vehículo nuevo'**
  String get newVehicle;

  /// No description provided for @fieldCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get fieldCategory;

  /// No description provided for @fieldColor.
  ///
  /// In es, this message translates to:
  /// **'Color'**
  String get fieldColor;

  /// No description provided for @fieldBrand.
  ///
  /// In es, this message translates to:
  /// **'Marca'**
  String get fieldBrand;

  /// No description provided for @fieldPlate.
  ///
  /// In es, this message translates to:
  /// **'Placa'**
  String get fieldPlate;

  /// No description provided for @fieldName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get fieldName;

  /// No description provided for @fieldVehicle.
  ///
  /// In es, this message translates to:
  /// **'Vehículo'**
  String get fieldVehicle;

  /// No description provided for @fieldAmount.
  ///
  /// In es, this message translates to:
  /// **'Valor (COP)'**
  String get fieldAmount;

  /// No description provided for @fieldType.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get fieldType;

  /// No description provided for @fieldStartDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha de inicio'**
  String get fieldStartDate;

  /// No description provided for @fieldEndDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha de fin'**
  String get fieldEndDate;

  /// No description provided for @fieldDisplayName.
  ///
  /// In es, this message translates to:
  /// **'Nombre para mostrar'**
  String get fieldDisplayName;

  /// No description provided for @fieldRole.
  ///
  /// In es, this message translates to:
  /// **'Rol'**
  String get fieldRole;

  /// No description provided for @categoryRequiredHelper.
  ///
  /// In es, this message translates to:
  /// **'Obligatoria para registrar esta placa'**
  String get categoryRequiredHelper;

  /// No description provided for @colorOptional.
  ///
  /// In es, this message translates to:
  /// **'Color (opcional)'**
  String get colorOptional;

  /// No description provided for @brandOptional.
  ///
  /// In es, this message translates to:
  /// **'Marca (opcional)'**
  String get brandOptional;

  /// No description provided for @photosTitle.
  ///
  /// In es, this message translates to:
  /// **'Fotos de evidencia ({count}/{max})'**
  String photosTitle(int count, int max);

  /// No description provided for @addPhoto.
  ///
  /// In es, this message translates to:
  /// **'Agregar foto'**
  String get addPhoto;

  /// No description provided for @removePhoto.
  ///
  /// In es, this message translates to:
  /// **'Quitar foto'**
  String get removePhoto;

  /// No description provided for @photoLabel.
  ///
  /// In es, this message translates to:
  /// **'Foto {index}'**
  String photoLabel(int index);

  /// No description provided for @photosMaxReached.
  ///
  /// In es, this message translates to:
  /// **'Máximo {max} fotos por entrada'**
  String photosMaxReached(int max);

  /// No description provided for @checkInRepeat.
  ///
  /// In es, this message translates to:
  /// **'Repetir entrada {plate}'**
  String checkInRepeat(String plate);

  /// No description provided for @checkInAlreadyInside.
  ///
  /// In es, this message translates to:
  /// **'Este vehículo ya figura dentro ({plate}). Verifica antes de registrarlo de nuevo.'**
  String checkInAlreadyInside(String plate);

  /// No description provided for @checkInLeftKeys.
  ///
  /// In es, this message translates to:
  /// **'Deja las llaves'**
  String get checkInLeftKeys;

  /// No description provided for @checkInLeftKeysHint.
  ///
  /// In es, this message translates to:
  /// **'Se guardan en recepción'**
  String get checkInLeftKeysHint;

  /// No description provided for @checkInLeftKeysShort.
  ///
  /// In es, this message translates to:
  /// **'Llaves'**
  String get checkInLeftKeysShort;

  /// No description provided for @checkInSubmit.
  ///
  /// In es, this message translates to:
  /// **'Registrar entrada'**
  String get checkInSubmit;

  /// No description provided for @checkInSuccess.
  ///
  /// In es, this message translates to:
  /// **'Entrada registrada: {plate}'**
  String checkInSuccess(String plate);

  /// No description provided for @checkInQueued.
  ///
  /// In es, this message translates to:
  /// **'Entrada guardada sin conexión: {plate}'**
  String checkInQueued(String plate);

  /// No description provided for @markExit.
  ///
  /// In es, this message translates to:
  /// **'Marcar salida'**
  String get markExit;

  /// No description provided for @openSessionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Vehículos dentro'**
  String get openSessionsTitle;

  /// No description provided for @openSessionsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay vehículos en el parqueadero'**
  String get openSessionsEmpty;

  /// No description provided for @sessionEntry.
  ///
  /// In es, this message translates to:
  /// **'Entrada: {time}'**
  String sessionEntry(String time);

  /// No description provided for @sessionPhotos.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{sin fotos} =1{1 foto} other{{count} fotos}}'**
  String sessionPhotos(int count);

  /// No description provided for @statusOpen.
  ///
  /// In es, this message translates to:
  /// **'Dentro'**
  String get statusOpen;

  /// No description provided for @statusPendingSync.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de sincronizar'**
  String get statusPendingSync;

  /// No description provided for @statusClosed.
  ///
  /// In es, this message translates to:
  /// **'Cerrada'**
  String get statusClosed;

  /// No description provided for @checkOutTitle.
  ///
  /// In es, this message translates to:
  /// **'Registrar salida'**
  String get checkOutTitle;

  /// No description provided for @searchPlate.
  ///
  /// In es, this message translates to:
  /// **'Buscar por placa'**
  String get searchPlate;

  /// No description provided for @checkOutClearSearch.
  ///
  /// In es, this message translates to:
  /// **'Limpiar búsqueda'**
  String get checkOutClearSearch;

  /// No description provided for @scanExitTooltip.
  ///
  /// In es, this message translates to:
  /// **'Escanear QR y registrar salida'**
  String get scanExitTooltip;

  /// No description provided for @scanQrTitle.
  ///
  /// In es, this message translates to:
  /// **'Escanear recibo'**
  String get scanQrTitle;

  /// No description provided for @scanQrHint.
  ///
  /// In es, this message translates to:
  /// **'Apunta la cámara al código QR del recibo'**
  String get scanQrHint;

  /// No description provided for @scanQrTorch.
  ///
  /// In es, this message translates to:
  /// **'Linterna'**
  String get scanQrTorch;

  /// No description provided for @scanQrCameraError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la cámara. Revisa el permiso.'**
  String get scanQrCameraError;

  /// No description provided for @checkOutScanQr.
  ///
  /// In es, this message translates to:
  /// **'Escanear el QR del recibo'**
  String get checkOutScanQr;

  /// No description provided for @checkOutQrUnreadable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el código QR'**
  String get checkOutQrUnreadable;

  /// No description provided for @checkOutQrNoSession.
  ///
  /// In es, this message translates to:
  /// **'No hay una sesión abierta para {plate}'**
  String checkOutQrNoSession(String plate);

  /// No description provided for @checkOutNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Ninguna placa coincide con «{query}»'**
  String checkOutNoMatch(String query);

  /// No description provided for @checkOutLongStay.
  ///
  /// In es, this message translates to:
  /// **'Más de 24 h'**
  String get checkOutLongStay;

  /// No description provided for @checkOutEstimate.
  ///
  /// In es, this message translates to:
  /// **'Total estimado: {amount}'**
  String checkOutEstimate(String amount);

  /// No description provided for @checkOutPassCovered.
  ///
  /// In es, this message translates to:
  /// **'Mensualidad activa: sin cobro'**
  String get checkOutPassCovered;

  /// No description provided for @checkOutReprintTicket.
  ///
  /// In es, this message translates to:
  /// **'Reimprimir recibo de entrada'**
  String get checkOutReprintTicket;

  /// No description provided for @checkOutCharge.
  ///
  /// In es, this message translates to:
  /// **'Cobrar'**
  String get checkOutCharge;

  /// No description provided for @checkOutChargeTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cobrar salida de {plate}'**
  String checkOutChargeTooltip(String plate);

  /// No description provided for @checkOutConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Cobrar la salida del vehículo {plate}?'**
  String checkOutConfirm(String plate);

  /// No description provided for @unknownVehicle.
  ///
  /// In es, this message translates to:
  /// **'Vehículo #{id}'**
  String unknownVehicle(int id);

  /// No description provided for @receiptTitle.
  ///
  /// In es, this message translates to:
  /// **'Salida de {plate}'**
  String receiptTitle(String plate);

  /// No description provided for @receiptEntry.
  ///
  /// In es, this message translates to:
  /// **'Entrada'**
  String get receiptEntry;

  /// No description provided for @receiptExit.
  ///
  /// In es, this message translates to:
  /// **'Salida'**
  String get receiptExit;

  /// No description provided for @receiptDuration.
  ///
  /// In es, this message translates to:
  /// **'Tiempo'**
  String get receiptDuration;

  /// No description provided for @receiptEstimated.
  ///
  /// In es, this message translates to:
  /// **'Valor estimado'**
  String get receiptEstimated;

  /// No description provided for @receiptEstimateUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Se calcula al cerrar'**
  String get receiptEstimateUnavailable;

  /// No description provided for @receiptAmount.
  ///
  /// In es, this message translates to:
  /// **'Total cobrado'**
  String get receiptAmount;

  /// No description provided for @receiptPayment.
  ///
  /// In es, this message translates to:
  /// **'Pago'**
  String get receiptPayment;

  /// No description provided for @receiptDiscount.
  ///
  /// In es, this message translates to:
  /// **'Descuento'**
  String get receiptDiscount;

  /// No description provided for @paymentMethodTitle.
  ///
  /// In es, this message translates to:
  /// **'Método de pago'**
  String get paymentMethodTitle;

  /// No description provided for @paymentCash.
  ///
  /// In es, this message translates to:
  /// **'Efectivo'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta'**
  String get paymentCard;

  /// No description provided for @paymentTransfer.
  ///
  /// In es, this message translates to:
  /// **'Transferencia'**
  String get paymentTransfer;

  /// No description provided for @paymentMonthlyPass.
  ///
  /// In es, this message translates to:
  /// **'Mensualidad'**
  String get paymentMonthlyPass;

  /// No description provided for @paymentExempt.
  ///
  /// In es, this message translates to:
  /// **'Exento'**
  String get paymentExempt;

  /// No description provided for @lostTicket.
  ///
  /// In es, this message translates to:
  /// **'Ticket perdido'**
  String get lostTicket;

  /// No description provided for @lostTicketHint.
  ///
  /// In es, this message translates to:
  /// **'Se cobra la tarifa completa del día.'**
  String get lostTicketHint;

  /// No description provided for @lostTicketReason.
  ///
  /// In es, this message translates to:
  /// **'Motivo (ticket perdido)'**
  String get lostTicketReason;

  /// No description provided for @lostTicketReasonRequired.
  ///
  /// In es, this message translates to:
  /// **'Indica el motivo del ticket perdido'**
  String get lostTicketReasonRequired;

  /// No description provided for @discountAmount.
  ///
  /// In es, this message translates to:
  /// **'Descuento (COP)'**
  String get discountAmount;

  /// No description provided for @discountReason.
  ///
  /// In es, this message translates to:
  /// **'Motivo del descuento'**
  String get discountReason;

  /// No description provided for @discountReasonRequired.
  ///
  /// In es, this message translates to:
  /// **'Indica el motivo del descuento'**
  String get discountReasonRequired;

  /// No description provided for @paymentUnknown.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get paymentUnknown;

  /// No description provided for @receiptTicket.
  ///
  /// In es, this message translates to:
  /// **'Ticket'**
  String get receiptTicket;

  /// No description provided for @receiptConfirm.
  ///
  /// In es, this message translates to:
  /// **'Cobrar y cerrar'**
  String get receiptConfirm;

  /// No description provided for @receiptDoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Salida registrada'**
  String get receiptDoneTitle;

  /// No description provided for @receiptQueued.
  ///
  /// In es, this message translates to:
  /// **'Salida guardada sin conexión. El valor se calculará al sincronizar'**
  String get receiptQueued;

  /// No description provided for @durationHoursMinutes.
  ///
  /// In es, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationMinutes.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @receiptGenerate.
  ///
  /// In es, this message translates to:
  /// **'Generar recibo'**
  String get receiptGenerate;

  /// No description provided for @receiptView.
  ///
  /// In es, this message translates to:
  /// **'Ver recibo'**
  String get receiptView;

  /// No description provided for @receiptNewCharge.
  ///
  /// In es, this message translates to:
  /// **'Nuevo cobro'**
  String get receiptNewCharge;

  /// No description provided for @receiptQrHint.
  ///
  /// In es, this message translates to:
  /// **'Presenta este código al salir para registrar la salida'**
  String get receiptQrHint;

  /// No description provided for @receiptClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get receiptClose;

  /// No description provided for @printReceipt.
  ///
  /// In es, this message translates to:
  /// **'Imprimir'**
  String get printReceipt;

  /// No description provided for @printSystem.
  ///
  /// In es, this message translates to:
  /// **'Impresora del sistema (PDF)'**
  String get printSystem;

  /// No description provided for @printBluetooth.
  ///
  /// In es, this message translates to:
  /// **'Impresoras Bluetooth'**
  String get printBluetooth;

  /// No description provided for @printScan.
  ///
  /// In es, this message translates to:
  /// **'Buscar impresoras'**
  String get printScan;

  /// No description provided for @printScanning.
  ///
  /// In es, this message translates to:
  /// **'Buscando impresoras...'**
  String get printScanning;

  /// No description provided for @printNoPrinters.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron impresoras Bluetooth'**
  String get printNoPrinters;

  /// No description provided for @printSuccess.
  ///
  /// In es, this message translates to:
  /// **'Recibo enviado a la impresora'**
  String get printSuccess;

  /// No description provided for @printError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo imprimir'**
  String get printError;

  /// No description provided for @receiptPhotos.
  ///
  /// In es, this message translates to:
  /// **'Fotos de evidencia'**
  String get receiptPhotos;

  /// No description provided for @checkInReceiptTitle.
  ///
  /// In es, this message translates to:
  /// **'Entrada registrada'**
  String get checkInReceiptTitle;

  /// No description provided for @receiptGeneratedAt.
  ///
  /// In es, this message translates to:
  /// **'Generado el {time}'**
  String receiptGeneratedAt(String time);

  /// No description provided for @scanTitle.
  ///
  /// In es, this message translates to:
  /// **'Escanear placa'**
  String get scanTitle;

  /// No description provided for @scanCapture.
  ///
  /// In es, this message translates to:
  /// **'Tomar foto de la placa'**
  String get scanCapture;

  /// No description provided for @scanManualHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe la placa manualmente'**
  String get scanManualHint;

  /// No description provided for @scanManual.
  ///
  /// In es, this message translates to:
  /// **'Ingresar manualmente'**
  String get scanManual;

  /// No description provided for @scanEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ingresa una placa antes de confirmar'**
  String get scanEmpty;

  /// No description provided for @categoriesTitle.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get categoriesTitle;

  /// No description provided for @categorySpotsLeft.
  ///
  /// In es, this message translates to:
  /// **'quedan {count}'**
  String categorySpotsLeft(int count);

  /// No description provided for @categoryNoSpots.
  ///
  /// In es, this message translates to:
  /// **'sin cupo'**
  String get categoryNoSpots;

  /// No description provided for @categoriesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay categorías'**
  String get categoriesEmpty;

  /// No description provided for @categoryNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva categoría'**
  String get categoryNew;

  /// No description provided for @categoryRename.
  ///
  /// In es, this message translates to:
  /// **'Renombrar categoría'**
  String get categoryRename;

  /// No description provided for @categoryCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad: {count}'**
  String categoryCapacity(int count);

  /// No description provided for @categoryCapacityUnlimited.
  ///
  /// In es, this message translates to:
  /// **'Sin límite de capacidad'**
  String get categoryCapacityUnlimited;

  /// No description provided for @categoryCapacityTitle.
  ///
  /// In es, this message translates to:
  /// **'Capacidad de {name}'**
  String categoryCapacityTitle(String name);

  /// No description provided for @categoryCapacityLabel.
  ///
  /// In es, this message translates to:
  /// **'Capacidad'**
  String get categoryCapacityLabel;

  /// No description provided for @errorCategoryFull.
  ///
  /// In es, this message translates to:
  /// **'La categoría está llena'**
  String get errorCategoryFull;

  /// No description provided for @homeFull.
  ///
  /// In es, this message translates to:
  /// **'Lleno'**
  String get homeFull;

  /// No description provided for @homeFullCategories.
  ///
  /// In es, this message translates to:
  /// **'Categorías llenas: {names}'**
  String homeFullCategories(String names);

  /// No description provided for @reportsOccupancyOf.
  ///
  /// In es, this message translates to:
  /// **'Vehículos dentro: {open} / {capacity}'**
  String reportsOccupancyOf(int open, int capacity);

  /// No description provided for @categoryDeleteTooltip.
  ///
  /// In es, this message translates to:
  /// **'Eliminar categoría {name}'**
  String categoryDeleteTooltip(String name);

  /// No description provided for @categoryDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar categoría?'**
  String get categoryDeleteTitle;

  /// No description provided for @categoryDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará «{name}». Esta acción no se puede deshacer.'**
  String categoryDeleteBody(String name);

  /// No description provided for @categoryAddTooltip.
  ///
  /// In es, this message translates to:
  /// **'Agregar categoría'**
  String get categoryAddTooltip;

  /// No description provided for @categoryFallback.
  ///
  /// In es, this message translates to:
  /// **'Categoría {id}'**
  String categoryFallback(int id);

  /// No description provided for @vehiclesSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar placa'**
  String get vehiclesSearch;

  /// No description provided for @vehiclesNoMatch.
  ///
  /// In es, this message translates to:
  /// **'No hay vehículos para «{query}»'**
  String vehiclesNoMatch(String query);

  /// No description provided for @vehicleCreated.
  ///
  /// In es, this message translates to:
  /// **'Vehículo creado: {plate}'**
  String vehicleCreated(String plate);

  /// No description provided for @vehicleCheckInAction.
  ///
  /// In es, this message translates to:
  /// **'Registrar entrada'**
  String get vehicleCheckInAction;

  /// No description provided for @vehiclesTitle.
  ///
  /// In es, this message translates to:
  /// **'Vehículos'**
  String get vehiclesTitle;

  /// No description provided for @vehiclesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay vehículos registrados'**
  String get vehiclesEmpty;

  /// No description provided for @vehicleNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo vehículo'**
  String get vehicleNew;

  /// No description provided for @vehicleAddTooltip.
  ///
  /// In es, this message translates to:
  /// **'Agregar vehículo'**
  String get vehicleAddTooltip;

  /// No description provided for @vehicleDeleteTooltip.
  ///
  /// In es, this message translates to:
  /// **'Eliminar vehículo {plate}'**
  String vehicleDeleteTooltip(String plate);

  /// No description provided for @vehicleDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar vehículo?'**
  String get vehicleDeleteTitle;

  /// No description provided for @vehicleDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará el vehículo {plate}. Esta acción no se puede deshacer.'**
  String vehicleDeleteBody(String plate);

  /// No description provided for @tariffsTitle.
  ///
  /// In es, this message translates to:
  /// **'Tarifas'**
  String get tariffsTitle;

  /// No description provided for @tariffsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay tarifas'**
  String get tariffsEmpty;

  /// No description provided for @tariffNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva tarifa'**
  String get tariffNew;

  /// No description provided for @tariffAddTooltip.
  ///
  /// In es, this message translates to:
  /// **'Agregar tarifa'**
  String get tariffAddTooltip;

  /// No description provided for @tariffTypeHourly.
  ///
  /// In es, this message translates to:
  /// **'Por hora'**
  String get tariffTypeHourly;

  /// No description provided for @tariffTypeDaily.
  ///
  /// In es, this message translates to:
  /// **'Por día'**
  String get tariffTypeDaily;

  /// No description provided for @tariffTypeNightly.
  ///
  /// In es, this message translates to:
  /// **'Nocturna'**
  String get tariffTypeNightly;

  /// No description provided for @tariffTypeMonthly.
  ///
  /// In es, this message translates to:
  /// **'Mensual'**
  String get tariffTypeMonthly;

  /// No description provided for @tariffStart.
  ///
  /// In es, this message translates to:
  /// **'Inicio (HH:MM)'**
  String get tariffStart;

  /// No description provided for @tariffEnd.
  ///
  /// In es, this message translates to:
  /// **'Fin (HH:MM)'**
  String get tariffEnd;

  /// No description provided for @tariffActiveLabel.
  ///
  /// In es, this message translates to:
  /// **'Tarifa activa'**
  String get tariffActiveLabel;

  /// No description provided for @tariffDeleteTooltip.
  ///
  /// In es, this message translates to:
  /// **'Eliminar tarifa'**
  String get tariffDeleteTooltip;

  /// No description provided for @tariffDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar tarifa?'**
  String get tariffDeleteTitle;

  /// No description provided for @tariffDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará la tarifa {label}. Esta acción no se puede deshacer.'**
  String tariffDeleteBody(String label);

  /// No description provided for @tariffDeactivated.
  ///
  /// In es, this message translates to:
  /// **'Tarifa desactivada'**
  String get tariffDeactivated;

  /// No description provided for @invalidTime.
  ///
  /// In es, this message translates to:
  /// **'Usa el formato HH:MM (24 h)'**
  String get invalidTime;

  /// No description provided for @invalidAmount.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un valor mayor a 0'**
  String get invalidAmount;

  /// No description provided for @usersTitle.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get usersTitle;

  /// No description provided for @usersFilterAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get usersFilterAll;

  /// No description provided for @usersFilterEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay usuarios con este filtro'**
  String get usersFilterEmpty;

  /// No description provided for @usersEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay usuarios'**
  String get usersEmpty;

  /// No description provided for @userNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo usuario'**
  String get userNew;

  /// No description provided for @userAddTooltip.
  ///
  /// In es, this message translates to:
  /// **'Agregar usuario'**
  String get userAddTooltip;

  /// No description provided for @userActions.
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get userActions;

  /// No description provided for @userResetPin.
  ///
  /// In es, this message translates to:
  /// **'Restablecer PIN'**
  String get userResetPin;

  /// No description provided for @userResetPinTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo PIN para {name}'**
  String userResetPinTitle(String name);

  /// No description provided for @userNewPin.
  ///
  /// In es, this message translates to:
  /// **'Nuevo PIN (6 dígitos)'**
  String get userNewPin;

  /// No description provided for @userDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar usuario'**
  String get userDelete;

  /// No description provided for @userDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar usuario?'**
  String get userDeleteTitle;

  /// No description provided for @userDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará la cuenta de {name}. Esta acción no se puede deshacer.'**
  String userDeleteBody(String name);

  /// No description provided for @userActiveLabel.
  ///
  /// In es, this message translates to:
  /// **'Usuario activo: {name}'**
  String userActiveLabel(String name);

  /// No description provided for @userDeactivated.
  ///
  /// In es, this message translates to:
  /// **'Usuario {name} desactivado'**
  String userDeactivated(String name);

  /// No description provided for @pinInvalid.
  ///
  /// In es, this message translates to:
  /// **'El PIN debe tener 6 dígitos'**
  String get pinInvalid;

  /// No description provided for @monthlyPassPendingTitle.
  ///
  /// In es, this message translates to:
  /// **'Pagos pendientes'**
  String get monthlyPassPendingTitle;

  /// No description provided for @monthlyPassDue.
  ///
  /// In es, this message translates to:
  /// **'Vence: {date}'**
  String monthlyPassDue(String date);

  /// No description provided for @monthlyPassWhatsapp.
  ///
  /// In es, this message translates to:
  /// **'Avisar por WhatsApp'**
  String get monthlyPassWhatsapp;

  /// No description provided for @monthlyPassWhatsappMessage.
  ///
  /// In es, this message translates to:
  /// **'Hola, te recordamos que la mensualidad del vehículo {plate} vence el {date}.'**
  String monthlyPassWhatsappMessage(String plate, String date);

  /// No description provided for @monthlyPassStatusActive.
  ///
  /// In es, this message translates to:
  /// **'Vigente'**
  String get monthlyPassStatusActive;

  /// No description provided for @monthlyPassStatusUpcoming.
  ///
  /// In es, this message translates to:
  /// **'Próxima'**
  String get monthlyPassStatusUpcoming;

  /// No description provided for @monthlyPassStatusExpired.
  ///
  /// In es, this message translates to:
  /// **'Vencida'**
  String get monthlyPassStatusExpired;

  /// No description provided for @monthlyPassCharge.
  ///
  /// In es, this message translates to:
  /// **'Cobrar'**
  String get monthlyPassCharge;

  /// No description provided for @monthlyPassRenewalMethod.
  ///
  /// In es, this message translates to:
  /// **'Método para renovación'**
  String get monthlyPassRenewalMethod;

  /// No description provided for @monthlyPassAutoRenew.
  ///
  /// In es, this message translates to:
  /// **'Renovación automática'**
  String get monthlyPassAutoRenew;

  /// No description provided for @monthlyPassAutoRenewHint.
  ///
  /// In es, this message translates to:
  /// **'Se renueva por el mismo periodo y valor al vencer'**
  String get monthlyPassAutoRenewHint;

  /// No description provided for @monthlyPassesTitle.
  ///
  /// In es, this message translates to:
  /// **'Mensualidades'**
  String get monthlyPassesTitle;

  /// No description provided for @monthlyPassesNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Ninguna mensualidad coincide con «{query}»'**
  String monthlyPassesNoMatch(String query);

  /// No description provided for @monthlyPassCreated.
  ///
  /// In es, this message translates to:
  /// **'Mensualidad creada'**
  String get monthlyPassCreated;

  /// No description provided for @monthlyPassDeleted.
  ///
  /// In es, this message translates to:
  /// **'Mensualidad eliminada'**
  String get monthlyPassDeleted;

  /// No description provided for @monthlyPassPaymentDone.
  ///
  /// In es, this message translates to:
  /// **'Pago de mensualidad registrado'**
  String get monthlyPassPaymentDone;

  /// No description provided for @monthlyPassRenew.
  ///
  /// In es, this message translates to:
  /// **'Renovar 30 días'**
  String get monthlyPassRenew;

  /// No description provided for @monthlyPassRenewTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Renovar la mensualidad?'**
  String get monthlyPassRenewTitle;

  /// No description provided for @monthlyPassRenewBody.
  ///
  /// In es, this message translates to:
  /// **'Se extenderá hasta {date}, conservando el valor actual.'**
  String monthlyPassRenewBody(String date);

  /// No description provided for @monthlyPassRenewed.
  ///
  /// In es, this message translates to:
  /// **'Mensualidad renovada 30 días'**
  String get monthlyPassRenewed;

  /// No description provided for @monthlyPassesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay mensualidades'**
  String get monthlyPassesEmpty;

  /// No description provided for @monthlyPassNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva mensualidad'**
  String get monthlyPassNew;

  /// No description provided for @monthlyPassEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar mensualidad'**
  String get monthlyPassEdit;

  /// No description provided for @monthlyPassAddTooltip.
  ///
  /// In es, this message translates to:
  /// **'Agregar mensualidad'**
  String get monthlyPassAddTooltip;

  /// No description provided for @monthlyPassEditTooltip.
  ///
  /// In es, this message translates to:
  /// **'Editar mensualidad de {plate}'**
  String monthlyPassEditTooltip(String plate);

  /// No description provided for @monthlyPassDeleteTooltip.
  ///
  /// In es, this message translates to:
  /// **'Eliminar mensualidad de {plate}'**
  String monthlyPassDeleteTooltip(String plate);

  /// No description provided for @monthlyPassDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar mensualidad?'**
  String get monthlyPassDeleteTitle;

  /// No description provided for @monthlyPassDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará la mensualidad de {plate}. Esta acción no se puede deshacer.'**
  String monthlyPassDeleteBody(String plate);

  /// No description provided for @monthlyPassActiveLabel.
  ///
  /// In es, this message translates to:
  /// **'Mensualidad activa: {plate}'**
  String monthlyPassActiveLabel(String plate);

  /// No description provided for @monthlyPassDeactivated.
  ///
  /// In es, this message translates to:
  /// **'Mensualidad de {plate} desactivada'**
  String monthlyPassDeactivated(String plate);

  /// No description provided for @monthlyPassPeriod.
  ///
  /// In es, this message translates to:
  /// **'{start} – {end}'**
  String monthlyPassPeriod(String start, String end);

  /// No description provided for @selectDate.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar fecha'**
  String get selectDate;

  /// No description provided for @dateRangeInvalid.
  ///
  /// In es, this message translates to:
  /// **'La fecha de fin debe ser posterior a la de inicio'**
  String get dateRangeInvalid;

  /// No description provided for @reportsAllLots.
  ///
  /// In es, this message translates to:
  /// **'Todas las sedes'**
  String get reportsAllLots;

  /// No description provided for @reportsAllLotsHint.
  ///
  /// In es, this message translates to:
  /// **'Suma las ventas de todas las sedes'**
  String get reportsAllLotsHint;

  /// No description provided for @reportsLotTickets.
  ///
  /// In es, this message translates to:
  /// **'{count} salidas'**
  String reportsLotTickets(int count);

  /// No description provided for @reportsLotAverage.
  ///
  /// In es, this message translates to:
  /// **'promedio {amount}'**
  String reportsLotAverage(String amount);

  /// No description provided for @reportsLotShare.
  ///
  /// In es, this message translates to:
  /// **'{percent}% del total'**
  String reportsLotShare(int percent);

  /// No description provided for @reportsByLot.
  ///
  /// In es, this message translates to:
  /// **'Ingresos por sede'**
  String get reportsByLot;

  /// No description provided for @reportsToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get reportsToday;

  /// No description provided for @reportsLast7.
  ///
  /// In es, this message translates to:
  /// **'7 días'**
  String get reportsLast7;

  /// No description provided for @reportsLast30.
  ///
  /// In es, this message translates to:
  /// **'30 días'**
  String get reportsLast30;

  /// No description provided for @reportsTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get reportsTitle;

  /// No description provided for @lotSwitchTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar de sede'**
  String get lotSwitchTitle;

  /// No description provided for @lotSwitchTooltip.
  ///
  /// In es, this message translates to:
  /// **'Sede actual: {site}. Toca para cambiar.'**
  String lotSwitchTooltip(String site);

  /// No description provided for @reportsRangeTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cambiar rango de fechas'**
  String get reportsRangeTooltip;

  /// No description provided for @reportsVsPrevious.
  ///
  /// In es, this message translates to:
  /// **'{percent} % vs. periodo anterior'**
  String reportsVsPrevious(String percent);

  /// No description provided for @reportsPreviousTotal.
  ///
  /// In es, this message translates to:
  /// **'Antes: {amount}'**
  String reportsPreviousTotal(String amount);

  /// No description provided for @reportsVariationLabel.
  ///
  /// In es, this message translates to:
  /// **'Variación vs. periodo anterior'**
  String get reportsVariationLabel;

  /// No description provided for @reportsPreviousLabel.
  ///
  /// In es, this message translates to:
  /// **'Periodo anterior'**
  String get reportsPreviousLabel;

  /// No description provided for @reportsExportCsv.
  ///
  /// In es, this message translates to:
  /// **'Copiar CSV'**
  String get reportsExportCsv;

  /// No description provided for @reportsCsvCopied.
  ///
  /// In es, this message translates to:
  /// **'CSV copiado al portapapeles'**
  String get reportsCsvCopied;

  /// No description provided for @reportsTotalRevenue.
  ///
  /// In es, this message translates to:
  /// **'Ingresos totales'**
  String get reportsTotalRevenue;

  /// No description provided for @reportsRevenueByDay.
  ///
  /// In es, this message translates to:
  /// **'Ingresos por día'**
  String get reportsRevenueByDay;

  /// No description provided for @reportsPassRevenue.
  ///
  /// In es, this message translates to:
  /// **'Mensualidades cobradas'**
  String get reportsPassRevenue;

  /// No description provided for @reportsRevenueByPayment.
  ///
  /// In es, this message translates to:
  /// **'Ingresos por método de pago'**
  String get reportsRevenueByPayment;

  /// No description provided for @reportsTotalDiscounts.
  ///
  /// In es, this message translates to:
  /// **'Descuentos aplicados'**
  String get reportsTotalDiscounts;

  /// No description provided for @reportsDiscountLog.
  ///
  /// In es, this message translates to:
  /// **'Detalle de descuentos'**
  String get reportsDiscountLog;

  /// No description provided for @reportsDiscountBy.
  ///
  /// In es, this message translates to:
  /// **'por {admin}'**
  String reportsDiscountBy(String admin);

  /// No description provided for @reportsDiscountedSessions.
  ///
  /// In es, this message translates to:
  /// **'{count} salidas con descuento'**
  String reportsDiscountedSessions(int count);

  /// No description provided for @reportsRevenueByCategory.
  ///
  /// In es, this message translates to:
  /// **'Ingresos por categoría'**
  String get reportsRevenueByCategory;

  /// No description provided for @reportsWhatsapp.
  ///
  /// In es, this message translates to:
  /// **'WhatsApp'**
  String get reportsWhatsapp;

  /// No description provided for @reportsWhatsappSent.
  ///
  /// In es, this message translates to:
  /// **'Enviados'**
  String get reportsWhatsappSent;

  /// No description provided for @reportsWhatsappFailed.
  ///
  /// In es, this message translates to:
  /// **'Fallidos'**
  String get reportsWhatsappFailed;

  /// No description provided for @reportsWhatsappPending.
  ///
  /// In es, this message translates to:
  /// **'En cola'**
  String get reportsWhatsappPending;

  /// No description provided for @reportsWhatsappDay.
  ///
  /// In es, this message translates to:
  /// **'{sent} enviados · {failed} fallidos'**
  String reportsWhatsappDay(int sent, int failed);

  /// No description provided for @reportsOccupancy.
  ///
  /// In es, this message translates to:
  /// **'Ocupación'**
  String get reportsOccupancy;

  /// No description provided for @reportsOpenSessions.
  ///
  /// In es, this message translates to:
  /// **'Vehículos dentro: {count}'**
  String reportsOpenSessions(int count);

  /// No description provided for @reportsNoCategoryData.
  ///
  /// In es, this message translates to:
  /// **'Sin datos por categoría'**
  String get reportsNoCategoryData;

  /// No description provided for @reportsNoRevenue.
  ///
  /// In es, this message translates to:
  /// **'Sin ingresos en este rango'**
  String get reportsNoRevenue;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
