import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';

/// Branded first frame while the session restore (and lot memberships) runs.
/// The router keeps this route until `AuthCubit` resolves, so the app never
/// flashes the login form before deciding where to send the user.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/branding/logo.png', width: 88, height: 88),
            const SizedBox(height: Space.md),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: context.l10n.loading,
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              context.l10n.loading,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
