import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../public_booking/presentation/captcha/booking_captcha_field.dart';
import '../../public_booking/presentation/captcha/captcha_request.dart';
import '../application/public_waitlist_cubit.dart';
import '../domain/entities/public_waitlist.dart';
import '../domain/entities/waitlist_entry.dart';

/// Public waitlist card on `/reserve`: joins the queue when the lot (or a
/// category) is full and follows the customer's turn.
///
/// Renders nothing when the lot has the waitlist off, so a deployment that
/// never enables it looks exactly as before.
class PublicWaitlistCard extends StatefulWidget {
  const PublicWaitlistCard({
    super.key,
    required this.lotId,
    required this.fullCategories,
    this.initialCode,
    this.captchaSiteKey = '',
    this.captchaBuilder,
  });

  final int lotId;

  /// Categories without space, the first one preselected.
  final List<({int id, String name})> fullCategories;

  /// Deep-link code (`/reserve?lot=1&waitlist=42`), prefilled in the lookup.
  final int? initialCode;

  final String captchaSiteKey;
  final CaptchaBuilder? captchaBuilder;

  @override
  State<PublicWaitlistCard> createState() => _PublicWaitlistCardState();
}

class _PublicWaitlistCardState extends State<PublicWaitlistCard> {
  final _plate = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  int _waitHours = 3;
  int _holdHours = 1;
  String? _captchaToken;
  String? _captchaMessage;
  int _captchaEpoch = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _code.text = '${widget.initialCode}';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    final cubit = _maybeCubit(context);
    if (cubit != null && cubit.state is PublicWaitlistLoading) {
      cubit.load(widget.lotId);
    }
  }

  @override
  void dispose() {
    _plate.dispose();
    _name.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _captchaOn =>
      widget.captchaSiteKey.isNotEmpty && widget.captchaBuilder != null;

  /// The card is optional debt-free for callers that do not register the
  /// cubit (the booking page in a widget test): it renders nothing there.
  PublicWaitlistCubit? _maybeCubit(BuildContext context) {
    try {
      return context.read<PublicWaitlistCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _maybeCubit(context);
    if (cubit == null) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<PublicWaitlistCubit, PublicWaitlistState>(
      bloc: cubit,
      builder: (context, state) => switch (state) {
        PublicWaitlistLoading() => const _Skeleton(),
        PublicWaitlistUnavailable() => const SizedBox.shrink(),
        PublicWaitlistFailure(:final failure) => ErrorState(
          message: context.l10n.failure(failure),
          onRetry: () => context.read<PublicWaitlistCubit>().load(widget.lotId),
        ),
        final PublicWaitlistReady ready => _card(context, ready),
      },
    );
  }

  Widget _card(BuildContext context, PublicWaitlistReady ready) {
    final entry = ready.entry;
    return Container(
      margin: const EdgeInsets.only(top: Space.lg),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.waitlistJoinTitle,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Space.xs),
          if (ready.actionFailure case final failure?) ...[
            Text(
              context.l10n.failure(failure),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: Space.sm),
          ],
          if (ready.claimed != null)
            _claimed(context, ready)
          else if (entry == null)
            _form(context, ready)
          else
            _turn(context, ready, entry),
        ],
      ),
    );
  }

  Widget _claimed(BuildContext context, PublicWaitlistReady ready) {
    final reservation = ready.claimed!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.bookingSuccessTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: Space.xs),
        Text(
          '${reservation.plate} · ${reservation.categoryName} · '
          '${formatTime(reservation.reservedUntil)}',
        ),
      ],
    );
  }

  Widget _form(BuildContext context, PublicWaitlistReady ready) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.waitlistJoinHint,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: Space.sm),
        if (widget.fullCategories.isNotEmpty)
          Text(
            '${l10n.waitlistWaitingCount(ready.info.waitingFor(widget.fullCategories.first.id))} · '
            '${widget.fullCategories.first.name}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: Space.sm),
        TextField(
          key: const Key('waitlist-plate'),
          controller: _plate,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: l10n.plateLabel),
        ),
        const SizedBox(height: Space.sm),
        TextField(
          key: const Key('waitlist-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.bookingName),
        ),
        const SizedBox(height: Space.sm),
        TextField(
          key: const Key('waitlist-phone'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: l10n.bookingPhone),
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                key: const Key('waitlist-wait-hours'),
                initialValue: _waitHours,
                decoration: InputDecoration(labelText: l10n.waitlistWaitFor),
                items: [
                  for (final hours in const [1, 2, 3, 6, 12])
                    DropdownMenuItem(
                      value: hours,
                      child: Text(l10n.waitlistHoldHours(hours)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _waitHours = value ?? _waitHours),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                key: const Key('waitlist-hold-hours'),
                initialValue: _holdHours,
                decoration: InputDecoration(labelText: l10n.waitlistHoldFor),
                items: [
                  for (final hours in const [1, 2, 4, 8, 24])
                    DropdownMenuItem(
                      value: hours,
                      child: Text(l10n.waitlistHoldHours(hours)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _holdHours = value ?? _holdHours),
              ),
            ),
          ],
        ),
        if (_captchaOn) ...[
          const SizedBox(height: Space.sm),
          BookingCaptchaField(
            captcha: KeyedSubtree(
              key: ValueKey(_captchaEpoch),
              child: widget.captchaBuilder!(
                context,
                CaptchaRequest(
                  siteKey: widget.captchaSiteKey,
                  onToken: (token) => setState(() {
                    _captchaToken = token;
                    _captchaMessage = null;
                  }),
                  onExpired: () => setState(() {
                    _captchaToken = null;
                    _captchaMessage = l10n.bookingCaptchaExpired;
                  }),
                  onError: () => setState(() {
                    _captchaToken = null;
                    _captchaMessage = l10n.bookingCaptchaFailed;
                  }),
                ),
              ),
            ),
            message: _captchaMessage,
            canRetry: _captchaMessage != null,
            onRetry: () => setState(() {
              _captchaToken = null;
              _captchaMessage = null;
              _captchaEpoch += 1;
            }),
          ),
        ],
        const SizedBox(height: Space.md),
        FilledButton.icon(
          key: const Key('waitlist-join'),
          onPressed: ready.submitting ? null : () => _join(context, ready),
          icon: const Icon(Icons.hourglass_top_outlined),
          label: Text(l10n.waitlistJoinAction),
        ),
        if (_code.text.isNotEmpty || widget.initialCode != null) ...[
          const SizedBox(height: Space.md),
          Text(l10n.waitlistLookupLabel),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('waitlist-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.waitlistLookupLabel,
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              OutlinedButton(
                onPressed: ready.submitting ? null : () => _lookup(context),
                child: Text(l10n.actionRetry),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _turn(
    BuildContext context,
    PublicWaitlistReady ready,
    PublicWaitlistEntry entry,
  ) {
    final l10n = context.l10n;
    if (entry.isFinished) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.waitlistExpiredTitle),
          const SizedBox(height: Space.xs),
          Text(l10n.waitlistExpiredHint),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.isOffered
              ? l10n.waitlistOfferTitle
              : entry.isClaimed
              ? l10n.waitlistJoined
              : l10n.waitlistJoined,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (entry.isOffered && entry.offerUntil != null)
          Text(l10n.waitlistOfferBody(formatTime(entry.offerUntil!))),
        if (entry.isWaiting) ...[
          Text(l10n.waitlistPosition(entry.position)),
          Text(l10n.waitlistCode(entry.id)),
          Text(
            entry.notifyChannel == WaitlistChannel.whatsapp
                ? l10n.waitlistNotifyWhatsapp
                : l10n.waitlistNotifyScreen,
          ),
          Text(l10n.waitlistKeepCode),
        ],
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          children: [
            if (entry.isOffered)
              FilledButton(
                key: const Key('waitlist-claim'),
                onPressed: ready.submitting
                    ? null
                    : () => context.read<PublicWaitlistCubit>().claim(),
                child: Text(l10n.waitlistClaim),
              ),
            if (!entry.isClaimed)
              TextButton(
                key: const Key('waitlist-leave'),
                onPressed: ready.submitting
                    ? null
                    : () => context.read<PublicWaitlistCubit>().leave(),
                child: Text(l10n.waitlistLeave),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _join(BuildContext context, PublicWaitlistReady ready) async {
    final category = widget.fullCategories.firstOrNull;
    if (category == null) {
      return;
    }
    final now = DateTime.now();
    await context.read<PublicWaitlistCubit>().join(
      plate: _plate.text.trim().toUpperCase(),
      categoryId: category.id,
      waitUntil: now.add(Duration(hours: _waitHours)),
      holdMinutes: _holdHours * 60,
      phone: _phone.text.trim(),
      name: _name.text.trim(),
      captchaToken: _captchaOn ? _captchaToken : null,
    );
    if (_captchaOn && mounted) {
      setState(() {
        _captchaToken = null;
        _captchaEpoch += 1;
      });
    }
  }

  Future<void> _lookup(BuildContext context) async {
    final code = int.tryParse(_code.text.trim());
    if (code == null) {
      return;
    }
    await context.read<PublicWaitlistCubit>().lookup(code, _phone.text.trim());
  }
}

/// `HH:mm` in the device zone (the page is the customer's).
String formatTime(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: Space.lg),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final width in const [180.0, 260.0, 120.0])
            Container(
              width: width,
              height: 14,
              margin: const EdgeInsets.only(bottom: Space.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
            ),
        ],
      ),
    );
  }
}
