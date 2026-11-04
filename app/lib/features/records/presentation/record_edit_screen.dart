import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../photos/presentation/photo_widgets.dart';
import '../data/record_repository.dart';
import '../domain/record_detail.dart';
import '../../../core/widgets/readable_width.dart';
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
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final r = widget.view.record;
    _recordedAt = r.recordedAt.toLocal();
    _level = RecordLevel.parse(r.level);
    _weight = TextEditingController(text: r.valueNumber?.toString() ?? '');
    _memo = TextEditingController(text: r.memo ?? '');
  }

  @override
  void dispose() {
    _weight.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
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
    if (time == null) {
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
    await ref
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
        );
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    // 保存のときにセッションを使うので、読み込んでおく
    ref.watch(sessionProvider);
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
