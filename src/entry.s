.segment "INES"
.byte $4E,$45,$53,$1A ; INES
.byte 16 ; PRG banks
.byte 8  ; CHR banks
.byte %1000000 ; 6
.byte %0 ; 7
.byte %0 ; 8
.byte %0 ; 9
.byte %0 ; 10
.byte %0 ; 11
.byte %0 ; 12
.byte %0 ; 13
.byte %0 ; 14
.byte %0 ; 15

.macro jsl addr, bank
.ifnblank bank
.endif
  lda #<addr                                      ; copy address to routine
  sta TmpE                                      ;
  lda #>addr                                      ;
  sta TmpF                                    ;
.ifnblank bank
.else
  jsr CommonBankJSR                               ; and call it!
.endif
.endmacro

.macro jsl_menu addr
  lda #<addr                                      ; copy address to routine
  sta TmpE                                      ;
  lda #>addr                                      ;
  sta TmpF                                    ;
  jsr BankCallMenu                                ; and call it
.endmacro


.include "inc.s"

.segment "PRG0"
.include "areas/Y00X00.s"
.include "areas/Y00X01.s"
.include "areas/Y00X02.s"
.include "areas/Y00X03.s"
.include "areas/Y01X00.s"
.include "areas/Y01X01.s"
.include "areas/Y01X02.s"
.include "areas/Y01X03.s"
.include "areas/Y02X00.s"
.include "areas/Y02X01.s"
.include "areas/Y02X02.s"
.include "areas/Y02X03.s"
.include "areas/Y03X00.s"
.include "areas/Y03X01.s"
.include "areas/Y03X02.s"
.include "areas/Y03X03.s"
.include "areas/Y04X00.s"
.include "areas/Y04X01.s"
.include "areas/Y04X02.s"
.include "areas/Y04X03.s"
.include "areas/Y05X00.s"
.include "areas/Y05X01.s"
.include "areas/Y05X02.s"
.include "areas/Y05X03.s"
.include "areas/Y06X00.s"
.include "areas/Y06X01.s"
.include "areas/Y06X02.s"
.include "areas/Y06X03.s"
.include "areas/Y07X00.s"
.include "areas/Y07X01.s"
.include "areas/Y07X02.s"
.include "areas/Y07X03.s"
.include "areas/Y08X00.s"
.include "areas/Y08X01.s"
.include "areas/Y08X02.s"
.include "areas/Y08X03.s"
.include "areas/Y09X00.s"
.include "areas/Y09X01.s"
.include "areas/Y09X02.s"
.include "areas/Y09X03.s"
.include "areas/Y10X00.s"
.include "areas/Y10X01.s"
.include "areas/Y10X02.s"
.include "areas/Y10X03.s"
.include "areas/Y11X00.s"
.include "areas/Y11X01.s"
.include "areas/Y11X02.s"
.include "areas/Y11X03.s"
.include "areas/Y12X00.s"
.include "areas/Y12X01.s"
.include "areas/Y12X02.s"
.include "areas/Y12X03.s"
.include "areas/Y13X00.s"
.include "areas/Y13X01.s"
.include "areas/Y13X02.s"
.include "areas/Y13X03.s"
.include "areas/Y14X00.s"
.include "areas/Y14X01.s"
.include "areas/Y14X02.s"
.include "areas/Y14X03.s"
.include "areas/Y15X00.s"
.include "areas/Y15X01.s"
.include "areas/Y15X02.s"
.include "areas/Y15X03.s"
.include "areas/Y16X00.s"
.include "areas/Y16X01.s"
.include "areas/Y16X02.s"
.include "areas/Y16X03.s"
.include "areas/Y17X00.s"
.include "areas/Y17X01.s"
.include "areas/Y17X02.s"
.include "areas/Y17X03.s"

.segment "PRG8"
.include "metatiles.s"

.segment "PRG9"
.include "BANK_09.s"

.segment "PRG10"
.include "audio.s"
.include "initram.s"
TitlescreenNametables:
.incbin "titlescreen.nam"
TitleScreenPalette:
.incbin "titlescreen.pal"
TitlescreenMMC3Banks:
.byte $1C,$1E
.include "dragonencounter.s"
.include "titlescreen.s"

.segment "PRACTISE"
.include "practise.s"

.segment "PAD"

.segment "GAME"
.include "game.s"

.segment "CHR"
.incbin "chr/0.bin"
.incbin "chr/1.bin"
.incbin "chr/2.bin"
.incbin "chr/3.bin"
.incbin "chr/4.bin"
.incbin "chr/5.bin"
.incbin "chr/6.bin"
.incbin "chr/7_titlescreen.bin"
.incbin "chr/8.bin"
.incbin "chr/9.bin"
.incbin "chr/10.bin"
.incbin "chr/11.bin"
.incbin "chr/12.bin"
.incbin "chr/13.bin"
.incbin "chr/14.bin"
.incbin "chr/15.bin"
