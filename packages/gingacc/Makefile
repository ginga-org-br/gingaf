MAKEFLAGS += -s --no-print-directory

.PHONY: help test deps clean

help:
	@echo Usage: make [target]
	@echo.
	@echo Targets:
	@echo   deps   Install Flutter dependencies
	@echo   test   Run Flutter tests
	@echo   clean  Clean Flutter build artifacts

deps:
	flutter pub get

test:
	flutter test

clean:
	flutter clean
