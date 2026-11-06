MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help
$(if $(filter Windows_NT,$(OS)),$(if $(shell where printf 2>nul),,$(error coreutils is not installed. Please run: winget install coreutils)))

.PHONY: help deps deps-host deps-android format build build-web build-android release release-web release-android publish test test-linux-distros doc clean run-example serve serve-node deploy-folder integration_test

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
		"  deps-host                                    Install host OS dependencies" \
		"  deps-android                                 Install Android SDK and emulator dependencies" \
		"  format                                       Format Dart code across workspace" \
		"  build                                        Build application for current host OS" \
		"  build-web                                    Build application for web" \
		"  build-android                                Build application for Android" \
		"  release                                      Build and package release for current host OS" \
		"  release-web                                  Build and package release for web" \
		"  release-android                              Build and package release for Android" \
		"  publish                                      Publish release to GitHub" \
		"  serve                                        Serve web player and playground" \
		"  serve-node                                   Serve Node express embedded player and playground" \
		"  test                                         Run tests for Flutter workspace" \
		"  test-linux-distros                           Test Linux release across Ubuntu 22.04, 24.04, 26.04" \
		"  doc                                          Generate Dart documentation" \
		"  clean                                        Clean build artifacts" \
		"  run-example                                  Run one application at examples/ (e.g. make run-example app=video.ncl)" \
		"  integration_test                             Run integration tests"

.dart_tool/package_config.json: pubspec.yaml $(wildcard packages/*/pubspec.yaml)
	flutter pub get
	@touch -c .dart_tool/package_config.json

deps: .dart_tool/package_config.json

ifeq ($(CURRENT_OS),windows)
deps-host:
	powershell -ExecutionPolicy Bypass -File windows/install-host-deps-windows.ps1

deps-android:
	powershell -ExecutionPolicy Bypass -File android/install-host-deps-android.ps1
else ifeq ($(CURRENT_OS),macos)
deps-host:
	bash macos/install-host-deps-macos.sh

deps-android:
	bash android/install-host-deps-android.sh
else
deps-host:
	bash linux/install-host-deps-ubuntu.sh

deps-android:
	bash android/install-host-deps-android.sh
endif

define package-zip
	$(if $(wildcard $(2)/*),cd $(2) && tar -a -cf $(CURDIR)/$(1) *)
endef

build: deps
	flutter build $(CURRENT_OS) --no-pub --release

build-web: deps
	flutter build web --no-pub --release

build-android: deps
	flutter build apk --no-pub --release

ifeq ($(CURRENT_OS),windows)
release: build
	$(call package-zip,gingaf-v$(VERSION)-windows-x64.zip,build/windows/x64/runner/Release)
else ifeq ($(CURRENT_OS),macos)
release: build
	$(call package-zip,gingaf-v$(VERSION)-macos.zip,build/macos/Build/Products/Release)
else
release: deps
	bash linux/release-linux-deb.sh $(VERSION)
endif

release-web: build-web
	$(call package-zip,gingaf-v$(VERSION)-web.zip,build/web)

release-android: build-android
	cp build/app/outputs/flutter-apk/app-release.apk gingaf-v$(VERSION)-android.apk

test-linux-distros:
	bash linux/test-linux-distros.sh

test:
	flutter test test packages/gingacc/test packages/ncldoc/test packages/nclui/test packages/plugins/test packages/playground/test --no-pub

format:
	dart format .

integration_test:
	flutter test --no-pub integration_test -d $(if $(d),$(d),$(CURRENT_OS))

doc:
	npx -y @mermaid-js/mermaid-cli -i doc/architecture.mmd -o doc/architecture.svg -b transparent
	dart doc
	touch doc/api/.nojekyll
	mkdir -p doc/api/doc
	cp doc/architecture.svg doc/api/doc/architecture.svg
	npx serve doc/api

RELEASE_FILES = $(sort $(wildcard gingaf-v$(VERSION)-*.zip gingaf-v$(VERSION)-*.deb gingaf-v$(VERSION)-*.apk))

publish:
	$(if $(strip $(RELEASE_FILES)),,$(error No release artifacts found to publish for v$(VERSION)))
	gh release upload v$(VERSION) $(strip $(RELEASE_FILES)) --clobber || gh release create v$(VERSION) $(strip $(RELEASE_FILES)) --generate-notes

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

clean:
	flutter clean
	rm -rf build/web node/dist node/gingaf node/playground

define check-app
	$(if $(app),,$(error Please specify app (e.g. app=video.ncl)))
	$(if $(filter http://% https://%,$(app)), \
		$(eval APP_TARGET := $(app)), \
		$(eval APP_EXAMPLE := $(if $(findstring examples/,$(app)),$(subst examples/,,$(app)),$(app))) \
		$(if $(wildcard examples/$(APP_EXAMPLE)),,$(error File examples/$(APP_EXAMPLE) does not exist)) \
		$(eval APP_TARGET := examples/$(APP_EXAMPLE)))
endef

run-example:
	$(call check-app)
	$(info ======================================================================)
	$(info Running Example: $(APP_TARGET))
	$(info ======================================================================)
	flutter run --no-pub -d $(if $(d),$(d),$(CURRENT_OS)) --dart-define="GINGA_APP=$(APP_TARGET)" --dart-define="GINGA_PLAYGROUND=false" || true
