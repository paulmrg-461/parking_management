import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/maps_launcher.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/plate_input_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../settings/domain/whatsapp_url.dart';
import '../application/public_booking_cubit.dart';
import '../domain/entities/public_booking.dart';
import '../domain/phone_rules.dart';

/// Public, mobile-first customer page: the site's real availability and a
/// direct reservation, no account needed.
class PublicBookingPage extends StatefulWidget {
  const PublicBookingPage({
    super.key,
    required this.lotId,
    this.refreshInterval = const Duration(minutes: 1),
  });

  final int lotId;

  /// How often the availability is re-read while the form is open (`null`
  /// disables it, e.g. in tests).
  final Duration? refreshInterval;

  @override
  State<PublicBookingPage> createState() => _PublicBookingPageState();
}

class _PublicBookingPageState extends State<PublicBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  int? _categoryId;
  int _hours = 2;
  String? _categoryError;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<PublicBookingCubit>().load(widget.lotId));
    final interval = widget.refreshInterval;
    if (interval != null) {
      _refreshTimer = Timer.periodic(interval, (_) => _refreshAvailability());
    }
  }

  /// A customer may leave the page open while deciding; the numbers should
  /// not go stale, and a silent refresh never replaces the form with a
  /// skeleton (the screen they are reading stays put).
  void _refreshAvailability() {
    if (!mounted) {
      return;
    }
    final cubit = context.read<PublicBookingCubit>();
    final state = cubit.state;
    if (state.status != PublicBookingStatus.loaded ||
        state.submitting ||
        state.cancelling) {
      return;
    }
    unawaited(cubit.refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _plate.dispose();
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _cancel(
    BuildContext context,
    PublicReservation reservation,
  ) async {
    final confirmed = await _confirmCancel(context, reservation.plate);
    if (confirmed && context.mounted) {
      await context.read<PublicBookingCubit>().cancel();
    }
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final valid = _formKey.currentState?.validate() ?? false;
    if (_categoryId == null) {
      setState(() => _categoryError = l10n.bookingSelectCategory);
    }
    if (!valid || _categoryId == null) {
      return;
    }
    await context.read<PublicBookingCubit>().submit(
      plate: _plate.text.trim().toUpperCase(),
      categoryId: _categoryId!,
      hours: _hours,
      phone: normalizeMobilePhone(_phone.text) ?? _phone.text.trim(),
      name: _name.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<PublicBookingCubit, PublicBookingState>(
          builder: (context, state) => switch (state.status) {
            PublicBookingStatus.initial ||
            PublicBookingStatus.loading => const SkeletonCardList(itemCount: 3),
            PublicBookingStatus.failure => ErrorState(
              message: _errorText(l10n, state.failure),
              onRetry: () =>
                  context.read<PublicBookingCubit>().load(widget.lotId),
            ),
            PublicBookingStatus.loaded => _loaded(context, state, l10n),
          },
        ),
      ),
    );
  }

  Widget _loaded(
    BuildContext context,
    PublicBookingState state,
    AppLocalizations l10n,
  ) {
    if (state.cancelled) {
      return _Cancelled(onAnother: context.read<PublicBookingCubit>().reset);
    }
    final reservation = state.reservation;
    if (reservation != null) {
      return _Confirmation(
        reservation: reservation,
        cancelling: state.cancelling,
        error: state.actionFailure == null
            ? null
            : _errorText(l10n, state.actionFailure),
        onAnother: context.read<PublicBookingCubit>().reset,
        onCancel: () => _cancel(context, reservation),
      );
    }
    final availability = state.availability!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(Space.md),
          children: [
            _Hero(availability: availability),
            const SizedBox(height: Space.lg),
            SectionHeader(
              icon: Icons.event_available_outlined,
              title: l10n.bookingSectionAvailability,
              subtitle: l10n.bookingSectionHint,
              action: IconButton(
                tooltip: l10n.bookingRefresh,
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    context.read<PublicBookingCubit>().load(widget.lotId),
              ),
            ),
            const SizedBox(height: Space.sm),
            if (availability.categories.isEmpty)
              _Notice(icon: Icons.info_outline, message: l10n.bookingEmpty)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 620;
                  final width = wide
                      ? (constraints.maxWidth - Space.sm) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final category in availability.categories)
                        SizedBox(
                          width: width,
                          child: _CategoryCard(
                            category: category,
                            currency: availability.currency,
                            selected: _categoryId == category.id,
                            onSelect: category.isFull
                                ? null
                                : () => setState(() {
                                    _categoryId = category.id;
                                    _categoryError = null;
                                  }),
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (_categoryError != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  _categoryError!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: Space.lg),
            _FormCard(
              formKey: _formKey,
              plate: _plate,
              phone: _phone,
              name: _name,
              hours: _hours,
              submitting: state.submitting,
              error: state.actionFailure == null
                  ? null
                  : _errorText(l10n, state.actionFailure),
              onHours: (hours) => setState(() => _hours = hours),
              onSubmit: _submit,
              onPolicies: () => context.push('/policies?lot=${widget.lotId}'),
            ),
            const SizedBox(height: Space.lg),
            _LookupCard(
              loading: state.lookupLoading,
              done: state.lookupDone,
              result: state.lookupResult,
              error: state.lookupFailure == null
                  ? null
                  : _errorText(l10n, state.lookupFailure),
              cancelling: state.cancelling,
              onLookup: (code, phone) => context
                  .read<PublicBookingCubit>()
                  .lookup(code: code, phone: phone),
              onCancel: context.read<PublicBookingCubit>().cancelLookup,
            ),
            const SizedBox(height: Space.lg),
            Text(
              l10n.bookingFooter,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.md),
          ],
        ),
      ),
    );
  }
}

/// "Ya reservaste": retrieve an active hold with the code printed on the
/// confirmation plus the mobile used to book, and cancel it from here. Without
/// this the cancel action would only exist while the confirmation is open.
class _LookupCard extends StatefulWidget {
  const _LookupCard({
    required this.loading,
    required this.done,
    required this.result,
    required this.error,
    required this.cancelling,
    required this.onLookup,
    required this.onCancel,
  });

  final bool loading;
  final bool done;
  final PublicReservation? result;
  final String? error;
  final bool cancelling;
  final void Function(int code, String phone) onLookup;
  final VoidCallback onCancel;

  @override
  State<_LookupCard> createState() => _LookupCardState();
}

class _LookupCardState extends State<_LookupCard> {
  final _code = TextEditingController();
  final _phone = TextEditingController();
  String? _invalid;

  @override
  void dispose() {
    _code.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final code = int.tryParse(_code.text.trim());
    final phone = normalizeMobilePhone(_phone.text);
    if (code == null || code <= 0 || phone == null) {
      setState(() => _invalid = l10n.bookingLookupInvalid);
      return;
    }
    setState(() => _invalid = null);
    FocusScope.of(context).unfocus();
    widget.onLookup(code, phone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = widget.result;
    final error = widget.error ?? _invalid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.confirmation_number_outlined, color: scheme.primary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    l10n.bookingLookupTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              l10n.bookingLookupHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    key: const Key('booking_lookup_code'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.bookingLookupCode,
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: TextField(
                    key: const Key('booking_lookup_phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.bookingLookupPhone,
                      hintText: l10n.bookingPhoneHint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            FilledButton.tonalIcon(
              onPressed: widget.loading ? null : _submit,
              icon: widget.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(
                widget.loading
                    ? l10n.bookingLookupChecking
                    : l10n.bookingLookupAction,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(Layout.minTouch),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: Space.sm),
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.bookingLookupFound(result.plate),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusChip(
                          label: _categoryLabel(result.categoryName),
                          tone: StatusTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      '${l10n.bookingUntil} '
                      '${Formatters.dateTime(result.reservedUntil)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    TextButton.icon(
                      onPressed: widget.cancelling
                          ? null
                          : () async {
                              final confirmed = await _confirmCancel(
                                context,
                                result.plate,
                              );
                              if (confirmed) {
                                widget.onCancel();
                              }
                            },
                      icon: const Icon(Icons.event_busy_outlined),
                      label: Text(l10n.bookingCancel),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                        minimumSize: const Size(0, Layout.minTouch),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (widget.done) ...[
              const SizedBox(height: Space.sm),
              Text(
                l10n.bookingLookupNotFound,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.availability});

  final PublicBookingAvailability availability;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainerLow],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: availability.logoUrl == null
                      ? ColoredBox(
                          color: scheme.surface,
                          child: Icon(
                            Icons.local_parking,
                            size: 34,
                            color: scheme.primary,
                          ),
                        )
                      : Image.network(
                          availability.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: scheme.surface,
                            child: Icon(
                              Icons.local_parking,
                              size: 34,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      availability.lotName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (availability.address.isNotEmpty)
                      Text(
                        availability.address,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (availability.schedule.isNotEmpty)
                      Text(
                        availability.schedule,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          StatusChip(
            label: l10n.bookingOnline,
            tone: StatusTone.success,
            icon: Icons.bolt,
          ),
          const SizedBox(height: Space.sm),
          Text(
            l10n.bookingTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            l10n.bookingSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (availability.phone.isNotEmpty ||
              availability.whatsapp.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                if (availability.phone.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.call_outlined, size: 18),
                    label: Text(availability.phone),
                    onPressed: () => _call(availability.phone),
                  ),
                if (availability.whatsapp.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.chat_outlined, size: 18),
                    label: Text(l10n.bookingWhatsApp),
                    onPressed: () => openWhatsapp(
                      context,
                      whatsappUrl(
                        availability.whatsapp,
                        text: l10n.bookingWhatsAppMessage(availability.lotName),
                      ),
                    ),
                  ),
                if (availability.address.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.directions_outlined, size: 18),
                    label: Text(l10n.bookingDirections),
                    onPressed: () => openMaps(context, availability.address),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.currency,
    required this.selected,
    required this.onSelect,
  });

  final PublicCategoryAvailability category;
  final String currency;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);
    final full = category.isFull;
    final color = full
        ? scheme.error
        : category.isUnlimited
        ? status.success
        : status.success;
    final label = full
        ? l10n.bookingFull
        : category.isUnlimited
        ? l10n.bookingUnlimited
        : l10n.bookingAvailable(category.available ?? 0);
    final ratio = category.isUnlimited || category.capacity <= 0
        ? null
        : ((category.available ?? 0) / category.capacity).clamp(0.0, 1.0);
    final price = category.hasPrice
        ? l10n.bookingFromPrice(Money.formatAs(currency, category.hourlyAmount))
        : l10n.bookingPriceUndefined;
    final semantic = '${category.name}: $label. $price';
    return Semantics(
      button: onSelect != null,
      selected: selected,
      label: semantic,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _groupIcon(category.group),
                        color: scheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        _categoryLabel(category.name),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, color: scheme.primary),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  price,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (ratio != null) ...[
                  const SizedBox(height: Space.xs),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    color: full ? scheme.error : status.success,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.plate,
    required this.phone,
    required this.name,
    required this.hours,
    required this.submitting,
    required this.error,
    required this.onHours,
    required this.onSubmit,
    required this.onPolicies,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController plate;
  final TextEditingController phone;
  final TextEditingController name;
  final int hours;
  final bool submitting;
  final String? error;
  final ValueChanged<int> onHours;
  final VoidCallback onSubmit;
  final VoidCallback onPolicies;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, color: scheme.primary),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      l10n.bookingFormTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              PlateInputField(
                controller: plate,
                label: l10n.plateLabel,
                validator: (value) => (value ?? '').trim().length < 3
                    ? l10n.bookingErrorPlate
                    : null,
              ),
              const SizedBox(height: Space.sm),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: InputDecoration(
                  labelText: l10n.bookingPhone,
                  hintText: l10n.bookingPhoneHint,
                ),
                validator: (value) => normalizeMobilePhone(value ?? '') == null
                    ? l10n.bookingErrorPhone
                    : null,
              ),
              const SizedBox(height: Space.sm),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: l10n.bookingName,
                  counterText: '',
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? l10n.bookingErrorName : null,
              ),
              const SizedBox(height: Space.xs),
              Text(
                l10n.bookingDuration,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Space.xs),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  for (final value in const [1, 2, 4, 8])
                    ChoiceChip(
                      label: Text(l10n.bookingDurationHours(value)),
                      selected: hours == value,
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) => onHours(value),
                    ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: Space.sm),
                Container(
                  padding: const EdgeInsets.all(Space.sm),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: scheme.onErrorContainer,
                        size: 18,
                      ),
                      const SizedBox(width: Space.xs),
                      Expanded(
                        child: Text(
                          error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Space.md),
              FilledButton.icon(
                onPressed: submitting ? null : onSubmit,
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.event_available),
                label: Text(
                  submitting ? l10n.bookingSubmitting : l10n.bookingSubmit,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: Space.xs),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.bookingLegal,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: onPolicies,
                    child: Text(l10n.bookingPolicies),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The customer freed the space: thank them and offer a new booking.
class _Cancelled extends StatelessWidget {
  const _Cancelled({required this.onAnother});

  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            const SizedBox(height: Space.xxl),
            Icon(Icons.event_busy_outlined, size: 72, color: scheme.primary),
            const SizedBox(height: Space.md),
            Text(
              l10n.bookingCancelledTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              l10n.bookingCancelledHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.lg),
            FilledButton.icon(
              onPressed: onAnother,
              icon: const Icon(Icons.add),
              label: Text(l10n.bookingAnother),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({
    required this.reservation,
    required this.cancelling,
    required this.error,
    required this.onAnother,
    required this.onCancel,
  });

  final PublicReservation reservation;
  final bool cancelling;
  final String? error;
  final VoidCallback onAnother;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(Space.md),
          children: [
            const SizedBox(height: Space.xl),
            Icon(Icons.check_circle, size: 72, color: status.success),
            const SizedBox(height: Space.md),
            Text(
              l10n.bookingSuccessTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              l10n.bookingSuccessHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.bookingCode,
                          style: theme.textTheme.labelMedium,
                        ),
                        const Spacer(),
                        StatusChip(
                          label: '#${reservation.id}',
                          tone: StatusTone.success,
                        ),
                      ],
                    ),
                    const Divider(height: Space.lg),
                    _DetailRow(
                      label: l10n.bookingPlateDetail,
                      value: reservation.plate,
                    ),
                    _DetailRow(
                      label: l10n.bookingCategoryDetail,
                      value: _categoryLabel(reservation.categoryName),
                    ),
                    _DetailRow(
                      label: l10n.bookingUntil,
                      value: Formatters.dateTime(reservation.reservedUntil),
                    ),
                    if (reservation.address.isNotEmpty)
                      _DetailRow(
                        label: l10n.bookingAddress,
                        value: reservation.address,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            if (reservation.phone.isNotEmpty || reservation.whatsapp.isNotEmpty)
              Row(
                children: [
                  if (reservation.phone.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _call(reservation.phone),
                        icon: const Icon(Icons.call_outlined),
                        label: Text(l10n.bookingCall),
                      ),
                    ),
                  if (reservation.phone.isNotEmpty &&
                      reservation.whatsapp.isNotEmpty)
                    const SizedBox(width: Space.sm),
                  if (reservation.whatsapp.isNotEmpty)
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => openWhatsapp(
                          context,
                          whatsappUrl(
                            reservation.whatsapp,
                            text: l10n.bookingWhatsAppMessage(
                              reservation.lotName,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.chat_outlined),
                        label: Text(l10n.bookingWhatsApp),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: Space.md),
            TextButton.icon(
              onPressed: onAnother,
              icon: const Icon(Icons.add),
              label: Text(l10n.bookingAnother),
            ),
            if (error != null) ...[
              const SizedBox(height: Space.sm),
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(
                        error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Space.sm),
            TextButton.icon(
              onPressed: cancelling ? null : onCancel,
              icon: cancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_busy_outlined),
              label: Text(l10n.bookingCancel),
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
                minimumSize: const Size(0, Layout.minTouch),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

IconData _groupIcon(String group) => switch (group) {
  'car' => Icons.directions_car_outlined,
  'moto' => Icons.two_wheeler_outlined,
  _ => Icons.local_shipping_outlined,
};

String _categoryLabel(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '—';
  }
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

Future<void> _call(String phone) async {
  final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) {
    return;
  }
  try {
    await launchUrl(Uri.parse('tel:$digits'));
  } catch (_) {
    // A device without a dialer simply does nothing.
  }
}

/// One dialog for both cancel paths (confirmation screen and lookup).
Future<bool> _confirmCancel(BuildContext context, String plate) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.bookingCancelTitle),
      content: Text(l10n.bookingCancelBody(plate)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.bookingCancel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

String _errorText(AppLocalizations l10n, Failure? failure) {
  if (failure == null) {
    return l10n.errorUnknown;
  }
  return switch (failure.code) {
    'CategoryFullError' || 'ParkingFullError' => l10n.bookingErrorFull,
    'ReservationExistsError' => l10n.bookingErrorExists,
    'ReservationLimitError' => l10n.bookingErrorLimit,
    'ReservationNotFoundError' => l10n.bookingErrorNotFound,
    'VehicleAlreadyInsideError' => l10n.bookingErrorInside,
    'InvalidReservationWindowError' => l10n.bookingErrorWindow,
    'InvalidPhoneError' => l10n.bookingErrorPhone,
    'InvalidNameError' => l10n.bookingErrorName,
    'InvalidPlateError' => l10n.bookingErrorPlate,
    'LotNotFoundError' => l10n.bookingErrorLot,
    _ => l10n.failure(failure),
  };
}
