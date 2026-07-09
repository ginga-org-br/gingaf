.PHONY: test deps build build-windows build-web clean run-example check-app

BASE_HREF ?= /

deps:
	flutter pub get

test:
	flutter test

build: 
	flutter build windows

build-windows: build/windows/x64/runner/Release/gingaf.exe

rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
DART_FILES := $(call rwildcard,../ncl_doc .,*.dart)

build/windows/x64/runner/Release/gingaf.exe: $(DART_FILES)
	flutter build windows

build-web:
	flutter build web --base-href $(BASE_HREF)

clean:
	flutter clean

examples:
	-cmd /c "mklink /J examples ..\examples" || ln -s ../examples examples

check-app:
	$(if $(app),,$(error Please specify app (e.g. app=video.ncl)))
	$(eval APP_EXAMPLE := $(if $(findstring examples/,$(app)),$(subst examples/,,$(app)),$(app)))
	$(eval APP_EXAMPLE := $(APP_EXAMPLE)$(if $(filter %.ncl %.html,$(APP_EXAMPLE)),,.ncl))
	$(if $(wildcard ../examples/$(APP_EXAMPLE)),,$(error File ../examples/$(APP_EXAMPLE) does not exist))

run-example: check-app examples
	@echo ======================================================================
	@echo Running Example: $(APP_EXAMPLE)
	@echo ======================================================================
	flutter run --no-pub -d windows --dart-define="APP=examples/$(APP_EXAMPLE)"
