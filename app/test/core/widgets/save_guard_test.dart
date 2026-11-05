import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/logging/app_log.dart';
import 'package:meowscope/core/widgets/save_guard.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<ScaffoldMessengerState> show(WidgetTester tester) async {
    final key = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: key,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    return key.currentState!;
  }

  testWidgets('UT-SG-01 保存できたら true で、案内もログも出さない', (tester) async {
    final messenger = await show(tester);
    final ok = await guardSave(
      log: AppLog(db),
      messenger: messenger,
      what: '猫の保存',
      action: () async {},
    );
    await tester.pump();

    expect(ok, isTrue);
    expect(find.text(saveFailedMessage), findsNothing);
    expect(
      await tester.runAsync(() => db.select(db.clientLogs).get()),
      isEmpty,
    );
  });

  testWidgets('UT-SG-02 失敗したら false で案内を出し、ログには例外の種類だけを書く（内容は書かない）', (
    tester,
  ) async {
    final messenger = await show(tester);
    final ok = await tester.runAsync(
      () => guardSave(
        log: AppLog(db),
        messenger: messenger,
        what: '猫の保存',
        action: () async => throw StateError('ミケ 完食'),
      ),
    );
    await tester.pump();

    expect(ok, isFalse);
    expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
    final logs = await tester.runAsync(() => db.select(db.clientLogs).get());
    expect(logs!.single.status, 'error');
    expect(logs.single.message, '猫の保存に失敗：StateError');
  });
}
