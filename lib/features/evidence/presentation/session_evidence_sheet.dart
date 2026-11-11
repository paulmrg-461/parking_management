import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/di/injection.dart';
import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dialog_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/entities/session_evidence.dart';
import '../domain/repositories/session_evidence_repository.dart';

/// Opens the in-app evidence gallery of one session. [repository] is injectable
/// for widget tests; production resolves it from the service locator.
Future<void> showSessionEvidence(
  BuildContext context, {
  required int sessionId,
  required String plate,
  SessionEvidenceRepository? repository,
}) {
  final evidence =
      repository ??
      (serviceLocator.isRegistered<SessionEvidenceRepository>()
          ? serviceLocator<SessionEvidenceRepository>()
          : null);
  if (evidence == null) {
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SessionEvidenceSheet(
      sessionId: sessionId,
      plate: plate,
      repository: evidence,
    ),
  );
}

class SessionEvidenceSheet extends StatefulWidget {
  const SessionEvidenceSheet({
    super.key,
    required this.sessionId,
    required this.plate,
    required this.repository,
  });

  final int sessionId;
  final String plate;
  final SessionEvidenceRepository repository;

  @override
  State<SessionEvidenceSheet> createState() => _SessionEvidenceSheetState();
}

class _SessionEvidenceSheetState extends State<SessionEvidenceSheet> {
  late Future<List<SessionEvidence>> _items;

  @override
  void initState() {
    super.initState();
    _items = _load();
  }

  Future<List<SessionEvidence>> _load() =>
      widget.repository.listForSession(widget.sessionId);

  void _retry() {
    setState(() {
      _items = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.xs,
          Space.md,
          Space.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DialogHeader(
              icon: Icons.photo_library_outlined,
              title: l10n.sessionEvidenceTitle(widget.plate),
            ),
            const SizedBox(height: Space.md),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: 160, maxHeight: maxHeight),
              child: FutureBuilder<List<SessionEvidence>>(
                future: _items,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _EvidenceSkeleton();
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    return _EvidenceMessage(
                      icon: Icons.error_outline,
                      message: error is Failure
                          ? l10n.failure(error)
                          : l10n.errorUnknown,
                      action: TextButton(
                        onPressed: _retry,
                        child: Text(l10n.actionRetry),
                      ),
                    );
                  }
                  final items = snapshot.data ?? const <SessionEvidence>[];
                  if (items.isEmpty) {
                    return _EvidenceMessage(
                      icon: Icons.photo_outlined,
                      message: l10n.sessionEvidenceEmpty,
                    );
                  }
                  return GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: Space.sm,
                          crossAxisSpacing: Space.sm,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _EvidenceTile(evidence: items[index], index: index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceSkeleton extends StatelessWidget {
  const _EvidenceSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: Space.sm,
      crossAxisSpacing: Space.sm,
      children: [
        const SkeletonBox(height: 96, radius: Radii.sm),
        const SkeletonBox(height: 96, radius: Radii.sm),
        const SkeletonBox(height: 96, radius: Radii.sm),
        const SkeletonBox(height: 96, radius: Radii.sm),
        const SkeletonBox(height: 96, radius: Radii.sm),
        const SkeletonBox(height: 96, radius: Radii.sm),
      ],
    ),
  );
}

class _EvidenceMessage extends StatelessWidget {
  const _EvidenceMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: Space.sm),
          Text(message, textAlign: TextAlign.center),
          if (action case final action?) ...[
            const SizedBox(height: Space.sm),
            action,
          ],
        ],
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.evidence, required this.index});

  final SessionEvidence evidence;
  final int index;

  Future<void> _open(BuildContext context) async {
    final url = evidence.url;
    if (url == null || url.isEmpty) {
      return;
    }
    if (!evidence.isVideo) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(Space.md),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        showErrorSnack(context, context.l10n.sessionEvidenceOpenFailed);
      }
    } catch (_) {
      if (context.mounted) {
        showErrorSnack(context, context.l10n.sessionEvidenceOpenFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final semantic = evidence.isVideo
        ? l10n.sessionEvidenceVideoLabel(evidence.durationSeconds ?? 0)
        : l10n.sessionEvidencePhotoLabel(index + 1);
    return Semantics(
      button: evidence.isAvailable,
      label: semantic,
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: evidence.isAvailable ? () => _open(context) : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!evidence.isVideo && evidence.isAvailable)
                Image.network(
                  evidence.url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.broken_image_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else if (evidence.isVideo)
                Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 40,
                    color: scheme.primary,
                  ),
                )
              else
                Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              if (evidence.isVideo)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      l10n.sessionEvidenceDurationShort(
                        evidence.durationSeconds ?? 0,
                      ),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              if (!evidence.isAvailable)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Center(
                      child: Icon(
                        Icons.cloud_off_outlined,
                        color: scheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
