// Picks the platform adapters at compile time so the web bundle never
// references ML Kit, `dart:io` or `path_provider` file APIs.
export 'platform_module_io.dart'
    if (dart.library.js_interop) 'platform_module_web.dart';
