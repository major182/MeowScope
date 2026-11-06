import 'dart:convert';

/// 通知の種類（DB 設計書 user_settings.notifications のキー）
enum NotificationKind {
  medication('お薬の時間'),
  anomaly('いつもとの差'),
  reminder('記録忘れ'),
  family('家族の記録'),
  birthday('誕生日');

  const NotificationKind(this.label);

  /// 通知の設定（S-49）に出す名前
  final String label;
}

/// いつもとの差の判定方式（BR-20）
enum AnomalyMethod {
  statistical('ふだんの傾向から自動で判定'),
  threshold('自分で決めたしきい値');

  const AnomalyMethod(this.label);

  final String label;

  /// 保存した値から戻す。知らない値や未設定は既定（統計）にする
  static AnomalyMethod parse(String? value) => AnomalyMethod.values.firstWhere(
    (m) => m.name == value,
    orElse: () => AnomalyMethod.statistical,
  );
}

/// 通知の設定（S-49、F-NT-05）。アカウントの設定として同期する
class NotificationSettings {
  const NotificationSettings({
    this.enabled = const {},
    this.reminderHours = defaultReminderHours,
    this.method = AnomalyMethod.statistical,
  });

  /// 記録忘れの時間の既定と範囲（BR-13、S-49）
  static const defaultReminderHours = 10;
  static const minReminderHours = 1;
  static const maxReminderHours = 48;

  /// 種類ごとのオン・オフ。ない種類はオン
  final Map<NotificationKind, bool> enabled;

  /// 記録忘れの n 時間
  final int reminderHours;

  final AnomalyMethod method;

  bool isOn(NotificationKind kind) => enabled[kind] ?? true;

  NotificationSettings copyWith({
    Map<NotificationKind, bool>? enabled,
    int? reminderHours,
    AnomalyMethod? method,
  }) => NotificationSettings(
    enabled: enabled ?? this.enabled,
    reminderHours: reminderHours ?? this.reminderHours,
    method: method ?? this.method,
  );

  /// [kind] のオン・オフだけを変えた設定
  NotificationSettings toggled(NotificationKind kind, bool on) =>
      copyWith(enabled: {...enabled, kind: on});

  /// 種類ごとのオン・オフを、保存と同期に使う JSON の形にする（すべての種類を書く）
  Map<String, bool> get flags => {
    for (final kind in NotificationKind.values) kind.name: isOn(kind),
  };

  /// 保存した値（端末の状態）から作る。壊れた値は既定に戻す
  static NotificationSettings parse({
    String? flagsJson,
    String? reminderHours,
    String? method,
  }) {
    final enabled = <NotificationKind, bool>{};
    if (flagsJson != null) {
      try {
        final decoded = jsonDecode(flagsJson);
        if (decoded is Map) {
          for (final kind in NotificationKind.values) {
            final value = decoded[kind.name];
            if (value is bool) {
              enabled[kind] = value;
            }
          }
        }
      } on FormatException {
        // 壊れていれば、すべてオン（既定）として扱う
      }
    }
    final hours = int.tryParse(reminderHours ?? '');
    return NotificationSettings(
      enabled: enabled,
      reminderHours:
          hours != null &&
              hours >= minReminderHours &&
              hours <= maxReminderHours
          ? hours
          : defaultReminderHours,
      method: AnomalyMethod.parse(method),
    );
  }

  /// 記録忘れの時間の入力チェック（S-49）。正しければ null
  static String? validateHours(String text) {
    final hours = int.tryParse(text.trim());
    if (hours == null || hours < minReminderHours || hours > maxReminderHours) {
      return '$minReminderHours〜$maxReminderHoursの数字で入れてください';
    }
    return null;
  }
}
