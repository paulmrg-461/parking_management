import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/submission_feedback.dart';

/// Opens one of the developer links; injectable so widget tests never leave
/// the process. Returns `false` when the platform could not open it.
typedef AboutLinkLauncher = Future<bool> Function(Uri uri);

/// Public "about the developer" page: DevPaul identity, the app summary and
/// the contact links, with the authorship notice in three places (hero chip,
/// app card footer and page footer).
class AboutDeveloperPage extends StatelessWidget {
  const AboutDeveloperPage({super.key, this.launch});

  /// Test seam; real builds use `url_launcher`.
  final AboutLinkLauncher? launch;

  static const _version = String.fromEnvironment(
    'FLUTTER_BUILD_NAME',
    defaultValue: '1.0.0',
  );
  static const _build = String.fromEnvironment(
    'FLUTTER_BUILD_NUMBER',
    defaultValue: '1',
  );

  static const _devpaul = 'https://devpaul.pro';
  static const _github = 'https://github.com/paulmrg-461';
  static const _linkedin = 'https://www.linkedin.com/in/paul-realpe-631b17a6/';
  static const _instagram = 'https://www.instagram.com/devpaul_co/';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutDeveloper)),
      body: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Hero(version: _version, buildNumber: _build),
                  const SizedBox(height: Space.lg),
                  _LinkCard(
                    links: [
                      _AboutLink(Icons.language, l10n.aboutWebsite, _devpaul),
                      _AboutLink(Icons.code, l10n.aboutGitHub, _github),
                      _AboutLink(Icons.work_outline, l10n.aboutLinkedIn, _linkedin),
                      _AboutLink(
                        Icons.camera_alt_outlined,
                        l10n.aboutInstagram,
                        _instagram,
                      ),
                    ],
                    onOpen: (uri) => _open(context, uri),
                  ),
                  const SizedBox(height: Space.lg),
                  SectionHeader(
                    icon: Icons.info_outline,
                    title: l10n.aboutAppTitle,
                  ),
                  const SizedBox(height: Space.sm),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(Radii.sm),
                                ),
                                child: Icon(
                                  Icons.local_parking_rounded,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.appTitle,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      l10n.aboutVersion('$_version ($_build)'),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Space.md),
                          Text(
                            l10n.aboutAppBody,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: Space.md),
                          Divider(color: scheme.outlineVariant),
                          const SizedBox(height: Space.sm),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: Space.xs),
                              Text(
                                l10n.aboutMadeBy,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  Text(
                    l10n.aboutMadeBy,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    l10n.aboutRights,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      final launcher = launch ?? _defaultLaunch;
      ok = await launcher(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      showErrorSnack(context, context.l10n.aboutOpenError);
    }
  }

  Future<bool> _defaultLaunch(Uri uri) async {
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _AboutLink {
  const _AboutLink(this.icon, this.label, this.url);

  final IconData icon;
  final String label;
  final String url;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer,
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.08),
                scheme.surface,
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            children: [
              Container(
                width: 132,
                height: 132,
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Image.asset(
                    'assets/branding/devpaul.png',
                    fit: BoxFit.contain,
                    semanticLabel: l10n.aboutLogoLabel,
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                'DevPaul',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                'Paul Realpe · ${l10n.aboutRole}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.md),
              StatusChip(
                label: l10n.aboutMadeBy,
                tone: StatusTone.success,
                icon: Icons.verified_outlined,
              ),
              const SizedBox(height: Space.md),
              Text(
                l10n.aboutIntro,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: Space.xs),
              Text(
                l10n.aboutVersion('$version ($buildNumber)'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.links, required this.onOpen});

  final List<_AboutLink> links;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(icon: Icons.link, title: l10n.aboutFindMe),
        const SizedBox(height: Space.sm),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < links.length; index++) ...[
                if (index > 0) Divider(height: 1, color: scheme.outlineVariant),
                ListTile(
                  leading: Icon(links[index].icon, size: 20),
                  title: Text(links[index].label),
                  subtitle: Text(
                    Uri.parse(links[index].url).host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () => onOpen(Uri.parse(links[index].url)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
