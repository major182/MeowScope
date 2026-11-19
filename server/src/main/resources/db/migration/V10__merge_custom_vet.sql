-- 独自の項目「通院」を標準の項目「病院」へまとめる（Ver.1.3.0。BR-38。DB 設計書 4章）
--
-- 見分け方：独自の項目（kind = 'custom'）で、アイコンが通院のイラスト（custom_vet）のもの。
-- 名前は利用者が自由に付けるので使わない。見分け方は一般公開の前に見直す（BR-38）。
-- どの更新も server_seq を進め、同期で各端末へ届ける（V7 のトリガーは、更新で server_seq を変えたときだけ
-- 番号を振り直す。変えないと端末に届かない）。病院は V9 で各おうちに1つある。

-- 1. その記録を、同じおうちの病院へ付け替える（消した記録も、復元はしないが付け替えておく）
UPDATE records r
SET record_type_id = vet.id, updated_at = now(), server_seq = nextval('sync_seq')
FROM record_types t
JOIN record_types vet ON vet.household_id = t.household_id AND vet.kind = 'vet'
WHERE r.record_type_id = t.id AND t.kind = 'custom' AND t.icon = 'custom_vet';

-- 2. その項目を指すウィジェットのボタンを消す（病院のボタンは利用者が選び直す）
UPDATE widget_buttons w
SET deleted_at = now(), updated_at = now(), server_seq = nextval('sync_seq')
FROM record_types t
WHERE w.record_type_id = t.id AND t.kind = 'custom' AND t.icon = 'custom_vet' AND w.deleted_at IS NULL;

-- 3. その項目を消す（削除の印。記録項目はふだん消さないが、まとめた項目だけは消す）
UPDATE record_types
SET deleted_at = now(), updated_at = now(), server_seq = nextval('sync_seq')
WHERE kind = 'custom' AND icon = 'custom_vet' AND deleted_at IS NULL;
