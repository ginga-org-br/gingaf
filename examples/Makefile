MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help

.PHONY: help deps gifs

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps          Check dependencies for GIF generation (ffmpeg, flutter, dart)" \
		"  gifs          Generate GIFs (e.g. make gifs [target=video.ncl], default all)"

deps:
ifeq ($(OS),Windows_NT)
	where ffmpeg >nul 2>nul || (echo "ffmpeg not found" && exit 1)
	where flutter >nul 2>nul || (echo "flutter not found" && exit 1)
else
	which ffmpeg >/dev/null 2>&1 || (echo "ffmpeg not found" && exit 1)
	which flutter >/dev/null 2>&1 || (echo "flutter not found" && exit 1)
endif

gifs: deps
	dart run scripts/generate_gif.dart $(target)
