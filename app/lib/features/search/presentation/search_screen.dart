import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/today.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/readable_width.dart';
import '../../calendar/domain/calendar_month.dart';
import '../../cats/presentation/cat_filter.dart';
import '../../icons/icon_avatar.dart';
import '../../records/data/record_repository.dart';
import '../../records/presentation/record_format.dart';
import '../../records/presentation/record_providers.dart';
import '../../sync/presentation/sync_controller.dart';
import '../domain/record_search.dart';

/// 条件に合う記録を、新しい順に見張る。同期で記録が届いたら出し直す
final searchResultsProvider = StreamProvider.autoDispose
    .family<List<RecordEntry>, SearchQuery>((ref, query) {
      final session = ref.watch(sessionProvider).value;
      if (session == null) {
        return Stream.value(const []);
      }
      return ref
          .watch(recordRepositoryProvider)
          .watchSearch(session.householdId, query);
    });

/// 記録の検索（S-23。F-VW-03）
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _words = TextEditingController();
  SearchQuery _query = emptyQuery;

  @override
  void initState() {
    super.initState();
    // 開いたとき1回だけ同期し、ほかの端末の記録も探せるようにする（S-23）。
    // 失敗しても端末にある記録で探せるので、結果は待たない
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(syncControllerProvider.notifier).sync();
      }
    });
  }

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  void _update(SearchQuery query) => setState(() => _query = query);

  /// 期間の端を選ぶ。もう一方の端を越えないよう、選べる範囲を絞る
  Future<void> _pickDate({required bool start}) async {
    final today = dateOnly(ref.read(nowProvider)());
    final from = _query.from;
    final to = _query.to;
    final picked = await showAppDatePicker(
      context: context,
      weekStart: ref.read(weekStartProvider).value ?? WeekStart.sunday,
      initialDate: (start ? from : to) ?? (start ? (to ?? today) : today),
      firstDate: start ? DateTime(2000) : (from ?? DateTime(2000)),
      lastDate: start ? (to ?? today) : today,
    );
    if (picked == null || !mounted) {
      return;
    }
    _update(
      start
          ? (
              words: _query.words,
              recordTypeId: _query.recordTypeId,
              catId: _query.catId,
              from: picked,
              to: _query.to,
            )
          : (
              words: _query.words,
              recordTypeId: _query.recordTypeId,
              catId: _query.catId,
              from: _query.from,
              to: picked,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 日付の選択で使うので読み込んでおく
    ref.watch(weekStartProvider);
    final types = ref.watch(allRecordTypesProvider).value ?? const [];
    final results = ref.watch(searchResultsProvider(_query));
    final words = splitWords(_query.words);
    // 広い窓では中身の幅を 640px までにして中央に寄せる（NF-UX-02。#274）
    final side = readablePadding(context, 12).left;
    return Scaffold(
      appBar: AppBar(title: const Text('記録の検索')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, 8, side, 0),
            child: TextField(
              controller: _words,
              decoration: const InputDecoration(
                labelText: 'メモの言葉',
                hintText: '空白で区切ると、すべてを含む記録',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (text) => _update((
                words: text,
                recordTypeId: _query.recordTypeId,
                catId: _query.catId,
                from: _query.from,
                to: _query.to,
              )),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            // 左に寄せる（列の中では、中身の幅のまま中央に置かれるため。S-23 の絵。#272）
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String?>(
                    value: types.any((t) => t.id == _query.recordTypeId)
                        ? _query.recordTypeId
                        : null,
                    onChanged: (id) => _update((
                      words: _query.words,
                      recordTypeId: id,
                      catId: _query.catId,
                      from: _query.from,
                      to: _query.to,
                    )),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('すべての項目'),
                      ),
                      // 非表示の項目も選べる（過去の記録を探すため）
                      for (final t in types)
                        DropdownMenuItem<String?>(
                          value: t.id,
                          child: Text(t.hidden ? '${t.name}（非表示中）' : t.name),
                        ),
                    ],
                  ),
                  // お別れの猫も選べる
                  CatFilter(
                    selected: _query.catId,
                    onChanged: (id) => _update((
                      words: _query.words,
                      recordTypeId: _query.recordTypeId,
                      catId: id,
                      from: _query.from,
                      to: _query.to,
                    )),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: Row(
              children: [
                const Text('期間'),
                const SizedBox(width: 8),
                _DateButton(
                  label: '始め',
                  value: _query.from,
                  onPressed: () => _pickDate(start: true),
                ),
                const Text('〜'),
                _DateButton(
                  label: '終わり',
                  value: _query.to,
                  onPressed: () => _pickDate(start: false),
                ),
                if (_query.from != null || _query.to != null)
                  IconButton(
                    tooltip: '期間を外す',
                    onPressed: () => _update((
                      words: _query.words,
                      recordTypeId: _query.recordTypeId,
                      catId: _query.catId,
                      from: null,
                      to: null,
                    )),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (results.value) {
              null => const Center(child: CircularProgressIndicator()),
              [] => const Center(child: Text('見つかりませんでした')),
              final list => ListView(
                // 一覧の行は自分で左右に 16 の余白を持つので、その分を引く
                padding: EdgeInsets.symmetric(horizontal: side - 12),
                children: [
                  for (final e in list)
                    ListTile(
                      leading: Text(formatDateTime(e.recordedAt)),
                      title: Align(
                        alignment: Alignment.centerLeft,
                        child: IconLabel(
                          icon: e.catIcon,
                          text: '${e.catName}　${e.typeName}',
                        ),
                      ),
                      subtitle: e.memo == null
                          ? null
                          : _HighlightedMemo(memo: e.memo!, words: words),
                      onTap: () => context.push('/records/${e.id}'),
                    ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// 期間の端のボタン。選んでいなければ名前（「始め」など）を出す
class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return TextButton(
      onPressed: onPressed,
      child: Text(v == null ? label : '${v.year}/${v.month}/${v.day}'),
    );
  }
}

/// メモを2行まで出し、当たった言葉に色を付ける（S-23）。
/// 当たった言葉が後ろにあれば、その少し前から出す
class _HighlightedMemo extends StatelessWidget {
  const _HighlightedMemo({required this.memo, required this.words});

  final String memo;
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ranges = matchRanges(memo, words);
    final start = snippetStart(ranges);
    final spans = <TextSpan>[if (start > 0) const TextSpan(text: '…')];
    var pos = start;
    for (final r in ranges) {
      if (r.start > pos) {
        spans.add(TextSpan(text: memo.substring(pos, r.start)));
      }
      spans.add(
        TextSpan(
          text: memo.substring(r.start, r.end),
          style: TextStyle(
            backgroundColor: scheme.tertiaryContainer,
            color: scheme.onTertiaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      pos = r.end;
    }
    if (pos < memo.length) {
      spans.add(TextSpan(text: memo.substring(pos)));
    }
    return Text.rich(
      TextSpan(text: 'メモ：', children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
