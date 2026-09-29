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

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuración del parqueadero'**
  String get settingsTitle;

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

  /// No description provided for @checkOutNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Ninguna placa coincide con «{query}»'**
  String checkOutNoMatch(String query);

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
  /// **'El PIN debe tener de 4 a 6 dígitos'**
  String get pinInvalid;

  /// No description provided for @monthlyPassesTitle.
  ///
  /// In es, this message translates to:
  /// **'Mensualidades'**
  String get monthlyPassesTitle;

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

  /// No description provided for @reportsTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get reportsTitle;

  /// No description provided for @reportsRangeTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cambiar rango de fechas'**
  String get reportsRangeTooltip;

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

  /// No description provided for @reportsRevenueByCategory.
  ///
  /// In es, this message translates to:
  /// **'Ingresos por categoría'**
  String get reportsRevenueByCategory;

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
