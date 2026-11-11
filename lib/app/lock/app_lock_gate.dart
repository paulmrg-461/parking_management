import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/security/auto_lock_cubit.dart';
import '../../features/auth/application/auth_cubit.dart';
import 'lock_screen.dart';

/// Wraps the whole app: watches for idle time and covers the UI with
/// [LockScreen] while the session stays signed in. Any pointer interaction
/// resets the idle clock; the timer checks every 15 s and on resume.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.cubit, required this.child});

  final AutoLockCubit cubit;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  Timer? _timer;
  String? _username;

  @override
  void initState() {
    super.initState();
    widget.cubit.restore();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      widget.cubit.check();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent && !widget.cubit.state) {
      widget.cubit.recordActivity();
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.cubit.check();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthUnauthenticated && previous is! AuthUnauthenticated,
      listener: (_, _) => widget.cubit.unlock(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (!widget.cubit.state) {
            widget.cubit.recordActivity();
          }
        },
        child: BlocBuilder<AutoLockCubit, bool>(
          bloc: widget.cubit,
          builder: (context, locked) {
            final auth = context.watch<AuthCubit>().state;
            final session = auth is AuthAuthenticated ? auth.session : null;
            _username ??= session?.user.username;
            // While the PIN is being checked the state is AuthLoading or
            // AuthFailure; keep the overlay until it succeeds or the user
            // signs out (AuthUnauthenticated unlocks via the listener).
            final hide =
                !locked || _username == null || auth is AuthUnauthenticated;
            if (hide) {
              return widget.child;
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                LockScreen(
                  username: _username!,
                  onUnlocked: widget.cubit.unlock,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
