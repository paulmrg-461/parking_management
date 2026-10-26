import 'package:equatable/equatable.dart';

/// One browser push endpoint: the URL the push service gave the browser plus
/// the two keys the payload is encrypted with.
class WebPushSubscription extends Equatable {
  const WebPushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;

  @override
  List<Object?> get props => [endpoint];
}
