// Coverage ratchet for `flutter test --coverage`.
//
// The thresholds are FLOORS, not the final goal: raise them when a layer
// improves so coverage can only move forward. AGENTS targets 90 % on
// domain/application/infrastructure mappers; application already meets it,
// while domain/infrastructure still carry untested Supabase adapters.
//
// Usage: flutter test --coverage && dart run tool/check_coverage.dart
import 'dart:io';

const _lcovPath = 'coverage/lcov.info';

/// Global floor (all non-generated lib files).
const _globalFloor = 70.0;

/// Layer floors; keep them in sync with the measured baseline.
const _layerFloors = <String, double>{
  'application/': 90.0,
  'domain/': 35.0,
  'infrastructure/': 25.0,
};

class _Counter {
  int found = 0;
  int hit = 0;

  double get percent => found == 0 ? 100 : 100 * hit / found;

  void add(int lf, int lh) {
    found += lf;
    hit += lh;
  }
}

void main() {
  final file = File(_lcovPath);
  if (!file.existsSync()) {
    stderr.writeln('coverage file not found: $_lcovPath');
    stderr.writeln('Run: flutter test --coverage');
    exitCode = 2;
    return;
  }

  final global = _Counter();
  final layers = <String, _Counter>{
    for (final layer in _layerFloors.keys) layer: _Counter(),
  };

  String? current;
  var lf = 0;
  var lh = 0;
  void flush() {
    final path = current;
    if (path == null || lf == 0) {
      return;
    }
    if (_ignored(path)) {
      return;
    }
    global.add(lf, lh);
    for (final layer in layers.keys) {
      if (path.contains('/$layer')) {
        layers[layer]!.add(lf, lh);
        break;
      }
    }
  }

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      flush();
      current = line.substring(3);
      lf = 0;
      lh = 0;
    } else if (line.startsWith('LF:')) {
      lf = int.tryParse(line.substring(3)) ?? 0;
    } else if (line.startsWith('LH:')) {
      lh = int.tryParse(line.substring(3)) ?? 0;
    }
  }
  flush();

  var failed = false;
  stdout.writeln('Coverage (lines)');
  stdout.writeln('  all                ${_fmt(global.percent)}  floor ${_fmt(_globalFloor)}');
  if (global.percent < _globalFloor) {
    failed = true;
  }
  for (final entry in _layerFloors.entries) {
    final counter = layers[entry.key]!;
    final ok = counter.percent >= entry.value;
    stdout.writeln(
      '  ${entry.key.padRight(18)} ${_fmt(counter.percent)}  floor ${_fmt(entry.value)}'
      '${ok ? '' : '  <-- below floor'}',
    );
    if (!ok) {
      failed = true;
    }
  }

  if (failed) {
    stderr.writeln('Coverage dropped below the ratchet. Add tests or explain '
        'the intentional exception in the PR.');
    exitCode = 1;
  }
}

String _fmt(double value) => '${value.toStringAsFixed(1)}%';

/// Generated code and localization output do not count against the ratchet.
bool _ignored(String path) =>
    path.endsWith('.g.dart') ||
    path.startsWith('lib/l10n/') ||
    path.contains('/l10n/');
