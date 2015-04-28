all:

WGET = wget
CURL = curl
GIT = git
PERL = ./perl

updatenightly: local/bin/pmbp.pl
	$(CURL) -s -S -L https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	$(GIT) add modules t_deps/modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config

## ------ Setup ------

deps: always
	true
ifdef PMBP_HEROKU_BUILDPACK
else
	$(MAKE) git-submodules
endif
	$(MAKE) pmbp-install
	$(MAKE) data

git-submodules:
	$(GIT) submodule update --init

PMBP_OPTIONS=

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(CURL) -s -S -L https://raw.githubusercontent.com/wakaba/perl-setupenv/master/bin/pmbp.pl > $@
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --install

## ------ Data files ------

data: data/langs.json local/plural-list.json

data/langs.json: bin/create-langs.pl local/locale-names.json
	$(PERL) bin/create-langs.pl > $@

local/plural-list.json: local/plurals.json

local/locale-names.json:
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-locale/master/data/langs/locale-names.json
local/plurals.json:
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-locale/master/data/langs/plurals.json

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main:
	$(PROVE) t/local-http/*.t

always:
