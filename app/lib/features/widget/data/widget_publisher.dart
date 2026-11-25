import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../records/domain/record_kind.dart';
import '../domain/widget_snapshot.dart';
import 'widget_button_repository.dart';
import 'widget_host.dart';

/// 記録できる猫（ウィジェットの選択に出す）。入っているすべてのおうちの猫（BR-40）
final _widgetCatsProvider = StreamProvider.autoDispose<List<CatRow>>((ref) {
  final ids = ref.watch(householdIdsProvider);
  // 材料がそろうまでは流さない
  if (ids == null) {
    return const Stream.empty();
  }
  if (ids.isEmpty) {
    return Stream.value(const []);
  }
  return ref.watch(recordRepositoryProvider).watchActiveCatsIn(ids);
});

/// 自分のボタン。入っているすべてのおうちのもの（BR-40）
final _widgetButtonsProvider =
    StreamProvider.autoDispose<List<WidgetButtonView>>((ref) {
      final userId = ref.watch(
        sessionProvider.select((s) => s.value?.author.id),
      );
      if (userId == null) {
        return Stream.value(const []);
      }
      return ref.watch(widgetButtonRepositoryProvider).watchAllButtons(userId);
    });

/// ウィジェットに渡す内容。読み込みの途中は null（中途半端な内容を渡さない）
final widgetSnapshotProvider = Provider.autoDispose<WidgetState?>((ref) {
  final user = ref.watch(authUserProvider);
  final session = ref.watch(sessionProvider);
  final households = ref.watch(householdsProvider);
  final buttons = ref.watch(_widgetButtonsProvider);
  final cats = ref.watch(_widgetCatsProvider);
  if (!user.hasValue || !session.hasValue) {
    return null;
  }
  if (user.value == null || session.value == null) {
    return const WidgetState.needsApp();
  }
  // 読み込み中（ログインの状態が届く前の空の一覧など）は渡さない
  if (ref.watch(householdIdsProvider) == null ||
      !households.hasValue ||
      !buttons.hasValue ||
      !cats.hasValue) {
    return null;
  }
  return WidgetState(
    households: [
      for (final h in households.value!)
        (
          id: h.id,
          name: h.name,
          snapshot: WidgetSnapshot.of(
            signedIn: true,
            householdReady: true,
            // 非表示の項目のボタンはウィジェットに出さない（S-44）
            buttons: [
              for (final b in buttons.value!)
                if (b.type.householdId == h.id && !b.type.hidden)
                  (
                    id: b.type.id,
                    name: b.type.name,
                    icon:
                        iconAsset(typeIconValue(b.type.kind, b.type.icon)) ??
                        fallbackIconAsset,
                  ),
            ],
            cats: [
              for (final c in cats.value!)
                if (c.householdId == h.id) (id: c.id, name: c.name),
            ],
          ),
        ),
    ],
  );
});

/// ウィジェットへ渡す。前と同じ内容なら渡さない
///
/// 猫の選択の途中に内容が変わったとき（消えた猫やボタン）は、Android の側がボタンの表示に戻す
/// （ウィジェットごとに、選び始めたときの内容を覚えて比べる）
class WidgetPublisher {
  WidgetPublisher(this._host);

  final WidgetHost _host;
  String? _last;

  Future<void> publish(WidgetState? state) async {
    if (state == null) {
      return;
    }
    final json = state.toJson();
    if (json == _last) {
      return;
    }
    _last = json;
    await _host.save(WidgetKeys.snapshot, json);
    await _host.refresh();
  }
}
