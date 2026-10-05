import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createChecker } from './lib/checker.js';
import { createDemoSource } from './lib/demo.js';
import { createWclSource } from './lib/source.js';
import { createWclClient } from './lib/wcl.js';

const PUBLIC_DIR = fileURLToPath(new URL('./public/', import.meta.url));
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml' };

export function createApp(checker, { demo = false } = {}) {
  const routes = {
    '/api/config': async () => ({ demo }),
    '/api/report': async (q) => checker.listReport(q.get('code')),
    '/api/analyze': async (q) => checker.analyze(q.get('code'), Number(q.get('fight')), Number(q.get('source'))),
  };

  return createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const send = (status, body, type = 'application/json; charset=utf-8') => {
      res.writeHead(status, { 'Content-Type': type });
      res.end(type.startsWith('application/json') ? JSON.stringify(body) : body);
    };

    const route = routes[url.pathname];
    if (route) {
      try {
        send(200, await route(url.searchParams));
      } catch (err) {
        console.error(err);
        send(400, { error: err.message });
      }
      return;
    }

    const rel = normalize(url.pathname === '/' ? 'index.html' : url.pathname.slice(1));
    if (rel.startsWith('..')) return send(403, 'Forbidden', 'text/plain');
    try {
      send(200, await readFile(join(PUBLIC_DIR, rel)), MIME[extname(rel)] ?? 'application/octet-stream');
    } catch {
      send(404, 'Not found', 'text/plain');
    }
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const demo = process.env.WCL_DEMO === '1' || !process.env.WCL_CLIENT_ID;
  const source = demo
    ? createDemoSource()
    : createWclSource(createWclClient({ clientId: process.env.WCL_CLIENT_ID, clientSecret: process.env.WCL_CLIENT_SECRET, host: process.env.WCL_HOST }));
  const checker = createChecker(source, {
    sampleSize: Number(process.env.SAMPLE_SIZE) || 6,
    percentile: Number(process.env.PERCENTILE) || 99,
  });
  const port = Number(process.env.PORT) || 3000;
  createApp(checker, { demo }).listen(port, () => {
    console.log(`WoW Logs Checker on http://localhost:${port}${demo ? ' (demo mode: set WCL_CLIENT_ID/WCL_CLIENT_SECRET for real logs)' : ''}`);
  });
}
