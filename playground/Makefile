.PHONY: help test deps serve build clean run-example

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps         Install npm dependencies
	@echo   test         Run playground tests
	@echo   serve        Build web player and start dev server
	@echo   build        Build production playground bundle
	@echo   clean        Clean playground build artifacts
	@echo   run-example  Run Express example application

deps:
	npm install --no-audit --no-fund

test:
	node test/main.test.js

serve: deps
	npm run dev

build: deps
	npm run build

clean:
	npm run clean

run-example: build
	cd example && npm install --no-audit --no-fund && npm start
