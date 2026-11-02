import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/policy_template.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../application/policies_cubit.dart';
import '../domain/entities/lot_profile.dart';

/// Public page with the site's service contract / legal policy, linked from
/// the evidence page (no login; only identity, contact and the policy text).
class PoliciesPage extends StatefulWidget {
  const PoliciesPage({super.key, this.lotId});

  final int? lotId;

  @override
  State<PoliciesPage> createState() => _PoliciesPageState();
}

class _PoliciesPageState extends State<PoliciesPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<PoliciesCubit>().load(widget.lotId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.policiesTitle)),
      body: BlocBuilder<PoliciesCubit, PoliciesState>(
        builder: (context, state) => switch (state.status) {
          PoliciesStatus.initial ||
          PoliciesStatus.loading => const SkeletonCardList(itemCount: 3),
          PoliciesStatus.failure => ErrorState(
            message: l10n.policiesInvalid,
            onRetry: () =>
                unawaited(context.read<PoliciesCubit>().load(widget.lotId)),
          ),
          PoliciesStatus.loaded => _PoliciesBody(profile: state.profile!),
        },
      ),
    );
  }
}

class _PoliciesBody extends StatelessWidget {
  const _PoliciesBody({required this.profile});

  final LotProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final policy = renderPolicyTemplate(
      profile.legalPolicy,
      parking: profile.name,
      address: profile.address,
      schedule: profile.schedule,
      phone: profile.phone,
    ).trim();
    final lines = [
      for (final line in policy.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final heading = lines.isEmpty ? null : lines.first;
    final clauses = lines.length <= 1 ? const <String>[] : lines.skip(1).toList();
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Icon(
                        Icons.local_parking_rounded,
                        size: 30,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.policiesTitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (profile.address.isNotEmpty ||
                    profile.schedule.isNotEmpty ||
                    profile.phone.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  if (profile.address.isNotEmpty)
                    _ContactRow(
                      icon: Icons.place_outlined,
                      text: profile.address,
                    ),
                  if (profile.schedule.isNotEmpty)
                    _ContactRow(
                      icon: Icons.schedule_outlined,
                      text: profile.schedule,
                    ),
                  if (profile.phone.isNotEmpty)
                    _ContactRow(
                      icon: Icons.phone_outlined,
                      text: profile.phone,
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        if (policy.isEmpty)
          Text(l10n.policiesEmpty, style: theme.textTheme.bodyLarge)
        else ...[
          SectionHeader(
            icon: Icons.gavel_outlined,
            title: l10n.policiesTitle,
          ),
          const SizedBox(height: Space.sm),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (heading != null)
                    Text(
                      heading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (heading != null && clauses.isNotEmpty)
                    const SizedBox(height: Space.md),
                  for (var index = 0; index < clauses.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: SelectableText(
                              clauses[index],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Space.lg),
        Text(
          l10n.policiesHelp,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
