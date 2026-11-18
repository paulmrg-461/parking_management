import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/devices_cubit.dart';
import '../domain/entities/lot_device.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<DevicesCubit>().load());
  }

  Future<void> _register() async {
    final result = await showDialog<({DeviceKind kind, String name})>(
      context: context,
      builder: (_) => const _DeviceDialog(),
    );
    if (result == null || !mounted) return;
    final device = await context.read<DevicesCubit>().register(
      result.kind,
      result.name,
    );
    if (device != null && mounted) await _showKey(device);
  }

  Future<void> _rotate(LotDevice device) async {
    final rotated = await context.read<DevicesCubit>().rotate(device.id);
    if (rotated != null && mounted) await _showKey(rotated);
  }

  Future<void> _showKey(LotDevice device) async {
    final key = device.apiKey;
    if (key == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('device_key_dialog'),
        title: Text(context.l10n.devicesKeyTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(key),
            const SizedBox(height: Space.sm),
            Text(context.l10n.devicesKeyHint),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('device_key_copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key));
              if (context.mounted) {
                showInfoSnack(context, context.l10n.devicesCopied);
              }
            },
            child: Text(context.l10n.devicesCopied),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.actionClose),
          ),
        ],
      ),
    );
  }

  Future<void> _events(LotDevice device) async {
    final events = await context.read<DevicesCubit>().events(device.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          Text(context.l10n.devicesEvents,
              style: Theme.of(context).textTheme.titleMedium),
          for (final event in events)
            ListTile(
              dense: true,
              title: Text(event.event),
              subtitle: Text(event.createdAt?.toString() ?? ''),
            ),
        ],
      ),
    );
  }

  Future<void> _rename(LotDevice device) async {
    final controller = TextEditingController(text: device.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        key: Key('device_rename_${device.id}'),
        title: Text(context.l10n.devicesRename),
        content: TextField(
          key: Key('device_rename_field_${device.id}'),
          controller: controller,
          maxLength: 60,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            key: Key('device_rename_save_${device.id}'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.actionSave),
          ),
        ],
      ),
    );
    if (name == null || name == device.name) return;
    await context.read<DevicesCubit>().rename(device, name);
  }

  Future<void> _delete(LotDevice device) async {
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: context.l10n.devicesDeleteConfirm,
        body: device.name,
        confirmLabel: context.l10n.devicesDelete,
        destructive: true,
      ),
    );
    if (confirmed && mounted) {
      await context.read<DevicesCubit>().delete(device.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('devices_add'),
        onPressed: _register,
        icon: const Icon(Icons.add),
        label: Text(l10n.devicesAdd),
      ),
      body: BlocConsumer<DevicesCubit, DevicesState>(
        listenWhen: (previous, current) =>
            current is DevicesLoaded &&
            previous is DevicesLoaded &&
            current.submission != previous.submission,
        listener: (context, state) {
          if (state is! DevicesLoaded) return;
          final submission = state.submission;
          if (submission is SubmissionSucceeded) {
            showInfoSnack(context, l10n.devicesSaved);
          } else if (submission is SubmissionFailed) {
            final failed = submission;
            showErrorSnack(
              context,
              l10n.errorText(failed.message, failed.failure),
            );
          }
        },
        builder: (context, state) => switch (state) {
          DevicesLoading() => const SkeletonList(),
          DevicesFailure(:final failure) => Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: ErrorState(
              message: l10n.failure(failure),
              onRetry: context.read<DevicesCubit>().load,
            ),
          ),
          DevicesLoaded(:final list) => list.devices.isEmpty
              ? EmptyState(
                  title: l10n.devicesEmpty,
                  message: l10n.devicesEmptyHint,
                  icon: Icons.devices_other_outlined,
                  action: FilledButton.icon(
                    onPressed: _register,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.devicesAdd),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(Space.md),
                  children: [
                    Text(
                      l10n.devicesOfflineMinutes,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    for (final device in list.devices)
                      _DeviceCard(
                        device: device,
                        onRotate: () => _rotate(device),
                        onToggle: () => context
                            .read<DevicesCubit>()
                            .toggle(device),
                        onRename: () => _rename(device),
                        onEvents: () => _events(device),
                        onDelete: () => _delete(device),
                      ),
                  ],
                ),
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.onRotate,
    required this.onToggle,
    required this.onRename,
    required this.onEvents,
    required this.onDelete,
  });

  final LotDevice device;
  final VoidCallback onRotate;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onEvents;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: Key('device_${device.id}'),
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: Padding(
        padding: const EdgeInsets.all(Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(device.name)),
                StatusChip(
                  label: switch (device.status) {
                    DeviceStatus.online => l10n.devicesStatusOnline,
                    DeviceStatus.offline => l10n.devicesStatusOffline,
                    DeviceStatus.neverSeen => l10n.devicesStatusNeverSeen,
                    DeviceStatus.disabled => l10n.devicesStatusDisabled,
                  },
                  tone: switch (device.status) {
                    DeviceStatus.online => StatusTone.success,
                    DeviceStatus.offline => StatusTone.warning,
                    DeviceStatus.disabled => StatusTone.neutral,
                    DeviceStatus.neverSeen => StatusTone.pending,
                  },
                ),
              ],
            ),
            Text('${device.kind.wire} · ${device.keyPrefix}'),
            if (device.firmwareVersion != null)
              Text(l10n.devicesFirmware(device.firmwareVersion!)),
            Wrap(
              spacing: Space.xs,
              children: [
                IconButton(
                  key: Key('device_rotate_${device.id}'),
                  tooltip: l10n.devicesRotate,
                  onPressed: onRotate,
                  icon: const Icon(Icons.key_outlined),
                ),
                IconButton(
                  key: Key('device_toggle_${device.id}'),
                  tooltip: device.enabled
                      ? l10n.devicesDisable
                      : l10n.devicesEnable,
                  onPressed: onToggle,
                  icon: Icon(
                    device.enabled
                        ? Icons.toggle_on_outlined
                        : Icons.toggle_off_outlined,
                  ),
                ),
                IconButton(
                  key: Key('device_rename_${device.id}'),
                  tooltip: l10n.devicesRename,
                  onPressed: onRename,
                  icon: const Icon(Icons.drive_file_rename_outline),
                ),
                IconButton(
                  key: Key('device_events_${device.id}'),
                  tooltip: l10n.devicesEvents,
                  onPressed: onEvents,
                  icon: const Icon(Icons.history),
                ),
                IconButton(
                  key: Key('device_delete_${device.id}'),
                  tooltip: l10n.devicesDelete,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceDialog extends StatefulWidget {
  const _DeviceDialog();

  @override
  State<_DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<_DeviceDialog> {
  DeviceKind _kind = DeviceKind.camera;
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.length < 1 || name.length > 60) {
      setState(() => _error = context.l10n.errorInvalidDeviceName);
      return;
    }
    Navigator.of(context).pop((kind: _kind, name: name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('device_dialog'),
      title: Text(l10n.devicesAdd),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<DeviceKind>(
              key: const Key('device_kind'),
              isExpanded: true,
              initialValue: _kind,
              decoration: InputDecoration(labelText: l10n.devicesKind),
              items: [
                for (final kind in DeviceKind.values)
                  DropdownMenuItem(
                    value: kind,
                    child: Text(kind.wire),
                  ),
              ],
              onChanged: (value) => setState(() => _kind = value ?? _kind),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('device_name'),
              controller: _name,
              maxLength: 60,
              decoration: InputDecoration(labelText: l10n.devicesName),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('device_save'),
          onPressed: _save,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
