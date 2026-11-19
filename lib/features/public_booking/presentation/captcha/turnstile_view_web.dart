import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../../core/widgets/skeleton.dart';
import 'captcha_request.dart';

const bool turnstileSupported = true;

Widget buildTurnstile(BuildContext context, CaptchaRequest request) =>
    TurnstileView(request: request);

const _scriptUrl =
    'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
const _scriptTimeout = Duration(seconds: 15);
const _attachPoll = Duration(milliseconds: 50);
const _attachMaxTicks = 40;

/// Height of the managed Turnstile widget (65 px) on the 8pt grid.
const double _widgetHeight = 72;

@JS('turnstile')
external _TurnstileApi? get _api;

extension type _TurnstileApi._(JSObject _) implements JSObject {
  external JSAny? render(web.HTMLElement container, JSObject options);
  external void remove(JSAny widgetId);
}

Future<void>? _scriptLoad;

/// Loads `api.js` once per page. A failed load is forgotten so "retry" can
/// try again (ad blockers and flaky networks are the usual cause).
Future<void> _loadScript() => _scriptLoad ??= _injectScript();

Future<void> _injectScript() async {
  if (_api != null) {
    return;
  }
  final done = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = _scriptUrl
    ..async = true
    ..defer = true;
  script.onload = ((web.Event _) => done.complete()).toJS;
  script.onerror = ((web.Event _) {
    done.completeError(StateError('Turnstile script failed to load'));
  }).toJS;
  web.document.head!.append(script);
  try {
    await done.future.timeout(_scriptTimeout);
  } on Object {
    _scriptLoad = null;
    script.remove();
    rethrow;
  }
}

/// The Turnstile challenge inside a platform view. Loading shows a skeleton
/// with the widget's geometry; a script or challenge failure is reported
/// through [CaptchaRequest.onError] and the form renders the message + retry.
class TurnstileView extends StatefulWidget {
  const TurnstileView({super.key, required this.request});

  final CaptchaRequest request;

  @override
  State<TurnstileView> createState() => _TurnstileViewState();
}

class _TurnstileViewState extends State<TurnstileView> {
  bool _ready = false;
  JSAny? _widgetId;
  Timer? _attachTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      await _loadScript();
    } on Object {
      if (mounted) {
        widget.request.onError();
      }
      return;
    }
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  /// Turnstile needs the container in the document; the platform view hands
  /// the element over slightly before attaching it.
  void _onElement(Object created) {
    final element = created as web.HTMLElement;
    element.style
      ..width = '100%'
      ..height = '100%';
    _attachTimer = Timer.periodic(_attachPoll, (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (element.isConnected || timer.tick >= _attachMaxTicks) {
        timer.cancel();
        _render(element);
      }
    });
  }

  void _render(web.HTMLElement element) {
    final api = _api;
    if (api == null) {
      widget.request.onError();
      return;
    }
    try {
      _widgetId = api.render(element, _options());
    } on Object {
      widget.request.onError();
    }
  }

  JSObject _options() {
    final request = widget.request;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return JSObject()
      ..['sitekey'] = request.siteKey.toJS
      ..['theme'] = (dark ? 'dark' : 'light').toJS
      ..['size'] = 'flexible'.toJS
      ..['language'] = Localizations.localeOf(context).languageCode.toJS
      ..['callback'] = ((JSString token) => request.onToken(token.toDart)).toJS
      ..['expired-callback'] = (() => request.onExpired()).toJS
      ..['timeout-callback'] = (() => request.onExpired()).toJS
      ..['error-callback'] = ((JSAny? _) {
        request.onError();
        // `true` tells Turnstile the page handled the error itself.
        return true.toJS;
      }).toJS;
  }

  @override
  void dispose() {
    _attachTimer?.cancel();
    final id = _widgetId;
    if (id != null) {
      try {
        _api?.remove(id);
      } on Object {
        // The iframe is already gone with the platform view.
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _widgetHeight,
    child: _ready
        ? HtmlElementView.fromTagName(
            tagName: 'div',
            onElementCreated: _onElement,
          )
        : const SkeletonPulse(child: SkeletonBox(height: _widgetHeight)),
  );
}
