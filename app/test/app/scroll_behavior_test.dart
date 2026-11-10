import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/notifications/data/notifier.dart';
import 'package:meowscope/main.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  testWidgets('UT-AP-01 どの画面でも、上端・下端までスクロールしたときに画面が伸びる表現を出さない（#140）', (
    tester,
  ) async {
    final notifier = InAppNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          notifierProvider.overrideWithValue(notifier),
        ],
        child: const MeowScopeApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Navigator).first);
    final indicator = ScrollConfiguration.of(context).buildOverscrollIndicator(
      context,
      const SizedBox(),
      ScrollableDetails.vertical(controller: ScrollController()),
    );
    expect(indicator, isA<SizedBox>());

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await notifier.close();
  });
}
