.PHONY: test deps serve build

deps:
	npm install

serve:
	$(MAKE) -C ../ginga build-web BASE_HREF=/gingaf/playground/player/
	cp -r ../ginga/build/web/. public/player/
	npm run dev

build:
	$(MAKE) -C ../ginga build-web BASE_HREF=/gingaf/playground/player/
	cp -r ../ginga/build/web/. public/player/
	npm run build
