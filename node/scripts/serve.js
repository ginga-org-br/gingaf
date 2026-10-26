const express = require('express');
const path = require('path');
const fs = require('fs');
const cp = require('child_process');

const args = process.argv.slice(2);
const withExpress = args.includes('--express') || args.includes('--with-express');
const targetPages = args.filter(arg => !arg.startsWith('--'));
if (targetPages.length === 0) {
  targetPages.push('index.html');
}
const defaultPage = targetPages[0];

const port = parseInt(process.env.PORT || '5173', 10);
const playgroundDir = path.resolve(__dirname, '..', 'playground');
const examplesDir = path.resolve(__dirname, '..', '..', 'examples');
const nodeExamplesDir = path.resolve(__dirname, '..', 'examples');

const app = express();

function serveExampleHtml(res, filePath, basePath) {
  let content = fs.readFileSync(filePath, 'utf8');
  content = content.replace(/href="\/style\.css"/g, `href="${basePath}style.css"`);
  content = content.replace(/src="\/src\/main\.ts(\?[^"]*)?"/g, (match, query) => `src="${basePath}bundle.js${query || ''}"`);
  content = content.replace(/src="\.\/main\.js(\?[^"]*)?"/g, (match, query) => `src="${basePath}bundle.js${query || ''}"`);
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.send(content);
}

app.use((req, res, next) => {
  const [rawPath] = (req.url || '').split('?');
  const cleanPath = rawPath.replace(/\/+$/, '');

  if (cleanPath === '' || cleanPath === '/' || cleanPath === '/gingaf' || cleanPath === '/gingaf/playground') {
    const search = req.url.includes('?') ? req.url.slice(req.url.indexOf('?')) : '';
    res.redirect(302, `/gingaf/playground/${defaultPage}${search}`);
    return;
  }
  next();
});

express.static.mime.define({
  'application/wasm': ['wasm'],
  'application/xml': ['ncl'],
  'text/plain': ['lua']
});

app.get('/style.css', (req, res) => {
  res.sendFile(path.join(playgroundDir, 'style.css'));
});

app.get('/bundle.js', (req, res) => {
  res.sendFile(path.join(playgroundDir, 'bundle.js'));
});

app.get('/src/main.ts', (req, res) => {
  res.setHeader('Content-Type', 'application/javascript');
  res.sendFile(path.join(playgroundDir, 'bundle.js'));
});

app.get('/gingaf/playground/catalog.json', (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.sendFile(path.join(examplesDir, 'catalog.json'));
});

app.use('/gingaf/playground/examples', (req, res, next) => {
  const file = req.path.replace(/^\/+/, '');
  const candidate = path.join(nodeExamplesDir, file);
  if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
    return serveExampleHtml(res, candidate, '../');
  }
  next();
});

app.use('/examples', (req, res, next) => {
  const file = req.path.replace(/^\/+/, '');
  const candidate = path.join(nodeExamplesDir, file);
  if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
    return serveExampleHtml(res, candidate, '/gingaf/playground/');
  }
  next();
});

app.use('/examples', express.static(examplesDir, {
  setHeaders: (res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
  }
}));

app.use('/gingaf/examples', (req, res, next) => {
  const file = req.path.replace(/^\/+/, '');
  const candidate = path.join(nodeExamplesDir, file);
  if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
    return serveExampleHtml(res, candidate, '/gingaf/playground/');
  }
  next();
});

app.use('/gingaf/examples', express.static(examplesDir, {
  setHeaders: (res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
  }
}));

app.use('/gingaf/playground', (req, res, next) => {
  const file = req.path.replace(/^\/+/, '');
  const candidate = path.join(nodeExamplesDir, file);
  if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
    return serveExampleHtml(res, candidate, './');
  }
  next();
});

app.use('/gingaf/playground', express.static(playgroundDir, {
  setHeaders: (res, filePath) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    if (filePath.endsWith('.wasm')) {
      res.setHeader('Content-Type', 'application/wasm');
    }
  }
}));

app.listen(port, () => {
  const startCmd = process.platform === 'win32' ? 'start' : process.platform === 'darwin' ? 'open' : 'xdg-open';

  for (const page of targetPages) {
    const url = `http://localhost:${port}/gingaf/playground/${page}`;
    console.log(`\n   Local:   ${url}`);

    if (process.env.NO_OPEN !== 'true') {
      cp.exec(`${startCmd} ${url}`, (err) => {
        if (err) {
          console.warn(`Could not open browser automatically: ${err.message}`);
        }
      });
    }
  }
  console.log('');

  if (withExpress) {
    const expressAppPath = path.resolve(__dirname, '..', 'example-node-express', 'index.js');
    const expressPort = process.env.EXPRESS_PORT || '3000';
    const expressProcess = cp.spawn(process.execPath, [expressAppPath], {
      cwd: path.resolve(__dirname, '..', 'example-node-express'),
      stdio: 'inherit',
      env: { ...process.env, PORT: expressPort }
    });

    const cleanup = () => {
      try {
        expressProcess.kill();
      } catch (_) {}
      process.exit();
    };

    process.on('SIGINT', cleanup);
    process.on('SIGTERM', cleanup);
    process.on('exit', cleanup);
  }
});
