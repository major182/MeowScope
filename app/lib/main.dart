import 'dart:ui';

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
      child: const MeowScopeApp(),
    ),
  );
}

class MeowScopeApp extends StatefulWidget {
  const MeowScopeApp({super.key});

  @override
  State<MeowScopeApp> createState() => _MeowScopeAppState();
}

class _MeowScopeAppState extends State<MeowScopeApp> {
  final GoRouter _router = createRouter();

  @override
  void dispose() {
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
