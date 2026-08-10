ifeq ($(OS),Windows_NT)
    RM = if exist $(subst /,\,$1) del /F /Q $(subst /,\,$1)
    RMDIR = if exist $(subst /,\,$1) rmdir /S /Q $(subst /,\,$1)
    MKDIR = if not exist $(subst /,\,$1) mkdir $(subst /,\,$1)
    CP = copy /Y $(subst /,\,$1) $(subst /,\,$2)
    CPDIR = xcopy /E /I /Y /Q $(subst /,\,$1) $(subst /,\,$2)
else
    RM = rm -f
    RMDIR = rm -rf
    MKDIR = mkdir -p
    CP = cp
    CPDIR = cp -R
endif

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
	$(MAKE) -C ../ginga-node build
	npm install --no-audit --no-fund

test:
	node test/main.test.js

serve:
	npm run dev

build:
	npm run build

clean:
	npm run clean
