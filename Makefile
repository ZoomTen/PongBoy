.PHONY: all book game

MAKE ?= make
DIR := docs
BOOKDIR := $(DIR)/_book

CHAPTERS := \
	part1.md \
	part2.md \
	part3.md \
	part4.md \
	part5.md \
	part6.md


all: game

book: PongBoy_contents.md $(shell find -name '*.md')
	srcweave -w $(BOOKDIR) -t $(DIR) \
	--formatter srcweave-format $^

game: book
	cd $(DIR)/src; $(MAKE)
	cd $(DIR)/src; $(MAKE) tidy
	cd $(DIR); zip -r _book/pong-src.zip src

clean:
	rm -fv $(DIR)/_book/*.html
	if [ -f $(DIR)/src/Makefile ]; then cd $(DIR)/src; $(MAKE) clean; fi
	rm -rfv $(DIR)/src/*.asm $(DIR)/src/Makefile $(DIR)/src/include
