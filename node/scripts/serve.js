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

const app = express();

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

app.use('/examples', (req, res, next) => {
  const filePath = path.resolve(examplesDir, req.path.replace(/^\//, ''));
  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    const ext = path.extname(filePath).toLowerCase();
    if (ext === '.lua') res.setHeader('Content-Type', 'text/plain');
    else if (ext === '.ncl') res.setHeader('Content-Type', 'application/xml');
    else if (ext === '.html' || ext === '.htm') res.setHeader('Content-Type', 'text/html');
    else if (ext === '.mp4') res.setHeader('Content-Type', 'video/mp4');
    else if (ext === '.webm') res.setHeader('Content-Type', 'video/webm');
    else if (ext === '.ogv') res.setHeader('Content-Type', 'video/ogg');
    else if (ext === '.mp3') res.setHeader('Content-Type', 'audio/mpeg');
    else if (ext === '.wav') res.setHeader('Content-Type', 'audio/wav');
    else if (ext === '.png') res.setHeader('Content-Type', 'image/png');
    else if (ext === '.jpg' || ext === '.jpeg') res.setHeader('Content-Type', 'image/jpeg');

    res.setHeader('Access-Control-Allow-Origin', '*');
    fs.createReadStream(filePath).pipe(res);
    return;
  }
  next();
});

express.static.mime.define({
  'application/wasm': ['wasm'],
  'application/xml': ['ncl'],
  'text/plain': ['lua']
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
    const expressProcess = cp.spawn(process.execPath, [expressAppPath], {
      stdio: 'inherit'
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
