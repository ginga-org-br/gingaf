# ncl_doc

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../../LICENSE)

Logic package handling the NCL document logic.

## Run Headless (no-UI) Ginga-NCL applications

All example NCL documents are stored in the `examples/` folder.

To run headless NCL simulation:

```bash
dart packages/ncldoc/lib/main.dart examples/video.ncl
```

For easy, you can use `make run`. See below.

```bash
cd packages/ncldoc
make run-example app=video.ncl
```
