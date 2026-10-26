import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/app_notification.dart';
import '../domain/repositories/notification_repository.dart';

enum NotificationsStatus { initial, loading, loaded, failure }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.items = const [],
    this.error,
    this.latestArrived,
    this.actionError,
  });

  final NotificationsStatus status;
  final List<AppNotification> items;
  final Failure? error;

  /// Set exactly when a realtime insert arrives (used for the in-app banner).
  final AppNotification? latestArrived;
  final Failure? actionError;

  int get unreadCount => items.where((item) => !item.isRead).length;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? items,
    Failure? error,
    AppNotification? latestArrived,
    Failure? actionError,
  }) => NotificationsState(
    status: status ?? this.status,
    items: items ?? this.items,
    error: error,
    latestArrived: latestArrived ?? this.latestArrived,
    actionError: actionError,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    error,
    latestArrived,
    actionError,
  ];
}

class NotificationsCubit extends ResilientCubit<NotificationsState> {
  NotificationsCubit(this._repository) : super(const NotificationsState());

  final NotificationRepository _repository;
  StreamSubscription<AppNotification>? _subscription;
  bool _started = false;

  /// Loads the inbox and subscribes to live inserts. Safe to call once.
  Future<void> start(int? userId) async {
    if (_started) {
      return;
    }
    _started = true;
    _subscription = _repository.watch(userId).listen(
      _onIncoming,
      onError: (_) {
        // Realtime reconnects on its own; the next load catches up.
      },
    );
    await load();
  }

  Future<void> load() async {
    emit(state.copyWith(status: NotificationsStatus.loading, error: null));
    try {
      final items = await _repository.load();
      emit(
        NotificationsState(
          status: NotificationsStatus.loaded,
          items: items,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          error: failure,
        ),
      );
    }
  }

  Future<void> markRead(int id) async {
    final previous = state.items;
    final next = [
      for (final item in previous)
        item.id == id ? item.copyWith(isRead: true) : item,
    ];
    emit(state.copyWith(items: next, actionError: null));
    try {
      await _repository.markRead(ids: [id]);
    } on Failure catch (failure) {
      emit(state.copyWith(items: previous, actionError: failure));
    }
  }

  Future<void> markAllRead() async {
    final previous = state.items;
    emit(
      state.copyWith(
        items: [for (final item in previous) item.copyWith(isRead: true)],
        actionError: null,
      ),
    );
    try {
      await _repository.markRead();
    } on Failure catch (failure) {
      emit(state.copyWith(items: previous, actionError: failure));
    }
  }

  void clearActionError() => emit(state.copyWith(actionError: null));

  void _onIncoming(AppNotification notification) {
    if (state.items.any((item) => item.id == notification.id)) {
      return;
    }
    emit(
      state.copyWith(
        status: NotificationsStatus.loaded,
        items: [notification, ...state.items],
        latestArrived: notification,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
