import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app_links/app_links.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/router.dart';
import 'core/providers.dart';
import 'features/notifications/data/notifier.dart';
import 'features/widget/widget_bridge.dart';

/// 通知を押したときに開く場所（payload）。画面の側で聞いて開く
final _notificationTaps = StreamController<String?>.broadcast();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android は OS の通知を使う。Windows はアプリの画面の中で知らせる（BR-09。既定の版のまま）
  final AppNotifier? notifier = Platform.isAndroid
      ? await AndroidNotifier.create(onTap: _notificationTaps.add)
      // Windows は画面の中で知らせ、窓が手前になければタスクバーのアイコンを点滅させる
      : Platform.isWindows
      ? InAppNotifier(attention: flashTaskbar)
      : null;
  final container = ProviderContainer(
    overrides: [
      if (notifier != null) notifierProvider.overrideWithValue(notifier),
    ],
  );
  // 例外とクラッシュを端末のログに残す（F-LG-03）。内容に記録が含まれないよう、種類と場所だけを書く
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    container
        .read(appLogProvider)
        .record(
          'error',
          '画面の例外：${details.exception.runtimeType}（${details.library}）',
        );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    container
        .read(appLogProvider)
        .record('critical', '想定外の例外：${error.runtimeType}');
    return true;
  };
  if (Platform.isAndroid) {
    startWidgetBridge(container);
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      // Android は招待のリンク（meowscope://invite?token=...）を押すとアプリが開く
      child: MeowScopeApp(
        links: Platform.isAndroid ? AppLinks().uriLinkStream : null,
        notificationTaps: _notificationTaps.stream,
      ),
    ),
  );
}

class MeowScopeApp extends StatefulWidget {
  const MeowScopeApp({super.key, this.links, this.notificationTaps});

  /// 開かれたリンク。テストでは決めた値を流す
  final Stream<Uri>? links;

  /// 押された通知の開く場所（Android）
  final Stream<String?>? notificationTaps;

  @override
  State<MeowScopeApp> createState() => _MeowScopeAppState();
}

class _MeowScopeAppState extends State<MeowScopeApp> {
  final GoRouter _router = createRouter();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _links;
  StreamSubscription<String?>? _taps;
  StreamSubscription<AppNotification>? _inApp;

  @override
  void initState() {
    super.initState();
    _links = widget.links?.listen(_open);
    _taps = widget.notificationTaps?.listen(_openPath);
    // Windows（とテスト）は、知らせる内容を画面の下に出す（BR-09）
    final notifier = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(notifierProvider);
    if (notifier is InAppNotifier) {
      _inApp = notifier.stream.listen(_showInApp);
    }
  }

  void _openPath(String? path) {
    if (path != null && path.startsWith('/')) {
      _router.push(path);
    }
  }

  void _showInApp(AppNotification n) {
    _messenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(n.body == null ? n.title : '${n.title}\n${n.body}'),
        duration: const Duration(seconds: 6),
        persist: false,
        action: n.payload == null
            ? null
            : SnackBarAction(
                label: '開く',
                onPressed: () => _openPath(n.payload),
              ),
      ),
    );
  }

  /// 招待のリンクなら、参加の画面を開く
  void _open(Uri uri) {
    final token = uri.queryParameters['token'];
    if (uri.scheme == 'meowscope' && uri.host == 'invite' && token != null) {
      _router.push(
        Uri(path: '/join', queryParameters: {'token': token}).toString(),
      );
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    _taps?.cancel();
    _inApp?.cancel();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MeowScope',
      scaffoldMessengerKey: _messenger,
      // 日本語のアプリとして表示する。指定しないと、日本語と中国語で共通の漢字が中国語の字形で出ることがある
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFC2662D)),
      routerConfig: _router,
    );
  }
}
