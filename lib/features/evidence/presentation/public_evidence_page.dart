import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/plate_text.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/evidence_cubit.dart';
import '../domain/entities/public_evidence.dart';

/// Public, plate-keyed evidence page opened by the QR/link on the receipt.
/// No login: the link carries the session and the plate is the access key.
class PublicEvidencePage extends StatefulWidget {
  const PublicEvidencePage({super.key, this.sessionId, this.plate});

  final int? sessionId;
  final String? plate;

  @override
  State<PublicEvidencePage> createState() => _PublicEvidencePageState();
}

class _PublicEvidencePageState extends State<PublicEvidencePage> {
  final _plate = TextEditingController();
  String? _key;

  @override
  void initState() {
    super.initState();
    _key = widget.plate;
    if ((_key ?? '').trim().isNotEmpty) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _load() => context.read<EvidenceCubit>().load(
    sessionId: widget.sessionId,
    plate: _key,
  );

  void _unlock() {
    final plate = _plate.text.trim().toUpperCase();
    if (plate.isEmpty) {
      return;
    }
    setState(() => _key = plate);
    unawaited(_load());
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.evidenceTitle)),
      body: BlocBuilder<EvidenceCubit, EvidenceState>(
        builder: (context, state) {
          if ((_key ?? '').trim().isEmpty) {
            return _PlateGate(
              sessionInvalid: widget.sessionId == null || widget.sessionId! <= 0,
              controller: _plate,
              onUnlock: _unlock,
            );
          }
          return switch (state.status) {
          EvidenceStatus.initial ||
          EvidenceStatus.loading => const SkeletonCardList(itemCount: 3),
          EvidenceStatus.failure => Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ErrorState(
                  message: l10n.evidenceInvalid,
                  onRetry: () => unawaited(_load()),
                ),
              ],
            ),
          ),
            EvidenceStatus.loaded => _EvidenceBody(
              evidence: state.evidence!,
              onOpen: _open,
            ),
          };
        },
      ),
    );
  }
}

class _PlateGate extends StatelessWidget {
  const _PlateGate({
    required this.sessionInvalid,
    required this.controller,
    required this.onUnlock,
  });

  final bool sessionInvalid;
  final TextEditingController controller;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
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
                        Icons.lock_outline,
                        size: Space.xl,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    l10n.evidenceGateTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    l10n.evidenceGateHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  if (sessionInvalid)
                    Text(
                      l10n.evidenceInvalid,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    )
                  else ...[
                    TextField(
                      key: const Key('evidence_plate'),
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => onUnlock(),
                      decoration: InputDecoration(
                        labelText: l10n.plateLabel,
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: Layout.minTouch,
                      ),
                      child: FilledButton.icon(
                        key: const Key('evidence_unlock'),
                        onPressed: onUnlock,
                        icon: const Icon(Icons.lock_open),
                        label: Text(l10n.evidenceUnlock),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceBody extends StatelessWidget {
  const _EvidenceBody({required this.evidence, required this.onOpen});

  final PublicEvidence evidence;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 700 ? 4 : 2;
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PlateText(evidence.plate),
                    const Spacer(),
                    StatusChip(
                      label: evidence.exitTime == null
                          ? l10n.statusOpen
                          : l10n.statusClosed,
                      tone: evidence.exitTime == null
                          ? StatusTone.warning
                          : StatusTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  l10n.evidenceKey(evidence.plate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  evidence.exitTime == null
                      ? l10n.evidenceEntry(
                          Formatters.dateTime(evidence.entryTime),
                        )
                      : '${l10n.evidenceEntry(Formatters.dateTime(evidence.entryTime))} — '
                            '${Formatters.dateTime(evidence.exitTime!)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        if (evidence.isEmpty)
          EmptyState(
            message: l10n.evidenceEmpty,
            icon: Icons.photo_library_outlined,
          )
        else ...[
          Text(
            l10n.evidencePhotos(evidence.photos.length),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: Space.sm),
          if (evidence.photos.isEmpty)
            Text(l10n.evidenceNoPhotos, style: theme.textTheme.bodySmall),
          if (evidence.photos.isNotEmpty)
            GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Space.sm,
              crossAxisSpacing: Space.sm,
              children: [
                for (final photo in evidence.photos)
                  _PhotoTile(
                    media: photo,
                    onTap: () => onOpen(photo.url),
                  ),
              ],
            ),
          if (evidence.videos.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Text(
              l10n.evidenceVideos(evidence.videos.length),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: Space.sm),
            for (final video in evidence.videos)
              Card(
                margin: const EdgeInsets.only(bottom: Space.sm),
                child: ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: Text(l10n.evidencePlayVideo),
                  subtitle: Text(
                    [
                      Formatters.dateTime(video.takenAt),
                      if (video.duration case final duration?)
                        Formatters.duration(context.l10n, duration),
                    ].join(' · '),
                  ),
                  onTap: () => onOpen(video.url),
                ),
              ),
          ],
        ],
        if (evidence.lotId case final lotId?) ...[
          const SizedBox(height: Space.md),
          OutlinedButton.icon(
            key: const Key('evidence_policies'),
            onPressed: () => context.push('/policies?lot=$lotId'),
            icon: const Icon(Icons.gavel_outlined),
            label: Text(l10n.evidenceOpenPolicies),
          ),
        ],
        const SizedBox(height: Space.lg),
        Text(
          l10n.evidenceHelp,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.media, required this.onTap});

  final EvidenceMedia media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Material(
        color: scheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Image.network(
            media.url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (_, _, _) => Icon(
              Icons.broken_image_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
