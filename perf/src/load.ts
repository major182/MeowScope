// PT-01〜05：利用者が同時に使うときの API の速さ（NF-PF-01・03）。シナリオは環境変数 SCENARIO で選ぶ
//
// 1人の仮想利用者（VU）は1台の端末。ログインして、実際の使い方に近い比率で同期・記録・写真を繰り返す
import { sleep } from 'k6';
import exec from 'k6/execution';
import type { Options } from 'k6/options';
import {
  MARK,
  accept,
  createHousehold,
  fakeJpeg,
  getPhoto,
  id,
  login,
  putPhoto,
  record,
  refresh,
  register,
  sync,
  type Household,
  type Tokens,
} from './api.ts';

/** 作る利用者の数（2人で1つのおうち） */
const USERS = Number(__ENV.USERS ?? 100);

/** シナリオごとの負荷のかけ方。SHORT=1 は時間を 1/10 にした動作の確認（合否・記録には使わない） */
const short = __ENV.SHORT === '1';
const t = (sec: number) => `${Math.max(5, Math.round(short ? sec / 10 : sec))}s`;

const scenarios: Record<string, Options['scenarios']> = {
  smoke: { smoke: { executor: 'per-vu-iterations', vus: 1, iterations: 20, maxDuration: '2m' } },
  load: {
    load: {
      executor: 'ramping-vus',
      stages: [
        { duration: t(60), target: 100 },
        { duration: t(600), target: 100 },
        { duration: t(30), target: 0 },
      ],
    },
  },
  stress: {
    stress: {
      executor: 'ramping-vus',
      stages: [
        { duration: t(120), target: 100 },
        { duration: t(180), target: 200 },
        { duration: t(180), target: 300 },
        { duration: t(180), target: 400 },
        { duration: t(180), target: 500 },
        { duration: t(60), target: 0 },
      ],
    },
  },
  spike: {
    spike: {
      executor: 'ramping-vus',
      stages: [
        { duration: t(60), target: 10 },
        { duration: '10s', target: 200 },
        { duration: t(120), target: 200 },
        { duration: '10s', target: 10 },
        { duration: t(90), target: 10 },
      ],
    },
  },
  soak: {
    soak: {
      executor: 'ramping-vus',
      stages: [
        { duration: t(60), target: 100 },
        { duration: t(3600), target: 100 },
        { duration: t(30), target: 0 },
      ],
    },
  },
};

const scenario = __ENV.SCENARIO ?? 'smoke';
// stress は限界を探すので合否を付けない（記録だけ）
const judged = scenario !== 'stress';

export const options: Options = {
  scenarios: scenarios[scenario],
  setupTimeout: '10m',
  // 応答の時間の分布に p99 も出す
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  thresholds: judged
    ? {
        // NF-PF-01・03：通常の操作の 95% が1秒以内。操作ごとにも見る（件数の多い同期に、少ない操作の遅れが埋もれないように）
        // 準備（setup）の登録などは測らないよう、シナリオの中のリクエストだけを見る
        [`http_req_duration{scenario:${scenario}}`]: ['p(95)<1000'],
        ...Object.fromEntries(
          ['sync:pull', 'sync:push', 'sync:full', 'photo:put', 'photo:get', 'login', 'refresh'].map((n) => [
            `http_req_duration{scenario:${scenario},name:${n}}`,
            ['p(95)<1000'],
          ]),
        ),
        [`http_req_failed{scenario:${scenario}}`]: ['rate<0.01'],
        [`checks{scenario:${scenario}}`]: ['rate>0.99'],
      }
    : {},
};

type User = { email: string; household: Household };

/** テストの初めに、目印つきの利用者とおうちを作る。2人で1つのおうち、猫は1〜3匹、30日分の記録 */
export function setup(): User[] {
  const run = id().slice(0, 8);
  const users: User[] = [];
  for (let i = 0; i < USERS; i += 2) {
    const a = `${MARK}${run}-${i}@example.test`;
    const b = `${MARK}${run}-${i + 1}@example.test`;
    const ta = register(a, `perf${i}`);
    const tb = register(b, `perf${i + 1}`);
    const h = createHousehold(ta, `${MARK}家${i / 2}`, 1 + ((i / 2) % 3));
    accept(tb, h.invite);
    // 30日分（1匹1日に約10件）を500件ずつ送る
    const changes = [];
    const today = new Date();
    for (let d = 1; d <= 30; d++) {
      for (const cat of h.cats) {
        for (const [kind, hours] of [
          ['food', [7, 12, 19]],
          ['water', [8, 13, 20]],
          ['urine', [9, 15, 21]],
          ['stool', [10]],
        ] as const) {
          for (const hour of hours) {
            const at = new Date(today.getFullYear(), today.getMonth(), today.getDate() - d, hour);
            changes.push(record(h, cat, kind, at, 'perf'));
          }
        }
      }
    }
    for (let k = 0; k < changes.length; k += 500) {
      sync(ta, 0, changes.slice(k, k + 500), 'seed');
    }
    users.push({ email: a, household: h }, { email: b, household: h });
  }
  return users;
}

// VU ごとの状態（k6 は VU ごとにこのモジュールを読み込む）
let tokens: Tokens | null = null;
let lastSeq = 0;
const photo = fakeJpeg();

export default function (users: User[]) {
  const me = users[(exec.vu.idInTest - 1) % users.length];
  if (tokens === null) {
    // 起動したとき：ログインして全件を受け取る
    tokens = login(me.email);
    let r;
    do {
      r = sync(tokens, lastSeq, [], 'full');
      lastSeq = r.nextSeq;
    } while (r.hasMore);
  } else if (Date.now() - tokens.at > 10 * 60 * 1000) {
    // アクセストークン（15分）が切れる前に更新する
    tokens = refresh(tokens);
  }
  const h = me.household;
  const cat = h.cats[Math.floor(Math.random() * h.cats.length)];
  // smoke は全部の操作を一通り行うよう、回ごとに順に選ぶ
  const roll = scenario === 'smoke' ? (exec.vu.iterationInScenario % 20) / 20 : Math.random();
  if (roll < 0.7) {
    // 70%：差分同期（起動・画面の表示のたび。ほとんどは変更なしか数件）
    lastSeq = sync(tokens, lastSeq, [], 'pull').nextSeq;
  } else if (roll < 0.9) {
    // 20%：記録を1〜3件送る
    const kinds = ['food', 'water', 'urine', 'stool', 'vomit', 'weight'];
    const n = 1 + Math.floor(Math.random() * 3);
    const changes = Array.from({ length: n }, () =>
      record(h, cat, kinds[Math.floor(Math.random() * kinds.length)], new Date(), 'perf'),
    );
    lastSeq = sync(tokens, lastSeq, changes, 'push').nextSeq;
  } else if (roll < 0.95) {
    // 5%：写真つきの記録を送り、写真を取得する（同期で写真の情報 → 画像の本体の順）
    const rec = record(h, cat, 'vomit', new Date(), 'perf');
    const photoId = id();
    lastSeq = sync(
      tokens,
      lastSeq,
      [
        rec,
        {
          table: 'record_photos',
          id: photoId,
          updatedAt: new Date().toISOString(),
          deletedAt: null,
          data: { recordId: rec.id, sortOrder: 1 },
        },
      ],
      'push',
    ).nextSeq;
    putPhoto(tokens, photoId, photo);
    getPhoto(tokens, photoId);
  } else {
    // 5%：ログインのし直しと、トークンの更新
    tokens = Math.random() < 0.5 ? login(me.email) : refresh(tokens);
  }
  // 次の操作までの間（人が画面を見ている時間）
  sleep(1 + Math.random() * 2);
}
