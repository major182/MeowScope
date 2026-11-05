import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../records/domain/record_kind.dart';
import '../domain/widget_snapshot.dart';
import '../presentation/widget_buttons_screen.dart';
import 'widget_host.dart';

/// 記録できる猫（ウィジェットの選択に出す）
final _widgetCatsProvider = StreamProvider.autoDispose<List<CatRow>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(recordRepositoryProvider)
      .watchActiveCats(session.householdId);
});

/// ウィジェットに渡す内容。読み込みの途中は null（中途半端な内容を渡さない）
final widgetSnapshotProvider = Provider.autoDispose<WidgetSnapshot?>((ref) {
  final user = ref.watch(authUserProvider);
  final session = ref.watch(sessionProvider);
  final buttons = ref.watch(widgetButtonsProvider);
  final cats = ref.watch(_widgetCatsProvider);
  if (!user.hasValue || !session.hasValue) {
    return null;
  }
  if (user.value == null || session.value == null) {
    return WidgetSnapshot.of(
      signedIn: user.value != null,
      householdReady: false,
      buttons: const [],
      cats: const [],
    );
  }
  if (!buttons.hasValue || !cats.hasValue) {
    return null;
  }
  return WidgetSnapshot.of(
    signedIn: true,
    householdReady: true,
    // 非表示の項目のボタンはウィジェットに出さない（S-44）
    buttons: [
      for (final b in buttons.value!)
        if (!b.type.hidden)
          (
            id: b.type.id,
            name: b.type.name,
            icon: iconAsset(b.type.icon) ?? fallbackIconAsset,
          ),
    ],
    cats: [for (final c in cats.value!) (id: c.id, name: c.name)],
  );
});

/// ウィジェットへ渡す。前と同じ内容なら渡さない
class WidgetPublisher {
  WidgetPublisher(this._host);

  final WidgetHost _host;
  String? _last;

  Future<void> publish(WidgetSnapshot? snapshot) async {
    if (snapshot == null) {
      return;
    }
    final json = snapshot.toJson();
    if (json == _last) {
      return;
    }
    _last = json;
    await _host.save(WidgetKeys.snapshot, json);
    // 内容が変わったら、選択の途中の表示（消えた猫やボタン）を残さず、ボタンに戻す
    await _host.showUi('buttons');
  }
}
