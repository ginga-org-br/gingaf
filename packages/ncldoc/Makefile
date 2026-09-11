MAKEFLAGS += -s --no-print-directory

.PHONY: help test deps clean run-example check-app

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps         Install Flutter/Dart dependencies" \
		"  test         Run unit tests" \
		"  clean        Clean build artifacts" \
		"  run-example  Run headless NCL example (e.g. make run-example app=video.ncl)"

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
	$(if $(wildcard ../../examples/$(APP_EXAMPLE)),,$(error File ../../examples/$(APP_EXAMPLE) does not exist))

run-example: check-app
	$(info ======================================================================)
	$(info Running Headless NCL Example: $(APP_EXAMPLE))
	$(info ======================================================================)
	dart lib/main.dart ../../examples/$(APP_EXAMPLE)
