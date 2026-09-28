/// Result of sending a receipt to a Bluetooth printer.
enum PrintOutcome {
  success,
  printerNotSelected,
  scanInProgress,
  printInProgress,
  timeout,
  ticketEmpty,
  failed,
}
