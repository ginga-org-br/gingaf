.PHONY: test setup download-puc-examples

setup:
	$(MAKE) -C ncl_doc setup
	$(MAKE) -C ginga setup
	$(MAKE) -C playground setup

test:
	$(MAKE) -C ncl_doc test
	$(MAKE) -C ginga test
	$(MAKE) -C playground test