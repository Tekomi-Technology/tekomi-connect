import { readFile } from 'node:fs/promises';
import type { ProxyConnection, ProxyProtocol } from './types.js';

const DEFAULT_PROTOCOL: ProxyProtocol = 'http';

function parsePort(value: string, source: string): number {
  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`invalid proxy port in ${source}`);
  }
  return port;
}

/** Supports Webshare's host:port:user:password format and normal proxy URLs. */
export function parseProxyLine(raw: string, source = 'proxy list'): ProxyConnection | null {
  const line = raw.trim();
  if (!line || line.startsWith('#')) return null;

  if (line.includes('://')) {
    const url = new URL(line);
    const protocol = url.protocol.slice(0, -1) as ProxyProtocol;
    if (!['http', 'https', 'socks5'].includes(protocol)) throw new Error(`unsupported proxy protocol in ${source}`);
    if (!url.hostname || !url.port) throw new Error(`proxy URL needs host and port in ${source}`);
    return {
      protocol,
      host: url.hostname,
      port: parsePort(url.port, source),
      username: url.username ? decodeURIComponent(url.username) : null,
      password: url.password ? decodeURIComponent(url.password) : null,
    };
  }

  const parts = line.split(':');
  if (parts.length !== 2 && parts.length !== 4) throw new Error(`expected host:port or host:port:user:password in ${source}`);
  const [host, port, username, password] = parts;
  if (!host || !port) throw new Error(`proxy host and port are required in ${source}`);
  return {
    protocol: DEFAULT_PROTOCOL,
    host,
    port: parsePort(port, source),
    username: parts.length === 4 ? username || null : null,
    password: parts.length === 4 ? password || null : null,
  };
}

export function parseProxyList(raw: string, source = 'proxy list'): ProxyConnection[] {
  return raw.split(/\r?\n|,/).map((line, index) => parseProxyLine(line, `${source}:${index + 1}`)).filter((p): p is ProxyConnection => p !== null);
}

/**
 * Assigns one proxy per channel. The assignment is deterministic when a channel id exists;
 * credentials then carry the selected proxy so restarts and reconnects never rotate identity.
 */
export class ProxyPool {
  private next = 0;

  constructor(private readonly proxies: ProxyConnection[]) {}

  static async fromEnvironment(env: NodeJS.ProcessEnv = process.env): Promise<ProxyPool> {
    const inline = env.ZALO_PROXY_POOL?.trim();
    const file = env.ZALO_PROXY_POOL_FILE?.trim();
    if (inline) return new ProxyPool(parseProxyList(inline, 'ZALO_PROXY_POOL'));
    if (file) return new ProxyPool(parseProxyList(await readFile(file, 'utf8'), file));
    return new ProxyPool([]);
  }

  get size(): number { return this.proxies.length; }

  assign(channelId?: number, existing?: ProxyConnection): ProxyConnection | undefined {
    if (existing) return existing;
    if (!this.proxies.length) return undefined;
    const index = channelId == null ? this.next++ % this.proxies.length : (Math.max(1, channelId) - 1) % this.proxies.length;
    return this.proxies[index];
  }

}
