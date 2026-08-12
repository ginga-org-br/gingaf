MAKEFLAGS += -s --no-print-directory

.PHONY: help deps test build build-windows build-web build-release-zip clean run-example check-app setup

BASE_HREF ?= /

ifeq ($(OS),Windows_NT)
    VERSION ?= $(shell powershell -Command "(Get-Content pubspec.yaml | Select-String '^version:').Line.Split(':')[1].Trim().Split('+')[0]")
    PLATFORM := windows-x64
    BUILD_CMD := flutter build windows --release
    RELEASE_DIR := build/windows/x64/runner/Release
    ZIP_CMD = powershell -Command "if (Test-Path '$(ZIP_NAME)') { Remove-Item '$(ZIP_NAME)' }; Compress-Archive -Path '$(RELEASE_DIR)/*' -DestinationPath '$(ZIP_NAME)'"
else
    VERSION ?= $(shell grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1 | tr -d '\r')
    UNAME_S := $(shell uname -s)
    UNAME_M := $(shell uname -m)
    ifeq ($(UNAME_S),Darwin)
        PLATFORM := macos-$(UNAME_M)
        BUILD_CMD := flutter build macos --release
        RELEASE_DIR := build/macos/Build/Products/Release
    else
        PLATFORM := linux-$(UNAME_M)
        BUILD_CMD := flutter build linux --release
        RELEASE_DIR := build/linux/$(UNAME_M)/release/bundle
    endif
    ZIP_CMD = rm -f $(ZIP_NAME) && (cd $(RELEASE_DIR) && zip -r $(CURDIR)/$(ZIP_NAME) .)
endif

ZIP_NAME := gingaf-v$(VERSION)-$(PLATFORM).zip

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps                 Install dependencies for Flutter workspace
	@echo   test                 Run tests for Flutter workspace
	@echo   build-windows        Build debug executable for Windows
	@echo   build-web            Build web release bundle
	@echo   build-release-zip    Zip current platform release build
	@echo   clean                Clean build artifacts
	@echo   run-example          Run NCL example application (e.g. make run-example app=video.ncl)

deps:
	flutter pub get

test: deps
	flutter test

build-windows:
	flutter build windows --debug

build-web:
	flutter build web --base-href $(BASE_HREF)

build-release-zip:
	$(BUILD_CMD)
	$(ZIP_CMD)

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
	flutter run -d windows --dart-define="APP=examples/$(APP_EXAMPLE)" || true
