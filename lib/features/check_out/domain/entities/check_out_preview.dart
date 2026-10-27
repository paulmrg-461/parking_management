import 'package:equatable/equatable.dart';

/// Fare preview for an open session (`rpc/check_out_preview`): the same math
/// the server uses when closing, without side effects.
class CheckOutPreview extends Equatable {
  const CheckOutPreview({
    required this.sessionId,
    required this.amount,
    this.hasPass = false,
  });

  final int sessionId;
  final int amount;
  final bool hasPass;

  factory CheckOutPreview.fromJson(Map<String, dynamic> json) =>
      CheckOutPreview(
        sessionId: (json['session_id'] as num).toInt(),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        hasPass: json['has_pass'] == true,
      );

  @override
  List<Object?> get props => [sessionId, amount, hasPass];
}
