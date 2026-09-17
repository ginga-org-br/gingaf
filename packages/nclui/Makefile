MAKEFLAGS += -s --no-print-directory

.PHONY: help test deps doc clean

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps   Install Flutter dependencies" \
		"  test   Run Flutter tests" \
		"  doc    Generate Dart documentation" \
		"  clean  Clean Flutter build artifacts"

deps:
	flutter pub get

test:
	flutter test

doc:
	dart doc

clean:
	flutter clean
	rm -rf doc/api
