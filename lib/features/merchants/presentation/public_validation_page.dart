import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/qr/qr_decoder.dart';
import '../../../core/qr/qr_scan_page.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/plate_input_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../plate_scanning/domain/repositories/plate_image_capture.dart';
import '../application/merchant_validation_cubit.dart';
import '../domain/entities/merchant.dart';
import '../domain/entities/merchant_portal.dart';

/// Public merchant page opened by the shop's link (`/validate?m=<token>`).
/// The token is the access key; the PIN is the merchant's proof.
class PublicValidationPage extends StatefulWidget {
  const PublicValidationPage({
    super.key,
    this.token,
    this.qrDecoder,
    this.capture,
    this.scanQr,
  });

  final String? token;

  /// Web scan seam (camera + decode); hidden when absent.
  final QrDecoder? qrDecoder;
  final PlateImageCapture? capture;

  /// Test seam; defaults to the live camera scanner.
  final Future<String?> Function(BuildContext context)? scanQr;

  @override
  State<PublicValidationPage> createState() => _PublicValidationPageState();
}

class _PublicValidationPageState extends State<PublicValidationPage> {
  final _plate = TextEditingController();
  final _pin = TextEditingController();
  String? _localError;

  String get _token => (widget.token ?? '').trim();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _plate.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_token.length != 48) {
      return;
    }
    await context.read<MerchantValidationCubit>().load(_token);
  }

  Future<void> _scan() async {
    final payload =
        await (widget.scanQr?.call(context) ?? scanQrWithCamera(context));
    if (payload == null || !mounted) {
      return;
    }
    final plate = plateFromQrPayload(payload);
    if (plate == null) {
      setState(() => _localError = context.l10n.checkOutQrUnreadable);
      return;
    }
    setState(() {
      _plate.text = plate;
      _localError = null;
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final plate = _plate.text.trim();
    final pin = _pin.text.trim();
    if (plate.length < 3) {
      setState(() => _localError = l10n.errorEmptyPlate);
      return;
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(pin)) {
      setState(() => _localError = l10n.validatePinLabel);
      return;
    }
    setState(() => _localError = null);
    await context.read<MerchantValidationCubit>().submit(
      pin: pin,
      plate: plate,
    );
  }

  bool get _canScan =>
      widget.scanQr != null ||
      (widget.capture != null && widget.qrDecoder != null);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_token.length != 48) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.validateTitle)),
        body: Center(
          child: EmptyState(
            message: l10n.validateInvalidLink,
            icon: Icons.link_off,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.validateTitle)),
      body: BlocBuilder<MerchantValidationCubit, MerchantValidationState>(
        builder: (context, state) => switch (state) {
          MerchantValidationInitial() ||
          MerchantValidationLoading() => const SkeletonCardList(itemCount: 2),
          MerchantValidationInvalidLink() => Center(
            child: EmptyState(
              message: l10n.validateInvalidLink,
              icon: Icons.link_off,
            ),
          ),
          MerchantValidationFailure(:final failure) => Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: ErrorState(
              message: l10n.failure(failure),
              onRetry: () => unawaited(_load()),
            ),
          ),
          MerchantValidationReady(
            :final portal,
            :final submitting,
            :final attemptsLeft,
            :final lockedUntil,
            :final actionFailure,
          ) => _Form(
            portal: portal,
            plate: _plate,
            pin: _pin,
            submitting: submitting,
            attemptsLeft: attemptsLeft,
            lockedUntil: lockedUntil,
            actionFailure: actionFailure,
            localError: _localError,
            canScan: _canScan,
            onScan: () => unawaited(_scan()),
            onSubmit: submitting || lockedUntil != null ? null : _submit,
          ),
          MerchantValidationDone(:final portal) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    l10n.validateSuccess(_benefit(l10n, portal)),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Space.lg),
                  FilledButton(
                    key: const Key('validate_another'),
                    onPressed: () {
                      _plate.clear();
                      _pin.clear();
                      context.read<MerchantValidationCubit>().another();
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l10n.validateAnother),
                  ),
                ],
              ),
            ),
          ),
        },
      ),
    );
  }

  static String _benefit(AppLocalizations l10n, MerchantPortal portal) =>
      switch (portal.kind) {
        MerchantBenefitKind.freeMinutes =>
          l10n.validateBenefitMinutes(portal.value),
        MerchantBenefitKind.percentage =>
          l10n.validateBenefitPercent(portal.value),
        MerchantBenefitKind.fixedAmount =>
          l10n.validateBenefitAmount(Money.format(portal.value)),
      };
}

class _Form extends StatelessWidget {
  const _Form({
    required this.portal,
    required this.plate,
    required this.pin,
    required this.submitting,
    required this.attemptsLeft,
    required this.lockedUntil,
    required this.actionFailure,
    required this.localError,
    required this.canScan,
    required this.onScan,
    required this.onSubmit,
  });

  final MerchantPortal portal;
  final TextEditingController plate;
  final TextEditingController pin;
  final bool submitting;
  final int? attemptsLeft;
  final DateTime? lockedUntil;
  final Failure? actionFailure;
  final String? localError;
  final bool canScan;
  final VoidCallback onScan;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locked = lockedUntil != null;
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(portal.merchantName, style: theme.textTheme.titleMedium),
                Text(portal.lotName, style: theme.textTheme.bodySmall),
                const SizedBox(height: Space.sm),
                Text(
                  switch (portal.kind) {
                    MerchantBenefitKind.freeMinutes =>
                      l10n.validateBenefitMinutes(portal.value),
                    MerchantBenefitKind.percentage =>
                      l10n.validateBenefitPercent(portal.value),
                    MerchantBenefitKind.fixedAmount =>
                      l10n.validateBenefitAmount(Money.format(portal.value)),
                  },
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        PlateInputField(
          controller: plate,
          label: l10n.validatePlateLabel,
          onScan: canScan ? onScan : null,
          onSubmitted: (_) => onSubmit?.call(),
        ),
        const SizedBox(height: Space.md),
        TextField(
          key: const Key('validate_pin'),
          controller: pin,
          enabled: !locked,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          autofillHints: const [],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.validatePinLabel,
            counterText: '',
          ),
          onSubmitted: (_) => onSubmit?.call(),
        ),
        if (locked) ...[
          const SizedBox(height: Space.sm),
          Text(
            l10n.validateLocked(Formatters.time(lockedUntil!)),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        if (!locked && attemptsLeft != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            l10n.validateWrongPin(attemptsLeft!),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        if (localError != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            localError!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        if (actionFailure != null) ...[
          const SizedBox(height: Space.md),
          ErrorState(
            message: l10n.errorText(
              actionFailure!.message,
              actionFailure,
            ),
            onRetry: () => onSubmit?.call(),
          ),
        ],
        const SizedBox(height: Space.lg),
        FilledButton(
          key: const Key('validate_submit'),
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.validateSubmit),
        ),
      ],
    );
  }
}
