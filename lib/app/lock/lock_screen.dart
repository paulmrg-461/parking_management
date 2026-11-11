import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/l10n/failure_messages.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../features/auth/application/auth_cubit.dart';

/// Full-screen PIN gate shown after the idle timeout. Verifying the PIN uses
/// the regular GoTrue login, so no extra secret is stored on the device.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.username,
    required this.onUnlocked,
  });

  final String username;
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const _maxAttempts = 5;

  final _formKey = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _focus = FocusNode();
  bool _submitting = false;
  int _attempts = 0;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_submitting || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthCubit>();
    await auth.login(widget.username, _pin.text.trim());
    if (!mounted) {
      return;
    }
    if (auth.state is AuthAuthenticated) {
      _pin.clear();
      widget.onUnlocked();
      return;
    }
    final failure = auth.state is AuthFailure
        ? (auth.state as AuthFailure).failure
        : null;
    setState(() {
      _submitting = false;
      _attempts++;
      _error = failure == null
          ? context.l10n.lockWrongPin
          : context.l10n.failure(failure);
    });
    _pin.clear();
    _focus.requestFocus();
    if (_attempts >= _maxAttempts) {
      await auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = (_maxAttempts - _attempts).clamp(0, _maxAttempts);
    return Positioned.fill(
      child: ColoredBox(
        color: scheme.surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_clock,
                                size: Space.xl,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.md),
                          Text(
                            l10n.lockTitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            l10n.lockHint,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: Space.sm),
                          Center(
                            child: Chip(
                              avatar: const Icon(
                                Icons.person_outline,
                                size: 18,
                              ),
                              label: Text(widget.username),
                            ),
                          ),
                          const SizedBox(height: Space.md),
                          TextFormField(
                            key: const Key('lock_pin'),
                            controller: _pin,
                            focusNode: _focus,
                            autofocus: true,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.loginPin,
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            onFieldSubmitted: (_) => _unlock(),
                            validator: (value) =>
                                (value ?? '').trim().length == 6
                                ? null
                                : l10n.pinInvalid,
                          ),
                          if (_error case final error?) ...[
                            const SizedBox(height: Space.sm),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                error,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                            Text(
                              l10n.lockAttemptsLeft(remaining),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: Space.md),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: Layout.minTouch,
                            ),
                            child: FilledButton.icon(
                              key: const Key('lock_unlock'),
                              onPressed: _submitting ? null : _unlock,
                              icon: _submitting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.lock_open),
                              label: Text(l10n.lockUnlock),
                            ),
                          ),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => context.read<AuthCubit>().logout(),
                            child: Text(l10n.lockLogout),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
