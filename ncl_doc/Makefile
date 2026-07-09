.PHONY: test deps clean run-example check-app

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
	$(if $(wildcard ../examples/$(APP_EXAMPLE)),,$(error File ../examples/$(APP_EXAMPLE) does not exist))

run-example: check-app
	@echo ======================================================================
	@echo Running Headless NCL Example: $(APP_EXAMPLE)
	@echo ======================================================================
	dart lib/main.dart ../examples/$(APP_EXAMPLE)
