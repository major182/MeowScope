import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/readable_width.dart';
import '../../../core/widgets/save_guard.dart';
import '../data/medication_repository.dart';
import '../domain/medication_plan.dart';

/// 入力チェックの文（S-50）
const medicationNameRequired = '薬の名前を入力してください';
const medicationTooLong = '${MedicationRepository.maxLength}文字以内で入れてください';
const medicationCatRequired = '猫を選んでください';

/// 薬の名前の入力チェック。正しければ null
String? validateMedicationName(String? text) {
  final trimmed = text?.trim() ?? '';
  if (trimmed.isEmpty) {
    return medicationNameRequired;
  }
  return trimmed.length > MedicationRepository.maxLength
      ? medicationTooLong
      : null;
}

/// 量の入力チェック（任意）。正しければ null
String? validateMedicationDose(String? text) =>
    (text?.trim().length ?? 0) > MedicationRepository.maxLength
    ? medicationTooLong
    : null;

/// おうちの猫（お別れを含み、削除済みを除く）。選べるのはお別れでない猫と、編集中の予定の猫
final _catsProvider = StreamProvider.autoDispose<List<CatRow>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref.watch(recordRepositoryProvider).watchCats(session.householdId);
});

final _scheduleProvider = StreamProvider.autoDispose
    .family<MedicationScheduleRow?, String>(
      (ref, id) => ref.watch(medicationRepositoryProvider).watchSchedule(id),
    );

/// お薬の予定の追加と編集（S-50）。[scheduleId] がなければ追加
class MedicationFormScreen extends ConsumerWidget {
  const MedicationFormScreen({super.key, this.scheduleId});

  final String? scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(_catsProvider).value;
    List<CatRow>? choices(String? keep) => all == null
        ? null
        : [
            for (final c in all)
              if (c.status == 'active' || c.id == keep) c,
          ];
    final id = scheduleId;
    if (id == null) {
      final cats = choices(null);
      return cats == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _MedicationForm(cats: cats);
    }
    final schedule = ref.watch(_scheduleProvider(id));
    return switch ((all, schedule)) {
      (_?, AsyncData(value: final s?)) => _MedicationForm(
        key: ValueKey(s.id),
        cats: choices(s.catId)!,
        initial: s,
      ),
      (_, AsyncData(value: null)) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('この予定は削除されました')),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _MedicationForm extends ConsumerStatefulWidget {
  const _MedicationForm({super.key, required this.cats, this.initial});

  final List<CatRow> cats;
  final MedicationScheduleRow? initial;

  @override
  ConsumerState<_MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends ConsumerState<_MedicationForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _dose = TextEditingController(text: widget.initial?.dose);
  late String? _catId =
      widget.initial?.catId ??
      (widget.cats.length == 1 ? widget.cats.single.id : null);
  late var _time =
      parseTimeOfDay(widget.initial?.timeOfDay ?? '') ?? (hour: 8, minute: 0);
  late var _enabled = widget.initial?.enabled ?? true;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _time.hour, minute: _time.minute),
    );
    if (picked != null) {
      setState(() => _time = (hour: picked.hour, minute: picked.minute));
    }
  }

  Future<void> _save() async {
    final session = ref.read(sessionProvider).value;
    final catId = _catId;
    if (_saving ||
        session == null ||
        !_form.currentState!.validate() ||
        catId == null) {
      return;
    }
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(medicationRepositoryProvider);
    final time = formatTimeOfDay(_time.hour, _time.minute);
    final initial = widget.initial;
    final saved = await guardSave(
      log: ref.read(appLogProvider),
      messenger: messenger,
      what: 'お薬の予定の保存',
      action: () async {
        if (initial == null) {
          await repo.add(
            householdId: session.householdId,
            userId: session.author.id,
            catId: catId,
            name: _name.text,
            dose: _dose.text,
            timeOfDay: time,
            enabled: _enabled,
          );
        } else {
          await repo.update(
            id: initial.id,
            userId: session.author.id,
            catId: catId,
            name: _name.text,
            dose: _dose.text,
            timeOfDay: time,
            enabled: _enabled,
          );
        }
      },
    );
    if (!saved) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('お薬の予定を保存しました')));
    router.pop();
  }

  Future<void> _delete(MedicationScheduleRow schedule) async {
    final session = ref.read(sessionProvider).value;
    if (session == null) {
      return;
    }
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final log = ref.read(appLogProvider);
    final ok = await confirmDelete(
      context,
      title: '${schedule.name}の予定を削除しますか？',
      message: '家族の端末からも消え、お薬の時間の通知も止まります',
    );
    if (!ok) {
      return;
    }
    final deleted = await guardSave(
      log: log,
      messenger: messenger,
      what: 'お薬の予定の削除',
      action: () => ref
          .read(medicationRepositoryProvider)
          .delete(id: schedule.id, userId: session.author.id),
    );
    if (deleted) {
      router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    return Scaffold(
      appBar: AppBar(title: Text(initial == null ? '予定を追加' : '予定の編集')),
      body: Form(
        key: _form,
        child: ListView(
          padding: readablePadding(context, 16),
          children: [
            if (widget.cats.isEmpty && initial == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('予定を追加できる猫がいません。先に猫を登録してください'),
              ),
            DropdownButtonFormField<String>(
              initialValue: _catId,
              decoration: const InputDecoration(labelText: '猫'),
              // 編集中の予定の猫がお別れになっていても、選んだままにできる
              items: [
                for (final c in widget.cats)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      c.status == 'farewell' ? '${c.name}（お別れ）' : c.name,
                    ),
                  ),
              ],
              onChanged: (id) => setState(() => _catId = id),
              validator: (id) => id == null ? medicationCatRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '薬の名前'),
              validator: validateMedicationName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dose,
              decoration: const InputDecoration(labelText: '量（任意。例：1錠）'),
              validator: validateMedicationDose,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('時刻（毎日）'),
              subtitle: Text(formatTimeOfDay(_time.hour, _time.minute)),
              trailing: IconButton(
                tooltip: '時刻を選ぶ',
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule),
              ),
              onTap: _pickTime,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('通知する'),
              value: _enabled,
              onChanged: (on) => setState(() => _enabled = on),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || (widget.cats.isEmpty && initial == null)
                  ? null
                  : _save,
              child: const Text('保存する'),
            ),
            if (initial != null) ...[
              const Divider(height: 48),
              TextButton(
                onPressed: () => _delete(initial),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('削除する'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
