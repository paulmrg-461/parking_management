import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/app_url.dart';
import '../../../core/widgets/dialog_header.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../domain/entities/merchant.dart';

/// Shows the token link and the PIN exactly once (they are unrecoverable).
Future<void> showMerchantCredentialsDialog(
  BuildContext context,
  MerchantCredentials credentials,
) => showDialog<void>(
  context: context,
  builder: (_) => _CredentialsDialog(credentials: credentials),
);

class _CredentialsDialog extends StatelessWidget {
  const _CredentialsDialog({required this.credentials});

  final MerchantCredentials credentials;

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    showInfoSnack(context, context.l10n.merchantCredentialsCopy);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = appBaseUri();
    final link = credentials.linkFor(base);
    final path = credentials.linkPath ?? '';
    return AlertDialog(
      title: DialogHeader(
        icon: Icons.key_outlined,
        title: l10n.merchantCredentialsTitle,
        subtitle: l10n.merchantCredentialsHint,
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (credentials.token != null) ...[
              _Row(
                label: l10n.merchantCredentialsLink,
                value: link?.toString() ?? path,
                onCopy: () =>
                    _copy(context, link?.toString() ?? path),
              ),
              if (link == null)
                Text(
                  l10n.merchantCredentialsNoAppUrl(path),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: Space.md),
            ],
            _Row(
              label: l10n.merchantCredentialsPin,
              value: credentials.pin,
              onCopy: () => _copy(context, credentials.pin),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.merchantCredentialsCopy,
              onPressed: onCopy,
              icon: const Icon(Icons.copy_all_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
