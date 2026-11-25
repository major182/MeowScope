import 'package:drift/drift.dart';

import '../../features/auth/data/auth_repository.dart';
import 'app_database.dart';

/// 自分が入っているおうち（入った順）。抜けたおうち・消えたおうちは含めない（BR-39）
///
/// 自分のメンバーの行があるおうちに加えて、今のおうちも含める。招待で入った直後や、端末で作った直後は、
/// 同期でメンバーの行が届くまで行がないため。並びは入った順（メンバーの行の作成日時）で、
/// 行のないおうちは最後に置く
Selectable<HouseholdRow> myHouseholds(AppDatabase db, String userId) {
  return db
      .customSelect(
        '''
        SELECT h.* FROM households h
        LEFT JOIN household_members m
          ON m.household_id = h.id AND m.user_id = ?1 AND m.deleted_at IS NULL
        WHERE h.deleted_at IS NULL
          AND (m.id IS NOT NULL
            OR h.id IN (SELECT value FROM app_states WHERE key = ?2))
        GROUP BY h.id
        ORDER BY MIN(m.created_at) IS NULL, MIN(m.created_at), h.created_at, h.id
        ''',
        variables: [
          Variable.withString(userId),
          Variable.withString(SessionKeys.householdId),
        ],
        readsFrom: {db.households, db.householdMembers, db.appStates},
      )
      .asyncMap((row) => db.households.mapFromRow(row));
}

/// 今のおうちを [householdId] にする（BR-39）。ユーザーごとの最後に選んだおうちも同じにする
Future<void> selectHousehold(
  AppDatabase db,
  String userId,
  String householdId,
) async {
  for (final key in [
    SessionKeys.householdId,
    SessionKeys.householdOf(userId),
  ]) {
    await db
        .into(db.appStates)
        .insertOnConflictUpdate(
          AppStatesCompanion.insert(key: key, value: householdId),
        );
  }
}

/// 今のおうちがなければ、入っているおうちの最初のものを選ぶ。選んだおうちの ID を返す
///
/// 機種変更の後と、今のおうちを抜けた後に使う（S-04 を出さずに済む。BR-39）。
/// 入っているおうちがなければ何もせず、null を返す（S-04 へ）
Future<String?> chooseHouseholdIfNone(AppDatabase db, String userId) async {
  final current = await (db.select(
    db.appStates,
  )..where((s) => s.key.equals(SessionKeys.householdId))).getSingleOrNull();
  if (current != null) {
    return current.value;
  }
  final first = (await myHouseholds(db, userId).get()).firstOrNull;
  if (first == null) {
    return null;
  }
  await selectHousehold(db, userId, first.id);
  return first.id;
}
