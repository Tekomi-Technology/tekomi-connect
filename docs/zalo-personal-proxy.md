# Zalo Personal proxy pool

`zca-js` keeps one WebSocket session per Zalo personal account. The worker now routes both
the QR login and the live session through a per-account proxy, so several accounts can run
concurrently without sharing the server's public IP.

Configure the worker with either:

```dotenv
ZALO_PROXY_POOL_FILE=/run/secrets/zalo-proxies.txt
```

Each line may use Webshare's format:

```text
host:port:username:password
```

or a URL such as `http://username:password@host:port`. HTTP, HTTPS and SOCKS5 are supported.
The pool is assigned deterministically by `channel_id`; a new QR login uses the next pool
entry. After login, the selected proxy is stored inside the encrypted Zalo credentials, so
reconnects and worker restarts retain the same egress identity.

For a re-authentication, Chatwoot sends the existing `channel_id` to the worker and the worker
reuses that account's saved proxy. If no pool is configured, behavior remains direct-connect.

Check a pool without logging into Zalo:

```sh
cd zalo_worker
npm run proxy:check -- /path/to/proxies.txt
```

The command checks `https://api.ipify.org` through each entry and does not print proxy
credentials. The proxy file should be mounted into the worker container as a read-only secret;
do not commit it to the repository.
