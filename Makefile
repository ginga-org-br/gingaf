.PHONY: help test deps

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps  Install dependencies for all components
	@echo   test  Run unit tests for all components

deps:
	$(MAKE) -C ccws deps
	$(MAKE) -C ncldoc deps
	$(MAKE) -C ginga deps
	$(MAKE) -C playground deps
	$(MAKE) -C vscode deps

test: deps
	$(MAKE) -C ccws test
	$(MAKE) -C ncldoc test
	$(MAKE) -C ginga test
	$(MAKE) -C playground test
	$(MAKE) -C vscode test