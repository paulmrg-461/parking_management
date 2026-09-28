import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';
import '../network/connectivity_cubit.dart';
import '../theme/tokens.dart';

/// Thin banner shown while offline (driven by [ConnectivityCubit]); the
/// change is announced to screen readers. Renders nothing when no cubit is
/// provided (isolated widget tests).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = _maybeCubit(context);
    if (cubit == null) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<ConnectivityCubit, bool>(
      bloc: cubit,
      builder: (context, online) => AnimatedSize(
        duration: Motion.short,
        child: online ? const SizedBox(width: double.infinity) : const _Bar(),
      ),
    );
  }

  ConnectivityCubit? _maybeCubit(BuildContext context) {
    try {
      return context.read<ConnectivityCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: scheme.inverseSurface,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, size: 20, color: scheme.onInverseSurface),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    context.l10n.offlineBanner,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onInverseSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
