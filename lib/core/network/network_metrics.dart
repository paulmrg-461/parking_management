/// Lightweight counters for the HTTP layer, shown in `/diagnostics` (admins)
/// so support can tell "slow/retrying network" apart from "server down".
/// They are process-local: reset when the app restarts.
abstract final class NetworkMetrics {
  static int timeouts = 0;
  static int retries = 0;
  static int failed = 0;

  static void reset() {
    timeouts = 0;
    retries = 0;
    failed = 0;
  }
}
