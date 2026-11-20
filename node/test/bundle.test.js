const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { execFileSync } = require('node:child_process');

const nodeDir = path.resolve(__dirname, '..');
const pkg = JSON.parse(fs.readFileSync(path.join(nodeDir, 'package.json'), 'utf8'));
const gingaNode = require(path.join(nodeDir, pkg.main));

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

test('packaged gingaf-web bundle exists and is resolved by getAssetsPath', async () => {
  const bundleDir = path.join(nodeDir, 'dist', 'gingaf-web');
  assert.equal(fs.existsSync(path.join(bundleDir, 'index.html')), true);
  assert.equal(fs.existsSync(path.join(bundleDir, 'main.dart.js')), true);
  assert.equal(gingaNode.getAssetsPath(), bundleDir);

  const app = await gingaNode.startServer(0);
  try {
    const indexRes = await httpRequest(`http://127.0.0.1:${app.port}/index.html`);
    assert.equal(indexRes.statusCode, 200);
    assert.equal(indexRes.headers['access-control-allow-origin'], '*');
    assert.match(indexRes.body, /flutter/i);

    const jsRes = await httpRequest(`http://127.0.0.1:${app.port}/main.dart.js`);
    assert.equal(jsRes.statusCode, 200);
    assert.ok(jsRes.body.length > 1000);
  } finally {
    await new Promise((resolve) => app.server.close(resolve));
  }
});

test('npm pack dry-run includes packaged gingaf-web assets', () => {
  const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  const raw = execFileSync(npmCmd, ['pack', '--dry-run', '--json'], {
    cwd: nodeDir,
    encoding: 'utf8'
  });
  const parsed = JSON.parse(raw);
  const filePaths = new Set(parsed[0].files.map((f) => f.path));

  assert.equal(filePaths.has('dist/index.js'), true);
  assert.equal(filePaths.has('dist/index.d.ts'), true);
  assert.equal(filePaths.has('dist/gingaf-web/index.html'), true);
  assert.equal(filePaths.has('dist/gingaf-web/main.dart.js'), true);
});
