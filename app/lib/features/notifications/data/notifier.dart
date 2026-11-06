import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 知らせる内容。[id] は同じ通知を置き換えるときに使う（同じ id なら新しいもので置き換わる）
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.payload,
  });

  final int id;
  final String title;
  final String? body;

  /// 押したときに開く場所（アプリの中のパス）
  final String? payload;
}

/// 通知を出す部品（F-NT-01〜06、BR-09）。テストでは記録するだけの版に差し替える
abstract interface class AppNotifier {
  /// 通知が許可されているか。許可の要らない端末（Windows）は true
  Future<bool> isPermitted();

  /// 利用者に通知の許可を求める（Android 13 以降）。許可されたら true
  Future<bool> requestPermission();

  /// すぐに知らせる
  Future<void> show(AppNotification notification);
}

/// Android：OS の通知として出す
class AndroidNotifier implements AppNotifier {
  AndroidNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// 通知のチャンネル。Android の設定画面で利用者が見る名前になる
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'meowscope',
      'MeowScope の通知',
      channelDescription: 'お薬の時間・いつもとの差・記録忘れ・家族の記録・誕生日',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// アプリの起動時に1回だけ呼ぶ。[onTap] は通知を押したときに、payload を受け取る
  static Future<AndroidNotifier> create({
    void Function(String? payload)? onTap,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          onTap?.call(response.payload),
    );
    return AndroidNotifier(plugin);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> isPermitted() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> show(AppNotification n) => _plugin.show(
    id: n.id,
    title: n.title,
    body: n.body,
    notificationDetails: _details,
    payload: n.payload,
  );
}

/// Windows：OS の通知は出さず、アプリの起動中に画面の中で知らせる（BR-09）。
/// 画面の側は [stream] を聞いて、画面の下に出す
class InAppNotifier implements AppNotifier {
  /// [attention] は、知らせたときに利用者の目を引く処理（Windows はタスクバーのアイコンの点滅）
  InAppNotifier({this.attention});

  final Future<void> Function()? attention;

  final _controller = StreamController<AppNotification>.broadcast();

  Stream<AppNotification> get stream => _controller.stream;

  @override
  Future<bool> isPermitted() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show(AppNotification n) async {
    _controller.add(n);
    try {
      await attention?.call();
    } on Object {
      // 点滅できなくても、画面の中では知らせているので続ける
    }
  }

  Future<void> close() => _controller.close();
}

/// Windows のタスクバーのアイコンを点滅させる（BR-09）。窓が手前にあれば何もしない。
/// 窓を手前に出すと点滅は止まる（windows/runner/flutter_window.cpp の FlashWindowEx）
Future<void> flashTaskbar() =>
    const MethodChannel('meowscope/taskbar').invokeMethod<bool>('flash');
