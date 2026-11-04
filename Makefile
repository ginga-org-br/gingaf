MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help
$(if $(filter Windows_NT,$(OS)),$(if $(shell where printf 2>nul),,$(error coreutils is not installed. Please run: winget install coreutils)))

.PHONY: help deps release release-web build-web release-windows release-android release-linux release-linux-deb release-macos test tests doc release-publish clean clean-web run-example check-app serve serve-node deploy-folder integration_test test-linux-distros

BASE_HREF ?= /

VERSION ?= $(firstword $(subst +, ,$(patsubst version:%,%,$(filter version:%,$(subst version: ,version:,$(file <pubspec.yaml))))))

ifeq ($(OS),Windows_NT)
CURRENT_OS := windows
else ifneq ($(wildcard /System/Library),)
CURRENT_OS := macos
else
CURRENT_OS := linux
endif

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps                                         Install dependencies for Flutter workspace" \
		"  format                                       Format Dart code across workspace" \
		"  release                                      Build release application for current host OS" \
		"  release-web                                  Build release application for web" \
		"  release-android                              Build release application for Android" \
		"  release-{windows,linux,macos}                Build release application for target desktop platform" \
		"  release-linux-deb                            Build release Debian package inside Ubuntu 22.04 Docker container" \
		"  serve                                        Serve web player and playground" \
		"  serve-node                                   Serve Node express embedded player and playground" \
		"  test                                         Run tests for Flutter workspace" \
		"  test-linux-distros                           Test Linux release across Ubuntu 22.04, 24.04, 26.04" \
		"  doc                                          Generate Dart documentation" \
		"  release-publish                              Publish release to GitHub Releases via gh" \
		"  clean                                        Clean build artifacts" \
		"  run-example                                  Run one application at examples/ (e.g. make run-example app=video.ncl)" \
		"  integration_test                             Run integration tests"

.dart_tool/package_config.json: pubspec.yaml $(wildcard packages/*/pubspec.yaml)
	flutter pub get
	@touch -c .dart_tool/package_config.json

deps: .dart_tool/package_config.json

release: release-$(CURRENT_OS)

release-web: deps
	flutter build web --no-pub --release

release-windows: deps
	flutter build windows --no-pub --release

release-android: deps
	flutter build apk --no-pub --release

release-linux: deps
	flutter build linux --no-pub --release
	bash linux/package-deb.sh build/linux/x64/release/bundle $(VERSION) $(CURDIR)/gingaf-v$(VERSION)-linux-amd64.deb

release-linux-deb:
	bash linux/release-linux-deb.sh

test-linux-distros:
	bash linux/test-linux-distros.sh

release-macos: deps
	flutter build macos --no-pub --release

test:
	flutter test test packages/gingacc/test packages/ncldoc/test packages/nclui/test packages/plugins/test packages/playground/test --no-pub

format:
	dart format .
	
integration_test:
	flutter test --no-pub integration_test $(if $(d),-d $(d))

doc:
	npx -y @mermaid-js/mermaid-cli -i doc/architecture.mmd -o doc/architecture.svg -b transparent
	dart doc
	touch doc/api/.nojekyll
	mkdir -p doc/api/doc
	cp doc/architecture.svg doc/api/doc/architecture.svg
	npx serve doc/api

RELEASE_FILES = $(sort $(if $(wildcard build/windows/x64/runner/Release/*),gingaf-v$(VERSION)-windows-x64.zip) $(if $(wildcard build/macos/Build/Products/Release/*),gingaf-v$(VERSION)-macos.zip) $(wildcard gingaf-v$(VERSION)-*.zip gingaf-v$(VERSION)-*.deb))

define package-zip
	$(if $(wildcard $(2)/*),cd $(2) && tar -a -cf $(CURDIR)/$(1) *)
endef

release-publish:
	$(if $(strip $(RELEASE_FILES)),,$(error No release artifacts found to publish for v$(VERSION)))
	$(call package-zip,gingaf-v$(VERSION)-windows-x64.zip,build/windows/x64/runner/Release)
	$(call package-zip,gingaf-v$(VERSION)-macos.zip,build/macos/Build/Products/Release)
	gh release upload v$(VERSION) $(strip $(RELEASE_FILES)) --clobber || gh release create v$(VERSION) $(strip $(RELEASE_FILES)) --generate-notes


build-web: release-web

serve: $(if $(wildcard build/web/main.dart.js),,build-web)
	@printf "\n   playground alone:        http://localhost:5173/gingaf/playground/\n"
	@printf "   playground with app:     http://localhost:5173/gingaf/playground/?app=https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/video.ncl\n"
	@printf "   player with app:         http://localhost:5173/gingaf/?app=https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/video.ncl\n\n"
	node serve.js

serve-node: $(if $(wildcard build/web/main.dart.js),,build-web)
	npm --prefix node install --no-audit --no-fund
	npm --prefix node/example-node-express install --no-audit --no-fund
	npm --prefix node run build
	mkdir -p node/playground/gingaf-web
	cp -r build/web/* node/playground/gingaf-web/
	npm --prefix node/example-node-express start &
	node serve.js

deploy-folder: build-web
	$(if $(strip $(GINGA_DEPLOY)),,$(error GINGA_DEPLOY environment variable is not set))
	mkdir -p $(GINGA_DEPLOY)/gingaf
	rsync -av --delete build/web/ $(GINGA_DEPLOY)/gingaf/
	rsync -av --delete examples/ $(GINGA_DEPLOY)/gingaf/examples/
	cp examples/catalog.json $(GINGA_DEPLOY)/gingaf/catalog.json

clean-web:
	rm -rf build/web

clean: clean-web
	flutter clean
	rm -rf node/dist node/gingaf node/playground

check-app:
	$(if $(app),,$(error Please specify app (e.g. app=video.ncl)))
	$(eval APP_EXAMPLE := $(if $(findstring examples/,$(app)),$(subst examples/,,$(app)),$(app)))
	$(if $(wildcard examples/$(APP_EXAMPLE)),,$(error File examples/$(APP_EXAMPLE) does not exist))

run-example: check-app
	$(info ======================================================================)
	$(info Running Example: $(APP_EXAMPLE))
	$(info ======================================================================)
	flutter run --no-pub $(if $(d),-d $(d)) --dart-define="GINGA_APP=examples/$(APP_EXAMPLE)" --dart-define="GINGA_PLAYGROUND=false" || true

