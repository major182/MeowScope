import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app_links/app_links.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/router.dart';
import 'core/providers.dart';

void main() {
  final container = ProviderContainer();
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
  runApp(
    UncontrolledProviderScope(
      container: container,
      // Android は招待のリンク（meowscope://invite?token=...）を押すとアプリが開く
      child: MeowScopeApp(
        links: Platform.isAndroid ? AppLinks().uriLinkStream : null,
      ),
    ),
  );
}

class MeowScopeApp extends StatefulWidget {
  const MeowScopeApp({super.key, this.links});

  /// 開かれたリンク。テストでは決めた値を流す
  final Stream<Uri>? links;

  @override
  State<MeowScopeApp> createState() => _MeowScopeAppState();
}

class _MeowScopeAppState extends State<MeowScopeApp> {
  final GoRouter _router = createRouter();
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    _links = widget.links?.listen(_open);
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
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MeowScope',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFC2662D)),
      routerConfig: _router,
    );
  }
}
