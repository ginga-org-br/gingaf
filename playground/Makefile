.PHONY: help test deps serve build clean run-example simulate-gh-deploy

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps                Install npm dependencies
	@echo   test                Run playground tests
	@echo   serve               Build and start dev server
	@echo   build               Build production playground bundle
	@echo   clean               Clean playground build artifacts
	@echo   run-example         Run single app integration example (index-app-example.html)
	@echo   simulate-gh-deploy  Simulate GitHub Pages deploy with act and serve site

deps:
	npm install --no-audit --no-fund

test:
	node test/main.test.js

serve: build
	npm run dev

build: deps
	npm run build

clean:
	npm run clean

run-example: build
	npm run run-example

simulate-gh-deploy:
	act -C .. -W .github/workflows/deploy-playground.yml -j build
	node -e "const fs=require('fs'); const src=fs.existsSync('../site/playground')?'../site/playground':'dist'; fs.mkdirSync('../site/gingaf',{recursive:true}); fs.cpSync(src,'../site/gingaf/playground',{recursive:true,force:true}); if(fs.existsSync('../site/serve.json')) fs.rmSync('../site/serve.json'); fs.writeFileSync('../site/index.html', '<!DOCTYPE html><html><head><meta http-equiv=\x22refresh\x22 content=\x220; url=/gingaf/playground/\x22></head></html>');"
	npx serve ../site -p 8080