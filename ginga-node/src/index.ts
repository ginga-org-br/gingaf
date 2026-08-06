import path from 'path';
import fs from 'fs';
import express, { Express, Handler } from 'express';

export function getAssetsPath(): string {
  const assetsPath = path.resolve(__dirname, '..', 'assets');
  return assetsPath;
}

export function gingafMiddleware(): Handler {
  const assetsPath = getAssetsPath();
  return express.static(assetsPath);
}

export function startServer(port: number = 3000): Promise<Express> {
  return new Promise((resolve) => {
    const app = express();
    const assetsPath = getAssetsPath();

    app.use(express.static(assetsPath));

    app.get('*', (req, res) => {
      const indexPath = path.join(assetsPath, 'index.html');
      if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
      } else {
        res.status(404).send('Index HTML not found');
      }
    });

    app.listen(port, () => {
      resolve(app);
    });
  });
}
