# ginga-node

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../LICENSE)

Node.js middleware and static distribution package for [gingaf](https://github.com/ginga-org-br/gingaf).

The `node/` directory contains the **Ginga Web Playground & Player** application as well as the **`ginga-node`** npm package.

## Web Playground (`node/`)

The web interactive playground allows viewing and editing NCL and HTML5 documents directly in the browser with live execution powered by the Monaco Editor and the `gingaf` Web runtime.

The compiled playground website is output to `node/playground/` and deployed to GitHub Pages at [https://ginga-org-br.github.io/gingaf/playground/](https://ginga-org-br.github.io/gingaf/playground/).

## Build

To build and serve the playground locally:

```bash
make -C node serve
```

To serve all integration examples (Playground alone, Player alone, and Express app):

```bash
make -C node serve-examples
```
