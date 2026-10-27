import 'web_push_registrar.dart';
import 'web_push_stub.dart'
    if (dart.library.js_interop) 'web_push_web.dart' as impl;

WebPushRegistrar createWebPushRegistrar() => impl.createRegistrar();
