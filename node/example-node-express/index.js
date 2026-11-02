const express = require('express');
const path = require('path');
let gingaNode;
try {
  gingaNode = require('../playground/index.js');
} catch (_) {
  gingaNode = require('ginga-node');
}
const { gingaMiddleware } = gingaNode;

const app = express();
const PORT = process.env.PORT || 3000;

try {
  express.static.mime.define({
    'application/wasm': ['wasm'],
    'application/xml': ['ncl'],
    'text/plain': ['lua']
  });
} catch (_) {}

app.use('/app', express.static(path.join(__dirname, 'app'), {
  setHeaders: (res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
  }
}));
app.use('/gingaf-web', gingaMiddleware());

app.get(['/', '/node-embed-player', '/node-embed-player/'], (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="icon" type="image/png" href="/gingaf-web/favicon.png?v=2" />
  <title>GingaF Express Example</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, -apple-system, sans-serif; background: #ffffff; color: #000000; height: 100vh; display: flex; flex-direction: column; }
    header { padding: 1rem 1.5rem; background: #ffffff; border-bottom: 1px solid #e2e8f0; display: flex; align-items: center; justify-content: space-between; }
    h1 { font-size: 1.25rem; font-weight: 600; color: #000000; }
    .status { font-size: 0.875rem; color: #000000; background: #ffffff; padding: 0.25rem 0.75rem; border-radius: 9999px; border: 1px solid #cbd5e1; }
    main { flex: 1; position: relative; width: 100%; height: 100%; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <header>
    <h1>nodejs opening express-hosted /app/video.ncl and /gingaf?app=/app/video.ncl</h1>
  </header>
  <main>
    <iframe src="/gingaf-web/index.html?app=/app/video.ncl&ginga_app=/app/video.ncl"></iframe>
  </main>
  <script>
    (function() {
      const appSrc = '/app/video.ncl';
      try {
        sessionStorage.setItem('GINGA_APP', appSrc);
      } catch (_) {}
      const iframe = document.querySelector('iframe');
      if (iframe) {
        iframe.addEventListener('load', function() {
          try {
            iframe.contentWindow?.sessionStorage?.setItem('GINGA_APP', appSrc);
            if (iframe.contentWindow) {
              const gingaObj = { app: appSrc };
              iframe.contentWindow.Ginga = gingaObj;
              iframe.contentWindow.GingaApp = gingaObj;
            }
          } catch (_) {}
        });
      }
    })();
  </script>
</body>
</html>`);
});

app.get(['/playground', '/playground/', '/node-embed-playground', '/node-embed-playground/'], (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="icon" type="image/png" href="/gingaf-web/favicon.png?v=2" />
  <title>GingaF Playground Express Example</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, -apple-system, sans-serif; background: #ffffff; color: #000000; height: 100vh; display: flex; flex-direction: column; }
    header { padding: 1rem 1.5rem; background: #ffffff; border-bottom: 1px solid #e2e8f0; display: flex; align-items: center; justify-content: space-between; }
    h1 { font-size: 1.25rem; font-weight: 600; color: #000000; }
    .status { font-size: 0.875rem; color: #000000; background: #ffffff; padding: 0.25rem 0.75rem; border-radius: 9999px; border: 1px solid #cbd5e1; }
    main { flex: 1; position: relative; width: 100%; height: 100%; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <header>
    <h1>nodejs opening express-hosted /app/video.ncl and /gingaf?app=/app/video.ncl&amp;playground=true</h1>
  </header>
  <main>
    <iframe src="/gingaf-web/playground/?app=/app/video.ncl&ginga_app=/app/video.ncl"></iframe>
  </main>
  <script>
    (function() {
      const appSrc = '/app/video.ncl';
      try {
        sessionStorage.setItem('GINGA_APP', appSrc);
        sessionStorage.setItem('GINGA_PLAYGROUND', 'true');
      } catch (_) {}
      const iframe = document.querySelector('iframe');
      if (iframe) {
        iframe.addEventListener('load', function() {
          try {
            iframe.contentWindow?.sessionStorage?.setItem('GINGA_APP', appSrc);
            iframe.contentWindow?.sessionStorage?.setItem('GINGA_PLAYGROUND', 'true');
            if (iframe.contentWindow) {
              const gingaObj = { app: appSrc, playground: true };
              iframe.contentWindow.Ginga = gingaObj;
              iframe.contentWindow.GingaApp = gingaObj;
            }
          } catch (_) {}
        });
      }
    })();
  </script>
</body>
</html>`);
});

app.listen(PORT, () => {
  const url = `http://localhost:${PORT}`;
  console.log(`   nodejs embed player:     ${url}/node-embed-player`);
  console.log(`   nodejs embed playground: ${url}/node-embed-playground\n`);
});
