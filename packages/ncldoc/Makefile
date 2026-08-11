MAKEFLAGS += -s --no-print-directory

.PHONY: help test deps clean run-example check-app

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps         Install Flutter/Dart dependencies
	@echo   test         Run unit tests
	@echo   clean        Clean build artifacts
	@echo   run-example  Run headless NCL example (e.g. make run-example app=video.ncl)

deps:
	flutter pub get

test:
	flutter test

clean:
	flutter clean

check-app:
	$(if $(app),,$(error Please specify app (e.g. app=video.ncl)))
	$(eval APP_EXAMPLE := $(if $(findstring examples/,$(app)),$(subst examples/,,$(app)),$(app)))
	$(eval APP_EXAMPLE := $(APP_EXAMPLE)$(if $(filter %.ncl %.html,$(APP_EXAMPLE)),,.ncl))
	$(if $(wildcard ../../ginga/examples/$(APP_EXAMPLE)),,$(error File ../../ginga/examples/$(APP_EXAMPLE) does not exist))

run-example: check-app
	@echo ======================================================================
	@echo Running Headless NCL Example: $(APP_EXAMPLE)
	@echo ======================================================================
	dart lib/main.dart ../../ginga/examples/$(APP_EXAMPLE)
