.PHONY: test deps


deps:
	$(MAKE) -C ncl_doc deps
	$(MAKE) -C ginga deps
	$(MAKE) -C ginga-playground deps

test:
	$(MAKE) -C ncl_doc test
	$(MAKE) -C ginga test
	$(MAKE) -C ginga-playground test