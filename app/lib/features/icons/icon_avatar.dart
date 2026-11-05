import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/providers.dart';
import '../photos/data/photo_picker.dart';
import '../photos/data/photo_repository.dart' show PhotoUnreadable;
import 'icon_repository.dart';

/// アイコンの画像。テストでは差し替える
final iconImageProvider = FutureProvider.autoDispose
    .family<Uint8List?, IconRef>(
      (ref, icon) => ref.read(iconRepositoryProvider).load(icon),
    );

/// 丸いアイコン。なければ既定のイラスト（猫：default_cat、ユーザー：default_user）を出す
class IconAvatar extends ConsumerWidget {
  const IconAvatar({super.key, required this.icon, this.radius = 20});

  final IconRef icon;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(iconImageProvider(icon)).value;
    final fallback = icon.owner == IconOwner.cat
        ? 'assets/icons/default_cat.png'
        : 'assets/icons/default_user.png';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: bytes == null
          ? AssetImage(fallback)
          : MemoryImage(bytes) as ImageProvider,
    );
  }
}

/// 押すとアイコンを選び直せるアイコン（S-45、猫のプロフィール）
class EditableIcon extends ConsumerWidget {
  const EditableIcon({super.key, required this.icon});

  final IconRef icon;

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    // 画像を選ぶ間に画面が閉じても使えるよう、先に取っておく（閉じた後の ref は使えない）
    final container = ProviderScope.containerOf(context);
    final repo = ref.read(iconRepositoryProvider);
    final bytes = await ref.read(photoPickerProvider).pick(PhotoSource.gallery);
    if (bytes == null) {
      return;
    }
    try {
      await repo.setIcon(icon.owner, icon.id, bytes);
      container.invalidate(iconImageProvider(icon));
      messenger.showSnackBar(const SnackBar(content: Text('アイコンを変更しました')));
    } on PhotoUnreadable {
      messenger.showSnackBar(const SnackBar(content: Text('この画像は読み込めませんでした')));
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _change(context, ref),
        child: Column(
          children: [
            IconAvatar(icon: icon, radius: 40),
            const SizedBox(height: 4),
            const Text('アイコンを変える'),
          ],
        ),
      ),
    );
  }
}
