import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../core/api/api_error.dart';
import '../../core/db/app_database.dart';
import '../photos/domain/photo_compress.dart';
import '../photos/data/photo_repository.dart' show PhotoUnreadable;

/// アイコンの持ち主の種類
enum IconOwner { user, cat }

/// 表示するアイコン。[hasIcon] はサーバーにあるか、[version] はその版（行の通し番号）
class IconRef {
  const IconRef(this.owner, this.id, {this.hasIcon = false, this.version});

  final IconOwner owner;
  final String id;
  final bool hasIcon;
  final int? version;

  @override
  bool operator ==(Object other) =>
      other is IconRef &&
      other.owner == owner &&
      other.id == id &&
      other.hasIcon == hasIcon &&
      other.version == version;

  @override
  int get hashCode => Object.hash(owner, id, hasIcon, version);
}

/// ユーザーと猫のアイコン（F-SH-07）
///
/// - 設定するときは 512px の JPEG に縮めてサーバーへ送り、端末にも保存する。通信が要る
/// - 表示するときは端末の保存を使い、版が変わっていればサーバーから取り直す
/// - 取れなければ null（画面は既定のイラストを出す）
class IconRepository {
  IconRepository(this._db, this._api, this._directory);

  final AppDatabase _db;
  final Dio _api;
  final Future<Directory> Function() _directory;

  static const maxSide = 512;

  /// 端末で設定したアイコンの印。同期で版が届くまでは、この保存を使う
  static const _local = 'local';

  Future<File> _file(IconOwner owner, String id) async {
    final dir = Directory(
      '${(await _directory()).path}${Platform.pathSeparator}icons',
    );
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}${owner.name}-$id.jpg');
  }

  String _key(IconOwner owner, String id) => 'icon.${owner.name}.$id';

  /// アイコンを設定する。[PhotoUnreadable]：画像として読めない。[ApiError]：送れない
  Future<void> setIcon(IconOwner owner, String id, Uint8List bytes) async {
    final compressed = compressPhoto(bytes, maxSide: maxSide);
    if (compressed == null) {
      throw const PhotoUnreadable();
    }
    try {
      await _api.put<void>(
        owner == IconOwner.user ? '/me/icon' : '/cats/$id/icon',
        data: compressed,
        options: Options(contentType: 'image/jpeg'),
      );
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
    await (await _file(owner, id)).writeAsBytes(compressed, flush: true);
    await _setVersion(owner, id, _local);
    if (owner == IconOwner.cat) {
      await (_db.update(_db.cats)..where((c) => c.id.equals(id))).write(
        const CatsCompanion(hasIcon: Value(true)),
      );
    } else {
      await (_db.update(_db.householdMembers)
            ..where((m) => m.userId.equals(id)))
          .write(const HouseholdMembersCompanion(hasIcon: Value(true)));
    }
  }

  /// 表示する画像。なければ null
  Future<Uint8List?> load(IconRef ref) async {
    final file = await _file(ref.owner, ref.id);
    final saved = await _version(ref.owner, ref.id);
    if (await file.exists() &&
        (saved == _local || (saved != null && saved == '${ref.version}'))) {
      return file.readAsBytes();
    }
    if (!ref.hasIcon) {
      return null;
    }
    try {
      final response = await _api.get<List<int>>(
        ref.owner == IconOwner.user
            ? '/users/${ref.id}/icon'
            : '/cats/${ref.id}/icon',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data!);
      await file.writeAsBytes(bytes, flush: true);
      await _setVersion(ref.owner, ref.id, '${ref.version}');
      return bytes;
    } on DioException {
      // オフラインなど。前に保存したものがあれば、古くてもそれを出す
      return await file.exists() ? file.readAsBytes() : null;
    }
  }

  Future<String?> _version(IconOwner owner, String id) async =>
      (await (_db.select(
        _db.appStates,
      )..where((s) => s.key.equals(_key(owner, id)))).getSingleOrNull())?.value;

  Future<void> _setVersion(IconOwner owner, String id, String value) => _db
      .into(_db.appStates)
      .insertOnConflictUpdate(
        AppStatesCompanion.insert(key: _key(owner, id), value: value),
      );
}
