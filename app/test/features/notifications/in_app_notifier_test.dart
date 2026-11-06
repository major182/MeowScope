import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/notifications/data/notifier.dart';

void main() {
  const notification = AppNotification(id: 1, title: 'ミケの記録が10時間ありません');

  test('UT-NS-10 Windows：知らせると画面の側へ流し、目を引く処理（タスクバーの点滅）を呼ぶ', () async {
    var flashed = 0;
    final notifier = InAppNotifier(attention: () async => flashed++);
    final shown = <AppNotification>[];
    final sub = notifier.stream.listen(shown.add);

    await notifier.show(notification);
    await Future<void>.delayed(Duration.zero);

    expect(shown.single.title, 'ミケの記録が10時間ありません');
    expect(flashed, 1);
    await sub.cancel();
    await notifier.close();
  });

  test('UT-NS-11 異常系：点滅に失敗しても、画面の中では知らせて例外を外へ出さない', () async {
    final notifier = InAppNotifier(
      attention: () async => throw StateError('窓がない'),
    );
    final shown = <AppNotification>[];
    final sub = notifier.stream.listen(shown.add);

    await notifier.show(notification);
    await Future<void>.delayed(Duration.zero);

    expect(shown, hasLength(1));
    await sub.cancel();
    await notifier.close();
  });
}
