import path from 'path';
import fs from 'fs';
import type { Server } from 'http';
import type { Express, Handler } from 'express';

export interface GingaMiddlewareOptions {
  assetsPath?: string;
}

export interface GingaServerApp extends Express {
  server: Server;
  port: number;
}

export function getAssetsPath(customPath?: string): string {
  if (customPath && fs.existsSync(customPath)) {
    return path.resolve(customPath);
  }

  const distPath = path.resolve(__dirname, 'gingaf-web');
  if (fs.existsSync(distPath) && fs.existsSync(path.join(distPath, 'index.html'))) {
    return distPath;
  }

  const buildWebPath = path.resolve(__dirname, '..', '..', 'build', 'web');
  if (fs.existsSync(buildWebPath) && fs.existsSync(path.join(buildWebPath, 'index.html'))) {
    return buildWebPath;
  }

  const distParentPath = path.resolve(__dirname, '..', 'dist', 'gingaf-web');
  if (fs.existsSync(distParentPath) && fs.existsSync(path.join(distParentPath, 'index.html'))) {
    return distParentPath;
  }

  const webPath = path.resolve(__dirname, '..', '..', 'web');
  if (fs.existsSync(webPath) && fs.existsSync(path.join(webPath, 'index.html'))) {
    return webPath;
  }

  const gingafPath = path.resolve(__dirname, '..', 'gingaf');
  if (fs.existsSync(gingafPath)) return gingafPath;

  const publicPath = path.resolve(__dirname, '..', 'public', 'gingaf-web');
  if (fs.existsSync(publicPath)) return publicPath;

  const repoBuildWebPath = path.resolve(__dirname, '..', '..', '..', '..', 'build', 'web');
  if (fs.existsSync(repoBuildWebPath) && fs.existsSync(path.join(repoBuildWebPath, 'index.html'))) {
    return repoBuildWebPath;
  }

  const repoDistWebPath = path.resolve(__dirname, '..', '..', '..', 'dist', 'gingaf-web');
  if (fs.existsSync(repoDistWebPath) && fs.existsSync(path.join(repoDistWebPath, 'index.html'))) {
    return repoDistWebPath;
  }

  return distPath;
}

export function gingafMiddleware(options: GingaMiddlewareOptions = {}): Handler {
  const express = require('express');
  try {
    express.static.mime?.define?.(
      {
        'application/wasm': ['wasm'],
        'application/xml': ['ncl'],
        'application/x-ncl360': ['ncl360'],
        'text/plain': ['lua']
      },
      true
    );
  } catch (_) {}

  const assetsPath = getAssetsPath(options.assetsPath);
  const staticMiddleware = express.static(assetsPath, {
    setHeaders: (res: any, filePath: string) => {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Private-Network', 'true');
      if (filePath.endsWith('.wasm')) {
        res.setHeader('Content-Type', 'application/wasm');
      } else if (filePath.endsWith('.ncl360')) {
        res.setHeader('Content-Type', 'application/x-ncl360');
      } else if (filePath.endsWith('.ncl')) {
        res.setHeader('Content-Type', 'application/xml');
      } else if (filePath.endsWith('.lua')) {
        res.setHeader('Content-Type', 'text/plain; charset=utf-8');
      }
    }
  });

  return (req: any, res: any, next: any) => {
    if (req.path === '/playground' || req.path === '/playground/') {
      const playgroundIndex = path.join(assetsPath, 'playground', 'index.html');
      if (fs.existsSync(playgroundIndex)) {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Private-Network', 'true');
        return res.sendFile(playgroundIndex);
      }
      const rootIndex = path.join(assetsPath, 'index.html');
      if (fs.existsSync(rootIndex)) {
        const query = req.url.includes('?') ? req.url.substring(req.url.indexOf('?')) : '';
        const params = new URLSearchParams(query.startsWith('?') ? query.substring(1) : query);
        params.set('playground', 'true');
        const base = req.baseUrl ? `${req.baseUrl.replace(/\/+$/, '')}/` : '/';
        return res.redirect(`${base}?${params.toString()}`);
      }
    }
    return staticMiddleware(req, res, next);
  };
}

export const gingaMiddleware = gingafMiddleware;

export function createApp(options: GingaMiddlewareOptions = {}): Express {
  const express = require('express');
  const app: Express = express();
  const assetsPath = getAssetsPath(options.assetsPath);

  app.use(gingafMiddleware({ assetsPath }));

  app.get('*', (req: any, res: any) => {
    const indexPath = path.join(assetsPath, 'index.html');
    if (fs.existsSync(indexPath)) {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Private-Network', 'true');
      res.sendFile(indexPath);
    } else {
      res.status(404).send('Index HTML not found');
    }
  });

  return app;
}

export function startServer(
  port: number = 3000,
  options: GingaMiddlewareOptions = {}
): Promise<GingaServerApp> {
  return new Promise((resolve, reject) => {
    const app = createApp(options) as GingaServerApp;
    const server = app.listen(port, () => {
      const address = server.address();
      app.server = server;
      app.port = typeof address === 'object' && address !== null ? address.port : port;
      resolve(app);
    });
    server.on('error', reject);
  });
}

export interface EmbedOptions {
  container: string | HTMLElement;
  playerUrl?: string;
  src?: string;
  playground?: boolean;
  width?: string;
  height?: string;
}

export function embedGingaF(options: EmbedOptions): HTMLIFrameElement {
  const {
    container,
    playerUrl = '/gingaf-web/index.html',
    src,
    playground,
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
  }
  if (playground !== undefined) {
    url.searchParams.set('playground', String(playground));
    try {
      window.sessionStorage.setItem('GINGA_PLAYGROUND', String(playground));
    } catch (_) {}
  }
  if (src || playground !== undefined) {
    iframe.onload = () => {
      try {
        if (src) {
          iframe.contentWindow?.sessionStorage?.setItem('GINGA_APP', src);
        }
        if (playground !== undefined) {
          iframe.contentWindow?.sessionStorage?.setItem('GINGA_PLAYGROUND', String(playground));
        }
        if (iframe.contentWindow) {
          const gingaObj: Record<string, unknown> = {};
          if (src) gingaObj.app = src;
          if (playground !== undefined) gingaObj.playground = playground;
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
