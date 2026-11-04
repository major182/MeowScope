import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../../auth/domain/credentials.dart';
import '../../sync/presentation/sync_controller.dart';

/// 招待されたおうちに参加（S-04 から開く。Android は招待のリンクを押しても開く）
///
/// 招待の文をそのまま貼り付けてもよい（リンクの中のトークンを取り出す）
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.token});

  /// リンクから開いたときのトークン
  final String? token;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final _text = TextEditingController(text: widget.token ?? '');
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final user = ref.read(authUserProvider).value;
    final token = extractInviteToken(_text.text);
    if (user == null) {
      setState(() => _error = 'ログインしてから参加してください');
      return;
    }
    if (token == null) {
      setState(() => _error = '招待の文かリンクを貼り付けてください');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    try {
      await ref
          .read(accountRepositoryProvider)
          .acceptInvitation(userId: user.id, token: token);
      // すぐに同期して、おうちの猫と記録を受け取る。待たずにホームへ進む（届いたら画面が変わる）
      unawaited(ref.read(syncControllerProvider.notifier).sync());
      router.go('/');
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message({
            404: 'この招待は使えません（期限切れか、使用済みです）。招待した人に作り直してもらってください',
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.read で読めるよう、ログイン中のユーザーを見張っておく
    ref.watch(authUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('招待されたおうちに参加')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('LINE などで届いた招待の文を、そのまま貼り付けてください'),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '招待の文',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _sending ? null : _join,
            child: const Text('参加する'),
          ),
        ],
      ),
    );
  }
}
