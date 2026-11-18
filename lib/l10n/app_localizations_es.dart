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
  String get actionClose => 'Cerrar';

  @override
  String activityCheckIn(String actor, String plate) {
    return '$actor registró el ingreso de $plate';
  }

  @override
  String activityCheckOut(String actor, String plate, String amount) {
    return '$actor registró la salida de $plate · Cobro: $amount';
  }

  @override
  String activityCheckOutNoAmount(String actor, String plate) {
    return '$actor registró la salida de $plate';
  }

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
  String get themeMode => 'Apariencia';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

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
  String get evidenceGateTitle => 'Ingresa la placa para ver las evidencias';

  @override
  String get evidenceGateHint =>
      'La placa impresa en el recibo es la clave de acceso.';

  @override
  String get evidenceUnlock => 'Ver evidencias';

  @override
  String get policiesTitle => 'Políticas y contrato';

  @override
  String get bookingTitle => 'Reserva tu espacio';

  @override
  String get bookingSubtitle =>
      'Elige el tipo de vehículo y asegura tu cupo en segundos.';

  @override
  String get bookingOnline => 'Reserva en línea';

  @override
  String get bookingSectionAvailability => 'Disponibilidad ahora';

  @override
  String get bookingSectionHint => 'Datos en tiempo real del parqueadero';

  @override
  String get bookingRefresh => 'Actualizar disponibilidad';

  @override
  String bookingAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count disponibles',
      one: '1 disponible',
    );
    return '$_temp0';
  }

  @override
  String get bookingFull => 'Completo';

  @override
  String get bookingUnlimited => 'Sin límite';

  @override
  String get bookingNoSpaceTitle => 'No hay cupo en este momento';

  @override
  String get bookingNoSpaceHint =>
      'Se acaba de llenar. Puedes llamar al parqueadero o volver a intentar en unos minutos.';

  @override
  String bookingFromPrice(String price) {
    return 'Desde $price/hora';
  }

  @override
  String get bookingPriceUndefined => 'Tarifa en recepción';

  @override
  String get bookingSelectCategory => 'Elige un tipo de vehículo';

  @override
  String get bookingFormTitle => 'Tus datos';

  @override
  String get bookingPhone => 'Celular';

  @override
  String get bookingPhoneHint => '300 000 0000';

  @override
  String get bookingName => 'Nombre';

  @override
  String get bookingDuration => '¿Cuánto tiempo necesitas?';

  @override
  String bookingDurationHours(int hours) {
    return '$hours h';
  }

  @override
  String get bookingSubmit => 'Reservar espacio';

  @override
  String get bookingSubmitting => 'Reservando…';

  @override
  String get bookingLegal =>
      'Al reservar aceptas las políticas y el contrato del parqueadero.';

  @override
  String get bookingPolicies => 'Ver políticas';

  @override
  String get bookingSuccessTitle => '¡Reserva confirmada!';

  @override
  String get bookingSuccessHint =>
      'Muestra este código al llegar al parqueadero.';

  @override
  String get bookingCode => 'Código de reserva';

  @override
  String get bookingPlateDetail => 'Placa';

  @override
  String get bookingCategoryDetail => 'Tipo';

  @override
  String get bookingUntil => 'Válida hasta';

  @override
  String get bookingAddress => 'Dirección';

  @override
  String get bookingAnother => 'Hacer otra reserva';

  @override
  String get bookingLookupTitle => '¿Ya reservaste?';

  @override
  String get bookingLookupHint =>
      'Consulta o cancela con el código y el celular de tu reserva.';

  @override
  String get bookingLookupCode => 'Código';

  @override
  String get bookingLookupPhone => 'Celular';

  @override
  String get bookingLookupAction => 'Consultar reserva';

  @override
  String get bookingLookupChecking => 'Buscando…';

  @override
  String get bookingLookupInvalid => 'Escribe el código y un celular válido.';

  @override
  String get bookingLookupNotFound =>
      'No encontramos una reserva activa con esos datos. Revisa el código y el celular.';

  @override
  String bookingLookupFound(String plate) {
    return 'Reserva de $plate';
  }

  @override
  String get bookingCancel => 'Cancelar reserva';

  @override
  String get bookingCancelTitle => '¿Cancelar tu reserva?';

  @override
  String bookingCancelBody(String plate) {
    return 'Se liberará el cupo de $plate. Esta acción no se puede deshacer.';
  }

  @override
  String get bookingCancelledTitle => 'Reserva cancelada';

  @override
  String get bookingCancelledHint =>
      'El cupo volvió a quedar disponible. Gracias por avisar.';

  @override
  String get bookingErrorNotFound =>
      'No encontramos esa reserva. Revisa el código o llama al parqueadero.';

  @override
  String get bookingCall => 'Llamar';

  @override
  String get bookingWhatsApp => 'WhatsApp';

  @override
  String bookingWhatsAppMessage(String lot) {
    return 'Hola, tengo una reserva en $lot.';
  }

  @override
  String get bookingEmpty =>
      'No hay tipos de vehículo configurados. Llama al parqueadero.';

  @override
  String get bookingFooter =>
      'Reserva sujeta a disponibilidad. Si no puedes asistir, avísanos.';

  @override
  String get bookingErrorFull =>
      'Ese tipo de vehículo ya no tiene espacio. Elige otro o intenta más tarde.';

  @override
  String get bookingErrorExists =>
      'Ya tienes una reserva activa para esta placa.';

  @override
  String get bookingErrorLimit =>
      'Alcanzaste el límite de reservas para este teléfono.';

  @override
  String get bookingErrorInside =>
      'Este vehículo ya está dentro del parqueadero.';

  @override
  String get bookingErrorWindow => 'La hora de la reserva no es válida.';

  @override
  String get bookingErrorPhone =>
      'Ingresa un celular válido de 10 dígitos (empieza por 3).';

  @override
  String get bookingErrorName => 'Ingresa tu nombre.';

  @override
  String get bookingErrorPlate => 'Ingresa una placa válida.';

  @override
  String get bookingErrorLot => 'No encontramos este parqueadero.';

  @override
  String get bookingCaptchaLabel => 'Verificación de seguridad';

  @override
  String get bookingCaptchaPending =>
      'Completa la verificación de seguridad para reservar.';

  @override
  String get bookingCaptchaExpired =>
      'La verificación venció. Complétala de nuevo.';

  @override
  String get bookingCaptchaFailed =>
      'No pudimos verificar que eres una persona. Inténtalo de nuevo.';

  @override
  String get bookingCaptchaUnavailable =>
      'La verificación de seguridad no está disponible en este momento. Intenta en unos minutos o llama al parqueadero.';

  @override
  String get bookingCaptchaRequired =>
      'Este parqueadero pide una verificación de seguridad para reservar en línea. Recarga la página o llama al parqueadero.';

  @override
  String get bookingErrorThrottled =>
      'Hay muchas reservas en línea en este momento. Intenta en unos minutos o llama al parqueadero.';

  @override
  String get policiesInvalid =>
      'No pudimos cargar las políticas de este parqueadero.';

  @override
  String get policiesEmpty => 'Este parqueadero aún no publicó sus políticas.';

  @override
  String get policiesHelp =>
      'Al ingresar el vehículo aceptas estas políticas. Si tienes dudas, contacta al parqueadero.';

  @override
  String get evidenceOpenPolicies => 'Ver políticas y contrato del parqueadero';

  @override
  String get evidenceTitle => 'Evidencias del vehículo';

  @override
  String get evidenceInvalid =>
      'Este enlace no es válido o la placa no coincide.';

  @override
  String evidenceKey(String plate) {
    return 'Clave de acceso: $plate';
  }

  @override
  String evidenceEntry(String when) {
    return 'Ingreso: $when';
  }

  @override
  String get evidenceEmpty => 'Este ingreso no tiene fotos ni videos.';

  @override
  String get evidenceNoPhotos => 'Sin fotos.';

  @override
  String evidencePhotos(int count) {
    return 'Fotos ($count)';
  }

  @override
  String evidenceVideos(int count) {
    return 'Videos ($count)';
  }

  @override
  String get evidencePlayVideo => 'Ver video';

  @override
  String get evidenceHelp =>
      'Comparte este enlace solo con el propietario del vehículo. Las evidencias se eliminan según la retención del parqueadero.';

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
  String get errorLostTicketPassMethod =>
      'Un tiquete perdido no se puede cobrar con mensualidad; elige otro medio de pago';

  @override
  String get errorStaleExitTime =>
      'Esta salida se registró sin conexión hace más de 12 horas y no se puede sincronizar; regístrala de nuevo';

  @override
  String get errorEvidenceNotFound =>
      'No se encontraron las fotos de evidencia; tómalas de nuevo';

  @override
  String get errorEvidenceAlreadyUsed =>
      'Estas fotos de evidencia ya se usaron en otra entrada; tómalas de nuevo';

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
  String get syncNow => 'Reintentar ahora';

  @override
  String syncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflictos por resolver',
      one: '1 conflicto por resolver',
    );
    return '$_temp0';
  }

  @override
  String get syncConflictTitle => 'Cambio en conflicto';

  @override
  String get syncConflictHint =>
      'Otra persona cambió este registro mientras lo editabas.';

  @override
  String get syncKeepMine => 'Quedarme con lo mío';

  @override
  String get syncKeepTheirs => 'Quedarme con lo del servidor';

  @override
  String get conflictTitle => 'Resolver conflicto';

  @override
  String get syncConflictSection => 'Requieren tu decisión';

  @override
  String get syncConflictTileSubtitle => 'Otra persona cambió este registro.';

  @override
  String get conflictIntro =>
      'Tus cambios sin conexión chocan con cambios de otra persona.';

  @override
  String get conflictColumnBase => 'Antes';

  @override
  String get conflictColumnMine => 'Mío';

  @override
  String get conflictColumnTheirs => 'Del servidor';

  @override
  String conflictAutoMerged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios sin choque se aplicarán solos.',
      one: '1 cambio sin choque se aplicará solo.',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get conflictPickEach => 'Elige un valor para cada campo.';

  @override
  String get conflictApply => 'Aplicar selección';

  @override
  String get conflictDeletedTitle => 'Otra persona eliminó este registro.';

  @override
  String get conflictDeletedBody =>
      'Tus cambios no se pueden aplicar. Puedes aceptar la eliminación y volver a ingresarlos si hace falta.';

  @override
  String get conflictAcceptDeletion => 'Aceptar la eliminación';

  @override
  String get conflictEditedTitle =>
      'Otra persona editó este registro mientras lo eliminabas.';

  @override
  String get conflictKeepDelete => 'Eliminar de todos modos';

  @override
  String get conflictKeepRecord => 'Conservar el registro';

  @override
  String get conflictAgain =>
      'El registro cambió de nuevo. Revisa los valores actuales.';

  @override
  String get conflictEmpty => 'No hay conflictos pendientes.';

  @override
  String get conflictNone => 'Sin valor';

  @override
  String get cfYes => 'Sí';

  @override
  String get cfNo => 'No';

  @override
  String get waitlistJoinTitle => 'Lista de espera';

  @override
  String get waitlistJoinHint =>
      'Estamos llenos. Déjanos tus datos y te avisamos cuando se libere un cupo.';

  @override
  String get waitlistJoinAction => 'Unirme a la lista de espera';

  @override
  String get waitlistWaitFor => 'Puedo esperar hasta:';

  @override
  String get waitlistHoldFor => 'Reservar el cupo por:';

  @override
  String waitlistHoldHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String get waitlistJoined => 'Estás en la lista de espera';

  @override
  String waitlistPosition(int position) {
    return 'Tu turno: $position';
  }

  @override
  String waitlistCode(int code) {
    return 'Código $code';
  }

  @override
  String get waitlistKeepCode =>
      'Guarda este código: lo necesitas para reclamar o salir de la lista.';

  @override
  String get waitlistNotifyWhatsapp => 'Te avisaremos por WhatsApp.';

  @override
  String get waitlistNotifyScreen =>
      'Mantén esta página abierta o llámanos: te avisaremos aquí.';

  @override
  String get waitlistOfferTitle => '¡Se liberó un cupo!';

  @override
  String waitlistOfferBody(String time) {
    return 'Resérvalo antes de las $time.';
  }

  @override
  String get waitlistClaim => 'Reclamar mi cupo';

  @override
  String get waitlistLeave => 'Salir de la lista';

  @override
  String get waitlistLeft => 'Saliste de la lista de espera';

  @override
  String get waitlistExpiredTitle => 'Tu oferta venció';

  @override
  String get waitlistExpiredHint => 'Puedes volver a unirte a la lista.';

  @override
  String waitlistWaitingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas esperando',
      one: '1 persona esperando',
    );
    return '$_temp0';
  }

  @override
  String get waitlistLookupLabel => 'Código de lista de espera';

  @override
  String get waitlistDeskTitle => 'Lista de espera';

  @override
  String get waitlistDeskEmptyTitle => 'Nadie en lista de espera';

  @override
  String get waitlistDeskEmptyHint =>
      'Cuando el parqueadero se llene, los clientes web podrán anotarse aquí.';

  @override
  String waitlistDeskOffered(String time) {
    return 'Oferta hasta $time';
  }

  @override
  String get waitlistDeskCallCustomer =>
      'Llamar: el cliente no tiene WhatsApp automático';

  @override
  String get waitlistDeskClaim => 'Dar el cupo';

  @override
  String get waitlistDeskRemove => 'Quitar de la lista';

  @override
  String waitlistDeskRemoveBody(String plate) {
    return 'Se quitará a $plate de la lista y se liberará su oferta.';
  }

  @override
  String get waitlistSettingsTitle => 'Lista de espera';

  @override
  String get waitlistSettingsEnabled => 'Activar lista de espera pública';

  @override
  String get waitlistSettingsClaimMinutes => 'Minutos para reclamar una oferta';

  @override
  String get waitlistSettingsMaxEntries => 'Máximo de personas en lista';

  @override
  String get waitlistOfferChip => 'Oferta';

  @override
  String get notifTypeWaitlist => 'Lista de espera';

  @override
  String get errorWaitlistDisabled => 'La lista de espera no está disponible.';

  @override
  String get errorWaitlistNotNeeded =>
      'Hay cupo disponible: puedes reservar ahora.';

  @override
  String get errorWaitlistExists => 'Esa placa ya está en la lista de espera.';

  @override
  String get errorWaitlistLimit =>
      'Este celular ya tiene dos turnos en la lista.';

  @override
  String get errorWaitlistFull => 'La lista de espera está llena.';

  @override
  String get errorWaitlistWindow => 'Elige un tiempo de espera válido.';

  @override
  String get errorWaitlistNotFound => 'No encontramos ese turno.';

  @override
  String get errorWaitlistNotOffered => 'Aún no hay un cupo para ti.';

  @override
  String get errorOfferGone => 'La oferta ya no está disponible.';

  @override
  String get reportWaitlistTitle => 'Lista de espera';

  @override
  String get reportWaitlistJoined => 'Anotados';

  @override
  String get reportWaitlistOffered => 'Ofertas';

  @override
  String get reportWaitlistClaimed => 'Reclamadas';

  @override
  String get homeForecastTitle => 'Pronóstico de ocupación';

  @override
  String get homeForecastHint => 'Próximas 12 horas según el historial';

  @override
  String homeForecastFullAt(String group, String time) {
    return '$group: se llenaría cerca de las $time';
  }

  @override
  String homeForecastFullNow(String group) {
    return '$group: ya está lleno';
  }

  @override
  String get homeForecastNotFull =>
      'No se prevé que se llene en las próximas 12 horas';

  @override
  String get homeForecastGroupCar => 'Autos';

  @override
  String get homeForecastGroupMoto => 'Motos';

  @override
  String get homeForecastConfidenceHigh => 'Confianza alta';

  @override
  String get homeForecastConfidenceMedium => 'Confianza media';

  @override
  String get homeForecastConfidenceLow => 'Confianza baja';

  @override
  String homeForecastBarSemantics(int hour, int expected, int capacity) {
    return '$hour:00, se esperan $expected de $capacity';
  }

  @override
  String get homeForecastInsufficient =>
      'Aún reunimos historial para pronosticar';

  @override
  String get homeForecastNoCapacity =>
      'Configura la capacidad para ver el pronóstico';

  @override
  String get homeForecastDisabled => 'El pronóstico está desactivado';

  @override
  String get homeForecastUnavailable => 'Pronóstico no disponible';

  @override
  String get reportsForecastTitle => 'Precisión del pronóstico';

  @override
  String get reportsForecastSubtitle =>
      'Error medio al repetir el pronóstico sobre las últimas semanas';

  @override
  String get reportsForecastRun => 'Calcular precisión';

  @override
  String reportsForecastMae(String value) {
    return 'Error medio: $value vehículos';
  }

  @override
  String reportsForecastPriorOnly(String value) {
    return 'Solo con el historial: $value';
  }

  @override
  String reportsForecastBetter(int percent) {
    return '$percent % mejor con datos en vivo';
  }

  @override
  String reportsForecastLead(int hours, String value) {
    return 'A $hours h: $value';
  }

  @override
  String get reportsForecastEmpty => 'Aún no hay historial suficiente';

  @override
  String get reportsForecastUnavailable => 'No se pudo calcular la precisión';

  @override
  String get publicForecastTitle => '¿Cuándo se llena?';

  @override
  String publicForecastFullAt(String time) {
    return 'Suele llenarse cerca de las $time';
  }

  @override
  String get publicForecastFullNow => 'Ahora está lleno';

  @override
  String get publicForecastNotFull => 'No suele llenarse en las próximas horas';

  @override
  String get publicForecastGroupCar => 'Autos';

  @override
  String get publicForecastGroupMoto => 'Motos';

  @override
  String get publicForecastLevelFree => 'Con espacio';

  @override
  String get publicForecastLevelBusy => 'Concurrido';

  @override
  String get publicForecastLevelFull => 'Lleno';

  @override
  String get publicForecastDisclaimer =>
      'Estimación según días anteriores; puede variar.';

  @override
  String get navAnomalies => 'Anomalías';

  @override
  String get anomaliesTitle => 'Anomalías de caja';

  @override
  String get anomaliesSettings => 'Umbrales';

  @override
  String anomaliesOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abiertas',
      one: '1 abierta',
    );
    return '$_temp0';
  }

  @override
  String get anomaliesStatusOpen => 'Abiertas';

  @override
  String get anomaliesStatusAcknowledged => 'Reconocidas';

  @override
  String get anomaliesStatusDismissed => 'Descartadas';

  @override
  String get anomaliesStatusAll => 'Todas';

  @override
  String get anomaliesClearFilters => 'Limpiar filtros';

  @override
  String get anomaliesRuleLabel => 'Regla';

  @override
  String get anomaliesSeverityLabel => 'Severidad';

  @override
  String get anomaliesSeverityLow => 'Baja';

  @override
  String get anomaliesSeverityMedium => 'Media';

  @override
  String get anomaliesSeverityHigh => 'Alta';

  @override
  String get anomalyRuleShiftShortage => 'Faltantes repetidos';

  @override
  String get anomalyRuleLostTicketRate => 'Tasa alta de ticket perdido';

  @override
  String get anomalyRulePostCloseAdjustment => 'Ajuste después del cierre';

  @override
  String get anomalyRuleZeroCharge => 'Salida sin cobro';

  @override
  String get anomalyRuleShortLostTicket => 'Ticket perdido con estadía corta';

  @override
  String get anomalyRuleDiscountRate => 'Descuentos frecuentes';

  @override
  String get anomalyRuleShiftOpenLong => 'Turno abierto demasiado tiempo';

  @override
  String get anomalyRuleSessionOpenLong => 'Vehículo dentro por muchos días';

  @override
  String anomalyDescShiftShortage(int count, String amount) {
    return '$count turnos con faltante, total $amount';
  }

  @override
  String anomalyDescLostTicketRate(String rate, String baseline) {
    return '$rate % de tickets perdidos frente a $baseline % de la sede';
  }

  @override
  String anomalyDescPostCloseAdjustment(String from, String to, String admin) {
    return 'Diferencia $from → $to ajustada por $admin';
  }

  @override
  String anomalyDescZeroCharge(String plate, String method) {
    return '$plate salió sin cobro ($method)';
  }

  @override
  String anomalyDescShortLostTicket(String plate, int minutes) {
    return '$plate: ticket perdido tras $minutes min';
  }

  @override
  String anomalyDescDiscountRate(int count, String share) {
    return '$count descuentos ($share % de las salidas)';
  }

  @override
  String anomalyDescShiftOpenLong(int hours) {
    return 'Abierto desde hace $hours h';
  }

  @override
  String anomalyDescSessionOpenLong(String plate, int days) {
    return '$plate lleva $days días dentro';
  }

  @override
  String get anomalyAcknowledge => 'Reconocer';

  @override
  String get anomalyDismiss => 'Descartar';

  @override
  String get anomalyNoteLabel => 'Nota';

  @override
  String get anomalyNoteRequired => 'Escribe una nota de al menos 3 caracteres';

  @override
  String get anomalyViewAudit => 'Ver auditoría';

  @override
  String get anomalyViewContext => 'Ver detalle';

  @override
  String get anomaliesEmptyTitle => 'Todo en orden';

  @override
  String get anomaliesEmpty => 'No hay anomalías con estos filtros.';

  @override
  String get anomaliesSettingsEnabled => 'Detección activa';

  @override
  String get anomaliesSettingsSaved => 'Umbrales guardados';

  @override
  String get anomaliesSettingsWindowDays => 'Ventana (días)';

  @override
  String get anomaliesSettingsShortageMinAmount => 'Faltante mínimo por turno';

  @override
  String get anomaliesSettingsShortageMinShifts =>
      'Turnos con faltante para alertar';

  @override
  String get anomaliesSettingsLostTicketMinClosed =>
      'Salidas mínimas por operador';

  @override
  String get anomaliesSettingsLostTicketMinRatePct =>
      'Tasa mínima de ticket perdido (%)';

  @override
  String get anomaliesSettingsLostTicketFactorPct =>
      'Veces la tasa de la sede (%)';

  @override
  String get anomaliesSettingsAdjustmentMinAmount =>
      'Ajuste mínimo tras el cierre';

  @override
  String get anomaliesSettingsShortStayMinutes => 'Estadía corta (minutos)';

  @override
  String get anomaliesSettingsDiscountMinCount =>
      'Descuentos mínimos por admin';

  @override
  String get anomaliesSettingsDiscountSharePct => 'Cuota de descuentos (%)';

  @override
  String get anomaliesSettingsShiftOpenHours => 'Horas para turno abierto';

  @override
  String get anomaliesSettingsSessionOpenDays => 'Días para vehículo dentro';

  @override
  String get notifTypeCashAnomaly => 'Anomalía de caja';

  @override
  String get errorAnomalyNotFound => 'No encontramos esa anomalía';

  @override
  String get errorAnomalyAlreadyResolved => 'Esa anomalía ya fue revisada';

  @override
  String get errorAnomalyNoteRequired =>
      'Escribe una nota de al menos 3 caracteres';

  @override
  String get errorInvalidAnomalySetting => 'Revisa los valores de los umbrales';

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
  String get entitySettings => 'Configuración';

  @override
  String get categoryFullHint =>
      'Las categorías llenas aparecen deshabilitadas.';

  @override
  String get navLots => 'Sedes';

  @override
  String lotMembersTitle(String name) {
    return 'Miembros de $name';
  }

  @override
  String get lotMembersEmpty => 'Esta sede no tiene usuarios';

  @override
  String get userInactive => 'inactivo';

  @override
  String get lotsTitle => 'Sedes del parqueadero';

  @override
  String get navAudit => 'Auditoría';

  @override
  String get navDiagnostics => 'Diagnóstico';

  @override
  String get diagnosticsTitle => 'Diagnóstico';

  @override
  String get diagnosticsWhatsapp => 'WhatsApp';

  @override
  String get diagnosticsWhatsappPending => 'En cola';

  @override
  String get diagnosticsWhatsappFailedCount => 'Fallidos';

  @override
  String get diagnosticsWhatsappSent => 'Enviados (24 h)';

  @override
  String get diagnosticsWhatsappEmpty =>
      'Sin mensajes de WhatsApp en el periodo';

  @override
  String diagnosticsWhatsappAttempts(int count) {
    return '$count intentos';
  }

  @override
  String get diagnosticsSystem => 'Sistema';

  @override
  String diagnosticsMigrations(int count) {
    return 'Migraciones aplicadas ($count)';
  }

  @override
  String diagnosticsLots(int active, int total) {
    return 'Sedes activas: $active de $total';
  }

  @override
  String get diagnosticsOpenSessions => 'Sesiones abiertas';

  @override
  String get diagnosticsStaleSessions => 'Sesiones abiertas +24 h';

  @override
  String get diagnosticsOpenShifts => 'Turnos abiertos +12 h';

  @override
  String get diagnosticsPendingPayments => 'Pagos de mensualidad pendientes';

  @override
  String get diagnosticsReservations => 'Reservas activas';

  @override
  String get diagnosticsIdempotency => 'Claves de idempotencia';

  @override
  String get diagnosticsNotifications => 'Notificaciones';

  @override
  String get diagnosticsPendingPush => 'Pendientes de push';

  @override
  String get diagnosticsDeadPush => 'Fallidas tras 3 intentos';

  @override
  String get diagnosticsUnread => 'Sin leer / total';

  @override
  String get diagnosticsStorage => 'Almacenamiento';

  @override
  String diagnosticsErrors(int count) {
    return 'Errores de la app ($count)';
  }

  @override
  String get diagnosticsErrorsEmpty =>
      'Sin errores reportados en los últimos 7 días';

  @override
  String get diagnosticsErrorDetail => 'Detalle del error';

  @override
  String get auditExport => 'Exportar';

  @override
  String get auditExportPdf => 'Exportar PDF';

  @override
  String get auditExportCsv => 'Copiar CSV';

  @override
  String get auditCopied => 'CSV copiado al portapapeles';

  @override
  String get auditActor => 'Actor';

  @override
  String get auditAllActors => 'Todos';

  @override
  String get auditSearch => 'Buscar';

  @override
  String get auditSearchHint => 'Placa, usuario, tabla o valor';

  @override
  String get auditTitle => 'Auditoría';

  @override
  String get auditTable => 'Tabla';

  @override
  String get auditAllTables => 'Todas';

  @override
  String get auditFilterDates => 'Filtrar por fecha';

  @override
  String get auditEmpty => 'Sin cambios registrados';

  @override
  String get auditChangesTitle => 'Cambios';

  @override
  String get lotAdd => 'Nueva sede';

  @override
  String get lotCode => 'Código (2-10 letras/números)';

  @override
  String get lotLabel => 'Sede';

  @override
  String get lotName => 'Nombre de la sede';

  @override
  String get lotAddress => 'Dirección (opcional)';

  @override
  String get lotsEmpty => 'Aún no hay sedes';

  @override
  String lotMembers(int count) {
    return '$count usuarios';
  }

  @override
  String get navReservations => 'Reservas';

  @override
  String get reservationsTitle => 'Reservas de cupo';

  @override
  String get reservationAdd => 'Nueva reserva';

  @override
  String get reservationCreated => 'Reserva creada';

  @override
  String get reservationCancelled => 'Reserva cancelada';

  @override
  String get reservationsEmpty => 'No hay reservas activas';

  @override
  String reservationExpiresIn(String duration) {
    return 'Vence en $duration';
  }

  @override
  String get reservationInGrace => 'En tolerancia';

  @override
  String get reservationQuick2h => '+2 h';

  @override
  String get reservationQuick4h => '+4 h';

  @override
  String get reservationEndOfDay => 'Fin del día';

  @override
  String reservationUntil(String when) {
    return 'Hasta $when';
  }

  @override
  String reservationUntilLabel(String when) {
    return 'Reservar hasta $when';
  }

  @override
  String get reservationNotes => 'Notas (opcional)';

  @override
  String get reservationCheckIn => 'Registrar entrada';

  @override
  String get checkInHoldTitle => 'Reserva activa';

  @override
  String get reservationCancel => 'Cancelar reserva';

  @override
  String get reservationCancelTitle => '¿Cancelar la reserva?';

  @override
  String reservationCancelBody(String plate) {
    return 'Se liberará el cupo reservado para $plate.';
  }

  @override
  String get sidebarCollapse => 'Contraer menú';

  @override
  String get sidebarExpand => 'Expandir menú';

  @override
  String get navGroupOperation => 'Operación';

  @override
  String get navGroupManagement => 'Gestión';

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
  String get navSettings => 'Configuración';

  @override
  String get navContact => 'Contacto';

  @override
  String get navNotifications => 'Avisos';

  @override
  String get webPushTitle => 'Notificaciones del navegador';

  @override
  String get webPushSubtitle => 'Recibe avisos aunque la pestaña esté cerrada.';

  @override
  String get webPushDenied =>
      'El navegador no dio permiso para las notificaciones';

  @override
  String get notificationsTitle => 'Notificaciones';

  @override
  String get notificationsEmpty => 'No hay notificaciones';

  @override
  String get notificationsMarkAll => 'Marcar todo leído';

  @override
  String get navRecords => 'Registros';

  @override
  String get recordsTitle => 'Registros de vehículos';

  @override
  String recordsCount(int count) {
    return '$count registros';
  }

  @override
  String recordsEmpty(String plate) {
    return 'Sin registros para «$plate»';
  }

  @override
  String get recordsEmptyAll => 'Aún no hay registros en esta sede';

  @override
  String get recordsClearFilter => 'Ver todos';

  @override
  String recordsOpenSince(String since, String duration) {
    return 'Dentro desde $since · $duration';
  }

  @override
  String recordsWindow(String duration, String entry, String exit) {
    return '$entry → $exit · $duration';
  }

  @override
  String get recordsRangeAll => 'Todo';

  @override
  String get recordsRangeToday => 'Hoy';

  @override
  String get recordsRangeWeek => '7 días';

  @override
  String get recordsRangeMonth => '30 días';

  @override
  String get recordsRangeTooltip => 'Rango de fechas';

  @override
  String get recordsExportCsv => 'Copiar CSV';

  @override
  String get recordsExportPdf => 'Exportar PDF';

  @override
  String get recordsCsvCopied => 'CSV copiado al portapapeles';

  @override
  String get recordsExportEmpty => 'No hay registros para exportar';

  @override
  String get recordsEntry => 'Ingreso';

  @override
  String get recordsExit => 'Salida';

  @override
  String get recordsDuration => 'Duración';

  @override
  String get recordsAmount => 'Cobro';

  @override
  String get recordsLoadMore => 'Cargar más';

  @override
  String get navHistory => 'Historial';

  @override
  String get homeShift => 'Turno / Caja';

  @override
  String get checkOutNoShift =>
      'No hay turno abierto: este cobro no entrará en el arqueo.';

  @override
  String get shiftUnavailable => 'Turno no disponible';

  @override
  String get shiftOffline =>
      'Necesitas conexión para operar la caja y el arqueo.';

  @override
  String get shiftHistoryFilter => 'Filtrar por fecha';

  @override
  String get shiftHistoryClearFilter => 'Quitar filtro';

  @override
  String get shiftHistoryEmpty => 'No hay turnos en el rango seleccionado';

  @override
  String get shiftCardSales => 'Ventas con tarjeta';

  @override
  String get shiftTransferSales => 'Ventas por transferencia';

  @override
  String get shiftPassSales => 'Mensualidades';

  @override
  String get shiftSessionCount => 'Salidas cobradas';

  @override
  String get shiftCashMovements => 'Movimientos de caja';

  @override
  String get shiftReconciliation => 'Arqueo';

  @override
  String get shiftNotesTitle => 'Notas';

  @override
  String get actionExportPdf => 'Exportar PDF';

  @override
  String get actionShare => 'Compartir';

  @override
  String get shiftTitle => 'Turno / Caja';

  @override
  String get shiftNoOpen => 'No hay turno abierto';

  @override
  String get shiftOpeningFloat => 'Base inicial';

  @override
  String get shiftOpen => 'Abrir turno';

  @override
  String get shiftOpenTitle => 'Turno abierto';

  @override
  String get shiftOpenedDone => 'Turno abierto correctamente';

  @override
  String get shiftClosedDone => 'Turno cerrado correctamente';

  @override
  String get shiftMovementDone => 'Movimiento de caja registrado';

  @override
  String get shiftAdjustedDone => 'Cierre del turno corregido';

  @override
  String shiftOpenedAt(String time) {
    return 'Abierto: $time';
  }

  @override
  String get shiftSales => 'Ventas';

  @override
  String get shiftCashSales => 'Ventas en efectivo';

  @override
  String get shiftWithdrawals => 'Retiros';

  @override
  String get shiftDeposits => 'Ingresos de efectivo';

  @override
  String get shiftDiscounts => 'Descuentos';

  @override
  String get shiftPassPayments => 'Mensualidades cobradas';

  @override
  String get shiftPassCash => 'Mensualidades en efectivo';

  @override
  String get shiftExpectedCash => 'Efectivo esperado';

  @override
  String get shiftSessions => 'Salidas';

  @override
  String get shiftWithdraw => 'Retirar efectivo';

  @override
  String get shiftDeposit => 'Ingresar efectivo';

  @override
  String get shiftClose => 'Cerrar turno';

  @override
  String get shiftDifferenceConfirmTitle => 'El arqueo no cuadra';

  @override
  String shiftDifferenceConfirmBody(String amount) {
    return 'Diferencia de $amount frente al efectivo esperado. ¿Cerrar el turno igualmente?';
  }

  @override
  String get shiftClosedTitle => 'Turno cerrado';

  @override
  String get cashCountTitle => 'Contar efectivo';

  @override
  String cashCountUse(String amount) {
    return 'Usar $amount';
  }

  @override
  String get shiftAdjust => 'Corregir cierre de turno';

  @override
  String get shiftCountedCash => 'Efectivo contado';

  @override
  String get shiftDifference => 'Diferencia';

  @override
  String get shiftNotes => 'Notas';

  @override
  String get shiftReason => 'Motivo';

  @override
  String get shiftHistory => 'Turnos recientes';

  @override
  String get errorShiftAlreadyOpen => 'Ya tienes un turno abierto';

  @override
  String get errorNoOpenShift => 'No hay un turno abierto';

  @override
  String get errorShiftNotFound => 'Turno no encontrado';

  @override
  String get errorLastAdmin => 'No puedes dejar el sistema sin administradores';

  @override
  String get errorCannotDeleteSelf => 'No puedes eliminar tu propia cuenta';

  @override
  String get errorPaymentNotFound => 'Pago no encontrado';

  @override
  String get errorPaymentAlreadyProcessed => 'Este pago ya fue procesado';

  @override
  String get errorShiftStillOpen => 'El turno sigue abierto';

  @override
  String get errorShiftAdjustReason => 'Indica el motivo de la corrección';

  @override
  String get errorInvalidOpeningFloat => 'La base inicial no es válida';

  @override
  String get errorInvalidCountedCash => 'El efectivo contado no es válido';

  @override
  String get errorInvalidCashMovement => 'El movimiento de caja no es válido';

  @override
  String get errorCashMovementReason => 'Indica el motivo del movimiento';

  @override
  String get errorInvalidDiscount => 'El descuento no es válido';

  @override
  String get errorDiscountReason => 'Indica el motivo del descuento';

  @override
  String get errorVehicleBlacklisted =>
      'Este vehículo está bloqueado; un administrador debe desbloquearlo';

  @override
  String get vehiclePhone => 'Teléfono del cliente';

  @override
  String get vehiclePhoneHint => '+57 300 111 2233';

  @override
  String get vehiclePhoneTitle => 'Teléfono para avisos';

  @override
  String get vehicleAddPhone => 'Agregar teléfono';

  @override
  String get vehicleEditPhone => 'Editar teléfono';

  @override
  String get vehicleOwner => 'Propietario';

  @override
  String get vehicleOwnerNameOptional => 'Nombre del propietario (opcional)';

  @override
  String get vehicleOwnerNameHint => 'Ej. Paul Realpe';

  @override
  String get vehicleOwnerTitle => 'Datos del propietario';

  @override
  String get vehicleOwnerHint =>
      'Opcional: útil para mensualidades o si dejan llaves.';

  @override
  String get vehicleAddOwner => 'Agregar propietario';

  @override
  String get vehicleEditOwner => 'Editar datos del propietario';

  @override
  String get errorInvalidOwnerName =>
      'Escribe el nombre completo (2 a 120 caracteres)';

  @override
  String get vehicleSendWhatsapp => 'Enviar recibo por WhatsApp';

  @override
  String vehicleWhatsappReady(String plate) {
    return 'Hola, tu vehículo $plate está listo para retirar.';
  }

  @override
  String get vehicleChargeAction => 'Cobrar en caja';

  @override
  String vehicleEvidenceAction(int count) {
    return 'Ver evidencias ($count)';
  }

  @override
  String sessionEvidenceTitle(String plate) {
    return 'Evidencias de $plate';
  }

  @override
  String get sessionEvidenceEmpty => 'Sin fotos ni videos para esta sesión';

  @override
  String sessionEvidencePhotoLabel(int index) {
    return 'Foto $index';
  }

  @override
  String sessionEvidenceVideoLabel(int seconds) {
    return 'Video de $seconds s';
  }

  @override
  String sessionEvidenceDurationShort(int seconds) {
    return '$seconds s';
  }

  @override
  String get sessionEvidenceOpenFailed => 'No se pudo abrir la evidencia';

  @override
  String sessionEvidenceShort(int count) {
    return 'Evidencias ($count)';
  }

  @override
  String get vehicleWhatsappReadyAction => 'Avisar que está listo';

  @override
  String vehicleWhatsappReceipt(String plate) {
    return 'Hola, te compartimos el recibo del vehículo $plate:';
  }

  @override
  String vehicleWhatsappHello(String plate) {
    return 'Hola, te escribimos del parqueadero por el vehículo $plate.';
  }

  @override
  String get vehicleWhatsappThanks => '¡Gracias por tu visita!';

  @override
  String get errorInvalidPhone => 'Escribe un teléfono válido (7 a 15 dígitos)';

  @override
  String get errorWhatsappUnavailable =>
      'No se pudo abrir WhatsApp en este dispositivo';

  @override
  String get errorVersionConflict =>
      'Otra persona cambió este registro. Revisa el conflicto desde el ícono de sincronización.';

  @override
  String get errorConflictPending =>
      'Resuelve primero el conflicto pendiente de este registro.';

  @override
  String get errorVersionRequired =>
      'Actualiza la aplicación para editar este registro.';

  @override
  String get errorMinVersionRequired =>
      'Define primero la versión mínima de la app.';

  @override
  String get errorMapsUnavailable =>
      'No se pudo abrir el mapa en este dispositivo';

  @override
  String get bookingDirections => 'Cómo llegar';

  @override
  String get vehicleNotes => 'Notas del vehículo';

  @override
  String get vehicleNotesHint => 'Rayones, incidentes, acuerdos…';

  @override
  String get vehicleAddNotes => 'Agregar nota';

  @override
  String get vehicleEditNotes => 'Editar nota';

  @override
  String get vehicleBlacklist => 'Bloquear vehículo';

  @override
  String get vehicleUnblock => 'Desbloquear';

  @override
  String get vehicleBlacklisted => 'Bloqueado';

  @override
  String get vehicleBlacklistTitle => '¿Bloquear vehículo?';

  @override
  String vehicleBlacklistBody(String plate) {
    return '$plate no podrá ingresar hasta que un administrador lo desbloquee.';
  }

  @override
  String get vehicleUnblockTitle => '¿Desbloquear vehículo?';

  @override
  String vehicleUnblockBody(String plate) {
    return '$plate podrá volver a ingresar al parqueadero.';
  }

  @override
  String get vehicleHistoryTitle => 'Historial de vehículo';

  @override
  String get vehicleHistoryAction => 'Ver historial';

  @override
  String get setupTitle => 'Primeros pasos';

  @override
  String setupProgress(int done, int total) {
    return '$done de $total listos';
  }

  @override
  String get setupCategories => 'Categorías de vehículos';

  @override
  String get setupCategoriesHint => 'Carros, motos y otros tipos';

  @override
  String get setupTariffs => 'Tarifas';

  @override
  String get setupTariffsHint => 'Precios por hora, día y noche';

  @override
  String get setupCapacity => 'Espacios y capacidad';

  @override
  String get setupCapacityHint => 'Capacidad en Ajustes o mapa físico';

  @override
  String get setupIdentity => 'Datos del parqueadero';

  @override
  String get setupIdentityHint => 'Dirección y teléfono para recibos y QR';

  @override
  String get vehicleHistoryPrompt =>
      'Busca una placa para ver sus entradas y salidas';

  @override
  String get vehicleHistoryVisits => 'Visitas';

  @override
  String get vehicleHistoryTotalSpent => 'Total pagado';

  @override
  String get vehicleHistoryAllLots => 'Todas las sedes';

  @override
  String vehicleHistoryCurrentLotVisits(int count) {
    return 'En esta sede: $count';
  }

  @override
  String get actionReprintTicket => 'Reimprimir ticket';

  @override
  String get vehicleHistorySessions => 'Movimientos';

  @override
  String get vehicleHistoryNoSessions => 'Sin movimientos registrados';

  @override
  String vehicleHistoryDuration(String duration) {
    return 'Duración: $duration';
  }

  @override
  String get vehicleHistoryOpen => 'En curso';

  @override
  String get navMenu => 'Menú';

  @override
  String get navMenuTooltip => 'Abrir el menú';

  @override
  String get navMore => 'Más';

  @override
  String get navMoreTooltip => 'Más secciones de gestión';

  @override
  String get settingsDiscardTitle => '¿Descartar cambios?';

  @override
  String get settingsDiscardBody =>
      'Hay cambios sin guardar en la configuración.';

  @override
  String get settingsDiscard => 'Descartar';

  @override
  String get spotsCapacityHint =>
      'El mapa debe tener exactamente los espacios configurados en Ajustes.';

  @override
  String spotsGroupCount(int drawn, int target) {
    return '$drawn de $target';
  }

  @override
  String spotsRemaining(int count) {
    return 'Faltan $count';
  }

  @override
  String spotsExcess(int count) {
    return 'Sobran $count';
  }

  @override
  String get errorSpotCapacityReached =>
      'Ya dibujaste todos los espacios configurados';

  @override
  String get errorSpotCapacityRequired =>
      'No puedes dejar menos espacios que los configurados; ajusta la capacidad en Ajustes';

  @override
  String get spotsTitle => 'Mapa del parqueadero';

  @override
  String get spotsAdminOnly => 'Solo un administrador puede editar el mapa';

  @override
  String get spotsAdd => 'Agregar espacio';

  @override
  String get spotsHint => 'Arrastra un espacio para moverlo · toca para editar';

  @override
  String get spotsEmpty =>
      'Aún no hay espacios. Agrega el primero para armar el mapa.';

  @override
  String get spotsAddTitle => 'Nuevo espacio';

  @override
  String get spotsCode => 'Código';

  @override
  String get spotsGroup => 'Grupo';

  @override
  String get spotsActive => 'Disponible';

  @override
  String get spotsActiveHint => 'Desactívalo para mantenimiento';

  @override
  String get spotsReason => 'Motivo del mantenimiento (opcional)';

  @override
  String get spotsReasonHint => 'Ej. fuga de aceite, pintura, vidrio roto';

  @override
  String get spotsReasonInvalid =>
      'Escribe al menos 3 caracteres o déjalo vacío';

  @override
  String get spotsHistory => 'Ver historial';

  @override
  String spotsHistoryTitle(String code) {
    return 'Historial de $code';
  }

  @override
  String get spotsHistoryEmpty => 'Sin cambios de estado';

  @override
  String get spotsHistorySystem => 'Sistema';

  @override
  String get spotsDelete => 'Eliminar espacio';

  @override
  String get spotsDeleteTitle => '¿Eliminar el espacio?';

  @override
  String spotsDeleteBody(String code) {
    return 'El espacio $code saldrá del mapa. El historial se conserva.';
  }

  @override
  String get spotsDragHere => 'Suelta aquí';

  @override
  String get errorSpotCodeTaken => 'Ya existe un espacio con ese código';

  @override
  String get errorSpotCellTaken => 'Esa celda ya está ocupada';

  @override
  String get errorSpotTaken => 'Ese espacio ya está ocupado';

  @override
  String get errorSpotOutOfService => 'Ese espacio está fuera de servicio';

  @override
  String get errorSpotOccupied =>
      'No puedes eliminar un espacio con un vehículo dentro';

  @override
  String get errorSpotGroup => 'El espacio no corresponde al tipo de vehículo';

  @override
  String get errorSpotCodeInvalid =>
      'Código inválido (A-Z, 0-9 y guion; máximo 16)';

  @override
  String get errorSpotNotFound => 'El espacio no existe';

  @override
  String get settingsSectionIdentity => 'Identidad';

  @override
  String get settingsSectionSpaces => 'Espacios y mapa';

  @override
  String get settingsSectionEvidence => 'Evidencia';

  @override
  String get settingsSectionEmergency => 'Emergencias';

  @override
  String get settingsPolicePhone => 'Cuadrante de policía más cercano';

  @override
  String get settingsPolicePhoneHint =>
      'Se usa en el botón de emergencia. Si lo dejas vacío, se llamará al 123.';

  @override
  String get errorInvalidEmergencyPhone =>
      'Escribe un número válido (3 a 15 dígitos)';

  @override
  String get settingsSectionPreferences => 'Preferencias';

  @override
  String get settingsCurrency => 'Moneda';

  @override
  String get settingsCurrencyHint =>
      'Los montos se guardan en la unidad menor de la moneda (COP pesos, USD centavos). Al cambiarla, revisa las tarifas y precios.';

  @override
  String get currencyCop => 'Peso colombiano (COP)';

  @override
  String get currencyUsd => 'Dólar estadounidense (USD)';

  @override
  String get languageTooltip => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsSectionLegal => 'Políticas y contrato';

  @override
  String get settingsLegalPolicy => 'Texto de políticas y contrato de servicio';

  @override
  String get settingsLegalPolicyHint =>
      'Se muestra al cliente en la página de evidencias. El texto admite etiquetas para el nombre, la dirección, el horario y el teléfono.';

  @override
  String get settingsLegalReset => 'Restaurar plantilla';

  @override
  String get settingsLegalResetDone => 'Plantilla restaurada';

  @override
  String get settingsLegalPreview => 'Vista previa';

  @override
  String get settingsLegalPreviewTitle => 'Vista previa de las políticas';

  @override
  String get settingsLegalEmpty =>
      'Sin texto. Usa la plantilla o escribe tus políticas.';

  @override
  String get settingsSectionMessaging => 'Mensajería';

  @override
  String settingsOutOfServiceMapHint(int count) {
    return '$count bahía(s) en mantenimiento · se controla en el mapa';
  }

  @override
  String get settingsOutOfServiceHint =>
      'Se descuentan de los espacios disponibles';

  @override
  String get settingsTitle => 'Configuración del parqueadero';

  @override
  String get settingsCarCapacity => 'Espacios para carros y camionetas';

  @override
  String get settingsMotoCapacity => 'Espacios para motos';

  @override
  String get settingsCarOutOfService => 'Carros fuera de servicio';

  @override
  String get settingsMotoOutOfService => 'Motos fuera de servicio';

  @override
  String get settingsOutOfServiceTooMany =>
      'No puede superar la capacidad configurada';

  @override
  String capacityOutOfService(int count) {
    return '$count fuera de servicio';
  }

  @override
  String get slotMaintenance => 'Mantenimiento';

  @override
  String get slotMaintenanceShort => 'Mant.';

  @override
  String get settingsKeyCapacity => 'Máximo de vehículos con llaves';

  @override
  String get settingsReservationGrace => 'Tolerancia de reservas (min)';

  @override
  String get settingsReservationGraceHint =>
      'Minutos de gracia tras el vencimiento para que el cliente llegue; 0 la desactiva.';

  @override
  String get settingsCapacityHint => '0 = sin límite';

  @override
  String get errorParkingFull =>
      'No hay espacios disponibles para este tipo de vehículo';

  @override
  String get errorKeysFull =>
      'Se alcanzó el máximo de vehículos que pueden dejar las llaves';

  @override
  String get settingsEvidenceRetention => 'Retención de evidencias (días)';

  @override
  String get settingsEvidenceRetentionHint =>
      '0 = conservar siempre. Las fotos más antiguas se borran automáticamente.';

  @override
  String get settingsWhatsappAuto => 'WhatsApp automático';

  @override
  String get settingsWhatsappAutoHint =>
      'Envía los avisos por la API de WhatsApp (requiere credenciales en el servidor). Si está apagado, se abre WhatsApp en el teléfono.';

  @override
  String get whatsappQueued => 'Mensaje en cola de WhatsApp';

  @override
  String get errorWhatsappDisabled =>
      'El WhatsApp automático está desactivado en esta sede';

  @override
  String get settingsName => 'Nombre';

  @override
  String get settingsAddress => 'Dirección';

  @override
  String get settingsSchedule => 'Horario';

  @override
  String get settingsPhone => 'Teléfono';

  @override
  String get settingsWebsite => 'Sitio web';

  @override
  String get settingsWhatsapp => 'Número de WhatsApp';

  @override
  String get settingsSaved => 'Configuración guardada';

  @override
  String get settingsCoverSection => 'Portada de la página pública';

  @override
  String get settingsCoverHint =>
      'Una foto ancha del parqueadero se muestra en la página de reservas.';

  @override
  String get settingsCoverConfigured =>
      'Portada configurada. Puedes reemplazarla cuando quieras.';

  @override
  String get settingsCoverPick => 'Elegir portada';

  @override
  String get settingsLogoSection => 'Logo';

  @override
  String get settingsLogoPick => 'Elegir logo';

  @override
  String get settingsWebsiteInvalid => 'Ingresa una URL válida';

  @override
  String get contactTitle => 'Contacto';

  @override
  String get contactWhatsApp => 'WhatsApp';

  @override
  String get whatsappTooltip => 'Escribir por WhatsApp';

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
  String get homeTodayEmpty => 'Sin movimientos hoy';

  @override
  String get homeToday => 'Hoy';

  @override
  String get homeTodayEntries => 'Entradas';

  @override
  String get homeTodayExits => 'Salidas';

  @override
  String get homeTodayCash => 'Efectivo';

  @override
  String get homeTodayPasses => 'Mensualidades';

  @override
  String get homeTrend => 'Tendencia';

  @override
  String get homeTrendHint => 'Últimos 7 días';

  @override
  String homeTrendRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get homeTrendTotal => 'Ingresos';

  @override
  String get homeTrendEntries => 'Entradas';

  @override
  String get homeTrendExits => 'Salidas';

  @override
  String get homeTrendOpenReports => 'Abrir reportes';

  @override
  String get homeTrendEmpty => 'Sin movimientos en los últimos días';

  @override
  String get homeTrendUnavailable => 'Tendencia no disponible';

  @override
  String homeTrendDay(String date, String amount, int entries, int exits) {
    return '$date: $amount · $entries entradas · $exits salidas';
  }

  @override
  String homeTrendVsPrevious(String delta) {
    return '$delta vs semana anterior';
  }

  @override
  String get homeTrendFlat => 'Igual que la semana anterior';

  @override
  String homeStaleData(String time) {
    return 'Sin conexión · datos guardados de las $time';
  }

  @override
  String get homeCapacityTitle => 'Capacidad del parqueadero';

  @override
  String get homeCapacityCars => 'Carros y camionetas';

  @override
  String get homeCapacityMotos => 'Motos';

  @override
  String get homeCapacityKeys => 'Vehículos con llaves';

  @override
  String homeReservedCount(int count) {
    return '$count reservados';
  }

  @override
  String homeReservationsActive(int count) {
    return '$count reservas activas';
  }

  @override
  String homeReservationsExpiring(int count) {
    return '$count por vencer';
  }

  @override
  String get homeSeeReservations => 'Ver reservas';

  @override
  String get homeNoLimit => 'sin límite';

  @override
  String get homeInsideSeeAll => 'Ver todos';

  @override
  String spotLabel(String code) {
    return 'Espacio $code';
  }

  @override
  String get slotNoSpotAssignedOne => '1 vehículo sin espacio asignado';

  @override
  String slotNoSpotAssigned(int count) {
    return '$count vehículos sin espacio asignado';
  }

  @override
  String get slotBoardTitle => 'Mapa de espacios';

  @override
  String slotBoardFree(int count) {
    return '$count libres';
  }

  @override
  String get slotBoardAll => 'Todos';

  @override
  String get slotBoardCars => 'Carros';

  @override
  String get slotBoardMotos => 'Motos';

  @override
  String get slotBoardHolds => 'Reservas';

  @override
  String get slotBoardHeavy => 'Pesados';

  @override
  String get slotEstimateUnavailable => 'No se pudo calcular la tarifa';

  @override
  String get slotBoardEmpty =>
      'Configura los espacios del parqueadero en Ajustes';

  @override
  String get slotBoardConfigure => 'Configurar';

  @override
  String get slotBoardNoHolds => 'No hay reservas activas';

  @override
  String get slotFree => 'Libre';

  @override
  String get slotOccupied => 'Ocupado';

  @override
  String get slotReserved => 'Reservado';

  @override
  String get slotEstimate => 'Tarifa estimada';

  @override
  String get homeSummary => 'Resumen';

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
  String get plateKeypadTooltip => 'Teclado en pantalla';

  @override
  String get plateKeypadBackspace => 'Borrar';

  @override
  String get plateKeypadClear => 'Limpiar';

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
  String get fieldAmount => 'Valor';

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
  String checkInRepeat(String plate) {
    return 'Repetir entrada $plate';
  }

  @override
  String checkInAlreadyInside(String plate) {
    return 'Este vehículo ya figura dentro ($plate). Verifica antes de registrarlo de nuevo.';
  }

  @override
  String get checkInLeftKeys => 'Deja las llaves';

  @override
  String get checkInLeftKeysHint => 'Se guardan en recepción';

  @override
  String get checkInLeftKeysShort => 'Llaves';

  @override
  String get checkInSubmit => 'Registrar entrada';

  @override
  String get checkInSpotTitle => 'Espacio';

  @override
  String get checkInSpotAuto => 'Automático (primer libre)';

  @override
  String get checkInSpotNone => 'Sin espacios libres para este grupo';

  @override
  String checkInSuccessSpot(String plate, String spot) {
    return 'Entrada registrada · $plate en $spot';
  }

  @override
  String get videoEvidenceTitle => 'Video de evidencia (opcional)';

  @override
  String get videoEvidenceHint =>
      'Graba un recorrido corto del vehículo (máx. 60 s) por si hay reclamos.';

  @override
  String get videoPick => 'Elegir video';

  @override
  String get videoRecord => 'Grabar video';

  @override
  String get videoRecorded => 'Video listo';

  @override
  String get videoRecordedHint =>
      'Se adjuntará al ingreso y respeta la retención de evidencia.';

  @override
  String get videoRemove => 'Quitar video';

  @override
  String get videoPickFailed => 'No se pudo grabar el video';

  @override
  String get errorVideoTooLarge => 'El video debe pesar menos de 50 MB';

  @override
  String sessionVideos(int count) {
    return '$count video(s)';
  }

  @override
  String checkInSuccess(String plate) {
    return 'Entrada registrada: $plate';
  }

  @override
  String checkInQueued(String plate) {
    return 'Entrada guardada sin conexión: $plate';
  }

  @override
  String get markExit => 'Marcar salida';

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
  String get monthlyPassesSearch => 'Buscar placa o propietario';

  @override
  String get monthlyPassesSearchHint => 'Placa, nombre o teléfono';

  @override
  String get checkOutClearSearch => 'Limpiar búsqueda';

  @override
  String get scanExitTooltip => 'Escanear QR y registrar salida';

  @override
  String get scanQrTitle => 'Escanear recibo';

  @override
  String get scanQrHint => 'Apunta la cámara al código QR del recibo';

  @override
  String get scanQrTorch => 'Linterna';

  @override
  String get scanQrCameraError =>
      'No se pudo abrir la cámara. Revisa el permiso.';

  @override
  String get checkOutScanQr => 'Escanear el QR del recibo';

  @override
  String get checkOutQrUnreadable => 'No se pudo leer el código QR';

  @override
  String checkOutQrNoSession(String plate) {
    return 'No hay una sesión abierta para $plate';
  }

  @override
  String checkOutNoMatch(String query) {
    return 'Ninguna placa coincide con «$query»';
  }

  @override
  String get checkOutLongStay => 'Más de 24 h';

  @override
  String checkOutEstimate(String amount) {
    return 'Total estimado: $amount';
  }

  @override
  String get checkOutPassCovered => 'Mensualidad activa: sin cobro';

  @override
  String get checkOutReprintTicket => 'Reimprimir recibo de entrada';

  @override
  String get checkOutCharge => 'Cobrar';

  @override
  String checkOutChargeTooltip(String plate) {
    return 'Cobrar salida de $plate';
  }

  @override
  String checkOutConfirm(String plate) {
    return '¿Cobrar la salida del vehículo $plate?';
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
  String get receiptCashReceived => 'Recibido';

  @override
  String get receiptChange => 'Cambio';

  @override
  String get receiptPayment => 'Pago';

  @override
  String get receiptDiscount => 'Descuento';

  @override
  String get checkOutSettlement => 'Liquidación';

  @override
  String fareTime(String duration) {
    return 'Tiempo: $duration';
  }

  @override
  String fareDays(int days) {
    return '$days días';
  }

  @override
  String fareDayHours(int hours, String rate) {
    return '$hours h × $rate (día)';
  }

  @override
  String fareNightHours(int hours, String rate) {
    return '$hours h × $rate (noche)';
  }

  @override
  String fareDailyCap(String amount) {
    return 'Tope diario aplicado ($amount)';
  }

  @override
  String get fareTotal => 'Total a cobrar';

  @override
  String get slotBoardError => 'No se pudo cargar el mapa de espacios';

  @override
  String get slotBoardRetry => 'Reintentar';

  @override
  String get paymentMethodTitle => 'Método de pago';

  @override
  String get paymentCardDebit => 'Débito';

  @override
  String get paymentCardCredit => 'Crédito';

  @override
  String get checkoutCashReceived => '¿Con cuánto paga?';

  @override
  String get checkoutCashChange => 'Cambio';

  @override
  String get checkoutCashShort => 'Falta';

  @override
  String get checkoutCashShortError => 'El efectivo recibido no cubre el total';

  @override
  String get checkoutCardType => 'Tipo de tarjeta';

  @override
  String get paymentCash => 'Efectivo';

  @override
  String get paymentCard => 'Tarjeta';

  @override
  String get paymentTransfer => 'Transferencia';

  @override
  String get paymentMonthlyPass => 'Mensualidad';

  @override
  String get paymentExempt => 'Exento';

  @override
  String get lostTicket => 'Ticket perdido';

  @override
  String get lostTicketHint => 'Se cobra la tarifa completa del día.';

  @override
  String get lostTicketReason => 'Motivo (ticket perdido)';

  @override
  String get lostTicketReasonRequired => 'Indica el motivo del ticket perdido';

  @override
  String get discountAmount => 'Descuento';

  @override
  String get discountReason => 'Motivo del descuento';

  @override
  String get discountReasonRequired => 'Indica el motivo del descuento';

  @override
  String get paymentUnknown => 'Otro';

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
  String get receiptView => 'Ver recibo';

  @override
  String get receiptNewCharge => 'Nuevo cobro';

  @override
  String get receiptEvidenceHint =>
      'Evidencias del vehículo: escanea (clave: placa)';

  @override
  String get receiptQrHint =>
      'Presenta este código al salir para registrar la salida';

  @override
  String get receiptClose => 'Cerrar';

  @override
  String get printReceipt => 'Imprimir';

  @override
  String get printSystem => 'Impresora del sistema (PDF)';

  @override
  String get printBluetooth => 'Impresoras Bluetooth';

  @override
  String get printScan => 'Buscar impresoras';

  @override
  String get printScanning => 'Buscando impresoras...';

  @override
  String get printNoPrinters => 'No se encontraron impresoras Bluetooth';

  @override
  String get printSuccess => 'Recibo enviado a la impresora';

  @override
  String get printError => 'No se pudo imprimir';

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
  String categorySpotsLeft(int count) {
    return 'quedan $count';
  }

  @override
  String get categoryNoSpots => 'sin cupo';

  @override
  String get categoriesEmpty => 'Aún no hay categorías';

  @override
  String get categoryNew => 'Nueva categoría';

  @override
  String get categoryRename => 'Renombrar categoría';

  @override
  String categoryCapacity(int count) {
    return 'Capacidad: $count';
  }

  @override
  String get categoryCapacityUnlimited => 'Sin límite de capacidad';

  @override
  String categoryCapacityTitle(String name) {
    return 'Capacidad de $name';
  }

  @override
  String get categoryCapacityLabel => 'Capacidad';

  @override
  String get errorCategoryFull => 'La categoría está llena';

  @override
  String get homeFull => 'Lleno';

  @override
  String homeFullCategories(String names) {
    return 'Categorías llenas: $names';
  }

  @override
  String reportsOccupancyOf(int open, int capacity) {
    return 'Vehículos dentro: $open / $capacity';
  }

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
  String get vehiclesSearch => 'Buscar placa o propietario';

  @override
  String get vehiclesSearchHint => 'Placa, nombre o teléfono';

  @override
  String vehiclesNoMatch(String query) {
    return 'No hay vehículos para «$query»';
  }

  @override
  String vehicleCreated(String plate) {
    return 'Vehículo creado: $plate';
  }

  @override
  String get vehicleCheckInAction => 'Registrar entrada';

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
  String get usersFilterAll => 'Todos';

  @override
  String get usersFilterEmpty => 'No hay usuarios con este filtro';

  @override
  String get usersEmpty => 'Aún no hay usuarios';

  @override
  String get userNew => 'Nuevo usuario';

  @override
  String get userAddTooltip => 'Agregar usuario';

  @override
  String get userActions => 'Acciones';

  @override
  String get userResetPin => 'Restablecer PIN';

  @override
  String userResetPinTitle(String name) {
    return 'Nuevo PIN para $name';
  }

  @override
  String get userNewPin => 'Nuevo PIN (6 dígitos)';

  @override
  String get userDelete => 'Eliminar usuario';

  @override
  String get userDeleteTitle => '¿Eliminar usuario?';

  @override
  String userDeleteBody(String name) {
    return 'Se eliminará la cuenta de $name. Esta acción no se puede deshacer.';
  }

  @override
  String userActiveLabel(String name) {
    return 'Usuario activo: $name';
  }

  @override
  String userDeactivated(String name) {
    return 'Usuario $name desactivado';
  }

  @override
  String get pinInvalid => 'El PIN debe tener 6 dígitos';

  @override
  String get monthlyPassPendingTitle => 'Pagos pendientes';

  @override
  String monthlyPassDue(String date) {
    return 'Vence: $date';
  }

  @override
  String get monthlyPassWhatsapp => 'Avisar por WhatsApp';

  @override
  String monthlyPassWhatsappMessage(String plate, String date) {
    return 'Hola, te recordamos que la mensualidad del vehículo $plate vence el $date.';
  }

  @override
  String get monthlyPassStatusActive => 'Vigente';

  @override
  String get monthlyPassStatusUpcoming => 'Próxima';

  @override
  String get monthlyPassStatusExpired => 'Vencida';

  @override
  String get monthlyPassCharge => 'Cobrar';

  @override
  String get monthlyPassRenewalMethod => 'Método para renovación';

  @override
  String get monthlyPassAutoRenew => 'Renovación automática';

  @override
  String get monthlyPassAutoRenewHint =>
      'Se renueva por el mismo periodo y valor al vencer';

  @override
  String get monthlyPassesTitle => 'Mensualidades';

  @override
  String monthlyPassesNoMatch(String query) {
    return 'Ninguna mensualidad coincide con «$query»';
  }

  @override
  String get monthlyPassCreated => 'Mensualidad creada';

  @override
  String get monthlyPassDeleted => 'Mensualidad eliminada';

  @override
  String get monthlyPassPaymentDone => 'Pago de mensualidad registrado';

  @override
  String get monthlyPassRenew => 'Renovar 30 días';

  @override
  String get monthlyPassRenewTitle => '¿Renovar la mensualidad?';

  @override
  String monthlyPassRenewBody(String date) {
    return 'Se extenderá hasta $date, conservando el valor actual.';
  }

  @override
  String get monthlyPassRenewed => 'Mensualidad renovada 30 días';

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
  String get reportsAllLots => 'Todas las sedes';

  @override
  String get reportsAllLotsHint => 'Suma las ventas de todas las sedes';

  @override
  String reportsLotTickets(int count) {
    return '$count salidas';
  }

  @override
  String reportsLotAverage(String amount) {
    return 'promedio $amount';
  }

  @override
  String reportsLotShare(int percent) {
    return '$percent% del total';
  }

  @override
  String get reportsByLot => 'Ingresos por sede';

  @override
  String get reportsToday => 'Hoy';

  @override
  String get reportsLast7 => '7 días';

  @override
  String get reportsLast30 => '30 días';

  @override
  String get reportsThisMonth => 'Este mes';

  @override
  String get reportsLastMonth => 'Mes anterior';

  @override
  String get reportsTitle => 'Reportes';

  @override
  String get lotSwitchTitle => 'Cambiar de sede';

  @override
  String lotSwitchTooltip(String site) {
    return 'Sede actual: $site. Toca para cambiar.';
  }

  @override
  String get reportsRangeTooltip => 'Cambiar rango de fechas';

  @override
  String reportsVsPrevious(String percent) {
    return '$percent % vs. periodo anterior';
  }

  @override
  String reportsPreviousTotal(String amount) {
    return 'Antes: $amount';
  }

  @override
  String get reportsVariationLabel => 'Variación vs. periodo anterior';

  @override
  String get reportsPreviousLabel => 'Periodo anterior';

  @override
  String get reportsExportCsv => 'Copiar CSV';

  @override
  String get reportsCsvCopied => 'CSV copiado al portapapeles';

  @override
  String get reportsTotalRevenue => 'Ingresos totales';

  @override
  String get reportsRevenueByDay => 'Ingresos por día';

  @override
  String get reportsReservationsTitle => 'Reservas de cupo';

  @override
  String get reportsReservationsSubtitle =>
      'Cuántas se crearon en el periodo y cómo terminaron';

  @override
  String get reportsReservationsPublic => 'Reservas web';

  @override
  String reportsReservationsConversion(int value) {
    return '$value% llegaron a entrar';
  }

  @override
  String get reportsReservationsClosed => 'Canceladas o vencidas';

  @override
  String reportsReservationsClosedHint(int cancelled, int expired) {
    String _temp0 = intl.Intl.pluralLogic(
      cancelled,
      locale: localeName,
      other: '$cancelled canceladas',
      one: '1 cancelada',
    );
    String _temp1 = intl.Intl.pluralLogic(
      expired,
      locale: localeName,
      other: '$expired vencidas',
      one: '1 vencida',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String reportsReservationsTotal(int total, int app, int used) {
    return '$total reservas en total · $app desde recepción · $used terminaron en entrada';
  }

  @override
  String get reportsHourlyTitle => 'Tráfico por hora';

  @override
  String get reportsHourlySubtitle =>
      'Entradas y salidas en el horario del parqueadero';

  @override
  String reportsHourlyPeak(String time, int count) {
    return 'Hora pico: $time · $count entradas';
  }

  @override
  String reportsHourlyCell(String time, int entries, int exits) {
    return '$time · $entries entradas · $exits salidas';
  }

  @override
  String get reportsHourlyEmpty => 'Sin entradas en el periodo';

  @override
  String reportsHourlyPair(int entries, int exits) {
    return '$entries entradas · $exits salidas';
  }

  @override
  String get reportsHourlyLegend =>
      'La barra muestra las entradas; el detalle incluye las salidas.';

  @override
  String get reportsPassRevenue => 'Mensualidades cobradas';

  @override
  String get reportsRevenueByPayment => 'Ingresos por método de pago';

  @override
  String get reportsTotalDiscounts => 'Descuentos aplicados';

  @override
  String get reportsDiscountLog => 'Detalle de descuentos';

  @override
  String reportsDiscountBy(String admin) {
    return 'por $admin';
  }

  @override
  String reportsDiscountedSessions(int count) {
    return '$count salidas con descuento';
  }

  @override
  String get reportsRevenueByCategory => 'Ingresos por categoría';

  @override
  String get reportsWhatsapp => 'WhatsApp';

  @override
  String get reportsWhatsappSent => 'Enviados';

  @override
  String get reportsWhatsappFailed => 'Fallidos';

  @override
  String get reportsWhatsappPending => 'En cola';

  @override
  String reportsWhatsappDay(int sent, int failed) {
    return '$sent enviados · $failed fallidos';
  }

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

  @override
  String get errorTitle => 'Algo salió mal';

  @override
  String get actionClearFilters => 'Limpiar filtros';

  @override
  String get notificationsToday => 'Hoy';

  @override
  String get notificationsYesterday => 'Ayer';

  @override
  String get notificationsEarlier => 'Anteriores';

  @override
  String get notificationsEmptyTitle => 'Bandeja vacía';

  @override
  String get notificationsEmptyHint =>
      'Los avisos de entradas, salidas, turnos y mensualidades aparecerán aquí.';

  @override
  String get notificationsOpenRecords => 'Ver registros';

  @override
  String get notificationsUnreadOnly => 'No leídas';

  @override
  String get notificationsAll => 'Todas';

  @override
  String get notificationsFilterLabel => 'Filtrar notificaciones';

  @override
  String get auditActionInsert => 'Crear';

  @override
  String get auditActionUpdate => 'Editar';

  @override
  String get auditActionDelete => 'Eliminar';

  @override
  String get auditEmptyFiltered => 'Ningún cambio coincide con los filtros';

  @override
  String get usersSearchHint => 'Buscar por nombre o usuario';

  @override
  String get usersEmptyTitle => 'Sin usuarios';

  @override
  String get usersEmptyHint =>
      'Agrega el primer operador para empezar a registrar movimientos.';

  @override
  String get usersAddFirst => 'Agregar usuario';

  @override
  String get recordsSummarySessions => 'Sesiones';

  @override
  String get recordsSummaryCharged => 'Cobrado';

  @override
  String get recordsEmptyTitle => 'Sin movimientos';

  @override
  String get homeQuickActions => 'Accesos rápidos';

  @override
  String get homeSummaryHint => 'Estado del parqueadero en tiempo real';

  @override
  String get shiftSummaryTitle => 'Resumen del turno';

  @override
  String get spotsLegend => 'Convenciones';

  @override
  String get spotsLegendFree => 'Libre';

  @override
  String get spotsLegendOccupied => 'Ocupado';

  @override
  String get spotsLegendHold => 'Reserva';

  @override
  String get spotsLegendMaintenance => 'Mantenimiento';

  @override
  String get diagnosticsSummary => 'Resumen operativo';

  @override
  String get notificationsUnreadEmpty => 'No tienes notificaciones sin leer';

  @override
  String auditCount(int count) {
    return '$count cambios';
  }

  @override
  String get auditEmptyHint =>
      'Los cambios en datos maestros se registran automáticamente.';

  @override
  String get auditEmptyFilteredHint =>
      'Prueba con otro rango de fechas, tabla o actor.';

  @override
  String get auditBefore => 'Antes';

  @override
  String get auditAfter => 'Después';

  @override
  String get auditField => 'Campo';

  @override
  String get usersSearchLabel => 'Buscar usuario';

  @override
  String get loginOperatorAccess => 'Acceso de operador';

  @override
  String get loginHelper =>
      'Usa el usuario y el PIN de 6 dígitos asignados por el administrador.';

  @override
  String get loginSecure => 'Conexión protegida';

  @override
  String get loginShowPin => 'Mostrar PIN';

  @override
  String get loginHidePin => 'Ocultar PIN';

  @override
  String get loginFeatureCheckIn => 'Entradas y salidas en segundos';

  @override
  String get loginFeatureCash => 'Caja y turnos cuadrados';

  @override
  String get loginFeatureReports => 'Reportes en tiempo real';

  @override
  String get reservationsActive => 'Reservas activas';

  @override
  String get reservationsExpiring => 'Por vencer';

  @override
  String get reservationsEmptyTitle => 'Sin reservas';

  @override
  String get reservationsEmptyHint =>
      'Reserva el cupo de un cliente para asegurar su entrada.';

  @override
  String get reservationsSearchLabel => 'Buscar reserva';

  @override
  String get reservationsSearchHint => 'Placa, nombre, celular o código';

  @override
  String get reservationWeb => 'Web';

  @override
  String get reservationCall => 'Llamar al cliente';

  @override
  String get reservationWhatsApp => 'WhatsApp al cliente';

  @override
  String reservationWhatsAppMessage(String plate) {
    return 'Hola, te escribimos por tu reserva de la placa $plate.';
  }

  @override
  String get reservationsOnlyExpiring => 'Solo por vencer';

  @override
  String get reservationsOnlyPublic => 'Solo web';

  @override
  String get reservationsCopyCsv => 'Copiar CSV';

  @override
  String get reservationsCsvCopied => 'Reservas copiadas en CSV';

  @override
  String reservationsCount(int count) {
    return '$count reservas';
  }

  @override
  String get reservationsFilteredEmpty =>
      'Ninguna reserva coincide con el filtro';

  @override
  String get monthlyPassesEmptyTitle => 'Sin mensualidades';

  @override
  String get monthlyPassesEmptyHint =>
      'Crea una mensualidad para cobrar por adelantado y agilizar la salida.';

  @override
  String get monthlyPassesActive => 'Vigentes';

  @override
  String monthlyPassesCount(int count) {
    return '$count mensualidades';
  }

  @override
  String get monthlyPassesOnlyActive => 'Solo vigentes';

  @override
  String get monthlyPassesFilteredEmpty =>
      'Ninguna mensualidad coincide con el filtro';

  @override
  String get monthlyPassesList => 'Mensualidades registradas';

  @override
  String get categoriesEmptyHint =>
      'Crea las categorías del parqueadero (moto, carro, camioneta…) para asignar tarifas y cupos.';

  @override
  String get tariffsEmptyHint =>
      'Agrega tarifas por hora, día, noche o mensualidad para cada categoría.';

  @override
  String get diagnosticsPendingQueue => 'Cola pendiente';

  @override
  String get diagnosticsAlerts => 'Alertas';

  @override
  String get diagnosticsOpenNow => 'Dentro ahora';

  @override
  String vehiclesCount(int count) {
    return '$count vehículos';
  }

  @override
  String parkedCount(int count) {
    return '$count dentro';
  }

  @override
  String get checkOutEmptyTitle => 'Parqueadero vacío';

  @override
  String get checkOutEmptyHint =>
      'Registra una entrada para verla aquí y cobrarla al salir.';

  @override
  String get checkOutGoToCheckIn => 'Registrar entrada';

  @override
  String get checkInVehicleSection => 'Vehículo';

  @override
  String checkInHoldLookup(int count) {
    return 'Buscar reserva ($count)';
  }

  @override
  String get checkInHoldLookupTitle => 'Reservas activas';

  @override
  String get checkInHoldLookupEmpty =>
      'No hay reservas activas en este momento.';

  @override
  String get checkInVehicleHint => 'Placa, categoría y datos del vehículo';

  @override
  String get checkInEvidenceSection => 'Evidencia';

  @override
  String get checkInEvidenceHint => 'Fotos o video del estado del vehículo';

  @override
  String get notifTypeCheckIn => 'Entrada';

  @override
  String get notifTypeCheckOut => 'Salida';

  @override
  String get notifTypePassExpiring => 'Mensualidad por vencer';

  @override
  String get notifTypePassRenewed => 'Mensualidad renovada';

  @override
  String get notifTypeOverstay => 'Estadía larga';

  @override
  String get notifTypeReservation => 'Reserva web';

  @override
  String get notifTypeShiftClosed => 'Cierre de turno';

  @override
  String get notifTypeGeneric => 'Aviso';

  @override
  String get aboutDeveloper => 'Acerca del desarrollador';

  @override
  String get aboutRole => 'Ingeniero de Sistemas';

  @override
  String get aboutIntro =>
      'Ingeniero de Sistemas con más de 7 años de experiencia en desarrollo web y móvil. Diseño y construyo la app, el backend, la base de datos y la infraestructura, cuidando la experiencia de uso y los detalles.';

  @override
  String get aboutFindMe => 'Encuéntrame';

  @override
  String get aboutWebsite => 'Sitio web';

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get aboutLinkedIn => 'LinkedIn';

  @override
  String get aboutInstagram => 'Instagram';

  @override
  String get aboutAppTitle => 'Sobre la app';

  @override
  String get aboutAppBody =>
      'Sistema de gestión de parqueadero: entradas y salidas, cobro por tiempo, turnos de caja, mensualidades, reservas y reportes en tiempo real.';

  @override
  String aboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get aboutMadeBy => 'Hecho por DevPaul';

  @override
  String get aboutRights => '© 2026 DevPaul. Todos los derechos reservados.';

  @override
  String get aboutLogoLabel => 'Logotipo de DevPaul';

  @override
  String get aboutOpenError => 'No se pudo abrir el enlace';

  @override
  String get shiftOpeningHint =>
      'Cuenta el efectivo con el que inicia la caja.';

  @override
  String get shiftClosedHint => 'Resumen del último turno cerrado.';

  @override
  String get diagnosticsHealthyTitle => 'Todo en orden';

  @override
  String get diagnosticsHealthyHint =>
      'No hay alertas ni colas pendientes en este momento.';

  @override
  String diagnosticsAttention(int count) {
    return '$count punto(s) requieren atención';
  }

  @override
  String get diagnosticsAttentionHint => 'Revisa las secciones marcadas abajo.';

  @override
  String get routeErrorTitle => 'Página no encontrada';

  @override
  String get routeErrorBody =>
      'La ruta no existe o ya no está disponible. Vuelve al inicio para continuar.';

  @override
  String get routeErrorHome => 'Volver al inicio';

  @override
  String get loginSessionExpired =>
      'Tu sesión expiró. Ingresa de nuevo para continuar.';

  @override
  String checkoutChargeAmount(String amount) {
    return 'Cobrar $amount';
  }

  @override
  String get checkoutCashExact => 'Exacto';

  @override
  String cashCountQuantity(String denomination) {
    return 'Cantidad de $denomination';
  }

  @override
  String get plateScanAction => 'Escanear placa';

  @override
  String get vehicleEditTitle => 'Editar vehículo';

  @override
  String vehicleEditTooltip(String plate) {
    return 'Editar vehículo $plate';
  }

  @override
  String vehicleUpdated(String plate) {
    return 'Vehículo $plate actualizado';
  }

  @override
  String get vehicleEditHint =>
      'La placa no cambia; puedes ajustar categoría, marca y color.';

  @override
  String get autoLockTitle => 'Bloqueo automático';

  @override
  String get autoLockHint =>
      'Bloquea la app tras este tiempo sin uso y pide el PIN para volver.';

  @override
  String get autoLockOff => 'Desactivado';

  @override
  String autoLockMinutes(int count) {
    return '$count min';
  }

  @override
  String get lockTitle => 'Sesión bloqueada';

  @override
  String get lockHint => 'Ingresa tu PIN para continuar.';

  @override
  String get lockUnlock => 'Desbloquear';

  @override
  String get lockWrongPin => 'PIN incorrecto. Inténtalo de nuevo.';

  @override
  String lockAttemptsLeft(int count) {
    return 'Intentos restantes: $count';
  }

  @override
  String get lockLogout => 'Cerrar sesión';

  @override
  String get settingsMinVersion => 'Versión mínima de la app';

  @override
  String get settingsMinVersionHint =>
      'Opcional, ej. 1.4.2. Los APK más antiguos verán un aviso de actualización.';

  @override
  String get settingsMinVersionInvalid => 'Usa el formato 1.4.2';

  @override
  String updateRequired(String current, String minimum) {
    return 'Actualiza la app: este equipo tiene $current y la sede requiere $minimum o superior.';
  }

  @override
  String get helpTitle => 'Ayuda';

  @override
  String get helpIntro => 'Guías rápidas para la operación diaria.';

  @override
  String get helpSearchLabel => 'Buscar en la ayuda';

  @override
  String helpResults(int count) {
    return '$count artículos';
  }

  @override
  String get helpNoResults => 'No hay artículos que coincidan con la búsqueda.';

  @override
  String get helpSectionStart => 'Primeros pasos';

  @override
  String get helpSectionCash => 'Cobros y caja';

  @override
  String get helpSectionVehicles => 'Vehículos';

  @override
  String get helpSectionOffline => 'Sin conexión y seguridad';

  @override
  String get helpOpenShiftTitle => 'Abrir turno';

  @override
  String get helpOpenShiftBody =>
      'Entra en Caja y pulsa Abrir turno. Cuenta el efectivo inicial; ese valor será la base del arqueo.';

  @override
  String get helpChargeTitle => 'Cobrar una salida';

  @override
  String get helpChargeBody =>
      'En Salida busca la placa o escanea el QR, revisa el desglose y pulsa Cobrar. Elige el método de pago y confirma.';

  @override
  String get helpReprintTitle => 'Reimprimir un ticket';

  @override
  String get helpReprintBody =>
      'Abre el historial del vehículo o la sesión abierta y usa Reimprimir ticket para generar el recibo de nuevo.';

  @override
  String get helpCloseShiftTitle => 'Cerrar el turno (arqueo)';

  @override
  String get helpCloseShiftBody =>
      'En Caja pulsa Cerrar turno, cuenta el efectivo (puedes usar el contador por denominaciones) y confirma la diferencia si existe.';

  @override
  String get helpMovementTitle => 'Ingresos y retiros de efectivo';

  @override
  String get helpMovementBody =>
      'Desde Caja registra un retiro o ingreso con su motivo. Queda en el historial del turno y en los reportes.';

  @override
  String get helpCheckInTitle => 'Registrar una entrada';

  @override
  String get helpCheckInBody =>
      'En Entrada escribe la placa, elige categoría y espacio si aplica, y adjunta fotos o video del estado del vehículo.';

  @override
  String get helpReservationTitle => 'Reservas de cupo';

  @override
  String get helpReservationBody =>
      'En Reservas crea una con placa, categoría y hora límite. Desde la reserva puedes registrar la entrada o cancelarla.';

  @override
  String get helpPassTitle => 'Mensualidades';

  @override
  String get helpPassBody =>
      'En Mensualidades agrega el vehículo, el periodo y el valor. Puedes cobrar renovaciones y avisar por WhatsApp.';

  @override
  String get helpOfflineTitle => 'Trabajar sin conexión';

  @override
  String get helpOfflineBody =>
      'Entradas, salidas y cambios de vehículos se guardan y sincronizan al volver la red. Las acciones de caja y mensualidades requieren conexión.';

  @override
  String get helpAutoLockTitle => 'Bloqueo automático';

  @override
  String get helpAutoLockBody =>
      'Si la app queda inactiva pide el PIN. Cambia el tiempo en Menú → Bloqueo automático (o en el sidebar).';

  @override
  String get helpUpdateTitle => 'Aviso de actualización';

  @override
  String get helpUpdateBody =>
      'Si aparece un aviso de versión, instala el APK más reciente que te entregue el administrador; la app seguirá funcionando para lo básico hasta entonces.';

  @override
  String get diagnosticsClientNetwork => 'Red del cliente';

  @override
  String get diagnosticsTimeouts => 'Tiempos de espera agotados';

  @override
  String get diagnosticsRetries => 'Reintentos automáticos';

  @override
  String get diagnosticsFailedRequests => 'Solicitudes fallidas';

  @override
  String get evidenceDuration => 'Tiempo en el parqueadero';

  @override
  String get evidenceEstimatedAmount => 'Valor estimado';

  @override
  String get evidenceChargedAmount => 'Total cobrado';

  @override
  String get evidencePassCovered => 'Cubierto por mensualidad';

  @override
  String get evidencePriceMayChange => 'Puede cambiar hasta la salida';

  @override
  String get evidenceCall => 'Llamar al parqueadero';

  @override
  String get evidenceWhatsApp => 'Escribir por WhatsApp';

  @override
  String evidenceWhatsAppMessage(String plate) {
    return 'Hola, escribo por el vehículo $plate.';
  }

  @override
  String get preferencesTitle => 'Ajustes';

  @override
  String get preferencesHint => 'Idioma, apariencia y bloqueo automático.';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String get aboutDevelopers => 'Desarrolladores';

  @override
  String get aboutJimmyRole => 'Desarrollador';

  @override
  String monthlyPassUseTariff(String amount) {
    return 'Usar tarifa mensual ($amount)';
  }

  @override
  String get emergencyTitle => 'Emergencia';

  @override
  String get emergencyBody =>
      'Reporta la emergencia al cuadrante de policía más cercano.';

  @override
  String get emergencyDrawerHint => 'Llamar al cuadrante de policía';

  @override
  String get emergencyNumberLabel => 'Cuadrante de policía más cercano';

  @override
  String get emergencyDefaultLabel => 'Línea de emergencia';

  @override
  String get emergencyDefaultHint =>
      'Aún no hay un número del cuadrante configurado.';

  @override
  String get emergencyCallNow => 'Llamar ahora';

  @override
  String emergencyCallDefault(String phone) {
    return 'Llamar al $phone';
  }

  @override
  String get emergencyGoToSettings => 'Configurar en Ajustes';

  @override
  String get emergencyAskAdmin =>
      'Pide al administrador que configure el número del cuadrante en Ajustes.';

  @override
  String get emergencyCallFailed => 'No se pudo abrir el marcador.';

  @override
  String emergencyLocation(String location) {
    return 'Ubicación: $location';
  }

  @override
  String get reportsPeriodTitle => 'Comparación por periodo';

  @override
  String get reportsPeriodSubtitle =>
      'Cada mes frente al mes anterior y al mismo mes del año pasado';

  @override
  String get reportsPeriodActiveLotOnly => 'Solo la sede activa';

  @override
  String reportsPeriodMonths(int count) {
    return '$count meses';
  }

  @override
  String get reportsPeriodMetricLabel => 'Indicador';

  @override
  String get reportsPeriodMetricRevenue => 'Ingresos';

  @override
  String get reportsPeriodMetricEntries => 'Entradas';

  @override
  String get reportsPeriodMetricExits => 'Salidas';

  @override
  String get reportsPeriodMetricAvgTicket => 'Ticket promedio';

  @override
  String get reportsPeriodMetricAvgStay => 'Estadía promedio';

  @override
  String get reportsPeriodMetricPassRevenue => 'Ingresos por mensualidades';

  @override
  String get reportsPeriodMetricReservations => 'Reservas';

  @override
  String reportsPeriodReservationsUsed(int count) {
    return '$count usadas';
  }

  @override
  String reportsPeriodPartial(int days, int total) {
    return 'Mes en curso · $days de $total días';
  }

  @override
  String get reportsPeriodPartialChip => 'Parcial';

  @override
  String reportsPeriodPartialHint(int days) {
    return 'Se compara con los primeros $days días de cada mes';
  }

  @override
  String reportsPeriodVsMonth(String delta) {
    return '$delta vs mes anterior';
  }

  @override
  String reportsPeriodVsYear(String delta) {
    return '$delta vs año anterior';
  }

  @override
  String get reportsPeriodFlatMonth => 'Igual que el mes anterior';

  @override
  String get reportsPeriodFlatYear => 'Igual que el año anterior';

  @override
  String get reportsPeriodNoBase => 'Sin base de comparación';

  @override
  String get reportsPeriodLegendCurrent => 'Mes';

  @override
  String get reportsPeriodLegendLastYear => 'Mismo mes del año anterior';

  @override
  String get reportsPeriodEmptyTitle => 'Aún no hay historial';

  @override
  String get reportsPeriodEmpty =>
      'Cuando el parqueadero tenga movimiento verás aquí la comparación mensual.';

  @override
  String get reportsPeriodUnavailable => 'No se pudo cargar la comparación.';

  @override
  String reportsPeriodBarSemantics(
    String month,
    String value,
    String previous,
  ) {
    return '$month: $value; año anterior: $previous';
  }

  @override
  String reportsPeriodPdfPartial(String month, String days) {
    return '$month ($days)';
  }

  @override
  String get reportsPeriodPdfNoBase => 'n/d';

  @override
  String get navSatisfaction => 'Satisfacción';

  @override
  String get feedbackTitle => 'Tu opinión';

  @override
  String get feedbackGateTitle => 'Ingresa la placa para calificar tu visita';

  @override
  String get feedbackGateHint =>
      'La placa impresa en el recibo es la clave de acceso.';

  @override
  String get feedbackUnlock => 'Continuar';

  @override
  String feedbackHeroTitle(String lot) {
    return '¿Cómo fue tu visita a $lot?';
  }

  @override
  String get feedbackHeroSubtitle =>
      'Tu opinión ayuda a mejorar el servicio. Toma menos de un minuto.';

  @override
  String get feedbackRateLabel => 'Tu calificación';

  @override
  String feedbackStarLabel(int rating) {
    return 'Calificar con $rating estrellas';
  }

  @override
  String get feedbackRating1 => 'Muy mala';

  @override
  String get feedbackRating2 => 'Mala';

  @override
  String get feedbackRating3 => 'Regular';

  @override
  String get feedbackRating4 => 'Buena';

  @override
  String get feedbackRating5 => 'Excelente';

  @override
  String get feedbackCommentLabel => 'Comentario (opcional)';

  @override
  String get feedbackCommentHint => 'Cuéntanos qué podemos mejorar';

  @override
  String get feedbackSubmit => 'Enviar calificación';

  @override
  String get feedbackThanksTitle => '¡Gracias por tu opinión!';

  @override
  String get feedbackThanksBody =>
      'Tu calificación ayuda a que el servicio mejore cada día.';

  @override
  String get feedbackCloseHint => 'Puedes cerrar esta página.';

  @override
  String get feedbackAlreadyTitle => 'Ya calificaste esta visita';

  @override
  String get feedbackAlreadyBody =>
      'Gracias. Solo se acepta una calificación por visita.';

  @override
  String get feedbackInvalidTitle => 'No encontramos esta visita';

  @override
  String get feedbackInvalidBody =>
      'Revisa el enlace o el código del recibo. Si el problema continúa, pide ayuda en la recepción.';

  @override
  String get feedbackPendingTitle => 'Tu visita sigue en curso';

  @override
  String get feedbackPendingBody =>
      'Podrás calificarla cuando registres la salida.';

  @override
  String get feedbackReportTitle => 'Satisfacción del cliente';

  @override
  String get feedbackReportSubtitle =>
      'Opiniones de tus clientes en el periodo';

  @override
  String feedbackPeriodSummary(int total, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total respuestas',
      one: '1 respuesta',
    );
    return '$_temp0 · últimos $days días';
  }

  @override
  String get feedbackAverage => 'Calificación promedio';

  @override
  String feedbackAverageValue(int whole, int decimal) {
    return '$whole,$decimal';
  }

  @override
  String feedbackAverageCaption(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Basada en $total respuestas',
      one: 'Basada en 1 respuesta',
      zero: 'Sin respuestas',
    );
    return '$_temp0';
  }

  @override
  String get feedbackResponses => 'Respuestas';

  @override
  String feedbackResponseRate(int percent) {
    return '$percent% de las salidas';
  }

  @override
  String get feedbackLowRatings => 'Calificaciones bajas';

  @override
  String get feedbackLowCaption => '1 a 3 estrellas';

  @override
  String get feedbackLowEmpty => 'Ninguna';

  @override
  String get feedbackDistribution => 'Distribución';

  @override
  String feedbackDistributionRow(int rating) {
    return '$rating estrellas';
  }

  @override
  String feedbackDistributionSemantics(int rating, int count) {
    return '$rating estrellas: $count respuestas';
  }

  @override
  String get feedbackRecent => 'Últimos comentarios';

  @override
  String get feedbackRecentEmpty => 'Sin comentarios en el periodo';

  @override
  String get feedbackNoComment => 'Sin comentario';

  @override
  String get feedbackEmptyTitle => 'Aún no hay calificaciones';

  @override
  String get feedbackEmptyBody =>
      'Cuando tus clientes califiquen una visita desde el recibo, verás aquí el promedio y sus comentarios.';

  @override
  String get feedbackRefresh => 'Actualizar';

  @override
  String get errorFeedbackAlready =>
      'Ya calificaste esta visita. Solo se acepta una calificación por visita.';

  @override
  String get receiptFeedbackHint => 'Califica tu visita: escanea el código';

  @override
  String vehicleWhatsappFeedback(String url) {
    return 'Califica tu visita: $url';
  }

  @override
  String feedbackPeriodDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get paymentOnline => 'En línea';

  @override
  String get onlinePayTitle => 'Paga desde tu celular';

  @override
  String get onlinePayDue => 'Valor a pagar';

  @override
  String get onlinePayAction => 'Pagar en línea';

  @override
  String onlinePayHint(int minutes) {
    return 'Tarjeta, PSE o Nequi. Después de pagar tienes $minutes minutos para salir.';
  }

  @override
  String get onlinePayChecking => 'Confirmando tu pago…';

  @override
  String get onlinePayApproved =>
      'Pago recibido. Muestra esta pantalla al salir.';

  @override
  String get onlinePayDeclined =>
      'El pago no fue aprobado. Puedes intentarlo de nuevo.';

  @override
  String get onlinePayPending =>
      'Aún no confirmamos tu pago. Si ya pagaste, espera un momento.';

  @override
  String onlinePayGraceUntil(String time) {
    return 'Sal antes de las $time';
  }

  @override
  String get onlinePayLate =>
      'Si pasas de esa hora, pagas la diferencia en caja.';

  @override
  String get onlinePayNothingDue => 'No tienes nada por pagar.';

  @override
  String get checkOutPaidOnline => 'Pagado en línea';

  @override
  String get checkOutBalanceDue => 'Saldo en caja';

  @override
  String get checkOutNoCashDue => 'Sin cobro en caja: ya pagó en línea';

  @override
  String get checkOutGraceExpired =>
      'Venció la tolerancia de salida; se cobra la diferencia';

  @override
  String get checkOutOnlineUnknownOffline =>
      'Sin conexión no se puede confirmar si este vehículo pagó en línea';

  @override
  String get shiftOnlineSales => 'Pagos en línea';

  @override
  String get receiptPaidOnline => 'Pagado en línea';

  @override
  String get settingsOnlinePayments => 'Pagos en línea';

  @override
  String get settingsOnlinePaymentsHint =>
      'Permite que el cliente pague desde el QR del recibo. Requiere credenciales Wompi en el servidor.';

  @override
  String get settingsOnlineGraceMinutes =>
      'Minutos para salir después de pagar';

  @override
  String get settingsOnlineMinAmount => 'Valor mínimo en línea';

  @override
  String get settingsOnlineCopOnly => 'Solo disponible para sedes en COP';

  @override
  String get notifTypeOnlinePayment => 'Pago en línea';

  @override
  String get notifTypeOnlinePaymentReview => 'Pago en línea por revisar';

  @override
  String get reportOnlinePayments => 'Pagos en línea';

  @override
  String get reportOnlineReference => 'Referencia';

  @override
  String get errorOnlinePaymentsDisabled =>
      'Los pagos en línea no están activos en esta sede';

  @override
  String get errorNothingToPay => 'No hay nada por pagar';

  @override
  String get errorAmountTooLow =>
      'El valor es menor al mínimo para pagar en línea; paga en caja';

  @override
  String get errorPaymentsNotConfigured =>
      'El pago en línea no está disponible por ahora; paga en caja';

  @override
  String get errorPaymentThrottled =>
      'Demasiados intentos de pago. Intenta de nuevo en una hora o paga en caja';

  @override
  String get errorPaymentEventFailed =>
      'No se pudo registrar el pago; intenta más tarde';

  @override
  String get errorInvalidLink => 'El enlace no es válido o está incompleto';

  @override
  String get checkOutConfirmExit => 'Confirmar salida';

  @override
  String get passRenewalTitle => 'Renueva tu mensualidad';

  @override
  String passRenewalPlate(String plate) {
    return 'Vehículo $plate';
  }

  @override
  String passRenewalPeriod(String from, String to) {
    return 'Nuevo periodo: $from a $to';
  }

  @override
  String get passRenewalAmount => 'Valor';

  @override
  String get passRenewalPay => 'Pagar y renovar';

  @override
  String get passRenewalChecking => 'Confirmando tu pago…';

  @override
  String passRenewalPaid(String date) {
    return 'Mensualidad renovada hasta el $date.';
  }

  @override
  String get passRenewalUnavailable =>
      'Este enlace ya no está disponible. Comunícate con el parqueadero.';

  @override
  String get passRenewalPayAtDesk =>
      'El pago en línea no está disponible por ahora; renueva en caja.';

  @override
  String get passRenewalLinkSent => 'Enlace enviado';

  @override
  String get passRenewalRenewedOnline => 'Renovada en línea';

  @override
  String get passRenewalSendLink => 'Enviar enlace de renovación';

  @override
  String get passRenewalLinkQueued => 'Enlace en cola de WhatsApp';

  @override
  String get settingsPassRenewal => 'Renovación de mensualidades';

  @override
  String get settingsPassRenewalHint =>
      'Envía recordatorios por WhatsApp antes de que venza la mensualidad.';

  @override
  String get settingsPassRenewalLinks => 'Incluir enlace de pago';

  @override
  String get settingsPassRenewalLinksHint =>
      'Requiere pagos en línea activos y credenciales Wompi.';

  @override
  String get settingsPassRenewalCadence => 'Días de aviso (ej. 7,3,1)';

  @override
  String get settingsPassRenewalCadenceInvalid =>
      'Usa hasta 5 números entre 0 y 30 separados por comas';

  @override
  String get notifTypePassRenewalPaid => 'Mensualidad renovada en línea';

  @override
  String get errorPassRenewalNotFound => 'Enlace de renovación no válido';

  @override
  String get errorPassRenewalPaid => 'Esta mensualidad ya fue renovada';

  @override
  String get errorPassRenewalExpired => 'El enlace de renovación venció';

  @override
  String get errorPassRenewalDisabled =>
      'La renovación en línea no está activa en esta sede';

  @override
  String get errorMissingOwnerPhone =>
      'El vehículo no tiene teléfono del propietario';

  @override
  String get errorPassAlreadyRenewed =>
      'La mensualidad ya tiene una renovación';

  @override
  String get errorPassNotFound => 'Mensualidad no encontrada';

  @override
  String get navMerchants => 'Convenios';

  @override
  String get merchantsTitle => 'Convenios con comercios';

  @override
  String get merchantsEmpty =>
      'Aún no hay convenios. Crea uno para dar descuento a los clientes de un comercio vecino.';

  @override
  String get merchantsAdd => 'Nuevo convenio';

  @override
  String get merchantFormName => 'Nombre del comercio';

  @override
  String get merchantFormKind => 'Tipo de beneficio';

  @override
  String get merchantKindFreeMinutes => 'Minutos gratis';

  @override
  String get merchantKindPercentage => 'Porcentaje';

  @override
  String get merchantKindFixedAmount => 'Monto fijo';

  @override
  String get merchantFormValueMinutes => 'Minutos gratis (1-1440)';

  @override
  String get merchantFormValuePercent => 'Porcentaje (1-100)';

  @override
  String get merchantFormValueAmount => 'Monto del descuento';

  @override
  String get merchantFormMaxAmount => 'Tope por validación (opcional)';

  @override
  String get merchantFormBilling => '¿Quién paga el beneficio?';

  @override
  String get merchantBillingMerchantPaid => 'El comercio paga';

  @override
  String get merchantBillingCourtesy => 'Cortesía del parqueadero';

  @override
  String get merchantFormDailyCap => 'Máximo por día (opcional)';

  @override
  String get merchantFormMonthlyCap => 'Máximo por mes (opcional)';

  @override
  String get merchantFormActive => 'Activo';

  @override
  String merchantUsage(int today, int month) {
    return 'Hoy $today · Mes $month';
  }

  @override
  String merchantPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pendientes',
      one: '1 pendiente',
      zero: 'Sin pendientes',
    );
    return '$_temp0';
  }

  @override
  String get merchantLocked => 'Bloqueado por PIN';

  @override
  String get merchantCredentialsTitle => 'Credenciales del comercio';

  @override
  String get merchantCredentialsHint =>
      'Se muestran una sola vez. Entrega el enlace y el PIN al cajero del comercio.';

  @override
  String get merchantCredentialsLink => 'Enlace';

  @override
  String get merchantCredentialsPin => 'PIN';

  @override
  String get merchantCredentialsCopy => 'Copiar';

  @override
  String merchantCredentialsNoAppUrl(String path) {
    return 'Falta configurar APP_URL: copia solo la ruta $path.';
  }

  @override
  String get merchantResetPin => 'Generar nuevo PIN';

  @override
  String get merchantRotateToken => 'Generar nuevo enlace y PIN';

  @override
  String merchantDeleteConfirm(String name) {
    return '¿Eliminar el convenio $name?';
  }

  @override
  String get merchantPolicyTitle => 'Convenios por vehículo';

  @override
  String get merchantPolicyMax =>
      'Máximo de convenios por vehículo (0 = desactivar)';

  @override
  String get merchantSettlementTitle => 'Liquidación';

  @override
  String get merchantSettlementEmpty => 'No hubo convenios en este rango.';

  @override
  String get merchantSettlementValidations => 'Validaciones';

  @override
  String get merchantSettlementApplied => 'Aplicadas';

  @override
  String get merchantSettlementForfeited => 'Sin efecto';

  @override
  String get merchantSettlementRevoked => 'Revocadas';

  @override
  String get merchantSettlementDiscounted => 'Descuento otorgado';

  @override
  String get merchantSettlementOwed => 'A cobrar al comercio';

  @override
  String get merchantSettlementCourtesy => 'Cortesía del parqueadero';

  @override
  String get merchantSettlementPdfTitle => 'Liquidación de convenios';

  @override
  String get validateTitle => 'Validar parqueo';

  @override
  String get validatePlateLabel => 'Placa del cliente';

  @override
  String get validateScanQr => 'Escanear QR del recibo';

  @override
  String get validatePinLabel => 'PIN del comercio';

  @override
  String get validateSubmit => 'Validar';

  @override
  String validateBenefitMinutes(int minutes) {
    return '$minutes minutos gratis';
  }

  @override
  String validateBenefitPercent(int percent) {
    return '$percent% de descuento';
  }

  @override
  String validateBenefitAmount(String amount) {
    return '$amount de descuento';
  }

  @override
  String validateSuccess(String benefit) {
    return 'Convenio registrado: $benefit';
  }

  @override
  String validateWrongPin(int left) {
    return 'PIN incorrecto. Intentos restantes: $left';
  }

  @override
  String validateLocked(String time) {
    return 'Demasiados intentos. Intenta de nuevo a las $time.';
  }

  @override
  String get validateInvalidLink =>
      'Este enlace no es válido. Pide uno nuevo al parqueadero.';

  @override
  String get validateAnother => 'Validar otra placa';

  @override
  String get deskMerchantTitle => 'Convenio';

  @override
  String get deskMerchantPick => 'Elegir comercio';

  @override
  String get deskMerchantApply => 'Aplicar convenio';

  @override
  String get deskMerchantRevoke => 'Quitar convenio';

  @override
  String get deskMerchantRevokeReason => 'Motivo (mínimo 3 caracteres)';

  @override
  String get deskMerchantOffline => 'Requiere conexión';

  @override
  String get fareGross => 'Tarifa';

  @override
  String fareAdjustmentMerchant(String name) {
    return 'Convenio $name';
  }

  @override
  String get fareAmountDue => 'A pagar';

  @override
  String get errorMerchantNotFound => 'Comercio no encontrado.';

  @override
  String get errorMerchantInactive => 'Este convenio está desactivado.';

  @override
  String get errorDuplicateMerchant => 'Ya existe un comercio con ese nombre.';

  @override
  String get errorMerchantInUse =>
      'El convenio tiene validaciones: desactívalo en lugar de eliminarlo.';

  @override
  String get errorAlreadyValidated => 'Este comercio ya validó ese vehículo.';

  @override
  String get errorMerchantLimit =>
      'El vehículo ya alcanzó el máximo de convenios.';

  @override
  String get errorMerchantCap =>
      'El comercio alcanzó su límite de validaciones.';

  @override
  String get errorSessionNotEligible =>
      'Este vehículo tiene mensualidad: no necesita convenio.';

  @override
  String get errorValidationNotFound => 'Validación no encontrada.';

  @override
  String get errorValidationNotRevocable =>
      'Solo se puede quitar una validación pendiente de un vehículo que sigue dentro.';

  @override
  String get errorRevokeReasonRequired =>
      'Escribe un motivo de 3 a 200 caracteres.';

  @override
  String get navPricing => 'Tarifas dinamicas';

  @override
  String get pricingTitle => 'Tarifas dinamicas';

  @override
  String get pricingEnabled => 'Activar tarifas dinamicas';

  @override
  String get pricingEnabledHint =>
      'Con la opcion apagada se cobra siempre la tarifa normal.';

  @override
  String get pricingFloor => 'Minimo (% de la tarifa)';

  @override
  String get pricingCeiling => 'Maximo (% de la tarifa)';

  @override
  String get pricingRoundTo => 'Redondear a';

  @override
  String get pricingSettingsSaved => 'Ajustes guardados';

  @override
  String get pricingRulesTitle => 'Reglas';

  @override
  String get pricingNoRules => 'Aun no hay reglas';

  @override
  String get pricingNoRulesHint =>
      'Crea una regla para subir o bajar la tarifa segun ocupacion u horario.';

  @override
  String get pricingAddRule => 'Agregar regla';

  @override
  String get pricingEditRule => 'Editar regla';

  @override
  String get pricingRuleName => 'Nombre';

  @override
  String get pricingRulePriority => 'Prioridad (mayor gana)';

  @override
  String get pricingRuleGroup => 'Tipo de vehiculo';

  @override
  String get pricingRuleGroupAll => 'Todos';

  @override
  String get pricingRuleOccupancyFrom => 'Ocupacion desde (%)';

  @override
  String get pricingRuleOccupancyTo => 'Ocupacion hasta (%)';

  @override
  String get pricingRuleWeekdays => 'Dias';

  @override
  String get pricingRuleFromTime => 'Desde';

  @override
  String get pricingRuleToTime => 'Hasta';

  @override
  String get pricingRuleMultiplier => 'Multiplicador (%)';

  @override
  String get pricingRuleSurcharge => 'Recargo fijo';

  @override
  String get pricingRuleActive => 'Activa';

  @override
  String pricingRuleSummary(String group, String when, String effect) {
    return '$group, $when: $effect';
  }

  @override
  String get pricingRuleSaved => 'Regla guardada';

  @override
  String get pricingRuleDeleted => 'Regla eliminada';

  @override
  String get pricingRuleDeleteConfirm =>
      'Las entradas ya registradas conservan su tarifa. Eliminar esta regla?';

  @override
  String get pricingSimulate => 'Simular';

  @override
  String pricingSimulateDays(int days) {
    return 'Ultimos $days dias';
  }

  @override
  String get pricingSimIncludeDraft => 'Incluir la regla sin guardar';

  @override
  String get pricingSimBase => 'Cobro con tarifa normal';

  @override
  String get pricingSimTotal => 'Cobro simulado';

  @override
  String get pricingSimDelta => 'Diferencia';

  @override
  String pricingSimAffected(int count) {
    return '$count entradas afectadas';
  }

  @override
  String pricingSimAtLimits(int floor, int ceiling) {
    return '$floor en el minimo, $ceiling en el maximo';
  }

  @override
  String get pricingSimByRule => 'Por regla';

  @override
  String get pricingSimByHour => 'Por hora de entrada';

  @override
  String get pricingSimEmpty => 'No hay entradas cobradas en ese periodo.';

  @override
  String get pricingSimNote =>
      'Usa tarifas y capacidad actuales y no cuenta reservas.';

  @override
  String get pricingReportTitle => 'Impacto de tarifas dinamicas';

  @override
  String get pricingReportLocked => 'Entradas con tarifa fijada';

  @override
  String get pricingReportExtra => 'Ingreso adicional';

  @override
  String get pricingReportDiscount => 'Descuentos por tarifa';

  @override
  String get pricingReportNet => 'Efecto neto';

  @override
  String priceQuoteNow(String amount) {
    return 'Tarifa ahora: $amount/h';
  }

  @override
  String priceQuoteUsually(String amount) {
    return 'Normal: $amount/h';
  }

  @override
  String get priceQuoteHigher => 'Mas alta';

  @override
  String get priceQuoteLower => 'Mas baja';

  @override
  String get priceQuoteOffline => 'La tarifa se confirma al sincronizar.';

  @override
  String publicPriceNow(String amount) {
    return 'Ahora $amount/h';
  }

  @override
  String publicPriceUsually(String amount) {
    return 'Precio normal $amount/h';
  }

  @override
  String publicRateLocked(String amount) {
    return 'Tarifa fijada: $amount/h hasta tu llegada';
  }

  @override
  String farePricingRule(String name, String percent) {
    return 'Tarifa dinamica: $name ($percent)';
  }

  @override
  String receiptRateLine(String name) {
    return 'Tarifa: $name';
  }

  @override
  String get fareRateLocked => 'Tarifa fijada a la entrada';

  @override
  String get errorInvalidPricingRule =>
      'Revisa la regla: hay valores fuera de rango.';

  @override
  String get errorDuplicatePricingRule => 'Ya existe una regla con ese nombre.';

  @override
  String get errorPricingRuleNotFound => 'La regla ya no existe.';

  @override
  String get errorInvalidPricingSettings =>
      'Minimo, maximo o redondeo fuera de rango.';

  @override
  String get errorPricingSimulationTooLarge =>
      'Demasiadas entradas: elige menos dias.';

  @override
  String get loyaltyTitle => 'Fidelización';

  @override
  String get loyaltyTabProgram => 'Programa';

  @override
  String get loyaltyTabMembers => 'Clientes';

  @override
  String get loyaltyTabReport => 'Reporte';

  @override
  String get loyaltyEnabled => 'Programa activo';

  @override
  String get loyaltyVisitsRequired => 'Visitas para ganar';

  @override
  String get loyaltyRewardKind => 'Tipo de recompensa';

  @override
  String get loyaltyKindFreeStay => 'Estadía gratis';

  @override
  String get loyaltyKindFixed => 'Descuento fijo';

  @override
  String get loyaltyRewardMax => 'Tope de la estadía gratis';

  @override
  String get loyaltyRewardFixed => 'Valor del descuento';

  @override
  String get loyaltyMinAmount => 'Pago mínimo por visita';

  @override
  String get loyaltyMinMinutes => 'Minutos mínimos por visita';

  @override
  String get loyaltyRedeemMode => 'Canje';

  @override
  String get loyaltyModeAuto => 'Automático';

  @override
  String get loyaltyModeOperator => 'Lo decide el operador';

  @override
  String get loyaltyStackMerchant => 'Acumular con convenios';

  @override
  String get loyaltyValidDays => 'Vigencia de la recompensa (días)';

  @override
  String get loyaltySave => 'Guardar programa';

  @override
  String get loyaltySaved => 'Programa guardado';

  @override
  String loyaltyVisitOf(int current, int total) {
    return 'Visita $current de $total';
  }

  @override
  String get loyaltyRewardAvailable => 'Recompensa disponible';

  @override
  String get loyaltyRewardEarned => '¡Recompensa ganada!';

  @override
  String get loyaltyUseReward => 'Usar recompensa';

  @override
  String get loyaltyDontUseNow => 'No usar ahora';

  @override
  String get loyaltyRewardLine => 'Recompensa de fidelidad';

  @override
  String loyaltyRewardExpires(String date) {
    return 'Vence el $date';
  }

  @override
  String get loyaltyMembersEmpty => 'Aún no hay clientes con visitas';

  @override
  String get loyaltyEnableCta => 'Activar el programa';

  @override
  String get loyaltySearchPlate => 'Buscar placa';

  @override
  String get loyaltyAdjust => 'Corregir progreso';

  @override
  String get loyaltyAdjustDelta => 'Cambio (+/-)';

  @override
  String get loyaltyAdjustReason => 'Motivo (obligatorio)';

  @override
  String get loyaltyReportMembers => 'Clientes';

  @override
  String get loyaltyReportCounted => 'Visitas contadas';

  @override
  String get loyaltyReportSkipped => 'Visitas no contadas';

  @override
  String get loyaltyReportEarned => 'Recompensas ganadas';

  @override
  String get loyaltyReportRedeemed => 'Recompensas canjeadas';

  @override
  String get loyaltyReportDiscount => 'Descuento otorgado';

  @override
  String get loyaltyReportTopPlates => 'Placas frecuentes';

  @override
  String get loyaltySkip_pass => 'Pase mensual';

  @override
  String get loyaltySkip_lost_ticket => 'Ticket perdido';

  @override
  String get loyaltySkip_exempt => 'Exento';

  @override
  String get loyaltySkip_below_amount => 'Pago bajo el mínimo';

  @override
  String get loyaltySkip_below_minutes => 'Estadía muy corta';

  @override
  String get loyaltySkip_same_day => 'Ya contó hoy';

  @override
  String get loyaltySkip_reward_redeemed => 'Usó recompensa';

  @override
  String get loyaltySkip_error => 'Error interno';

  @override
  String get loyaltyRefreshReport => 'Actualizar reporte';

  @override
  String get loyaltyCopyCsv => 'Copiar CSV';

  @override
  String get loyaltyCsvCopied => 'CSV copiado';

  @override
  String get loyaltySharePdf => 'Compartir PDF';

  @override
  String get errorLoyaltyDisabled =>
      'El programa de fidelización está desactivado';

  @override
  String get errorLoyaltySettings => 'Revisa los valores del programa';

  @override
  String get errorLoyaltyChoice => 'Opción de canje no válida';

  @override
  String get errorNoRewardAvailable =>
      'Esta placa no tiene recompensa disponible';

  @override
  String get errorLoyaltyReason => 'Escribe un motivo de 3 a 200 caracteres';

  @override
  String get errorLoyaltyAdjustRange =>
      'El ajuste dejaría el progreso fuera de rango';

  @override
  String get errorLoyaltyAccountNotFound =>
      'Esa placa no tiene cuenta de fidelización';

  @override
  String get loyaltyReportEmpty => 'Aún no hay datos en el periodo';

  @override
  String get navLoyalty => 'Fidelización';

  @override
  String get navInvoicing => 'Facturación';

  @override
  String get invoicingTitle => 'Facturación electrónica';

  @override
  String get invoicingMode => 'Modo';

  @override
  String get invoicingModeOff => 'Apagada';

  @override
  String get invoicingModeOnRequest => 'Solo a solicitud';

  @override
  String get invoicingModeAlways => 'Siempre';

  @override
  String get invoicingSettings => 'Datos del emisor';

  @override
  String get invoicingNit => 'NIT del emisor';

  @override
  String get invoicingLegalName => 'Razón social';

  @override
  String get invoicingMunicipality => 'Código de municipio';

  @override
  String get invoicingTaxRate => 'Tarifa de impuesto (puntos básicos)';

  @override
  String get invoicingPricesIncludeTax => 'Los precios ya incluyen el impuesto';

  @override
  String get invoicingResolutions => 'Resoluciones de numeración';

  @override
  String get invoicingResolutionAdd => 'Agregar resolución';

  @override
  String invoicingResolutionRemaining(int count) {
    return 'Quedan $count números';
  }

  @override
  String get invoicingDocuments => 'Documentos';

  @override
  String get invoicingEmpty =>
      'Aún no hay documentos. Configura una resolución para empezar.';

  @override
  String get invoicingStatusPending => 'Pendiente';

  @override
  String get invoicingStatusSent => 'Enviado';

  @override
  String get invoicingStatusAccepted => 'Aceptado';

  @override
  String get invoicingStatusRejected => 'Rechazado';

  @override
  String get invoicingStatusFailed => 'Falló';

  @override
  String get invoicingRetry => 'Reintentar envío';

  @override
  String get invoicingCreditNote => 'Nota crédito';

  @override
  String get invoicingCreditReason => 'Motivo de la nota crédito';

  @override
  String get invoicingIssue => 'Emitir factura electrónica';

  @override
  String invoicingIssued(String number) {
    return 'Documento creado: $number';
  }

  @override
  String get invoicingNotConfigured =>
      'El proveedor de facturación no está configurado; los documentos quedan pendientes.';

  @override
  String get invoicingOnlineOnly => 'Requiere conexión';

  @override
  String get fiscalCustomerSection => 'Datos para factura (opcional)';

  @override
  String get fiscalDocType => 'Tipo de documento';

  @override
  String get fiscalDocNumber => 'Número de documento';

  @override
  String get fiscalName => 'Nombre o razón social';

  @override
  String get fiscalEmail => 'Correo electrónico';

  @override
  String get fiscalInvalidCustomer => 'Revisa los datos del cliente';

  @override
  String get receiptFiscalPending => 'Documento electrónico en proceso';

  @override
  String get notifTypeFiscalFailed => 'Documento electrónico con problema';

  @override
  String get notifTypeFiscalResolutionLow =>
      'Resolución de numeración por agotarse';

  @override
  String get errorFiscalNotEnabled =>
      'La facturación electrónica no está activa';

  @override
  String get errorFiscalResolutionMissing =>
      'No hay resolución de numeración activa';

  @override
  String get errorFiscalResolutionExpired =>
      'La resolución de numeración venció';

  @override
  String get errorFiscalResolutionExhausted =>
      'Se agotó la numeración autorizada';

  @override
  String get errorFiscalSourceNotFound => 'No se encontró la venta a facturar';

  @override
  String get errorFiscalSourceNotBillable => 'Esta venta no se puede facturar';

  @override
  String get errorInvalidFiscalCustomer => 'Datos del cliente no válidos';

  @override
  String get errorFiscalDocumentNotFound => 'Documento no encontrado';

  @override
  String get errorFiscalDocumentNotAccepted =>
      'Solo se puede acreditar un documento aceptado';

  @override
  String get errorFiscalDocumentAlreadyCredited =>
      'El documento ya tiene una nota crédito';

  @override
  String get errorInvalidFiscalStatus =>
      'El documento no está en un estado que permita reintentar';

  @override
  String get errorFiscalSettingsIncomplete =>
      'Completa NIT, razón social y municipio';

  @override
  String get errorFiscalDocumentImmutable =>
      'El documento ya está numerado y no se puede modificar';

  @override
  String get fiscalInvoiceTitle => 'FACTURA ELECTRÓNICA DE VENTA';

  @override
  String get fiscalPosTitle => 'DOCUMENTO EQUIVALENTE POS';

  @override
  String get fiscalCufe => 'CUFE';

  @override
  String get assistantTitle => 'Asistente de reportes';

  @override
  String get assistantOpenTooltip => 'Preguntar al asistente';

  @override
  String get assistantInputHint =>
      'Pregunta sobre ingresos, tráfico o reservas';

  @override
  String get assistantSend => 'Enviar';

  @override
  String get assistantClear => 'Nueva conversación';

  @override
  String get assistantEmptyTitle => 'Pregunta en lenguaje natural';

  @override
  String get assistantEmptyMessage =>
      'Las cifras salen de tus reportes y cada una muestra su fuente.';

  @override
  String get assistantSuggestionsTitle => 'Prueba con';

  @override
  String get assistantSuggestRevenueMonth =>
      '¿Cuánto generaron las motos el mes pasado?';

  @override
  String get assistantSuggestBusiestHour => '¿A qué hora entran más vehículos?';

  @override
  String get assistantSuggestReservations =>
      '¿Cuántas reservas web terminaron en entrada este mes?';

  @override
  String get assistantSuggestCompare =>
      '¿Cómo van los ingresos de esta semana frente a la anterior?';

  @override
  String get assistantSuggestCash =>
      '¿Hubo diferencias de caja en los últimos cierres?';

  @override
  String get assistantSuggestFull =>
      '¿Qué tan lleno está el parqueadero ahora?';

  @override
  String get assistantPrivacyNote =>
      'Tu pregunta y datos agregados de tus reportes se envían al proveedor de IA. No escribas placas ni nombres.';

  @override
  String get assistantRedacted =>
      'Quitamos datos personales de tu pregunta antes de enviarla.';

  @override
  String assistantBudgetLeft(int count) {
    return 'Quedan $count consultas hoy';
  }

  @override
  String get assistantThinking => 'Consultando tus reportes…';

  @override
  String assistantToolRunning(String report) {
    return 'Consultando $report…';
  }

  @override
  String assistantToolDone(String report) {
    return '$report: listo';
  }

  @override
  String get assistantStatusNeedsClarification => 'Necesito un dato más';

  @override
  String get assistantStatusOutOfScope => 'Fuera de alcance';

  @override
  String get assistantStatusNoData => 'Sin datos en el periodo';

  @override
  String get assistantFigures => 'Cifras';

  @override
  String get assistantSourceTitle => 'De dónde sale esta cifra';

  @override
  String assistantSourceReport(String rpc) {
    return 'Reporte: $rpc';
  }

  @override
  String assistantSourceArgs(String args) {
    return 'Parámetros: $args';
  }

  @override
  String assistantSourcePath(String path) {
    return 'Campo: $path';
  }

  @override
  String assistantSourceRaw(String value) {
    return 'Valor en el reporte: $value';
  }

  @override
  String get assistantVerified => 'Cifra verificada con el reporte';

  @override
  String get assistantUnverified => 'No se pudo verificar esta cifra';

  @override
  String get assistantUndefinedValue => '—';

  @override
  String get assistantCopyAnswer => 'Copiar respuesta';

  @override
  String get assistantCopyFigures => 'Copiar cifras (CSV)';

  @override
  String get assistantCopied => 'Copiado al portapapeles';

  @override
  String get assistantDisclaimer =>
      'Respuesta generada por IA a partir de tus reportes. Verifica las cifras en su fuente.';

  @override
  String get assistantNotConfiguredTitle => 'El asistente no está activado';

  @override
  String get assistantNotConfiguredMessage =>
      'Falta la clave de la API de IA en el servidor. Consulta el runbook de secretos.';

  @override
  String assistantPeriod(String start, String end) {
    return 'Periodo: $start a $end';
  }

  @override
  String get errorAiBudget =>
      'Se alcanzó el límite diario de consultas del asistente';

  @override
  String get errorAiUnavailable =>
      'El asistente no está disponible en este momento';

  @override
  String get errorAiTimeout => 'El asistente tardó demasiado. Intenta de nuevo';

  @override
  String get errorAiUpstream =>
      'El servicio de IA no respondió. Intenta de nuevo';

  @override
  String get errorAiRefused => 'El asistente no pudo responder esta pregunta';

  @override
  String get errorAiAnswerInvalid =>
      'La respuesta no pasó la verificación de cifras';

  @override
  String get errorAiLimit =>
      'La pregunta es demasiado amplia. Prueba con un periodo más corto';

  @override
  String get errorAiQuestionInvalid => 'Escribe una pregunta válida';

  @override
  String get damageTitle => 'Comparación de daños';

  @override
  String get damageAdvisoryTitle => 'Análisis orientativo con IA';

  @override
  String get damageAdvisoryBody =>
      'Puede pasar por alto daños o confundir reflejos y suciedad con daños. Verifica cada punto en el vehículo: la decisión es de una persona.';

  @override
  String get damageVerdictNone =>
      'No se detectaron daños nuevos en las fotos comparadas';

  @override
  String get damageVerdictPossible => 'Posible daño nuevo: verifica';

  @override
  String get damageVerdictInsufficient =>
      'Evidencia insuficiente para comparar';

  @override
  String get damageClassPre => 'Ya existía';

  @override
  String get damageClassNew => 'Posible daño nuevo: verifica';

  @override
  String get damageClassUncertain => 'Incierto';

  @override
  String get damageRun => 'Comparar con las fotos de entrada';

  @override
  String get damageRerun => 'Volver a analizar';

  @override
  String get damageRunning => 'Analizando fotos…';

  @override
  String get damageEmptyTitle => 'Aún no hay comparación';

  @override
  String get damageEmptyNeedExit =>
      'Toma fotos de salida en el check-out para poder comparar.';

  @override
  String get damageEmptyNeedEntry =>
      'Esta entrada no tiene fotos para comparar.';

  @override
  String get damageNotConfigured =>
      'El análisis con IA no está activado en el servidor.';

  @override
  String get damageReviewConfirm => 'Confirmar';

  @override
  String get damageReviewDismiss => 'Descartar';

  @override
  String get damageReviewNoteLabel => 'Nota (obligatoria)';

  @override
  String get damageReviewAudited =>
      'La decisión y la nota quedan en la auditoría.';

  @override
  String get damageExitSection => 'Fotos de salida (opcional)';

  @override
  String get damageExitHint =>
      'Sirven para resolver reclamos de daños. Usa los mismos ángulos que a la entrada.';

  @override
  String get damageExitOffline => 'Las fotos de salida necesitan conexión.';

  @override
  String get damageExitSaved => 'Fotos de salida guardadas';

  @override
  String get damageExitFailed => 'No se pudieron guardar las fotos de salida';

  @override
  String get damageExitSkippedOffline =>
      'Salida registrada sin conexión: las fotos de salida no se guardaron.';

  @override
  String get damageAddPhoto => 'Tomar foto';

  @override
  String damagePhotosCount(int count) {
    return '$count foto(s)';
  }

  @override
  String get errorInsufficientEvidence =>
      'Faltan fotos de entrada o de salida para comparar';

  @override
  String get errorComparisonInProgress =>
      'Ya hay un análisis en curso para este vehículo';

  @override
  String get errorComparisonExists =>
      'Ya se analizó esta salida; un administrador puede repetirla';

  @override
  String get errorEvidenceUnreadable => 'No se pudieron leer las fotos';

  @override
  String get errorEvidenceLimit => 'Máximo 5 fotos de salida por vehículo';

  @override
  String get errorFindingNotFound => 'Hallazgo no encontrado';

  @override
  String get errorComparisonNotFound => 'Comparación no encontrada';

  @override
  String get navDevices => 'Dispositivos';

  @override
  String get devicesTitle => 'Dispositivos';

  @override
  String get devicesEmpty => 'Aún no hay dispositivos';

  @override
  String get devicesEmptyHint =>
      'Registra una cámara, barrera o hub para conectarlo.';

  @override
  String get devicesAdd => 'Registrar dispositivo';

  @override
  String get devicesKind => 'Tipo';

  @override
  String get devicesName => 'Nombre';

  @override
  String get devicesRate => 'Peticiones por minuto';

  @override
  String get devicesStatusOnline => 'En línea';

  @override
  String get devicesStatusOffline => 'Sin conexión';

  @override
  String get devicesStatusNeverSeen => 'Nunca visto';

  @override
  String get devicesStatusDisabled => 'Deshabilitado';

  @override
  String get devicesRotate => 'Rotar clave';

  @override
  String get devicesKeyTitle => 'Guarda esta clave';

  @override
  String get devicesKeyHint =>
      'No se volverá a mostrar. Configúrala en el dispositivo.';

  @override
  String get devicesCopied => 'Copiado';

  @override
  String get devicesEnable => 'Habilitar';

  @override
  String get devicesDisable => 'Deshabilitar';

  @override
  String get devicesRename => 'Renombrar';

  @override
  String get devicesDelete => 'Eliminar';

  @override
  String get devicesEvents => 'Historial';

  @override
  String get devicesOfflineMinutes => 'Minutos para marcar sin conexión';

  @override
  String get devicesSaved => 'Guardado';

  @override
  String get devicesDeleteConfirm =>
      'El dispositivo dejará de autenticarse. ¿Eliminar?';

  @override
  String devicesLastSeen(String when) {
    return 'Último contacto: $when';
  }

  @override
  String devicesFirmware(String version) {
    return 'Firmware: $version';
  }

  @override
  String get errorInvalidDeviceKind => 'Tipo de dispositivo no válido';

  @override
  String get errorInvalidDeviceName => 'Nombre de dispositivo no válido';

  @override
  String get errorDeviceNameTaken => 'Ya existe un dispositivo con ese nombre';

  @override
  String get errorDeviceLimit => 'Máximo 50 dispositivos por sede';

  @override
  String get errorDeviceNotFound => 'Dispositivo no encontrado';

  @override
  String get errorDeviceUnauthorized => 'Clave de dispositivo no válida';

  @override
  String get errorDeviceDisabled => 'El dispositivo está deshabilitado';

  @override
  String get errorDeviceClockSkew => 'Reloj del dispositivo desviado';

  @override
  String get errorDeviceReplay => 'Petición repetida';

  @override
  String get errorDeviceRateLimited => 'Demasiadas peticiones del dispositivo';
}
