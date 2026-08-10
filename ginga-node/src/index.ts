import path from 'path';
import fs from 'fs';
import type { Express, Handler } from 'express';

export function getAssetsPath(): string {
  const assetsPath = path.resolve(__dirname, '..', 'assets');
  return assetsPath;
}

export function gingafMiddleware(): Handler {
  const express = require('express');
  const assetsPath = getAssetsPath();
  return express.static(assetsPath);
}

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
    url.searchParams.set('app', src);
  }

  iframe.src = url.toString();
  iframe.style.width = width;
  iframe.style.height = height;
  iframe.style.border = 'none';

  targetEl.replaceChildren(iframe);
  return iframe;
}
