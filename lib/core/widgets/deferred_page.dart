import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'error_state.dart';

/// Loads a `deferred as` library ([loader] = `lib.loadLibrary`) and only
/// then calls [builder], so deferred code is never touched before it is
/// loaded. Shows a spinner while loading and a retry on failure (e.g. the
/// web chunk could not be downloaded).
class DeferredPage extends StatefulWidget {
  const DeferredPage({super.key, required this.loader, required this.builder});

  final Future<void> Function() loader;
  final WidgetBuilder builder;

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late Future<void> _loading = widget.loader();

  void _retry() {
    final loading = widget.loader();
    setState(() {
      _loading = loading;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: context.l10n.loading,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _LoadError(onRetry: _retry);
        }
        return widget.builder(context);
      },
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ErrorState(
        message: context.l10n.deferredLoadError,
        onRetry: onRetry,
      ),
    );
  }
}
