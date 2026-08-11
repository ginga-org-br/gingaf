MAKEFLAGS += -s --no-print-directory

.PHONY: help test deps clean

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps   Install Dart dependencies
	@echo   test   Run Dart tests
	@echo   clean  Clean Dart tool cache

deps:
	dart pub get

test:
	dart test

clean:
	rm -rf .dart_tool
