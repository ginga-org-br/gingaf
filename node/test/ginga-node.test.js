const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const { execFileSync } = require('node:child_process');
const express = require('express');

const nodeDir = path.resolve(__dirname, '..');
const pkgPath = path.join(nodeDir, 'package.json');
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
const builtEntry = path.join(nodeDir, pkg.main);
const builtTypes = path.join(nodeDir, pkg.types);
const gingaNode = require(builtEntry);

function httpRequest(url) {
  return new Promise((resolve, reject) => {
    const req = http.get(url, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: Buffer.concat(chunks).toString('utf8')
        });
      });
    });
    req.on('error', reject);
  });
}

function createFixtureAssets() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ginga-node-test-'));
  fs.writeFileSync(path.join(dir, 'index.html'), '<!doctype html><html><body>GingaF Test</body></html>');
  fs.writeFileSync(path.join(dir, 'runtime.wasm'), Buffer.from([0x00, 0x61, 0x73, 0x6d]));
  fs.writeFileSync(path.join(dir, 'scene.ncl'), '<ncl id="demo"/>');
  fs.writeFileSync(path.join(dir, 'vr.ncl360'), '<ncl360 id="vr"/>');
  fs.writeFileSync(path.join(dir, 'logic.lua'), 'event.post("in", { class = "ncl" })');
  return dir;
}

test('compiled package entry and TypeScript declarations exist with expected exports', () => {
  assert.equal(fs.existsSync(builtEntry), true);
  assert.equal(fs.existsSync(builtTypes), true);

  assert.equal(typeof gingaNode.getAssetsPath, 'function');
  assert.equal(typeof gingaNode.gingafMiddleware, 'function');
  assert.equal(gingaNode.gingaMiddleware, gingaNode.gingafMiddleware);
  assert.equal(typeof gingaNode.createApp, 'function');
  assert.equal(typeof gingaNode.startServer, 'function');
  assert.equal(typeof gingaNode.embedGingaF, 'function');
});

test('getAssetsPath resolves custom override and fallback paths', () => {
  const fixtureDir = createFixtureAssets();
  try {
    assert.equal(gingaNode.getAssetsPath(fixtureDir), fixtureDir);
    const defaultPath = gingaNode.getAssetsPath();
    assert.equal(typeof defaultPath, 'string');
    assert.equal(path.isAbsolute(defaultPath), true);
  } finally {
    fs.rmSync(fixtureDir, { recursive: true, force: true });
  }
});

test('gingafMiddleware serves MIME types, CORS headers, and playground redirect', async () => {
  const fixtureDir = createFixtureAssets();
  const app = express();
  app.use('/gingaf-web', gingaNode.gingafMiddleware({ assetsPath: fixtureDir }));

  const server = await new Promise((resolve) => {
    const s = app.listen(0, () => resolve(s));
  });
  const port = server.address().port;
  const base = `http://127.0.0.1:${port}/gingaf-web`;

  try {
    const indexRes = await httpRequest(`${base}/index.html`);
    assert.equal(indexRes.statusCode, 200);
    assert.equal(indexRes.headers['access-control-allow-origin'], '*');
    assert.equal(indexRes.headers['access-control-allow-private-network'], 'true');
    assert.match(indexRes.body, /GingaF Test/);

    const wasmRes = await httpRequest(`${base}/runtime.wasm`);
    assert.equal(wasmRes.statusCode, 200);
    assert.match(wasmRes.headers['content-type'], /application\/wasm/);

    const nclRes = await httpRequest(`${base}/scene.ncl`);
    assert.equal(nclRes.statusCode, 200);
    assert.match(nclRes.headers['content-type'], /application\/xml/);

    const ncl360Res = await httpRequest(`${base}/vr.ncl360`);
    assert.equal(ncl360Res.statusCode, 200);
    assert.match(ncl360Res.headers['content-type'], /application\/x-ncl360/);

    const luaRes = await httpRequest(`${base}/logic.lua`);
    assert.equal(luaRes.statusCode, 200);
    assert.match(luaRes.headers['content-type'], /text\/plain/);

    const pgRes = await httpRequest(`${base}/playground/?app=/app/video.ncl`);
    assert.equal(pgRes.statusCode, 302);
    assert.equal(
      pgRes.headers.location,
      '/gingaf-web/?app=%2Fapp%2Fvideo.ncl&playground=true'
    );

    const pgNoSlashRes = await httpRequest(`${base}/playground?app=/app/video.ncl`);
    assert.equal(pgNoSlashRes.statusCode, 302);
    assert.equal(
      pgNoSlashRes.headers.location,
      '/gingaf-web/?app=%2Fapp%2Fvideo.ncl&playground=true'
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
    fs.rmSync(fixtureDir, { recursive: true, force: true });
  }
});

test('startServer binds ephemeral port, serves root and SPA fallback, and closes cleanly', async () => {
  const fixtureDir = createFixtureAssets();
  const app = await gingaNode.startServer(0, { assetsPath: fixtureDir });

  try {
    assert.equal(typeof app.port, 'number');
    assert.ok(app.port > 0);
    assert.ok(app.server);

    const rootRes = await httpRequest(`http://127.0.0.1:${app.port}/`);
    assert.equal(rootRes.statusCode, 200);
    assert.match(rootRes.body, /GingaF Test/);

    const fallbackRes = await httpRequest(`http://127.0.0.1:${app.port}/unknown/route`);
    assert.equal(fallbackRes.statusCode, 200);
    assert.match(fallbackRes.body, /GingaF Test/);
  } finally {
    await new Promise((resolve) => app.server.close(resolve));
    fs.rmSync(fixtureDir, { recursive: true, force: true });
  }
});

test('embedGingaF builds iframe URL, sets storage/window hooks, and throws on missing container', () => {
  const parentStore = new Map();
  const iframeStore = new Map();
  let replacedChild = null;

  const containerEl = {
    replaceChildren(node) {
      replacedChild = node;
    }
  };

  const iframeEl = {
    src: '',
    style: {},
    onload: null,
    contentWindow: {
      sessionStorage: {
        setItem(k, v) {
          iframeStore.set(k, v);
        }
      }
    }
  };

  const prevWindow = global.window;
  const prevDocument = global.document;
  global.window = {
    location: { origin: 'http://localhost:3000' },
    sessionStorage: {
      setItem(k, v) {
        parentStore.set(k, v);
      }
    }
  };
  global.document = {
    querySelector(selector) {
      return selector === '#player' ? containerEl : null;
    },
    createElement(tag) {
      assert.equal(tag, 'iframe');
      return iframeEl;
    }
  };

  try {
    const result = gingaNode.embedGingaF({
      container: '#player',
      playerUrl: '/gingaf-web/index.html',
      src: '/app/video.ncl',
      playground: true,
      width: '800px',
      height: '450px'
    });

    assert.equal(result, iframeEl);
    assert.equal(replacedChild, iframeEl);
    assert.equal(
      iframeEl.src,
      'http://localhost:3000/gingaf-web/index.html?ginga_app=%2Fapp%2Fvideo.ncl&playground=true'
    );
    assert.equal(iframeEl.style.width, '800px');
    assert.equal(iframeEl.style.height, '450px');
    assert.equal(parentStore.get('GINGA_APP'), '/app/video.ncl');
    assert.equal(parentStore.get('GINGA_PLAYGROUND'), 'true');

    assert.equal(typeof iframeEl.onload, 'function');
    iframeEl.onload();
    assert.equal(iframeStore.get('GINGA_APP'), '/app/video.ncl');
    assert.equal(iframeStore.get('GINGA_PLAYGROUND'), 'true');
    assert.deepEqual(iframeEl.contentWindow.Ginga, {
      app: '/app/video.ncl',
      playground: true
    });

    assert.throws(
      () => gingaNode.embedGingaF({ container: '#missing' }),
      /not found/
    );
  } finally {
    global.window = prevWindow;
    global.document = prevDocument;
  }
});

test('npm pack dry-run includes compiled dist files and excludes dev sources', () => {
  const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  const raw = execFileSync(npmCmd, ['pack', '--dry-run', '--json'], {
    cwd: nodeDir,
    encoding: 'utf8'
  });
  const parsed = JSON.parse(raw);
  assert.equal(Array.isArray(parsed), true);
  assert.equal(parsed.length, 1);

  const filePaths = new Set(parsed[0].files.map((f) => f.path));
  assert.equal(filePaths.has('package.json'), true);
  assert.equal(filePaths.has('README.md'), true);
  assert.equal(filePaths.has('LICENSE'), true);
  assert.equal(filePaths.has('dist/index.js'), true);
  assert.equal(filePaths.has('dist/index.d.ts'), true);

  for (const p of filePaths) {
    assert.equal(p.startsWith('src/'), false);
    assert.equal(p.startsWith('test/'), false);
    assert.equal(p.startsWith('example-node-express/'), false);
  }
});

