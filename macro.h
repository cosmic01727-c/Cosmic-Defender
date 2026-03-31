; MACRO.H
; Common macros for Atari 2600 development

;-------------------------------------------------------------------------------
; CLEAN_START - Clear RAM and registers
;-------------------------------------------------------------------------------
    MAC CLEAN_START
        sei             ; Disable interrupts
        cld             ; Clear decimal mode
        
        ldx #0
        txa
        tay
.ClearStack:
        dex
        txs
        pha
        bne .ClearStack ; Clear stack

        lda #0
.ClearMem:
        sta $00,X       ; Clear zero page
        inx
        bne .ClearMem
    ENDM

;-------------------------------------------------------------------------------
; VERTICAL_SYNC - Start vertical sync
;-------------------------------------------------------------------------------
    MAC VERTICAL_SYNC
        lda #2
        sta VSYNC
        sta WSYNC
        sta WSYNC
        sta WSYNC
        lda #0
        sta VSYNC
    ENDM

;-------------------------------------------------------------------------------
; VERTICAL_BLANK - Wait for vertical blank (37 lines)
;-------------------------------------------------------------------------------
    MAC VERTICAL_BLANK
        ldx #37
.VBlankLoop:
        sta WSYNC
        dex
        bne .VBlankLoop
    ENDM

;-------------------------------------------------------------------------------
; REPEAT/REPEND - Repeat code X times
;-------------------------------------------------------------------------------
    MAC REPEAT
.COUNT  SET {1}
    ENDM

    MAC REPEND
.COUNT  SET .COUNT - 1
        IF .COUNT > 0
            REPEAT .COUNT
        ENDIF
    ENDM
