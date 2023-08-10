@title Using game modes

# Using game modes

## Set up for game mode support

So thus far the game loop only accomodates for only one activity: the main game. Maybe other features or screens are to be added, which&mdash;with this kind of setup&mdash;might make a mess out of the codebase.

<figure>
<img src="../figures/boring-flowchart.svg">
</figure>

Many games have a "game mode" (or "game state") pattern for its main loop. Essentially, what this means is that every mode in the game has its own dedicated loop subroutine that processes only the logic relevant to that mode, and it's the main loop's job to execute the correct one for each game mode.

I think it's a good idea to start implementing that now, since I have a working game and thus a known "good" state.

The pattern basically works like this:

--- Game loop code :=
GameLoop::
@{Determine which game mode is to be run and perform initializations}
@{Perform game mode loop}
@{Wait one frame}
	jp GameLoop
---

I'll want to keep track of the current game mode, and also the previous game mode, so that my routine knows when a new one is loaded. Gonna put them in HRAM for quick access.

--- HRAM definitions +=
hGameMode:: db
hOldGameMode:: db
---

Not only would I want every game mode have its own loop routine, but also an initialization routine that runs only when the game mode is switched to. For both, I'll be using a jumptable with the pointers to each routine.

--- Determine which game mode is to be run and perform initializations
	ld hl, hOldGameMode
	ldh a, [hGameMode]
	cp [hl]
	jr z, .skip_init
	
	ld hl, GMInitJumptable
	call GotoJumptableEntry
	
	ldh a, [hGameMode]  ; reload game mode
	ldh [hOldGameMode], a  ; replace old game mode
.skip_init
---

And here's the function that will execute the appropriate routine. The A register determines which entry is to be selected, and HL must be advanced accordingly. Since the jumptable entries are simple pointers, they'll be two bytes each&mdash;so HL + 2 &times; A.

I'll retrieve the value of HL (the entry itself) *from* where HL is pointing to (the address of the entry), and then jump there.

--- GotoJumptableEntry
;;--
;; Go to jumptable entry
;; 
;; @param HL  Jumptable address containing pointers
;; @param A   Entry number
;; @clobber DE
;;--
GotoJumptableEntry::
	ld e, a
	ld d, 0
	add hl, de
	add hl, de
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	jp [hl]
---
--- Helper functions +=
@{GotoJumptableEntry}
---

I'll reserve the init routines jumptable here. (Game mode related stuff have the "GM" prefix, for "Game Mode")

--- Game loop code +=
GMInitJumptable::
@{Pointers to game mode initialization routines}
---

Since I copied `hGameMode` to `hOldGameMode`, A contains `hGameMode`. So, executing the loop is simply:

--- Perform game mode loop
	ld hl, GMLoopJumptable
	call GotoJumptableEntry
---

And the associated jumptable:

--- Game loop code +=
GMLoopJumptable::
@{Pointers to game mode loop routines}
---

Last, I reserve some slots for the actual init and loop routines in the main program code:

--- Main program +=
@{Game mode initialization code}
@{Game mode loop code}
---

## Adapting my code for the new system

Let's adapt the main loop I have now into a "self-contained" game mode. First I'll reserve some constants for the game mode identifier.

--- Constants +=
@{Game mode constants}
---

--- Game mode constants
GM_GAME equ 0
---

Next, I'll move the portion of the existing init code into its own function.

--- GM_Game init code
GM_Game_init::
	call DisableLCD
@{Set up the game graphics}
@{Set up sprites and variables}
	jp EnableLCD
---

--- Game mode initialization code
@{GM_Game init code}
---

Likewise with the existing loop code.

--- GM_Game loop code
GM_Game_loop::
@{Handle joypad input}
@{Handle ball physics}
@{Update screen}
	ret
---

--- Game mode loop code
@{GM_Game loop code}
---

I'll add the addresses of both routines to their respective jumptables.

--- Pointers to game mode initialization routines
	dw GM_Game_init
---

--- Pointers to game mode loop routines
	dw GM_Game_loop
---

### Fix the program init

Next, I'll have to change the initialization routine to use the new system, by setting the initial game mode.

--- Initialization code :=
Init::
@{Disable interrupts}
@{Save the Game Boy type}
@{Turn off the screen}
@{Clear RAM and place the stack pointer}
@{Reset audio}
@{Reset the screen}
@{Copy HRAM DMA code}

; +++
@{Set the initial game mode}
; +++

@{Turn on screen}
@{Enable the interrupts again}
---

I set the initial `hOldGameMode` to force the game to fire the initialization routine.

--- Set the initial game mode
	ld a, $ff
	ldh [hOldGameMode], a
	xor a  ; ld a, GM_GAME
	ldh [hGameMode], a
---

I'll also do this when resetting the game state from the scoring routine.

--- Reset the game state :=
; force a reinitialization
	ld a, $ff
	ldh [hOldGameMode], a
	jp GameLoop
---

After this, the game should look and play identical as before. The changes are really just under-the-hood stuff that'll make it more convenient to me to add more screens to the game.

### Fix score updating

This is kind of a quick hack (out of several quick hacks done so far, really) so that the score doesn't update all the time, only when asked to.

--- WRAM definitions +=
wShouldUpdateScore:: db
---

--- Update the score display :=
; +++
	ld a, [wShouldUpdateScore]
	and a
	jr z, .skip_score_update
; +++

	ld a, [wLeftScore]
	ld hl, LEFT_SCORE_VRAM_START
	call ShowScore
	
	ld a, [wRightScore]
	ld hl, RIGHT_SCORE_VRAM_START
	call ShowScore
; +++
.skip_score_update
; +++
---

And I set it to be enabled when the game first boots up.

--- Set up sprites and variables +=
	ld a, 1
	ld [wShouldUpdateScore], a
---
## Adding a title screen

<figure>
<img src="../figures/game-mode.svg">
</figure>

Well, it's time to use this new system to add a new screen: the title screen. At the moment, it really should just do nothing but say "Press Start", and then kicks you into straight into the game. Although from the player's perspective it comes before the gameplay, internally I'm going to define this mode *after* the gameplay mode.

Because its only job is to show the game's title and wait for joypad input, the code is gonna be really simple:

--- GM_Title init code
GM_Title_init::
	call DisableLCD
@{Set up the title screen graphics}
	jp EnableLCD
---

--- GM_Title loop code
GM_Title_loop::
@{Handle title screen joypad input}
	ret
---

### Initialization

Of course, the initialization is simply just copying the necessary graphics data to VRAM...

--- Set up the title screen graphics
	ld hl, vChars0
	ld de, TitleScreenGFX
	ld bc, TitleScreenGFX_END - TitleScreenGFX
	call CopyMem16
	
	ld hl, vBGMap0
	ld de, TitleScreenMAP
	ld bc, TitleScreenMAP_END - TitleScreenMAP
	call CopyMem16
---

And both the tileset and the tilemap are generated off of a single png...

<figure>
<img class="pixelated" alt="Game graphics" src="../src/gfx/title-screen.png">
<figcaption>Title screen graphics. Yes, I just made an entire 256&times;256 px tile map for only one screenful of graphics, 'cuz I'm just lazy.</figcaption>
</figure>

--- Miscellaneous data +=
TitleScreenGFX::
	incbin "gfx/title-screen.2bpp"
TitleScreenGFX_END::
---

--- Miscellaneous data +=
TitleScreenMAP::
	incbin "gfx/title-screen.map"
TitleScreenMAP_END::
---

### Loop

The loop is just checking whether or not the START button is pressed, with an early `ret` if not:

--- Handle title screen joypad input
	call ReadJoypad
	ldh a, [hInput]
	bit BUTTONF_START, a
	ret z
---

But if it *is* pressed, it'll jump to the game.

--- Handle title screen joypad input +=
	xor a  ; ld a, GM_GAME
	ldh [hGameMode], a
	ret
---

### Adding it to the ROM

Let's add all of the stuff above into the ROM.

--- Game mode initialization code +=
@{GM_Title init code}
---

--- Game mode loop code +=
@{GM_Title loop code}
---

--- Pointers to game mode initialization routines +=
	dw GM_Title_init
---

--- Pointers to game mode loop routines +=
	dw GM_Title_loop
---

## Booting up to the title screen

I'll change the starting game mode here.

--- Game mode constants +=
GM_TITLE equ 1
---

--- Set the initial game mode :=
	ld a, $ff
	ldh [hOldGameMode], a
	ld a, GM_TITLE ; +++
	ldh [hGameMode], a
---


## Fading the screen in and out

I want to add a nice fade in/out effect to the game. Originally I was gonna be fancy and make a "unique" fading routing that switches between phases every frame, but I think I'll just be making a simple one.

The idea here is change the palettes every odd frame or so:

<figure>
<img src="../figures/fade1.svg">
<figcaption>A sensible fading routine</figcaption>
</figure>

I'll want to write a routine to delay C amount of frames, calling `DelayFrame` and decrementing C each time until C is 0.

--- DelayFrames
;;--
;; @param  C  amount of frames to wait
;; @return C  0
;;--
DelayFrames::
.loop
	call DelayFrame
	dec c
	jr nz, .loop
	ret
---
--- Helper functions +=
@{DelayFrames}
---

Next up, a shortcut to apply the palette data and wait 2 frames using the above function. If doing 2 frames, `call DelayFrame; jp DelayFrame` may suffice, but for some reason I want the delay between phases to be configurable.

--- ApplyPaletteWait
;;--
;; Applies palette A and then wait 2 frames.
;; 
;; @param  A  palette data
;;--
ApplyPaletteWait::
	ldh [rBGP], a
	ldh [rOBP0], a
	ldh [rOBP1], a
	ld c, 2 ; frames to wait between phases
	jp DelayFrames
---

Then, the actual routines. I'll just be writing palette data and then a short delay between writes.

--- FadeOut
FadeOut::
	ld a, %11100100
	call ApplyPaletteWait
	ld a, %10010000
	call ApplyPaletteWait
	ld a, %01000000
	call ApplyPaletteWait
	xor a  ; %00000000
	jp ApplyPaletteWait
---

--- FadeIn
FadeIn::
	xor a  ; %00000000
	call ApplyPaletteWait
	ld a, %01000000
	call ApplyPaletteWait
	ld a, %10010000
	call ApplyPaletteWait
	ld a, %11100100
	jp ApplyPaletteWait
---

--- Helper functions +=
@{FadeOut}
@{FadeIn}
@{ApplyPaletteWait}
---

### Applying the fade effects

First I'll apply the fade-in effect to the title screen. I replaced the `jp EnableLCD` instruction with the `call` equivalent, and then jumping to `FadeIn`.

--- GM_Title init code :=
GM_Title_init::
	call DisableLCD
@{Set up the title screen graphics}
	call EnableLCD
	jp FadeIn
---

For the gameplay entry, I decided to use `DelayFrames` to wait some amount of time before fading out and resetting the game state.

--- GM_Game init code :=
GM_Game_init::
	ld c, 32
	call DelayFrames
	call FadeOut
	call DisableLCD
@{Set up the game graphics}
@{Set up sprites and variables}
	call EnableLCD
	jp FadeIn
---
