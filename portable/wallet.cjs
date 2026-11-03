#!/usr/bin/env node
/**
 * U-Hermes 马盘 · 设备钱包（客户端半边）
 *
 * 分工：客户端只持**一把可换的凭证**；签发、余额、计费、支付全在服务端（闭源）。
 * 绝不用硬件指纹派生 key —— 读得到序列号就能花你的钱，而且泄露了换不掉。
 *
 * 六条硬契约（改代码前先看）：
 *   C1 首启收敛**绝不抛异常**（连打开存储都要在 try 里）
 *   C2 验证只用只读接口，不消耗额度
 *   C3 状态不认识时不猜
 *   C4 凭证只有一个真相源（收敛路径要 in-flight 去重）
 *   C5 换 key 后必须同步到真正用 key 的地方
 *   C6 存储损坏退化成"未绑定"，所以界面必须有「填入已有」
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const https = require('node:https');

const ENDPOINTS = ['https://api.u-claw.org', 'https://api.u-claw.org.cn'];
const TIMEOUT_MS = 6000;

let inFlight = null;

// ────────────────────────────────── 存储（五字段，一个都不能省）
function statePath(dataRoot) { return path.join(dataRoot, 'wallet.json'); }

function readState(dataRoot) {
  try {
    const raw = fs.readFileSync(statePath(dataRoot), 'utf8');
    const s = JSON.parse(raw);
    return {
      apiKey: typeof s.apiKey === 'string' ? s.apiKey : undefined,
      walletId: typeof s.walletId === 'string' ? s.walletId : undefined,
      pendingKey: typeof s.pendingKey === 'string' ? s.pendingKey : undefined,
      pendingKind: typeof s.pendingKind === 'string' ? s.pendingKind : undefined,
      pendingFrom: typeof s.pendingFrom === 'string' ? s.pendingFrom : undefined,
    };
  } catch {
    // 文件不存在 / 写坏 / U 盘拔了 —— 一律退化成「还没绑定」
    return {};
  }
}

function writeState(dataRoot, state) {
  const p = statePath(dataRoot);
  const tmp = p + '.tmp';
  const body = JSON.stringify(state, null, 2);
  fs.mkdirSync(dataRoot, { recursive: true });
  const fd = fs.openSync(tmp, 'w');
  try { fs.writeSync(fd, body); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
  fs.renameSync(tmp, p);
  try { fs.chmodSync(p, 0o600); } catch { /* exFAT/NTFS 上无 Unix 权限位，忽略 */ }
}

// ────────────────────────────────── 网络（多端点 failover）
function request(base, method, urlPath, body, headers) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlPath, base);
    const mod = u.protocol === 'https:' ? https : http;
    const payload = body ? Buffer.from(JSON.stringify(body)) : null;
    const req = mod.request(u, {
      method,
      timeout: TIMEOUT_MS,
      headers: Object.assign(
        { accept: 'application/json' },
        payload ? { 'content-type': 'application/json', 'content-length': payload.length } : {},
        headers || {},
      ),
    }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const text = Buffer.concat(chunks).toString('utf8');
        let json = null;
        try { json = JSON.parse(text); } catch {}
        resolve({ status: res.statusCode, json, text, base });
      });
    });
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function callAll(method, urlPath, body, headers) {
  let lastErr;
  for (const base of ENDPOINTS) {
    try { return await request(base, method, urlPath, body, headers); }
    catch (e) { lastErr = e; }
  }
  throw lastErr || new Error('所有端点都不可达');
}

// ────────────────────────────────── 动作
async function bind() {
  const res = await callAll('POST', '/device/bind', {
    platform: process.platform, channel: 'u-hermes-mapan',
  });
  if (res.status !== 200 || !res.json?.apiKey) {
    throw new Error(`bind 失败 HTTP ${res.status}`);
  }
  return { apiKey: res.json.apiKey, walletId: res.json.walletId || '' };
}

/** 只读验证：0 余额的 key 用真实模型调用永远验不通（C2） */
async function verify(apiKey) {
  const res = await callAll('GET', '/api/usage/token/', null, { authorization: `Bearer ${apiKey}` });
  return res.status === 200;
}

async function settlePending(dataRoot, state, log) {
  const kind = state.pendingKind;
  if (kind !== 'rotate') {
    log && log('WARN 未知的 pendingKind，保留现状不猜：', String(kind)); // C3
    return state;
  }
  const ok = await verify(state.pendingKey);            // C2：不消耗额度
  if (!ok) return state;                                 // 下次启动再收敛，旧 key 仍有效
  try {
    const res = await callAll('POST', '/device/rotate/commit', {
      currentKey: state.pendingFrom, newKey: state.pendingKey,
    });
    if (res.status !== 200) throw new Error(`HTTP ${res.status}`);
    const next = { apiKey: state.pendingKey, walletId: state.walletId };
    writeState(dataRoot, next);
    log && log('pending 已收尾：新 key 转正');
    return next;
  } catch (e) {
    log && log('WARN pending 收尾失败，稍后重试：', e.message);
    return state;
  }
}

async function doEnsure({ dataRoot, log }) {
  let state = {};
  try {
    state = readState(dataRoot);                        // C1：连读都要保护
  } catch (e) {
    log && log('WARN 打不开钱包存储：', e.message);
    return { apiKey: '', walletId: '' };
  }
  try {
    if (state.pendingKey) state = await settlePending(dataRoot, state, log);
    if (state.apiKey) return { apiKey: state.apiKey, walletId: state.walletId || '' };

    const fresh = await bind();
    const next = { apiKey: fresh.apiKey, walletId: fresh.walletId };
    writeState(dataRoot, next);
    log && log('已绑定新设备钱包');
    return next;
  } catch (e) {
    log && log('WARN 钱包收敛失败（不阻断启动）：', e.message);
    return { apiKey: state.apiKey || '', walletId: state.walletId || '' };
  }
}

function ensureDeviceKey(deps) { return (inFlight ??= doEnsure(deps).finally(() => { inFlight = null; })); }

/** 换一把：两阶段。已失败过就续用那把，不要重新 mint（会在服务端留一堆悬空 key）。 */
async function rotateDeviceKey({ dataRoot, log }) {
  const state = readState(dataRoot);
  if (state.pendingKey) return ensureDeviceKey({ dataRoot, log });
  if (!state.apiKey) throw new Error('还没有钱包，先让首启自动绑定');
  const res = await callAll('POST', '/device/rotate', { currentKey: state.apiKey });
  if (res.status !== 200 || !res.json?.apiKey) throw new Error(`rotate 失败 HTTP ${res.status}`);
  writeState(dataRoot, Object.assign({}, state, {
    pendingKey: res.json.apiKey, pendingKind: 'rotate', pendingFrom: state.apiKey,
  }));
  log && log('已 mint 新 key，等下次启动 commit');
  return { apiKey: state.apiKey, walletId: state.walletId || '' };
}

/** 填一把：纯本地 + 一次只读验证。认了才落盘（写错的 key 比没有更坑） */
async function adoptDeviceKey({ dataRoot, apiKey, log }) {
  if (!/^sk-\S{16,}$/.test(apiKey || '')) throw new Error('密钥格式不对（应以 sk- 开头）');
  const ok = await verify(apiKey);
  if (!ok) throw new Error('这把密钥验证没通过，没有保存');
  writeState(dataRoot, { apiKey });
  log && log('已填入已有密钥');
}

/** 移除本机：不删服务端余额（C5：先清消费者由调用方负责） */
function resetLocalWallet({ dataRoot, log }) {
  const state = readState(dataRoot);
  if (state.pendingKey && state.pendingKind !== 'rotate') {
    throw new Error('存在未知的进行中操作，先别动');
  }
  writeState(dataRoot, {});
  log && log('已移除本机钱包（服务端余额不动，旧 key 仍可填入找回）');
}

// ────────────────────────────────── 注入（唯一出口）
function envPath(hermesHome) { return path.join(hermesHome, '.env'); }

function upsertEnv(file, kv) {
  let lines = [];
  try { lines = fs.readFileSync(file, 'utf8').split(/\r?\n/); } catch {}
  const keep = lines.filter((l) => {
    const m = l.match(/^\s*([A-Z0-9_]+)\s*=/);
    return !(m && m[1] in kv);
  });
  const add = Object.entries(kv).map(([k, v]) => `${k}=${v}`);
  const out = keep.filter((l, i) => l !== '' || i < keep.length - 1).concat(add).join('\n');
  const tmp = file + '.tmp';
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(tmp, out.endsWith('\n') ? out : out + '\n');
  try { fs.chmodSync(tmp, 0o600); } catch {}
  fs.renameSync(tmp, file);
}

function applyKey({ hermesHome, log }) {
  const dataRoot = path.dirname(hermesHome); // 约定：<dataRoot>/hermes-home
  const s = readState(dataRoot);
  if (!s.apiKey) {
    log && log('没有可用凭证，跳过写入');
    return;
  }
  upsertEnv(envPath(hermesHome), {
    OPENAI_API_KEY: s.apiKey,
    OPENAI_BASE_URL: 'https://api.u-claw.org/v1',
  });
  log && log('已把钱包凭证写进 HERMES_HOME/.env');
}

module.exports = {
  ensureDeviceKey, rotateDeviceKey, adoptDeviceKey, resetLocalWallet, applyKey,
  readState, writeState, ENDPOINTS,
};
