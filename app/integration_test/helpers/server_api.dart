import 'package:dio/dio.dart';
import 'package:meowscope/core/api/api_client.dart' show apiBaseUrl;
import 'package:uuid/uuid.dart';

/// E2E テストの中から、本物のサーバーの API を直接呼ぶ（家族のもう1人の操作や、サーバーに届いたかの確認に使う）
///
/// 接続先はアプリと同じ `API_BASE_URL`（Android のエミュレーターなら http://10.0.2.2:8080/api/v1）
class ServerApi {
  final _dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  static const _uuid = Uuid();

  /// テストごとに重ならないメールアドレス
  static String uniqueEmail(String who) =>
      'e2e-$who-${_uuid.v4().substring(0, 8)}@example.com';

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  /// 新規登録して、アクセストークンを返す
  Future<String> register(String email, String password, String name) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'password': password, 'displayName': name},
    );
    return r.data!['accessToken'] as String;
  }

  Future<String> login(String email, String password) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return r.data!['accessToken'] as String;
  }

  /// おうちを作る。記録項目はご飯と水だけ。それぞれの ID を返す
  Future<({String household, String food, String water})> createHousehold(
    String token,
    String name,
  ) async {
    final ids = (household: _uuid.v4(), food: _uuid.v4(), water: _uuid.v4());
    await _dio.post<void>(
      '/households',
      data: {
        'id': ids.household,
        'name': name,
        'recordTypes': [
          {
            'id': ids.food,
            'name': 'ご飯',
            'icon': 'food',
            'kind': 'food',
            'sortOrder': 0,
          },
          {
            'id': ids.water,
            'name': '水',
            'icon': 'water',
            'kind': 'water',
            'sortOrder': 1,
          },
        ],
      },
      options: _auth(token),
    );
    return ids;
  }

  /// 猫と、その猫の記録を1件作る
  Future<void> addCatAndRecord(
    String token, {
    required String household,
    required String catName,
    required String typeId,
    required String authorName,
  }) async {
    final cat = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await sync(token, [
      {
        'table': 'cats',
        'id': cat,
        'updatedAt': now,
        'deletedAt': null,
        'data': {'householdId': household, 'name': catName, 'status': 'active'},
      },
      {
        'table': 'records',
        'id': _uuid.v4(),
        'updatedAt': now,
        'deletedAt': null,
        'data': {
          'catId': cat,
          'recordTypeId': typeId,
          'recordedAt': now,
          'authorName': authorName,
        },
      },
    ]);
  }

  /// 招待のリンクを作る
  Future<String> invite(String token, String household) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/households/$household/invitations',
      options: _auth(token),
    );
    return r.data!['link'] as String;
  }

  /// 変更を送り、サーバーにある変更をすべて受け取る
  Future<List<Map<String, dynamic>>> sync(
    String token, [
    List<Map<String, Object?>> changes = const [],
  ]) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/sync',
      data: {'lastSeq': 0, 'changes': changes},
      options: _auth(token),
    );
    return (r.data!['changes'] as List).cast<Map<String, dynamic>>();
  }
}
