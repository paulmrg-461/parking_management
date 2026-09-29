import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../settings/application/branding_cubit.dart';
import '../application/auth_cubit.dart';

/// Sign-in form: validated, autofill-friendly, Enter submits (web), the
/// button shows progress and errors are announced as a live region.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _maxWidth = 400.0;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: _buildForm(context),
              ),
            ),
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
            const _Header(),
            const SizedBox(height: Space.xl),
            TextFormField(
              controller: _usernameController,
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
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.loginPin,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: _required,
            ),
            const SizedBox(height: Space.lg),
            _SubmitSection(onSubmit: _submit),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<BrandingCubit, BrandingState>(
      builder: (context, branding) => Column(
        children: [
          if (branding.logoOrNull case final bytes?)
            ClipRRect(
              borderRadius: BorderRadius.circular(Space.sm),
              child: Image.memory(
                bytes,
                width: Space.xxl,
                height: Space.xxl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.local_parking_rounded,
                  size: Space.xxl,
                  color: theme.colorScheme.primary,
                ),
              ),
            )
          else
            Icon(
              Icons.local_parking_rounded,
              size: Space.xxl,
              color: theme.colorScheme.primary,
            ),
          const SizedBox(height: Space.md),
          Semantics(
            header: true,
            child: Text(
              branding.titleFor(context.l10n),
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            context.l10n.loginSubtitle,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
            FilledButton(
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
            if (state is AuthFailure) ...[
              const SizedBox(height: Space.md),
              _ErrorText(_message(context, state)),
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

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.error),
      ),
    );
  }
}
