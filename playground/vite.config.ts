import { defineConfig } from 'vite';
import path from 'path';
import fs from 'fs';
import { getAssetsPath } from 'gingaf-node';

export default defineConfig({
  base: '/playground/',
  plugins: [
    {
      name: 'playground',
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
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
              else if (ext === '.html') res.setHeader('Content-Type', 'text/html');
              
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
        if (fs.existsSync(src)) {
          if (fs.existsSync(dest)) fs.rmSync(dest, { recursive: true, force: true });
          fs.mkdirSync(dest, { recursive: true });
          fs.cpSync(src, dest, { recursive: true });
        }
      }
    }
  ]
});
