.PHONY: test deps serve build

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
