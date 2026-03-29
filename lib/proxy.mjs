/**
 * wp-dev-sync dev proxy — reverse proxy with Vite HMR injection.
 * Zero npm dependencies — uses only Node.js built-in modules.
 *
 * Environment variables (set by commands/dev.sh):
 *   SITE_URL     — Remote WordPress URL (e.g. https://mysite.com)
 *   DEV_PORT     — Local proxy port (default: 9000)
 *   VITE_PORT    — Vite dev server port (default: 5173)
 *   VITE_ENTRY   — Vite entry point (default: resources/scripts/frontend/main.ts)
 *   LOCAL_PATH   — Local theme directory (for public asset path detection)
 *
 * @author Renan Diaz <https://reandimo.dev>
 */

import http from 'node:http';
import https from 'node:https';
import { URL } from 'node:url';
import zlib from 'node:zlib';

// ── Config ──────────────────────────────────────────────────

const SITE_URL    = process.env.SITE_URL;
const DEV_PORT    = parseInt(process.env.DEV_PORT || '9000', 10);
const VITE_PORT   = parseInt(process.env.VITE_PORT || '5173', 10);
const VITE_ENTRY  = process.env.VITE_ENTRY || 'resources/scripts/frontend/main.ts';

if (!SITE_URL) {
  console.error('[proxy] SITE_URL is not set. Add it to your .env');
  process.exit(1);
}

const siteUrl   = new URL(SITE_URL);
const isHttps   = siteUrl.protocol === 'https:';
const requester = isHttps ? https : http;
const siteHost  = siteUrl.host;
const siteOrigin = siteUrl.origin;  // https://mysite.com (no trailing slash)

const VITE_BASE = `http://localhost:${VITE_PORT}`;

// ── Vite injection snippets ─────────────────────────────────

const VITE_CLIENT_TAG = `<script type="module" src="${VITE_BASE}/@vite/client"></script>`;
const VITE_ENTRY_TAG  = `<script type="module" crossorigin src="${VITE_BASE}/${VITE_ENTRY}"></script>`;

// ── Helpers ─────────────────────────────────────────────────

function decompressResponse(proxyRes, callback) {
  const encoding = (proxyRes.headers['content-encoding'] || '').toLowerCase();
  let stream = proxyRes;

  if (encoding === 'gzip') {
    stream = proxyRes.pipe(zlib.createGunzip());
  } else if (encoding === 'deflate') {
    stream = proxyRes.pipe(zlib.createInflate());
  } else if (encoding === 'br') {
    stream = proxyRes.pipe(zlib.createBrotliDecompress());
  }

  const chunks = [];
  stream.on('data', (chunk) => chunks.push(chunk));
  stream.on('end', () => callback(null, Buffer.concat(chunks).toString('utf-8')));
  stream.on('error', (err) => callback(err));
}

function rewriteHtml(html) {
  // 1. Remove production theme CSS (public/css/) to avoid duplicates with Vite HMR
  html = html.replace(/<link[^>]*href=["'][^"']*\/public\/css\/[^"']*["'][^>]*\/?>/gi, '<!-- [wp-dev-sync] removed production CSS -->');

  // 2. Remove production theme JS (public/js/) to avoid duplicates with Vite entry
  html = html.replace(/<script[^>]*src=["'][^"']*\/public\/js\/[^"']*["'][^>]*><\/script>/gi, '<!-- [wp-dev-sync] removed production JS -->');

  // 3. Inject Vite client + entry before </head>
  html = html.replace(
    '</head>',
    `  ${VITE_CLIENT_TAG}\n  ${VITE_ENTRY_TAG}\n</head>`
  );

  // 4. Rewrite absolute URLs: remote site → local proxy
  //    Only rewrite in href/src/action attributes and Location-like contexts.
  //    Avoid rewriting inside content/text to prevent data corruption.
  const localOrigin = `http://localhost:${DEV_PORT}`;
  html = html.replaceAll(siteOrigin, localOrigin);

  // Also handle protocol-relative URLs (//mysite.com)
  const protocolRelative = `//${siteUrl.host}`;
  html = html.replaceAll(protocolRelative, `//localhost:${DEV_PORT}`);

  return html;
}

function rewriteHeaders(headers, statusCode) {
  const result = { ...headers };
  const localOrigin = `http://localhost:${DEV_PORT}`;

  // Rewrite redirects
  if (result.location) {
    result.location = result.location.replaceAll(siteOrigin, localOrigin);
  }

  // Rewrite cookies: remove domain restriction and Secure flag
  if (result['set-cookie']) {
    result['set-cookie'] = result['set-cookie'].map((cookie) =>
      cookie
        .replace(/;\s*domain=[^;]*/gi, '')
        .replace(/;\s*secure/gi, '')
        .replace(/;\s*SameSite=None/gi, '; SameSite=Lax')
    );
  }

  // Remove CSP headers that would block Vite client injection
  delete result['content-security-policy'];
  delete result['content-security-policy-report-only'];

  // Remove content-length and encoding since we may modify the body
  delete result['content-length'];
  delete result['content-encoding'];

  return result;
}

// ── Proxy server ────────────────────────────────────────────

const server = http.createServer((req, res) => {
  const options = {
    hostname: siteUrl.hostname,
    port: siteUrl.port || (isHttps ? 443 : 80),
    path: req.url,
    method: req.method,
    headers: {
      ...req.headers,
      host: siteHost,
      // Override referer/origin to match remote site
      ...(req.headers.referer && {
        referer: req.headers.referer.replace(`http://localhost:${DEV_PORT}`, siteOrigin),
      }),
      ...(req.headers.origin && {
        origin: siteOrigin,
      }),
    },
    // Accept self-signed certs in dev
    rejectUnauthorized: false,
  };

  // Remove proxy-specific headers
  delete options.headers['accept-encoding'];

  const proxyReq = requester.request(options, (proxyRes) => {
    const contentType = proxyRes.headers['content-type'] || '';
    const isHtml = contentType.includes('text/html');

    if (isHtml && proxyRes.statusCode < 400) {
      // Collect and modify HTML response
      decompressResponse(proxyRes, (err, body) => {
        if (err) {
          res.writeHead(502);
          res.end(`[wp-dev-sync] Decompression error: ${err.message}`);
          return;
        }

        const modifiedHtml = rewriteHtml(body);
        const headers = rewriteHeaders(proxyRes.headers, proxyRes.statusCode);

        res.writeHead(proxyRes.statusCode, headers);
        res.end(modifiedHtml);
      });
    } else {
      // Pass through non-HTML (images, fonts, API, etc.)
      const headers = rewriteHeaders(proxyRes.headers, proxyRes.statusCode);

      // Keep original encoding for non-HTML
      if (proxyRes.headers['content-encoding']) {
        headers['content-encoding'] = proxyRes.headers['content-encoding'];
      }
      if (proxyRes.headers['content-length']) {
        headers['content-length'] = proxyRes.headers['content-length'];
      }

      res.writeHead(proxyRes.statusCode, headers);
      proxyRes.pipe(res);
    }
  });

  proxyReq.on('error', (err) => {
    console.error(`[proxy] Error: ${err.message} — ${req.method} ${req.url}`);
    if (!res.headersSent) {
      res.writeHead(502, { 'Content-Type': 'text/plain' });
      res.end(`[wp-dev-sync] Proxy error: ${err.message}`);
    }
  });

  req.pipe(proxyReq);
});

// ── Start ───────────────────────────────────────────────────

server.listen(DEV_PORT, '127.0.0.1', () => {
  const msg = JSON.stringify({
    type: 'ready',
    port: DEV_PORT,
    proxy: `http://127.0.0.1:${DEV_PORT}`,
    target: siteOrigin,
  });
  // Signal ready to parent bash process via stdout marker
  console.log(`__PROXY_READY__${msg}`);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`[proxy] Port ${DEV_PORT} is already in use. Try a different DEV_PORT.`);
  } else {
    console.error(`[proxy] Server error: ${err.message}`);
  }
  process.exit(1);
});
