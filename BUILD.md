# Build

`gingaf` is based on Flutter. Follow the workflow below to set up host dependencies, build, test, and run examples.

```bash
make deps-host
make deps
make build
make test
make run-example app=video.ncl
```

`make deps-host` installs host OS dependencies, and `make deps-android` installs Android SDK and emulator dependencies if targeting Android. When building on WSL2, enable `guiApplications=true` in `~/.wslconfig`; on Android, launch the emulator with `flutter emulators --launch flutter_dev` before running.

## Running Examples

Example NCL, Lua, and HTML documents are located in `examples/`. Run an example locally or directly from a remote URL with `make run-example` (optionally passing `d=<device>` such as `linux`, `windows`, `macos`, `chrome`, or `emulator-5554`), or launch the local web playground server at `http://localhost:5173/gingaf/playground/` with `make serve`:

```bash
make run-example app=video.ncl
make run-example app=video.ncl d=chrome
make run-example app=https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/video.ncl d=emulator-5554
make serve
```

## Releases

To build and package a distributable release artifact (`.zip`, `.deb`, or `.apk`):

```bash
make release
make release-web
make release-android
```

To upload or create a GitHub Release using the `gh` CLI:

```bash
make publish
```
