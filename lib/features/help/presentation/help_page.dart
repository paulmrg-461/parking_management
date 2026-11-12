import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/section_header.dart';

class _HelpEntry {
  const _HelpEntry(this.title, this.body);

  final String title;
  final String body;
}

class _HelpSection {
  const _HelpSection(this.title, this.icon, this.entries);

  final String title;
  final IconData icon;
  final List<_HelpEntry> entries;
}

/// Operator help center: short, searchable how-tos for the daily flows.
/// Content is localized, so the same page works in Spanish and English.
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  String _query = '';

  List<_HelpSection> _sections(AppLocalizations l10n) => [
    _HelpSection(l10n.helpSectionStart, Icons.play_circle_outline, [
      _HelpEntry(l10n.helpOpenShiftTitle, l10n.helpOpenShiftBody),
      _HelpEntry(l10n.helpChargeTitle, l10n.helpChargeBody),
      _HelpEntry(l10n.helpReprintTitle, l10n.helpReprintBody),
    ]),
    _HelpSection(l10n.helpSectionCash, Icons.point_of_sale, [
      _HelpEntry(l10n.helpCloseShiftTitle, l10n.helpCloseShiftBody),
      _HelpEntry(l10n.helpMovementTitle, l10n.helpMovementBody),
    ]),
    _HelpSection(l10n.helpSectionVehicles, Icons.directions_car_outlined, [
      _HelpEntry(l10n.helpCheckInTitle, l10n.helpCheckInBody),
      _HelpEntry(l10n.helpReservationTitle, l10n.helpReservationBody),
      _HelpEntry(l10n.helpPassTitle, l10n.helpPassBody),
    ]),
    _HelpSection(l10n.helpSectionOffline, Icons.security_outlined, [
      _HelpEntry(l10n.helpOfflineTitle, l10n.helpOfflineBody),
      _HelpEntry(l10n.helpAutoLockTitle, l10n.helpAutoLockBody),
      _HelpEntry(l10n.helpUpdateTitle, l10n.helpUpdateBody),
    ]),
  ];

  List<_HelpSection> _filtered(AppLocalizations l10n) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) {
      return _sections(l10n);
    }
    return [
      for (final section in _sections(l10n))
        if ([
              for (final entry in section.entries)
                if (entry.title.toLowerCase().contains(needle) ||
                    entry.body.toLowerCase().contains(needle))
                  entry,
            ]
            case final entries when entries.isNotEmpty)
          _HelpSection(section.title, section.icon, entries),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = _filtered(l10n);
    final total = sections.fold<int>(
      0,
      (sum, section) => sum + section.entries.length,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: FilterBar(
              summary: _query.trim().isEmpty
                  ? l10n.helpIntro
                  : l10n.helpResults(total),
              children: [
                SizedBox(
                  width: 280,
                  child: SearchField(
                    key: const Key('help_search'),
                    label: l10n.helpSearchLabel,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: sections.isEmpty
                ? EmptyState(
                    icon: Icons.search_off,
                    message: l10n.helpNoResults,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Space.md,
                      0,
                      Space.md,
                      Space.xl,
                    ),
                    children: [
                      for (final section in sections) ...[
                        SectionHeader(icon: section.icon, title: section.title),
                        const SizedBox(height: Space.sm),
                        Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (
                                var i = 0;
                                i < section.entries.length;
                                i++
                              ) ...[
                                if (i > 0) const Divider(height: 1),
                                ExpansionTile(
                                  key: ValueKey(
                                    '${section.title}/${section.entries[i].title}',
                                  ),
                                  initiallyExpanded: _query.trim().isNotEmpty,
                                  title: Text(section.entries[i].title),
                                  childrenPadding: const EdgeInsets.fromLTRB(
                                    Space.md,
                                    0,
                                    Space.md,
                                    Space.md,
                                  ),
                                  expandedCrossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      section.entries[i].body,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(height: 1.5),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.lg),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
