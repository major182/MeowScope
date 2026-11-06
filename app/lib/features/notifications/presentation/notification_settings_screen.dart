import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/readable_width.dart';
import '../../../core/widgets/save_guard.dart';
import '../domain/notification_settings.dart';

/// 通知の設定（S-49、F-NT-05）
///
/// 種類ごとのオン・オフ、記録忘れの時間、いつもとの差の判定方式を決める。変えたらすぐ保存し、アカウントの設定として同期する
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  final _hours = TextEditingController();
  String? _hoursError;
  bool? _permitted;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    // 端末の設定で許可を変えて戻ってきたときに、案内を出し直す
    _lifecycle = AppLifecycleListener(onResume: _checkPermission);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final permitted = await ref.read(notifierProvider).isPermitted();
    if (mounted) {
      setState(() => _permitted = permitted);
    }
  }

  Future<void> _request() async {
    final permitted = await ref.read(notifierProvider).requestPermission();
    if (mounted) {
      setState(() => _permitted = permitted);
    }
  }

  Future<void> _save(NotificationSettings value) => guardSave(
    log: ref.read(appLogProvider),
    messenger: ScaffoldMessenger.of(context),
    what: '通知の設定の保存',
    action: () => ref
        .read(settingsRepositoryProvider)
        .setNotificationSettings(
          value,
          userId: ref.read(authUserProvider).value?.id,
        ),
  );

  /// 記録忘れの時間は、正しい値になったときだけ保存する
  void _changeHours(NotificationSettings current, String text) {
    final error = NotificationSettings.validateHours(text);
    setState(() => _hoursError = error);
    if (error == null) {
      _save(current.copyWith(reminderHours: int.parse(text.trim())));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 保存のときにユーザーを使うので、読み込んでおく
    ref.watch(authUserProvider);
    final settings = ref.watch(notificationSettingsProvider).value;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 入力中の値を上書きしないよう、欄が空のときだけ保存した値を入れる
    if (_hours.text.isEmpty && _hoursError == null) {
      _hours.text = '${settings.reminderHours}';
    }
    final android = defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(title: const Text('通知の設定')),
      body: ListView(
        padding: readablePadding(context, 0),
        children: [
          if (android && _permitted == false)
            MaterialBanner(
              content: const Text('通知が許可されていません'),
              actions: [
                TextButton(onPressed: _request, child: const Text('許可する')),
              ],
            ),
          if (!android)
            const ListTile(
              dense: true,
              title: Text('Windows では、アプリを開いている間に画面の下でお知らせします'),
            ),
          // Windows では、記録にかかわる種類（記録忘れ・お薬の時間・家族の記録）は出さない（BR-09）
          for (final kind in NotificationKind.forDevice(android: android)) ...[
            SwitchListTile(
              title: Text(kind.label),
              value: settings.isOn(kind),
              onChanged: (on) => _save(settings.toggled(kind, on)),
            ),
            if (kind == NotificationKind.reminder &&
                settings.isOn(NotificationKind.reminder))
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text('最後の記録から'),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: _hours,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          suffixText: '時間',
                          errorText: _hoursError,
                          errorMaxLines: 2,
                        ),
                        onChanged: (text) => _changeHours(settings, text),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const Divider(),
          const ListTile(title: Text('いつもとの差の判定方式')),
          RadioGroup<AnomalyMethod>(
            groupValue: settings.method,
            onChanged: (method) {
              if (method != null) {
                _save(settings.copyWith(method: method));
              }
            },
            child: Column(
              children: [
                for (final method in AnomalyMethod.values)
                  RadioListTile<AnomalyMethod>(
                    value: method,
                    title: Text(method.label),
                  ),
              ],
            ),
          ),
          if (settings.method == AnomalyMethod.threshold)
            const ListTile(
              contentPadding: EdgeInsets.only(left: 32, right: 16),
              title: Text('しきい値の設定'),
              // しきい値の設定（S-47）は、いつもとの差の検知（計画の5）で作る
              subtitle: Text('準備中'),
              enabled: false,
            ),
        ],
      ),
    );
  }
}
