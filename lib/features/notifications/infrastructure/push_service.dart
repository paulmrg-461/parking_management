import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../domain/repositories/notification_repository.dart';

/// Registers this device for background push. In-app notifications do not
/// depend on it: they arrive through Realtime even when FCM is disabled.
abstract class PushService {
  Future<void> start();
}

class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<void> start() async {}
}

class FcmPushService implements PushService {
  FcmPushService(this._repository, this._config);

  final NotificationRepository _repository;
  final AppConfig _config;
  bool _started = false;

  @override
  Future<void> start() async {
    if (_started || !_config.fcmEnabled || !_hasFirebaseOptions) {
      return;
    }
    _started = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: _config.firebaseApiKey,
            appId: _config.firebaseAppId,
            messagingSenderId: _config.firebaseMessagingSenderId,
            projectId: _config.firebaseProjectId,
            storageBucket: _config.firebaseStorageBucket.isEmpty
                ? null
                : _config.firebaseStorageBucket,
          ),
        );
      }
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      await _register(await FirebaseMessaging.instance.getToken(
        vapidKey: _config.fcmVapidKey.isEmpty ? null : _config.fcmVapidKey,
      ));
      FirebaseMessaging.instance.onTokenRefresh.listen(_register);
    } catch (_) {
      // A missing/invalid Firebase project must never block login.
      _started = false;
    }
  }

  bool get _hasFirebaseOptions =>
      _config.firebaseApiKey.isNotEmpty &&
      _config.firebaseAppId.isNotEmpty &&
      _config.firebaseMessagingSenderId.isNotEmpty &&
      _config.firebaseProjectId.isNotEmpty;

  Future<void> _register(String? token) async {
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      await _repository.registerDeviceToken(token, _platform);
    } on Object {
      // The token is refreshed by FCM; retry on the next event.
    }
  }

  String get _platform {
    if (kIsWeb) {
      return 'web';
    }
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}
