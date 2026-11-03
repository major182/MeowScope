import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/features/photos/data/photo_repository.dart';
import 'package:meowscope/features/photos/domain/photo_compress.dart';
import 'package:meowscope/features/photos/presentation/photo_widgets.dart';
import 'package:meowscope/features/sync/data/sync_engine.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

/// 指定の大きさの JPEG
Uint8List jpeg(int width, int height) =>
    img.encodeJpg(img.Image(width: width, height: height));

/// 記録を1件入れる（写真を付ける先）
Future<void> addRecordRow(AppDatabase db, String id) async {
  await addHousehold(db, 'h1');
  await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
  await db
      .into(db.recordTypes)
      .insert(
        RecordTypesCompanion.insert(
          id: 't1',
          createdAt: testTime,
          updatedAt: testTime,
          householdId: 'h1',
          name: 'ご飯',
          kind: 'food',
        ),
      );
  await db
      .into(db.records)
      .insert(
        RecordsCompanion.insert(
          id: id,
          createdAt: testTime,
          updatedAt: testTime,
          catId: 'c1',
          recordTypeId: 't1',
          recordedAt: testTime,
          authorName: 'はる',
        ),
      );
}

void main() {
  group('縮小', () {
    (int, int) size(Uint8List bytes) {
      final image = img.decodeImage(bytes)!;
      return (image.width, image.height);
    }

    test('UT-PH-01 長辺が 1600px を超えたら縮め、以下ならそのまま（境界値 1600・1601、縦長）', () {
      expect(size(compressPhoto(jpeg(3200, 1600))!), (1600, 800));
      expect(size(compressPhoto(jpeg(1000, 2000))!), (800, 1600));
      expect(size(compressPhoto(jpeg(1600, 900))!), (1600, 900));
      expect(size(compressPhoto(jpeg(1601, 800))!).$1, 1600);
      expect(size(compressPhoto(jpeg(800, 600))!), (800, 600));
    });

    test('UT-PH-02 JPEG で保存し直す。PNG も受け付け、画像でなければ null', () {
      final png = img.encodePng(img.Image(width: 10, height: 10));
      final out = compressPhoto(png)!;
      expect(out.sublist(0, 2), [0xFF, 0xD8]);
      expect(compressPhoto(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('写真の保存', () {
    late AppDatabase db;
    late Directory dir;
    late PhotoRepository repo;
    var now = DateTime.utc(2026, 11, 3, 12);

    setUp(() async {
      db = memoryDatabase();
      dir = Directory.systemTemp.createTempSync('meowscope_photos_');
      now = DateTime.utc(2026, 11, 3, 12);
      repo = PhotoRepository(db, () async => dir, clock: () => now);
      await addRecordRow(db, 'r1');
    });
    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('UT-PH-03 付けると、縮めた画像をファイルに置き、写真の情報を同期待ちに、画像を送信待ちに入れる', () async {
      final id = await repo.addPhoto(
        recordId: 'r1',
        userId: 'u1',
        bytes: jpeg(3200, 1600),
      );

      final photo = await db.select(db.recordPhotos).getSingle();
      expect(
        (photo.id, photo.recordId, photo.sortOrder, photo.uploaded),
        (id, 'r1', 1, false),
      );
      final file = await repo.localFile(id);
      expect(file, isNotNull);
      expect(photo.sizeBytes, file!.lengthSync());
      expect((await db.select(db.pendingPhotos).getSingle()).userId, 'u1');
      final pending = await db.select(db.pendingChanges).getSingle();
      expect((pending.targetTable, pending.rowId), ('record_photos', id));
    });

    test('UT-PH-04 3枚までで、4枚目は付けられない（AC-03）。外すと空いた番号を使う', () async {
      final ids = [
        for (var i = 0; i < 3; i++)
          await repo.addPhoto(
            recordId: 'r1',
            userId: 'u1',
            bytes: jpeg(10, 10),
          ),
      ];
      await expectLater(
        repo.addPhoto(recordId: 'r1', userId: 'u1', bytes: jpeg(10, 10)),
        throwsA(isA<PhotoLimitReached>()),
      );

      await repo.removePhoto(photoId: ids[1], userId: 'u1');
      await repo.addPhoto(recordId: 'r1', userId: 'u1', bytes: jpeg(10, 10));

      final photos = await repo.watchPhotos('r1').first;
      expect(photos.map((p) => p.sortOrder), [1, 2, 3]);
      expect(photos.map((p) => p.id), isNot(contains(ids[1])));
    });

    test('UT-PH-05 外すと削除の印を付けて同期待ちに入れ、端末の画像と送信待ちを消す。2回目は何もしない', () async {
      final id = await repo.addPhoto(
        recordId: 'r1',
        userId: 'u1',
        bytes: jpeg(10, 10),
      );
      final path = (await repo.localFile(id))!.path;

      await repo.removePhoto(photoId: id, userId: 'u1');
      await repo.removePhoto(photoId: id, userId: 'u1');

      expect(
        (await db.select(db.recordPhotos).getSingle()).deletedAt,
        isNotNull,
      );
      expect(File(path).existsSync(), isFalse);
      expect(await db.select(db.pendingPhotos).get(), isEmpty);
      expect(await db.select(db.pendingChanges).get(), hasLength(2));
    });

    test('UT-PH-06 異常系：画像でなければ付けず、何も残さない', () async {
      await expectLater(
        repo.addPhoto(
          recordId: 'r1',
          userId: 'u1',
          bytes: Uint8List.fromList([1, 2]),
        ),
        throwsA(isA<PhotoUnreadable>()),
      );
      expect(await db.select(db.recordPhotos).get(), isEmpty);
      expect(dir.listSync(), isEmpty);
    });

    test('UT-PH-07 30日を過ぎた写真を端末から消す。ちょうど30日は残し、送信待ちは残す（境界値、AC-14）', () async {
      final sent = await repo.addPhoto(
        recordId: 'r1',
        userId: 'u1',
        bytes: jpeg(10, 10),
      );
      final waiting = await repo.addPhoto(
        recordId: 'r1',
        userId: 'u1',
        bytes: jpeg(10, 10),
      );
      // sent は送り終わった
      await (db.delete(
        db.pendingPhotos,
      )..where((p) => p.photoId.equals(sent))).go();

      now = now.add(const Duration(days: 30));
      expect(await repo.cleanupOld(), 0);
      now = now.add(const Duration(seconds: 1));
      expect(await repo.cleanupOld(), 1);

      expect(await repo.localFile(sent), isNull);
      expect(await repo.localFile(waiting), isNotNull);
    });
  });

  group('写真の同期と表示', () {
    late AppDatabase db;
    late Directory dir;
    late FakeServer server;
    late MemoryTokenStore tokens;
    late PhotoRepository repo;
    late SyncEngine engine;

    setUp(() async {
      db = memoryDatabase();
      dir = Directory.systemTemp.createTempSync('meowscope_photos_');
      server = FakeServer()
        ..on('POST', '/sync', (r) {
          final sent = ((r.data as Map)['changes'] as List).cast<Map>();
          return FakeResponse(200, {
            'results': [
              for (final c in sent) {'id': c['id'], 'status': 'applied'},
            ],
            'changes': [],
            'nextSeq': 1,
            'hasMore': false,
            'fullResyncRequired': false,
          });
        });
      tokens = MemoryTokenStore()
        ..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      repo = PhotoRepository(db, () async => dir);
      engine = SyncEngine(db, fakeApiClient(server, tokens), tokens);
      await addRecordRow(db, 'r1');
    });
    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('UT-PH-08 同期で写真の情報を送った後に画像を送り、送れたら送信待ちから外して「送信済み」にする', () async {
      final id = await repo.addPhoto(
        recordId: 'r1',
        userId: 'u1',
        bytes: jpeg(10, 10),
      );
      server.on('PUT', '/photos/$id', (r) => const FakeResponse(204));

      expect(await engine.run('u1'), isA<SyncSucceeded>());

      final change =
          ((server.sentTo('/sync').single.data as Map)['changes'] as List)
              .cast<Map>()
              .singleWhere((c) => c['table'] == 'record_photos');
      expect((change['data'] as Map)['recordId'], 'r1');
      final put = server.sentTo('/photos/$id').single;
      expect(put.contentType, 'image/jpeg');
      expect(put.data, (await repo.localFile(id))!.readAsBytesSync());
      expect(await db.select(db.pendingPhotos).get(), isEmpty);
      expect((await db.select(db.recordPhotos).getSingle()).uploaded, isTrue);
      // 送った後も、端末の画像は残す
      expect(await repo.localFile(id), isNotNull);
    });

    test('UT-PH-09 異常系：つながらなければ送信待ちを残す。404 なら送り直さない。ファイルがなければ外す', () async {
      final id = await repo.addPhoto(
        recordId: 'r1',
        userId: 'u1',
        bytes: jpeg(10, 10),
      );
      server.on('PUT', '/photos/$id', (r) => const FakeResponse.offline());
      expect(await engine.run('u1'), isA<SyncFailed>());
      expect(await db.select(db.pendingPhotos).get(), hasLength(1));

      server.on('PUT', '/photos/$id', (r) => const FakeResponse(404));
      expect(await engine.run('u1'), isA<SyncSucceeded>());
      expect(await db.select(db.pendingPhotos).get(), isEmpty);

      final other = await repo.addPhoto(
        recordId: 'r1',
        userId: 'u1',
        bytes: jpeg(10, 10),
      );
      (await repo.localFile(other))!.deleteSync();
      await engine.run('u1');
      expect(server.sentTo('/photos/$other'), isEmpty);
      expect(await db.select(db.pendingPhotos).get(), isEmpty);
    });

    test('UT-PH-10 受け取った写真の情報を反映し、おうちから外れたら写真の情報も消す', () async {
      server.on(
        'POST',
        '/sync',
        (r) => const FakeResponse(200, {
          'results': [],
          'changes': [
            {
              'table': 'record_photos',
              'id': 'p1',
              'seq': 1,
              'updatedAt': '2026-11-03T00:00:00Z',
              'deletedAt': null,
              'data': {
                'recordId': 'r1',
                'sortOrder': 2,
                'sizeBytes': 100,
                'uploaded': true,
              },
            },
          ],
          'nextSeq': 1,
          'hasMore': false,
          'fullResyncRequired': false,
        }),
      );
      await engine.run('u1');
      final photo = await db.select(db.recordPhotos).getSingle();
      expect(
        (photo.sortOrder, photo.uploaded, photo.sizeBytes),
        (2, true, 100),
      );

      server.on(
        'POST',
        '/sync',
        (r) => const FakeResponse(200, {
          'results': [],
          'changes': [
            {
              'table': 'household_members',
              'id': 'm1',
              'seq': 2,
              'updatedAt': '2026-11-03T00:00:00Z',
              'deletedAt': '2026-11-03T01:00:00Z',
              'data': {
                'householdId': 'h1',
                'userId': 'u1',
                'displayName': 'はる',
              },
            },
          ],
          'nextSeq': 2,
          'hasMore': false,
          'fullResyncRequired': false,
        }),
      );
      await engine.run('u1');
      expect(await db.select(db.recordPhotos).get(), isEmpty);
    });

    test('UT-PH-11 表示：端末の画像 → サーバーの画像 → 送られていない／オフラインの案内（BR-28）', () async {
      final local = await repo.addPhoto(
        recordId: 'r1',
        userId: 'u1',
        bytes: jpeg(10, 10),
      );
      Future<RecordPhotoRow> row(String id, {required bool uploaded}) async {
        await db
            .into(db.recordPhotos)
            .insertOnConflictUpdate(
              RecordPhotosCompanion.insert(
                id: id,
                createdAt: testTime,
                updatedAt: testTime,
                recordId: 'r1',
                sortOrder: 3,
                uploaded: Value(uploaded),
              ),
            );
        return (db.select(
          db.recordPhotos,
        )..where((p) => p.id.equals(id))).getSingle();
      }

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoDirectoryProvider.overrideWithValue(() async => dir),
          apiClientProvider.overrideWithValue(fakeApiClient(server, tokens)),
        ],
      );
      addTearDown(container.dispose);
      server.on(
        'GET',
        '/photos/remote',
        (r) => const FakeResponse(200, [1, 2, 3]),
      );
      server.on('GET', '/photos/offline', (r) => const FakeResponse.offline());

      final localRow = (await repo.watchPhotos('r1').first).singleWhere(
        (p) => p.id == local,
      );
      expect(
        await container.read(photoImageProvider(localRow).future),
        isA<PhotoBytes>(),
      );
      final remote = await container.read(
        photoImageProvider(await row('remote', uploaded: true)).future,
      );
      expect((remote as PhotoBytes).bytes, isNotEmpty);
      expect(
        await container.read(
          photoImageProvider(await row('waiting', uploaded: false)).future,
        ),
        isA<PhotoNotYetUploaded>(),
      );
      expect(
        await container.read(
          photoImageProvider(await row('offline', uploaded: true)).future,
        ),
        isA<PhotoOffline>(),
      );
    });
  });
}
