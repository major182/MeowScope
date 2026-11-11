// 性能テストから MeowScope の API を呼ぶ部品（API 設計書 2・4・5・6章）
import http from 'k6/http';
import { check, fail } from 'k6';
// k6 の標準の Web Crypto で作る（外部の配布元から部品を読み込まない）
declare const crypto: { randomUUID(): string };

/** 接続先。実行の道具（run.ts）が、性能テスト専用の環境のサーバーを渡す */
export const BASE = __ENV.BASE_URL ?? 'http://localhost:8081/api/v1';

/** テストのデータの目印。メールアドレスの先頭とドメインで、開発用のデータと見分ける */
export const MARK = 'perf-';
export const PASSWORD = 'Passw0rd!';

export const id = (): string => crypto.randomUUID();

export type Tokens = { accessToken: string; refreshToken: string; at: number };

const json = { 'Content-Type': 'application/json' };
const auth = (t: Tokens) => ({ ...json, Authorization: `Bearer ${t.accessToken}` });

/** API を呼ぶ。`name` で結果を集計し、期待した状態でなければ check に失敗を残す */
function post(path: string, body: unknown, name: string, headers: Record<string, string> = json, ok = 200) {
  const res = http.post(BASE + path, JSON.stringify(body), { headers, tags: { name } });
  check(res, { [`${name} ${ok}`]: (r) => r.status === ok });
  return res;
}

function tokensOf(res: http.RefinedResponse<http.ResponseType | undefined>): Tokens {
  const b = res.json() as { accessToken: string; refreshToken: string } | null;
  if (!b?.accessToken) {
    fail(`トークンを受け取れなかった：${res.status} ${String(res.body).slice(0, 200)}`);
  }
  return { accessToken: b.accessToken, refreshToken: b.refreshToken, at: Date.now() };
}

export const register = (email: string, name: string) =>
  tokensOf(post('/auth/register', { email, password: PASSWORD, displayName: name }, 'register', json, 201));

export const login = (email: string) => tokensOf(post('/auth/login', { email, password: PASSWORD }, 'login'));

export const refresh = (t: Tokens) => tokensOf(post('/auth/refresh', { refreshToken: t.refreshToken }, 'refresh'));

/** 標準の8項目（アプリの RecordKind と同じ並び） */
export const KINDS = [
  ['food', 'ご飯', 'food'],
  ['water', '水', 'water'],
  ['medicine', '薬', 'medicine'],
  ['urine', 'おしっこ', 'pee'],
  ['stool', 'うんち', 'poop'],
  ['vomit', '吐いた', 'vomit'],
  ['weight', '体重', 'weight'],
  ['brushing', 'ブラシ', 'brushing'],
] as const;

export type Household = { householdId: string; types: Record<string, string>; cats: string[] };

/** おうちと猫を作る。招待のトークンを返す（家族のもう1人を加えるため） */
export function createHousehold(t: Tokens, name: string, catCount: number): Household & { invite: string } {
  const householdId = id();
  const types: Record<string, string> = {};
  const recordTypes = KINDS.map(([kind, label, icon], i) => {
    types[kind] = id();
    return { id: types[kind], name: label, icon, kind, sortOrder: i };
  });
  post('/households', { id: householdId, name, recordTypes }, 'households', auth(t), 201);
  const cats = Array.from({ length: catCount }, () => id());
  const now = new Date().toISOString();
  sync(
    t,
    0,
    cats.map((c, i) => ({
      table: 'cats',
      id: c,
      updatedAt: now,
      deletedAt: null,
      data: { householdId, name: `猫${i + 1}`, status: 'active' },
    })),
    'seed',
  );
  const res = post(`/households/${householdId}/invitations`, {}, 'invitations', auth(t), 201);
  return { householdId, types, cats, invite: (res.json() as { token: string }).token };
}

export const accept = (t: Tokens, token: string) => post('/invitations/accept', { token }, 'accept', auth(t));

export type Change = {
  table: string;
  id: string;
  updatedAt: string;
  deletedAt: string | null;
  data: Record<string, unknown>;
};

export type SyncResult = { nextSeq: number; hasMore: boolean; changes: unknown[]; results: { status: string }[] };

/** 同期を1回呼ぶ。`name` は集計の名前（pull・push・full など） */
export function sync(t: Tokens, lastSeq: number, changes: Change[], name: string): SyncResult {
  const res = post('/sync', { lastSeq, changes }, `sync:${name}`, auth(t));
  const body = res.json() as SyncResult | null;
  if (body && changes.length > 0) {
    check(body, { [`sync:${name} 反映`]: (b) => b.results.every((r) => r.status !== 'rejected') });
  }
  return body ?? { nextSeq: lastSeq, hasMore: false, changes: [], results: [] };
}

/** 記録の変更を作る */
export function record(h: Household, cat: string, kind: string, at: Date, author: string): Change {
  return {
    table: 'records',
    id: id(),
    updatedAt: new Date().toISOString(),
    deletedAt: null,
    data: {
      catId: cat,
      recordTypeId: h.types[kind],
      recordedAt: at.toISOString(),
      authorName: author,
      ...(kind === 'weight' ? { valueNumber: 4 + Math.round(Math.random() * 10) / 10 } : {}),
    },
  };
}

/** 写真の本体：先頭が JPEG の印の 300KB（端末は長辺 1600px の JPEG に縮めて送る） */
export function fakeJpeg(): ArrayBuffer {
  const bytes = new Uint8Array(300 * 1024);
  bytes.set([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00]);
  for (let i = 11; i < bytes.length; i++) {
    bytes[i] = (i * 31) & 0xff;
  }
  bytes.set([0xff, 0xd9], bytes.length - 2);
  return bytes.buffer;
}

export function putPhoto(t: Tokens, photoId: string, body: ArrayBuffer) {
  const res = http.put(`${BASE}/photos/${photoId}`, body, {
    headers: { 'Content-Type': 'image/jpeg', Authorization: `Bearer ${t.accessToken}` },
    tags: { name: 'photo:put' },
  });
  check(res, { 'photo:put 2xx': (r) => r.status >= 200 && r.status < 300 });
}

export function getPhoto(t: Tokens, photoId: string) {
  const res = http.get(`${BASE}/photos/${photoId}`, {
    headers: { Authorization: `Bearer ${t.accessToken}` },
    tags: { name: 'photo:get' },
    responseType: 'none',
  });
  check(res, { 'photo:get 200': (r) => r.status === 200 });
}
