@title Introduction and setup

# Introduction and setup

## Some prerequisites

In order to build this game, I assume you have the following (A Unix-like shell is preferred):

* [GNU Make](https://www.gnu.org/software/make/)
* [ASMotor](https://github.com/asmotor/asmotor)
* [SuperFamiConv](https://github.com/Optiroc/SuperFamiconv)

All of those should be accessible from your terminal, they are required to build the source code that's being explained here.

The source code (and ROM) can be obtained as a [zip file](pong-src.zip), for convenience.

### Assumptions

Since these are what the assembler uses:
- Hexadecimal numbers are prefixed with `$`, e.g. `$7f`.
- Binary numbers are prefixed with `%`, e.g. `%1010`.

The terms "game" and "program" will probably be used interchangeably. Likewise between the terms "function", "routine", and "subroutine".

"Sections" are used to organize the program. The linker uses these as a guide to place code and data. I can use this to specify manually that a piece of code should reside in a specific bank (or a location), but for this write-up I decided to place everything in bank 0, also known as the home bank (because it's always accessible by the Game Boy).

I'll refer registers (8-bit and 16-bit) in uppercase, e.g. A, B, C, HL, DE, etc.

<pre>
; place everything below the section line at bank 0 ("home").
	section "code", HOME
</pre>

Labels are suffixed with `::` so that they may be exported automatically. It's probably a quirk of the assembler, but unless labels are exported, I find that they won't appear in the .map file (which is readable as a .sym file by emulators like BGB and Emulicious, useful for debugging).

The syntax highlighting in this write-up won't be helpful, and I don't feel like hacking the script further to include a syntax highlighter for Game Boy ASM... colors are pretty though.

## Code layout

### Files and directories

My source code layout is quite minimal for this tutorial (`./` is the source directory):

* `./pong.asm` - All the game logic resides in this file.
* `./include/*` - Anything that can be included from `pong.asm`.
* `./gfx/*` - Graphics data, including generated files.
* No dedicated object file folder or generated ROM folder is considered for now.

For the exact steps being taken to build the ROM, see [the Makefile](part6.html#s6:0).

### ROM code

Now I'll start writing `pong.asm`. First, I'll want to define the constants, macros, and variables (allocated to memory) since the source is read from top to bottom. I'll reserve these sections and then add to them as I go.

The first $4000 bytes of the Game Boy ROM are mapped, appropriately, to the first $4000 bytes of the Game Boy's memory. If you take a look at [the memory map](https://gbdev.io/pandocs/Memory_Map.html#jump-vectors-in-first-rom-bank), early on you'll find what's called "jump vectors". In short, they're basically what is called by an `rst` instruction, as well as any interrupt, should they be enabled. Because they're placed as the first thing in memory, I have to place these at the start of the ROM as well.

After the jump vectors, there's a bit of unused space up to `$00FF` that I may use for other purpose as I see fit. Let's call this "high HOME" since it's a small area of the HOME bank before the header. For now, I'll leave this unused by placing nothing in it.  Following *that* is the entry point, cartridge header, the main program, and finally anything else the game might require (such as graphics).

--- /src/pong.asm
@{Constants includes}
@{Memory definitions}
@{Jump vectors}

	section "high_home", HOME[$68]
; not used
	
	section "entry", HOME[$100]
@{Entry point}

	section "header", HOME[$134]
@{Header}

	section "program", HOME[$150]
@{Main program}

	section "data", DATA
@{Miscellaneous data}
---

## Setup constants and variables

I'll start by defining some basic constants here. I first include the [hardware constants file](part6.html#s6:1), and then my custom constants.

--- Constants includes
	include "include/hardware.inc"
	include "include/constants.inc"
---

The compiler will replace these lines with the actual contents of whatever file I'm including as if it's part of the main source code, so that they will get compiled with the rest of the code.
</aside>

### Basic constants

For now, I'll just place the start of some significant memory addresses in my `constants.inc`.

--- /src/include/constants.inc
VRAM_START equ $8000
SRAM_START equ $a000
WRAM_START equ $c000
ECHO_START equ $e000
HRAM_START equ $ff80
---

`VRAM_START equ $8000` makes it so I can just type in `VRAM_START` instead of the literal number `$8000` every time I want to use it in code. This makes the code a bit more readable and also if I ever need to change it, this can be the only place to do so (and then it's reflected on the entire program)

### Game constants

Next up, constants used by the game. I can fill this out later.

--- /src/include/constants.inc +=
; Game constants
@{Constants}
---

## Memory definitions

The memory definitions will be in yet another separate include file.

--- Memory definitions
	include "include/ram.inc"
---

I'll define variables to put in both WRAM and HRAM here.

WRAM ("work RAM") is the 8K section of memory where most of the game-related variables live. It starts at address `$C000` in the Game Boy's memory, so that's where I'll specify where it begins.

(`BSS` here is the predefined section type for a memory allocation)

HRAM ("high RAM") is limited to 127 bytes, and is where I'll put any variables that need to be accessed quickly. It starts at `$FF80` in the Game Boy's memory.

There are instructions specifically for manipulating the memory between `$FF00` and `$FFFF`, and these take less space and cycles than if we were to use the regular equivalents&mdash;thus there's an opportunity for optimization there.

--- /src/include/ram.inc
	section "wram", BSS[$c000]
@{WRAM definitions}

	section "hram", HRAM
@{HRAM definitions}
---

## Hardware jump vectors

As is explained before, the jump vectors consist of `rst` jump vectors and interrupt jump vectors:

--- Jump vectors
@{Rst vectors}
@{Interrupt vectors}
---

### Rst jump points

First, the jump points for the `rst` instructions.

--- Rst vectors
	section "rst00", HOME[0]
	@{Rst00 vector}
	
	section "rst08", HOME[8]
	@{Rst08 vector}
	
	section "rst10", HOME[$10]
	@{Rst10 vector}
	
	section "rst18", HOME[$18]
	@{Rst18 vector}
	
	section "rst20", HOME[$20]
	@{Rst20 vector}
	
	section "rst28", HOME[$28]
	@{Rst28 vector}
	
	section "rst30", HOME[$30]
	@{Rst30 vector}
	
	section "rst38", HOME[$38]
	@{Rst38 vector}
---

For now, I'll leave them unused.

When the `rst` instruction is invoked, it'll actually do a `call`, so I'll place a `ret` instruction on these to make it immediately go back to wherever it's called from.

--- Rst00 vector
ret
---

--- Rst08 vector
ret
---

--- Rst10 vector
ret
---

--- Rst18 vector
ret
---

--- Rst20 vector
ret
---

--- Rst28 vector
ret
---

--- Rst30 vector
ret
---

--- Rst38 vector
ret
---

### Interrupt jump routines

Then, the interrupt vectors.

--- Interrupt vectors
	section "int_vblank", HOME[$40]
	@{VBlank interrupt vector}
	
	section "int_hblank", HOME[$48]
	@{HBlank interrupt vector}
	
	section "int_timer", HOME[$50]
	@{Timer interrupt vector}
	
	section "int_serial", HOME[$58]
	@{Serial interrupt vector}
	
	section "int_joypad", HOME[$60]
	@{Joypad interrupt vector}
---

I'll blank these out for now, as well. This time, I use `reti` to acknowledge that I'm returning from an interrupt call.

--- VBlank interrupt vector
reti
---

--- HBlank interrupt vector
reti
---

--- Timer interrupt vector
reti
---

--- Serial interrupt vector
reti
---

--- Joypad interrupt vector
reti
---

## Entry point and header

When the Game Boy is powered on, it loads the cartridge along with a 256 byte boot ROM that shows the Nintendo logo and plays the bootup sound. After the sequence finishes, it will instantly jump to address `$100`, which at this point it hands over control to my program.

There's not much room available here, because the header starts at address `$104`. So, I'll just do a jump to the *actual* initialization routine.

--- Entry point
	jp Init
---

Next up is the Nintendo logo bitmap. The boot ROM checks this bitmap, and will lock up the Game Boy if it does not match. Fortunately, the linker will handle this automatically, so I don't need to include this data myself.

Right after *that*, I define the cartridge header. You can think of this as "metadata" about the game and the kind of cartridge it should be burned into. [Here](https://gbdev.io/pandocs/The_Cartridge_Header.html#the-cartridge-header) is where you can find more information about its fields.

There are two checksums in the header, the header checksum and the global checksum, out of which the boot ROM will only check the former. The linker will handle both of these as well, so I simply set these to 0 here.

--- Header
	db "PONG FOR REAL  " ; game title
	db $00 ; cgb enabled ("no")
	db "ZD" ; new licensee code
	db $00 ; sgb enabled ("no")
	db $00 ; cart type ("ROM")
	db $00 ; rom size ("32k")
	db $00 ; ram size ("none")
	db $01 ; destination ("international")
	db $33 ; old licensee code ("use new instead")
	db $00 ; rom version
	db 0   ; header chksum, handled by linker
	dw 0   ; global chksum, handled by linker
---

## Main program layout

After the header, I can now get to work on the actual game. The code will start at address `$150`. 
First, it'll run the initialization code. The game loop can start immediately after initialization. Afterwards, I'll place the helper functions. Those can actually be placed anywhere, but I want to place them after the "main" routines.

--- Main program
@{Initialization code}
@{Game loop code}
@{Helper functions}
---

## Basic helper functions

### FillMem16

I'll first define a couple of generic memory-filling functions here.

This one operates on a 16-bit length. It puts the value of A to the memory address pointed to by HL, increments HL, then repeats until the desired length is reached.

--- FillMem16
;;--
;; Fill memory with HL continuously with A
;; for BC bytes
;;
;; @param A    value for fill
;; @param HL   start address
;; @param BC   how many bytes
;;
;; @return A   same
;; @return HL  HL + BC + 1
;; @return BC  0000
;;--
FillMem16::
	dec bc
	inc b
	inc c
.loop
	ld [hl+], a
	dec c
	jr nz, .loop
	dec b
	ret z
	jr .loop
---

To use this function, I'll need to first set up its parameters by loading the appropriate registers with the correct values. Then I simply `call FillMem16`.

<pre>
	ld a, 0
	ld hl, StartAddress
	ld bc, $1000
	call FillMem16
</pre>

I'll add it to the list of helper functions.

--- Helper functions
@{FillMem16}
---

### FillMem8

This one is the same as above, but operates on an 8-bit length instead. Instead of BC, this one uses only the C register.

--- FillMem8
;;--
;; Fill memory with HL with A continuously for
;; C bytes
;;
;; @param A    value for fill
;; @param HL   start address
;; @param C    how many bytes
;;
;; @return A   same
;; @return HL  HL + C + 1
;; @return C   0
;;--
FillMem8::
.loop
	ld [hl+], a
	dec c
	jr nz, .loop
	ret
---

Adding this one too.

--- Helper functions +=
@{FillMem8}
---

Next up is the memory copying functions...

### CopyMem16

Not only HL can be used for indirect memory addressing. BC and DE can be used as well. Although I can't also decrement and increment in one go&mdash;that would still need to be done through separate instructions.

--- CopyMem16
;;--
;; Copies a portion of memory from DE to HL for
;; BC bytes.
;;
;; @param HL   destination start address
;; @param DE   source start address
;; @param BC   how many bytes
;;
;; @return A   Byte in (DE + BC)
;; @return HL  HL + BC + 1
;; @return BC  0000
;;--
CopyMem16::
	dec bc
	inc b
	inc c
.loop
	ld a, [de]
	inc de
	ld [hl+], a
	dec c
	jr nz, .loop
	dec b
	ret z
	jr .loop
---

--- Helper functions +=
@{CopyMem16}
---

## VBlank

The vertical blank (VBlank) is a period of time where the Game Boy stops rendering the screen, because the [scanline number set to be rendered](https://gbdev.io/pandocs/STAT.html#ff44--ly-lcd-y-coordinate-read-only) exceeds the height of the screen (144 lines). As execution goes on, the scanline number will keep incrementing until it reaches 153, after which loops back to zero, when the Game Boy will render the first scanline again.

<figure>
<img src="../figures/vblank.svg">
</figure>

Since the Game Boy isn't rendering the screen at this point, it's one of the safest places to do whatever I want relating to the screen&mdash;say, loading graphics or changing the background data. But as you can probably see, the catch is that there's not a whole lot of time available, so it's best not to stuff it with *everything*. In any case, I'll reserve it for now:

--- VBlank interrupt routine
VBlank::
@{Save registers state}
@{Contents of VBlank}
@{Reload registers state}
	reti
---

### Preserving the register state

Because this is an interrupt routine, it can be triggered in the middle of program execution. To ensure the program can continue without unintended effects, I'll save the state of the current 16-bit register pairs to the Game Boy's stack through a few `push` instructions:

--- Save registers state
	push af
	push bc
	push de
	push hl
---

<figure>
<img src="../figures/stack.svg">
</figure>

At the end of the routine, I'll have to reload them by `pop`ping them back in. Because it's a first-in-last-out stack, the registers need to be reloaded in **reverse** order.

--- Reload registers state
	pop hl
	pop de
	pop bc
	pop af
----

If the same ordering is used as the one to save registers, then HL would end up in AF, DE would end up in BC, etc.

(I should point out at this point that F isn't an actual register&mdash;it's just paired with A for the `push af` instruction.)

### Adding it to the ROM

I'll add this in the "helper functions" slot, I guess.

--- Helper functions +=
@{VBlank interrupt routine}
---

### Setting the interrupt vector

All that's needed is just a jump instruction to make the Game Boy execute the routine when VBlank is reached:

--- VBlank interrupt vector :=
jp VBlank
---
