import type { Agent } from 'node:http';
import { HttpsProxyAgent } from 'https-proxy-agent';
import { SocksProxyAgent } from 'socks-proxy-agent';
import nodeFetch from 'node-fetch';
import type { ProxyConnection } from './types.js';

export interface ProxyOptions {
  agent?: Agent;
  polyfill?: typeof fetch;
}

export function proxyUrl(proxy: ProxyConnection): string {
  const auth = proxy.username
    ? `${encodeURIComponent(proxy.username)}:${encodeURIComponent(proxy.password ?? '')}@`
    : '';
  return `${proxy.protocol}://${auth}${proxy.host}:${proxy.port}`;
}

const proxiedFetch = async (url: Parameters<typeof nodeFetch>[0], init?: Parameters<typeof nodeFetch>[1]) => {
  const response = await nodeFetch(url, init);
  Object.assign(response.headers, { getSetCookie: () => response.headers.raw()['set-cookie'] ?? [] });
  return response;
};

/** zca-js uses the agent for websocket traffic and its fetch polyfill for HTTP API calls. */
export function buildProxyOptions(proxy: ProxyConnection | null | undefined): ProxyOptions {
  if (!proxy) return {};
  const url = proxyUrl(proxy);
  const agent = proxy.protocol === 'socks5' ? new SocksProxyAgent(url) : new HttpsProxyAgent(url);
  return { agent: agent as unknown as Agent, polyfill: proxiedFetch as unknown as typeof fetch };
}
