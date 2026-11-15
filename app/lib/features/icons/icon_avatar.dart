import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/providers.dart';
import '../photos/data/photo_picker.dart';
import '../photos/data/photo_repository.dart' show PhotoUnreadable;
import '../photos/domain/photo_compress.dart';
import 'icon_crop_screen.dart';
import 'icon_repository.dart';

/// 切り抜きの画面に出す画像の長辺。拡大しても粗くならず、端末で重すぎない大きさ
const cropSourceMaxSide = 1600;

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

/// 小さなアイコンと名前を並べる。猫とユーザーの名前を出す場面で使う（画面設計書 1章「アイコン＋名前」）
class IconLabel extends StatelessWidget {
  const IconLabel({
    super.key,
    required this.icon,
    required this.text,
    this.radius = 12,
    this.style,
  });

  final IconRef icon;
  final String text;
  final double radius;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconAvatar(icon: icon, radius: radius),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: style)),
      ],
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
    // 先に向きを直して縮める。切り抜きの画面の表示と、切り抜く画像を同じにするため（F-SH-10）
    final prepared = compressPhoto(bytes, maxSide: cropSourceMaxSide);
    if (prepared == null) {
      messenger.showSnackBar(const SnackBar(content: Text('この画像は読み込めませんでした')));
      return;
    }
    if (!context.mounted) {
      return;
    }
    // どこを切り抜くかを選ぶ。閉じたら何もしない
    final cropped = await showIconCropper(context, prepared);
    if (cropped == null) {
      return;
    }
    try {
      await repo.setIcon(icon.owner, icon.id, cropped);
      // 表示は版ごとに分かれている。送信の後の同期で版が変わると、新しい版の表示が
      // 先に古いファイルを読んでしまうことがあるので、版に関係なく全部を読み直す（#248）
      container.invalidate(iconImageProvider);
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
