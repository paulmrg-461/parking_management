/// Labels used by the printed receipts (PDF and thermal), which cannot reach
/// the Flutter localization delegates. The on-screen receipt already renders
/// `context.l10n`; the paper one follows the same app language.
class ReceiptLabels {
  const ReceiptLabels({
    required this.checkInTitle,
    required this.checkOutTitle,
    required this.plate,
    required this.entry,
    required this.exit,
    required this.duration,
    required this.photos,
    required this.pendingSync,
    required this.total,
    required this.discount,
    required this.payment,
    required this.received,
    required this.change,
    required this.ticket,
    required this.generatedOn,
    required this.thanks,
    required this.scanHint,
    required this.evidenceHint,
    required this.paymentMethod,
  });

  final String checkInTitle;
  final String checkOutTitle;
  final String plate;
  final String entry;
  final String exit;
  final String duration;
  final String photos;
  final String pendingSync;
  final String total;
  final String discount;
  final String payment;
  final String received;
  final String change;
  final String ticket;
  final String generatedOn;
  final String thanks;

  /// Caption under the QR that opens the check-out flow.
  final String scanHint;

  /// Caption under the smaller QR that opens the public evidence page.
  final String evidenceHint;

  /// Localizes a wire value (`cash`, `card`, `transfer`, `monthly_pass`,
  /// `exempt`) plus the optional card type (`debit`/`credit`).
  final String Function(String method, String? cardType) paymentMethod;

  /// Accent-free labels: thermal printers run on a CP437 code page.
  static const spanish = ReceiptLabels(
    checkInTitle: 'RECIBO DE ENTRADA',
    checkOutTitle: 'RECIBO DE SALIDA',
    plate: 'Placa',
    entry: 'Entrada',
    exit: 'Salida',
    duration: 'Tiempo',
    photos: 'Fotos',
    pendingSync: 'PENDIENTE DE SINCRONIZAR',
    total: 'Total',
    discount: 'Descuento',
    payment: 'Pago',
    received: 'Recibido',
    change: 'Cambio',
    ticket: 'Ticket',
    generatedOn: 'Generado el',
    thanks: 'Gracias por su visita',
    scanHint: 'Presente este codigo al salir',
    evidenceHint: 'Evidencias del vehiculo (clave: placa)',
    paymentMethod: _paymentEs,
  );

  static const english = ReceiptLabels(
    checkInTitle: 'CHECK-IN RECEIPT',
    checkOutTitle: 'CHECK-OUT RECEIPT',
    plate: 'Plate',
    entry: 'Entry',
    exit: 'Exit',
    duration: 'Duration',
    photos: 'Photos',
    pendingSync: 'PENDING SYNC',
    total: 'Total',
    discount: 'Discount',
    payment: 'Payment',
    received: 'Received',
    change: 'Change',
    ticket: 'Ticket',
    generatedOn: 'Generated on',
    thanks: 'Thank you for your visit',
    scanHint: 'Show this code at the exit',
    evidenceHint: 'Vehicle evidence (key: plate)',
    paymentMethod: _paymentEn,
  );

  /// Falls back to Spanish for any other locale.
  factory ReceiptLabels.forLanguage(String languageCode) =>
      languageCode == 'en' ? english : spanish;

  static String _paymentEs(String method, String? cardType) => switch (method) {
    'card' when cardType == 'debit' => 'Tarjeta debito',
    'card' when cardType == 'credit' => 'Tarjeta credito',
    'cash' => 'Efectivo',
    'card' => 'Tarjeta',
    'transfer' => 'Transferencia',
    'monthly_pass' => 'Mensualidad',
    'exempt' => 'Exento',
    _ => method,
  };

  static String _paymentEn(String method, String? cardType) => switch (method) {
    'card' when cardType == 'debit' => 'Debit card',
    'card' when cardType == 'credit' => 'Credit card',
    'cash' => 'Cash',
    'card' => 'Card',
    'transfer' => 'Transfer',
    'monthly_pass' => 'Monthly pass',
    'exempt' => 'Exempt',
    _ => method,
  };
}
