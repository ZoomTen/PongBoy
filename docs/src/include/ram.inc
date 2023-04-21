; src/include/ram.inc
	section "wram", BSS[$c000]
; WRAM definitions
wStack:: ds $100 - 1
wStackTop:: db
wVirtualOAM:: ds 4*MAX_SPRITES
; paddle position
wLeftPaddleY:: db
wRightPaddleY:: db
; score
wLeftScore:: db
wRightScore:: db
; ball position
wBallX:: db
wBallY:: db
;;--
;; bit 0: left (0) / right (1)
;; bit 1: up (0) / down (1)
;; bit 2: no vertical momentum (0) / vertical momentum (1)
;;--
wBallNextDirection:: db
wDeltaYFromPaddle:: db
wWhichServe:: db
wAIMovementDelay:: db
wAISetDelay:: db
wShouldUpdateScore:: db


	section "hram", HRAM
; HRAM definitions
hGBType:: db
hDMACode:: ds 10
hAskVBlank:: db
hInput:: db
hGameMode:: db
hOldGameMode:: db


