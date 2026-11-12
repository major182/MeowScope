import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';

/// 版が読めないときにログに書く値
const unknownVersion = 'unknown';

/// 端末のログ（F-LG-03、F-LG-04、ログ設計書 8章）
///
/// - 同期の失敗・例外・クラッシュを端末の DB に記録し、同期のときにサーバーへ送る
/// - 最新の [maxStored] 件まで持ち、古いものから消す。サーバーが止まっていても端末の動作を妨げない
/// - 出さない情報を守る：メールアドレスに見える文字列を伏せ、記録の内容は書かない（呼ぶ側で種類と ID だけを渡す）
class AppLog {
  AppLog(
    this._db, {
    DateTime Function()? clock,
    Future<String> Function()? version,
  }) : _clock = clock ?? DateTime.now,
       _version = version ?? (() async => unknownVersion);

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// 今の版（画面と同じ pubspec.yaml の版。F-UP-03）。版の出どころを1つにするため外から渡す
  final Future<String> Function() _version;

  /// 版を読む。読めなくてもログの書き出し・送信は止めない
  Future<String> _readVersion() async {
    try {
      return await _version();
    } on Object {
      return unknownVersion;
    }
  }

  static const maxStored = 1000;
  static const maxMessage = 2000;
  static const batchSize = 100;

  static final _email = RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+');

  /// メールアドレスを伏せ、長すぎる文を切る
  static String sanitize(String message) {
    final masked = message.replaceAll(_email, '***@***');
    return masked.length > maxMessage
        ? masked.substring(0, maxMessage)
        : masked;
  }

  Future<void> record(
    String status,
    String message, {
    String? requestId,
  }) async {
    try {
      await _db.transaction(() async {
        await _db
            .into(_db.clientLogs)
            .insert(
              ClientLogsCompanion.insert(
                status: status,
                message: sanitize(message),
                occurredAt: _clock().toUtc(),
                requestId: Value(requestId),
              ),
            );
        // 最新の1000件だけを残す
        await _db.customStatement(
          'DELETE FROM client_logs WHERE seq NOT IN '
          '(SELECT seq FROM client_logs ORDER BY seq DESC LIMIT $maxStored)',
        );
      });
    } on Object {
      // ログが書けなくても、アプリの操作は止めない
    }
  }

  /// 問い合わせのために書き出す文（S-06）。古い順に1行1件
  Future<String> exportText() async {
    final rows = await (_db.select(
      _db.clientLogs,
    )..orderBy([(l) => OrderingTerm.asc(l.seq)])).get();
    final version = await _readVersion();
    final header =
        'MeowScope $version / ${_platform()} / ${Platform.operatingSystemVersion}';
    return [
      header,
      for (final r in rows)
        '${r.occurredAt.toUtc().toIso8601String()} [${r.status}] ${r.message}'
            '${r.requestId == null ? '' : ' (問い合わせ番号：${r.requestId})'}',
    ].join('\n');
  }

  /// 送っていないログをサーバーへ送る。送れたものは消す。失敗しても例外は投げない
  Future<void> send(Dio api) async {
    try {
      final version = await _readVersion();
      while (true) {
        final rows =
            await (_db.select(_db.clientLogs)
                  ..orderBy([(l) => OrderingTerm.asc(l.seq)])
                  ..limit(batchSize))
                .get();
        if (rows.isEmpty) {
          return;
        }
        await api.post<void>(
          '/client-logs',
          data: {
            'logs': [
              for (final r in rows)
                {
                  'status': r.status,
                  'message': r.message,
                  'occurredAt': r.occurredAt.toUtc().toIso8601String(),
                  'platform': _platform(),
                  'appVersion': version,
                  'osVersion': _osVersion(),
                  'requestId': r.requestId,
                },
            ],
          },
        );
        await (_db.delete(
          _db.clientLogs,
        )..where((l) => l.seq.isSmallerOrEqualValue(rows.last.seq))).go();
      }
    } on DioException {
      // 次の同期で送り直す
    }
  }

  /// OS の版（サーバーは 100 文字までを受け付ける）
  static String _osVersion() {
    final text = sanitize(Platform.operatingSystemVersion);
    return text.length > 100 ? text.substring(0, 100) : text;
  }

  static String _platform() =>
      defaultTargetPlatform == TargetPlatform.android ? 'android' : 'windows';
}
