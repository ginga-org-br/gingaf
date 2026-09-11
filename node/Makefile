MAKEFLAGS += -s --no-print-directory

.PHONY: help deps build clean serve serve-examples

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps                          Install npm dependencies" \
		"  build                         Build Flutter web, copy assets, and compile TypeScript with esbuild" \
		"  clean                         Remove built artifacts" \
		"  serve                         Serve Playground application" \
		"  serve-examples                Serve all 3 examples (Playground app, Player app, Node Express app)"

deps:
	npm install --no-audit --no-fund

build: deps
	npm run build --silent

clean:
	npm run clean --silent

serve: build
	npm run serve --silent

serve-examples: build
	node scripts/serve.js --express examples/playground-app-example.html examples/player-app-example.html


