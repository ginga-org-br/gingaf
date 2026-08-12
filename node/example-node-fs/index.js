const express = require('express');
const { gingaMiddleware } = require('../dist/index.js');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.static(__dirname));
app.use('/gingaf-web', gingaMiddleware());

app.get('/', (req, res) => {
  const fullAppUrl = `${req.protocol}://${req.get('host')}/video.ncl`;
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>GingaF Express Example</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #f8fafc; height: 100vh; display: flex; flex-direction: column; }
    header { padding: 1rem 1.5rem; background: #1e293b; border-bottom: 1px solid #334155; display: flex; align-items: center; justify-content: space-between; }
    h1 { font-size: 1.25rem; font-weight: 600; color: #38bdf8; }
    .status { font-size: 0.875rem; color: #94a3b8; background: #0f172a; padding: 0.25rem 0.75rem; border-radius: 9999px; border: 1px solid #334155; }
    main { flex: 1; position: relative; width: 100%; height: 100%; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <header>
    <h1>gingaf example from nodejs (Local File)</h1>
    <div class="status">Loading /video.ncl from local filesystem</div>
  </header>
  <main>
    <iframe src="/gingaf-web/index.html?app=${encodeURIComponent(fullAppUrl)}"></iframe>
  </main>
</body>
</html>`);
});

const cp = require('child_process');

app.listen(PORT, () => {
  const url = `http://localhost:${PORT}`;
  console.log(`\n  ➜ Local:   ${url}\n`);
  const startCmd = process.platform === 'win32' ? 'start' : process.platform === 'darwin' ? 'open' : 'xdg-open';
  cp.exec(`${startCmd} ${url}`, () => {});
});
