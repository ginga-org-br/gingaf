.PHONY: test deps build build-windows build-web clean run-example check-app

BASE_HREF ?= /

deps:
	flutter pub get

test:
	flutter test

build-windows: 
	flutter build windows --debug

rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
DART_FILES := $(call rwildcard,../ncl_doc .,*.dart)

build-web:
	flutter build web --base-href $(BASE_HREF)

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
	flutter run --no-pub -d windows --dart-define="APP=examples/$(APP_EXAMPLE)"
