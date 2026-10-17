'use strict';
// 用环境变量填充 xray-config.template.json，写出实际配置。
// 出错信息只说"哪个变量有问题"，绝不输出变量的值。
const fs = require('fs');
const path = require('path');

const env = process.env;
const fail = (msg) => { console.error('[gen-config] 错误：' + msg); process.exit(1); };
const get = (k) => (env[k] || '').trim();
const need = (k) => { const v = get(k); if (!v) fail(k + ' 未设置'); return v; };

const out = process.argv[2];
if (!out) fail('缺少输出路径参数');

const port = Number(need('XRAY_PORT'));
if (!Number.isInteger(port) || port < 1 || port > 65535) fail('XRAY_PORT 不是有效端口');
if (String(port) === (get('PORT') || '8080')) fail('XRAY_PORT 不能等于 PORT');

const uuid = need('XRAY_UUID');
if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uuid)) fail('XRAY_UUID 格式不对');

const priv = need('REALITY_PRIVATE_KEY');
if (!/^[A-Za-z0-9_-]{43}$/.test(priv)) fail('REALITY_PRIVATE_KEY 格式不对（应为 43 个字符）');

const shortId = need('REALITY_SHORT_ID');
if (!/^([0-9a-f]{2}){1,8}$/i.test(shortId)) fail('REALITY_SHORT_ID 格式不对（应为 2~16 位偶数长度的十六进制）');

let dest = need('REALITY_DEST');
if (!/^[A-Za-z0-9.-]+(:\d{1,5})?$/.test(dest)) fail('REALITY_DEST 格式不对（例：www.example.com:443）');
if (!dest.includes(':')) dest += ':443';

const names = need('REALITY_SERVER_NAMES').split(',').map((s) => s.trim()).filter(Boolean);
if (!names.length || !names.every((n) => /^[A-Za-z0-9.-]+$/.test(n))) fail('REALITY_SERVER_NAMES 格式不对（多个用英文逗号分隔）');

const cfg = JSON.parse(fs.readFileSync(path.join(__dirname, 'xray-config.template.json'), 'utf8'));
const inb = cfg.inbounds[0];
inb.port = port;
inb.settings.clients[0].id = uuid;
const rs = inb.streamSettings.realitySettings;
rs.dest = dest;
rs.serverNames = names;
rs.privateKey = priv;
rs.shortIds = [shortId];

fs.writeFileSync(out, JSON.stringify(cfg), { mode: 0o600 });
console.log('[gen-config] 配置已生成');
