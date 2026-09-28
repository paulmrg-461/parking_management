// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Parqueadero';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionCreate => 'Crear';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionUndo => 'Deshacer';

  @override
  String get actionDone => 'Listo';

  @override
  String get actionLoadMore => 'Cargar más';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionLogout => 'Cerrar sesión';

  @override
  String get loading => 'Cargando';

  @override
  String get fieldRequired => 'Campo obligatorio';

  @override
  String get notAvailable => '—';

  @override
  String get errorNetwork => 'No hay conexión con el servidor';

  @override
  String get errorServer =>
      'El servidor no está disponible. Intenta de nuevo en un momento';

  @override
  String get errorAuth => 'Usuario o PIN incorrectos';

  @override
  String get errorForbidden => 'No tienes permiso para realizar esta acción';

  @override
  String get errorSessionExpired => 'Tu sesión expiró. Vuelve a iniciar sesión';

  @override
  String get errorStorage =>
      'No se pudo guardar la información en el dispositivo';

  @override
  String get errorUnknown => 'Ocurrió un error inesperado';

  @override
  String errorRateLimited(int minutes) {
    return 'Demasiados intentos. Intenta de nuevo en $minutes min';
  }

  @override
  String get errorTooManyAttempts => 'Demasiados intentos. Intenta más tarde';

  @override
  String get errorNotFound => 'No se encontró el registro';

  @override
  String get errorConflict =>
      'La operación entra en conflicto con los datos actuales';

  @override
  String get errorInvalidData => 'Los datos enviados no son válidos';

  @override
  String get errorVehicleNotFound => 'Vehículo no encontrado';

  @override
  String get errorCategoryNotFound => 'Categoría no encontrada';

  @override
  String get errorTariffNotFound => 'Tarifa no encontrada';

  @override
  String get errorUserNotFound => 'Usuario no encontrado';

  @override
  String get errorMonthlyPassNotFound => 'Mensualidad no encontrada';

  @override
  String get errorSessionNotFound => 'La entrada ya no existe';

  @override
  String get errorMissingHourlyTariff =>
      'La categoría no tiene tarifa por hora configurada';

  @override
  String get errorDuplicateOpenSession =>
      'Este vehículo ya está dentro del parqueadero';

  @override
  String get errorDuplicatePlate => 'Ya existe un vehículo con esa placa';

  @override
  String get errorDuplicateCategory => 'Ya existe una categoría con ese nombre';

  @override
  String get errorDuplicateUsername => 'Ese nombre de usuario ya existe';

  @override
  String get errorSessionAlreadyClosed => 'Esta salida ya fue registrada';

  @override
  String get errorVehicleNotRegistered =>
      'Vehículo nuevo: selecciona una categoría';

  @override
  String get errorInvalidPhoto => 'Las fotos deben ser imágenes JPEG o PNG';

  @override
  String get errorPhotoTooLarge => 'Cada foto debe pesar 5 MB o menos';

  @override
  String get errorTooManyPhotos => 'Superaste el máximo de fotos por entrada';

  @override
  String get errorAdminRequired => 'Solo un administrador puede hacer esto';

  @override
  String get errorIdempotency => 'Esta operación ya se había enviado';

  @override
  String get errorEmptyPlate => 'Ingresa la placa';

  @override
  String get errorOcrNoText => 'No se pudo leer la placa en la foto';

  @override
  String get errorScanUnavailable =>
      'El escaneo de placas no está disponible aquí';

  @override
  String get errorPendingSyncCheckOut =>
      'Esta entrada aún no se ha sincronizado. Intenta cuando haya conexión';

  @override
  String get errorMissingPendingPhoto => 'Falta una foto de evidencia en cola';

  @override
  String get deferredLoadError => 'No se pudo cargar esta sección';

  @override
  String get offlineBanner =>
      'Sin conexión. Los cambios se guardan y se sincronizarán al reconectar';

  @override
  String syncPendingTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios pendientes de sincronizar',
      one: '1 cambio pendiente de sincronizar',
    );
    return '$_temp0';
  }

  @override
  String syncPendingWithErrors(String base, int errors) {
    return '$base ($errors con error)';
  }

  @override
  String get syncSheetTitle => 'Cambios sin sincronizar';

  @override
  String syncQueued(int count) {
    return '$count en cola, se reintentarán solos.';
  }

  @override
  String get syncDiscard => 'Descartar cambio';

  @override
  String get syncUnknownError => 'Error desconocido';

  @override
  String get entityVehicle => 'Vehículo';

  @override
  String get entityTariff => 'Tarifa';

  @override
  String get entityCategory => 'Categoría';

  @override
  String get entityCheckIn => 'Entrada';

  @override
  String get entityCheckOut => 'Salida';

  @override
  String get navHome => 'Inicio';

  @override
  String get navCheckIn => 'Entrada';

  @override
  String get navCheckOut => 'Salida';

  @override
  String get navVehicles => 'Vehículos';

  @override
  String get navTariffs => 'Tarifas';

  @override
  String get navCategories => 'Categorías';

  @override
  String get navMonthlyPasses => 'Mensualidades';

  @override
  String get navUsers => 'Usuarios';

  @override
  String get navReports => 'Reportes';

  @override
  String get navMore => 'Más';

  @override
  String get navMoreTooltip => 'Más secciones de gestión';

  @override
  String get loginSubtitle => 'Inicia sesión para continuar';

  @override
  String get loginUsername => 'Usuario';

  @override
  String get loginPin => 'PIN';

  @override
  String get loginSubmit => 'Ingresar';

  @override
  String get loginFailed => 'No se pudo iniciar sesión';

  @override
  String homeGreeting(String name) {
    return 'Hola, $name';
  }

  @override
  String get roleAdmin => 'Administrador';

  @override
  String get roleOperator => 'Operador';

  @override
  String get homeOccupancy => 'Vehículos dentro';

  @override
  String get homeOccupancyUnavailable => 'Ocupación no disponible';

  @override
  String get homeEntryHint => 'Registrar un vehículo que llega';

  @override
  String get homeExitHint => 'Cobrar y cerrar una estadía';

  @override
  String get homeManagement => 'Gestión';

  @override
  String get homeRefreshTooltip => 'Actualizar ocupación';

  @override
  String get plateLabel => 'Placa';

  @override
  String get plateHint => 'ABC123';

  @override
  String get plateScanTooltip => 'Escanear placa con la cámara';

  @override
  String plateDetected(String plate) {
    return 'Placa detectada: $plate';
  }

  @override
  String get checkInTitle => 'Registrar entrada';

  @override
  String get lookupLoading => 'Buscando vehículo';

  @override
  String lookupError(String message) {
    return 'No se pudo consultar el vehículo: $message';
  }

  @override
  String get registeredVehicle => 'Vehículo registrado';

  @override
  String get newVehicle => 'Vehículo nuevo';

  @override
  String get fieldCategory => 'Categoría';

  @override
  String get fieldColor => 'Color';

  @override
  String get fieldBrand => 'Marca';

  @override
  String get fieldPlate => 'Placa';

  @override
  String get fieldName => 'Nombre';

  @override
  String get fieldVehicle => 'Vehículo';

  @override
  String get fieldAmount => 'Valor (COP)';

  @override
  String get fieldType => 'Tipo';

  @override
  String get fieldStartDate => 'Fecha de inicio';

  @override
  String get fieldEndDate => 'Fecha de fin';

  @override
  String get fieldDisplayName => 'Nombre para mostrar';

  @override
  String get fieldRole => 'Rol';

  @override
  String get categoryRequiredHelper => 'Obligatoria para registrar esta placa';

  @override
  String get colorOptional => 'Color (opcional)';

  @override
  String get brandOptional => 'Marca (opcional)';

  @override
  String photosTitle(int count, int max) {
    return 'Fotos de evidencia ($count/$max)';
  }

  @override
  String get addPhoto => 'Agregar foto';

  @override
  String get removePhoto => 'Quitar foto';

  @override
  String photoLabel(int index) {
    return 'Foto $index';
  }

  @override
  String photosMaxReached(int max) {
    return 'Máximo $max fotos por entrada';
  }

  @override
  String get checkInSubmit => 'Registrar entrada';

  @override
  String checkInSuccess(String plate) {
    return 'Entrada registrada: $plate';
  }

  @override
  String checkInQueued(String plate) {
    return 'Entrada guardada sin conexión: $plate';
  }

  @override
  String get openSessionsTitle => 'Vehículos dentro';

  @override
  String get openSessionsEmpty => 'No hay vehículos en el parqueadero';

  @override
  String sessionEntry(String time) {
    return 'Entrada: $time';
  }

  @override
  String sessionPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '1 foto',
      zero: 'sin fotos',
    );
    return '$_temp0';
  }

  @override
  String get statusOpen => 'Dentro';

  @override
  String get statusPendingSync => 'Pendiente de sincronizar';

  @override
  String get statusClosed => 'Cerrada';

  @override
  String get checkOutTitle => 'Registrar salida';

  @override
  String get searchPlate => 'Buscar por placa';

  @override
  String checkOutNoMatch(String query) {
    return 'Ninguna placa coincide con «$query»';
  }

  @override
  String get checkOutCharge => 'Cobrar';

  @override
  String checkOutChargeTooltip(String plate) {
    return 'Cobrar salida de $plate';
  }

  @override
  String unknownVehicle(int id) {
    return 'Vehículo #$id';
  }

  @override
  String receiptTitle(String plate) {
    return 'Salida de $plate';
  }

  @override
  String get receiptEntry => 'Entrada';

  @override
  String get receiptExit => 'Salida';

  @override
  String get receiptDuration => 'Tiempo';

  @override
  String get receiptEstimated => 'Valor estimado';

  @override
  String get receiptEstimateUnavailable => 'Se calcula al cerrar';

  @override
  String get receiptAmount => 'Total cobrado';

  @override
  String get receiptTicket => 'Ticket';

  @override
  String get receiptConfirm => 'Cobrar y cerrar';

  @override
  String get receiptDoneTitle => 'Salida registrada';

  @override
  String get receiptQueued =>
      'Salida guardada sin conexión. El valor se calculará al sincronizar';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get receiptGenerate => 'Generar recibo';

  @override
  String get receiptClose => 'Cerrar';

  @override
  String get receiptPhotos => 'Fotos de evidencia';

  @override
  String get checkInReceiptTitle => 'Entrada registrada';

  @override
  String receiptGeneratedAt(String time) {
    return 'Generado el $time';
  }

  @override
  String get scanTitle => 'Escanear placa';

  @override
  String get scanCapture => 'Tomar foto de la placa';

  @override
  String get scanManualHint => 'Escribe la placa manualmente';

  @override
  String get scanManual => 'Ingresar manualmente';

  @override
  String get scanEmpty => 'Ingresa una placa antes de confirmar';

  @override
  String get categoriesTitle => 'Categorías';

  @override
  String get categoriesEmpty => 'Aún no hay categorías';

  @override
  String get categoryNew => 'Nueva categoría';

  @override
  String get categoryRename => 'Renombrar categoría';

  @override
  String categoryDeleteTooltip(String name) {
    return 'Eliminar categoría $name';
  }

  @override
  String get categoryDeleteTitle => '¿Eliminar categoría?';

  @override
  String categoryDeleteBody(String name) {
    return 'Se eliminará «$name». Esta acción no se puede deshacer.';
  }

  @override
  String get categoryAddTooltip => 'Agregar categoría';

  @override
  String categoryFallback(int id) {
    return 'Categoría $id';
  }

  @override
  String get vehiclesTitle => 'Vehículos';

  @override
  String get vehiclesEmpty => 'Aún no hay vehículos registrados';

  @override
  String get vehicleNew => 'Nuevo vehículo';

  @override
  String get vehicleAddTooltip => 'Agregar vehículo';

  @override
  String vehicleDeleteTooltip(String plate) {
    return 'Eliminar vehículo $plate';
  }

  @override
  String get vehicleDeleteTitle => '¿Eliminar vehículo?';

  @override
  String vehicleDeleteBody(String plate) {
    return 'Se eliminará el vehículo $plate. Esta acción no se puede deshacer.';
  }

  @override
  String get tariffsTitle => 'Tarifas';

  @override
  String get tariffsEmpty => 'Aún no hay tarifas';

  @override
  String get tariffNew => 'Nueva tarifa';

  @override
  String get tariffAddTooltip => 'Agregar tarifa';

  @override
  String get tariffTypeHourly => 'Por hora';

  @override
  String get tariffTypeDaily => 'Por día';

  @override
  String get tariffTypeNightly => 'Nocturna';

  @override
  String get tariffTypeMonthly => 'Mensual';

  @override
  String get tariffStart => 'Inicio (HH:MM)';

  @override
  String get tariffEnd => 'Fin (HH:MM)';

  @override
  String get tariffActiveLabel => 'Tarifa activa';

  @override
  String get tariffDeleteTooltip => 'Eliminar tarifa';

  @override
  String get tariffDeleteTitle => '¿Eliminar tarifa?';

  @override
  String tariffDeleteBody(String label) {
    return 'Se eliminará la tarifa $label. Esta acción no se puede deshacer.';
  }

  @override
  String get tariffDeactivated => 'Tarifa desactivada';

  @override
  String get invalidTime => 'Usa el formato HH:MM (24 h)';

  @override
  String get invalidAmount => 'Ingresa un valor mayor a 0';

  @override
  String get usersTitle => 'Usuarios';

  @override
  String get usersEmpty => 'Aún no hay usuarios';

  @override
  String get userNew => 'Nuevo usuario';

  @override
  String get userAddTooltip => 'Agregar usuario';

  @override
  String userActiveLabel(String name) {
    return 'Usuario activo: $name';
  }

  @override
  String userDeactivated(String name) {
    return 'Usuario $name desactivado';
  }

  @override
  String get pinInvalid => 'El PIN debe tener de 4 a 6 dígitos';

  @override
  String get monthlyPassesTitle => 'Mensualidades';

  @override
  String get monthlyPassesEmpty => 'Aún no hay mensualidades';

  @override
  String get monthlyPassNew => 'Nueva mensualidad';

  @override
  String get monthlyPassEdit => 'Editar mensualidad';

  @override
  String get monthlyPassAddTooltip => 'Agregar mensualidad';

  @override
  String monthlyPassEditTooltip(String plate) {
    return 'Editar mensualidad de $plate';
  }

  @override
  String monthlyPassDeleteTooltip(String plate) {
    return 'Eliminar mensualidad de $plate';
  }

  @override
  String get monthlyPassDeleteTitle => '¿Eliminar mensualidad?';

  @override
  String monthlyPassDeleteBody(String plate) {
    return 'Se eliminará la mensualidad de $plate. Esta acción no se puede deshacer.';
  }

  @override
  String monthlyPassActiveLabel(String plate) {
    return 'Mensualidad activa: $plate';
  }

  @override
  String monthlyPassDeactivated(String plate) {
    return 'Mensualidad de $plate desactivada';
  }

  @override
  String monthlyPassPeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String get selectDate => 'Seleccionar fecha';

  @override
  String get dateRangeInvalid =>
      'La fecha de fin debe ser posterior a la de inicio';

  @override
  String get reportsTitle => 'Reportes';

  @override
  String get reportsRangeTooltip => 'Cambiar rango de fechas';

  @override
  String get reportsTotalRevenue => 'Ingresos totales';

  @override
  String get reportsRevenueByDay => 'Ingresos por día';

  @override
  String get reportsRevenueByCategory => 'Ingresos por categoría';

  @override
  String get reportsOccupancy => 'Ocupación';

  @override
  String reportsOpenSessions(int count) {
    return 'Vehículos dentro: $count';
  }

  @override
  String get reportsNoCategoryData => 'Sin datos por categoría';

  @override
  String get reportsNoRevenue => 'Sin ingresos en este rango';
}
