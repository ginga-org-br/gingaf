# ginga-node

[![](https://img.shields.io/badge/License-MIT-yellow.svg)](../LICENSE)

Node.js package, Express middleware, and web distribution for [gingaf](https://github.com/ginga-org-br/gingaf). It bundles the compiled GingaF Flutter Web runtime and Playground under `dist/gingaf-web/` for embedding NCL, NCL 360, and HTML5 applications in Node.js web apps.

## Installation

```bash
npm install ginga-node express
```

## Express Usage

```js
const express = require('express');
const { gingafMiddleware } = require('ginga-node');

const app = express();
app.use('/gingaf-web', gingafMiddleware());
app.listen(3000);
```

## Makefile Targets

Run inside `node/` (or via the root `Makefile` `*-node` targets):

```bash
make deps
make test
make package
make publish-dry-run
make publish-npm
```

From the repository root:

```bash
make test-node
make package-node
make publish-node-dry-run
make publish-node
```
