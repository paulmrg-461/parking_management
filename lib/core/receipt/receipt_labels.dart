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
    required this.ticket,
    required this.generatedOn,
    required this.thanks,
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
  final String ticket;
  final String generatedOn;
  final String thanks;

  /// Localizes a wire value (`cash`, `card`, `transfer`, `monthly_pass`,
  /// `exempt`).
  final String Function(String method) paymentMethod;

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
    ticket: 'Ticket',
    generatedOn: 'Generado el',
    thanks: 'Gracias por su visita',
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
    ticket: 'Ticket',
    generatedOn: 'Generated on',
    thanks: 'Thank you for your visit',
    paymentMethod: _paymentEn,
  );

  /// Falls back to Spanish for any other locale.
  factory ReceiptLabels.forLanguage(String languageCode) =>
      languageCode == 'en' ? english : spanish;

  static String _paymentEs(String method) => switch (method) {
    'cash' => 'Efectivo',
    'card' => 'Tarjeta',
    'transfer' => 'Transferencia',
    'monthly_pass' => 'Mensualidad',
    'exempt' => 'Exento',
    _ => method,
  };

  static String _paymentEn(String method) => switch (method) {
    'cash' => 'Cash',
    'card' => 'Card',
    'transfer' => 'Transfer',
    'monthly_pass' => 'Monthly pass',
    'exempt' => 'Exempt',
    _ => method,
  };
}
