import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../domain/photo_compress.dart';

/// 1つの記録に付けられる写真の数（データ要件、AC-03）
const maxPhotosPerRecord = 3;

/// 端末に写真を置いておく日数（データ要件、AC-14）
const localPhotoDays = 30;

/// 写真が上限に達している
class PhotoLimitReached implements Exception {
  const PhotoLimitReached();
}

/// 画像として読めない
class PhotoUnreadable implements Exception {
  const PhotoUnreadable();
}

/// 記録の写真（F-RC-03）
///
/// - 付けるときは縮めてから端末のフォルダーに保存し、写真の情報を同期待ちに、画像を送信待ちに入れる
/// - 送信が終わっても30日は端末に残し、その後は消す（送信待ちの写真は消さない）
/// - 端末にない写真は、オンラインのときだけサーバーから取って表示する
class PhotoRepository {
  PhotoRepository(
    this._db,
    this._directory, {
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;

  /// 写真を置くフォルダー。端末のアプリ用フォルダーの下（テストでは一時フォルダー）
  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// 記録の写真（消したものを除き、何枚目かの順）
  Stream<List<RecordPhotoRow>> watchPhotos(String recordId) {
    final query = _db.select(_db.recordPhotos)
      ..where((p) => p.recordId.equals(recordId) & p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]);
    return query.watch();
  }

  /// 写真を付ける。空いている一番前の番号を使う
  ///
  /// [PhotoLimitReached]：もう3枚ある。[PhotoUnreadable]：画像として読めない
  Future<String> addPhoto({
    required String recordId,
    required String userId,
    required Uint8List bytes,
  }) async {
    final used = (await watchPhotos(
      recordId,
    ).first).map((p) => p.sortOrder).toSet();
    if (used.length >= maxPhotosPerRecord) {
      throw const PhotoLimitReached();
    }
    final compressed = compressPhoto(bytes);
    if (compressed == null) {
      throw const PhotoUnreadable();
    }
    final sort = [for (var i = 1; i <= maxPhotosPerRecord; i++) i]
        .firstWhere((i) => !used.contains(i));
    final id = _uuid.v4();
    final dir = await _directory();
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}$id.jpg');
    await file.writeAsBytes(compressed, flush: true);
    final now = _clock().toUtc();
    await _db.transaction(() async {
      await _db
          .into(_db.recordPhotos)
          .insert(
            RecordPhotosCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              recordId: recordId,
              sortOrder: sort,
              sizeBytes: Value(compressed.length),
            ),
          );
      await _db
          .into(_db.localPhotos)
          .insert(
            LocalPhotosCompanion.insert(
              photoId: id,
              localPath: file.path,
              savedAt: now,
            ),
          );
      await _db
          .into(_db.pendingPhotos)
          .insert(
            PendingPhotosCompanion.insert(
              photoId: id,
              userId: userId,
              localPath: file.path,
            ),
          );
      await _pending(userId, id, {'recordId': recordId, 'sortOrder': sort});
    });
    return id;
  }

  /// 写真を外す。削除の印を付けて同期し、端末の画像も消す
  Future<void> removePhoto({
    required String photoId,
    required String userId,
  }) async {
    final now = _clock().toUtc();
    final local = await _localPath(photoId);
    await _db.transaction(() async {
      final updated =
          await (_db.update(
            _db.recordPhotos,
          )..where((p) => p.id.equals(photoId) & p.deletedAt.isNull())).write(
            RecordPhotosCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );
      if (updated == 0) {
        return;
      }
      await (_db.delete(
        _db.pendingPhotos,
      )..where((p) => p.photoId.equals(photoId))).go();
      await (_db.delete(
        _db.localPhotos,
      )..where((p) => p.photoId.equals(photoId))).go();
      await _pending(userId, photoId, {'deletedAt': now.toIso8601String()});
    });
    if (local != null) {
      await _deleteFile(local);
    }
  }

  /// 端末にある写真のファイル。なければ null
  Future<File?> localFile(String photoId) async {
    final path = await _localPath(photoId);
    if (path == null) {
      return null;
    }
    final file = File(path);
    return await file.exists() ? file : null;
  }

  /// 30日を過ぎた写真を端末から消す。送信待ちの写真は消さない
  Future<int> cleanupOld() async {
    final limit = _clock().toUtc().subtract(
      const Duration(days: localPhotoDays),
    );
    final waiting = _db.selectOnly(_db.pendingPhotos)
      ..addColumns([_db.pendingPhotos.photoId]);
    final old =
        await (_db.select(_db.localPhotos)..where(
              (p) =>
                  p.savedAt.isSmallerThanValue(limit) &
                  p.photoId.isNotInQuery(waiting),
            ))
            .get();
    for (final photo in old) {
      await _deleteFile(photo.localPath);
      await (_db.delete(
        _db.localPhotos,
      )..where((p) => p.photoId.equals(photo.photoId))).go();
    }
    return old.length;
  }

  Future<String?> _localPath(String photoId) async => (await (_db.select(
    _db.localPhotos,
  )..where((p) => p.photoId.equals(photoId))).getSingleOrNull())?.localPath;

  Future<void> _pending(String userId, String id, Map<String, Object?> data) =>
      _db
          .into(_db.pendingChanges)
          .insert(
            PendingChangesCompanion.insert(
              userId: userId,
              targetTable: 'record_photos',
              rowId: id,
              operation: 'upsert',
              payload: jsonEncode(data),
            ),
          );

  static Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // 消せなくても、記録の操作は止めない
    }
  }
}
