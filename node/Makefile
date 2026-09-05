MAKEFLAGS += -s --no-print-directory

.PHONY: help deps build serve serve-examples

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps                          Install npm dependencies
	@echo   build                         Build Flutter web, copy assets, and compile TypeScript with esbuild
	@echo   clean                         Remove built artifacts
	@echo   serve                         Serve Playground application
	@echo   serve-examples                Serve all 3 examples (Playground app, Player app, Node Express app)

deps:
	npm install --no-audit --no-fund

build: deps
	npm run build

clean:
	npm run clean

serve: build
	npm run serve

serve-examples: build
	node scripts/serve.js --express examples/playground-app-example.html examples/player-app-example.html


