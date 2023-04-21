.PHONY: all book game

MAKE ?= make
LIT ?= lit
DIR := docs

all: game

book: _index.lit $(shell find -name '*.lit')
	lit -odir $(DIR) $<

game: book
	cd $(DIR)/src; $(MAKE) -f Makefile.mk
	cd $(DIR)/src; $(MAKE) -f Makefile.mk tidy
	cd $(DIR); zip -r _book/pong-src.zip src

clean:
	rm -rfv $(DIR)/_book
	if [ -f $(DIR)/src/Makefile.mk ]; then cd $(DIR)/src; $(MAKE) -f Makefile.mk clean; fi
	rm -rfv $(DIR)/src/*.asm $(DIR)/src/Makefile.mk $(DIR)/src/include
