PYTHON ?= python
rm = $(PYTHON) -c "import os, sys; [os.remove(f) for f in sys.argv[1:] if os.path.exists(f)]"
rmdir = $(PYTHON) -c "import shutil, sys; [shutil.rmtree(f, ignore_errors=True) for f in sys.argv[1:]]"
mkdir = $(PYTHON) -c "import os, sys; [os.makedirs(f, exist_ok=True) for f in sys.argv[1:]]"
cp = $(PYTHON) -c "import shutil, sys; shutil.copy2(sys.argv[1], sys.argv[2])"
cpdir = $(PYTHON) -c "import shutil, sys; shutil.copytree(sys.argv[1], sys.argv[2], dirs_exist_ok=True)"

.PHONY: help test deps serve build clean

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps   Install npm dependencies
	@echo   test   Run playground tests
	@echo   serve  Build web player and start dev server
	@echo   build  Build production playground bundle
	@echo   clean  Clean playground build artifacts

deps:
	npm install --no-audit --no-fund

test:
	node test/main.test.js

public/player/flutter_bootstrap.js:
	$(MAKE) -C ../ginga build-web BASE_HREF=/gingaf/playground/player/
	@$(mkdir) public/player
	@$(cpdir) ../ginga/build/web public/player

serve: public/player/flutter_bootstrap.js
	npm run dev

build: public/player/flutter_bootstrap.js
	npm run build

clean:
	@$(rmdir) dist public/player
