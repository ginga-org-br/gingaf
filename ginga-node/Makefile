.PHONY: help deps build serve clean run-example

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps         Install npm dependencies
	@echo   build        Build Flutter web, copy assets, and compile TypeScript
	@echo   clean        Remove built artifacts
	@echo   run-example  Run Express example application

deps:
	npm install --no-audit --no-fund

build: deps
	npm run build


clean:
	node -e "const fs=require('fs'); ['dist', 'assets', 'node_modules'].forEach(d => fs.existsSync(d) && fs.rmSync(d, { recursive: true, force: true }));"

run-example:
	cd example && npm install --no-audit --no-fund && npm start
