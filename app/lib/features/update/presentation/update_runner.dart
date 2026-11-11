import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_release.dart';
import '../update_providers.dart';
import 'update_dialog.dart';

/// 起動したとき（ログインしていればすぐ、していなければログインした後）に更新を確かめ、
/// 新しい版があれば S-51 を出す（F-UP-01、BR-33）
///
/// 更新の API は認証が要るので、ログイン中だけ置く。「5分後」と設定の「更新を確かめる」の知らせもここで出す
class UpdateRunner extends ConsumerStatefulWidget {
  const UpdateRunner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateRunner> createState() => _UpdateRunnerState();
}

class _UpdateRunnerState extends ConsumerState<UpdateRunner> {
  var _showing = false;

  @override
  void initState() {
    super.initState();
    // 最初の表示が終わってから確かめる（表示の途中で状態を変えないため）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(updatePromptProvider.notifier).check();
    });
  }

  Future<void> _show(UpdateAvailable update) async {
    ref.read(updatePromptProvider.notifier).shown();
    // すでに出ていれば重ねない
    if (_showing) return;
    _showing = true;
    await showUpdateDialog(context, update);
    _showing = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(updatePromptProvider, (_, next) {
      if (next != null) _show(next);
    });
    return widget.child;
  }
}
