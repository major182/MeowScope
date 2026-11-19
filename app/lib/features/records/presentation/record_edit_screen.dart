import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../photos/presentation/photo_widgets.dart';
import '../data/record_repository.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../calendar/domain/calendar_month.dart';
import '../domain/record_detail.dart';
import '../domain/vet_detail.dart';
import '../../../core/widgets/readable_width.dart';
import '../../../core/widgets/save_guard.dart';
import 'record_format.dart';
import 'record_providers.dart';

/// 記録の詳細入力（S-12）。保存の後の「詳細を追加」と、詳細の画面の「編集」から開く
class RecordEditScreen extends ConsumerWidget {
  const RecordEditScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(recordDetailProvider(recordId))
        .when(
          data: (view) => view == null
              ? const RecordNotFound()
              : _RecordForm(key: ValueKey(recordId), view: view),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) => const RecordNotFound(),
        );
  }
}

/// 記録が見つからないとき（削除された後など）
class RecordNotFound extends StatelessWidget {
  const RecordNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('この記録は見つかりません')),
    );
  }
}

class _RecordForm extends ConsumerStatefulWidget {
  const _RecordForm({super.key, required this.view});

  final RecordDetailView view;

  @override
  ConsumerState<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends ConsumerState<_RecordForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _recordedAt;
  late RecordLevel? _level;
  late final TextEditingController _weight;
  late final TextEditingController _memo;
  late final TextEditingController _hospital;

  /// 次の予定日（病院。F-MD-01）
  DateTime? _nextDate;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final r = widget.view.record;
    _recordedAt = r.recordedAt.toLocal();
    _level = RecordLevel.parse(r.level);
    _weight = TextEditingController(text: r.valueNumber?.toString() ?? '');
    _memo = TextEditingController(text: r.memo ?? '');
    final vet = VetDetail.parse(r.detail);
    _hospital = TextEditingController(text: vet.hospital ?? '');
    _nextDate = vet.nextDate;
  }

  @override
  void dispose() {
    _weight.dispose();
    _memo.dispose();
    _hospital.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    // 週の始まりはアプリの設定に合わせる（F-VW-04。日付の選択はどの画面でも showAppDatePicker を使う）
    final date = await showAppDatePicker(
      context: context,
      weekStart: ref.read(weekStartProvider).value ?? WeekStart.sunday,
      initialDate: _recordedAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _recordedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _dateError = null;
    });
  }

  /// 次の予定日を選ぶ（S-12）。今日より前の日は選べない
  Future<void> _pickNextDate() async {
    final today = dateOnly(DateTime.now());
    final current = _nextDate;
    final picked = await showAppDatePicker(
      context: context,
      weekStart: ref.read(weekStartProvider).value ?? WeekStart.sunday,
      // 前に選んだ日が過ぎていたら、今日から選び直す
      initialDate: current == null || current.isBefore(today) ? today : current,
      firstDate: today,
      lastDate: DateTime(today.year + 5, today.month, today.day),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _nextDate = picked);
  }

  Future<void> _save() async {
    final dateError = validateRecordedAt(_recordedAt, DateTime.now());
    setState(() => _dateError = dateError);
    if (!_formKey.currentState!.validate() || dateError != null) {
      return;
    }
    final session = ref.read(sessionProvider).value;
    if (session == null) {
      return;
    }
    final kind = widget.view.kind;
    final weight = _weight.text.trim();
    final saved = await guardSave(
      log: ref.read(appLogProvider),
      messenger: ScaffoldMessenger.of(context),
      what: '記録の保存',
      action: () => ref
          .read(recordRepositoryProvider)
          .updateRecord(
            id: widget.view.record.id,
            recordedAt: _recordedAt,
            level: hasLevel(kind) ? _level?.name : null,
            valueNumber: hasWeight(kind) && weight.isNotEmpty
                ? double.parse(weight)
                : null,
            memo: _memo.text,
            author: session.author,
            // 病院だけ、名前と次の予定日を detail に入れる。ほかの項目は今の detail を残す
            detail: hasVetDetail(kind)
                ? (
                    json: VetDetail(
                      hospital: _hospital.text.trim().isEmpty
                          ? null
                          : _hospital.text.trim(),
                      nextDate: _nextDate,
                    ).encode(),
                  )
                : null,
          ),
    );
    // 失敗したら画面に残り、入力をやり直せるようにする
    // 保存できたことを開いた側へ返す（日付からの記録で、作った記録を残すかの判断に使う）
    if (saved && mounted) {
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    // 保存のときにセッションを、日付の選択で週の始まりを使うので、読み込んでおく
    ref.watch(sessionProvider);
    ref.watch(weekStartProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(view.typeName),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: readablePadding(context, 16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('猫'),
              trailing: Text(view.catName),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日時'),
              subtitle: _dateError == null
                  ? null
                  : Text(
                      _dateError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
              trailing: OutlinedButton(
                onPressed: _pickDateTime,
                child: Text(formatDateTime(_recordedAt)),
              ),
            ),
            const SizedBox(height: 8),
            Text('以下は任意です', style: Theme.of(context).textTheme.bodySmall),
            if (hasLevel(view.kind)) ...[
              const SizedBox(height: 16),
              const Text('量'),
              const SizedBox(height: 8),
              SegmentedButton<RecordLevel>(
                segments: [
                  for (final l in RecordLevel.values)
                    ButtonSegment(value: l, label: Text(l.label)),
                ],
                selected: {?_level},
                emptySelectionAllowed: true,
                onSelectionChanged: (s) =>
                    setState(() => _level = s.isEmpty ? null : s.first),
              ),
            ],
            if (hasVetDetail(view.kind)) ...[
              const SizedBox(height: 16),
              _HospitalField(controller: _hospital),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('次の予定日'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: _pickNextDate,
                      child: Text(
                        _nextDate == null
                            ? '選ぶ'
                            : '${_nextDate!.year}/${_nextDate!.month}/${_nextDate!.day}',
                      ),
                    ),
                    if (_nextDate != null)
                      IconButton(
                        tooltip: '次の予定日を外す',
                        onPressed: () => setState(() => _nextDate = null),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
            ],
            if (hasWeight(view.kind)) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _weight,
                decoration: const InputDecoration(
                  labelText: '体重',
                  suffixText: 'kg',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: validateWeight,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _memo,
              decoration: const InputDecoration(labelText: 'メモ'),
              maxLines: 4,
              maxLength: maxMemoLength,
            ),
            const SizedBox(height: 16),
            // 写真はその場で保存する（「保存」を押さなくても付く）
            PhotoEditor(recordId: widget.view.record.id),
          ],
        ),
      ),
    );
  }
}

/// 病院の名前の入力欄（S-12）。同じおうちで前に入れた名前を候補に出す（F-MD-01）
class _HospitalField extends ConsumerStatefulWidget {
  const _HospitalField({required this.controller});

  final TextEditingController controller;

  @override
  ConsumerState<_HospitalField> createState() => _HospitalFieldState();
}

class _HospitalFieldState extends ConsumerState<_HospitalField> {
  /// 候補の表示と入力欄で同じものを使う。描き直しても入力中の状態が切れないよう、ここで持つ
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(hospitalNamesProvider);
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) => filterSuggestions(names, value.text),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(labelText: '病院の名前'),
            maxLength: maxHospitalLength,
            validator: validateHospital,
          ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(title: Text(o), onTap: () => onSelected(o)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
