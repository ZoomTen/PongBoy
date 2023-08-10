@title Initialization

# Initialization

This is the very first thing that's executed once the Game Boy reaches my program, so I'll want to have the Game Boy in a predictable state after booting up. This is done through the initialization process.

--- Initialization code
Init::
@{Disable interrupts}
@{Save the Game Boy type}
@{Turn off the screen}
@{Clear RAM and place the stack pointer}
@{Reset audio}
@{Reset the screen}
@{Copy HRAM DMA code}

@{Set up the game graphics}
@{Set up sprites and variables}

@{Turn on screen}
@{Enable the interrupts again}
---

## First steps

I'll disable interrupts throughout the initialization process to ensure nothing.. er, "interrupts" me trying to reset the Game Boy state.

--- Disable interrupts
	di
---

Right after the boot ROM hands over control to my program, the A register contains [different values](https://gbdev.io/pandocs/Power_Up_Sequence.html#cpu-registers) depending on which Game Boy (or rather, which boot ROM) is used. In case I want to have console-specific features in the future (for example, palettes or extended graphics on Game Boy Color), I'll store this to a variable.

I'll place this variable in HRAM:

--- HRAM definitions
hGBType:: db
---

`db` is "define byte", used here as a shortcut for `ds 1`. `ds` itself (as you'll see in a bit) is&mdash;I think&mdash; "define space", basically a static allocation of some number of bytes. 

<aside>
`db`, when used in ROM, can be used to write raw data. e.g. `db 1, 2, $40` will write the bytes `01 02 40` literally into ROM. In RAM, it's equivalent to `ds 1`.
</aside>

And let this be the first thing done:

--- Save the Game Boy type
	ldh [hGBType], a
---

## Setting up RAM and stack

--- Clear RAM and place the stack pointer
@{Clearing WRAM}
@{Set up SP}
@{Clearing HRAM}
---

### WRAM

I'll clear WRAM by setting it to all zeroes.  This uses [FillMem16](part1.html#s0:7), which I defined earlier.

I pointed HL to the start of WRAM, BC to the size of WRAM (simply subtract the start of WRAM from the start of Echo RAM), and A to 0.

Ordinarily `ld a, 0` can be used to zero out `a`. But `xor a, a` (or simply `xor a`) has the same effect and is faster. It performs an exclusive OR between `a` and itself, resulting in 0 and stores the result back in `a`. Since the result is 0, it sets the Z flag&mdash;but I don't care about that right now.

--- Clearing WRAM
	xor a
	ld hl, WRAM_START
	ld bc, ECHO_START - WRAM_START
	call FillMem16
---

### HRAM

Next, I clear out HRAM. I'll use [FillMem8](helpers.html#6:2) here, since the clearing range is quite small. It's the same as `FillMem16`, except the range is 8 bits, and set in C. I don't need to set A again, since that remains zero.

I clear out one byte into HRAM, since the first byte is already occupied by the saved GB type.

--- Clearing HRAM
	ld hl, hGBType + 1
	ld c, $ffff - (hGBType - 1)
	call FillMem8
---

### SP

SP is the **s**tack **p**ointer. It points to an area in memory where registers are saved to and loaded from as the `push` and `pop` instructions are executed. As mentioned previously, it's first-in-last-out, just like a stack of plates. When pushed to, the register is stored where SP is, and SP decrements by two. The opposite happens when popped from: the register is retrieved from where SP was (without clearing it), and SP increments by two.

At boot up, the top of the stack is initialized to `$FFFE`. With this value, this cuts into HRAM space. I want to set the stack pointer somewhere in WRAM to give it some extra breathing space. [WRAM clearing](#8.1:2) uses the stack earlier (`call` is effectively `push pc`, conversely, `ret` being `pop pc`), which is why I did that first.

I define the reserved space in WRAM:

--- WRAM definitions
wStack:: ds $100 - 1
wStackTop:: db
---

Then set it in our init routine:

--- Set up SP
	ld sp, wStackTop
---

Now why would the stack be `$100` bytes long? Admittedly this is quite arbitrary, but there's a possibly good reason which you'll [see later](#8.1:8).

## Clearing the screen

### Turning off the screen

Before I can do anything with the screen, I should disable it to ensure that I'm not changing it while it's being accessed. Updating the screen *can* be done while it's on, but since I'm in an init function, it's better to just disable the screen.

I define a helper function `DisableLCD` here. All it does is wait for the current scanline number to be rendered to be out of bounds (waiting for line 145 to be hit), at which point the Game Boy will enter VBlank. After that, it's safe to disable the LCD controller, which I then do.

This waiting has to be done because disabling the LCD outside of VBlank [may damage real hardware](https://gbdev.io/pandocs/LCDC.html#lcdc7--lcd-enable).

--- DisableLCD
;;--
;; Turns off the screen
;;
;; @return [rLCDC] ~= LCD_ENABLE_BIT
;;--
DisableLCD::
.wait
	ld a, [rLY]
	cp LY_VBLANK
	jr nc, .disable ; >= LY_VBLANK? jump if yes
	jr .wait        ; otherwise keep waiting
.disable
	ld a, [rLCDC]
	res LCD_ENABLE_BIT, a ; disable LCD
	ld [rLCDC], a
	ret
---

--- Helper functions +=
@{DisableLCD}
---

I then call it from the initialization routine.

--- Turn off the screen
	call DisableLCD
---

### Reset the screen

I clear the entirety of VRAM and reset every scroll register. At this point, A = 0.

--- Reset the screen
; zero out VRAM
	ld hl, VRAM_START
	ld bc, SRAM_START - VRAM_START
	call FillMem16

; reset scroll registers
	ldh [rSCX], a
	ldh [rSCY], a
---

I scroll the window down off-screen initially.

--- Reset the screen +=
; scroll the window register out
	ld a, LY_VBLANK
	ldh [rWY], a
	ld a, 7
	ldh [rWX], a
---

And I reset all [monochrome palettes](https://gbdev.io/pandocs/Palettes.html#ff47--bgp-non-cgb-mode-only-bg-palette-data) used by the Game Boy. The Game Boy follows a sort of reverse-format for palettes, and is an 8-bit value with the shades being 2 bits each. The normal palette as defined in binary is `11 10 01 00` (black, dark gray, light gray, white), which I'll use to set all 3 palettes used by the Game Boy.

--- Reset the screen +=
	ld a, %11100100
	ldh [rBGP], a  ; background
	ldh [rOBP0], a ; object palette 0
	ldh [rOBP1], a ; object palette 1
---

## Reset audio

I'll kill the audio circuitry by zeroing out `NR52`. This has the [bonus effect](https://gbdev.io/pandocs/Audio_Registers.html#ff26--nr52-sound-onoff) of *also* zeroing out all the audio registers. A is still 0 at this point.

--- Reset audio
	ldh [rNR52], a
---

## Copy DMA code

This is needed for manipulating sprites, since it's not possible to manipulate OAM directly. Instead, let the Game Boy itself do it though a DMA transfer from RAM to OAM. During this time, the CPU cannot access anything other than HRAM, so to ensure the CPU can go back to the ROM safely, I need to place this code *inside* HRAM, and run it from there.

This also means that I need to make room for a "virtual OAM" inside of WRAM. This is what I'll update from within the program, instead of using the OAM memory region directly.

--- WRAM definitions +=
wVirtualOAM:: ds 4*MAX_SPRITES
---

<aside>
Compiler quirks mean there's to be no spaces between operands here, while they seem to be accepted inside of instructions. It's weird, I know.
</aside>

Let's define `MAX_SPRITES` to make the code a bit more obvious:

--- /src/include/constants.inc +=
MAX_SPRITES equ 40
---

With that, I can write the code that needs to be copied. Note that all this code does is wait until the DMA finishes doing its thing.

--- DMARoutine
DMARoutine::
	ld a, wVirtualOAM // $1000000 ; HIGH(wVirtualOAM)
	ldh [rDMA], a
	ld a, MAX_SPRITES ; wait 4 * MAX_SPRITES cycles 
.loop
	dec a        ; 1 cycle
	jr nz, .loop ; 3 cycles
	ret
DMARoutine_END::
---
--- Helper functions +=
@{DMARoutine}
---

<aside>
Yeah... <code>wVirtualOAM // $1000000</code>? My fault for using ASMotor, I guess lol. (That, or there's a better way that I've not yet discovered.)
</aside>

I reserve some space in HRAM for the code:

--- HRAM definitions +=
hDMACode:: ds 10
---

Then the DMA code is copied there. This time, I'm not using the helper functions, since I want to make use of this particular instruction: `ld [$ff00+c], a`.

--- Copy HRAM DMA code
	ld hl, DMARoutine
	ld b, DMARoutine_END - DMARoutine
	ld c, hDMACode ~/ $ff ; LOW(hDMACode)
.copy_code
	ld a, [hl+]
	ld [$ff00+c], a
	inc c
	dec b
	jr nz, .copy_code
---

Because of the nature of `rDMA`, I have to ensure that `wVirtualOAM`'s *location* is a multiple of `$100`. `wStack` ([as you saw earlier](#8.1:3)) comes before it, and the rather arbitrary size of `$100` happens to fit nicely with this requirement.

Now where would this code be run... how about once every frame? I can use the VBlank interrupt to call the code from the allocated space in HRAM:

--- Contents of VBlank
	call hDMACode
---

## Set up the game graphics

Next up, I'll copy the graphics to VRAM, starting with the actual tiles, and then setting up the background.

--- Set up the game graphics
@{Copy over the main tileset}
@{Copy over the score numeral tileset}
@{Copy over the background tile map}
---

### Load main tileset

The main tileset in use is, well, plain Pong graphics. For this game I'm going with a sort of 3D type look. These graphics will be used for the objects as well as the background.

<figure>
<img class="pixelated" alt="Game graphics" src="../src/gfx/game.png">
<figcaption>Game graphics</figcaption>
</figure>

I'll include the data here. The .2bpp file will be automatically generated from the .png file when built.

--- Miscellaneous data
PongGFX::
	incbin "gfx/game.2bpp"
PongGFX_END::
---

(Also notice the use of `incbin` instead of `include`. As it says, it inserts a binary file straight into the ROM, instead of trying to compile the file as source code&mdash;which is what `include` does.)

And then load it into VRAM&mdash;specifically, the first tileset slot&mdash;with the [CopyMem16](helpers.html#6:5) helper function. At this point, the screen is still off, so I'm safe to do it like a regular memory copy.

--- Copy over the main tileset
	ld hl, vChars0
	ld de, PongGFX
	ld bc, PongGFX_END - PongGFX
	call CopyMem16
---

### Loading numerals

Then, these numerals, which will be used for the score display. They're 8x16 blocks with the upper half stored first and then the lower half. They'll be used to print the score to the background.

<figure>
<img class="pixelated" alt="Score numerals" src="../src/gfx/numbers.png">
<figcaption>Score numerals</figcaption>
</figure>

I'll include it just like the Pong graphics:

--- Miscellaneous data +=
NumbersGFX::
	incbin "gfx/numbers.2bpp"
NumbersGFX_END::
---

And then load them up similarly, only such that it starts at tile $10.

--- Copy over the score numeral tileset
	ld hl, vChars0 + $100
	ld de, NumbersGFX
	ld bc, NumbersGFX_END - NumbersGFX
	call CopyMem16
---

There's a little compiler trick i can use here. Instead of `$100`, I can just say how many tiles to offset it with. To do that, I first define this:

--- Constants
tiles equs "* $10"
---

What this does is make it so that the statement `6 tiles` in the code turns into `6 * $10`. The `$10` is how big one tile's worth of graphics are in VRAM.

So now, I can write this instead:

--- Copy over the score numeral tileset :=
	ld hl, vChars0 + $10 tiles
	ld de, NumbersGFX
	ld bc, NumbersGFX_END - NumbersGFX
	call CopyMem16
---

### Load the background

The background will use the main tileset, so I'll incbin the tile map.

--- Miscellaneous data +=
BackgroundMAP::
	incbin "gfx/background.map"
BackgroundMAP_END::
---

I'm not doing anything fancy (or optimized) here, it's just a straight-up copy to the first background map slot.

--- Copy over the background tile map
	ld hl, vBGMap0
	ld de, BackgroundMAP
	ld bc, BackgroundMAP_END - BackgroundMAP
	call CopyMem16
---

### A look at VRAM

After this is done, here's what the tileset in VRAM will look like:

<figure>
<img src="../figures/vram1.svg">
</figure>

The Pong graphics start at tile `$00` through `$09`, while the numerals start at `$10`, being split as the upper half (`$10`&ndash;`$19`) and the lower half (`$1A`&ndash;`$22`)

## Initializing variables

I'll define the variables that I think a typical Pong game can have. Here I assume that the paddles will not be able to move left and right&mdash;only up and down. So I'll store only the Y position of both paddles.

--- WRAM definitions +=
; paddle position
wLeftPaddleY:: db
wRightPaddleY:: db
---

Every Pong clone since about 1975 has got to have its own scorekeeping system, so I'll prepare those, too.

--- WRAM definitions +=
; score
wLeftScore:: db
wRightScore:: db
---

Then the position of the ball, for the physics and stuff.

--- WRAM definitions +=
; ball position
wBallX:: db
wBallY:: db
---

And then I'll fill all of them in... except the score, obviously. The paddles will have the same starting position, so I can use one constant for both.

--- Constants +=
PADDLES_STARTING_Y equ $40
BALL_STARTING_X equ $54
BALL_STARTING_Y equ $50
---

--- Set up sprites and variables
	ld a, PADDLES_STARTING_Y
	ld [wLeftPaddleY], a
	ld [wRightPaddleY], a
	
	ld a, BALL_STARTING_X
	ld [wBallX], a
	
	ld a, BALL_STARTING_Y
	ld [wBallY], a
---

Next I'll place the objects on the screen, which I'll get to shortly.

--- Set up sprites and variables +=
	call SetupLeftPaddle
	call SetupRightPaddle
	call SetupBall
---

## Setting up sprites

I'm using a fixed allocation system for my sprites: 5 sprites each for the paddles and 1 sprite for the ball. So 11 sprites in total, all of them 8&times;8 sprites. Here's how it'll be laid out:

<figure>
<img src="../figures/vram2.svg">
</figure>

Given a starting Y position, the individual paddle sprites will be offset to the bottom by 8 pixels each (from the sprite above it) so as to form the complete paddle, while the ball stands on its own and can be moved freely.

### Initializing the left paddle

To make things a little easier, let's have a shortcut to add sprites. It just places whatever is in A, B, C, D to the address pointed to by HL.

--- AddSprite
;;--
;; Uses A, B, C, D to write to OAM.
;; 
;; @param HL   sprite starting position
;; @param A    sprite's Y position
;; @param B    sprite's X position
;; @param C    sprite's tile
;; @param D    sprite's flags
;;--
AddSprite::
	ld [hl+], a
	ld [hl], b
	inc hl
	ld [hl], c
	inc hl
	ld [hl], d
	inc hl
	ret
---

First up, something to put the left paddle sprite on screen. The left paddle will occupy sprite slots 0&ndash;4, so its starting slot is 0.

--- Constants +=
SPRITE_SLOT_LEFT_PADDLE equ 0
---

I want some space between the left side of the screen and the left paddle, just to make things nicer to look at. So here's the starting X position.

--- Constants +=
LEFT_PADDLE_X equ 16
---

The compiler trick explained previously, but this time I'm using it to say which sprite slot I want to start in.

--- Constants +=
sprite equs "+ 4*"
---

You can see it in action here, where `wVirtualOAM sprite SPRITE_SLOT_LEFT_PADDLE` really just compiles to `wVirtualOAM + 4*0`.

--- SetupLeftPaddle
SetupLeftPaddle::
	ld hl, wVirtualOAM sprite SPRITE_SLOT_LEFT_PADDLE
	ld d, 0  ; flags
	ld b, LEFT_PADDLE_X  ; X position
	ld c, 8  ; tile (top of paddle)
---

As established earlier, I can't put sprites directly into OAM memory, which is why `wVirtualOAM` is used instead.

I'll set up the first sprite of the paddle...

--- SetupLeftPaddle +=
; first sprite
	ld a, [wLeftPaddleY]
	call AddSprite
---

Then the next sprites will be added downwards of 8 pixels at a time.

--- SetupLeftPaddle +=
; second sprite
	ld c, 1  ; set tile to the mid-paddle one
	add a, 8
	call AddSprite

; third sprite
	add a, 8
	call AddSprite

; fourth sprite
	add a, 8
	call AddSprite

; final sprite
	ld c, 9  ; bottom of paddle
	add a, 8
---

Finally, I use `jp` here. It's better to use it than having a `call` then a `ret`, since this is a subroutine called from somewhere else.

--- SetupLeftPaddle +=
; fall through
	jp AddSprite
---

### Initializing the right paddle

Same as before, but the right paddle will occupy sprite slots 5&ndash;9.

--- Constants +=
SPRITE_SLOT_RIGHT_PADDLE equ 5
---

I'll set this to 8 pixels away from the right edge of the screen.

--- Constants +=
RIGHT_PADDLE_X equ 160-8
---

And then the similar-looking code.

--- SetupRightPaddle
SetupRightPaddle::
	ld hl, wVirtualOAM sprite SPRITE_SLOT_RIGHT_PADDLE
	ld d, 0  ; flags
	ld b, RIGHT_PADDLE_X  ; X position
	ld c, 8  ; tile
; first sprite
	ld a, [wRightPaddleY]
	call AddSprite
; second sprite
	ld c, 1
	add a, 8
	call AddSprite
; third sprite
	add a, 8
	call AddSprite
; fourth sprite
	add a, 8
	call AddSprite
; fifth sprite
	ld c, 9
	add a, 8
; fall through
	jp AddSprite
---

### Initializing the ball

The ball will occupy sprite slot 10. Since the ball is only one sprite, this is a simpler subroutine.

--- Constants +=
SPRITE_SLOT_BALL equ 10
---

Basically just a call to AddSprite, nothing more.

--- SetupBall
SetupBall::
	ld hl, wVirtualOAM sprite SPRITE_SLOT_BALL
	ld a, [wBallX]
	ld b, a
	ld a, [wBallY]
	ld c, 2
	ld d, 0
	jp AddSprite
---

### Add functions to ROM

Let's add the helpers I defined here...

--- Helper functions +=
@{AddSprite}
@{SetupLeftPaddle}
@{SetupRightPaddle}
@{SetupBall}
---

## Finishing up initialization

### Turning on the screen

Finally, I'll turn on the screen, since I'm just about done loading everything. I'll define `EnableLCD` to have a sort of "preset" for the entire game.

I chose to have the tileset at `$8000` and the tilemap at `$9800`.

--- EnableLCD
EnableLCD::
	ld a, LCD_ENABLE | LCD_SET_8000 | LCD_MAP_9800 | LCD_OBJ_NORM | LCD_OBJ_ENABLE | LCD_BG_ENABLE
	ldh [rLCDC], a
	ret
---
--- Helper functions +=
@{EnableLCD}
---

Then it's one `call` away.

--- Turn on screen
	call EnableLCD
---

### Enabling interrupts

Here I enable interrupts, but choosing specifically which interrupt to enable. In this case, only the VBlank interrupt.

--- Enable the interrupts again
; set the interrupt to enable
	ld a, 1 << VBLANK
	ldh [rIE], a

; enable them
	ei
---
