import { describe, expect, it } from 'vitest';
import { parseProxyLine, parseProxyList, ProxyPool } from '../src/proxyPool.js';

describe('proxy list parsing', () => {
  it('parses Webshare host:port:user:password rows', () => {
    expect(parseProxyLine('31.59.20.176:6754:user:pass')).toEqual({
      protocol: 'http', host: '31.59.20.176', port: 6754, username: 'user', password: 'pass',
    });
  });

  it('parses URL rows and ignores comments/blanks', () => {
    expect(parseProxyList('# comment\n\nhttps://u:p@example.test:8443')).toEqual([{
      protocol: 'https', host: 'example.test', port: 8443, username: 'u', password: 'p',
    }]);
  });

  it('keeps a deterministic proxy per channel and round-robins QR assignments', () => {
    const pool = new ProxyPool(parseProxyList('a:1:u:p\nb:2:u:p\nc:3:u:p'));
    expect(pool.assign(1)?.host).toBe('a');
    expect(pool.assign(2)?.host).toBe('b');
    expect(pool.assign(3)?.host).toBe('c');
    expect(pool.assign()?.host).toBe('a');
    expect(pool.assign(undefined, { protocol: 'http', host: 'saved', port: 1, username: null, password: null })?.host).toBe('saved');
  });
});
