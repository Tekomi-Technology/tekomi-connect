import { readFile } from 'node:fs/promises';
import fetch from 'node-fetch';
import { buildProxyOptions } from '../src/proxyOptions.js';
import { parseProxyList } from '../src/proxyPool.js';

const path = process.argv[2] ?? process.env.ZALO_PROXY_POOL_FILE;
if (!path) throw new Error('usage: npm run proxy:check -- /path/to/proxies.txt');

const proxies = parseProxyList(await readFile(path, 'utf8'), path);
if (!proxies.length) throw new Error('proxy list is empty');

let failed = 0;
for (const [index, proxy] of proxies.entries()) {
  const started = Date.now();
  try {
    const response = await fetch('https://api.ipify.org?format=json', {
      ...(buildProxyOptions(proxy) as object),
      timeout: 15_000,
    } as never);
    const body = await response.text();
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const ip = JSON.parse(body).ip ?? 'unknown';
    console.log(`proxy-${index + 1}: OK ${ip} (${Date.now() - started}ms)`);
  } catch (error) {
    failed += 1;
    console.error(`proxy-${index + 1}: FAILED ${error instanceof Error ? error.message : String(error)}`);
  }
}

console.log(`checked=${proxies.length} failed=${failed}`);
if (failed) process.exitCode = 1;
