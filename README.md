# gingaf

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

`gingaf` is an MIT-licensed, multi-platform implementation of the interactive TV middleware Ginga standardised by ITU-T and SBTVD.

For a web-based evaluation of `gingaf`, see [a github-hosted Ginga Playground](https://ginga-org-br.github.io/gingaf/playground/).

The `gingaf` project structure is:

- `ncldoc/` - Dart-based headless execution engine and core NCL logic. See [ncldoc/README.md](ncldoc/README.md).
- `ccws/` - Dart-based Complementary Device Web Service library. See [ccws/README.md](ccws/README.md).
- `ginga/` - Ginga visual of Ginga-NCL and Ginga-HTML5 applications (contains the `examples/` for testing). See how to run application at [ginga/README.md](ginga/README.md). Depends on `ncldoc/` and `ccws/`.
- `playground/` - web-based interactive playground for evaluating gingaf. See [playground/README.md](playground/README.md). Depends on `ginga`.
- `vscode/` - Visual Studio Code extension. See [vscode/README.md](vscode/README.md). Depends on `ginga`.

## Demonstration Videos

### Windows

https://github.com/user-attachments/assets/07c9fb0f-a9f1-406b-b650-fa4eee331af0

### Android

https://github.com/user-attachments/assets/5bbecb80-04c7-4574-88d5-e979d1c11e22

### Chrome

https://github.com/user-attachments/assets/b04eabac-4636-453c-beec-7ec845d841a4

### NCL headless

https://github.com/user-attachments/assets/576cba53-04b7-4b55-b4a5-97d1b78f4a79

### Playground Ginga-NCL (video.ncl)

https://github.com/user-attachments/assets/c6fd4ce3-66a5-4888-8b49-50dde510c2d8

### Playground  Ginga-HTML5 (current_service.html)

https://github.com/user-attachments/assets/3f4aa3f4-5950-4b6e-8a32-50021e8b014f

### Playground  Ginga-NCL with Lua (lua.ncl)

https://github.com/user-attachments/assets/b06bf145-4cc2-4431-9f00-98b218cfedde
