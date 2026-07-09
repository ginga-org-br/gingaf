.PHONY: test deps download-puc-examples

deps:
	$(MAKE) -C ncl_doc deps
	$(MAKE) -C ginga deps
	$(MAKE) -C playground deps

test:
	$(MAKE) -C ncl_doc test
	$(MAKE) -C ginga test
	$(MAKE) -C playground test