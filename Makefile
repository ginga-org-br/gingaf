MAKEFLAGS += -s --no-print-directory

.PHONY: help test deps

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps  Install dependencies for all components
	@echo   test  Run unit tests for all components

deps:
	$(MAKE) -C packages/ccws deps
	$(MAKE) -C packages/ncldoc deps
	$(MAKE) -C ginga deps
	$(MAKE) -C ginga-node deps
	$(MAKE) -C ginga-code deps

test: deps
	$(MAKE) -C packages/ccws test
	$(MAKE) -C packages/ncldoc test
	$(MAKE) -C ginga test
	$(MAKE) -C ginga-code test
