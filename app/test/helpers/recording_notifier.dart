import 'package:meowscope/features/notifications/data/notifier.dart';

/// 知らせた内容と予約を覚えておく版（テストの側の差し替え。本物の通知は出さない）
class RecordingNotifier implements AppNotifier {
  final shown = <AppNotification>[];
  final scheduled = <int, (AppNotification, DateTime)>{};

  /// 毎日の繰り返しで予約した id
  final daily = <int>{};
  final cancelled = <int>[];

  @override
  Future<bool> isPermitted() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show(AppNotification notification) async =>
      shown.add(notification);

  @override
  Future<void> schedule(
    AppNotification notification,
    DateTime at, {
    bool daily = false,
  }) async {
    scheduled[notification.id] = (notification, at);
    if (daily) {
      this.daily.add(notification.id);
    } else {
      this.daily.remove(notification.id);
    }
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
    daily.remove(id);
  }
}
