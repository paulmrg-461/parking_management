class AppSettings {
  AppSettings({
    this.deviceId = '',
    this.lastSyncAt,
  });

  final String deviceId;

  final DateTime? lastSyncAt;
}
