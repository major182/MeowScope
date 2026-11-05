import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/sync/data/rejected_change_repository.dart';
import 'package:meowscope/features/sync/domain/rejected_guidance.dart';

import '../../helpers/test_db.dart';

void main() {
  group('UT-RJ-02 原因と対応の案内（理由の同値分割）', () {
    test('理由ごとに、原因と対応を出す。権限のときだけ送り直しを出さない', () {
      for (final reason in [
        'unknown_table',
        'not_found',
        'constraint',
        'invalid',
        'too_many',
        'something_new',
      ]) {
        final g = guidanceFor(reason, null);
        expect(g.cause, isNotEmpty, reason: reason);
        expect(g.action, isNotEmpty, reason: reason);
        expect(g.canResend, isTrue, reason: reason);
      }
      final forbidden = guidanceFor('forbidden', null);
      expect(forbidden.canResend, isFalse);
      expect(forbidden.action, contains('一覧から消す'));
      expect(guidanceFor('unknown_table', null).cause, contains('版の違い'));
      expect(guidanceFor('too_many', null).cause, contains('3枚'));
    });

    test('値の誤りは、どの項目かを画面の言葉で出す。項目がなければ一般の文', () {
      final g = guidanceFor('invalid', 'level');
      expect(g.cause, '「量」の内容が決まりに合いません');
      expect(g.action, '「量」を直してから「送り直す」を押してください');
      expect(guidanceFor('invalid', null).cause, '内容が決まりに合いません');
    });

    test('UT-RJ-03 項目の名前：知っている名前は画面の言葉に、知らない名前はそのまま', () {
      expect(fieldLabel('valueNumber'), '体重');
      expect(fieldLabel('birthDate'), '生年月日');
      expect(fieldLabel('recordTypeId'), '記録項目');
      expect(fieldLabel('newField'), 'newField');
    });
  });

  group('送れなかった変更の一覧', () {
    late AppDatabase db;
    late RejectedChangeRepository repo;

    setUp(() async {
      db = memoryDatabase();
      repo = RejectedChangeRepository(db);
      await addHousehold(db, 'h1');
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await db
          .into(db.recordTypes)
          .insert(
            RecordTypesCompanion.insert(
              id: 't1',
              createdAt: testTime,
              updatedAt: testTime,
              householdId: 'h1',
              name: 'ご飯',
              kind: 'food',
            ),
          );
      await db
          .into(db.records)
          .insert(
            RecordsCompanion.insert(
              id: 'r1',
              createdAt: testTime,
              updatedAt: testTime,
              catId: 'c1',
              recordTypeId: 't1',
              recordedAt: DateTime(2026, 11, 5, 8, 10),
              authorName: 'はる',
            ),
          );
      await db
          .into(db.recordPhotos)
          .insert(
            RecordPhotosCompanion.insert(
              id: 'p1',
              createdAt: testTime,
              updatedAt: testTime,
              recordId: 'r1',
              sortOrder: 1,
            ),
          );
      await db
          .into(db.widgetButtons)
          .insert(
            WidgetButtonsCompanion.insert(
              id: 'w1',
              createdAt: testTime,
              updatedAt: testTime,
              userId: 'u1',
              recordTypeId: 't1',
            ),
          );
    });
    tearDown(() => db.close());

    Future<void> reject(
      String table,
      String id, {
      String user = 'u1',
      String reason = 'invalid',
      String? field,
      DateTime? at,
    }) => db
        .into(db.rejectedChanges)
        .insert(
          RejectedChangesCompanion.insert(
            userId: user,
            targetTable: table,
            rowId: id,
            reason: reason,
            field: Value(field),
            rejectedAt: at ?? testTime,
          ),
        );

    test('UT-RJ-04 何の変更かを、表ごとに利用者の言葉にする。記録とその写真は記録を開ける', () async {
      final cases = {
        ('records', 'r1'): ('11/05 08:10 ミケのご飯', 'r1'),
        ('record_photos', 'p1'): ('写真（11/05 08:10 ミケのご飯）', 'r1'),
        ('cats', 'c1'): ('猫：ミケ', null),
        ('record_types', 't1'): ('記録項目：ご飯', null),
        ('widget_buttons', 'w1'): ('ウィジェットのボタン：ご飯', null),
        ('households', 'h1'): ('おうち：みけ家', null),
        ('user_settings', 'u1'): ('設定（カレンダーの週の始まり）', null),
        ('other', 'x'): ('その他のデータ', null),
      };
      for (final (table, id) in cases.keys) {
        await reject(table, id);
      }

      final views = await repo.watch('u1').first;
      expect({
        for (final v in views) (v.table, v.rowId): (v.label, v.recordId),
      }, cases);
    });

    test('UT-RJ-05 端末から消えた行は「削除された…」と出し、記録は開けない', () async {
      for (final table in [
        'records',
        'record_photos',
        'cats',
        'record_types',
        'widget_buttons',
        'households',
      ]) {
        await reject(table, 'gone');
      }

      final views = await repo.watch('u1').first;
      expect(
        {for (final v in views) v.table: v.label},
        {
          'records': '削除された記録',
          'record_photos': '記録の写真',
          'cats': '猫：削除された猫',
          'record_types': '記録項目：削除された項目',
          'widget_buttons': 'ウィジェットのボタン：削除されたボタン',
          'households': 'おうち：削除されたおうち',
        },
      );
      expect(views.every((v) => v.recordId == null), isTrue);
    });

    test('UT-RJ-06 自分の分だけを新しい順に出す。理由と項目も渡す', () async {
      await reject('cats', 'c1', at: DateTime.utc(2026, 11, 4));
      await reject(
        'records',
        'r1',
        at: DateTime.utc(2026, 11, 5),
        field: 'level',
      );
      await reject('cats', 'c1', user: 'u2');

      final views = await repo.watch('u1').first;
      expect(views.map((v) => (v.table, v.reason, v.field)), [
        ('records', 'invalid', 'level'),
        ('cats', 'invalid', null),
      ]);
    });

    test('UT-RJ-07 送り直すと同期待ちに戻して一覧から外す。おうちは作成として戻す。一覧から消すと送らない', () async {
      await reject('records', 'r1');
      await reject('households', 'h1');
      await reject('cats', 'c1');
      final views = {for (final v in await repo.watch('u1').first) v.table: v};

      await repo.resend('u1', views['records']!);
      await repo.resend('u1', views['households']!);
      await repo.dismiss('u1', views['cats']!);

      expect(await db.select(db.rejectedChanges).get(), isEmpty);
      final pending = await db.select(db.pendingChanges).get();
      expect(
        pending.map((p) => (p.userId, p.targetTable, p.rowId, p.operation)),
        [
          ('u1', 'records', 'r1', 'upsert'),
          ('u1', 'households', 'h1', 'create'),
        ],
      );
    });
  });
}
