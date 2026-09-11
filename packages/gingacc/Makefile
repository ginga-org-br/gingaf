MAKEFLAGS += -s --no-print-directory

.PHONY: help test deps clean

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps   Install Flutter dependencies" \
		"  test   Run Flutter tests" \
		"  clean  Clean Flutter build artifacts"

deps:
	flutter pub get

test:
	flutter test

clean:
	flutter clean
