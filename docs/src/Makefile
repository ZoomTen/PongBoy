.PHONY: all tidy clean
ASM := $(ASMDIR)motorz80
ASMFLAGS := -z00 -v
SFC := $(SFCDIR)superfamiconv
LINK := xlink
LINKFLAGS :=
OBJ_FILES := pong.o

GFX_FILES := \
	gfx/game.2bpp \
	gfx/numbers.2bpp \
	gfx/title-screen.2bpp \
	gfx/title-screen.map
ROM_NAME := pong
$(ROM_NAME).gb: $(GFX_FILES) $(OBJ_FILES) include/*
	$(LINK) $(LINKFLAGS) -fngb -cngb -m$(ROM_NAME).sym -o$@ $(OBJ_FILES)
%.o: %.asm
	$(ASM) $(ASMFLAGS) -mcg -o$@ $<
%.2bpp: %.png
	$(SFC) tiles -M gb -R -i $< -d $@
%.map: %.png
	$(SFC) -M gb -i $< -m $@
all: $(ROM_NAME).gb
tidy:
	rm -fv $(OBJ_FILES) $(GFX_FILES) *.sym *.sav

clean: tidy
	rm -fv *.gb
