MAKEFLAGS += -s --no-print-directory

.PHONY: help deps test release release-publish clean run-example check-app

BASE_HREF ?= /

ifeq ($(OS),Windows_NT)
    VERSION ?= $(shell powershell -Command "(Get-Content pubspec.yaml | Select-String '^version:').Line.Split(':')[1].Trim().Split('+')[0]")
    PLATFORM := windows-x64
    RUN_OS := windows
    RELEASE_BUILD := flutter build windows --release
    RELEASE_DIR := build/windows/x64/runner/Release
    RELEASE_ZIP = powershell -Command "if (Test-Path '$(ZIP_NAME)') { Remove-Item '$(ZIP_NAME)' }; Compress-Archive -Path '$(RELEASE_DIR)/*' -DestinationPath '$(ZIP_NAME)'"
else
    VERSION ?= $(shell grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1 | tr -d '\r')
    UNAME_S := $(shell uname -s)
    UNAME_M := $(shell uname -m)
    ifeq ($(UNAME_S),Darwin)
        PLATFORM := macos-$(UNAME_M)
        RUN_OS := macos
        RELEASE_BUILD := flutter build macos --release
        RELEASE_DIR := build/macos/Build/Products/Release
    else
        ifeq ($(UNAME_M),x86_64)
            ARCH := x64
        else ifeq ($(UNAME_M),aarch64)
            ARCH := arm64
        else
            ARCH := $(UNAME_M)
        endif
        PLATFORM := linux-$(ARCH)
        RUN_OS := linux
        RELEASE_BUILD := flutter build linux --release
        RELEASE_DIR := build/linux/$(ARCH)/release/bundle
    endif
    RELEASE_ZIP = rm -f $(ZIP_NAME) && (cd $(RELEASE_DIR) && zip -r $(CURDIR)/$(ZIP_NAME) .)
endif

ZIP_NAME := gingaf-v$(VERSION)-$(PLATFORM).zip

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps                 Install dependencies for Flutter workspace
	@echo   test                 Run tests for Flutter workspace
	@echo   release              Zip current platform release build
	@echo   release-publish      Publish release to GitHub Releases via gh
	@echo   clean                Clean build artifacts
	@echo   run-example          Run NCL example application (e.g. make run-example app=video.ncl)

deps:
	flutter pub get

test:
	flutter test test packages/ccws/test packages/ncldoc/test --no-pub

build-windows:
	flutter build windows --debug


release:
	$(RELEASE_BUILD)
	$(RELEASE_ZIP)

release-publish: release
	gh release upload v$(VERSION) $(ZIP_NAME) --clobber || gh release create v$(VERSION) $(ZIP_NAME) --generate-notes

clean:
	flutter clean

check-app:
	$(if $(app),,$(error Please specify app (e.g. app=video.ncl)))
	$(eval APP_EXAMPLE := $(if $(findstring examples/,$(app)),$(subst examples/,,$(app)),$(app)))
	$(eval APP_EXAMPLE := $(APP_EXAMPLE)$(if $(filter %.ncl %.html,$(APP_EXAMPLE)),,.ncl))
	$(if $(wildcard examples/$(APP_EXAMPLE)),,$(error File examples/$(APP_EXAMPLE) does not exist))

run-example: check-app
	@echo ======================================================================
	@echo Running Example: $(APP_EXAMPLE)
	@echo ======================================================================
	flutter run --no-pub -d $(RUN_OS) --dart-define="APP=examples/$(APP_EXAMPLE)" || true
