/// Cloudflare Turnstile for the public booking form. Only the browser can
/// render it; every other target gets a stub so the app still compiles.
library;

export 'turnstile_view_stub.dart'
    if (dart.library.js_interop) 'turnstile_view_web.dart';
