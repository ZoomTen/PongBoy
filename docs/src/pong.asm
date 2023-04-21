; src/pong.asm
; Constants includes
	include "include/hardware.inc"
	include "include/constants.inc"

; Memory definitions
	include "include/ram.inc"

; Jump vectors
; Rst vectors
	section "rst00", HOME[0]
	; Rst00 vector
	ret

	
	section "rst08", HOME[8]
	; Rst08 vector
	ret

	
	section "rst10", HOME[$10]
	; Rst10 vector
	ret

	
	section "rst18", HOME[$18]
	; Rst18 vector
	ret

	
	section "rst20", HOME[$20]
	; Rst20 vector
	ret

	
	section "rst28", HOME[$28]
	; Rst28 vector
	ret

	
	section "rst30", HOME[$30]
	; Rst30 vector
	ret

	
	section "rst38", HOME[$38]
	; Rst38 vector
	ret


; Interrupt vectors
	section "int_vblank", HOME[$40]
	; VBlank interrupt vector
	jp VBlank

	
	section "int_hblank", HOME[$48]
	; HBlank interrupt vector
	reti

	
	section "int_timer", HOME[$50]
	; Timer interrupt vector
	reti

	
	section "int_serial", HOME[$58]
	; Serial interrupt vector
	reti

	
	section "int_joypad", HOME[$60]
	; Joypad interrupt vector
	reti




	section "high_home", HOME[$68]
; not used
	
	section "entry", HOME[$100]
; Entry point
	jp Init


	section "header", HOME[$134]
; Header
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


	section "program", HOME[$150]
; Main program
; Initialization code
Init::
; Disable interrupts
	di

; Save the Game Boy type
	ldh [hGBType], a

; Turn off the screen
	call DisableLCD

; Clear RAM and place the stack pointer
	xor a
	ld hl, WRAM_START
	ld bc, ECHO_START - WRAM_START
	call FillMem16
	ld sp, wStackTop
	ld hl, hGBType + 1
	ld c, $ffff - (hGBType - 1)
	call FillMem8

; Reset audio
	ldh [rNR52], a

; Reset the screen
; zero out VRAM
	ld hl, VRAM_START
	ld bc, SRAM_START - VRAM_START
	call FillMem16

; reset scroll registers
	ldh [rSCX], a
	ldh [rSCY], a
; scroll the window register out
	ld a, LY_VBLANK
	ldh [rWY], a
	ld a, 7
	ldh [rWX], a
	ld a, %11100100
	ldh [rBGP], a  ; background
	ldh [rOBP0], a ; object palette 0
	ldh [rOBP1], a ; object palette 1

; Copy HRAM DMA code
	ld hl, DMARoutine
	ld b, DMARoutine_END - DMARoutine
	ld c, hDMACode ~/ $ff ; LOW(hDMACode)
.copy_code
	ld a, [hl+]
	ld [$ff00+c], a
	inc c
	dec b
	jr nz, .copy_code


; +++
; Set the initial game mode
	ld a, $ff
	ldh [hOldGameMode], a
	ld a, GM_TITLE ; +++
	ldh [hGameMode], a

; +++

; Turn on screen
	call EnableLCD

; Enable the interrupts again
; set the interrupt to enable
	ld a, 1 << VBLANK
	ldh [rIE], a

; enable them
	ei


; Game loop code
GameLoop::
; Determine which game mode is to be run and perform initializations
	ld hl, hOldGameMode
	ldh a, [hGameMode]
	cp [hl]
	jr z, .skip_init
	
	ld hl, GMInitJumptable
	call GotoJumptableEntry
	
	ldh a, [hGameMode]  ; reload game mode
	ldh [hOldGameMode], a  ; replace old game mode
.skip_init

; Perform game mode loop
	ld hl, GMLoopJumptable
	call GotoJumptableEntry

; Wait one frame
	call DelayFrame

	jp GameLoop
GMInitJumptable::
; Pointers to game mode initialization routines
	dw GM_Game_init
	dw GM_Title_init

GMLoopJumptable::
; Pointers to game mode loop routines
	dw GM_Game_loop
	dw GM_Title_loop


; Helper functions
; FillMem16
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

; FillMem8
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

; CopyMem16
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

; VBlank interrupt routine
VBlank::
; Save registers state
	push af
	push bc
	push de
	push hl

; Contents of VBlank
	call hDMACode
	xor a
	ldh [hAskVBlank], a
; Update the score display
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


; Reload registers state
	pop hl
	pop de
	pop bc
	pop af

	reti

; DisableLCD
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

; DMARoutine
DMARoutine::
	ld a, wVirtualOAM // $1000000 ; HIGH(wVirtualOAM)
	ldh [rDMA], a
	ld a, MAX_SPRITES ; wait 4 * MAX_SPRITES cycles 
.loop
	dec a        ; 1 cycle
	jr nz, .loop ; 3 cycles
	ret
DMARoutine_END::

; AddSprite
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

; SetupLeftPaddle
SetupLeftPaddle::
	ld hl, wVirtualOAM sprite SPRITE_SLOT_LEFT_PADDLE
	ld d, 0  ; flags
	ld b, LEFT_PADDLE_X  ; X position
	ld c, 8  ; tile (top of paddle)
; first sprite
	ld a, [wLeftPaddleY]
	call AddSprite
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
; fall through
	jp AddSprite

; SetupRightPaddle
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

; SetupBall
SetupBall::
	ld hl, wVirtualOAM sprite SPRITE_SLOT_BALL
	ld a, [wBallX]
	ld b, a
	ld a, [wBallY]
	ld c, 2
	ld d, 0
	jp AddSprite

; EnableLCD
EnableLCD::
	ld a, LCD_ENABLE | LCD_SET_8000 | LCD_MAP_9800 | LCD_OBJ_NORM | LCD_OBJ_ENABLE | LCD_BG_ENABLE
	ldh [rLCDC], a
	ret

; DelayFrame
DelayFrame::
	ld a, 1
	ldh [hAskVBlank], a
.loop
	halt
	nop
	ldh a, [hAskVBlank]
	and a
	ret z  ; exit if vblank is acknowledged
	jr .loop

; ShowScore
;;--
;; 
;; @param A     score value, BCD
;; @param HL    where in VRAM to place it in
;; 
;; @clobber BC  the split score value
;; @clobber DE  $20 - 1
;;--
ShowScore::
; Split score into two numbers
	ld b, a  ; save original number

; get the lower half and put it into C
	and %00001111
	add $10 ; starting tile of numeral "0"
	ld c, a

; get the upper half and put it into B
	ld a, b
	and %11110000
	swap a  ; make it the lower half
	add $10 ; starting tile of numeral "0"
	ld b, a

; Print top half of the score
	ld [hl], b
	inc hl
	ld [hl], c

; Print bottom half of the score
; move VRAM position
	ld de, $20 - 1
	add hl, de

; I assume the lower half comes directly
; after the upper half, so add the offset
; to b and c
	ld a, 10
	add b
	ld b, a
	ld a, 10
	add c
	ld c, a

; put it to the screen
	ld [hl], b
	inc hl
	ld [hl], c

	ret

; ReadJoypad
ReadJoypad::
	; Read d-pad input and store
	ld a, 1 << F_rJOYP_SELECT_NOT_BUTTONS
	ldh [rJOYP], a
	rept 4
	ldh a, [rJOYP]
	endr
	cpl       ; flip all the bits
	and %1111 ; get only lower half
	swap a    ; make it the upper half
	ld b, a   ; store to b

	; Read button input and store
	ld a, 1 << F_rJOYP_SELECT_NOT_DPAD
	ldh [rJOYP], a
	rept 4
	ldh a, [rJOYP]
	endr
	cpl              ; flip all the bits
	and %1111        ; get only lower half
	or b             ; merge with the d-pad input earlier
	ldh [hInput], a  ; save

	; Reset the joypad register
	ld a, 1 << F_rJOYP_SELECT_NOT_BUTTONS | (1 << F_rJOYP_SELECT_NOT_DPAD)
	ldh [rJOYP], a

	ret

HandleLeftPaddleInput::
; Handle the left paddle
.left_paddle
	call ReadJoypad
	ldh a, [hInput]
	jr z, .left_paddle_done
	
	cp BUTTON_UP
	jr z, .up
	
	cp BUTTON_DOWN
	jr z, .down
	
	jr .left_paddle_done

.up
; Move the left paddle up
	ld a, [wLeftPaddleY]

	rept PADDLE_SPEED
	dec a
	endr
	
	cp PADDLES_UPPER_BOUNDARY
	jr nc, .apply_up

; cap position
	ld a, PADDLES_UPPER_BOUNDARY

.apply_up
	ld [wLeftPaddleY], a
	jr .left_paddle_done


.down
; Move the left paddle down
	ld a, [wLeftPaddleY]
	
	rept PADDLE_SPEED
	inc a
	endr
	
	cp PADDLES_LOWER_BOUNDARY
	jr c, .apply_down

; cap position
	ld a, PADDLES_LOWER_BOUNDARY

.apply_down
	ld [wLeftPaddleY], a
	jr .left_paddle_done


.left_paddle_done

	ret

HandleRightPaddleInput::
; Handle the right paddle
.right_paddle
; Determine if the right paddle can move or not
	ld a, [wAIMovementDelay]
	and a
	jr z, .move_paddle

; Only decrement the timer
	dec a
	ld [wAIMovementDelay], a
	jr .skip_right_paddle


.move_paddle
; Reset the timer
	ld a, [wAISetDelay]
	ld [wAIMovementDelay], a

; Move the right paddle relative to the ball
	ld hl, wRightPaddleY
	ld a, [wBallY]
	cp [hl]
	ld a, [hl]

; if paddle is lower than ball, move up
	jr c, .move_up

; else, move down
	inc a
	jr .check_boundaries

.move_up
	dec a
	; jr .check_boundaries


.check_boundaries
; Set position boundaries
; assumes A is the calculated paddle position
	cp PADDLES_UPPER_BOUNDARY
	jr c, .limit_upper
	cp PADDLES_LOWER_BOUNDARY
	jr nc, .limit_lower
	jr .set_paddle_y
.limit_upper
	ld a, PADDLES_UPPER_BOUNDARY
	jr .set_paddle_y
.limit_lower
	ld a, PADDLES_LOWER_BOUNDARY
	;jr .set_paddle_y

; Set right paddle's Y position
.set_paddle_y
	ld [wRightPaddleY], a


.skip_right_paddle

	ret
DetermineBallDirection::
; Determine ball's next movement
; Determine if the ball collides with anything
; Check if the ball hits the paddles' X coordinates
	ld a, [wBallX]
	cp LEFT_PADDLE_X + PADDLE_WIDTH
	
; [wBallX] <= (LEFT_PADDLE_X + PADDLE_WIDTH)
	jr c, .additional_left_check
	jr z, .additional_left_check
	
	jr .left_x_done

.additional_left_check
	cp LEFT_PADDLE_X
; [wBallX] >= (LEFT_PADDLE_X)
	jr nc, .check_left_colliding

.left_x_done
	cp RIGHT_PADDLE_X - PADDLE_WIDTH
	
; [wBallX] >= (RIGHT_PADDLE_X - PADDLE_WIDTH)
	jr nc, .additional_right_check
	
	jr .right_x_done

.additional_right_check
	cp RIGHT_PADDLE_X + PADDLE_WIDTH
	jr c, .check_right_colliding

.right_x_done

; Check if the ball is colliding with the top and bottom of the arena
	ld a, [wBallY]
	cp BALL_UPPER_BOUNDARY
; wBallY < BALL_UPPER_BOUNDARY
	jr c, .switch_only_y_direction
	cp BALL_LOWER_BOUNDARY
; wBallY > BALL_LOWER_BOUNDARY
	jr z, .skip_collision
	jr nc, .switch_only_y_direction

	jr .skip_collision

.check_left_colliding
; Check if the ball is touching the left paddle
	ld hl, wLeftPaddleY
	ld a, [wBallY]
	sub [hl]
; pass if wBallY < wLeftPaddleY
	jr c, .skip_collision

; pass if wBallY-wLeftPaddleY > PADDLE_HEIGHT
	cp PADDLE_HEIGHT
	jr z, .save_delta_and_collide_left
	jr nc, .skip_collision

.save_delta_and_collide_left
	ld [wDeltaYFromPaddle], a
	jr .switch_directions


.check_right_colliding
; Check if the ball is touching the right paddle
	ld hl, wRightPaddleY
	ld a, [wBallY]
	sub [hl]
	jr c, .skip_collision
	cp PADDLE_HEIGHT
	jr z, .save_delta_and_collide_right
	jr nc, .skip_collision
.save_delta_and_collide_right
	ld [wDeltaYFromPaddle], a
	jr .switch_directions



.switch_directions
; Switch ball directions
	cp PADDLE_HEIGHT/2
	ld a, [wBallNextDirection]
; bounce down if delta Y > (PADDLE_HEIGHT/2)
	jr nc, .down
; up
	xor a, 1 << F_HORIZONTAL  ; invert the horizontal direction
	res F_VERTICAL, a         ; move up
	jr .set_direction
.down
	xor a, 1 << F_HORIZONTAL  ; invert the horizontal direction
	set F_VERTICAL, a         ; move down
.set_direction
	set F_APPLY_VERTICAL, a   ; always set the vertical apply flag
	ld [wBallNextDirection], a

	jr .skip_collision

.switch_only_y_direction
; Switch ball directions but only the Y axis
	ld a, [wBallNextDirection]
	xor a, 1 << F_VERTICAL
	set F_APPLY_VERTICAL, a
	ld [wBallNextDirection], a


.skip_collision

	ret

ApplyBallMovement::
; Apply ball movement
; Apply horizontal movement
; Determine the ball's new horizontal direction
	ld a, [wBallNextDirection]
; store next direction in b
	ld b, a
; load horizontal position
	ld hl, wBallX
	bit F_HORIZONTAL, b
	jr z, .move_ball_left


.move_ball_right
; Move the ball to the right
	inc [hl]
; if new X >= (160+8), score one point towards the left player
	ld a, [hl]
	cp 160+8
	jp nc, ScorePointsAndReset

	jr .apply_ball_y

.move_ball_left
; Move the ball to the left
; forcibly clear flags, at this point A=0
	and a  ; clear carry
	rla    ; clear zero

	dec [hl]
	
; if new X < 0, score one point towards the right player
; set carry flag to mark the right player earns 1 point
	jr nz, .apply_ball_y
	scf
	jp ScorePointsAndReset

	; jr .apply_ball_y


.apply_ball_y
; Apply vertical movement
; Determine the ball's new vertical direction
	ld hl, wBallY
	bit F_APPLY_VERTICAL, b
	jr z, .finished_applying
	bit F_VERTICAL, b
	jr z, .move_ball_up


.move_ball_down
; Move the ball down
	inc [hl]

	jr .finished_applying

.move_ball_up
; Move the ball up
	dec [hl]

	; jr .finished_applying


.finished_applying

	ret
; Score points and reset the game state
;;--
;; Score points and reset the game states.
;; 
;; @param Carry   if set, give 1 point to the right player.
;;                otherwise, give 1 point to the left player.
;;--
ScorePointsAndReset::
; Determine if the score to be given is to the left player or the right
	ld hl, wLeftScore
	jr nc, .left_player_won

; right player won
	ld hl, wRightScore
	ld a, LEFT_PLAYER_SERVES
	ld [wWhichServe], a
	call .give_point
	jr .got_player

.left_player_won
	ld a, RIGHT_PLAYER_SERVES
	ld [wWhichServe], a
	call .give_point

.got_player

; Reset the game state
; force a reinitialization
	ld a, $ff
	ldh [hOldGameMode], a
	jp GameLoop


.give_point
; Score points to the appropriate player
	ld a, [hl]
	and a  ; reset flags
	inc a
	daa
	ld [hl], a
	ret


; ResetGame
ResetGame::
	ld a, PADDLES_STARTING_Y
	ld [wLeftPaddleY], a
	ld [wRightPaddleY], a
	
	ld a, BALL_STARTING_X
	ld [wBallX], a
	
	ld a, BALL_STARTING_Y
	ld [wBallY], a
	
	ld a, [wWhichServe]
	ld [wBallNextDirection], a
	
	xor a
	ld [wDeltaYFromPaddle], a
	
	call SetupLeftPaddle
	call SetupRightPaddle
	jp SetupBall

; GotoJumptableEntry
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

; DelayFrames
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

; FadeOut
FadeOut::
	ld a, %11100100
	call ApplyPaletteWait
	ld a, %10010000
	call ApplyPaletteWait
	ld a, %01000000
	call ApplyPaletteWait
	xor a  ; %00000000
	jp ApplyPaletteWait

; FadeIn
FadeIn::
	xor a  ; %00000000
	call ApplyPaletteWait
	ld a, %01000000
	call ApplyPaletteWait
	ld a, %10010000
	call ApplyPaletteWait
	ld a, %11100100
	jp ApplyPaletteWait

; ApplyPaletteWait
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


; Game mode initialization code
; GM_Game init code
GM_Game_init::
	ld c, 32
	call DelayFrames
	call FadeOut
	call DisableLCD
; Set up the game graphics
; Copy over the main tileset
	ld hl, vChars0
	ld de, PongGFX
	ld bc, PongGFX_END - PongGFX
	call CopyMem16

; Copy over the score numeral tileset
	ld hl, vChars0 + $10 tiles
	ld de, NumbersGFX
	ld bc, NumbersGFX_END - NumbersGFX
	call CopyMem16

; Copy over the background tile map
	ld hl, vBGMap0
	ld de, BackgroundMAP
	ld bc, BackgroundMAP_END - BackgroundMAP
	call CopyMem16


; Set up sprites and variables
	call ResetGame
	ld a, RIGHT_PADDLE_DELAY
	ld [wAISetDelay], a
	ld a, 1
	ld [wShouldUpdateScore], a

	call EnableLCD
	jp FadeIn

; GM_Title init code
GM_Title_init::
	call DisableLCD
; Set up the title screen graphics
	ld hl, vChars0
	ld de, TitleScreenGFX
	ld bc, TitleScreenGFX_END - TitleScreenGFX
	call CopyMem16
	
	ld hl, vBGMap0
	ld de, TitleScreenMAP
	ld bc, TitleScreenMAP_END - TitleScreenMAP
	call CopyMem16

	call EnableLCD
	jp FadeIn


; Game mode loop code
; GM_Game loop code
GM_Game_loop::
; Handle joypad input
	call HandleLeftPaddleInput
	call HandleRightPaddleInput

; Handle ball physics
	call DetermineBallDirection
	call ApplyBallMovement

; Update screen
; Update sprite positions
	call SetupLeftPaddle
	call SetupRightPaddle
	call SetupBall


	ret

; GM_Title loop code
GM_Title_loop::
; Handle title screen joypad input
	call ReadJoypad
	ldh a, [hInput]
	bit BUTTONF_START, a
	ret z
	xor a  ; ld a, GM_GAME
	ldh [hGameMode], a
	ret

	ret




	section "data", DATA
; Miscellaneous data
PongGFX::
	incbin "gfx/game.2bpp"
PongGFX_END::
NumbersGFX::
	incbin "gfx/numbers.2bpp"
NumbersGFX_END::
BackgroundMAP::
	incbin "gfx/background.map"
BackgroundMAP_END::
TitleScreenGFX::
	incbin "gfx/title-screen.2bpp"
TitleScreenGFX_END::
TitleScreenMAP::
	incbin "gfx/title-screen.map"
TitleScreenMAP_END::


