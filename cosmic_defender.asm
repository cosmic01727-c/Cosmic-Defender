; COSMIC DEFENDER - Atari 2600 Game
; A space shooter game based on the name "Cosmic"
; 
; Assemble with DASM: dasm cosmic_defender.asm -f3 -v0 -ocosmic_defender.bin
; 
; Controls:
; - Joystick Left/Right: Move ship
; - Button: Fire laser

    processor 6502
    include "vcs.h"
    include "macro.h"

    SEG.U VARS
    ORG $80

; Player variables
PlayerX         ds 1    ; Player X position (0-159)
PlayerY         ds 1    ; Player Y position (fixed at bottom)
PlayerColor     ds 1    ; Player sprite color

; Enemy variables
EnemyX          ds 1    ; Enemy X position
EnemyY          ds 1    ; Enemy Y position
EnemyDir        ds 1    ; Enemy direction (0=right, 1=left)
EnemyColor      ds 1    ; Enemy sprite color

; Missile (laser) variables
MissileX        ds 1    ; Missile X position
MissileY        ds 1    ; Missile Y position
MissileActive   ds 1    ; Is missile active? (0=no, 1=yes)

; Game variables
Score           ds 1    ; Player score
GameState       ds 1    ; 0=playing, 1=game over
FlashCounter    ds 1    ; For color cycling effects
Random          ds 1    ; Pseudo-random number
SoundTimer      ds 1    ; Timer for sound effects

; Temp variables
Temp            ds 1

    SEG CODE
    ORG $F000

;==============================================================================
; RESET - Initialize the game
;==============================================================================
Reset:
    CLEAN_START         ; Macro to clear RAM and registers

    ; Initialize player position
    lda #80             ; Center of screen (160/2)
    sta PlayerX
    lda #20             ; Near bottom of visible area
    sta PlayerY
    lda #$0E            ; White color
    sta PlayerColor

    ; Initialize enemy
    lda #40
    sta EnemyX
    lda #170            ; Start near top of visible area
    sta EnemyY
    lda #0
    sta EnemyDir
    lda #$32            ; Purple/red cosmic color
    sta EnemyColor

    ; Initialize missile as inactive
    lda #0
    sta MissileActive
    sta MissileY
    
    ; Initialize game state
    lda #0
    sta Score
    sta GameState
    sta FlashCounter
    sta SoundTimer
    
    lda #$FF
    sta Random          ; Seed random

;==============================================================================
; MAIN LOOP - Start of frame
;==============================================================================
MainLoop:
    ; Start of vertical blank
    lda #2
    sta VBLANK          ; Turn on VBLANK
    sta VSYNC           ; Turn on VSYNC
    
    ; 3 scanlines of VSYNC
    REPEAT 3
        sta WSYNC
    REPEND
    
    lda #0
    sta VSYNC           ; Turn off VSYNC
    
    ; 37 scanlines of vertical blank
    ldx #37
VBlankLoop:
    sta WSYNC
    dex
    bne VBlankLoop
    
    ; Do game logic during VBLANK
    jsr ProcessInput
    jsr UpdateEnemy
    jsr UpdateMissile
    jsr CheckCollision
    jsr UpdateColors
    jsr UpdateSound      ; Update sound effects
    jsr PositionSprites  ; Position all sprites before drawing
    
    lda #0
    sta VBLANK          ; Turn off VBLANK
    
;==============================================================================
; DRAW SCREEN - 192 scanlines
;==============================================================================
    ; Set initial colors
    lda #$0E
    sta COLUP0
    lda EnemyColor
    sta COLUP1
    
    ldx #192            ; 192 visible scanlines
    
ScanLoop:
    ; Background color - cosmic gradient
    txa
    lsr
    lsr
    lsr
    sta COLUBK
    
    ; Clear graphics by default
    lda #0
    sta GRP0
    sta GRP1
    sta ENAM0
    
    ; Check if we should draw player (8 scanlines tall)
    ; X register counts DOWN from 192, PlayerY is 20
    ; Draw when scanline X is between PlayerY and PlayerY+7
    cpx PlayerY
    bcc SkipPlayer      ; X < PlayerY, skip
    txa
    sec
    sbc PlayerY
    cmp #8
    bcs SkipPlayer      ; Difference >= 8, skip
    ; Draw player
    tay
    lda PlayerSprite,Y
    sta GRP0
    
SkipPlayer:
    ; Check if we should draw enemy (8 scanlines tall)
    cpx EnemyY
    bcc SkipEnemy
    txa
    sec
    sbc EnemyY
    cmp #8
    bcs SkipEnemy
    ; Draw enemy
    tay
    lda EnemySprite,Y
    sta GRP1
    
SkipEnemy:
    ; Check if we should draw missile (4 scanlines tall)
    lda MissileActive
    beq SkipMissile
    cpx MissileY
    bcc SkipMissile
    txa
    sec
    sbc MissileY
    cmp #4
    bcs SkipMissile
    lda #2
    sta ENAM0
    
SkipMissile:
    sta WSYNC           ; Wait for end of scanline
    dex
    bne ScanLoop
    
;==============================================================================
; OVERSCAN
;==============================================================================
    lda #2
    sta VBLANK          ; Turn on VBLANK for overscan
    
    ldx #30             ; 30 scanlines overscan
OverscanLoop:
    sta WSYNC
    dex
    bne OverscanLoop
    
    jmp MainLoop        ; Next frame

;==============================================================================
; SUBROUTINES
;==============================================================================

;------------------------------------------------------------------------------
; Process joystick input
;------------------------------------------------------------------------------
ProcessInput:
    ; Check if game over
    lda GameState
    bne InputDone       ; Don't process input if game over
    
    ; Read joystick
    lda SWCHA           ; Read port A (joystick)
    
    ; Check left (bit 6 = 0 when pressed)
    and #%01000000
    bne CheckRight
    lda PlayerX
    cmp #15             ; Left boundary (wider margin for 8-pixel sprite)
    bcc CheckRight
    dec PlayerX
    dec PlayerX
    
CheckRight:
    lda SWCHA
    ; Check right (bit 7 = 0 when pressed)
    and #%10000000
    bne CheckFire
    lda PlayerX
    cmp #145            ; Right boundary (account for sprite width)
    bcs CheckFire
    inc PlayerX
    inc PlayerX
    
CheckFire:
    ; Check fire button
    lda INPT4
    bmi InputDone       ; Button not pressed
    
    ; Fire missile if not already active
    lda MissileActive
    bne InputDone
    
    lda #1
    sta MissileActive
    lda PlayerX
    sta MissileX
    lda PlayerY
    clc
    adc #20             ; Start above player
    sta MissileY
    
    ; Shooting sound effect - laser "pew"
    lda #4              ; Pure tone
    sta AUDC0
    lda #15             ; High pitch
    sta AUDF0
    lda #8              ; Medium volume
    sta AUDV0
    lda #10             ; Sound duration in frames
    sta SoundTimer
    
InputDone:
    rts

;------------------------------------------------------------------------------
; Update enemy movement
;------------------------------------------------------------------------------
UpdateEnemy:
    ; Move enemy horizontally
    lda EnemyDir
    beq MoveRight
    
MoveLeft:
    dec EnemyX
    dec EnemyX
    lda EnemyX
    cmp #8
    bcs DoneHorizontal
    lda #0
    sta EnemyDir
    jmp DoneHorizontal
    
MoveRight:
    inc EnemyX
    inc EnemyX
    lda EnemyX
    cmp #150
    bcc DoneHorizontal
    lda #1
    sta EnemyDir
    
DoneHorizontal:
    ; Move enemy down slowly
    lda Random
    and #%00000111
    bne NoVertMove
    dec EnemyY
    dec EnemyY
    
NoVertMove:
    ; Check if enemy reached bottom (game over)
    lda EnemyY
    cmp #15
    bcs EnemyDone
    lda #1
    sta GameState       ; Game over
    
EnemyDone:
    ; Update pseudo-random
    lda Random
    asl
    eor Random
    sta Random
    rts

;------------------------------------------------------------------------------
; Update missile
;------------------------------------------------------------------------------
UpdateMissile:
    lda MissileActive
    beq MissileDone
    
    ; Move missile up
    inc MissileY
    inc MissileY
    inc MissileY
    inc MissileY
    
    ; Deactivate if off screen
    lda MissileY
    cmp #190
    bcc MissileDone
    lda #0
    sta MissileActive
    
MissileDone:
    rts

;------------------------------------------------------------------------------
; Check collision between missile and enemy
;------------------------------------------------------------------------------
CheckCollision:
    lda MissileActive
    beq NoCollision
    
    ; Check Y proximity
    lda MissileY
    sec
    sbc EnemyY
    bpl YCheck
    eor #$FF
    adc #1
YCheck:
    cmp #5              ; Within 5 pixels vertically
    bcs NoCollision
    
    ; Check X proximity
    lda MissileX
    sec
    sbc EnemyX
    bpl XCheck
    eor #$FF
    adc #1
XCheck:
    cmp #8              ; Within 8 pixels horizontally
    bcs NoCollision
    
    ; HIT! Reset enemy to top
    lda #170
    sta EnemyY
    lda Random
    and #%01111111
    clc
    adc #20
    sta EnemyX
    
    ; Deactivate missile
    lda #0
    sta MissileActive
    
    ; Increase score
    inc Score
    
    ; Explosion sound effect
    lda #8              ; Noise/explosion sound
    sta AUDC0
    lda #5              ; Lower pitch rumble
    sta AUDF0
    lda #10             ; Louder volume
    sta AUDV0
    lda #15             ; Longer sound duration
    sta SoundTimer
    
NoCollision:
    rts

;------------------------------------------------------------------------------
; Update color effects
;------------------------------------------------------------------------------
UpdateColors:
    inc FlashCounter
    lda FlashCounter
    and #$1F
    sta EnemyColor      ; Cycle enemy color for cosmic effect
    rts

;------------------------------------------------------------------------------
; Update sound effects
;------------------------------------------------------------------------------
UpdateSound:
    ; Countdown sound timer
    lda SoundTimer
    beq SoundOff
    dec SoundTimer
    ; Keep sound on while timer is active
    rts
    
SoundOff:
    ; Turn off sound when timer expires
    lda #0
    sta AUDV0
    rts

;------------------------------------------------------------------------------
; Position all sprites horizontally
;------------------------------------------------------------------------------
PositionSprites:
    ; Position Player 0 (your ship)
    lda PlayerX
    ldx #0
    jsr SetHorizPos
    
    ; Position Player 1 (enemy)
    lda EnemyX
    ldx #1
    jsr SetHorizPos
    
    ; Position Missile 0 (laser)
    lda MissileX
    ldx #2
    jsr SetHorizPos
    
    sta WSYNC
    sta HMOVE
    rts

;------------------------------------------------------------------------------
; Position routines (simplified)
;------------------------------------------------------------------------------
; SetHorizPos - Position sprite horizontally
; A = desired X position (0-159)
; X = object to position (0=P0, 1=P1, 2=M0, 3=M1, 4=Ball)
;------------------------------------------------------------------------------
SetHorizPos:
    sec
    sta WSYNC
DivideLoop:
    sbc #15
    bcs DivideLoop
    eor #7
    asl
    asl
    asl
    asl
    
    cpx #0
    bne NotP0
    sta HMP0
    sta RESP0
    rts
NotP0:
    cpx #1
    bne NotP1
    sta HMP1
    sta RESP1
    rts
NotP1:
    cpx #2
    bne NotM0
    sta HMM0
    sta RESM0
    rts
NotM0:
    rts

;==============================================================================
; SPRITE GRAPHICS DATA
;==============================================================================
PlayerSprite:
    .byte #%00111100    ; Line 0 - Top of ship
    .byte #%01111110    ; Line 1
    .byte #%11111111    ; Line 2 - Widest part
    .byte #%11111111    ; Line 3
    .byte #%01111110    ; Line 4
    .byte #%00111100    ; Line 5
    .byte #%00011000    ; Line 6
    .byte #%00011000    ; Line 7 - Bottom

EnemySprite:
    .byte #%00111100    ; Line 0 - Alien head
    .byte #%01111110    ; Line 1
    .byte #%11011011    ; Line 2 - Eyes
    .byte #%11111111    ; Line 3
    .byte #%01111110    ; Line 4
    .byte #%10111101    ; Line 5 - Arms
    .byte #%10100101    ; Line 6
    .byte #%11000011    ; Line 7 - Legs

;==============================================================================
; INTERRUPT VECTORS
;==============================================================================
    ORG $FFFA
    
    .word Reset         ; NMI
    .word Reset         ; RESET
    .word Reset         ; IRQ

    END

