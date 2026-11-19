/// 記録項目の端末ごとの並び順（F-RC-07、BR-36）
///
/// 並び順は項目の ID の一覧で持つ。端末の状態（app_states）に置き、同期しない
library;

import 'dart:convert';

/// 並び順を項目に当てはめる。[types] は登録の順（sort_order）に並んでいるものとする
///
/// - 並び順にある項目を、その順に先に並べる
/// - 並び順にない項目（並べ替えた後に増えた項目など）は、登録の順のまま最後に並べる
/// - 並び順にあって項目にない ID（消えた項目）は無視する
List<T> applyTypeOrder<T>(
  List<T> types,
  List<String> order,
  String Function(T) idOf,
) {
  if (order.isEmpty) {
    return types;
  }
  final rank = {for (final (i, id) in order.indexed) id: i};
  final known = [
    for (final t in types)
      if (rank.containsKey(idOf(t))) t,
  ]..sort((a, b) => rank[idOf(a)]!.compareTo(rank[idOf(b)]!));
  return [
    ...known,
    for (final t in types)
      if (!rank.containsKey(idOf(t))) t,
  ];
}

/// 保存した並び順（JSON の配列）を読む。未設定や壊れた値は空（登録の順）
List<String> parseTypeOrder(String? value) {
  if (value == null) {
    return const [];
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      return [
        for (final v in decoded)
          if (v is String) v,
      ];
    }
  } on FormatException {
    // 壊れた値は並べ替えていないものとして扱う
  }
  return const [];
}

/// 一覧の中で1つを動かした後の並び順を返す（ReorderableListView の onReorderItem の形）
///
/// [newIndex] は、動かした後の一覧での位置（自分が抜けた分は調整済み）
List<String> moveTypeOrder(List<String> ids, int oldIndex, int newIndex) {
  final list = [...ids];
  final id = list.removeAt(oldIndex);
  list.insert(newIndex, id);
  return list;
}

/// Android のホームで、通常の大きさで出すボタンの数（上2段 × 4列）。
/// これより後ろ（3段目から）は半分の大きさにする（画面設計書 S-10）
const homeFullSizeCount = 8;
