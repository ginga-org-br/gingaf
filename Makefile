MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help
$(if $(filter Windows_NT,$(OS)),$(if $(shell where printf 2>nul),,$(error coreutils is not installed. Please run: winget install coreutils)))

.PHONY: help deps release release-web release-windows release-android release-linux release-macos test tests doc release-publish clean run-example check-app serve serve-examples integration_test

BASE_HREF ?= /

VERSION ?= $(shell grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1 | tr -d '\r')

ifeq ($(OS),Windows_NT)
CURRENT_OS := windows
else
UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(UNAME_S),Darwin)
CURRENT_OS := macos
else
CURRENT_OS := linux
endif
endif

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps                                         Install dependencies for Flutter workspace" \
		"  release                                      Build release application for current host OS" \
		"  release-web                                  Build release application for web" \
		"  release-android                              Build release application for Android" \
		"  release-{windows,linux,macos}                Build release application for target desktop platform" \
		"  serve                                        Serve web playground application" \
		"  test                                         Run tests for Flutter workspace" \
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

release-macos: deps
	flutter build macos --no-pub --release

test:
	flutter test test packages/gingacc/test packages/ncldoc/test packages/nclui/test $(wildcard packages/playground/test) --no-pub

integration_test:
	flutter test --no-pub integration_test $(if $(d),-d $(d))

doc:
	npx -y @mermaid-js/mermaid-cli -i doc/architecture.mmd -o doc/architecture.svg -b transparent
	dart doc
	touch doc/api/.nojekyll
	mkdir -p doc/api/doc
	cp doc/architecture.svg doc/api/doc/architecture.svg
	npx serve doc/api


define package-zip
	[ ! -d $(2) ] || (cd $(2) && zip -q -FS -r $(CURDIR)/$(1) .)
endef

release-publish:
	$(call package-zip,gingaf-v$(VERSION)-windows-x64.zip,build/windows/x64/runner/Release)
	$(call package-zip,gingaf-v$(VERSION)-linux-x64.zip,build/linux/x64/release/bundle)
	$(call package-zip,gingaf-v$(VERSION)-macos.zip,build/macos/Build/Products/Release)
	gh release upload v$(VERSION) gingaf-v$(VERSION)-*.zip --clobber || gh release create v$(VERSION) gingaf-v$(VERSION)-*.zip --generate-notes


serve: release-web
	make -C node serve

serve-examples: release-web
	make -C node serve-examples

clean:
	flutter clean
	make -C node clean

check-app:
	$(if $(app),,$(error Please specify app (e.g. app=video.ncl)))
	$(eval APP_EXAMPLE := $(if $(findstring examples/,$(app)),$(subst examples/,,$(app)),$(app)))
	$(if $(wildcard examples/$(APP_EXAMPLE)),,$(error File examples/$(APP_EXAMPLE) does not exist))

run-example: check-app
	$(info ======================================================================)
	$(info Running Example: $(APP_EXAMPLE))
	$(info ======================================================================)
	flutter run --no-pub $(if $(d),-d $(d)) --dart-define="GINGA_APP=examples/$(APP_EXAMPLE)" || true
