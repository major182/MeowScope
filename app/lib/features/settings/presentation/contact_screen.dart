import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/readable_width.dart';

/// 問い合わせ先。リポジトリには書かず、ビルドのときに `--dart-define=CONTACT_EMAIL=...` で渡す（ログ設計書 8章）
const contactEmail = String.fromEnvironment('CONTACT_EMAIL');

/// ログの書き出しと問い合わせの案内（S-06、F-LG-04）。ログイン前（S-07）からも開ける
class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key, this.address = contactEmail});

  /// 問い合わせ先（テストでは値を渡す）
  final String address;

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final text = await ref.read(appLogProvider).exportText();
      final path = await ref.read(logFileSaverProvider)(text);
      messenger.showSnackBar(SnackBar(content: Text('保存しました：$path')));
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('保存できませんでした。「ログをコピーする」を使ってください')),
      );
    }
  }

  Future<void> _copyLog(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: await ref.read(appLogProvider).exportText()),
    );
    messenger.showSnackBar(const SnackBar(content: Text('ログをコピーしました')));
  }

  Future<void> _copyAddress(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: address));
    messenger.showSnackBar(const SnackBar(content: Text('宛先をコピーしました')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAddress = address.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('問い合わせ')),
      body: ListView(
        padding: readablePadding(context, 16),
        children: [
          const Text('不具合があったときは、ログを保存して次の宛先へ添付して連絡してください'),
          const SizedBox(height: 12),
          Text('問い合わせ先：${hasAddress ? address : '（このアプリには設定されていません）'}'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _save(context, ref),
            child: const Text('ログを保存する'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _copyLog(context, ref),
            child: const Text('ログをコピーする'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: hasAddress ? () => _copyAddress(context) : null,
            child: const Text('宛先をコピーする'),
          ),
        ],
      ),
    );
  }
}
