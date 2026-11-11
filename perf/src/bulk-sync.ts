// PT-06：5年分の記録のあるおうちの同期（NF-PF-04）
//
// 新しい端末で全件を受け取る時間（500件ずつ）と、家族が記録した後の差分同期の時間を、3回ずつ測る
import { check } from 'k6';
import { Trend } from 'k6/metrics';
import type { Options } from 'k6/options';
import { MARK, accept, createHousehold, id, login, record, register, sync, type Household } from './api.ts';

const YEARS = Number(__ENV.YEARS ?? 5);

/** 全件の受け取りにかかった時間と、差分同期の時間（ミリ秒） */
const fullSync = new Trend('pt06_full_sync', true);
const diffSync = new Trend('pt06_diff_sync', true);

export const options: Options = {
  scenarios: { bulk: { executor: 'per-vu-iterations', vus: 1, iterations: 3, maxDuration: '20m' } },
  setupTimeout: '20m',
  summaryTrendStats: ['avg', 'min', 'med', 'p(95)', 'max'],
  thresholds: {
    // NF-PF-04：差分同期は通常1分以内。新しい端末の全件の受け取りも1分以内を目安にする
    pt06_full_sync: ['max<60000'],
    pt06_diff_sync: ['max<60000'],
    'http_req_duration{name:sync:full}': ['p(95)<1000'],
    http_req_failed: ['rate<0.01'],
  },
};

type Data = { a: string; b: string; household: Household; records: number };

/** 5年分（1匹・1日に約15件）を作る。体重は3日に1回 */
export function setup(): Data {
  const run = id().slice(0, 8);
  const a = `${MARK}${run}-bulk-a@example.test`;
  const b = `${MARK}${run}-bulk-b@example.test`;
  const ta = register(a, 'perf-a');
  const tb = register(b, 'perf-b');
  const h = createHousehold(ta, `${MARK}5年の家`, 1);
  accept(tb, h.invite);
  const cat = h.cats[0];
  const today = new Date();
  let batch = [];
  let records = 0;
  const day = (d: number, hour: number) =>
    new Date(today.getFullYear(), today.getMonth(), today.getDate() - d, hour, (d * 7) % 60);
  for (let d = 1; d <= YEARS * 365; d++) {
    const kinds: [string, number[]][] = [
      ['food', [7, 12, 19]],
      ['water', [8, 10, 13, 16, 20]],
      ['urine', [9, 14, 21]],
      ['stool', [11, 22]],
      ['brushing', [18]],
    ];
    if (d % 3 === 0) kinds.push(['weight', [23]]);
    if (d % 20 === 0) kinds.push(['vomit', [6]]);
    for (const [kind, hours] of kinds) {
      for (const hour of hours) {
        batch.push(record(h, cat, kind, day(d, hour), 'perf'));
        if (batch.length === 500) {
          sync(ta, 0, batch, 'seed');
          records += batch.length;
          batch = [];
        }
      }
    }
  }
  if (batch.length > 0) {
    sync(ta, 0, batch, 'seed');
    records += batch.length;
  }
  console.log(`5年分のおうち：記録 ${records} 件`);
  return { a, b, household: h, records };
}

export default function (data: Data) {
  // 新しい端末：0 から最後まで受け取る
  const ta = login(data.a);
  const start = Date.now();
  let seq = 0;
  let received = 0;
  let r;
  do {
    r = sync(ta, seq, [], 'full');
    seq = r.nextSeq;
    received += r.changes.length;
  } while (r.hasMore);
  fullSync.add(Date.now() - start);
  check(received, { '全件を受け取った': (n) => n >= data.records });

  // 家族が10件記録した後の差分同期
  const tb = login(data.b);
  const cat = data.household.cats[0];
  sync(
    tb,
    0,
    Array.from({ length: 10 }, () => record(data.household, cat, 'food', new Date(), 'perf-b')),
    'push',
  );
  const diffStart = Date.now();
  let got = 0;
  do {
    r = sync(ta, seq, [], 'diff');
    seq = r.nextSeq;
    got += r.changes.length;
  } while (r.hasMore);
  diffSync.add(Date.now() - diffStart);
  check(got, { '差分の10件を受け取った': (n) => n >= 10 });
}
