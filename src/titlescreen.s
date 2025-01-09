RunTitleScreen:
  jsr ResetDataAndPalette                         ; clear out state
  lda #$37                                        ; select mmc3 bank
  sta SelectedBank2                               ;
  lda #$0                                         ; disable the status bar on the title screen
  sta StatusBarEnabled                            ;
  lda #%10100000                                  ; enable nmi and 8x16 sprites
  sta PPUCTRLCopy                                 ;
  sta PPU_CTRL                                    ;
  lda #$0                                         ; disable rendering
  sta PPUMASKCopy                                 ;
  sta PPU_MASK                                    ;
  lda #$0                                         ;
  sta PPUHScrollCopy                              ; clear scroll value
  sta PPUActiveNametable                          ; use first nametable
  lda #$E8                                        ;
  sta PPUVScrollCopy                              ; set vertical ppu scroll
  lda #$F                                         ; set full palette to black
  ldx #$1F                                        ;
: sta PaletteRAMCopy,x                            ;
  dex                                             ;
  bpl :-                                          ;
  jsl UpdatePaletteFromCopy                       ; banked call to update palette
  jsr DisableAllEntities                          ; clear display
  jsr SetupSpr0AndClearSprites                    ;
  jsr SetupTitleScreenSprites                     ; then set up titlescreen
  lda #$15                                        ; use titlescreen bank
  sta SelectedBank2                               ;
  lda #Music_Title                                ; start titlescreen music
  sta CurrentMusic                                ;
  jsr Audio_StartMusic                            ;
  jsr ShowTitlescreen                             ;
  lda #%00011110                                  ; enable rendering
  sta PPUMASKCopy                                 ;
  sta PPU_MASK                                    ;
  lda #120                                        ; delay for about 2 seconds
  sta FrameCountdownTimer                         ;
: lda FrameCountdownTimer                         ;
  bne :-                                          ;
  jsr TitleScreenFadeIn                           ; fade in title screen from black
  lda #$14                                        ; set up demo timer
  sta CutsceneTimer                               ;
@TitleScreenLoop:
  lda #$1                                         ; update timer length
  sta FrameCountdownTimer                         ;
  jsr ReadJoypad                                  ; get controller state
  cmp #$FF                                        ; are all inputs pressed on a combination of joypads
  bne :+                                          ; no - skip ahead
  lda #SFX_CheatMode                              ; yes - play cheat sound
  sta PendingSFX                                  ;
  sta CheatsEnabled                               ; and activate cheat mode
: and #CtlT                                       ; is the start button pressed?
  bne @StartGame                                  ; if so - start the game!
  lda JoypadInputExp                              ; check expansion port controller inputs
  cmp #CtlA|CtlR|CtlL                             ; if holding A, L and R on the expansion ports
  beq @SkipToCredits                              ; then we skip to the end credits
  lda IntervalTimer                               ; check timer for palette swaps
  and #%0111                                      ;
  bne @SkipPaletteSwaps                           ; if we're not swapping right now, continue
  lda PaletteRAMCopy+2                            ; store hue of current palette value in temp value
  and #%1111                                      ;
  sta Tmp8                                        ;
  lda PaletteRAMCopy+2                            ; get lightness of palette value
  and #$F0                                        ;
  sec                                             ; and reduce it by 10 to darken
  sbc #$10                                        ;
  bcs :+                                          ;
  lda #$30                                        ; set to max brightness when we underflow
: sta PaletteRAMCopy+$13                          ; set gray palette value
  ora Tmp8                                        ; then restore the hue
  sta PaletteRAMCopy+2                            ; and update the color palette value
@SkipPaletteSwaps:
  jsl WaitForCountdownTimer                       ; wait for timer to finish
  lda CutsceneTimer                               ; is the demo timer done?
  bne @TitleScreenLoop                            ; no - keep doing title screen
  jmp StartDemo                                   ; yes - start the demo!

@StartGame:
  JMP L_13_1B0B1                                  ;  1AF17 AF17 C 4C B1 B0        F:000151

@SkipToCredits:
  jmp RunCreditsScreen                            ; hop over to play the credits sequence

StartDemo:
  JSR FadeInPalette2                                  ;  1AF1D AF1D C 20 61 C4        F:001324
  jsr SetupSpr0AndClearSprites                    ; setup base sprites
  jsr DisableAllEntities                          ; make sure no entities are running
  jsr SetupDemoSprites                            ; and write out the 'press start' sprites
  lda #$4                                         ; get a random value from 0-3
  jsr StepRNG                                     ;
  sta CurrentAreaX                                ; and use that as the X screen
  lda #$10                                        ; get a random value from 0-15
  jsr StepRNG                                     ;
  sta CurrentAreaY                                ; and use that as the Y screen
  jsl LoadNewAreaData
: lda #$40                                        ; place demo player at a random X
  jsr StepRNG                                     ;
  sta PlayerXTile                                 ;
  STA PositionToBlock_XTile                                      ;  1AF49 AF49 C 85 0C           F:001345
  lda #$0                                         ;
  sta PlayerXPx                               ;
  lda #11                                         ; place demo player at a random Y
  jsr StepRNG                                     ;
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  STA PlayerYPx                                   ;
  STA PositionToBlock_YPx                                      ;  1AF5A AF5A C 85 0D           F:001345
  jsr PositionToBlock                          ; get the tile at the position
  ldy #$0                                         ;
  lda (BlockPtrLo),y                                ;
  and #$3F                                        ;
  cmp #$30                                        ; is it solid?
  bcs :-                                          ; if so - roll a new spot
  cmp #Tile_LockedDoor                            ; is it a locked door?
  beq :-                                          ; if so - roll a new spot
  cmp AreaBlockSwapFrom                           ; is it a tile that will swap when touched?
  beq :-                                          ; if so - roll a new spot
  iny                                             ; check tile under demo player
  lda (BlockPtrLo),y                                ;
  and #$3F                                        ;
  cmp #$30                                        ; is it solid?
  bcc :-                                          ; if not - roll a new spot
  beq :-                                          ; if not - roll a new spot
  lda PlayerXTile                                 ;
  SEC                                             ;  1AF7E AF7E C 38              F:001345
  SBC #$8                                         ;  1AF7F AF7F C E9 08           F:001345
  BCS B_13_1AF85                                  ;  1AF81 AF81 C B0 02           F:001345
  LDA #$0                                         ;  1AF83 AF83 C A9 00           F:001345
B_13_1AF85:
  CMP #$30                                        ;  1AF85 AF85 C C9 30           F:001345
  BCC B_13_1AF8B                                  ;  1AF87 AF87 C 90 02           F:001345
  LDA #$30                                        ;  1AF89 AF89 C A9 30           F:024653
B_13_1AF8B:
  STA CameraXTile                                      ;  1AF8B AF8B C 85 7C           F:001345
  LDA #$0                                         ;  1AF8D AF8D C A9 00           F:001345
  STA CameraXPx                                      ;  1AF8F AF8F C 85 7B           F:001345
B_13_1AF91:
  LDA #$5                                         ;  1AF91 AF91 C A9 05           F:001345
  JSR StepRNG                                  ;  1AF93 AF93 C 20 64 CC        F:001345
  TAX                                             ;  1AF96 AF96 C AA              F:001345
  TAY                                             ;  1AF97 AF97 C A8              F:001345
  SEC                                             ;  1AF98 AF98 C 38              F:001345
  LDA #$0                                         ;  1AF99 AF99 C A9 00           F:001345
: ROL                                             ;  1AF9B AF9B C 2A              F:001345
  DEY                                             ;  1AF9C AF9C C 88              F:001345
  BPL :-                                          ;  1AF9D AF9D C 10 FC           F:001345
  AND EnemySpawnRate                                      ;  1AF9F AF9F C 25 41           F:001345
  BEQ B_13_1AF91                                  ;  1AFA1 AFA1 C F0 EE           F:001345
  LDA D_13_1B0AC,X                                ;  1AFA3 AFA3 C BD AC B0        F:001345
  STA PlayerActiveItems                                      ;  1AFA6 AFA6 C 85 51           F:001345
  LDA #$0                                         ;  1AFA8 AFA8 C A9 00           F:001345
  STA PlayerSelectedItemSlot                                      ;  1AFAA AFAA C 85 55           F:001345
  STX PlayerCharacter                                      ;  1AFAC AFAC C 86 40           F:001345
  TXA                                             ;  1AFAE AFAE C 8A              F:001345
  ASL                                             ;  1AFAF AFAF C 0A              F:001345
  ASL                                             ;  1AFB0 AFB0 C 0A              F:001345
  CLC                                             ;  1AFB1 AFB1 C 18              F:001345
  ADC #$3                                         ;  1AFB2 AFB2 C 69 03           F:001345
  TAY                                             ;  1AFB4 AFB4 C A8              F:001345
  LDX #$3                                         ;  1AFB5 AFB5 C A2 03           F:001345
B_13_1AFB7:
  LDA CharacterAttributeData,Y                                ;  1AFB7 AFB7 C B9 A7 FF        F:001345
  STA PlayerAttributes,X                                    ;  1AFBA AFBA C 95 5C           F:001345
  DEY                                             ;  1AFBC AFBC C 88              F:001345
  DEX                                             ;  1AFBD AFBD C CA              F:001345
  BPL B_13_1AFB7                                  ;  1AFBE AFBE C 10 F7           F:001345
  LDA PlayerCharacter                                      ;  1AFC0 AFC0 C A5 40           F:001345
  CLC                                             ;  1AFC2 AFC2 C 18              F:001345
  ADC #$38                                        ;  1AFC3 AFC3 C 69 38           F:001345
  STA SelectedBank2                                      ;  1AFC5 AFC5 C 85 2C           F:001345
  LDA #$3E                                        ;  1AFC7 AFC7 C A9 3E           F:001345
  STA SelectedBank4                                      ;  1AFC9 AFC9 C 85 2E           F:001345
  LDA #$20                                        ;  1AFCB AFCB C A9 20           F:001345
  STA SelectedBank5                               ;  1AFCD AFCD C 85 2F           F:001345
  LDA #$D                                         ; set character to 'active' sprite
  STA PlayerSpriteTile                           ;
  LDA #$0                                         ; and clear attributes
  STA PlayerSpriteAttr                            ;
  LDA #$1                                         ;
  STA R_0042                                      ;
  LDA #100                                        ; restore health and mana when choosing character
  STA PlayerHP                                    ;
  STA PlayerMP                                    ;
  jsl L_14_1C38B
  JSR RedrawStatusbarBG                                  ;  1AFEC AFEC C 20 7A C5        F:001346
  jsl DrawLeftAreaDataColumn
  jsr UpdateHPDisplay                                  ; make sure our resources are all sane values
  jsr UpdateMPDisplay                                  ;
  jsr UpdateGoldDisplay                                ;
  jsr UpdateKeysDisplay                                ;
  JSR UpdateCameraPPUScroll                                  ;  1B006 B006 C 20 C7 C1        F:001347
  JSR ClearEntitySprites                                  ;  1B009 B009 C 20 7C D0        F:001347
  JSR UpdatePlayerSprites                                  ;  1B00C B00C C 20 D8 C1        F:001347
  JSR UpdateInventorySprites                                  ;  1B00F B00F C 20 34 C2        F:001347
  jsl FadeInAreaPalette
  LDA #$A                                         ;  1B01D B01D C A9 0A           F:001373
  STA CutsceneTimer                                      ;  1B01F B01F C 85 8C           F:001373
L_13_1B021:
  LDA #$1                                         ;  1B021 B021 C A9 01           F:001373
  STA FrameCountdownTimer                                      ;  1B023 B023 C 85 36           F:001373
  LDA CameraXTile                                      ;  1B025 B025 C A5 7C           F:001373
  STA CurrentCameraXTile                                      ;  1B027 B027 C 85 7E           F:001373
  JSR L_13_1B11A                                  ;  1B029 B029 C 20 1A B1        F:001373
  JSR ReadJoypad                                  ;  1B02C B02C C 20 43 CC        F:001373
  AND #$10                                        ;  1B02F B02F C 29 10           F:001373
  BEQ B_13_1B036                                  ;  1B031 B031 C F0 03           F:001373
  JMP $B0B1                                       ;  1B033 B033 . 4C B1 B0        

B_13_1B036:
  LDA Workset_FE                                      ;  1B036 B036 C A5 FE           F:001373
  STA JoypadInput                                      ;  1B038 B038 C 85 20           F:001373
  LDA PlayerMovingDirection                                      ;  1B03A B03A C A5 49           F:001373
  ORA PlayerYPxSpeed                                      ;  1B03C B03C C 05 4B           F:001373
  BEQ B_13_1B044                                  ;  1B03E B03E C F0 04           F:001373
  DEC R_0042                                      ;  1B040 B040 C C6 42           F:001374
  BNE B_13_1B04F                                  ;  1B042 B042 C D0 0B           F:001374
B_13_1B044:
  LDA #$80                                        ;  1B044 B044 C A9 80           F:001373
  STA R_0042                                      ;  1B046 B046 C 85 42           F:001373
  JSR RunDemoJoypad                                  ;  1B048 B048 C 20 E4 B0        F:001373
  LDA JoypadInput                                      ;  1B04B B04B C A5 20           F:001373
  STA Workset_FE                                      ;  1B04D B04D C 85 FE           F:001373
B_13_1B04F:
  jsl HandlePlayerControls
  jsl RunProjectileEntities
  jsl RunEnemyEntities
  jsl RunBlockSwapEntity
  jsl UpdateCameraPosition
  JSR UpdatePlayerSprites                                  ;  1B086 B086 C 20 D8 C1        F:001373
  JSR UpdateEntitySprites                                  ;  1B089 B089 C 20 B1 C2        F:001373
  LDA CurrentCameraXTile                                      ;  1B08C B08C C A5 7E           F:001373
  CMP CameraXTile                                      ;  1B08E B08E C C5 7C           F:001373
  BEQ B_13_1B094                                  ;  1B090 B090 C F0 02           F:001373
  INC ColumnWritePending                                      ;  1B092 B092 C E6 3D           F:001672
B_13_1B094:
  jsl WaitForCountdownTimer                       ; wait for timer to finish
  LDA CutsceneTimer                                      ;  1B09F B09F C A5 8C           F:001374
  BEQ B_13_1B0A6                                  ;  1B0A1 B0A1 C F0 03           F:001374
  JMP L_13_1B021                                  ;  1B0A3 B0A3 C 4C 21 B0        F:001374

B_13_1B0A6:
  JSR FadeInPalette2                                  ;  1B0A6 B0A6 C 20 61 C4        F:001927
  JMP RunTitleScreen                                  ;  1B0A9 B0A9 C 4C 64 AE        F:001947

D_13_1B0AC:
.byte $03                                         ;  1B0AC B0AC D        ?        F:001345
.byte $04                                         ;  1B0AD B0AD D        ?        F:005229
.byte $05                                         ;  1B0AE B0AE D        ?        F:038245
.byte $02                                         ;  1B0AF B0AF D        ?        F:003289
.byte $08                                         ;  1B0B0 B0B0 D        ?        F:016885

L_13_1B0B1:
  JSR FadeInPalette2                                  ;  1B0B1 B0B1 C 20 61 C4        F:000151
  jsl L_14_1C38B
  JSR RedrawStatusbarBG                                  ;  1B0BF B0BF C 20 7A C5        F:000171
  JSR SetupSpr0AndClearSprites                                  ;  1B0C2 B0C2 C 20 75 C3        F:000171
  JSR ResetDataAndPalette                                  ;  1B0C5 B0C5 C 20 31 B6        F:000171
  JSR UpdateHPDisplay                                  ;  1B0C8 B0C8 C 20 B6 CA        F:000171
  JSR UpdateGoldDisplay                                  ;  1B0CB B0CB C 20 F8 CA        F:000171
  JSR UpdateKeysDisplay                                  ;  1B0CE B0CE C 20 E2 CA        F:000171
  JSR UpdateGoldDisplay                                  ;  1B0D1 B0D1 C 20 F8 CA        F:000171
  LDA #$1                                         ;  1B0D4 B0D4 C A9 01           F:000171
  STA FrameCountdownTimer                                      ;  1B0D6 B0D6 C 85 36           F:000171
  jsl WaitForCountdownTimer                       ; wait for timer to finish
  RTS                                             ;  1B0E3 B0E3 C 60              F:000172

RunDemoJoypad:
  lda #$4                                         ; pick a random input option from 0-3
  jsr StepRNG                                     ;
  tax                                             ;
  lda @InputOptions,x                             ; update the joypad data with the demo inputs
  sta JoypadInput                                 ;
  lda #10                                         ; pick a random value from 0-9 to decide if we fire!
  jsr StepRNG                                     ;
  tax                                             ;
  bne :+                                          ; if it's not zero, we do nothing.
  lda JoypadInput                                 ; otherwise the demo presses B
  ora #CtlB                                       ;
  sta JoypadInput                                 ;
: rts                                             ; done!
@InputOptions:
.byte CtlA | CtlR
.byte CtlA | CtlD
.byte CtlA | CtlL
.byte $00

SetupTitleScreenSprites:
  ldx #TitleScreenSpritesEnd-TitleScreenSprites-1 ; bytes to copy
: lda TitleScreenSprites,x                        ; copy all sprite data
  sta SprY+(4*$10),x                              ;
  dex                                             ;
  bpl :-                                          ;
  rts                                             ; done!

SetupDemoSprites:
  ldx #DemoSpritesEnd-DemoSprites-1               ; bytes to copy
: lda DemoSprites,X                               ; copy all sprite data
  sta SprY+(4*$10),X                              ;
  dex                                             ;
  bpl :-                                          ;
  rts                                             ; done!

L_13_1B11A:
  LDX #$EF                                        ;  1B11A B11A C A2 EF           F:001373
  LDA IntervalTimer                                      ;  1B11C B11C C A5 84           F:001373
  AND #$30                                        ;  1B11E B11E C 29 30           F:001373
  BEQ B_13_1B124                                  ;  1B120 B120 C F0 02           F:001373
  LDX #$80                                        ;  1B122 B122 C A2 80           F:001386
B_13_1B124:
  STX R_0240                                      ;  1B124 B124 C 8E 40 02        F:001373
  STX R_0244                                      ;  1B127 B127 C 8E 44 02        F:001373
  STX R_0248                                      ;  1B12A B12A C 8E 48 02        F:001373
  STX R_024C                                      ;  1B12D B12D C 8E 4C 02        F:001373
  STX R_0250                                      ;  1B130 B130 C 8E 50 02        F:001373
  STX R_0254                                      ;  1B133 B133 C 8E 54 02        F:001373
  STX R_0258                                      ;  1B136 B136 C 8E 58 02        F:001373
  STX R_025C                                      ;  1B139 B139 C 8E 5C 02        F:001373
  RTS                                             ;  1B13C B13C C 60              F:001373

RunCreditsScreen:
.byte $E6,$92,$20,$9B,$B2,$20,$61,$C4             ;  1B13D B13D ........ ?? ?? a? 
.byte $20,$8B,$C3,$20,$EE,$B2,$A9,$20             ;  1B145 B145 ........  ?? ???  
.byte $85,$2A,$A9,$22,$85,$2B,$A5,$24             ;  1B14D B14D ........ ?*?"?+?$ 
.byte $09,$18,$85,$24,$A9,$FF,$20,$8F             ;  1B155 B155 ........ ???$?? ? 
.byte $CC,$A9,$0A,$85,$8E,$20,$08,$FC             ;  1B15D B15D ........ ????? ?? 
.byte $A9,$00,$8D,$1C,$00,$8D,$1D,$00             ;  1B165 B165 ........ ???????? 
.byte $8D,$0A,$00,$85,$7B,$85,$7C,$20             ;  1B16D B16D ........ ????{?|  
.byte $CC,$B2,$A9,$40,$85,$18,$A9,$01             ;  1B175 B175 ........ ???@???? 
.byte $85,$19,$A9,$20,$85,$1A,$A9,$9C             ;  1B17D B17D ........ ??? ???? 
.byte $85,$0C,$A9,$B7,$85,$0D,$20,$5D             ;  1B185 B185 ........ ?????? ] 
.byte $B2,$20,$EA,$B1,$B0,$08,$20,$5D             ;  1B18D B18D ........ ? ???? ] 
.byte $B2,$20,$15,$B2,$90,$F0,$A9,$20             ;  1B195 B195 ........ ? ?????  
.byte $85,$8F,$A5,$D4,$F0,$FC,$A5,$D4             ;  1B19D B19D ........ ???????? 
.byte $D0,$FC,$A9,$3C,$85,$36,$A5,$36             ;  1B1A5 B1A5 ........ ???<?6?6 
.byte $D0,$FC,$A9,$00,$85,$94,$85,$A4             ;  1B1AD B1AD ........ ???????? 
.byte $85,$B4,$85,$C4,$A9,$18,$85,$8F             ;  1B1B5 B1B5 ........ ???????? 
.byte $A2,$0A,$8A,$48,$A9,$30,$A2,$1F             ;  1B1BD B1BD ........ ???H?0?? 
.byte $9D,$80,$01,$CA,$10,$FA,$20,$69             ;  1B1C5 B1C5 ........ ?????? i 
.byte $C5,$A9,$01,$85,$36,$20,$35,$C1             ;  1B1CD B1CD ........ ????6 5? 
.byte $20,$CC,$B2,$20,$69,$C5,$A9,$02             ;  1B1D5 B1D5 ........  ?? i??? 
.byte $85,$36,$20,$35,$C1,$68,$AA,$CA             ;  1B1DD B1DD ........ ?6 5?h?? 
.byte $D0,$D8,$4C,$E7,$B1,$20,$FC,$B2             ;  1B1E5 B1E5 ........ ??L?? ?? 
.byte $A0,$00,$B1,$0C,$F0,$20,$C9,$0D             ;  1B1ED B1ED ........ ????? ?? 
.byte $F0,$12,$29,$0F,$85,$08,$B1,$0C             ;  1B1F5 B1F5 ........ ??)????? 
.byte $29,$F0,$0A,$05,$08,$99,$40,$01             ;  1B1FD B1FD ........ )?????@? 
.byte $C8,$4C,$EF,$B1,$20,$4E,$B2,$A9             ;  1B205 B205 ........ ?L?? N?? 
.byte $05,$20,$78,$B2,$18,$60,$38,$60             ;  1B20D B20D ........ ? x??`8` 
.byte $20,$FC,$B2,$A0,$00,$B1,$0C,$F0             ;  1B215 B215 ........  ??????? 
.byte $2E,$C9,$0D,$F0,$15,$29,$0F,$85             ;  1B21D B21D ........ .????)?? 
.byte $08,$B1,$0C,$29,$F0,$0A,$05,$08             ;  1B225 B225 ........ ???)???? 
.byte $18,$69,$10,$99,$40,$01,$C8,$4C             ;  1B22D B22D ........ ?i??@??L 
.byte $1A,$B2,$C8,$98,$18,$65,$0C,$85             ;  1B235 B235 ........ ?????e?? 
.byte $0C,$90,$02,$E6,$0D,$20,$4E,$B2             ;  1B23D B23D ........ ????? N? 
.byte $A9,$05,$20,$78,$B2,$18,$60,$38             ;  1B245 B245 ........ ?? x??`8 
.byte $60,$A9,$08,$85,$17,$A5,$0A,$0A             ;  1B24D B24D ........ `??????? 
.byte $26,$17,$0A,$26,$17,$85,$16,$60             ;  1B255 B255 ........ &??&???` 
.byte $E6,$0A,$A5,$0A,$29,$07,$F0,$08             ;  1B25D B25D ........ ????)??? 
.byte $A9,$FF,$20,$78,$B2,$4C,$5D,$B2             ;  1B265 B265 ........ ?? x?L]? 
.byte $A5,$0A,$C9,$F0,$D0,$04,$A9,$00             ;  1B26D B26D ........ ???????? 
.byte $85,$0A,$60,$48,$A5,$0A,$18,$69             ;  1B275 B275 ........ ??`H???i 
.byte $06,$C9,$F0,$90,$03,$18,$69,$10             ;  1B27D B27D ........ ??????i? 
.byte $85,$1E,$68,$20,$8F,$CC,$A9,$FF             ;  1B285 B285 ........ ??h ???? 
.byte $20,$8F,$CC,$A9,$FF,$20,$8F,$CC             ;  1B28D B28D ........  ???? ?? 
.byte $A9,$FF,$20,$8F,$CC,$60,$A9,$00             ;  1B295 B295 ........ ?? ??`?? 
.byte $85,$B4,$A9,$10,$85,$0D,$A5,$A0             ;  1B29D B29D ........ ???????? 
.byte $F0,$02,$C6,$A0,$A5,$B0,$F0,$02             ;  1B2A5 B2A5 ........ ???????? 
.byte $C6,$B0,$A5,$D0,$F0,$02,$C6,$D0             ;  1B2AD B2AD ........ ???????? 
.byte $A9,$14,$85,$0C,$20,$B1,$C2,$A9             ;  1B2B5 B2B5 ........ ???? ??? 
.byte $01,$85,$36,$20,$35,$C1,$C6,$0C             ;  1B2BD B2BD ........ ??6 5??? 
.byte $D0,$F2,$C6,$0D,$D0,$D8,$60,$A9             ;  1B2C5 B2C5 ........ ??????`? 
.byte $0F,$8D,$80,$01,$A9,$0C,$8D,$81             ;  1B2CD B2CD ........ ???????? 
.byte $01,$A9,$10,$8D,$82,$01,$A9,$30             ;  1B2D5 B2D5 ........ ???????0 
.byte $8D,$83,$01,$A9,$0F,$A2,$1B,$9D             ;  1B2DD B2DD ........ ???????? 
.byte $84,$01,$CA,$10,$FA,$20,$69,$C5             ;  1B2E5 B2E5 ........ ????? i? 
.byte $60,$A2,$00,$A9,$EF,$9D,$00,$02             ;  1B2ED B2ED ........ `??????? 
.byte $E8,$E8,$E8,$E8,$D0,$F7,$60,$A0             ;  1B2F5 B2F5 ........ ??????`? 
.byte $1F,$A9,$C0,$99,$40,$01,$88,$10             ;  1B2FD B2FD ........ ????@??? 
.byte $FA,$60

RunGameOverScreen:
.byte $A5,$8E,$48,$E6,$8D,$20             ;  1B305 B305 ........ ?`??H??  
.byte $7C,$D0,$A2,$35,$A0,$00,$20,$C5             ;  1B30D B30D ........ |??5?? ? 
.byte $B4,$A9,$3C,$85,$36,$20,$35,$C1             ;  1B315 B315 ........ ??<?6 5? 
.byte $A9,$08,$20,$2E,$D0,$C6,$8D,$A9             ;  1B31D B31D ........ ?? .???? 
.byte $05,$85,$0A,$A2,$0D,$A0,$00,$20             ;  1B325 B325 ........ ???????  
.byte $C5,$B4,$A2,$01,$A0,$00,$20,$C5             ;  1B32D B32D ........ ?????? ? 
.byte $B4,$A2,$09,$A0,$00,$20,$C5,$B4             ;  1B335 B335 ........ ????? ?? 
.byte $A2,$01,$A0,$40,$20,$C5,$B4,$C6             ;  1B33D B33D ........ ???@ ??? 
.byte $0A,$D0,$E0,$A9,$01,$85,$36,$A9             ;  1B345 B345 ........ ??????6? 
.byte $31,$85,$56,$20,$D8,$C1,$20,$35             ;  1B34D B34D ........ 1?V ?? 5 
.byte $C1,$A5,$EC,$D0,$29,$A5,$37,$10             ;  1B355 B355 ........ ????)?7? 
.byte $05,$E6,$37,$4C,$72,$B3,$A6,$55             ;  1B35D B35D ........ ??7Lr??U 
.byte $B5,$51,$C9,$0C,$D0,$18,$A9,$FF             ;  1B365 B365 ........ ?Q?????? 
.byte $95,$51,$20,$34,$C2,$20,$6A,$D1             ;  1B36D B36D ........ ?Q 4? j? 
.byte $A9,$19,$85,$56,$20,$09,$CC,$68             ;  1B375 B375 ........ ???V ??h 
.byte $20,$2E,$D0,$A2,$00,$60,$68,$20             ;  1B37D B37D ........  .???`h  
.byte $61,$C4,$A9,$00,$85,$EC,$85,$3E             ;  1B385 B385 ........ a??????> 
.byte $A9,$80,$85,$3F,$20,$8B,$C3,$20             ;  1B38D B38D ........ ???? ??  
.byte $8A,$D0,$20,$B1,$C2,$A9,$16,$85             ;  1B395 B395 ........ ?? ????? 
.byte $2B,$A9,$36,$85,$2C,$A9,$00,$8D             ;  1B39D B39D ........ +?6?,??? 
.byte $1C,$00,$8D,$1D,$00,$8D,$1E,$00             ;  1B3A5 B3A5 ........ ???????? 
.byte $85,$7B,$85,$7C,$A9,$6B,$85,$16             ;  1B3AD B3AD ........ ?{?|?k?? 
.byte $A9,$21,$85,$17,$A9,$AF,$85,$18             ;  1B3B5 B3B5 ........ ?!?????? 
.byte $A9,$B4,$85,$19,$A9,$09,$85,$1A             ;  1B3BD B3BD ........ ???????? 
.byte $A9,$05,$20,$8F,$CC,$A9,$4C,$85             ;  1B3C5 B3C5 ........ ?? ???L? 
.byte $16,$A9,$22,$85,$17,$A9,$B8,$85             ;  1B3CD B3CD ........ ??"????? 
.byte $18,$A9,$B4,$85,$19,$A9,$05,$85             ;  1B3D5 B3D5 ........ ???????? 
.byte $1A,$A9,$05,$20,$8F,$CC,$A9,$8C             ;  1B3DD B3DD ........ ??? ???? 
.byte $85,$16,$A9,$22,$85,$17,$A9,$BD             ;  1B3E5 B3E5 ........ ???"???? 
.byte $85,$18,$A9,$B4,$85,$19,$A9,$08             ;  1B3ED B3ED ........ ???????? 
.byte $85,$1A,$A9,$05,$20,$8F,$CC,$A9             ;  1B3F5 B3F5 ........ ???? ??? 
.byte $05,$85,$44,$A9,$00,$85,$43,$A9             ;  1B3FD B3FD ........ ??D???C? 
.byte $70,$85,$45,$A9,$39,$85,$56,$20             ;  1B405 B405 ........ p?E?9?V  
.byte $75,$C3,$20,$D8,$C1,$A9,$E0,$85             ;  1B40D B40D ........ u? ????? 
.byte $0E,$A9,$C4,$85,$0F,$20,$E4,$CC             ;  1B415 B415 ........ ????? ?? 
.byte $20,$09,$CC,$29,$10,$D0,$0D,$A5             ;  1B41D B41D ........  ??)???? 
.byte $45,$49,$10,$85,$45,$A9,$0C,$85             ;  1B425 B425 ........ EI??E??? 
.byte $8F,$4C,$1D,$B4,$A9,$18,$85,$8F             ;  1B42D B42D ........ ?L?????? 
.byte $A5,$45,$C9,$70,$F0,$15,$20,$61             ;  1B435 B435 ........ ?E?p?? a 
.byte $C4,$A9,$78,$85,$36,$A9,$35,$85             ;  1B43D B43D ........ ??x?6?5? 
.byte $0E,$A9,$C1,$85,$0F,$20,$E4,$CC             ;  1B445 B445 ........ ????? ?? 
.byte $A2,$02,$60,$20,$C5,$D0,$A9,$FF             ;  1B44D B44D ........ ??` ???? 
.byte $85,$51,$85,$52,$85,$53,$A9,$03             ;  1B455 B455 ........ ?Q?R?S?? 
.byte $85,$55,$A9,$06,$85,$40,$A9,$03             ;  1B45D B45D ........ ?U???@?? 
.byte $85,$47,$A9,$10,$85,$48,$20,$61             ;  1B465 B465 ........ ?G???H a 
.byte $C4,$A9,$02,$85,$8E,$20,$8B,$C3             ;  1B46D B46D ........ ????? ?? 
.byte $20,$7A,$C5,$20,$B6,$CA,$20,$CC             ;  1B475 B475 ........  z? ?? ? 
.byte $CA,$20,$E2,$CA,$20,$F8,$CA,$A9             ;  1B47D B47D ........ ? ?? ??? 
.byte $F2,$85,$0E,$A9,$C8,$85,$0F,$20             ;  1B485 B485 ........ ???????  
.byte $E4,$CC,$A9,$0F,$A2,$1F,$9D,$80             ;  1B48D B48D ........ ???????? 
.byte $01,$CA,$10,$FA,$A9,$EF,$8D,$10             ;  1B495 B495 ........ ???????? 
.byte $02,$8D,$14,$02,$A9,$B4,$85,$0E             ;  1B49D B49D ........ ???????? 
.byte $A9,$C4,$85,$0F,$20,$E4,$CC,$A2             ;  1B4A5 B4A5 ........ ???? ??? 
.byte $01,$60,$E7,$E1,$ED,$E5,$C0,$EF             ;  1B4AD B4AD ........ ?`?????? 
.byte $F6,$E5,$F2,$F2,$E5,$F4,$F2,$F9             ;  1B4B5 B4B5 ........ ???????? 
.byte $E3,$EF,$EE,$F4,$E9,$EE,$F5,$E5             ;  1B4BD B4BD ........ ???????? 
.byte $86,$56,$84,$57,$A9,$08,$85,$36             ;  1B4C5 B4C5 ........ ?V?W???6 
.byte $20,$D8,$C1,$20,$35,$C1,$60                 ;  1B4CD B4CD .......   ?? 5?`  
  LDX #$F                                         ;  1B4D4 B4D4 C A2 0F           F:000453
  LDY #$7                                         ;  1B4D6 B4D6 C A0 07           F:000453
B_13_1B4D8:
  LDA R_0308,Y                                    ;  1B4D8 B4D8 C B9 08 03        F:000453
  LSR                                             ;  1B4DB B4DB C 4A              F:000453
  LSR                                             ;  1B4DC B4DC C 4A              F:000453
  LSR                                             ;  1B4DD B4DD C 4A              F:000453
  LSR                                             ;  1B4DE B4DE C 4A              F:000453
  STA PasswordEntry,X                                    ;  1B4DF B4DF C 9D 22 03        F:000453
  DEX                                             ;  1B4E2 B4E2 C CA              F:000453
  LDA R_0308,Y                                    ;  1B4E3 B4E3 C B9 08 03        F:000453
  AND #$F                                         ;  1B4E6 B4E6 C 29 0F           F:000453
  STA PasswordEntry,X                                    ;  1B4E8 B4E8 C 9D 22 03        F:000453
  DEX                                             ;  1B4EB B4EB C CA              F:000453
  DEY                                             ;  1B4EC B4EC C 88              F:000453
  BPL B_13_1B4D8                                  ;  1B4ED B4ED C 10 E9           F:000453
  LDX #$F                                         ;  1B4EF B4EF C A2 0F           F:000453
B_13_1B4F1:
  LDA R_0310,X                                    ;  1B4F1 B4F1 C BD 10 03        F:000453
  AND #$F                                         ;  1B4F4 B4F4 C 29 0F           F:000453
  STA R_0332,X                                    ;  1B4F6 B4F6 C 9D 32 03        F:000453
  DEX                                             ;  1B4F9 B4F9 C CA              F:000453
  BPL B_13_1B4F1                                  ;  1B4FA B4FA C 10 F5           F:000453
  LDA R_0320                                      ;  1B4FC B4FC C AD 20 03        F:000453
  LDX #$F                                         ;  1B4FF B4FF C A2 0F           F:000453
B_13_1B501:
  LSR                                             ;  1B501 B501 C 4A              F:000453
  ROL PasswordEntry,X                                    ;  1B502 B502 C 3E 22 03        F:000453
  DEX                                             ;  1B505 B505 C CA              F:000453
  DEX                                             ;  1B506 B506 C CA              F:000453
  BPL B_13_1B501                                  ;  1B507 B507 C 10 F8           F:000453
  LDA R_0321                                      ;  1B509 B509 C AD 21 03        F:000453
  LDX #$F                                         ;  1B50C B50C C A2 0F           F:000453
B_13_1B50E:
  LSR                                             ;  1B50E B50E C 4A              F:000453
  ROL R_0332,X                                    ;  1B50F B50F C 3E 32 03        F:000453
  DEX                                             ;  1B512 B512 C CA              F:000453
  DEX                                             ;  1B513 B513 C CA              F:000453
  BPL B_13_1B50E                                  ;  1B514 B514 C 10 F8           F:000453
  LDA #$0                                         ;  1B516 B516 C A9 00           F:000453
  LDX #$1F                                        ;  1B518 B518 C A2 1F           F:000453
B_13_1B51A:
  CLC                                             ;  1B51A B51A C 18              F:000453
  ADC PasswordEntry,X                                    ;  1B51B B51B C 7D 22 03        F:000453
  DEX                                             ;  1B51E B51E C CA              F:000453
  BPL B_13_1B51A                                  ;  1B51F B51F C 10 F9           F:000453
  STA R_0389                                      ;  1B521 B521 C 8D 89 03        F:000453
  LDA #$A                                         ;  1B524 B524 C A9 0A           F:000453
  LDX #$1F                                        ;  1B526 B526 C A2 1F           F:000453
B_13_1B528:
  EOR PasswordEntry,X                                    ;  1B528 B528 C 5D 22 03        F:000453
  DEX                                             ;  1B52B B52B C CA              F:000453
  BPL B_13_1B528                                  ;  1B52C B52C C 10 FA           F:000453
  STA R_038A                                      ;  1B52E B52E C 8D 8A 03        F:000453
  LDA R_0389                                      ;  1B531 B531 C AD 89 03        F:000453
  LDX #$E                                         ;  1B534 B534 C A2 0E           F:000453
B_13_1B536:
  LSR                                             ;  1B536 B536 C 4A              F:000453
  ROL PasswordEntry,X                                    ;  1B537 B537 C 3E 22 03        F:000453
  DEX                                             ;  1B53A B53A C CA              F:000453
  DEX                                             ;  1B53B B53B C CA              F:000453
  BPL B_13_1B536                                  ;  1B53C B53C C 10 F8           F:000453
  LDA R_038A                                      ;  1B53E B53E C AD 8A 03        F:000453
  LDX #$E                                         ;  1B541 B541 C A2 0E           F:000453
B_13_1B543:
  LSR                                             ;  1B543 B543 C 4A              F:000453
  ROL R_0332,X                                    ;  1B544 B544 C 3E 32 03        F:000453
  DEX                                             ;  1B547 B547 C CA              F:000453
  DEX                                             ;  1B548 B548 C CA              F:000453
  BPL B_13_1B543                                  ;  1B549 B549 C 10 F8           F:000453
  LDA R_0331                                      ;  1B54B B54B C AD 31 03        F:000453
  STA RNGValue+1                                      ;  1B54E B54E C 85 3A           F:000453
  LDA R_0341                                      ;  1B550 B550 C AD 41 03        F:000453
  STA RNGValue+2                                      ;  1B553 B553 C 85 3B           F:000453
  LDX #$E                                         ;  1B555 B555 C A2 0E           F:000453
B_13_1B557:
  STX R_0008                                      ;  1B557 B557 C 86 08           F:000453
  LDA #$20                                        ;  1B559 B559 C A9 20           F:000453
  JSR StepRNG                                  ;  1B55B B55B C 20 64 CC        F:000453
  LDX R_0008                                      ;  1B55E B55E C A6 08           F:000453
  EOR PasswordEntry,X                                    ;  1B560 B560 C 5D 22 03        F:000453
  STA PasswordEntry,X                                    ;  1B563 B563 C 9D 22 03        F:000453
  LDA #$20                                        ;  1B566 B566 C A9 20           F:000453
  JSR StepRNG                                  ;  1B568 B568 C 20 64 CC        F:000453
  LDX R_0008                                      ;  1B56B B56B C A6 08           F:000453
  EOR R_0332,X                                    ;  1B56D B56D C 5D 32 03        F:000453
  STA R_0332,X                                    ;  1B570 B570 C 9D 32 03        F:000453
  DEX                                             ;  1B573 B573 C CA              F:000453
  BPL B_13_1B557                                  ;  1B574 B574 C 10 E1           F:000453
  RTS                                             ;  1B576 B576 C 60              F:000453

ApplyPassword:
  ldx #$1F
: lda PasswordEntry,x
  sta R_0342,x
  dex
  bpl :-
  lda R_0351
  sta RNGValue+1
  lda R_0361
  sta RNGValue+2
  ldx #$0E
: stx R_0008
  lda #$20
  jsr StepRNG
  ldx R_0008
  eor R_0342,x
  sta R_0342,x
  lda #$20
  jsr StepRNG
  ldx R_0008
  eor R_0352,x
  sta R_0352,x
  dex
  bpl :-
  ldx #$0E
: lsr R_0352,x
  ror a
  dex
  dex
  bpl :-
  sta R_038A
  ldx #$0E
: lsr R_0342,x
  ror a
  dex
  dex
  bpl :-
  sta R_0389
  lda #$00
  ldx #$1F
: clc
  adc R_0342,x
  dex
  bpl :-
  cmp R_0389
  beq :+
  jmp @Done
: lda #$0A
  ldx #$1F
: eor R_0342,x
  dex
  bpl :-
  cmp R_038A
  beq :+
  jmp @Done
: ldx #$0F                 
: lsr R_0342,x
  ror a                    
  dex                      
  dex                      
  bpl :-
  sta R_0320                
  ldx #$0F                 
: lsr R_0352,X              
  ror a
  dex
  dex
  bpl :-
  sta R_0321                
  ldx #$0F                 
  ldy #$07                 
: lda R_0342,x             
  asl a
  asl a
  asl a
  asl a
  dex                      
  ora R_0342,x              
  dex                      
  sta R_0308,y
  dey
  bpl :-
  ldx #$0F                 
: lda R_0352,x
  sta R_0310,x
  dex                      
  bpl :-
  clc                      
  rts                      
@Done:
  lda #$1C
  sta PendingSFX
  sta R_0090
  sec
  rts
  

ResetDataAndPalette:
  ldx #$40                                        ; clear $40-$8B
: lda InitRAM000,X                                ;
  sta Tmp0,X                                      ;
  inx                                             ;
  cpx #$8C                                        ;
  bne :-                                          ;
  lda #$F                                         ; set the full palette copy to F (black)
  ldx #$1F                                        ;
: sta PaletteRAMCopy,X                            ;
  dex                                             ;
  bpl :-                                          ;
  rts                                             ; done!

ShowTitlescreen:
  lda PPUCTRLCopy                                 ;
  pha                                             ;
  and #%01111011                                  ; clear NMI and set horizontal vram increments
  sta PPU_CTRL                                    ;
  lda #$0                                         ;
  sta StatusBarEnabled                            ; disable status bar on the titlescreen
  lda PPUMASKCopy                                 ;
  pha                                             ;
  and #%11100111                                  ; disable sprite and background rendering
  sta PPU_MASK                                    ;
  lda #$20                                        ; we're re-rendering, set PPU to $2000
  sta PPU_ADDR                                    ;
  lda #$0                                         ;
  sta PPU_ADDR                                    ;
  ldx #$0                                         ; and copy all the nametables for the titlescreen
: lda TitlescreenNametables+$000,x                ;
  sta PPU_DATA                                    ;
  inx                                             ;
  bne :-                                          ;
  ldx #$0                                         ;
: lda TitlescreenNametables+$100,x                ;
  sta PPU_DATA                                    ;
  inx                                             ;
  bne :-                                          ;
  ldx #$0                                         ;
: lda TitlescreenNametables+$200,x                ;
  sta PPU_DATA                                    ;
  inx                                             ;
  bne :-                                          ;
  ldx #$0                                         ;
: lda TitlescreenNametables+$300,x                ;
  sta PPU_DATA                                    ;
  inx                                             ;
  bne :-                                          ;
  lda TitlescreenMMC3Banks                        ; set some mmc3 banking data
  sta SelectedBank0                               ;
  lda TitlescreenMMC3Banks+1                      ;
  sta SelectedBank0+1                             ;
  pla                                             ; and restore caller ppu mask and ctrl copies
  sta PPUMASKCopy                                 ;
  pla                                             ;
  sta PPUCTRLCopy                                 ;
  sta PPU_CTRL                                    ; then set ppuctrl to whatever we were called with
  rts                                             ; done!

TitleScreenFadeIn:
  lda #$40                                        ; store value  value
  sta Tmp9                                        ;
: lda #$5                                         ; delay 5 frames between upates
  sta FrameCountdownTimer                         ;
  jsr ActivateTitleScreenPalette                  ; prepare title screen palette
  ldx #$0                                         ; fade full palette
  ldy #$20                                        ; 
  jsr FadeOutPalette                              ; apply fade from Tmp9 to palette.
  jsl WaitForCountdownTimer                       ; then update ppu and delay for a bit
  lda Tmp9                                        ; reduce fade by $10
  sec                                             ;
  sbc #$10                                        ;
  sta Tmp9                                        ;
  bpl :-                                          ; and loop until we're at full brightness
  jsr UpdatePaletteFromCopy                       ; write full brightness palette to ppu
  rts                                             ; done!

FadeOutPalette:
@Loop:
  lda PaletteRAMCopy,x                            ; get palette color hue
  and #%00001111                                  ;
  sta Tmp8                                        ; store in temp location
  lda PaletteRAMCopy,x                            ; then get brightness
  and #%11110000                                  ;
  sec                                             ;
  sbc Tmp9                                        ; reduce by fixed amount
  bcs :+                                          ;
  lda #%00001111                                  ; set to black if underflowed
  jmp @Update                                     ;
: ora Tmp8                                        ; restore hue
@Update:
  sta PaletteRAMCopy,x                            ; write new value
  inx                                             ; select next palette color
  dey                                             ;
  bne @Loop                                       ; and loop until done
  rts                                             ; done!

ActivateTitleScreenPalette:
  ldx #$1F                                        ; copy full palette
: lda TitleScreenPalette,X                        ;
  sta PaletteRAMCopy,X                            ;
  dex                                             ;
  bpl :-                                          ; loop until all is copied
  rts                                             ; done!

DemoSprites:
.byte $80,$C1,$00,$60
.byte $80,$C3,$00,$68
.byte $80,$C5,$00,$70
.byte $80,$C7,$00,$78
.byte $80,$C9,$00,$80
.byte $80,$CB,$00,$88
.byte $80,$CD,$00,$90
.byte $80,$CF,$00,$98
DemoSpritesEnd:

TitleScreenSprites:
.byte $6E,$01,$00,$60 ; P
.byte $6E,$03,$00,$68 ; U
.byte $6E,$05,$00,$70 ; S 
.byte $6E,$07,$00,$78 ; H
.byte $6E,$09,$00,$80 ; ST
.byte $6E,$0B,$00,$88 ; A
.byte $6E,$0D,$00,$90 ; R
.byte $6E,$0F,$00,$98 ; T
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
.byte $F8,$F8,$F8,$F8
TitleScreenSpritesEnd:

GameCreditsText:
.byte "            CREDITS",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte "             CAST",$0D
.byte $0D
.byte $0D
.byte "      Warrior  Xemn Worzen",$0D
.byte $0D
.byte "       Wizard  Mayna Worzen",$0D
.byte $0D
.byte "       Ranger  Roas Worzen",$0D
.byte $0D
.byte "          Elf  Lyll Worzen",$0D
.byte $0D
.byte "      Monster  Pochi",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte "            Monsters",$0D
.byte $0D
.byte $0D
.byte "      King Dragon  Keela  ",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte "           Taratunes",$0D
.byte "           Archwinger",$0D
.byte "           Erebone",$0D
.byte "           Rockgaea",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte "    Rock Veest         Mu",$0D
.byte "     Moricdo       Roid Moon",$0D
.byte "      Garba        Killer Bat",$0D
.byte "     Kraugen          Kimu",$0D
.byte "      Gridel        Crawler",$0D
.byte "    Snake Kid         Aryu",$0D
.byte "   Yashinotkin        Gers",$0D
.byte " Derudeathgadedo    Skeleton",$0D
.byte "       Slug          Tiger",$0D
.byte "     Cyclops         Mummy",$0D
.byte "    Lizard Man       Dwarf",$0D
.byte "      Giant           Orc",$0D
.byte "    Elemental        Writh",$0D
.byte "     Egg-man         Mimic",$0D
.byte "       Rock          Slime",$0D
.byte "    lightball        Prandi",$0D
.byte "      Memes          Golem",$0D
.byte "      Monch          Wizard",$0D
.byte "     Frog-man         Mayu",$0D
.byte "     Daru-do         Kirru",$0D
.byte "     Bupurch         Dorak",$0D
.byte "       Lion        Flail Snail",$0D
.byte "      Roman        Meta Black",$0D
.byte "       Edo",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte "            STAFF",$0D
.byte $0D
.byte $0D
.byte "        Scenario Staff",$0D
.byte $0D
.byte "            Hatabow",$0D
.byte "            Onyanko",$0D
.byte "            Ganchan",$0D
.byte "            Dr. Key",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte "          Programming",$0D
.byte $0D
.byte "            Dr. Key",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte "     Programming assistance",$0D
.byte $0D
.byte "            Hatabow",$0D
.byte "            Onyanko",$0D
.byte $0D
.byte $0D
.byte $0D
.byte "         Art & Graphic",$0D
.byte $0D
.byte "            Ganchan",$0D
.byte "            Kaijin",$0D
.byte "         Nowten Musume",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte "             Music",$0D
.byte $0D
.byte "            Koshiron",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte "            Produce",$0D
.byte $0D
.byte "            Shachow",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte "    Legacy of the Wizard",$0D
.byte $0D
.byte "        @1987  Falcom",$0D
.byte "@1988 Broderbund Software, Inc.",$0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
.byte $0D
GameCreditsTextEnd:

; unused padding
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $44,$51,$45,$50,$44,$60,$47,$4C,$4C,$46,$48,$49,$45,$C0,$C1,$C0
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $61,$61,$1A,$46,$45,$45,$47,$4B,$45,$74,$74,$45,$C0,$C1,$C0,$C0
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
