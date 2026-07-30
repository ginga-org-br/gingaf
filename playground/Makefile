.PHONY: help test deps serve build

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps   Install npm dependencies
	@echo   test   Run playground tests
	@echo   serve  Build web player and start dev server
	@echo   build  Build production playground bundle

deps:
	npm install --no-audit --no-fund

test:
	node test/main.test.js

serve:
	$(MAKE) -C ../ginga build-web BASE_HREF=/gingaf/playground/player/
	cp -r ../ginga/build/web/. public/player/
	npm run dev

build:
	$(MAKE) -C ../ginga build-web BASE_HREF=/gingaf/playground/player/
	cp -r ../ginga/build/web/. public/player/
	npm run build
