MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help
$(if $(filter Windows_NT,$(OS)),$(if $(shell where printf 2>nul),,$(error coreutils is not installed. Please run: winget install coreutils)))

.PHONY: help deps release-web release-windows release-android release-linux release-macos test tests doc release-publish clean run-example check-app serve serve-examples integration_test

BASE_HREF ?= /

VERSION ?= $(shell grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1 | tr -d '\r')

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps                                         Install dependencies for Flutter workspace" \
		"  release-{web,windows,android,linux,macos}    Build release application for target platform" \
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

release-web: deps
	flutter build web --no-pub --release


release-windows: deps
	flutter build windows --no-pub --release
	rm -f gingaf-v$(VERSION)-windows-x64.zip && (cd build/windows/x64/runner/Release && zip -r $(CURDIR)/gingaf-v$(VERSION)-windows-x64.zip .)

release-android: deps
	flutter build apk --no-pub --release
	rm -f gingaf-v$(VERSION)-android.zip && (cd build/app/outputs/flutter-apk && zip -r $(CURDIR)/gingaf-v$(VERSION)-android.zip app-release.apk)

release-linux: deps
	flutter build linux --no-pub --release
	rm -f gingaf-v$(VERSION)-linux-x64.zip && (cd build/linux/x64/release/bundle && zip -r $(CURDIR)/gingaf-v$(VERSION)-linux-x64.zip .)

release-macos: deps
	flutter build macos --no-pub --release
	rm -f gingaf-v$(VERSION)-macos.zip && (cd build/macos/Build/Products/Release && zip -r $(CURDIR)/gingaf-v$(VERSION)-macos.zip .)

test:
	flutter test test packages/gingacc/test packages/ncldoc/test packages/nclui/test --no-pub

integration_test:
	flutter test --no-pub integration_test $(if $(d),-d $(d))

doc:
	npx -y @mermaid-js/mermaid-cli -i doc/architecture.mmd -o doc/architecture.svg -b transparent
	dart doc
	touch doc/api/.nojekyll
	mkdir -p doc/api/doc
	cp doc/architecture.svg doc/api/doc/architecture.svg
	npx serve doc/api


release-publish:
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
