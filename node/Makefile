MAKEFLAGS += -s --no-print-directory

.PHONY: help deps build serve serve-playground serve-example-playground-app serve-example-player-app serve-example-node-express clean simulate-gh-deploy

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps                          Install npm dependencies
	@echo   build                         Build Flutter web, copy assets, and compile TypeScript/Vite
	@echo   clean                         Remove built artifacts
	@echo   serve                         Serve Playground application
	@echo   serve-playground              Open Ginga Playground IDE (playground.html)
	@echo   serve-example-playground-app  Open Ginga Playground with NCL app integration (example-playground-app.html)
	@echo   serve-example-player-app      Open Ginga Player with autostarting NCL app (example-player-app.html)
	@echo   serve-example-node-express    Serve Node.js Express app (example-node-express)
	@echo   simulate-gh-deploy            Simulate GitHub Actions deploy and serve site locally

deps:
	npm install --no-audit --no-fund

build: deps
	npm run build

clean:
	npm run clean

serve: build
	npm run serve-playground

serve-example-playground-app: build
	npm run serve-example-playground-app

serve-example-player-app: build
	npm run serve-example-player-app

serve-example-node-express: build
	npm run serve-example-node-express

simulate-gh-deploy: build
	-act -C .. -W .github/workflows/deploy-playground.yml -j build
	node -e "const fs=require('fs'); const src=fs.existsSync('../site/dst')?'../site/dst':'dist'; fs.mkdirSync('../site/gingaf/dst',{recursive:true}); fs.cpSync(src,'../site/gingaf/dst',{recursive:true,force:true}); if(fs.existsSync('../site/serve.json')) fs.rmSync('../site/serve.json'); if(fs.existsSync('../site/index.html')) fs.rmSync('../site/index.html');"
	node -e "const cp=require('child_process'); const startCmd=process.platform==='win32'?'start':process.platform==='darwin'?'open':'xdg-open'; setTimeout(()=>cp.exec('$${startCmd} http://localhost:8080/gingaf/dst/',()=>{}), 500);"
	npx serve ../site -p 8080
