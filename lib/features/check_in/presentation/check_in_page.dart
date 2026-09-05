import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../plate_scanning/infrastructure/image_picker_plate_capture.dart';
import '../application/check_in_cubit.dart';
import '../domain/entities/parking_session.dart';

/// Captures a check-in: a scanned or manually entered plate plus optional
/// evidence photos, submitted to open a new parking session. Also shows the
/// list of currently open sessions.
class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key, this.capture});

  /// Overridable image-capture mechanism, injected in tests to avoid
  /// invoking the real device camera.
  final PlateImageCapture? capture;

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final _plateController = TextEditingController();
  final List<File> _photos = [];
  late final PlateImageCapture _capture = widget.capture ?? ImagePickerPlateCapture();

  @override
  void initState() {
    super.initState();
    context.read<CheckInCubit>().loadOpenSessions();
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _scanPlate(BuildContext context) async {
    final result = await context.push<String>('/scan');
    if (result != null) {
      setState(() => _plateController.text = result);
    }
  }

  Future<void> _addPhoto() async {
    final image = await _capture.capture();
    if (image != null) {
      setState(() => _photos.add(File(image.path)));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _submit(BuildContext context) {
    context.read<CheckInCubit>().submitCheckIn(
          plate: _plateController.text,
          photos: List.of(_photos),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in')),
      body: BlocConsumer<CheckInCubit, CheckInState>(
        listener: (context, state) {
          if (state is CheckInSuccess) {
            _plateController.clear();
            setState(_photos.clear);
            context.read<CheckInCubit>().loadOpenSessions();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Check-in created for ${state.session.plate}'),
              ),
            );
          }
        },
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildForm(context, state),
            const Divider(height: 32),
            const Text(
              'Open sessions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildSessions(state),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, CheckInState state) {
    final submitting = state is CheckInSubmitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => _scanPlate(context),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Scan plate'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _plateController,
          decoration: const InputDecoration(labelText: 'Plate'),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),
        const Text('Evidence photos'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _photos.length; i++)
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(_photos[i], fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => _removePhoto(i),
                        child: const CircleAvatar(
                          radius: 10,
                          child: Icon(Icons.close, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            OutlinedButton(
              onPressed: _addPhoto,
              child: const Icon(Icons.add_a_photo),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state is CheckInFailure)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              state.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: submitting ? null : () => _submit(context),
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit check-in'),
        ),
      ],
    );
  }

  List<Widget> _buildSessions(CheckInState state) {
    if (state is CheckInInitial || state is CheckInLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final sessions = state is CheckInLoaded ? state.sessions : const <ParkingSession>[];
    if (sessions.isEmpty) {
      return const [Text('No open sessions')];
    }
    return [
      for (final session in sessions)
        ListTile(
          title: Text(session.plate),
          subtitle: Text('Entry: ${session.entryTime} · Photos: ${session.photoCount}'),
        ),
    ];
  }
}
