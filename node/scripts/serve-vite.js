const { createServer } = require('vite');
const cp = require('child_process');

const targetPage = process.argv[2] || 'playground.html';

(async () => {
  try {
    const server = await createServer({
      configFile: './vite.config.ts',
      server: { port: 5173 }
    });
    await server.listen();

    const port = server.config.server.port || 5173;
    let base = server.config.base || '/gingaf/dst/';
    if (!base.startsWith('/')) base = '/' + base;
    if (!base.endsWith('/')) base = base + '/';

    const url = `http://localhost:${port}${base}${targetPage}`;
    console.log(`\n   Local:   ${url}\n`);

    const startCmd = process.platform === 'win32' ? 'start' : process.platform === 'darwin' ? 'open' : 'xdg-open';
    cp.exec(`${startCmd} ${url}`, (err) => {
      if (err) {
        console.warn(`Could not open browser automatically: ${err.message}`);
      }
    });
  } catch (e) {
    console.error('Failed to start Vite server:', e);
    process.exit(1);
  }
})();
