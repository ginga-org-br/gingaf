import { defineConfig } from 'vite';
import path from 'path';
import fs from 'fs';

export default defineConfig({
  base: '/gingaf/playground/',
  plugins: [
    {
      name: 'playground',
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
          if (req.url?.startsWith('/examples/')) {
            const filePath = path.resolve(__dirname, '..', req.url.substring(1));
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
      }
    }
  ]
});
