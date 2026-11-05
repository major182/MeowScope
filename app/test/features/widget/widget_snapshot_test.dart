import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/widget/domain/widget_snapshot.dart';

const _food = (id: 't1', name: 'ご飯', icon: 'assets/icons/food.png');
const _mike = (id: 'c1', name: 'ミケ');
const _tama = (id: 'c2', name: 'タマ');
const _kuro = (id: 'c3', name: 'クロ');
const _shiro = (id: 'c4', name: 'シロ');
const _chacha = (id: 'c5', name: 'チャチャ');

WidgetSnapshot _of({
  bool signedIn = true,
  bool householdReady = true,
  List<WidgetButton> buttons = const [_food],
  List<WidgetItem> cats = const [_mike],
}) => WidgetSnapshot.of(
  signedIn: signedIn,
  householdReady: householdReady,
  buttons: buttons,
  cats: cats,
);

List<List<String>> _pageNames(WidgetSnapshot s) => [
  for (final p in s.pages) [for (final c in p) c.name],
];

void main() {
  test('UT-WG-11 状態：ログインなし・おうちなしはアプリを開く。ボタンなし・猫なしは案内（デシジョンテーブル）', () {
    expect(_of(signedIn: false).status, WidgetStatus.needsApp);
    expect(_of(householdReady: false).status, WidgetStatus.needsApp);
    expect(_of(buttons: const []).status, WidgetStatus.noButtons);
    expect(_of(cats: const []).status, WidgetStatus.noCats);
    expect(_of().status, WidgetStatus.ready);
    // ボタンがなければ、猫がいなくてもボタンの案内を先に出す
    expect(
      _of(buttons: const [], cats: const []).status,
      WidgetStatus.noButtons,
    );
    expect(_of(signedIn: false).message, 'MeowScope を開いてください');
    expect(_of(buttons: const []).message, '設定でボタンを登録してください');
    expect(_of(cats: const []).message, '先に猫を登録してください');
    expect(_of().message, isNull);
  });

  test('UT-WG-12 境界値：猫が1匹はページなし、2匹は1ページ、3匹で2ページ、5匹で3ページ', () {
    expect(_of(cats: const [_mike]).pages, isEmpty);
    expect(_pageNames(_of(cats: const [_mike, _tama])), [
      ['ミケ', 'タマ'],
    ]);
    expect(_pageNames(_of(cats: const [_mike, _tama, _kuro])), [
      ['ミケ', 'タマ'],
      ['クロ'],
    ]);
    expect(
      _pageNames(_of(cats: const [_mike, _tama, _kuro, _shiro, _chacha])),
      [
        ['ミケ', 'タマ'],
        ['クロ', 'シロ'],
        ['チャチャ'],
      ],
    );
  });

  test(
    'UT-WG-13 JSON：Android の側が読む形。ボタンは項目のイラスト、猫は猫のイラスト。1匹のときだけ onlyCat を入れる',
    () {
      final one = jsonDecode(_of().toJson()) as Map<String, dynamic>;
      expect(one, {
        'status': 'ready',
        'message': null,
        'buttons': [
          {'id': 't1', 'name': 'ご飯', 'icon': 'assets/icons/food.png'},
        ],
        'pages': <Object>[],
        'onlyCat': {'id': 'c1', 'name': 'ミケ', 'icon': widgetCatIcon},
      });
      final two = jsonDecode(
        _of(cats: const [_mike, _tama]).toJson(),
      ) as Map<String, dynamic>;
      expect(two['onlyCat'], isNull);
      expect((two['pages'] as List).single, hasLength(2));
    },
  );
}
