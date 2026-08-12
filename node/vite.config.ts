import { defineConfig } from 'vite';
import path from 'path';
import fs from 'fs';
import { getAssetsPath } from './src/index';

export default defineConfig({
  base: process.env.VITE_BASE || '/gingaf/dst/',
  build: {
    emptyOutDir: false,
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, 'index.html'),
        playground: path.resolve(__dirname, 'playground.html'),
        player: path.resolve(__dirname, 'player.html'),
        'playground-app-example': path.resolve(__dirname, 'playground-app-example.html'),
        'player-app-example': path.resolve(__dirname, 'player-app-example.html')
      }
    }
  },
  plugins: [
    {
      name: 'playground',
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
          if (req.url && (req.url === '/gingaf/playground' || req.url === '/gingaf/playground/' || req.url.startsWith('/gingaf/playground?'))) {
            const search = req.url.includes('?') ? req.url.slice(req.url.indexOf('?')) : '';
            res.writeHead(302, { Location: `/gingaf/dst/playground.html${search}` });
            res.end();
            return;
          }
          if (req.url && (req.url.startsWith('/gingaf-web') || req.url.includes('/gingaf-web'))) {
            let subPath = req.url.replace(/^.*\/gingaf-web\/?/, '').split('?')[0];
            if (!subPath || subPath === '') {
              subPath = 'index.html';
            }
            const assetsPath = getAssetsPath();
            const filePath = path.join(assetsPath, subPath);
            if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
              const ext = path.extname(filePath).toLowerCase();
              if (ext === '.js') res.setHeader('Content-Type', 'application/javascript');
              else if (ext === '.html') res.setHeader('Content-Type', 'text/html');
              else if (ext === '.wasm') res.setHeader('Content-Type', 'application/wasm');
              else if (ext === '.png') res.setHeader('Content-Type', 'image/png');
              else if (ext === '.jpg' || ext === '.jpeg') res.setHeader('Content-Type', 'image/jpeg');
              else if (ext === '.json') res.setHeader('Content-Type', 'application/json');

              res.setHeader('Access-Control-Allow-Origin', '*');
              fs.createReadStream(filePath).pipe(res);
              return;
            }
          }
          if (req.url?.startsWith('/examples/')) {
            const filePath = path.resolve(import.meta.dirname, '..', req.url.substring(1));
            if (fs.existsSync(filePath)) {
              const ext = path.extname(filePath);
              if (ext === '.lua') res.setHeader('Content-Type', 'text/plain');
              else if (ext === '.png') res.setHeader('Content-Type', 'image/png');
              else if (ext === '.jpg') res.setHeader('Content-Type', 'image/jpeg');
              else if (ext === '.ncl') res.setHeader('Content-Type', 'application/xml');
              else if (ext === '.html' || ext === '.htm') res.setHeader('Content-Type', 'text/html');
              else if (ext === '.mp4') res.setHeader('Content-Type', 'video/mp4');
              else if (ext === '.webm') res.setHeader('Content-Type', 'video/webm');
              else if (ext === '.ogv') res.setHeader('Content-Type', 'video/ogg');
              else if (ext === '.mp3') res.setHeader('Content-Type', 'audio/mpeg');
              else if (ext === '.wav') res.setHeader('Content-Type', 'audio/wav');
              
              res.setHeader('Access-Control-Allow-Origin', '*');
              fs.createReadStream(filePath).pipe(res);
              return;
            }
          }
          next();
        });
      },
      closeBundle() {
        const dest = path.resolve(import.meta.dirname, 'dist', 'gingaf-web');
        const src = getAssetsPath();
        if (fs.existsSync(src) && path.resolve(src) !== path.resolve(dest)) {
          if (fs.existsSync(dest)) fs.rmSync(dest, { recursive: true, force: true });
          fs.mkdirSync(dest, { recursive: true });
          fs.cpSync(src, dest, { recursive: true });
        }
      }
    }
  ]
});
