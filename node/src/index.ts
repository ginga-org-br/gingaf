import path from 'path';
import fs from 'fs';
import type { Express, Handler } from 'express';

export function getAssetsPath(): string {
  const buildWebPath = path.resolve(__dirname, '..', '..', 'build', 'web');
  if (fs.existsSync(buildWebPath) && fs.existsSync(path.join(buildWebPath, 'index.html'))) return buildWebPath;

  const distPath = path.resolve(__dirname, 'gingaf-web');
  if (fs.existsSync(distPath)) return distPath;

  const playgroundParentPath = path.resolve(__dirname, '..', 'playground', 'gingaf-web');
  if (fs.existsSync(playgroundParentPath)) return playgroundParentPath;

  const distParentPath = path.resolve(__dirname, '..', 'dist', 'gingaf-web');
  if (fs.existsSync(distParentPath)) return distParentPath;

  const webPath = path.resolve(__dirname, '..', '..', 'web');
  if (fs.existsSync(webPath) && fs.existsSync(path.join(webPath, 'index.html'))) return webPath;

  const gingafPath = path.resolve(__dirname, '..', 'gingaf');
  if (fs.existsSync(gingafPath)) return gingafPath;

  const publicPath = path.resolve(__dirname, '..', 'public', 'gingaf-web');
  if (fs.existsSync(publicPath)) return publicPath;

  return publicPath;
}

export function gingafMiddleware(): Handler {
  const express = require('express');
  try {
    express.static.mime?.define?.({
      'application/wasm': ['wasm'],
      'application/xml': ['ncl'],
      'text/plain': ['lua']
    });
  } catch (_) {}
  const assetsPath = getAssetsPath();
  const staticMiddleware = express.static(assetsPath, {
    setHeaders: (res: any, filePath: string) => {
      res.setHeader('Access-Control-Allow-Origin', '*');
      if (filePath.endsWith('.wasm')) {
        res.setHeader('Content-Type', 'application/wasm');
      }
    }
  });

  return (req: any, res: any, next: any) => {
    if (req.path === '/playground' || req.path === '/playground/') {
      const playgroundIndex = path.join(assetsPath, 'playground', 'index.html');
      if (fs.existsSync(playgroundIndex)) {
        return res.sendFile(playgroundIndex);
      }
      const rootIndex = path.join(assetsPath, 'index.html');
      if (fs.existsSync(rootIndex)) {
        const query = req.url.includes('?') ? req.url.substring(req.url.indexOf('?')) : '';
        const params = new URLSearchParams(query.startsWith('?') ? query.substring(1) : query);
        params.set('playground', 'true');
        return res.redirect(`../?${params.toString()}`);
      }
    }
    return staticMiddleware(req, res, next);
  };
}

export const gingaMiddleware = gingafMiddleware;

export function startServer(port: number = 3000): Promise<Express> {
  return new Promise((resolve) => {
    const express = require('express');
    const app = express();
    const assetsPath = getAssetsPath();

    app.use(express.static(assetsPath));

    app.get('*', (req: any, res: any) => {
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

export interface EmbedOptions {
  container: string | HTMLElement;
  playerUrl?: string;
  src?: string;
  width?: string;
  height?: string;
}

export function embedGingaF(options: EmbedOptions): HTMLIFrameElement {
  const {
    container,
    playerUrl = '/gingaf-web/index.html',
    src,
    width = '100%',
    height = '100%'
  } = options;

  const targetEl =
    typeof container === 'string'
      ? document.querySelector<HTMLElement>(container)
      : container;

  if (!targetEl) {
    throw new Error(`Target container element '${container}' not found.`);
  }

  const iframe = document.createElement('iframe');
  const url = new URL(playerUrl, window.location.origin);
  if (src) {
    url.searchParams.set('ginga_app', src);
    try {
      window.sessionStorage.setItem('GINGA_APP', src);
    } catch (_) {}
    iframe.onload = () => {
      try {
        iframe.contentWindow?.sessionStorage?.setItem('GINGA_APP', src);
        if (iframe.contentWindow) {
          const gingaObj = { app: src };
          (iframe.contentWindow as any).Ginga = gingaObj;
          (iframe.contentWindow as any).GingaApp = gingaObj;
        }
      } catch (_) {}
    };
  }

  iframe.src = url.toString();
  iframe.style.width = width;
  iframe.style.height = height;
  iframe.style.border = 'none';

  targetEl.replaceChildren(iframe);
  return iframe;
}
