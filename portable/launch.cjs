#!/usr/bin/env node
/**
 * U-Hermes 马盘 · 便携启动器
 *
 * 职责只有五件，别往里加东西：
 *   1. 从 __dirname 现推所有路径（永不信盘符）
 *   2. 单实例锁
 *   3. 确保引擎就位（交给 engine-install.cjs）
 *   4. 剥宿主机 provider env + 注入 HERMES_HOME
 *   5. 起 dashboard、抓真实 URL、开浏览器、退出时收子进程
 *
 * 界面不在这里做。浏览器就是界面。
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const net = require('node:net');
const { spawn } = require('node:child_process');

const appRoot = __dirname;                       // <盘>\U-Hermes\app
const pkgRoot = path.resolve(appRoot, '..');     // <盘>\U-Hermes
const dataRoot = path.join(pkgRoot, 'data');
const hermesHome = path.join(dataRoot, 'hermes-home');

const logDir = path.join(dataRoot, 'logs');
fs.mkdirSync(logDir, { recursive: true });
const logFile = path.join(logDir, 'launcher.log');
const log = (...a) => {
  const line = `[${new Date().toISOString()}] ${a.join(' ')}`;
  try { fs.appendFileSync(logFile, line + '\n'); } catch { /* 盘只读也别崩 */ }
  console.log(line);
};

const say = (msg) => { try { process.stdout.write(msg + '\n'); } catch {} };

// ─────────────────────────────────────────────── 1. 单实例
function acquireLock() {
  const lockPath = path.join(os.tmpdir ? hostStateDir() : '.', 'launch.lock');
  try {
    if (fs.existsSync(lockPath)) {
      const prev = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
      if (prev.pid && isAlive(prev.pid) && prev.host === os.hostname()) {
        say('马盘已经在运行了，这次就不重复启动了。');
        process.exit(0);
      }
      if (prev.drive && prev.drive !== pkgRoot.slice(0, 2) && prev.host !== os.hostname()) {
        log('WARN 同一张盘被另一台电脑在用：', prev.host, prev.drive);
        say('提示：这张盘好像正在另一台电脑上使用，两边同时写可能冲突。');
      }
    }
    fs.writeFileSync(lockPath, JSON.stringify({
      pid: process.pid, host: os.hostname(), drive: pkgRoot.slice(0, 2), at: Date.now(),
    }));
    process.on('exit', () => { try { fs.unlinkSync(lockPath); } catch {} });
  } catch (e) {
    log('WARN 单实例锁写入失败（不阻断）：', e.message);
  }
}

function hostStateDir() {
  const base = process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local');
  const dir = path.join(base, 'U-Hermes');
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

function isAlive(pid) {
  try { process.kill(pid, 0); return true; } catch { return false; }
}

// ─────────────────────────────────────────────── 2. provider env 剥离
/** 宿主机的 API Key 会被内核当成"已配置"并静默算到别人头上，必须剥掉。 */
const PROVIDER_ENV = [
  'OPENAI_API_KEY', 'OPENAI_BASE_URL', 'OPENAI_ORG_ID',
  'ANTHROPIC_API_KEY', 'ANTHROPIC_BASE_URL',
  'DEEPSEEK_API_KEY', 'DASHSCOPE_API_KEY', 'MOONSHOT_API_KEY',
  'GEMINI_API_KEY', 'GOOGLE_API_KEY', 'OPENROUTER_API_KEY',
  'XAI_API_KEY', 'GROQ_API_KEY', 'MISTRAL_API_KEY', 'SILICONFLOW_API_KEY',
  'ZHIPU_API_KEY', 'ARK_API_KEY', 'TOGETHER_API_KEY', 'FIREWORKS_API_KEY',
  'PERPLEXITY_API_KEY', 'COHERE_API_KEY', 'HF_TOKEN', 'AZURE_OPENAI_API_KEY',
];

function cleanEnv(extra) {
  const env = { ...process.env };
  let stripped = 0;
  for (const k of PROVIDER_ENV) if (k in env) { delete env[k]; stripped++; }
  if (stripped) log(`已剥离宿主机 provider 变量 ${stripped} 个（避免串号计费）`);
  for (const k of Object.keys(env)) {
    if (/_API_KEY$|_TOKEN$/.test(k) && k.startsWith('HERMES_')) delete env[k];
  }
  return Object.assign(env, {
    HERMES_HOME: hermesHome,
    PYTHONIOENCODING: 'utf-8',
    PYTHONUTF8: '1',
    NO_PROXY: dedupeNoProxy(env.NO_PROXY),
  }, extra || {});
}


function dedupeNoProxy(current) {
  const base = ['127.0.0.1', 'localhost', '::1'];
  const extra = String(current || '').split(',').map((x) => x.trim()).filter(Boolean)
    .filter((x) => !base.includes(x));
  return base.concat(extra).join(',');
}

// ─────────────────────────────────────────────── 3. 端口
const PORT_POOL = [9119, 9120, 9121, 9122, 9123];

function probePort(port) {
  return new Promise((resolve) => {
    const srv = net.createServer();
    srv.once('error', () => resolve(false));
    srv.once('listening', () => srv.close(() => resolve(true)));
    srv.listen(port, '127.0.0.1');
  });
}

async function pickPort() {
  for (const p of PORT_POOL) if (await probePort(p)) return p;
  return 0; // 全占就让系统分配，交给 stdout 兜底
}

// ─────────────────────────────────────────────── 4. 主流程
async function main() {
  say('🐎 U-Hermes 马盘 启动中…');
  acquireLock();
  fs.mkdirSync(hermesHome, { recursive: true });

  // 4.1 引擎
  let engine;
  try {
    engine = require('./engine-install.cjs').ensureEngine({ log, say });
  } catch (e) {
    log('FATAL 引擎安装失败：', e.stack || e.message);
    say('❌ 程序本体没准备好。');
    say('   把 U 盘重新完整拷贝一次（不要只拷一部分），再试。');
    return 2;
  }

  // 4.2 钱包（失败不阻断）
  let wallet = { apiKey: '', walletId: '' };
  try {
    wallet = await require('./wallet.cjs').ensureDeviceKey({ dataRoot, log });
  } catch (e) {
    log('WARN 钱包收敛失败，本次跳过（不影响启动）：', e.message);
  }
  if (wallet.apiKey) {
    try { require('./wallet.cjs').applyKey({ hermesHome, log }); } catch (e) {
      log('WARN 写配置失败：', e.message);
    }
    say('   ✓ 设备钱包就位');
  } else {
    say('   钱包暂不可用 —— 应用照常打开，配好 Key 或用本地模型就能用');
  }

  // 4.3 起服务
  const port = await pickPort();
  const entry = engine.entry;
  const args = ['dashboard', '--host', '127.0.0.1', '--port', String(port)];
  log('启动：', entry, args.join(' '));

  const child = spawn(entry, args, {
    cwd: pkgRoot, env: cleanEnv({ PORT: String(port) }), stdio: ['ignore', 'pipe', 'pipe'],
    shell: false, windowsHide: true,
  });

  const urlFrom = /https?:\/\/127\.0\.0\.1:(\d+)\S*/;
  let opened = false;
  const onData = (buf) => {
    const text = buf.toString('utf8');
    log('[hermes]', text.trimEnd().split('\n').slice(-2).join(' | '));
    if (opened) return;
    const m = text.match(urlFrom);
    if (m) { opened = true; openBrowser(m[0]); }
  };
  child.stdout.on('data', onData);
  child.stderr.on('data', onData);

  child.on('exit', (code, sig) => {
    log(`内核退出 code=${code} sig=${sig}`);
    say(`\n内核已退出（code=${code}）。日志：${logFile}`);
  });
  child.on('error', (e) => {
    log('FATAL 起不来：', e.message);
    say('❌ 程序启动失败：' + e.message);
    say(`   日志：${logFile}`);
  });

  // 兜底：30 秒还没抓到 URL，就当端口已知，直接开
  setTimeout(() => {
    if (opened) return;
    opened = true;
    const guess = `http://127.0.0.1:${port || 9119}`;
    log('未从输出里抓到 URL，按端口猜测开：', guess);
    openBrowser(guess);
  }, 30000);

  const shutdown = () => {
    log('收到退出信号，结束子进程');
    try { child.kill(); } catch {}
    process.exit(0);
  };
  for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP', 'SIGBREAK'])
    try { process.on(sig, () => { shutdown(); process.exit(0); }); } catch {}
  process.on('exit', () => { try { child.kill(); } catch {} });

  say(`   ✓ 已启动，界面地址：http://127.0.0.1:${port || '自动'}`);
  say('   （关闭本窗口不会关掉服务；再双击一次会复用已在跑的那份）');
  // 保活：子进程活着就不退出，让它自己接管控制台
  return new Promise((resolve) => child.on('close', (c) => resolve(c || 0)));
}

function openBrowser(url) {
  try {
    if (process.platform === 'win32') {
      spawn('cmd', ['/c', 'start', '""', url], { detached: true, stdio: 'ignore', windowsHide: true }).unref();
    } else if (process.platform === 'darwin') {
      spawn('open', [url], { detached: true, stdio: 'ignore' }).unref();
    } else {
      spawn('xdg-open', [url], { detached: true, stdio: 'ignore' }).unref();
    }
    say('   已在浏览器打开：' + url);
  } catch (e) {
    say('   打不开浏览器，请手动访问：' + url);
  }
}

if (require.main === module) {
  main().then((code) => process.exit(code || 0)).catch((e) => {
    log('FATAL 未捕获：', e.stack || e.message);
    say('❌ 启动器异常：' + e.message);
    process.exit(1);
  });
}

module.exports = { main, cleanEnv, PROVIDER_ENV, hermesHome, pkgRoot };
