MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help
$(if $(filter Windows_NT,$(OS)),$(if $(shell where printf 2>nul),,$(error coreutils is not installed. Please run: winget install coreutils)))

.PHONY: help deps format build build-gingaf test package publish-npm-dry-run publish-npm run-express run-examples-node clean

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps               Install Node.js dependencies for ginga-node and Express example" \
		"  format             Type-check TypeScript sources" \
		"  build              Compile TypeScript wrapper into dist/" \
		"  build-gingaf       Build Flutter Web bundle and stage into dist/gingaf-web/" \
		"  test               Run Node.js unit tests" \
		"  package            Build, test, and pack npm tarball (.tgz)" \
		"  publish-npm-dry-run  Run package and verify npm publish without uploading" \
		"  publish-npm        Build, test, and publish ginga-node to npm" \
		"  run-express        Run the Express example server" \
		"  run-examples-node  Serve Node express embedded player and playground" \
		"  clean              Remove compiled dist artifacts and tarballs"

deps:
	npm install --no-audit --no-fund
	rm -rf example-node-express/node_modules/ginga-node example-node-express/package-lock.json
	npm --prefix example-node-express install --no-audit --no-fund

format:
	npm run check

build:
	npm run build

../build/web/main.dart.js:
	$(MAKE) -C .. build/web/main.dart.js

build-gingaf: ../build/web/main.dart.js
	rm -rf dist/gingaf-web
	mkdir -p dist/gingaf-web
	cp -r ../build/web/* dist/gingaf-web/

test: build
	npm test

package: deps build build-gingaf
	rm -f *.tgz
	npm pack
	npm run test:package

publish-npm-dry-run: package
	npm publish --dry-run --access public

publish-npm: package
	npm publish --access public

run-express: build build-gingaf deps
	npm --prefix example-node-express start

run-examples-node: build build-gingaf deps
	npm --prefix example-node-express start &
	cd .. && node serve.js

clean:
	rm -rf dist *.tgz example-node-express/node_modules example-node-express/package-lock.json
