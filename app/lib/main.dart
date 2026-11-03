import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';

void main() {
  runApp(const ProviderScope(child: MeowScopeApp()));
}

class MeowScopeApp extends StatelessWidget {
  const MeowScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MeowScope',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFC2662D)),
      routerConfig: router,
    );
  }
}
