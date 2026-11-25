import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/today.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/readable_width.dart';
import '../../calendar/domain/calendar_month.dart';
import '../../cats/presentation/cat_filter.dart';
import '../../records/presentation/record_providers.dart';
import '../domain/record_csv.dart';

/// 保存の画面（Windows の「名前を付けて保存」）を出し、選ばれた場所を返す。やめたら null
///
/// テストでは本物の画面を出せないので、差し替えられるようにプロバイダーにする
final csvSaveLocationProvider = Provider<Future<String?> Function(String)>(
  (ref) => (suggestedName) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    return location?.path;
  },
);

/// 記録の CSV の出力（S-52。F-EX-01、BR-41）。Windows だけで開く
///
/// 期間・猫・項目で絞れる。どれも「すべて」も選べる。今のおうちの記録を、端末にあるものから出す
class CsvExportScreen extends ConsumerStatefulWidget {
  const CsvExportScreen({super.key});

  @override
  ConsumerState<CsvExportScreen> createState() => _CsvExportScreenState();
}

class _CsvExportScreenState extends ConsumerState<CsvExportScreen> {
  /// 全期間か
  var _allPeriod = true;
  DateTime? _from;
  DateTime? _to;

  /// 選んだ猫と項目。null は「すべて」
  Set<String>? _cats;
  Set<String>? _types;
  var _busy = false;

  /// 期間の端を選ぶ。もう一方の端を越えないよう、選べる範囲を絞る（S-23 と同じ）
  Future<void> _pickDate({required bool start}) async {
    final today = dateOnly(ref.read(nowProvider)());
    final picked = await showAppDatePicker(
      context: context,
      weekStart: ref.read(weekStartProvider).value ?? WeekStart.sunday,
      initialDate: (start ? _from : _to) ?? (start ? (_to ?? today) : today),
      firstDate: start ? DateTime(2000) : (_from ?? DateTime(2000)),
      lastDate: start ? (_to ?? today) : today,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => start ? _from = picked : _to = picked);
  }

  /// 出力できる条件がそろっているか。期間を指定するなら両端、絞るなら1つ以上
  bool get _ready =>
      (_allPeriod || (_from != null && _to != null)) &&
      (_cats?.isNotEmpty ?? true) &&
      (_types?.isNotEmpty ?? true);

  Future<void> _export() async {
    final session = ref.read(sessionProvider).value;
    if (session == null || !_ready || _busy) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final now = ref.read(nowProvider)();
    setState(() => _busy = true);
    try {
      var path = await ref.read(csvSaveLocationProvider)(suggestedCsvName(now));
      if (path == null) {
        return;
      }
      // 名前に拡張子を付け忘れても、CSV として開けるようにする
      if (!path.toLowerCase().endsWith('.csv')) {
        path = '$path.csv';
      }
      final CsvFilter filter = (
        from: _allPeriod ? null : _from,
        to: _allPeriod ? null : _to,
        catIds: _cats,
        recordTypeIds: _types,
      );
      final range = csvRange(filter, now);
      final records = await ref
          .read(recordRepositoryProvider)
          .range(session.householdId, from: range.from, to: range.to);
      final csv = buildRecordCsv(records, filter);
      await File(path).writeAsString(csv, flush: true);
      // 件数は、出した記録の数で数える（メモの中の改行を行と数えないため）
      final count = filterCsvRecords(records, filter).length;
      messenger.showSnackBar(SnackBar(content: Text('CSV を保存しました（$count件）')));
    } on FileSystemException {
      // 書き込めない場所（読み取り専用・ほかのアプリが開いている）など
      messenger.showSnackBar(
        const SnackBar(content: Text('保存できませんでした。別の場所か名前でお試しください')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 日付の選択で使うので読み込んでおく
    ref.watch(weekStartProvider);
    final cats = ref.watch(filterCatsProvider).value ?? const [];
    final types = ref.watch(allRecordTypesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('CSV の出力')),
      body: ListView(
        padding: readablePadding(context, 16),
        children: [
          Text('期間', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('全期間')),
              ButtonSegment(value: false, label: Text('期間を指定')),
            ],
            selected: {_allPeriod},
            onSelectionChanged: (s) => setState(() => _allPeriod = s.single),
          ),
          if (!_allPeriod) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => _pickDate(start: true),
                  child: Text(_from == null ? '開始日' : _label(_from!)),
                ),
                const Text('〜'),
                OutlinedButton(
                  onPressed: () => _pickDate(start: false),
                  child: Text(_to == null ? '終了日' : _label(_to!)),
                ),
              ],
            ),
          ],
          const Divider(height: 32),
          _Choices(
            title: '猫',
            allLabel: 'すべての猫',
            items: [for (final c in cats) (id: c.id, name: c.name)],
            selected: _cats,
            onChanged: (s) => setState(() => _cats = s),
          ),
          const Divider(height: 32),
          _Choices(
            title: '項目',
            allLabel: 'すべての項目',
            items: [for (final t in types) (id: t.id, name: t.name)],
            selected: _types,
            onChanged: (s) => setState(() => _types = s),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _ready && !_busy ? _export : null,
            icon: const Icon(Icons.download),
            label: const Text('CSV を出力'),
          ),
          const SizedBox(height: 8),
          Text(
            '1行に記録を1件出します。Excel で開けます（文字コードは UTF-8）',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _label(DateTime d) => '${d.year}/${d.month}/${d.day}';
}

/// 「すべて」か、選んだものだけか。[selected] が null なら「すべて」
class _Choices extends StatelessWidget {
  const _Choices({
    required this.title,
    required this.allLabel,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String allLabel;
  final List<({String id, String name})> items;
  final Set<String>? selected;
  final ValueChanged<Set<String>?> onChanged;

  @override
  Widget build(BuildContext context) {
    final all = selected == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(allLabel),
          value: all,
          // 絞るときは、はじめは何も選んでいない状態から選んでもらう
          onChanged: (v) => onChanged(v ? null : <String>{}),
        ),
        if (!all) ...[
          for (final item in items)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              value: selected!.contains(item.id),
              onChanged: (v) => onChanged(
                v ?? false
                    ? {...selected!, item.id}
                    : ({...selected!}..remove(item.id)),
              ),
            ),
          if (selected!.isEmpty)
            Text(
              '1つ以上選んでください',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ],
    );
  }
}
