// 性能テストを動かす：node perf/run.ts <テスト…> [--short] [--keep]
//
//   テスト：smoke load stress spike soak bulk（サーバー。k6）、app-windows app-android app-device（アプリ。PT-07。app-device は USB でつないだ実機）
//           night は、夜にまとめて行う順（load stress spike soak bulk app-windows app-android）
//   --short：時間を 1/10 にした動作の確認。スクリプトが動くかを見るだけで、合否・記録には使わない
//   --keep ：終わっても環境を捨てない（調べるため）。後から node perf/run.ts down で捨てる
//
// テストごとに性能テスト専用の環境（docker compose のプロジェクト meowscope-perf）を新しく立て、
// 終わったら、成功・失敗・中断のどれでも volume ごと捨て、残っていないことを確かめて記録する。
// 開発用の DB（プロジェクト meowscope）には触れない。結果は perf/results/ に置く（コミットしない）
import { execFileSync, spawn, spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { appendFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { cpus, totalmem } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const PERF = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(PERF, '..');
const PROJECT = 'meowscope-perf';
const K6_IMAGE = 'grafana/k6:2.3.0';
const ADB = join(process.env.LOCALAPPDATA ?? '', 'Android/Sdk/platform-tools/adb.exe');
const EMULATOR = join(process.env.LOCALAPPDATA ?? '', 'Android/Sdk/emulator/emulator.exe');
const AVD = process.env.PERF_AVD ?? 'Medium_Phone_API_37.0';

const SERVER_TESTS = ['smoke', 'load', 'stress', 'spike', 'soak', 'bulk'] as const;
const APP_TESTS = ['app-windows', 'app-android', 'app-device'] as const;
const NIGHT = ['load', 'stress', 'spike', 'soak', 'bulk', 'app-windows', 'app-android'];
const IDS: Record<string, string> = {
  smoke: 'PT-01',
  load: 'PT-02',
  stress: 'PT-03',
  spike: 'PT-04',
  soak: 'PT-05',
  bulk: 'PT-06',
  'app-windows': 'PT-07',
  'app-android': 'PT-07',
  'app-device': 'PT-07',
};

// 専用の環境の秘密の値は、実行のたびに作って環境変数で渡す（表示も保存もしない）
const env = {
  ...process.env,
  DB_PASSWORD: randomBytes(18).toString('base64url'),
  JWT_SECRET: randomBytes(48).toString('base64'),
};

function compose(...args: string[]) {
  const r = spawnSync(
    'docker',
    ['compose', '-p', PROJECT, '-f', join(ROOT, 'compose.yaml'), '-f', join(PERF, 'compose.perf.yaml'), ...args],
    { env, stdio: 'inherit' },
  );
  if (r.status !== 0) {
    throw new Error(`docker compose ${args.join(' ')} が失敗した（${r.status}）`);
  }
}

const out = (cmd: string, args: string[]) => execFileSync(cmd, args, { encoding: 'utf8', env }).trim();

async function waitHealthy() {
  for (let i = 0; i < 120; i++) {
    try {
      const r = await fetch('http://localhost:8081/actuator/health');
      if (r.ok && (await r.text()).includes('UP')) return;
    } catch {
      // 起動中
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  throw new Error('サーバーが起動しなかった');
}

async function up() {
  compose('up', '-d', '--build', '--wait');
  await waitHealthy();
  psql('CREATE EXTENSION IF NOT EXISTS pg_stat_statements');
}

const psql = (sql: string) =>
  out('docker', ['exec', `${PROJECT}-db-1`, 'psql', '-U', 'meowscope', '-d', 'meowscope', '-tAc', sql]);

/** 専用の環境を丸ごと捨て、コンテナと volume が残っていないことを確かめる */
function down(dir?: string) {
  compose('down', '-v', '--remove-orphans');
  const left = out('docker', ['volume', 'ls', '-q', '--filter', `label=com.docker.compose.project=${PROJECT}`]);
  const containers = out('docker', ['ps', '-aq', '--filter', `label=com.docker.compose.project=${PROJECT}`]);
  const n = (s: string) => (s ? s.split('\n').length : 0);
  const line = `後片付け：volume ${n(left)} 個、コンテナ ${n(containers)} 個が残っている（0 なら目印のデータもすべて消えた）`;
  console.log(line);
  if (dir) appendFileSync(join(dir, 'cleanup.txt'), `${new Date().toISOString()} ${line}\n`);
  if (n(left) + n(containers) > 0) throw new Error('専用の環境が残っている');
}

/** CPU・メモリと DB の接続数を5秒ごとに記録する */
function startSampler(dir: string) {
  const file = join(dir, 'stats.csv');
  writeFileSync(file, 'time,container,cpu,mem,db_connections\n');
  const timer = setInterval(() => {
    try {
      const conns = psql('SELECT count(*) FROM pg_stat_activity');
      const rows = out('docker', [
        'stats',
        '--no-stream',
        '--format',
        '{{.Name}},{{.CPUPerc}},{{.MemUsage}}',
      ])
        .split('\n')
        .filter((l) => l.startsWith(PROJECT));
      const now = new Date().toISOString();
      for (const r of rows) appendFileSync(file, `${now},${r.replaceAll(' / ', '/')},${conns}\n`);
    } catch {
      // 環境の立ち上げ・片付けの間は取れない
    }
  }, 5000);
  return () => clearInterval(timer);
}

/** 時間のかかった SQL の上位を残す（遅かったときに原因を探す） */
function saveSlowSql(dir: string) {
  const sql =
    "SELECT round(mean_exec_time::numeric,2) AS mean_ms, round(max_exec_time::numeric,2) AS max_ms, calls, left(regexp_replace(query,'\\s+',' ','g'),160) FROM pg_stat_statements WHERE query NOT LIKE '%pg_stat%' ORDER BY total_exec_time DESC LIMIT 15";
  writeFileSync(join(dir, 'slow-sql.txt'), psql(sql) + '\n');
  const marked = psql("SELECT count(*) FROM users WHERE email LIKE 'perf-%@example.test'");
  const records = psql('SELECT count(*) FROM records');
  appendFileSync(join(dir, 'cleanup.txt'), `捨てる前の目印の利用者 ${marked} 人、記録 ${records} 件\n`);
}

function run(cmd: string, args: string[], opts: { cwd?: string; env?: NodeJS.ProcessEnv } = {}) {
  return new Promise<number>((res) => {
    const p = spawn(cmd, args, { stdio: 'inherit', shell: process.platform === 'win32', ...opts });
    p.on('exit', (code) => res(code ?? 1));
  });
}

function k6(test: string, dir: string, short: boolean) {
  const script = test === 'bulk' ? 'bulk-sync.ts' : 'load.ts';
  const slash = (p: string) => p.replaceAll('\\', '/');
  return run('docker', [
    'run',
    '--rm',
    '--network',
    `${PROJECT}_default`,
    '-v',
    `${slash(join(PERF, 'src'))}:/scripts:ro`,
    '-v',
    `${slash(dir)}:/out`,
    '-e',
    'BASE_URL=http://server:8080/api/v1',
    '-e',
    `SCENARIO=${test}`,
    '-e',
    `SHORT=${short ? 1 : 0}`,
    '-e',
    `YEARS=${short ? 1 : 5}`,
    '-e',
    'K6_WEB_DASHBOARD=true',
    '-e',
    'K6_WEB_DASHBOARD_EXPORT=/out/report.html',
    K6_IMAGE,
    'run',
    '--summary-export',
    '/out/summary.json',
    `/scripts/${script}`,
  ]);
}

async function startEmulator() {
  const devices = out(ADB, ['devices']);
  if (devices.includes('emulator-5554')) return;
  spawn(EMULATOR, ['-avd', AVD, '-no-snapshot-save'], { detached: true, stdio: 'ignore' }).unref();
  for (let i = 0; i < 90; i++) {
    try {
      if (out(ADB, ['-s', 'emulator-5554', 'shell', 'getprop', 'sys.boot_completed']) === '1') return;
    } catch {
      // 起動中
    }
    await new Promise((r) => setTimeout(r, 4000));
  }
  throw new Error('エミュレーターが起動しなかった');
}

/** PT-07：アプリの profile ビルドで、5年分のデータの画面の速さを測る（app/perf_test） */
async function app(test: string, dir: string, short: boolean) {
  const android = test === 'app-android';
  const device = test === 'app-device' ? realDevice() : null;
  if (android) await startEmulator();
  // 実機は USB を通して PC の 8081 につなぐ（Wi-Fi の速さで揺れず、ファイアウォールの設定も要らない）
  if (device) out(ADB, ['-s', device, 'reverse', 'tcp:8081', 'tcp:8081']);
  const api = android ? 'http://10.0.2.2:8081/api/v1' : `http://${device ? '127.0.0.1' : 'localhost'}:8081/api/v1`;
  // flutter test は debug ビルドでしか動かないので、テストのファイルを profile ビルドで flutter run し、
  // 出力の PERF_RESULT の行を受け取る（アプリの依存関係・ビルドの設定は変えない）
  const p = spawn(
    'flutter',
    [
      'run',
      '--profile',
      '-d',
      device ?? (android ? 'emulator-5554' : 'windows'),
      '-t',
      'perf_test/app_perf_test.dart',
      `--dart-define=API_BASE_URL=${api}`,
      `--dart-define=PERF_YEARS=${short ? 1 : 5}`,
    ],
    { cwd: join(ROOT, 'app'), shell: process.platform === 'win32' },
  );
  const log = join(dir, 'app.log');
  let result: AppResult | null = null;
  let failed = false;
  const onLine = (line: string) => {
    appendFileSync(log, line + '\n');
    const m = line.match(/PERF_RESULT (\{.*\})/);
    if (m) result = JSON.parse(m[1]) as AppResult;
    if (/Test failed|EXCEPTION CAUGHT|TestFailure/.test(line)) failed = true;
    if (result || failed) p.stdin.write('q');
  };
  let buf = '';
  const feed = (d: Buffer) => {
    buf += d.toString();
    const lines = buf.split(/\r?\n/);
    buf = lines.pop() ?? '';
    lines.forEach(onLine);
  };
  p.stdout.on('data', feed);
  p.stderr.on('data', feed);
  const timer = setTimeout(() => p.kill(), 60 * 60 * 1000);
  await new Promise((res) => p.on('exit', res));
  clearTimeout(timer);
  if (!result) {
    console.error(`アプリの計測が終わらなかった（${log}）`);
    return 1;
  }
  if (device) {
    out(ADB, ['-s', device, 'reverse', '--remove', 'tcp:8081']);
    (result as AppResult).ms['プロセスからの起動（am start の TotalTime）'] = coldStarts(device, log);
  }
  return judgeApp(result, dir, android);
}

/** つないでいる実機（PERF_DEVICE で選べる。なければエミュレーターでない最初の端末） */
function realDevice() {
  if (process.env.PERF_DEVICE) return process.env.PERF_DEVICE;
  const serial = out(ADB, ['devices'])
    .split(/\r?\n/)
    .slice(1)
    .map((l) => l.split(/\s+/))
    .find(([s, state]) => state === 'device' && !s.startsWith('emulator-'))?.[0];
  if (!serial) throw new Error('実機が見つからない（USB デバッグをオンにしてつなぐ）');
  return serial;
}

/**
 * アプリのプロセスを立ち上げる時間も含めた起動（3回）。いつものアプリを profile ビルドで入れ直し、
 * 止めてから `am start -W` で起動して TotalTime（最初の画面が出るまで）を見る
 */
function coldStarts(device: string, log: string) {
  const app = join(ROOT, 'app');
  const r = spawnSync('flutter', ['build', 'apk', '--profile'], { cwd: app, shell: true, encoding: 'utf8' });
  appendFileSync(log, r.stdout + r.stderr);
  if (r.status !== 0) throw new Error('いつものアプリの profile ビルドが失敗した');
  out(ADB, ['-s', device, 'install', '-r', join(app, 'build/app/outputs/flutter-apk/app-profile.apk')]);
  const pkg = 'com.meowscope.meowscope';
  const times: number[] = [];
  for (let i = 0; i < 3; i++) {
    out(ADB, ['-s', device, 'shell', 'am', 'force-stop', pkg]);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 3000);
    const s = out(ADB, ['-s', device, 'shell', 'am', 'start', '-W', '-n', `${pkg}/.MainActivity`]);
    appendFileSync(log, s + '\n');
    times.push(Number(s.match(/TotalTime:\s*(\d+)/)?.[1] ?? NaN));
  }
  out(ADB, ['-s', device, 'shell', 'am', 'force-stop', pkg]);
  return times;
}

type AppResult = { years: number; records: number; platform: string; ms: Record<string, number[]> };

/** アプリのしきい値（NF-PF-02・04）。合否は Windows で付け、Android のエミュレーターは参考値 */
const APP_LIMITS: Record<string, number> = {
  起動からホームの表示: 3000,
  記録の保存: 500,
  カレンダーを開く: 1000,
  カレンダーの月の切り替え: 1000,
  統計を開く: 1000,
  体調のようすの日付の切り替え: 1000,
  初めての全件の同期: 60000,
};

function judgeApp(r: AppResult, dir: string, reference: boolean) {
  const lines = [`${r.platform}：${r.years}年分、端末の記録 ${r.records} 件${reference ? '（参考値。合否に使わない）' : ''}`];
  let ok = true;
  for (const [name, values] of Object.entries(r.ms)) {
    const limit = APP_LIMITS[name];
    if (limit === undefined) {
      // 件数などの記録だけの値
      lines.push(`・${name}：${values.join('・')}`);
      continue;
    }
    const max = Math.max(...values);
    const pass = max <= limit;
    if (!pass) ok = false;
    lines.push(`${pass ? '✓' : '✗'} ${name}：${values.join('・')} ms（最大 ${max}、基準 ${limit} 以下）`);
  }
  writeFileSync(join(dir, 'app.json'), JSON.stringify(r, null, 2));
  writeFileSync(join(dir, 'app-summary.txt'), lines.join('\n') + '\n');
  console.log(lines.join('\n'));
  return ok || reference ? 0 : 1;
}

async function main() {
  const args = process.argv.slice(2);
  const short = args.includes('--short');
  const keep = args.includes('--keep');
  let tests = args.filter((a) => !a.startsWith('--'));
  if (tests[0] === 'down') {
    down();
    return;
  }
  if (tests.includes('night')) tests = NIGHT;
  const known = [...SERVER_TESTS, ...APP_TESTS] as readonly string[];
  if (tests.length === 0 || tests.some((t) => !known.includes(t))) {
    console.error(`使い方：node perf/run.ts <${known.join('|')}|night>… [--short] [--keep]`);
    process.exit(64);
  }
  const commit = out('git', ['-C', ROOT, 'rev-parse', '--short', 'HEAD']);
  let failed = 0;
  for (const test of tests) {
    const stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const dir = join(PERF, 'results', `${stamp}_${IDS[test]}_${test}${short ? '_short' : ''}`);
    mkdirSync(dir, { recursive: true });
    writeFileSync(
      join(dir, 'env.txt'),
      [
        `テスト：${IDS[test]} ${test}${short ? '（時間を縮めた動作の確認。合否・記録には使わない）' : ''}`,
        `開始：${new Date().toISOString()}`,
        `コミット：${commit}`,
        `マシン：${cpus()[0]?.model}（${cpus().length} スレッド）、メモリ ${Math.round(totalmem() / 2 ** 30)}GB`,
        `k6：${K6_IMAGE}`,
      ].join('\n') + '\n',
    );
    console.log(`\n=== ${IDS[test]} ${test}${short ? '（短縮）' : ''} → ${dir}`);
    const interrupted = () => {
      console.log('中断した。専用の環境を捨てる');
      if (!keep) down(dir);
      process.exit(130);
    };
    process.once('SIGINT', interrupted);
    let stop = () => {};
    let code = 1;
    try {
      await up();
      stop = startSampler(dir);
      code = (SERVER_TESTS as readonly string[]).includes(test)
        ? await k6(test, dir, short)
        : await app(test, dir, short);
      saveSlowSql(dir);
    } finally {
      stop();
      process.removeListener('SIGINT', interrupted);
      if (!keep) down(dir);
    }
    appendFileSync(join(dir, 'env.txt'), `終了：${new Date().toISOString()}\n結果：${code === 0 ? '合格' : `不合格（${code}）`}\n`);
    console.log(`=== ${IDS[test]} ${test}：${code === 0 ? 'しきい値を満たした' : `しきい値を満たさなかった（${code}）`}`);
    if (code !== 0) failed++;
  }
  process.exit(failed > 0 ? 1 : 0);
}

await main();
