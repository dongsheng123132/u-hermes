#!/usr/bin/env node
/**
 * U-Hermes 马盘 · 引擎安装器
 *
 * 一条铁律：**客户机不装东西、不联网下载内核**。引擎是构建期打好的单归档，
 * 运行期只做四件事：校验 → 空间预检 → 解到本机缓存 → 原子落地。
 *
 * 为什么解到本机而不是盘上：U 盘顺序读还行、随机读写差，且寿命有限。
 * 引擎是**可重建缓存**，数据才是资产。
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

function hostEngineBase() {
  if (process.platform === 'win32') {
    const base = process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local');
    return path.join(base, 'U-Hermes', 'engine');
  }
  if (process.platform === 'darwin') {
    return path.join(os.homedir(), 'Library', 'Caches', 'U-Hermes', 'engine');
  }
  const base = process.env.XDG_CACHE_HOME || path.join(os.homedir(), '.cache');
  return path.join(base, 'u-hermes', 'engine');
}

function sha256File(file) {
  const h = crypto.createHash('sha256');
  const fd = fs.openSync(file, 'r');
  const buf = Buffer.allocUnsafe(1 << 20);
  try {
    let n;
    while ((n = fs.readSync(fd, buf, 0, buf.length, null)) > 0) h.update(buf.subarray(0, n));
  } finally { fs.closeSync(fd); }
  return h.digest('hex');
}

function freeBytes(dir) {
  try {
    // Node 18.6+ 提供 statfs；拿不到就放行（宁可试一次也不误拦）
    const st = fs.statfsSync ? fs.statfsSync(dir) : null;
    if (!st) return null;
    return Number(st.bsize) * Number(st.bavail);
  } catch { return null; }
}

function sweepStaleStaging(base) {
  let entries = [];
  try { entries = fs.readdirSync(base); } catch { return; }
  const cut = Date.now() - 2 * 3600 * 1000;
  for (const name of entries) {
    if (!name.startsWith('.staging-')) continue;
    const p = path.join(base, name);
    try {
      if (fs.statSync(p).mtimeMs < cut) { fs.rmSync(p, { recursive: true, force: true }); }
    } catch { /* 被占用就算了 */ }
  }
}

function ensureEngine({ log = console.log, say = () => {} } = {}) {
  const appRoot = __dirname;
  const pkgRoot = path.resolve(appRoot, '..');
  const manifestPath = path.join(appRoot, 'engine.json');

  if (!fs.existsSync(manifestPath)) {
    throw new Error('缺少 app/engine.json，这个 U 盘包不完整');
  }
  const man = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  for (const k of ['version', 'sha256', 'archive', 'entry']) {
    if (!man[k]) throw new Error(`engine.json 缺字段：${k}`);
  }

  const base = hostEngineBase();
  const target = path.join(base, man.version);
  const marker = path.join(target, '.ready');
  const entry = path.join(target, man.entry);

  // 已就位：只做纯本地校验，毫秒级
  if (fs.existsSync(marker) && fs.existsSync(entry)) {
    fs.writeFileSync(marker, String(Date.now()));
    return { entry, version: man.version, reused: true };
  }

  fs.mkdirSync(base, { recursive: true });
  sweepStaleStaging(base);

  const archive = path.join(appRoot, man.archive);
  if (!fs.existsSync(archive)) {
    throw new Error(`找不到引擎归档 ${man.archive}（U 盘拷贝不完整）`);
  }

  // 校验（坏 U 盘真会发生：同一文件连拷两次校验和都能不一样）
  log('校验引擎归档…');
  const got = sha256File(archive);
  if (got !== String(man.sha256).toLowerCase()) {
    throw new Error(`引擎归档校验失败（期望 ${man.sha256.slice(0, 12)}… 实际 ${got.slice(0, 12)}…）——请重新完整拷贝一次 U 盘`);
  }

  // 空间预检（不留给客户一堆 ENOSPC）
  const need = Number(man.unpackedBytes || 0) || 900 * 1024 * 1024;
  const free = freeBytes(base);
  if (free != null && free < need * 1.2) {
    throw new Error(`本机剩余空间不足：需要约 ${Math.ceil(need / 1048576)} MB，可用 ${Math.floor(free / 1048576)} MB。清理后重试。`);
  }

  // 解包到 staging → 原子 rename
  const staging = path.join(base, `.staging-${process.pid}`);
  fs.rmSync(staging, { recursive: true, force: true });
  fs.mkdirSync(staging, { recursive: true });
  say('   首次启动：正在把程序放到本机（约 10 秒）…');
  log('解包到 staging：', staging);

  const tar = spawnSync('tar', ['-xzf', archive, '-C', staging], {
    stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true,
  });
  if (tar.status !== 0) {
    const err = (tar.stderr || Buffer.from('')).toString('utf8').slice(0, 400);
    fs.rmSync(staging, { recursive: true, force: true });
    throw new Error('解包失败：' + (err || `tar exit ${tar.status}`));
  }

  // 归档内若多套了一层目录，剥掉
  let root = staging;
  const kids = fs.readdirSync(staging);
  if (kids.length === 1 && fs.statSync(path.join(staging, kids[0])).isDirectory()) {
    root = path.join(staging, kids[0]);
  }

  fs.rmSync(target, { recursive: true, force: true });
  try {
    fs.renameSync(root, target);
  } catch (e) {
    if (e.code === 'EXDEV' || e.code === 'EPERM') {
      fs.cpSync(root, target, { recursive: true });
      fs.rmSync(staging, { recursive: true, force: true });
    } else { throw e; }
  }
  fs.rmSync(staging, { recursive: true, force: true });

  if (!fs.existsSync(entry)) {
    throw new Error(`解包完成但找不到入口 ${man.entry}`);
  }
  fs.writeFileSync(marker, String(Date.now()));
  log('引擎就位：', target);
  return { entry, version: man.version, reused: false };
}

module.exports = { ensureEngine, hostEngineBase, sha256File };

if (require.main === module) {
  const r = ensureEngine({});
  console.log(JSON.stringify(r, null, 2));
}
