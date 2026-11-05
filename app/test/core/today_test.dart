import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/today.dart';

void main() {
  test('UT-DY-01 今日の日付を流し、0時を過ぎたら次の日付を流す', () async {
    // 0時の0.1秒前から始める。次に流すのは0時の1秒後（時計の誤差を避けるため）なので、約1.1秒待つ
    final times = [
      DateTime(2026, 11, 6, 23, 59, 59, 900),
      DateTime(2026, 11, 7, 0, 0, 1),
    ];
    var calls = 0;
    final days = await dayStream(() => times[calls++ < 1 ? 0 : 1])
        .take(2)
        .toList();

    expect(days, [DateTime(2026, 11, 6), DateTime(2026, 11, 7)]);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('UT-DY-02 境界値：0時の1秒後までは次の日付を流さない', () async {
    final days = <DateTime>[];
    final sub = dayStream(() => DateTime(2026, 11, 6, 23, 59, 59, 900))
        .listen(days.add);
    // 次に流すまで約1.1秒ある。0.5秒では流れない
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(days, [DateTime(2026, 11, 6)]);
    // 聞くのをやめたらタイマーも止まる（止まらなければ、この後に流れてしまう）
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    expect(days, hasLength(1));
  }, timeout: const Timeout(Duration(seconds: 10)));
}
