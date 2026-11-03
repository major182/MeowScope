import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../data/photo_picker.dart';
import '../data/photo_repository.dart';

/// 記録の写真の一覧
final recordPhotosProvider =
    StreamProvider.family<List<RecordPhotoRow>, String>(
      (ref, recordId) =>
          ref.watch(photoRepositoryProvider).watchPhotos(recordId),
    );

/// 写真を表示するための中身
sealed class PhotoImage {
  const PhotoImage();
}

class PhotoBytes extends PhotoImage {
  const PhotoBytes(this.bytes);

  final Uint8List bytes;
}

/// 端末になく、サーバーから取れなかった（オフラインなど。BR-28）
class PhotoOffline extends PhotoImage {
  const PhotoOffline();
}

/// まだ相手の端末から送られていない
class PhotoNotYetUploaded extends PhotoImage {
  const PhotoNotYetUploaded();
}

/// 写真の中身を、端末のファイル → サーバーの順に探す。サーバーから取った画像は端末に保存しない（30日の管理を増やさないため）
final photoImageProvider = FutureProvider.autoDispose
    .family<PhotoImage, RecordPhotoRow>((ref, photo) async {
      final file = await ref.read(photoRepositoryProvider).localFile(photo.id);
      if (file != null) {
        return PhotoBytes(await file.readAsBytes());
      }
      if (!photo.uploaded) {
        return const PhotoNotYetUploaded();
      }
      try {
        final response = await ref
            .read(apiClientProvider)
            .get<List<int>>(
              '/photos/${photo.id}',
              options: Options(responseType: ResponseType.bytes),
            );
        return PhotoBytes(Uint8List.fromList(response.data!));
      } on DioException {
        return const PhotoOffline();
      }
    });

/// 写真1枚の小さな表示
class PhotoThumb extends ConsumerWidget {
  const PhotoThumb({super.key, required this.photo, this.size = 96});

  final RecordPhotoRow photo;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(photoImageProvider(photo));
    final Widget child = switch (image.value) {
      PhotoBytes(:final bytes) => Image.memory(bytes, fit: BoxFit.cover),
      PhotoOffline() => const _Note('オンラインで表示できます'),
      PhotoNotYetUploaded() => const _Note('まだ届いていません'),
      null => const Center(child: CircularProgressIndicator()),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}

/// 記録の詳細（S-22）に出す写真。なければ何も出さない
class PhotoGallery extends ConsumerWidget {
  const PhotoGallery({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(recordPhotosProvider(recordId)).value ?? const [];
    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final p in photos) PhotoThumb(photo: p, size: 120)],
      ),
    );
  }
}

/// 記録の詳細入力（S-12）の写真の欄。3枚まで付けられ、外せる（AC-03）
class PhotoEditor extends ConsumerWidget {
  const PhotoEditor({super.key, required this.recordId});

  final String recordId;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    // カメラは Android だけ。Windows はファイルを選ぶ
    final source = defaultTargetPlatform == TargetPlatform.android
        ? await showModalBottomSheet<PhotoSource>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera),
                    title: const Text('カメラで撮る'),
                    onTap: () => Navigator.pop(context, PhotoSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('アルバムから選ぶ'),
                    onTap: () => Navigator.pop(context, PhotoSource.gallery),
                  ),
                ],
              ),
            ),
          )
        : PhotoSource.gallery;
    if (source == null) {
      return;
    }
    final bytes = await ref.read(photoPickerProvider).pick(source);
    final user = ref.read(authUserProvider).value;
    if (bytes == null || user == null) {
      return;
    }
    try {
      await ref
          .read(photoRepositoryProvider)
          .addPhoto(recordId: recordId, userId: user.id, bytes: bytes);
    } on PhotoUnreadable {
      messenger.showSnackBar(const SnackBar(content: Text('この画像は読み込めませんでした')));
    } on PhotoLimitReached {
      messenger.showSnackBar(
        const SnackBar(content: Text('写真は$maxPhotosPerRecord枚までです')),
      );
    }
  }

  Future<void> _remove(WidgetRef ref, RecordPhotoRow photo) async {
    final user = ref.read(authUserProvider).value;
    if (user != null) {
      await ref
          .read(photoRepositoryProvider)
          .removePhoto(photoId: photo.id, userId: user.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.read で読めるよう、ログイン中のユーザーを見張っておく
    ref.watch(authUserProvider);
    final photos = ref.watch(recordPhotosProvider(recordId)).value ?? const [];
    final full = photos.length >= maxPhotosPerRecord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('写真（$maxPhotosPerRecord枚まで）'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in photos)
              Stack(
                children: [
                  PhotoThumb(photo: p),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      tooltip: '写真を外す',
                      iconSize: 16,
                      onPressed: () => _remove(ref, p),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: full ? null : () => _add(context, ref),
          icon: const Icon(Icons.add_a_photo),
          label: Text(full ? '写真は$maxPhotosPerRecord枚までです' : '写真を追加'),
        ),
      ],
    );
  }
}
