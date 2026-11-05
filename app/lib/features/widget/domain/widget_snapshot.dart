import 'dart:convert';

/// ウィジェットに出す名前と ID
typedef WidgetItem = ({String id, String name});

/// ウィジェットのボタン。[icon] はアプリのイラストの場所（assets/icons/...）。Android の側はアプリの中のイラストを読んで出す
typedef WidgetButton = ({String id, String name, String icon});

/// 猫のボタンに出すイラスト
const widgetCatIcon = 'assets/icons/default_cat.png';

/// ウィジェットの状態
enum WidgetStatus {
  /// 記録できる
  ready,

  /// ログインしていない、またはおうちがない。押すとアプリを開く
  needsApp,

  /// ボタンがない。押すとボタンの設定（S-44）を開く
  noButtons,

  /// 猫がいない。押すとアプリを開く（ホームで猫の登録を促す）
  noCats,
}

/// 1ページに出す猫の数（ウィジェットは 2×2 の枠。下の段は「次へ」と「やめる」）
const catsPerPage = 2;

/// ウィジェットに渡すデータ（F-WG-01）。Android の側はこれを描くだけにする
///
/// 猫の選び方（Issue #80 で決定）：
/// - 1匹なら選ばずに記録する（BR-23）。2匹なら1ページ。3匹以上は2匹ずつのページに分け、「次へ」で送る
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.status,
    this.buttons = const [],
    this.cats = const [],
  });

  /// 端末の状態から作る。[signedIn] と [householdReady] のどちらかが偽なら、アプリを開くだけにする
  factory WidgetSnapshot.of({
    required bool signedIn,
    required bool householdReady,
    required List<WidgetButton> buttons,
    required List<WidgetItem> cats,
  }) {
    if (!signedIn || !householdReady) {
      return const WidgetSnapshot(status: WidgetStatus.needsApp);
    }
    if (buttons.isEmpty) {
      return const WidgetSnapshot(status: WidgetStatus.noButtons);
    }
    if (cats.isEmpty) {
      return WidgetSnapshot(status: WidgetStatus.noCats, buttons: buttons);
    }
    return WidgetSnapshot(
      status: WidgetStatus.ready,
      buttons: buttons,
      cats: cats,
    );
  }

  final WidgetStatus status;
  final List<WidgetButton> buttons;
  final List<WidgetItem> cats;

  /// 猫のページ。1匹なら選ばないので空
  List<List<WidgetItem>> get pages => cats.length <= 1
      ? const []
      : [
          for (var i = 0; i < cats.length; i += catsPerPage)
            cats.sublist(
              i,
              i + catsPerPage > cats.length ? cats.length : i + catsPerPage,
            ),
        ];

  /// 状態に合わせた案内の文
  String? get message => switch (status) {
    WidgetStatus.ready => null,
    WidgetStatus.needsApp => 'MeowScope を開いてください',
    WidgetStatus.noButtons => '設定でボタンを登録してください',
    WidgetStatus.noCats => '先に猫を登録してください',
  };

  /// Android の側へ渡す JSON
  String toJson() => jsonEncode({
    'status': status.name,
    'message': message,
    'buttons': [
      for (final b in buttons) {'id': b.id, 'name': b.name, 'icon': b.icon},
    ],
    'pages': [
      for (final p in pages)
        [
          for (final c in p)
            {'id': c.id, 'name': c.name, 'icon': widgetCatIcon},
        ],
    ],
    // 1匹のときは、押したらこの猫で記録する
    'onlyCat': cats.length == 1
        ? {
            'id': cats.single.id,
            'name': cats.single.name,
            'icon': widgetCatIcon,
          }
        : null,
  });
}
