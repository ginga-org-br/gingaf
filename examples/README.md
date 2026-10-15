# Ginga Examples

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This directory showcases Ginga-NCL and Ginga-HTML5 applications

## Runing examples from local

See [BUILD.md](../BUILD.md) to `make run-example app=APP_NAME` and run applications.

## Runing examples from Playground

You can start the Playground locally by `make serve` or run from the [ginga.org.br/gingaf/playground](https://ginga.org.br/gingaf/playground). It will serve all the examples and you can run them from the browser using the [catalog.json)](examples/catalog.json), which is resolved in order from:

    - **Local Development Server**: `http://localhost:5173/examples/catalog.json` (or `http://localhost:5173/gingaf/playground/catalog.json`)
    - **GitHub Pages**: `https://ginga-org-br.github.io/gingaf/examples/catalog.json`
    - **Fallback Raw Content**: `https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/catalog.json`

### Gif generation

From the `examples/` directory, use the following [Makefile](examples/Makefile) commands to generate preview GIFs for all examples:

```bash
make gifs target=video.ncl
```
