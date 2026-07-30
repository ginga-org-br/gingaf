.PHONY: help deps build package test clean run-vscode-with-extension-only

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps                              Install npm dependencies
	@echo   build                             Build the VS Code extension package
	@echo   test                              Run extension tests
	@echo   clean                             Clean up temporary test and package files
	@echo   run-vscode-with-extension-only   Run VS Code with only this extension loaded

deps:
	npm install --no-audit --no-fund

build:
	npx @vscode/vsce package


test:
	node test/extension.test.js

clean:
	rm -rf .vscode-test
	rm -f *.vsix

CODE_CMD := code

run-vscode-with-extension-only: build
	rm -rf .vscode-test/exts
	node -e "const cp = require('child_process'); const fs = require('fs'); const vsix = fs.readdirSync('.').find(f => f.endsWith('.vsix')); cp.spawnSync('$(CODE_CMD)', ['--extensions-dir=.vscode-test/exts', '--install-extension', vsix], { stdio: 'inherit', shell: true });"
	$(CODE_CMD) --user-data-dir=.vscode-test/user --extensions-dir=.vscode-test/exts



