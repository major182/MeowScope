import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/today.dart';
import '../../../core/widgets/save_guard.dart';
import '../../household/data/household_repository.dart';
import '../../records/domain/record_detail.dart';
import '../../records/presentation/cat_picker.dart';
import '../../records/presentation/home_screen.dart';
import '../../records/presentation/record_providers.dart';

/// 日付から記録を始める道筋（S-24）。日付は `YYYY-MM-DD`
String dayRecordAddPath(DateTime day) =>
    '/days/${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}/new';

/// 日付からの記録（S-24。F-VW-06、BR-35）
///
/// ①項目 → ②猫 → ③内容 → ④保存 の順に進む。③は記録の詳細入力（S-12）を使う。
/// S-12 は記録の ID を持つ画面（写真もその場で記録に付ける）なので、③へ進むときに記録を作り、
/// ③で保存せずに戻ったら、作った記録を消して①に戻る
class DayRecordAddScreen extends ConsumerStatefulWidget {
  const DayRecordAddScreen({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<DayRecordAddScreen> createState() => _DayRecordAddScreenState();
}

class _DayRecordAddScreenState extends ConsumerState<DayRecordAddScreen> {
  /// ③へ進む途中で、ボタンを続けて押されないようにする
  bool _busy = false;

  Future<void> _start(
    RecordTypeRow type,
    List<CatRow> cats,
    Session session,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    // 待つ間に画面が閉じても使えるよう、先に取っておく
    final repo = ref.read(recordRepositoryProvider);
    final log = ref.read(appLogProvider);
    final now = ref.read(nowProvider)();
    if (cats.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('先に猫を登録してください')));
      return;
    }
    setState(() => _busy = true);
    try {
      final cat = await pickCat(context, cats, type.name);
      if (cat == null) {
        return;
      }
      late final String id;
      final saved = await guardSave(
        log: log,
        messenger: messenger,
        what: '記録の追加',
        action: () async => id = await repo.addRecord(
          catId: cat.id,
          recordTypeId: type.id,
          author: session.author,
          recordedAt: defaultRecordedAt(widget.day, now),
        ),
      );
      if (!saved) {
        return;
      }
      final done = await router.push<bool>('/records/$id/edit');
      if (done == true) {
        // ④保存できたら閉じて、保存したことを開いた側へ返す。
        // 日別一覧から開いたときはそのまま日別一覧に戻り、カレンダーの長押しから開いたときは、
        // カレンダーがその日の日別一覧を開く（S-24 の④。#272）
        if (mounted) {
          context.pop(true);
        }
        return;
      }
      // 保存せずに戻ったので、③のために作った記録を消す
      await guardSave(
        log: log,
        messenger: messenger,
        what: '記録の取り消し',
        action: () => repo.deleteRecord(id: id, author: session.author),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    final types = ref.watch(orderedRecordTypesProvider).value ?? const [];
    // ボタンを押す前に猫の一覧を読み込んでおく
    final cats = ref.watch(activeCatsProvider).value ?? const [];
    final day = widget.day;
    // 未来の日は記録を始めない（BR-35）。画面からは開けないが、道筋を直接開かれたときの守り
    if (!canRecordOn(day, ref.watch(nowProvider)())) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('未来の日には記録できません')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('${day.month}月${day.day}日の記録')),
      body: session == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  '項目を選んでください',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                GridView(
                  gridDelegate: recordTypeGrid(context),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final t in types)
                      RecordTypeButton(
                        type: t,
                        onPressed: _busy
                            ? null
                            : () => _start(t, cats, session),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
