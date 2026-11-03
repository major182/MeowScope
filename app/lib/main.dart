import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/router.dart';

void main() {
  runApp(const ProviderScope(child: MeowScopeApp()));
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
