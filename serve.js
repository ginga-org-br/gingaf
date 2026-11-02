const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = parseInt(process.env.PORT || '5173', 10);
const ROOT = __dirname;
const BUILD_WEB = path.join(ROOT, 'build', 'web');
const EXAMPLES = path.join(ROOT, 'examples');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.ncl': 'application/xml; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.lua': 'text/plain; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

function resolveFilePath(reqPath) {
  const parsed = url.parse(reqPath);
  const pathname = decodeURIComponent(parsed.pathname || '/');

  if (pathname === '/favicon.ico' || pathname === '/gingaf/favicon.ico' ||
      pathname === '/gingaf/playground/favicon.ico' || pathname === '/playground/favicon.ico') {
    return path.join(BUILD_WEB, 'favicon.png');
  }

  if (pathname === '/gingaf/playground-embedded' || pathname === '/gingaf/playground-embedded/' ||
      pathname === '/playground-embedded' || pathname === '/playground-embedded/') {
    return path.join(EXAMPLES, 'playground-embedded.html');
  }

  if (pathname === '/gingaf/catalog.json' || pathname === '/catalog.json' ||
      pathname === '/gingaf/examples/catalog.json' || pathname === '/examples/catalog.json' ||
      pathname === '/gingaf/playground/catalog.json' || pathname === '/gingaf/playground/examples/catalog.json' ||
      pathname === '/playground/catalog.json' || pathname === '/playground/examples/catalog.json') {
    return path.join(EXAMPLES, 'catalog.json');
  }

  if (pathname.startsWith('/gingaf/examples/')) {
    const rel = pathname.substring('/gingaf/examples/'.length);
    const candidate = path.join(EXAMPLES, rel);
    if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
      return candidate;
    }
  }
  if (pathname.startsWith('/examples/')) {
    const rel = pathname.substring('/examples/'.length);
    const candidate = path.join(EXAMPLES, rel);
    if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
      return candidate;
    }
  }

  if (pathname.startsWith('/gingaf/playground/examples/')) {
    const rel = pathname.substring('/gingaf/playground/examples/'.length);
    const candidate = path.join(EXAMPLES, rel);
    if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
      return candidate;
    }
  }
  if (pathname.startsWith('/playground/examples/')) {
    const rel = pathname.substring('/playground/examples/'.length);
    const candidate = path.join(EXAMPLES, rel);
    if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
      return candidate;
    }
  }

  if (pathname.startsWith('/gingaf/playground/')) {
    const rel = pathname.substring('/gingaf/playground/'.length);
    if (!rel || rel === 'index.html') {
      return path.join(BUILD_WEB, 'index.html');
    }
    const buildCandidate = path.join(BUILD_WEB, rel);
    if (fs.existsSync(buildCandidate) && fs.statSync(buildCandidate).isFile()) {
      return buildCandidate;
    }
    const exCandidate = path.join(EXAMPLES, rel);
    if (fs.existsSync(exCandidate) && fs.statSync(exCandidate).isFile()) {
      return exCandidate;
    }
  }

  if (pathname.startsWith('/playground/')) {
    const rel = pathname.substring('/playground/'.length);
    if (!rel || rel === 'index.html') {
      return path.join(BUILD_WEB, 'index.html');
    }
    const buildCandidate = path.join(BUILD_WEB, rel);
    if (fs.existsSync(buildCandidate) && fs.statSync(buildCandidate).isFile()) {
      return buildCandidate;
    }
    const exCandidate = path.join(EXAMPLES, rel);
    if (fs.existsSync(exCandidate) && fs.statSync(exCandidate).isFile()) {
      return exCandidate;
    }
  }

  if (pathname === '/' || pathname === '/gingaf' || pathname === '/gingaf/' || pathname === '/gingaf/index.html') {
    return path.join(BUILD_WEB, 'index.html');
  }

  if (pathname.startsWith('/gingaf/')) {
    const rel = pathname.substring('/gingaf/'.length);
    const buildCandidate = path.join(BUILD_WEB, rel);
    if (fs.existsSync(buildCandidate) && fs.statSync(buildCandidate).isFile()) {
      return buildCandidate;
    }
    const exCandidate = path.join(EXAMPLES, rel);
    if (fs.existsSync(exCandidate) && fs.statSync(exCandidate).isFile()) {
      return exCandidate;
    }
  }

  const directPath = pathname.replace(/^\//, '');
  const buildCandidate = path.join(BUILD_WEB, directPath);
  if (fs.existsSync(buildCandidate) && fs.statSync(buildCandidate).isFile()) {
    return buildCandidate;
  }
  const exCandidate = path.join(EXAMPLES, directPath);
  if (fs.existsSync(exCandidate) && fs.statSync(exCandidate).isFile()) {
    return exCandidate;
  }

  return null;
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const parsed = url.parse(req.url, true);
  const pathname = decodeURIComponent(parsed.pathname || '/');

  const hasPlaygroundParam = parsed.query && (
    parsed.query.playground !== undefined ||
    parsed.query.ginga_playground !== undefined
  );

  if (hasPlaygroundParam && !pathname.includes('/playground')) {
    const remainingQuery = { ...parsed.query };
    delete remainingQuery.playground;
    delete remainingQuery.ginga_playground;
    const searchParams = new URLSearchParams(remainingQuery).toString();
    const targetUrl = '/gingaf/playground/' + (searchParams ? '?' + searchParams : '');
    res.writeHead(302, { 'Location': targetUrl });
    res.end();
    return;
  }

  if (pathname === '/gingaf/playground' || pathname === '/playground') {
    const query = parsed.search || '';
    res.writeHead(302, { 'Location': pathname + '/' + query });
    res.end();
    return;
  }

  const filePath = resolveFilePath(req.url);
  if (!filePath || !fs.existsSync(filePath)) {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
    return;
  }

  try {
    const stat = fs.statSync(filePath);
    if (stat.isDirectory()) {
      const indexCandidate = path.join(filePath, 'index.html');
      if (fs.existsSync(indexCandidate)) {
        serveFile(indexCandidate, res);
      } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
      }
      return;
    }
    serveFile(filePath, res);
  } catch (_) {
    res.writeHead(500, { 'Content-Type': 'text/plain' });
    res.end('Internal Server Error');
  }
});

function serveFile(filePath, res) {
  const ext = path.extname(filePath).toLowerCase();
  const mime = MIME_TYPES[ext] || 'application/octet-stream';
  res.writeHead(200, {
    'Content-Type': mime,
    'Cache-Control': 'no-cache, no-store, must-revalidate',
  });
  fs.createReadStream(filePath).pipe(res);
}

if (require.main === module) {
  server.listen(PORT);
}

module.exports = { server, resolveFilePath };
