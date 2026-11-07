import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/readable_width.dart';
import '../../../core/widgets/save_guard.dart';
import '../data/medication_repository.dart';

/// おうちのお薬の予定（猫の登録順・時刻の順）
final medicationEntriesProvider =
    StreamProvider.autoDispose<List<MedicationEntry>>((ref) {
      final session = ref.watch(sessionProvider).value;
      if (session == null) {
        return Stream.value(const []);
      }
      return ref
          .watch(medicationRepositoryProvider)
          .watchSchedules(session.householdId);
    });

/// 一覧の1行の薬の文。「○○錠 1錠」（量がなければ薬の名前だけ）
String medicationLabel(String name, String? dose) =>
    dose == null ? name : '$name $dose';

/// お薬の予定（S-50、F-MD-02）
///
/// 猫ごとに、毎日の時刻と薬を並べる。スイッチでオン・オフを変え、押すと編集の画面を開く。
/// 予定はおうちの家族と共有する。通知を出すかは各自の通知の設定（S-49）に従う
class MedicationSchedulesScreen extends ConsumerWidget {
  const MedicationSchedulesScreen({super.key});

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    MedicationEntry entry,
    bool enabled,
  ) async {
    final session = ref.read(sessionProvider).value;
    if (session == null) {
      return;
    }
    await guardSave(
      log: ref.read(appLogProvider),
      messenger: ScaffoldMessenger.of(context),
      what: 'お薬の予定の保存',
      action: () => ref
          .read(medicationRepositoryProvider)
          .setEnabled(
            id: entry.schedule.id,
            userId: session.author.id,
            enabled: enabled,
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(medicationEntriesProvider).value;
    final children = <Widget>[];
    String? lastCat;
    for (final e in entries ?? const <MedicationEntry>[]) {
      if (e.cat.id != lastCat) {
        lastCat = e.cat.id;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              e.cat.status == 'farewell' ? '${e.cat.name}（お別れ）' : e.cat.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      }
      final s = e.schedule;
      children.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Text(
            s.timeOfDay,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          title: Text(medicationLabel(s.name, s.dose)),
          onTap: () => context.push('/medications/${s.id}'),
          trailing: Switch(
            value: s.enabled,
            onChanged: (on) => _toggle(context, ref, e, on),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('お薬の予定')),
      body: ListView(
        padding: readablePadding(context, 16),
        children: [
          if (entries != null && entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('お薬の予定はまだありません'),
            ),
          ...children,
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.push('/medications/new'),
            child: const Text('予定を追加'),
          ),
        ],
      ),
    );
  }
}
