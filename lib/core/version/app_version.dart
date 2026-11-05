/// Version compiled into this build (`--dart-define`/Flutter build name).
const appVersion = String.fromEnvironment(
  'FLUTTER_BUILD_NAME',
  defaultValue: '1.0.0',
);

/// Build number compiled into this build.
const appBuildNumber = String.fromEnvironment(
  'FLUTTER_BUILD_NUMBER',
  defaultValue: '1',
);

/// Parses `major.minor[.patch]`; anything else returns `null`.
List<int>? parseVersion(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  final match = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?$').firstMatch(text);
  if (match == null) {
    return null;
  }
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3) ?? '0'),
  ];
}

/// Negative when [a] is older, zero when equal, positive when newer.
int compareVersions(String a, String b) {
  final left = parseVersion(a);
  final right = parseVersion(b);
  if (left == null || right == null) {
    return 0;
  }
  for (var i = 0; i < 3; i++) {
    final diff = left[i] - right[i];
    if (diff != 0) {
      return diff;
    }
  }
  return 0;
}

/// True only when both versions are valid and [current] is below [minimum].
/// An empty or malformed minimum never blocks the app.
bool isVersionOutdated(String current, String? minimum) {
  final min = (minimum ?? '').trim();
  if (min.isEmpty || parseVersion(min) == null) {
    return false;
  }
  return compareVersions(current, min) < 0;
}
