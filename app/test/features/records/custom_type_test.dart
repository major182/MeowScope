import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/domain/custom_type.dart';

import '../../helpers/test_db.dart';

void main() {
  group('入力の決まり', () {
    test('UT-TY-01 アイコンの値：知っている値／空／知らない値（同値分割）', () {
      expect(CustomIcon.parse('custom_treat'), CustomIcon.treat);
      expect(CustomIcon.parse(null), isNull);
      expect(CustomIcon.parse('food'), isNull);
    });

    test('UT-TY-02 名前：空と空白だけは不可', () {
      expect(validateTypeName(null, const []), '名前を入力してください');
      expect(validateTypeName('  ', const []), '名前を入力してください');
    });

    test('UT-TY-03 名前の境界値：20文字は可、21文字は不可', () {
      expect(validateTypeName('あ' * 20, const []), isNull);
      expect(validateTypeName('あ' * 21, const []), '20文字以内で入力してください');
    });

    test('UT-TY-04 名前：同じおうちの項目と同じ名前は不可（前後の空白を除いて比べる）', () {
      expect(validateTypeName(' ご飯 ', const ['ご飯']), '同じ名前の項目があります');
      expect(validateTypeName('通院', const ['ご飯']), isNull);
    });
  });

  group('リポジトリ', () {
    late AppDatabase db;
    late RecordRepository repo;

    setUp(() async {
      db = memoryDatabase();
      repo = RecordRepository(db, clock: () => DateTime(2026, 11, 3));
      await addHousehold(db, 'h1');
      await addHousehold(db, 'h2');
      await repo.addStandardTypes('h1');
      await db.delete(db.pendingChanges).go();
    });

    tearDown(() => db.close());

    Future<String> add(String name, {String householdId = 'h1'}) =>
        repo.addCustomType(
          householdId: householdId,
          userId: 'u1',
          name: name,
          icon: CustomIcon.vet.value,
        );

    test('UT-TY-05 独自の項目を標準の後ろに追加し、同期待ちに残す。名前の前後の空白を除く', () async {
      await add(' 通院 ');
      await add('爪切り');

      final types = await repo.watchTypes('h1').first;
      expect(types, hasLength(10));
      expect(types[8].name, '通院');
      expect(types[8].kind, 'custom');
      expect(types[8].icon, 'custom_vet');
      expect(types.map((t) => t.sortOrder).skip(8), [8, 9]);
      final changes = await db.select(db.pendingChanges).get();
      expect(changes.map((c) => c.targetTable), [
        'record_types',
        'record_types',
      ]);
      expect(jsonDecode(changes.first.payload)['name'], '通院');
    });

    test('UT-TY-06 境界値：項目のないおうちでは並び順 0 から', () async {
      await add('通院', householdId: 'h2');

      expect((await repo.watchTypes('h2').first).single.sortOrder, 0);
    });

    test('UT-TY-07 独自の項目の名前とアイコンを変える', () async {
      final id = await add('通院');

      await repo.updateCustomType(
        id: id,
        userId: 'u1',
        name: '病院',
        icon: CustomIcon.other.value,
      );

      final type = (await repo.watchTypes('h1').first).last;
      expect(type.name, '病院');
      expect(type.icon, 'custom_other');
    });

    test('UT-TY-08 異常系：標準の項目と存在しない項目は変えられず、同期待ちも残さない', () async {
      final food = (await repo.watchTypes('h1').first).first;

      for (final id in [food.id, 'none']) {
        await expectLater(
          repo.updateCustomType(id: id, userId: 'u1', name: 'x', icon: 'y'),
          throwsStateError,
        );
      }
      expect((await repo.watchTypes('h1').first).first.name, 'ご飯');
      expect(await db.select(db.pendingChanges).get(), isEmpty);
    });
  });
}
