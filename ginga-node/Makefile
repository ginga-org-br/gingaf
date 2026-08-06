PYTHON ?= python
rmdir = $(PYTHON) -c "import shutil, sys; [shutil.rmtree(f, ignore_errors=True) for f in sys.argv[1:]]"

.PHONY: help deps build serve clean run-example check-app

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps         Install npm dependencies
	@echo   build        Build Flutter web, copy assets, and compile TypeScript
	@echo   serve        Start standalone HTTP server
	@echo   clean        Clean node build artifacts
	@echo   run-example  Build and serve an NCL example (e.g. make run-example app=video.ncl)

deps:
	npm install --no-audit --no-fund

build:
	npm run build

serve:
	npm run serve

clean:
	@$(rmdir) dist assets

check-app:
	$(if $(app),,$(error Please specify app (e.g. app=video.ncl)))
	$(eval APP_EXAMPLE := $(if $(findstring examples/,$(app)),$(subst examples/,,$(app)),$(app)))
	$(eval APP_EXAMPLE := $(APP_EXAMPLE)$(if $(filter %.ncl %.html,$(APP_EXAMPLE)),,.ncl))
	$(if $(wildcard ../ginga/examples/$(APP_EXAMPLE)),,$(error File ../ginga/examples/$(APP_EXAMPLE) does not exist))

run-example: check-app
	@echo ======================================================================
	@echo Running Example: $(APP_EXAMPLE)
	@echo ======================================================================
	cd ../ginga && flutter build web --release --dart-define="APP=examples/$(APP_EXAMPLE)"
	npm run copy:assets
	npx tsc
	npx vite preview --outDir assets --open
