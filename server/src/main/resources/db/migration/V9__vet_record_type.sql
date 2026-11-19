-- 標準の項目「病院」（Ver.1.3.0。F-MD-01、BR-37。DB 設計書 4章）
--
-- 種類に vet（病院）を加える
ALTER TABLE record_types DROP CONSTRAINT record_types_kind_check;
ALTER TABLE record_types ADD CONSTRAINT record_types_kind_check CHECK (kind IN
    ('food', 'water', 'medicine', 'urine', 'stool', 'vomit', 'weight', 'brushing', 'vet', 'custom'));

-- 今あるおうちに、病院を1つずつ足す。端末ごとに作ると、複数の端末が同時に更新したときに重なるので、
-- サーバーで1回だけ作り、同期で各端末へ届ける（足した行にはトリガーで通し番号が振られる）。
-- アイコンは custom_vet：古いアプリでも通院のイラストで出るように（新しいアプリは種類から絵を決める）。
-- 並び順はそのおうちの最後（最大 + 1）。
INSERT INTO record_types (id, household_id, name, icon, kind, sort_order)
SELECT gen_random_uuid(), h.id, '病院', 'custom_vet', 'vet',
       COALESCE((SELECT max(t.sort_order) FROM record_types t WHERE t.household_id = h.id), -1) + 1
FROM households h
WHERE NOT EXISTS (SELECT 1 FROM record_types t WHERE t.household_id = h.id AND t.kind = 'vet');

-- 病院は1つのおうちに1つだけ（BR-37）。2つ目は同期で constraint として受け付けない
CREATE UNIQUE INDEX record_types_one_vet_per_household ON record_types (household_id) WHERE kind = 'vet';
