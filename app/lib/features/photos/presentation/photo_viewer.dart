import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import 'photo_widgets.dart';

/// ダブルタップで拡大するときの倍率
const photoDoubleTapScale = 2.5;

/// 拡大できる最大の倍率
const photoMaxScale = 5.0;

/// 記録の写真を全画面で開く（F-RC-06、画面設計書 S-22）
///
/// 確認の小窓と同じく、今の画面の上に重ねて開く（URL を持つ画面にはしない）。閉じると元の画面に戻る
Future<void> showPhotoViewer(
  BuildContext context, {
  required List<RecordPhotoRow> photos,
  required int initialIndex,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) =>
          PhotoViewer(photos: photos, initialIndex: initialIndex),
    ),
  );
}

/// 写真の全画面表示。左右にめくり、指・ホイール・ダブルタップで拡大する
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<RecordPhotoRow> photos;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  /// 今の写真を拡大しているか。拡大中はめくらない（拡大した写真を指で動かせるように）
  var _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0 || index >= widget.photos.length) {
      return;
    }
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.photos.length;
    // 写真が引き立つよう、背景は黒にする
    return CallbackShortcuts(
      // Windows：矢印のキーでめくる
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _go(_index - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _go(_index + 1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: count > 1 ? Text('${_index + 1} / $count') : null,
          ),
          body: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: count,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _zoomed = false;
                }),
                itemBuilder: (context, i) => _ZoomablePhoto(
                  photo: widget.photos[i],
                  onZoomChanged: (zoomed) {
                    if (zoomed != _zoomed) {
                      setState(() => _zoomed = zoomed);
                    }
                  },
                ),
              ),
              // 前後のボタン。Windows はマウスでめくれないので、ボタンでめくる
              if (count > 1) ...[
                if (_index > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _PageButton(
                      tooltip: '前の写真',
                      icon: Icons.chevron_left,
                      onPressed: () => _go(_index - 1),
                    ),
                  ),
                if (_index < count - 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _PageButton(
                      tooltip: '次の写真',
                      icon: Icons.chevron_right,
                      onPressed: () => _go(_index + 1),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

/// 1枚の写真。InteractiveViewer で、指で広げる・ホイール・ダブルタップで拡大する
class _ZoomablePhoto extends ConsumerStatefulWidget {
  const _ZoomablePhoto({required this.photo, required this.onZoomChanged});

  final RecordPhotoRow photo;
  final ValueChanged<bool> onZoomChanged;

  @override
  ConsumerState<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends ConsumerState<_ZoomablePhoto> {
  final _transform = TransformationController();

  /// ダブルタップした場所（そこを中心に拡大する）
  Offset _tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform.addListener(
      () => widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01),
    );
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// 拡大していれば元に戻し、そうでなければ押した場所を中心に拡大する
  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }
    const s = photoDoubleTapScale;
    // 押した点が拡大の後も同じ場所に来るよう、ずらしてから拡大する
    _transform.value = Matrix4.identity()
      ..translateByDouble(-_tapAt.dx * (s - 1), -_tapAt.dy * (s - 1), 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final image = ref.watch(photoImageProvider(widget.photo));
    return switch (image.value) {
      PhotoBytes(:final bytes) => GestureDetector(
        onDoubleTapDown: (d) => _tapAt = d.localPosition,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _transform,
          maxScale: photoMaxScale,
          child: SizedBox.expand(
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
      // 取れない写真は、小さな表示と同じ案内を出す（BR-28）
      PhotoOffline() => const _Message('オンラインで表示できます'),
      PhotoNotYetUploaded() => const _Message('まだ届いていません'),
      null => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
