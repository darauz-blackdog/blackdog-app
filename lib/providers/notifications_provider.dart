import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
        NotificationsNotifier.new);

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    // TODO: Replace with API call when backend supports notifications
    return [];
  }

  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(read: true) else n,
    ];
  }

  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(read: true)).toList();
  }
}

final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.read).length;
});
