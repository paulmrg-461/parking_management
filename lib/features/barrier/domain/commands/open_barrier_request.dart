import 'package:equatable/equatable.dart';

class OpenBarrierRequest extends Equatable {
  const OpenBarrierRequest({required this.deviceId, required this.reason});

  final int deviceId;
  final String reason;

  @override
  List<Object?> get props => [deviceId, reason];
}
