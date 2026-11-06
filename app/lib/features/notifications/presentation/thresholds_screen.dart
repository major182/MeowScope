import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/readable_width.dart';
import '../../../core/widgets/save_guard.dart';
import '../../records/domain/record_kind.dart';
import '../domain/anomaly.dart';

/// しきい値の対象の猫（お別れを除く）
final _catsProvider = StreamProvider.autoDispose<List<CatRow>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(recordRepositoryProvider)
      .watchActiveCats(session.householdId);
});

/// しきい値の入力チェックの文（S-47）
const countRangeMessage = '0〜99の数字で入れてください';
const minMaxMessage = '下限は上限以下にしてください';
const percentRangeMessage = '1〜50の数字で入れてください';

/// しきい値の設定（S-47、BR-20）
///
/// 猫ごとに、回数の1日の下限と上限（どちらも任意）と、体重のふだんとの差の割合を決める。
/// 猫のデータとして同期し、家族と共有する
class ThresholdsScreen extends ConsumerStatefulWidget {
  const ThresholdsScreen({super.key});

  @override
  ConsumerState<ThresholdsScreen> createState() => _ThresholdsScreenState();
}

class _ThresholdsScreenState extends ConsumerState<ThresholdsScreen> {
  String? _catId;
  final _min = {for (final k in anomalyCountKinds) k: TextEditingController()};
  final _max = {for (final k in anomalyCountKinds) k: TextEditingController()};
  final _percent = TextEditingController();
  final _errors = <String, String>{};
  var _saving = false;

  @override
  void dispose() {
    for (final c in [..._min.values, ..._max.values, _percent]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 選んだ猫の保存したしきい値を欄に入れる
  void _load(CatRow cat) {
    final t = CatThresholds.parse(cat.anomalyThresholds);
    for (final kind in anomalyCountKinds) {
      _min[kind]!.text = '${t.counts[kind]?.min ?? ''}';
      _max[kind]!.text = '${t.counts[kind]?.max ?? ''}';
    }
    _percent.text = '${t.weightPercent ?? defaultWeightPercent}';
    _errors.clear();
  }

  /// 空なら null、数字でなく範囲の外なら [error] を返す
  static ({int? value, bool ok}) _read(String text, int min, int max) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return (value: null, ok: true);
    }
    final v = int.tryParse(trimmed);
    return v == null || v < min || v > max
        ? (value: null, ok: false)
        : (value: v, ok: true);
  }

  Future<void> _save(String catId) async {
    final errors = <String, String>{};
    final counts = <String, ({int? min, int? max})>{};
    for (final kind in anomalyCountKinds) {
      final min = _read(_min[kind]!.text, 0, 99);
      final max = _read(_max[kind]!.text, 0, 99);
      if (!min.ok) {
        errors['$kind.min'] = countRangeMessage;
      }
      if (!max.ok) {
        errors['$kind.max'] = countRangeMessage;
      }
      if (min.ok &&
          max.ok &&
          min.value != null &&
          max.value != null &&
          min.value! > max.value!) {
        errors['$kind.min'] = minMaxMessage;
      }
      counts[kind] = (min: min.value, max: max.value);
    }
    final percent = _read(_percent.text, 1, 50);
    if (!percent.ok || percent.value == null) {
      errors['weight'] = percentRangeMessage;
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    if (errors.isNotEmpty || _saving) {
      return;
    }
    final json = CatThresholds(
      counts: counts,
      // 既定（5%）のままなら保存しない（既定が変わったときに追いつけるように）
      weightPercent: percent.value == defaultWeightPercent
          ? null
          : percent.value,
    ).toJson();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await guardSave(
      log: ref.read(appLogProvider),
      messenger: messenger,
      what: 'しきい値の保存',
      action: () => ref
          .read(catRepositoryProvider)
          .setThresholds(
            id: catId,
            userId: ref.read(authUserProvider).value!.id,
            thresholds: json,
          ),
    );
    if (mounted) {
      setState(() => _saving = false);
    }
    if (saved) {
      messenger.showSnackBar(const SnackBar(content: Text('しきい値を保存しました')));
    }
  }

  Widget _field(TextEditingController c, String label, String? error) =>
      SizedBox(
        width: 88,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            errorText: error,
            errorMaxLines: 3,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // 保存のときにユーザーを使うので、読み込んでおく
    ref.watch(authUserProvider);
    final cats = ref.watch(_catsProvider).value;
    if (cats == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (cats.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('しきい値の設定')),
        body: const Center(child: Text('猫が登録されていません')),
      );
    }
    // 最初は先頭の猫。選んでいた猫が消えたら先頭に戻す
    final cat = cats.firstWhere(
      (c) => c.id == _catId,
      orElse: () => cats.first,
    );
    if (cat.id != _catId) {
      _catId = cat.id;
      _load(cat);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('しきい値の設定')),
      body: ListView(
        padding: readablePadding(context, 16),
        children: [
          DropdownButton<String>(
            value: cat.id,
            onChanged: (id) {
              final next = cats.firstWhere((c) => c.id == id);
              setState(() {
                _catId = next.id;
                _load(next);
              });
            },
            items: [
              for (final c in cats)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('1日の回数の下限と上限（空ならその向きは判定しません）'),
          for (final kind in anomalyCountKinds)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(RecordKind.values.byName(kind).label),
                    ),
                  ),
                  _field(_min[kind]!, '下限', _errors['$kind.min']),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 16, 8, 0),
                    child: Text('〜'),
                  ),
                  _field(_max[kind]!, '上限', _errors['$kind.max']),
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 16),
                    child: Text('回'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 80,
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('体重'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 16, right: 8),
                child: Text('±'),
              ),
              _field(_percent, '', _errors['weight']),
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 16),
                child: Text('%'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : () => _save(cat.id),
            child: const Text('保存する'),
          ),
        ],
      ),
    );
  }
}
