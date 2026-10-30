import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_cubit.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/theme_mode_button.dart';
import '../../settings/application/branding_cubit.dart';
import '../../../app/router/route_access.dart';
import '../application/auth_cubit.dart';

/// Sign-in screen. Wide screens split into a brand panel and a card; phones
/// keep a single column. The PIN is obscured by default with an explicit
/// reveal toggle, Enter submits, and a rejected login is announced as a live
/// region error banner.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _formWidth = 420.0;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _showPin = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    final cubit = context.read<AuthCubit>();
    if (cubit.state is AuthLoading || !_formKey.currentState!.validate()) {
      return;
    }
    TextInput.finishAutofillContext();
    cubit.login(_usernameController.text.trim(), _pinController.text.trim());
  }

  String? _pin(String? value) {
    final pin = (value ?? '').trim();
    if (pin.isEmpty) {
      return context.l10n.fieldRequired;
    }
    return pin.length == 6 ? null : context.l10n.pinInvalid;
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? context.l10n.fieldRequired : null;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/');
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= Layout.railBreakpoint &&
                      constraints.maxHeight >= 560;
                  if (!wide) {
                    return _compact(context);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(flex: 11, child: _BrandPanel()),
                      Expanded(flex: 9, child: _cardArea(context)),
                    ],
                  );
                },
              ),
              const Positioned(
                top: Space.sm,
                right: Space.md,
                child: _CornerActions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _formWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _InlineBrand(),
              const SizedBox(height: Space.lg),
              _FormCard(child: _buildForm(context)),
              const SizedBox(height: Space.md),
              const _DeveloperCredit(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardArea(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _formWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FormCard(child: _buildForm(context)),
              const SizedBox(height: Space.md),
              const _DeveloperCredit(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final expired =
                    state is AuthUnauthenticated && state.expired;
                return expired
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: Space.md),
                        child: _SessionExpiredBanner(),
                      )
                    : const SizedBox.shrink();
              },
            ),
            SectionHeader(
              icon: Icons.shield_outlined,
              title: l10n.loginOperatorAccess,
              subtitle: l10n.loginHelper,
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _usernameController,
              autofocus: kIsWeb,
              decoration: InputDecoration(
                labelText: l10n.loginUsername,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: _required,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _pinController,
              obscureText: !_showPin,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.loginPin,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _showPin ? l10n.loginHidePin : l10n.loginShowPin,
                  icon: Icon(
                    _showPin
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _showPin = !_showPin),
                ),
              ),
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: _pin,
            ),
            const SizedBox(height: Space.lg),
            _SubmitSection(onSubmit: _submit),
            const SizedBox(height: Space.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Space.xs),
                Text(
                  l10n.loginSecure,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bordered surface shared by both layouts so the form keeps one geometry.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: child,
      ),
    );
  }
}

/// Wide-screen brand panel: identity, tagline and the three jobs of the app.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final onPanel = scheme.onPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.alphaBlend(scheme.primary.withValues(alpha: 0.72), scheme.surface),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Logo(size: 64, background: scheme.surface),
            const Spacer(),
            Semantics(
              header: true,
              child: Builder(
                builder: (context) => Text(
                  context.read<BrandingCubit>().state.titleFor(l10n),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: onPanel,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              l10n.loginSubtitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onPanel.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: Space.xl),
            _Feature(icon: Icons.login, label: l10n.loginFeatureCheckIn),
            _Feature(icon: Icons.point_of_sale, label: l10n.loginFeatureCash),
            _Feature(icon: Icons.insights_outlined, label: l10n.loginFeatureReports),
            const Spacer(),
            Text(
              l10n.appTitle,
              style: theme.textTheme.labelMedium?.copyWith(
                color: onPanel.withValues(alpha: 0.75),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact brand header for phones (no space for the split panel).
class _InlineBrand extends StatelessWidget {
  const _InlineBrand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return BlocBuilder<BrandingCubit, BrandingState>(
      builder: (context, branding) => Column(
        children: [
          _Logo(size: 64, background: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(height: Space.md),
          Semantics(
            header: true,
            child: Text(
              branding.titleFor(l10n),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            l10n.loginSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size, required this.background});

  final double size;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<BrandingCubit, BrandingState>(
      builder: (context, branding) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: switch (branding.logoOrNull) {
          final bytes? => Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.local_parking_rounded,
              size: size * 0.6,
              color: theme.colorScheme.primary,
            ),
          ),
          null => Image.asset(
            'assets/branding/logo.png',
            fit: BoxFit.contain,
            semanticLabel: context.l10n.appTitle,
            errorBuilder: (_, _, _) => Icon(
              Icons.local_parking_rounded,
              size: size * 0.6,
              color: theme.colorScheme.primary,
            ),
          ),
        },
      ),
    );
  }
}

/// Shown when the token was rejected mid-session (401), so the operator knows
/// why the app returned to the login screen.
class _SessionExpiredBanner extends StatelessWidget {
  const _SessionExpiredBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_clock, color: scheme.onTertiaryContainer),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                context.l10n.loginSessionExpired,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Authorship notice: a link to the developer page plus the rights line.
class _DeveloperCredit extends StatelessWidget {
  const _DeveloperCredit();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        TextButton.icon(
          onPressed: () => context.push(aboutPath),
          icon: const Icon(Icons.code, size: 18),
          label: Text(context.l10n.aboutMadeBy),
        ),
        Text(
          context.l10n.aboutRights,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Device preferences stay reachable before signing in.
class _CornerActions extends StatelessWidget {
  const _CornerActions();

  static bool _has<T>(BuildContext context) {
    try {
      context.read<T>();
      return true;
    } on ProviderNotFoundException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = _has<LocaleCubit>(context);
    final theme = _has<ThemeCubit>(context);
    if (!language && !theme) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (language) const LanguageButton(),
        if (theme) const ThemeModeButton(),
      ],
    );
  }
}

class _SubmitSection extends StatelessWidget {
  const _SubmitSection({required this.onSubmit});

  final VoidCallback onSubmit;

  static const _spinnerSize = 24.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final loading = state is AuthLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Layout.minTouch),
              child: FilledButton(
                onPressed: loading ? null : onSubmit,
                child: loading
                    ? SizedBox.square(
                        dimension: _spinnerSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: context.l10n.loading,
                        ),
                      )
                    : Text(context.l10n.loginSubmit),
              ),
            ),
            if (state is AuthFailure) ...[
              const SizedBox(height: Space.md),
              _ErrorBanner(_message(context, state)),
            ],
          ],
        );
      },
    );
  }

  String _message(BuildContext context, AuthFailure state) {
    final failure = state.failure;
    return failure == null
        ? context.l10n.loginFailed
        : context.l10n.failure(failure);
  }
}

/// Inline error surface: explicit icon, high contrast and a live region so a
/// screen reader announces the rejected login.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
