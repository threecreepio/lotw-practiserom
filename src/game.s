ResetGame:
  sei                                             ; standard boot
  ldx #$FF                                        ;
  txs                                             ;
  lda #$0                                         ; reset rendering and audio
  sta PPU_CTRL                                    ;
  sta PPU_MASK                                    ;
  sta APU_DMCFREQ                                 ;
  lda #$1F                                        ;
  sta a:R_0027                                    ;
  sta APU_STATUS                                  ;
  lda #$C0                                        ;
  sta JOYPAD2_FrameCtr                            ;
: lda PPU_STATUS                                  ;
  bpl :-                                          ; delay until ppu startup
: lda PPU_STATUS                                  ;
  bpl :-                                          ; delay until ppu startup
RebootGame:
  ldx #$FF                                        ; clear stack again (its already clear though)
  txs                                             ;
  lda #$0                                         ; set mmc3 mirroring
  sta MMC3_NametableMirroring                     ;
  JSR MMC3UseCommonBank                           ; make sure we're on the common mmc3 banks
  jmp :+                                          ; skip over unused code
  .byte $80                                       ; invalid instruction, unused code
  lda #$07                                        ; (unused) re-set our mmc3 bank
  sta MMC3LastBankSelect                          ; (unused)
  sta MMC3_RegBankSelect                          ; (unused)
  lda #$0D                                        ; (unused)
  sta MMC3_RegBankData                            ; (unused)
: jsr SetupDefaultRAMState                        ; ram init
  jsl_menu RunTitleScreen

@ResetGame:
  lda #$0                                         ; set starting game state
  sta PlayerStunTimer                             ;
  sta CameraXPx                                   ;
  sta PlayerXPx                                   ;
  lda #$30                                        ;
  sta CameraXTile                                 ;
  lda #$3C                                        ;
  sta PlayerXTile                                 ;
  lda #$A0                                        ;
  sta PlayerYPx                                   ;
  jsr LoadNewAreaData                             ; load in the starting area
  lda #CtlU                                       ; starting frame inputs for some reason
  sta JoypadInput                                 ;
  jsr HandlePlayerControls                        ;
@RunGameFrame:
  lda PlayerHP                                    ; is player still alive?
  bne @InGame                                     ; yep - skip ahead
  lda #$0                                         ; no - we are dying.
  sta InvincibilityFramesTimer                    ; clear iframes to prevent flickering player
  jsr UpdatePlayerSprites                         ; redraw the player
  jsl_menu RunGameOverScreen                      ; display the game over screen
  cpx #$0                                         ; did player request to continue?
  bne @CheckForReset                              ; otherwise check if player is resetting
  jmp @RunGameFrame                               ; continue game!
@CheckForReset:
  dex                                             ; check if player selected to reset
  bne @Reboot                                     ; if not.. i guess we reboot.
  jmp @ResetGame                                  ; otherwise we reset!
@Reboot:
  jmp RebootGame                                  ; if no valid option was selected we reboot

@InGame:
  lda #$1                                         ; prepare single-frame delay
  sta FrameCountdownTimer                         ;
  lda CameraXTile                                 ; copy current x tile in case it changes
  sta CurrentCameraXTile                          ;
  jsr ReadJoypad                                  ;
  jsr HandlePlayerControls                        ; deal with player inputs
  lda DragonEncounterActive                       ; are we fighting the dragon?
  bne @DragonEncounter                            ; if so - skip to the special dragon handling code!
  jsr RunProjectileEntities                       ; run all projectile entities
  JSR RunEnemyEntities                            ; run all enemy entities
  jsr RunBlockSwapEntity                          ; run entity used for breaking or moving tiles
  jsr UpdateCameraPosition                        ; position camera relative to the player
  php                                             ;
  jsr UpdatePlayerSprites                         ; redraw player
  jsr UpdateEntitySprites                         ; redraw entities
  plp                                             ; restore camera carry flag
  bcs :+                                          ; if we shouldn't wait for ppu updates, skip ahead
  lda CurrentCameraXTile                          ; have we changed tiles?
  cmp CameraXTile                                 ;
  beq :+                                          ; if not - skip ahead
  inc ColumnWritePending                          ; otherwise mark that we need to write a new column to the ppu
: jsr WaitForCountdownTimer                       ; wait for timer to finish
  jmp @RunGameFrame                               ; run next frame!

@DragonEncounter:
  jsl_menu DragonRoutine1
: jsr ReadJoypad                                  ; refresh joypad state
  jsl_menu DragonRoutine2
  jsl_menu DragonRoutine3
  jsl_menu DragonRoutine4
  jsl_menu DragonRoutine5
  lda PlayerHP                                    ; is the player alive?
  bne :-                                          ; if so - keep looping dragon routines
  lda PlayerXPx                                   ; convert full pixel position to tile
  lsr a                                           ;
  lsr a                                           ;
  lsr a                                           ;
  lsr a                                           ;
  sta PlayerXTile                                 ; and update position
  lda PlayerXPx                                   ; then remove tile position from pixel position
  and #$F                                         ;
  sta PlayerXPx                                   ;
  lda #$EF                                        ; move spr0 offscreen
  sta SprY                                        ;
  lda #$0                                         ; clear iframes to prevent flashing
  sta InvincibilityFramesTimer                    ;
  jsr UpdatePlayerSprites                         ; and make sure the player is drawn
  jsl_menu RunGameOverScreen                      ; let the player know they've failed miserably
  dex                                             ; does the player wish to reset?
  bne :+                                          ; no - continue to reboot
  jmp @ResetGame                                  ; yes - continue!
: jmp RebootGame                                  ; reboot the game. :(

WaitForCountdownTimer:
  lda ColumnWritePending                          ; is there a pending update to load in new tiles?
  beq :+                                          ; if not just skip ahead
  lda #$0                                         ; otherwise we write new tiles, mark update as complete
  sta ColumnWritePending                          ;
  jsr DrawMetatileColumnAtEdge                    ;
  jmp @WaitForTimer                               ; then wait for the timer to finish
: lda StatusbarUpdatePending                      ; do we need to update the status bar?
  beq :+                                          ; if not just skip ahead
  lda #$0                                         ; otherwise we update the status bar, mark update as complete
  sta StatusbarUpdatePending                      ;
  jsr UpdateStatusbar                             ; and update the status bar
  JMP @WaitForTimer                               ; then wait for the timer to finish
: lda FrameCountdownTimer                         ; is the timer active?
  beq @WaitForTimer                               ; if not - just skip ahead
  jsr UpdatePaletteFromCopy                       ; otherwise update the palette, we're probably fading screens
@WaitForTimer:
  lda FrameCountdownTimer                         ; are we still waiting?
  bne @WaitForTimer                               ; if so - loop!
  rts                                             ; otherwise we are done!

UpdateCameraPosition:
  lda CameraXTile                                 ; combine camera x position to single byte
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  ora CameraXPx                                   ;
  sta Tmp8                                        ; and store in temp value
  lda PlayerXTile                                 ; combine player x position to single byte
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  ora PlayerXPx                                   ;
  sec                                             ; subtract camera x from player x
  sbc Tmp8                                        ;
  cmp #$60                                        ; are we near the left edge?
  bcc @ScrollCameraLeft                           ; if so - scroll left
  cmp #$91                                        ; are we closer to the right edge?
  BCC @UpdatePPUScrollSEC                         ; if not we're in the middle, no need to scroll
  lda CameraXTile                                 ; check camera x position
  cmp #$30                                        ; are we right by the edge of the area?
  bcs @FixCameraRight                             ; if so - stop scrolling
  lda PlayerXTile                                 ; otherwise fix camera to 9 tiles behind the player
  sec                                             ;
  sbc #$9                                         ;
  sta CameraXTile                                 ;
  lda PlayerXPx                                   ;
  sta CameraXPx                                   ;
  lda #$1                                         ; and mark that we are scrolling right
  sta ScreenScrollDirection                       ;
  jmp @UpdatePPUScrollCLC                         ; finish up

@FixCameraRight:
  lda #$30                                        ; we can't scroll more, fix camera to edge
  sta CameraXTile                                 ;
  lda #$0                                         ;
  sta CameraXPx                                   ;
  JMP @UpdatePPUScrollSEC                         ; finish up

@ScrollCameraLeft:
  lda CameraXTile                                 ; is the camera fixed at the left edge?
  ora CameraXPx                                   ;
  beq @UpdatePPUScrollSEC                         ; if so - exit
  lda PlayerXTile                                 ; otherwise try to set the camera 6 tiles left of the player
  sec                                             ;
  sbc #$6                                         ;
  bcc @FixCameraLeft                              ; if we wrap, fix the camera to the left edge of the area
  sta CameraXTile                                 ; otherwise update the camera position
  lda PlayerXPx                                   ;
  sta CameraXPx                                   ;
  lda #$FF                                        ; and mark that we are scrolling left
  sta ScreenScrollDirection                       ;
  JMP @UpdatePPUScrollCLC                         ; finish up

@FixCameraLeft:
  lda #$0                                         ; we can't scroll more, fix camera to edge
  sta CameraXPx                                   ;
  sta CameraXTile                                 ;
@UpdatePPUScrollCLC:
  jsr UpdateCameraPPUScroll                       ; update scroll register copy
  clc                                             ; we need to update the ppu
  rts                                             ; done!
@UpdatePPUScrollSEC:
  jsr UpdateCameraPPUScroll                       ; set ppu scroll
  sec                                             ; we do not need to update the ppu
  rts                                             ; done!

UpdateCameraPPUScroll:
  lda CameraXTile                                 ; multiply x tile by 16 to get pixel position
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  ora CameraXPx                                   ; and add in subtile pixel position
  tax                                             ; move to X for no good reason
  lda #$0                                         ; if we overflowed, we will be in the second nametable
  rol a                                           ;
  stx PPUHScrollCopy                              ; set scroll value
  sta PPUActiveNametable                          ; and set nametable value
  rts                                             ; done!

UpdatePlayerSprites:
  @Tmp8 = $8
  lda InvincibilityFramesTimer                    ; check if player is in iframes
  beq @Update                                     ; nope - skip ahead to draw the player
  lda IntervalTimer                               ; yep - player will flash at 30hz, are we on an odd frame?
  and #$1                                         ;
  bne @Update                                     ; yep - draw player!
  lda #$EF                                        ; no - move player sprite off screen
  sta PlayerSpr0Y                                 ;
  sta PlayerSpr1Y                                 ;
  rts                                             ; and exit
@Update:
  lda PlayerYPx                                   ; shift player down to account for the title bar
  clc                                             ;
  adc #StatusBarHeight                            ;
  sta PlayerSpr0Y                                 ; and set as sprite Y
  sta PlayerSpr1Y                                 ;
  lda CameraXTile                                 ; put camera pixel position in temp location
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  ora CameraXPx                                   ;
  sta @Tmp8                                       ;
  lda PlayerXTile                                 ; calculate player pixel position
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  ora PlayerXPx                                   ;
  sec                                             ; and subtract camera position from player position
  sbc @Tmp8                                       ;
  sta PlayerSpr0X                                 ; position player X sprites at determined location
  clc                                             ;
  adc #$8                                         ;
  sta PlayerSpr1X                                 ;
  lda PlayerSpriteAttr                            ; set sprite attributes
  sta PlayerSpr0Attr                              ;
  sta PlayerSpr1Attr                              ;
  ldx PlayerSpriteTile                            ; get tile number of player sprite
  bit PlayerSpriteAttr                            ; are we inverting sprite order?
  bvs @Inverted                                   ; if so - skip ahead
  stx PlayerSpr0Tile                              ; set first sprite
  inx                                             ; advance 2 tiles to get next side
  inx                                             ;
  stx PlayerSpr1Tile                              ; and set second sprite
  rts                                             ; done!
@Inverted:
  stx PlayerSpr1Tile                              ; set second sprite
  inx                                             ; advance 2 tiles to get next side
  inx                                             ;
  stx PlayerSpr0Tile                              ; and set first sprite
  rts                                             ; done!

UpdateInventorySprites:
  lda PlayerSelectedItemSlot                      ; get which inventory slot is selected
  cmp #$3                                         ; check if no item is selected
  ldx #$13                                        ; default Y position
  bcc :+                                          ; if there is a selected item - skip ahead
  ldx #$EF                                        ; otherwise move the sprite off screen
  stx SprInventorySelectY                         ;
  stx SprInventorySelectY+4                       ;
  jmp @UpdateItems                                ; then skip ahead
: stx SprInventorySelectY                         ; set default Y position
  stx SprInventorySelectY+4                       ;
  asl a                                           ; multiply selected slot by 16
  asl a                                           ; which is the spacing between slots
  asl a                                           ;
  asl a                                           ;
  clc                                             ;
  adc #$C8                                        ; and add the offset from the left of the screen
  sta SprInventorySelectX                         ; to use as the position for the selection box
  clc                                             ;
  adc #$8                                         ;
  Sta SprInventorySelectX+4                       ;
  lda #$FF                                        ; set attributes
  sta SprInventorySelectAttr                      ;
  sta SprInventorySelectAttr+4                    ;
  lda #$1                                         ; and which sprites to use
  sta SprInventorySelectTile                      ;
  lda #$41                                        ;
  sta SprInventorySelectTile+4                    ;
@UpdateItems:
  ldx #$2                                         ; looping through each slot
  ldy #$10                                        ;
@Loop:
  lda PlayerActiveItems,x                         ; check item in slot
  bmi @EmptySlot                                  ; empty - skip
  asl a                                           ; multiply item id by 4
  asl a                                           ;
  clc                                             ;
  adc #$A1                                        ; and add offset in sprite table
  sta SprInventorySlotTile,y                      ; use those as the sprite tiles
  clc                                             ;
  adc #$2                                         ;
  sta SprInventorySlotTile+4,y                    ;
  tya                                             ; calculate X position of slot
  asl a                                           ;
  clc                                             ;
  adc #$C8                                        ;
  sta SprInventorySlotX,y                         ;
  clc                                             ;
  adc #$8                                         ;
  Sta SprInventorySlotX+4,y                       ;
  lda #$1                                         ; always use palette 1
  sta SprInventorySlotAttr,y                      ;
  sta SprInventorySlotAttr+4,y                    ;
  lda #$13                                        ; default Y position
  jmp :+                                          ; skip moving off screen
@EmptySlot:
  lda #$EF                                        ; set off screen Y position
: sta SprInventorySlotY,y                         ; set Y position of sprites
  sta SprInventorySlotY+4,y                       ;
  tya                                             ; next sprite slot is 8 before this one
  sec                                             ;
  sbc #$8                                         ;
  tay                                             ;
  dex                                             ;
  bpl @Loop                                       ; keep going until each item has rendered
  rts                                             ; done!

UpdateEntitySprites:
  LDA #$10                                        ;  1C2B1 C2B1 C A9 10           F:001373
  STA TmpA                                      ;  1C2B3 C2B3 C 85 0A           F:001373
  LDX R_003F                                      ;  1C2B5 C2B5 C A6 3F           F:001373
  LDY R_003E                                      ;  1C2B7 C2B7 C A4 3E           F:001373
B_14_1C2B9:
  JSR L_14_1C2DB                                  ;  1C2B9 C2B9 C 20 DB C2        F:001373
  TXA                                             ;  1C2BC C2BC C 8A              F:001373
  CLC                                             ;  1C2BD C2BD C 18              F:001373
  ADC #$8                                         ;  1C2BE C2BE C 69 08           F:001373
  ORA #$80                                        ;  1C2C0 C2C0 C 09 80           F:001373
  TAX                                             ;  1C2C2 C2C2 C AA              F:001373
  TYA                                             ;  1C2C3 C2C3 C 98              F:001373
  CLC                                             ;  1C2C4 C2C4 C 18              F:001373
  ADC #$30                                        ;  1C2C5 C2C5 C 69 30           F:001373
  TAY                                             ;  1C2C7 C2C7 C A8              F:001373
  DEC TmpA                                      ;  1C2C8 C2C8 C C6 0A           F:001373
  BNE B_14_1C2B9                                  ;  1C2CA C2CA C D0 ED           F:001373
  TXA                                             ;  1C2CC C2CC C 8A              F:001373
  CLC                                             ;  1C2CD C2CD C 18              F:001373
  ADC #$38                                        ;  1C2CE C2CE C 69 38           F:001373
  ORA #$80                                        ;  1C2D0 C2D0 C 09 80           F:001373
  STA R_003F                                      ;  1C2D2 C2D2 C 85 3F           F:001373
  TYA                                             ;  1C2D4 C2D4 C 98              F:001373
  CLC                                             ;  1C2D5 C2D5 C 18              F:001373
  ADC #$10                                        ;  1C2D6 C2D6 C 69 10           F:001373
  STA R_003E                                      ;  1C2D8 C2D8 C 85 3E           F:001373
  RTS                                             ;  1C2DA C2DA C 60              F:001373

L_14_1C2DB:
  lda Ent0Data+Ent_State,y                               ; is entity active?
  beq @MoveOffScreen                              ; if so - don't show sprites
  lda Ent0Data+Ent_YPx,y                          ; check if entity is on screen
  cmp #$BF                                        ;
  bcs @MoveOffScreen                              ; if not - don't show sprites
  lda Ent0Data+Ent_SprAttr,y                      ; set sprite attributes
  sta SprAttr,x                                   ;
  sta SprAttr+4,x                                 ;
  and #%01000000                                  ; are we inverting the sprite?
  bne @Flipped                                    ; if so - set tiles backwards
  lda Ent0Data,y                                  ; get entity sprite
  sta SprX,X                                      ;
  adc #$2                                         ; get second side
  sta SprX+4,X                                    ;
  jmp :+                                          ; and continue
@Flipped:
  lda Ent0Data,y                                  ; get entity sprite
  sta SprX+4,x                                    ; and update in inverted order
  adc #$2                                         ;
  sta SprX,x                                      ;
: lda Ent0Data+Ent_XPx,y                          ; get position inside tile
  sec                                             ;
  sbc CameraXPx                                   ; offset by camera pixel
  and #%00001111                                  ; only keep the 0-15px portion
  sta Tmp8                                        ; and store in temp
  lda Ent0Data+Ent_XTile,y                        ; then get the full tile position
  sbc CameraXTile                                 ; offset by camera tile position
  cmp #$10                                        ; are we too far to the right?
  bcs @MoveOffScreen                              ; if so - skip drawing the sprite
  asl a                                           ; multiply to screen pixel position
  asl a                                           ;
  asl a                                           ;
  asl a                                           ;
  ora Tmp8                                        ; combine with the subtile position
  sta Tmp8                                        ; and store in temp value
  lda Ent0Data+Ent_State,y                        ; check if entity is in damaged state
  cmp #EntState_Damaged                           ;
  bne :+                                          ; if not - skip head
  lda Ent0Data+Ent_VibrateX,y                     ; check if entity should vibrate
  beq :+                                          ; if not - skip ahead
  clc                                             ;
  adc Tmp8                                        ; otherwise add to the x position
  sta Tmp8                                        ; to create a little shake
  lda #$0                                         ;
  sta Ent0Data+Ent_VibrateX,y                     ; and clear damage flag
: lda Tmp8                                        ; are we too far right to show both sprites?
  cmp #$EF                                        ;
  bcs @ShowSingleSprite                           ; if so - only draw a single sprite
  sta SprTile,x                                   ; otherwise set left sprite
  clc                                             ;
  adc #$8                                         ;
  sta SprTile+4,x                                 ; then right sprite
  lda Ent0Data+Ent_YPx,y                          ; and set y position
  clc                                             ;
  adc #StatusBarHeight                            ; underneath the status bar
  sta SprY,x                                      ;
  sta SprY+4,x                                    ;
  rts                                             ; done!
@MoveOffScreen:
  lda #$EF                                        ; move both sprites off screen
  sta SprY,x                                      ;
  sta SprY+4,x                                    ;
  rts                                             ; done!
@ShowSingleSprite:
  sta SprTile,x                                   ; otherwise set left sprite
  lda Ent0Data+Ent_YPx,y                          ; and set y position
  clc                                             ;
  adc #StatusBarHeight                            ; underneath the status bar
  sta SprY,x                                      ;
  lda #$EF                                        ; and place second sprite off screen
  sta SprY+4,x                                    ;
  rts                                             ; done!

SetupSpr0AndClearSprites:
  ldx #3                                          ; copy sprite 0 to under the title bar
: lda Spr0Data,X                                  ;
  sta SprY,X                                      ;
  dex                                             ;
  bpl :-                                          ;
  ldx #$4                                         ; clear remaining sprites off screen
: lda #$F8                                        ;
  sta SprY,x                                      ;
  inx                                             ;
  bne :-                                          ;
  rts                                             ; done!

L_14_1C38B:
  LDA PPUCTRLCopy                                      ;  1C38B C38B C A5 23           F:001345
  PHA                                             ;  1C38D C38D C 48              F:001345
  AND #$7B                                        ;  1C38E C38E C 29 7B           F:001345
  STA PPU_CTRL                                    ;  1C390 C390 C 8D 00 20        F:001345
  LDA #$0                                         ;  1C393 C393 C A9 00           F:001345
  STA StatusBarEnabled                                      ;  1C395 C395 C 85 29           F:001345
  LDA PPUMASKCopy                                      ;  1C397 C397 C A5 24           F:001345
  PHA                                             ;  1C399 C399 C 48              F:001345
  AND #$E7                                        ;  1C39A C39A C 29 E7           F:001345
  STA PPU_MASK                                    ;  1C39C C39C C 8D 01 20        F:001345
  LDA #$20                                        ;  1C39F C39F C A9 20           F:001345
  STA PPU_ADDR                                    ;  1C3A1 C3A1 C 8D 06 20        F:001345
  LDA #$0                                         ;  1C3A4 C3A4 C A9 00           F:001345
  STA PPU_ADDR                                    ;  1C3A6 C3A6 C 8D 06 20        F:001345
  LDA #$C0                                        ;  1C3A9 C3A9 C A9 C0           F:001345
  LDY #$5                                         ;  1C3AB C3AB C A0 05           F:001345
B_14_1C3AD:
  LDX #$C0                                        ;  1C3AD C3AD C A2 C0           F:001345
B_14_1C3AF:
  STA PPU_DATA                                    ;  1C3AF C3AF C 8D 07 20        F:001345
  DEX                                             ;  1C3B2 C3B2 C CA              F:001345
  BNE B_14_1C3AF                                  ;  1C3B3 C3B3 C D0 FA           F:001345
  DEY                                             ;  1C3B5 C3B5 C 88              F:001345
  BNE B_14_1C3AD                                  ;  1C3B6 C3B6 C D0 F5           F:001345
  LDA #$0                                         ;  1C3B8 C3B8 C A9 00           F:001346
  LDX #$40                                        ;  1C3BA C3BA C A2 40           F:001346
B_14_1C3BC:
  STA PPU_DATA                                    ;  1C3BC C3BC C 8D 07 20        F:001346
  DEX                                             ;  1C3BF C3BF C CA              F:001346
  BNE B_14_1C3BC                                  ;  1C3C0 C3C0 C D0 FA           F:001346
  LDA #$C0                                        ;  1C3C2 C3C2 C A9 C0           F:001346
  LDY #$5                                         ;  1C3C4 C3C4 C A0 05           F:001346
B_14_1C3C6:
  LDX #$C0                                        ;  1C3C6 C3C6 C A2 C0           F:001346
B_14_1C3C8:
  STA PPU_DATA                                    ;  1C3C8 C3C8 C 8D 07 20        F:001346
  DEX                                             ;  1C3CB C3CB C CA              F:001346
  BNE B_14_1C3C8                                  ;  1C3CC C3CC C D0 FA           F:001346
  DEY                                             ;  1C3CE C3CE C 88              F:001346
  BNE B_14_1C3C6                                  ;  1C3CF C3CF C D0 F5           F:001346
  LDA #$0                                         ;  1C3D1 C3D1 C A9 00           F:001346
  LDX #$40                                        ;  1C3D3 C3D3 C A2 40           F:001346
B_14_1C3D5:
  STA PPU_DATA                                    ;  1C3D5 C3D5 C 8D 07 20        F:001346
  DEX                                             ;  1C3D8 C3D8 C CA              F:001346
  BNE B_14_1C3D5                                  ;  1C3D9 C3D9 C D0 FA           F:001346
  PLA                                             ;  1C3DB C3DB C 68              F:001346
  STA PPUMASKCopy                                      ;  1C3DC C3DC C 85 24           F:001346
  PLA                                             ;  1C3DE C3DE C 68              F:001346
  STA PPUCTRLCopy                                      ;  1C3DF C3DF C 85 23           F:001346
  STA PPU_CTRL                                    ;  1C3E1 C3E1 C 8D 00 20        F:001346
  RTS                                             ;  1C3E4 C3E4 C 60              F:001346

L_14_1C3E5:
  INC R_0092                                      ;  1C3E5 C3E5 C E6 92           F:000172
  ldy #$4                                         ; number of times to run palette update
@LoopUpdate:
  tya                                             ; store iteration counter on stack
  pha                                             ;
  lda #$5                                         ; delaying 5 frames between animation steps
  sta FrameCountdownTimer                         ;
  ldx #7*4                                        ; update all but first palette
@Loop:
  lda PaletteRAMCopy+4,x                          ; get palette color hue
  and #%00001111                                  ;
  sta Tmp8                                        ; store in temp location
  lda PaletteRAMCopy+4,x                          ; then get brightness
  and #%11110000                                  ;
  sec                                             ;
  sbc #$10                                        ; reduce by fixed amount
  bcs :+                                          ;
  lda #%00001111                                  ; set to black if underflowed
  jmp @Update                                     ;
: ora Tmp8                                        ; restore hue
@Update:
  sta PaletteRAMCopy+4,x                          ; write new value
  dex                                             ;
  bpl @Loop                                       ; and loop until done
  LSR R_00A0                                      ;  1C40F C40F C 46 A0           F:000172
  LSR R_00B0                                      ;  1C411 C411 C 46 B0           F:000172
  LSR R_00D0                                      ;  1C413 C413 C 46 D0           F:000172
  LDA #$0                                         ;  1C415 C415 C A9 00           F:000172
  STA R_00B4                                      ;  1C417 C417 C 85 B4           F:000172
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  PLA                                             ;  1C41C C41C C 68              F:000177
  TAY                                             ;  1C41D C41D C A8              F:000177
  dey                                             ;
  bne @LoopUpdate                                 ; loop update until complete
  lda #SFX_Off                                   ; halt music
  STA CurrentMusic                                ;
  LDA #$0                                         ;  1C425 C425 C A9 00           F:000192
  STA R_0094                                      ;  1C427 C427 C 85 94           F:000192
  STA R_00A4                                      ;  1C429 C429 C 85 A4           F:000192
  STA R_00C4                                      ;  1C42B C42B C 85 C4           F:000192
  STA R_0092                                      ;  1C42D C42D C 85 92           F:000192
  RTS                                             ;  1C42F C42F C 60              F:000192

L_14_1C430:
  ldy #$4                                         ; run 4 times
@LoopUpdate:
  tya                                             ; store iteration counter on stack
  pha                                             ;
  lda #$5                                         ; delaying 5 frames between animation steps
  sta FrameCountdownTimer                         ;
  ldx #7*4                                        ; update all but first palette
@Loop:
  lda PaletteRAMCopy+4,x                          ; get palette color hue
  and #%00001111                                  ;
  sta Tmp8                                        ; store in temp location
  lda PaletteRAMCopy+4,x                          ; then get brightness
  and #%11110000                                  ;
  sec                                             ;
  sbc #$10                                        ; reduce by fixed amount
  bcs :+                                          ;
  lda #%00001111                                  ; set to black if underflowed
  jmp @Update                                     ;
: ora Tmp8                                        ; restore hue
@Update:
  sta PaletteRAMCopy+4,x                          ; write new value
  dex                                             ;
  bpl @Loop                                       ; and loop until done
  jsr WaitForCountdownTimer                       ; wait for fade to complete
  pla                                             ; restore iteration counter from stack
  tay                                             ;
  dey                                             ;
  bne @LoopUpdate                                 ; and loop until done
  rts                                             ; done!

FadeInPalette2:
  ldy #$4                                         ; run 4 times
@LoopUpdate:
  tya                                             ; store iteration counter on stack
  pha                                             ;
  lda #$5                                         ; delaying 5 frames between animation steps
  sta FrameCountdownTimer                         ;
  ldx #8*4                                        ; fade out full palette
@Loop:
  lda PaletteRAMCopy,x                            ; get palette color hue
  and #%00001111                                  ;
  sta Tmp8                                        ; store in temp location
  lda PaletteRAMCopy,x                            ; then get brightness
  and #%11110000                                  ;
  sec                                             ;
  sbc #$10                                        ; reduce by fixed amount
  bcs :+                                          ;
  lda #%00001111                                  ; set to black if underflowed
  jmp @Update                                     ;
: ora Tmp8                                        ; restore hue
@Update:
  sta PaletteRAMCopy,x                            ; write new value
  dex                                             ; advance to next color
  bpl @Loop                                       ; loop until all colors faded
  jsr WaitForCountdownTimer                       ; wait for fade to complete
  pla                                             ; restore iteration counter from stack
  tay                                             ;
  dey                                             ;
  bne @LoopUpdate                                 ; and loop until done
  rts                                             ; done!

FadeInAreaPalette:
  @Fade = $09
  lda #$40                                        ; first pass all colors should be subtracted by 40, making them black
  sta @Fade                                       ;
: lda #$5                                         ; delay between updates
  sta FrameCountdownTimer                         ;
  jsr AreaPaletteSetup                            ; copy palette from area
  ldx #$4                                         ; offset into palette to start changing
  ldy #$1C                                        ; number of bytes to update
  jsr FadeOutPalette2                             ; set up fade
  jsr WaitForCountdownTimer                       ; wait for fade to complete
  lda @Fade                                       ; every pass we want to subtract by $10 less, fading the colors in
  sec                                             ;
  sbc #$10                                        ;
  sta @Fade                                       ;
  bpl :-                                          ; loop until full bright
  jsr UpdatePaletteFromCopy                       ; make sure the full bright palette is sent to the ppu
  rts                                             ; done!

.byte $A9,$40,$85,$09,$A9,$05,$85,$36             ;  1C4B4 C4B4 ........ ?@?????6 
.byte $A2,$04,$A0,$E0,$B1,$77,$99,$A0             ;  1C4BC C4BC ........ ?????w?? 
.byte $00,$C8,$CA,$D0,$F7,$A2,$00,$A0             ;  1C4C4 C4C4 ........ ???????? 
.byte $04,$20,$20,$C5,$20,$35,$C1,$A5             ;  1C4CC C4CC ........ ?  ? 5?? 
.byte $09,$38,$E9,$10,$85,$09,$10,$DC             ;  1C4D4 C4D4 ........ ?8?????? 
.byte $20,$69,$C5,$60,$A9,$40,$85,$09             ;  1C4DC C4DC ........  i?`?@?? 
.byte $A9,$05,$85,$36,$A2,$04,$A0,$E0             ;  1C4E4 C4E4 ........ ???6???? 
.byte $B1,$77,$99,$A0,$00,$C8,$CA,$D0             ;  1C4EC C4EC ........ ?w?????? 
.byte $F7,$A2,$04,$A0,$F0,$B1,$77,$99             ;  1C4F4 C4F4 ........ ??????w? 
.byte $A0,$00,$C8,$CA,$D0,$F7,$A2,$00             ;  1C4FC C4FC ........ ???????? 
.byte $A0,$04,$20,$20,$C5,$A2,$10,$A0             ;  1C504 C504 ........ ??  ???? 
.byte $04,$20,$20,$C5,$20,$35,$C1,$A5             ;  1C50C C50C ........ ?  ? 5?? 
.byte $09,$38,$E9,$10,$85,$09,$10,$C8             ;  1C514 C514 ........ ?8?????? 
.byte $20,$69,$C5,$60                             ;  1C51C C51C ....      i?`     

FadeOutPalette2:
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

LightningFlashScreen:
@Loop:
  txa                                             ; store caller X as repetitions
  pha                                             ;
  lda #$30                                        ; set full palette to bright white
  ldx #$1F                                        ;
: sta PaletteRAMCopy,x                            ;
  dex                                             ;
  bpl :-                                          ; loop until copied
  jsr UpdatePaletteFromCopy                       ; write palette
  lda #$1                                         ; delay for a bit
  sta FrameCountdownTimer                         ;
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  jsr AreaPaletteSetup                            ; get palette for new area
  jsr UpdatePaletteFromCopy                       ; and write it to ppu
  lda #$2                                         ; then delay a bit again
  sta FrameCountdownTimer                         ;
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  pla                                             ; restore caller X
  tax                                             ;
  dex                                             ; and decrement
  bne @Loop                                       ; if we're still looping, go back around
  rts                                             ; done!

UpdatePaletteFromCopy:
  jsr WaitForPPUOp                                ; wait for any pending ppu operation to complete
  lda #<$3F00                                     ; set ppu target position
  sta PPUUpdateAddrLo                             ;
  lda #>$3F00                                     ;
  sta PPUUpdateAddrHi                             ;
  lda #PPUOps_UpdatePalette                       ; then trigger the ppu update next frame
  jsr RunPPUOp                                    ;
  rts                                             ; done!

RedrawStatusbarBG:
  jsr WaitForPPUOp                                ; make sure we don't have any ppu updates pending
  lda PPUCTRLCopy                                 ; store caller ppuctrl
  pha                                             ;
  and #%01111011                                  ; disable nmi, and set horizontal draw direction
  sta PPU_CTRL                                    ;
  lda #$0                                         ; ignore statusbar rendering for now to give us some more time
  sta StatusBarEnabled                            ;
  lda PPUMASKCopy                                 ; store caller ppumask
  pha                                             ;
  and #%11100111                                  ; disable rendering while drawing
  sta PPU_MASK                                    ; move ppu to status bar area
  lda #>$2320                                     ;
  sta PPU_ADDR                                    ;
  lda #<$2320                                     ;
  sta PPU_ADDR                                    ;
  ldy #StatusBarBGDataEnd-StatusBarBGData         ; number of bytes to write to ppu
  ldx #$0                                         ;
: lda StatusBarBGData,x                           ; copy each byte
  sta PPU_DATA                                    ;
  inx                                             ;
  dey                                             ;
  bne :-                                          ; loop until all written
  lda #>$23F0                                     ; move ppu to attributes for statusbar
  sta PPU_ADDR                                    ;
  lda #<$23F0                                     ;
  sta PPU_ADDR                                    ;
  ldy #$10                                        ;
  lda #$0                                         ; all attribute data should be 0
: sta PPU_DATA                                    ;
  dey                                             ;
  bne :-                                          ; loop until all written
  lda #$1                                         ; set A to 1 and do nothing with it.
  inc StatusBarEnabled                            ; then re-enable the status bar handling
  pla                                             ; restore caller ppu state
  sta PPUMASKCopy                                 ;
  pla                                             ;
  sta PPUCTRLCopy                                 ;
  sta PPU_CTRL                                    ;
  rts                                             ; done!

DrawLeftAreaDataColumn:
  lda CameraXTile                                 ; check every other X tile
  and #%11111110                                  ;
  sta PositionToBlock_XTile                       ;
  lda #$0                                         ; lookup from the top screen tile
  sta PositionToBlock_YPx                         ;
  jsr PositionToBlock                             ; resolve pointer to column
  jsr DrawAreaColumn                              ; and draw the column
  rts                                             ; done!

L_14_1C5DC:
  lda CameraXTile                                 ; get leftmost tile
  and #%11111110                                  ; we draw every other tile, so, strip off last bit
  sta PositionToBlock_XTile                       ; use as lookup
  lda #$0                                         ;
  sta PositionToBlock_YPx                         ; target top left tile
  jsr PositionToBlock                             ; and look up the data for the column
  lda BlockPtrHi                                  ;  1C5E9 C5E9 C A5 0D           F:000192
  SEC                                             ;  1C5EB C5EB C 38              F:000192
  SBC #$5                                         ;  1C5EC C5EC C E9 05           F:000192
  CLC                                             ;  1C5EE C5EE C 18              F:000192
  ADC AreaBlockDataPtrHi                                      ;  1C5EF C5EF C 65 76           F:000192
  STA BlockPtrHi                                      ;  1C5F1 C5F1 C 85 0D           F:000192
  jsr DrawAreaColumn                              ; write the column tiles to PPU
  rts                                             ; done!

DrawAreaColumn:
  @WorkC = $C
  @WorkD = $D
  lda PPUCTRLCopy                                 ;
  pha                                             ;
  and #%01111111                                  ; make sure we aren't interrupted while drawing by disabling NMI
  ora #%00000100                                  ; we're doing vertical ppu updates
  sta PPU_CTRL                                    ;
  lda StatusBarEnabled                            ; store if the game is using the statusbar on stack
  pha                                             ;
  lda #$0                                         ; and disable the statusbar for now
  sta StatusBarEnabled                            ;
  lda PPUMASKCopy                                 ;
  pha                                             ;
  and #%11100111                                  ; disable ppu output
  sta PPU_MASK                                    ;
  lda @WorkC                                      ; store away previous values 
  pha                                             ;
  lda @WorkD                                      ;
  pha                                             ;
  lda CameraXTile                                 ;
  asl a                                           ;
  and #%00011100                                  ;
  STA PPUUpdateAddrLo                                      ;  1C61B C61B C 85 16           F:001346
  LDA CameraXTile                                      ;  1C61D C61D C A5 7C           F:001346
  AND #$10                                        ;  1C61F C61F C 29 10           F:001346
  LSR                                             ;  1C621 C621 C 4A              F:001346
  LSR                                             ;  1C622 C622 C 4A              F:001346
  STA PPUUpdateAddrHi                                      ;  1C623 C623 C 85 17           F:001346
  CLC                                             ;  1C625 C625 C 18              F:001346
  LDA #$0                                         ;  1C626 C626 C A9 00           F:001346
  ADC PPUUpdateAddrLo                                      ;  1C628 C628 C 65 16           F:001346
  STA PPUUpdateAddrLo                                      ;  1C62A C62A C 85 16           F:001346
  LDA #$20                                        ;  1C62C C62C C A9 20           F:001346
  ADC PPUUpdateAddrHi                                      ;  1C62E C62E C 65 17           F:001346
  STA PPUUpdateAddrHi                                      ;  1C630 C630 C 85 17           F:001346
  LDA #$12                                        ;  1C632 C632 C A9 12           F:001346
  STA TmpA                                      ;  1C634 C634 C 85 0A           F:001346
B_14_1C636:
  LDA #$C                                         ;  1C636 C636 C A9 0C           F:001346
  STA BlockOffset                                      ;  1C638 C638 C 85 0B           F:001346
  LDA PPUUpdateAddrHi                                      ;  1C63A C63A C A5 17           F:001346
  STA PPU_ADDR                                    ;  1C63C C63C C 8D 06 20        F:001346
  LDA PPUUpdateAddrLo                                      ;  1C63F C63F C A5 16           F:001346
  STA PPU_ADDR                                    ;  1C641 C641 C 8D 06 20        F:001346
  LDY #$0                                         ;  1C644 C644 C A0 00           F:001346
  STY R_0008                                      ;  1C646 C646 C 84 08           F:001346
B_14_1C648:
  LDY R_0008                                      ;  1C648 C648 C A4 08           F:001346
  LDA (BlockPtrLo),Y                                  ;  1C64A C64A C B1 0C           F:001346
  ASL                                             ;  1C64C C64C C 0A              F:001346
  ASL                                             ;  1C64D C64D C 0A              F:001346
  TAY                                             ;  1C64E C64E C A8              F:001346
  LDA (AreaBGGfxSet),Y                                  ;  1C64F C64F C B1 79           F:001346
  STA PPU_DATA                                    ;  1C651 C651 C 8D 07 20        F:001346
  INY                                             ;  1C654 C654 C C8              F:001346
  LDA (AreaBGGfxSet),Y                                  ;  1C655 C655 C B1 79           F:001346
  STA PPU_DATA                                    ;  1C657 C657 C 8D 07 20        F:001346
  INC R_0008                                      ;  1C65A C65A C E6 08           F:001346
  DEC BlockOffset                                      ;  1C65C C65C C C6 0B           F:001346
  BNE B_14_1C648                                  ;  1C65E C65E C D0 E8           F:001346
  LDA #$C                                         ;  1C660 C660 C A9 0C           F:001346
  STA BlockOffset                                      ;  1C662 C662 C 85 0B           F:001346
  LDA PPUUpdateAddrHi                                      ;  1C664 C664 C A5 17           F:001346
  STA PPU_ADDR                                    ;  1C666 C666 C 8D 06 20        F:001346
  LDY PPUUpdateAddrLo                                      ;  1C669 C669 C A4 16           F:001346
  INY                                             ;  1C66B C66B C C8              F:001346
  STY PPU_ADDR                                    ;  1C66C C66C C 8C 06 20        F:001346
  LDY #$0                                         ;  1C66F C66F C A0 00           F:001346
  STY R_0008                                      ;  1C671 C671 C 84 08           F:001346
B_14_1C673:
  LDY R_0008                                      ;  1C673 C673 C A4 08           F:001346
  LDA (BlockPtrLo),Y                                  ;  1C675 C675 C B1 0C           F:001346
  ASL                                             ;  1C677 C677 C 0A              F:001346
  ASL                                             ;  1C678 C678 C 0A              F:001346
  TAY                                             ;  1C679 C679 C A8              F:001346
  INY                                             ;  1C67A C67A C C8              F:001346
  INY                                             ;  1C67B C67B C C8              F:001346
  LDA (AreaBGGfxSet),Y                                  ;  1C67C C67C C B1 79           F:001346
  STA PPU_DATA                                    ;  1C67E C67E C 8D 07 20        F:001346
  INY                                             ;  1C681 C681 C C8              F:001346
  LDA (AreaBGGfxSet),Y                                  ;  1C682 C682 C B1 79           F:001346
  STA PPU_DATA                                    ;  1C684 C684 C 8D 07 20        F:001346
  INC R_0008                                      ;  1C687 C687 C E6 08           F:001346
  DEC BlockOffset                                      ;  1C689 C689 C C6 0B           F:001346
  BNE B_14_1C673                                  ;  1C68B C68B C D0 E6           F:001346
  INC PPUUpdateAddrLo                                      ;  1C68D C68D C E6 16           F:001346
  INC PPUUpdateAddrLo                                      ;  1C68F C68F C E6 16           F:001346
  LDA PPUUpdateAddrLo                                      ;  1C691 C691 C A5 16           F:001346
  AND #$20                                        ;  1C693 C693 C 29 20           F:001346
  BEQ B_14_1C6A1                                  ;  1C695 C695 C F0 0A           F:001346
  LDA #$0                                         ;  1C697 C697 C A9 00           F:001347
  STA PPUUpdateAddrLo                                      ;  1C699 C699 C 85 16           F:001347
  LDA PPUUpdateAddrHi                                      ;  1C69B C69B C A5 17           F:001347
  EOR #$4                                         ;  1C69D C69D C 49 04           F:001347
  STA PPUUpdateAddrHi                                      ;  1C69F C69F C 85 17           F:001347
B_14_1C6A1:
  CLC                                             ;  1C6A1 C6A1 C 18              F:001346
  LDA #$C                                         ;  1C6A2 C6A2 C A9 0C           F:001346
  ADC BlockPtrLo                                      ;  1C6A4 C6A4 C 65 0C           F:001346
  STA BlockPtrLo                                      ;  1C6A6 C6A6 C 85 0C           F:001346
  LDA #$0                                         ;  1C6A8 C6A8 C A9 00           F:001346
  ADC BlockPtrHi                                      ;  1C6AA C6AA C 65 0D           F:001346
  STA BlockPtrHi                                      ;  1C6AC C6AC C 85 0D           F:001346
  DEC TmpA                                      ;  1C6AE C6AE C C6 0A           F:001346
  BNE B_14_1C636                                  ;  1C6B0 C6B0 C D0 84           F:001346
  PLA                                             ;  1C6B2 C6B2 C 68              F:001347
  STA BlockPtrHi                                      ;  1C6B3 C6B3 C 85 0D           F:001347
  PLA                                             ;  1C6B5 C6B5 C 68              F:001347
  STA BlockPtrLo                                      ;  1C6B6 C6B6 C 85 0C           F:001347
  LDA CameraXTile                                      ;  1C6B8 C6B8 C A5 7C           F:001347
  LSR                                             ;  1C6BA C6BA C 4A              F:001347
  AND #$7                                         ;  1C6BB C6BB C 29 07           F:001347
  STA PPUUpdateAddrLo                                      ;  1C6BD C6BD C 85 16           F:001347
  LDA CameraXTile                                      ;  1C6BF C6BF C A5 7C           F:001347
  AND #$10                                        ;  1C6C1 C6C1 C 29 10           F:001347
  LSR                                             ;  1C6C3 C6C3 C 4A              F:001347
  LSR                                             ;  1C6C4 C6C4 C 4A              F:001347
  STA PPUUpdateAddrHi                                      ;  1C6C5 C6C5 C 85 17           F:001347
  CLC                                             ;  1C6C7 C6C7 C 18              F:001347
  LDA #$C0                                        ;  1C6C8 C6C8 C A9 C0           F:001347
  ADC PPUUpdateAddrLo                                      ;  1C6CA C6CA C 65 16           F:001347
  STA PPUUpdateAddrLo                                      ;  1C6CC C6CC C 85 16           F:001347
  LDA #$23                                        ;  1C6CE C6CE C A9 23           F:001347
  ADC PPUUpdateAddrHi                                      ;  1C6D0 C6D0 C 65 17           F:001347
  STA PPUUpdateAddrHi                                      ;  1C6D2 C6D2 C 85 17           F:001347
  LDA #$9                                         ;  1C6D4 C6D4 C A9 09           F:001347
  STA TmpA                                      ;  1C6D6 C6D6 C 85 0A           F:001347
L_14_1C6D8:
  LDX #$6                                         ;  1C6D8 C6D8 C A2 06           F:001347
B_14_1C6DA:
  LDY #$D                                         ;  1C6DA C6DA C A0 0D           F:001347
  LDA (BlockPtrLo),Y                                  ;  1C6DC C6DC C B1 0C           F:001347
  ROL                                             ;  1C6DE C6DE C 2A              F:001347
  ROL R_0008                                      ;  1C6DF C6DF C 26 08           F:001347
  ROL                                             ;  1C6E1 C6E1 C 2A              F:001347
  ROL R_0008                                      ;  1C6E2 C6E2 C 26 08           F:001347
  LDY #$1                                         ;  1C6E4 C6E4 C A0 01           F:001347
  LDA (BlockPtrLo),Y                                  ;  1C6E6 C6E6 C B1 0C           F:001347
  ROL                                             ;  1C6E8 C6E8 C 2A              F:001347
  ROL R_0008                                      ;  1C6E9 C6E9 C 26 08           F:001347
  ROL                                             ;  1C6EB C6EB C 2A              F:001347
  ROL R_0008                                      ;  1C6EC C6EC C 26 08           F:001347
  LDY #$C                                         ;  1C6EE C6EE C A0 0C           F:001347
  LDA (BlockPtrLo),Y                                  ;  1C6F0 C6F0 C B1 0C           F:001347
  ROL                                             ;  1C6F2 C6F2 C 2A              F:001347
  ROL R_0008                                      ;  1C6F3 C6F3 C 26 08           F:001347
  ROL                                             ;  1C6F5 C6F5 C 2A              F:001347
  ROL R_0008                                      ;  1C6F6 C6F6 C 26 08           F:001347
  LDY #$0                                         ;  1C6F8 C6F8 C A0 00           F:001347
  LDA (BlockPtrLo),Y                                  ;  1C6FA C6FA C B1 0C           F:001347
  ROL                                             ;  1C6FC C6FC C 2A              F:001347
  ROL R_0008                                      ;  1C6FD C6FD C 26 08           F:001347
  ROL                                             ;  1C6FF C6FF C 2A              F:001347
  ROL R_0008                                      ;  1C700 C700 C 26 08           F:001347
  LDA PPUUpdateAddrHi                                      ;  1C702 C702 C A5 17           F:001347
  STA PPU_ADDR                                    ;  1C704 C704 C 8D 06 20        F:001347
  LDA PPUUpdateAddrLo                                      ;  1C707 C707 C A5 16           F:001347
  STA PPU_ADDR                                    ;  1C709 C709 C 8D 06 20        F:001347
  LDA R_0008                                      ;  1C70C C70C C A5 08           F:001347
  STA PPU_DATA                                    ;  1C70E C70E C 8D 07 20        F:001347
  CLC                                             ;  1C711 C711 C 18              F:001347
  LDA #$2                                         ;  1C712 C712 C A9 02           F:001347
  ADC BlockPtrLo                                      ;  1C714 C714 C 65 0C           F:001347
  STA BlockPtrLo                                      ;  1C716 C716 C 85 0C           F:001347
  LDA #$0                                         ;  1C718 C718 C A9 00           F:001347
  ADC BlockPtrHi                                      ;  1C71A C71A C 65 0D           F:001347
  STA BlockPtrHi                                      ;  1C71C C71C C 85 0D           F:001347
  CLC                                             ;  1C71E C71E C 18              F:001347
  LDA #$8                                         ;  1C71F C71F C A9 08           F:001347
  ADC PPUUpdateAddrLo                                      ;  1C721 C721 C 65 16           F:001347
  STA PPUUpdateAddrLo                                      ;  1C723 C723 C 85 16           F:001347
  LDA #$0                                         ;  1C725 C725 C A9 00           F:001347
  ADC PPUUpdateAddrHi                                      ;  1C727 C727 C 65 17           F:001347
  STA PPUUpdateAddrHi                                      ;  1C729 C729 C 85 17           F:001347
  DEX                                             ;  1C72B C72B C CA              F:001347
  BNE B_14_1C6DA                                  ;  1C72C C72C C D0 AC           F:001347
  CLC                                             ;  1C72E C72E C 18              F:001347
  LDA #$C                                         ;  1C72F C72F C A9 0C           F:001347
  ADC BlockPtrLo                                      ;  1C731 C731 C 65 0C           F:001347
  STA BlockPtrLo                                      ;  1C733 C733 C 85 0C           F:001347
  LDA #$0                                         ;  1C735 C735 C A9 00           F:001347
  ADC BlockPtrHi                                      ;  1C737 C737 C 65 0D           F:001347
  STA BlockPtrHi                                      ;  1C739 C739 C 85 0D           F:001347
  CLC                                             ;  1C73B C73B C 18              F:001347
  LDA #$D1                                        ;  1C73C C73C C A9 D1           F:001347
  ADC PPUUpdateAddrLo                                      ;  1C73E C73E C 65 16           F:001347
  STA PPUUpdateAddrLo                                      ;  1C740 C740 C 85 16           F:001347
  LDA #$FF                                        ;  1C742 C742 C A9 FF           F:001347
  ADC PPUUpdateAddrHi                                      ;  1C744 C744 C 65 17           F:001347
  STA PPUUpdateAddrHi                                      ;  1C746 C746 C 85 17           F:001347
  LDA PPUUpdateAddrLo                                      ;  1C748 C748 C A5 16           F:001347
  AND #$8                                         ;  1C74A C74A C 29 08           F:001347
  BEQ @B_14_1C758                                  ;  1C74C C74C C F0 0A           F:001347
  LDA #$C0                                        ;  1C74E C74E C A9 C0           F:001347
  STA PPUUpdateAddrLo                                      ;  1C750 C750 C 85 16           F:001347
  LDA PPUUpdateAddrHi                                      ;  1C752 C752 C A5 17           F:001347
  EOR #$4                                         ;  1C754 C754 C 49 04           F:001347
  STA PPUUpdateAddrHi                                      ;  1C756 C756 C 85 17           F:001347
@B_14_1C758:
  DEC TmpA                                      ;  1C758 C758 C C6 0A           F:001347
  BEQ @Done                                  ;  1C75A C75A C F0 03           F:001347
  JMP L_14_1C6D8                                  ;  1C75C C75C C 4C D8 C6        F:001347

@Done:
  pla                                             ; restore some of callers state
  sta PPUMASKCopy                                 ;
  pla                                             ;
  sta StatusBarEnabled                            ;
  pla                                             ;
  sta PPUCTRLCopy                                 ;
  sta PPU_CTRL                                    ;
  rts                                             ; done!

L_14_1C76C:
  JSR WaitForPPUOp                                  ;  1C76C C76C C 20 97 CC        F:018875
  LDA CameraXTile                                      ;  1C76F C76F C A5 7C           F:018875
  ASL                                             ;  1C771 C771 C 0A              F:018875
  AND #$1F                                        ;  1C772 C772 C 29 1F           F:018875
  STA PPUUpdateAddrLo                                      ;  1C774 C774 C 85 16           F:018875
  LDA CameraXTile                                      ;  1C776 C776 C A5 7C           F:018875
  AND #$10                                        ;  1C778 C778 C 29 10           F:018875
  LSR                                             ;  1C77A C77A C 4A              F:018875
  LSR                                             ;  1C77B C77B C 4A              F:018875
  STA PPUUpdateAddrHi                                      ;  1C77C C77C C 85 17           F:018875
  CLC                                             ;  1C77E C77E C 18              F:018875
  LDA #$0                                         ;  1C77F C77F C A9 00           F:018875
  ADC PPUUpdateAddrLo                                      ;  1C781 C781 C 65 16           F:018875
  STA PPUUpdateAddrLo                                      ;  1C783 C783 C 85 16           F:018875
  LDA #$20                                        ;  1C785 C785 C A9 20           F:018875
  ADC PPUUpdateAddrHi                                      ;  1C787 C787 C 65 17           F:018875
  STA PPUUpdateAddrHi                                      ;  1C789 C789 C 85 17           F:018875
  LDA CameraXTile                                      ;  1C78B C78B C A5 7C           F:018875
  STA R_0008                                      ;  1C78D C78D C 85 08           F:018875
  LDA #$10                                        ;  1C78F C78F C A9 10           F:018875
  STA Tmp9                                      ;  1C791 C791 C 85 09           F:018875
B_14_1C793:
  LDA R_0008                                      ;  1C793 C793 C A5 08           F:018875
  STA BlockPtrLo                                      ;  1C795 C795 C 85 0C           F:018875
  JSR BankAndDrawMetatileColumn                                  ;  1C797 C797 C 20 33 C8        F:018875
  INC PPUUpdateAddrLo                                      ;  1C79A C79A C E6 16           F:018876
  INC PPUUpdateAddrLo                                      ;  1C79C C79C C E6 16           F:018876
  LDA PPUUpdateAddrLo                                      ;  1C79E C79E C A5 16           F:018876
  AND #$20                                        ;  1C7A0 C7A0 C 29 20           F:018876
  BEQ B_14_1C7AE                                  ;  1C7A2 C7A2 C F0 0A           F:018876
  LDA #$0                                         ;  1C7A4 C7A4 C A9 00           F:018891
  STA PPUUpdateAddrLo                                      ;  1C7A6 C7A6 C 85 16           F:018891
  LDA PPUUpdateAddrHi                                      ;  1C7A8 C7A8 C A5 17           F:018891
  EOR #$4                                         ;  1C7AA C7AA C 49 04           F:018891
  STA PPUUpdateAddrHi                                      ;  1C7AC C7AC C 85 17           F:018891
B_14_1C7AE:
  INC R_0008                                      ;  1C7AE C7AE C E6 08           F:018876
  DEC Tmp9                                      ;  1C7B0 C7B0 C C6 09           F:018876
  BNE B_14_1C793                                  ;  1C7B2 C7B2 C D0 DF           F:018876
  RTS                                             ;  1C7B4 C7B4 C 60              F:018891

L_14_1C7B5:
  JSR WaitForPPUOp                                  ;  1C7B5 C7B5 C 20 97 CC        F:000314
  LDA CameraXTile                                      ;  1C7B8 C7B8 C A5 7C           F:000314
  ASL                                             ;  1C7BA C7BA C 0A              F:000314
  AND #$1F                                        ;  1C7BB C7BB C 29 1F           F:000314
  STA PPUUpdateAddrLo                                        ;  1C7BD C7BD C 85 16           F:000314
  LDA CameraXTile                                      ;  1C7BF C7BF C A5 7C           F:000314
  AND #$10                                        ;  1C7C1 C7C1 C 29 10           F:000314
  LSR                                             ;  1C7C3 C7C3 C 4A              F:000314
  LSR                                             ;  1C7C4 C7C4 C 4A              F:000314
  STA PPUUpdateAddrHi                                      ;  1C7C5 C7C5 C 85 17           F:000314
  CLC                                             ;  1C7C7 C7C7 C 18              F:000314
  LDA #$0                                         ;  1C7C8 C7C8 C A9 00           F:000314
  ADC PPUUpdateAddrLo                                      ;  1C7CA C7CA C 65 16           F:000314
  STA PPUUpdateAddrLo                                      ;  1C7CC C7CC C 85 16           F:000314
  LDA #$20                                        ;  1C7CE C7CE C A9 20           F:000314
  ADC PPUUpdateAddrHi                                      ;  1C7D0 C7D0 C 65 17           F:000314
  STA PPUUpdateAddrHi                                      ;  1C7D2 C7D2 C 85 17           F:000314
  LDA CameraXTile                                      ;  1C7D4 C7D4 C A5 7C           F:000314
  STA R_0008                                      ;  1C7D6 C7D6 C 85 08           F:000314
  LDA #$10                                        ;  1C7D8 C7D8 C A9 10           F:000314
  STA Tmp9                                      ;  1C7DA C7DA C 85 09           F:000314
B_14_1C7DC:
  LDA R_0008                                      ;  1C7DC C7DC C A5 08           F:000314
  STA BlockPtrLo                                      ;  1C7DE C7DE C 85 0C           F:000314
  JSR L_14_1C85C                                  ;  1C7E0 C7E0 C 20 5C C8        F:000314
  INC PPUUpdateAddrLo                                      ;  1C7E3 C7E3 C E6 16           F:000315
  INC PPUUpdateAddrLo                                      ;  1C7E5 C7E5 C E6 16           F:000315
  LDA PPUUpdateAddrLo                                      ;  1C7E7 C7E7 C A5 16           F:000315
  AND #$20                                        ;  1C7E9 C7E9 C 29 20           F:000315
  BEQ B_14_1C7F7                                  ;  1C7EB C7EB C F0 0A           F:000315
  LDA #$0                                         ;  1C7ED C7ED C A9 00           F:000330
  STA PPUUpdateAddrLo                                      ;  1C7EF C7EF C 85 16           F:000330
  LDA PPUUpdateAddrHi                                      ;  1C7F1 C7F1 C A5 17           F:000330
  EOR #$4                                         ;  1C7F3 C7F3 C 49 04           F:000330
  STA PPUUpdateAddrHi                                      ;  1C7F5 C7F5 C 85 17           F:000330
B_14_1C7F7:
  INC R_0008                                      ;  1C7F7 C7F7 C E6 08           F:000315
  DEC Tmp9                                      ;  1C7F9 C7F9 C C6 09           F:000315
  BNE B_14_1C7DC                                  ;  1C7FB C7FB C D0 DF           F:000315
  RTS                                             ;  1C7FD C7FD C 60              F:000330

DrawMetatileColumnAtEdge:
  jsr WaitForPPUOp                                ; wait for any pending ppu operation to complete
  lda ScreenScrollDirection                       ; check which direction we are scrolling
  bmi @Left                                       ; hop ahead if we're going left
  lda CameraXTile                                 ; otherwise get the left screen column
  clc                                             ;
  Adc #$10                                        ; and add 16 tiles to get the right side
  sta BlockPtrLo                                  ; set offset
  jmp @Shared                                     ;
@Left:
  lda CameraXTile                                 ; get left screen column
  sta BlockPtrLo                                  ; set offset
@Shared:
  lda BlockPtrLo                                  ; get offset, which was already in A
  asl a                                           ; shift bits up
  and #%00011111                                  ; use as low ppu address
  sta PPUUpdateAddrLo                             ;
  lda BlockPtrLo                                  ; restore offset
  and #%00010000                                  ; and get bit 5
  lsr a                                           ; shift down to use as offset for high ppu address
  lsr a                                           ;
  sta PPUUpdateAddrHi                             ;
  clc                                             ; add $2000 to target to get to correct position
  lda #$0                                         ;
  adc PPUUpdateAddrLo                             ;
  sta PPUUpdateAddrLo                             ;
  lda #$20                                        ;
  adc PPUUpdateAddrHi                             ;
  sta PPUUpdateAddrHi                             ;
  jsr BankAndDrawMetatileColumn                   ; then draw the column
  rts                                             ; done!

BankAndDrawMetatileColumn:
  lda SelectedBank7                               ; store calling bank
  pha                                             ;
  lda #$7                                         ; select bank 7
  STA MMC3LastBankSelect                          ;
  sta MMC3_RegBankSelect                          ;
  lda #$9                                         ; switch to bank 9
  sta SelectedBank7                               ;
  sta MMC3_RegBankData                            ;
  lda #$0                                         ; get column from top tile
  sta PositionToBlock_YPx                         ;
  jsr PositionToBlock                             ; and fetch blockptr
  jsr DrawMetatileColumn                          ; then draw the column
  lda #$7                                         ; switching bank 7 back
  sta MMC3LastBankSelect                          ;
  sta MMC3_RegBankSelect                          ;
  pla                                             ; fetch calling bank
  sta SelectedBank7                               ;
  sta MMC3_RegBankData                            ; and switch back
  rts                                             ; done!

L_14_1C85C:
  LDA #$0                                         ;  1C85C C85C C A9 00           F:000314
  STA PositionToBlock_YPx                                      ;  1C85E C85E C 85 0D           F:000314
  JSR PositionToBlock                                  ;  1C860 C860 C 20 54 CA        F:000314
  LDA BlockPtrHi                                      ;  1C863 C863 C A5 0D           F:000314
  SEC                                             ;  1C865 C865 C 38              F:000314
  SBC #$5                                         ;  1C866 C866 C E9 05           F:000314
  CLC                                             ;  1C868 C868 C 18              F:000314
  ADC AreaBlockDataPtrHi                                      ;  1C869 C869 C 65 76           F:000314
  STA BlockPtrHi                                      ;  1C86B C86B C 85 0D           F:000314
  JSR DrawMetatileColumn                                  ;  1C86D C86D C 20 71 C8        F:000314
  RTS                                             ;  1C870 C870 C 60              F:000315

DrawMetatileColumn:
  lda #$0                                         ; clear offset
  sta BlockOffset                                 ;
  ldx #$16                                        ;  1C875 C875 C A2 16           F:001672
B_14_1C877:
  LDY BlockOffset                                      ;  1C877 C877 C A4 0B           F:001672
  LDA (BlockPtrLo),Y                                  ;  1C879 C879 C B1 0C           F:001672
  ASL                                             ;  1C87B C87B C 0A              F:001672
  ASL                                             ;  1C87C C87C C 0A              F:001672
  TAY                                             ;  1C87D C87D C A8              F:001672
  LDA (AreaBGGfxSet),Y                                  ;  1C87E C87E C B1 79           F:001672
  STA PPUDrawColumn0+1,X                                    ;  1C880 C880 C 9D 41 01        F:001672
  INY                                             ;  1C883 C883 C C8              F:001672
  LDA (AreaBGGfxSet),Y                                  ;  1C884 C884 C B1 79           F:001672
  STA PPUDrawColumn0,X                                    ;  1C886 C886 C 9D 40 01        F:001672
  INY                                             ;  1C889 C889 C C8              F:001672
  LDA (AreaBGGfxSet),Y                                  ;  1C88A C88A C B1 79           F:001672
  STA PPUDrawColumn1+1,X                                    ;  1C88C C88C C 9D 59 01        F:001672
  INY                                             ;  1C88F C88F C C8              F:001672
  LDA (AreaBGGfxSet),Y                                  ;  1C890 C890 C B1 79           F:001672
  STA PPUDrawColumn1,X                                    ;  1C892 C892 C 9D 58 01        F:001672
  INC BlockOffset                                      ;  1C895 C895 C E6 0B           F:001672
  DEX                                             ;  1C897 C897 C CA              F:001672
  DEX                                             ;  1C898 C898 C CA              F:001672
  BPL B_14_1C877                                  ;  1C899 C899 C 10 DC           F:001672
  LDA PPUUpdateAddrHi                                      ;  1C89B C89B C A5 17           F:001672
  CLC                                             ;  1C89D C89D C 18              F:001672
  ADC #$3                                         ;  1C89E C89E C 69 03           F:001672
  STA PPUUpdateData+1                                      ;  1C8A0 C8A0 C 85 19           F:001672
  LDA PPUUpdateAddrLo                                      ;  1C8A2 C8A2 C A5 16           F:001672
  LSR                                             ;  1C8A4 C8A4 C 4A              F:001672
  LSR                                             ;  1C8A5 C8A5 C 4A              F:001672
  CLC                                             ;  1C8A6 C8A6 C 18              F:001672
  ADC #$C0                                        ;  1C8A7 C8A7 C 69 C0           F:001672
  STA BlockOffset                                      ;  1C8A9 C8A9 C 85 0B           F:001672
  LDX #$33                                        ;  1C8AB C8AB C A2 33           F:001672
  LDA PPUUpdateAddrLo                                      ;  1C8AD C8AD C A5 16           F:001672
  AND #$2                                         ;  1C8AF C8AF C 29 02           F:001672
  BNE B_14_1C8B5                                  ;  1C8B1 C8B1 C D0 02           F:001672
  LDX #$CC                                        ;  1C8B3 C8B3 C A2 CC           F:001688
B_14_1C8B5:
  STX PPUUpdateData                                      ;  1C8B5 C8B5 C 86 18           F:001672
  LDY #$0                                         ;  1C8B7 C8B7 C A0 00           F:001672
  LDX #$A                                         ;  1C8B9 C8B9 C A2 0A           F:001672
B_14_1C8BB:
  LDA BlockOffset                                      ;  1C8BB C8BB C A5 0B           F:001672
  STA R_0170,X                                    ;  1C8BD C8BD C 9D 70 01        F:001672
  CLC                                             ;  1C8C0 C8C0 C 18              F:001672
  ADC #$8                                         ;  1C8C1 C8C1 C 69 08           F:001672
  STA BlockOffset                                      ;  1C8C3 C8C3 C 85 0B           F:001672
  LDA (BlockPtrLo),Y                                  ;  1C8C5 C8C5 C B1 0C           F:001672
  INY                                             ;  1C8C7 C8C7 C C8              F:001672
  AND #$C0                                        ;  1C8C8 C8C8 C 29 C0           F:001672
  LSR                                             ;  1C8CA C8CA C 4A              F:001672
  LSR                                             ;  1C8CB C8CB C 4A              F:001672
  LSR                                             ;  1C8CC C8CC C 4A              F:001672
  LSR                                             ;  1C8CD C8CD C 4A              F:001672
  STA R_0171,X                                    ;  1C8CE C8CE C 9D 71 01        F:001672
  LDA (BlockPtrLo),Y                                  ;  1C8D1 C8D1 C B1 0C           F:001672
  INY                                             ;  1C8D3 C8D3 C C8              F:001672
  AND #$C0                                        ;  1C8D4 C8D4 C 29 C0           F:001672
  ORA R_0171,X                                    ;  1C8D6 C8D6 C 1D 71 01        F:001672
  STA R_0171,X                                    ;  1C8D9 C8D9 C 9D 71 01        F:001672
  LDA PPUUpdateAddrLo                                      ;  1C8DC C8DC C A5 16           F:001672
  AND #$2                                         ;  1C8DE C8DE C 29 02           F:001672
  BNE B_14_1C8E8                                  ;  1C8E0 C8E0 C D0 06           F:001672
  LSR R_0171,X                                    ;  1C8E2 C8E2 C 5E 71 01        F:001688
  LSR R_0171,X                                    ;  1C8E5 C8E5 C 5E 71 01        F:001688
B_14_1C8E8:
  DEX                                             ;  1C8E8 C8E8 C CA              F:001672
  DEX                                             ;  1C8E9 C8E9 C CA              F:001672
  BPL B_14_1C8BB                                  ;  1C8EA C8EA C 10 CF           F:001672
  lda #PPUOps_DrawAreaColumn                      ; wait for nmi and send to PPU
  jsr RunPPUOp                                    ;
  rts                                             ; done!

LoadNewAreaData:
  jsr AreaDataLocate                              ; find the PRG data for the area we are in
  jsr AreaDataLoad                                ; load tiles
  jsr AreaConfigLoad                              ; load configuration
  jsr AreaPaletteSetup                            ; load palette
  rts                                             ; done!

ReloadAreaConfig:
  jsr AreaDataLocate                              ; find the PRG data for the area we are in
  jsr AreaConfigLoad                              ; load configuration
  jsr AreaPaletteSetup                            ; load palette
  rts                                             ; done!

AreaConfigLoad:
  LDY #$0                                         ;  1C909 C909 C A0 00           F:001345
  LDA (AreaDataPtr),Y                                  ;  1C90B C90B C B1 77           F:001345
  ADC #$A0                                        ;  1C90D C90D C 69 A0           F:001345
  STA AreaBGGfxSet+1                                      ;  1C90F C90F C 85 7A           F:001345
  LDA #$0                                         ;  1C911 C911 C A9 00           F:001345
  STA AreaBGGfxSet                                      ;  1C913 C913 C 85 79           F:001345
  INY                                             ;  1C915 C915 C C8              F:001345
  LDA (AreaDataPtr),Y                                  ;  1C916 C916 C B1 77           F:001345
  STA SelectedBank3                                      ;  1C918 C918 C 85 2D           F:001345
  INY                                             ;  1C91A C91A C C8              F:001345
  LDA (AreaDataPtr),Y                                  ;  1C91B C91B C B1 77           F:001345
  STA AreaBlockSwapFrom                                      ;  1C91D C91D C 85 70           F:001345
  INY                                             ;  1C91F C91F C C8              F:001345
  LDA (AreaDataPtr),Y                                  ;  1C920 C920 C B1 77           F:001345
  STA AreaBlockSwapTo                   ;  1C922 C922 C 85 71           F:001345
  INY                                             ;  1C924 C924 C C8              F:001345
  LDA (AreaDataPtr),Y                                  ;  1C925 C925 C B1 77           F:001345
  STA AreaBlockBreakTo                                      ;  1C927 C927 C 85 74           F:001345
  INY                                             ;  1C929 C929 C C8              F:001345
  LDA (AreaDataPtr),Y                                  ;  1C92A C92A C B1 77           F:001345
  ORA #$0                                         ;  1C92C C92C C 09 00           F:001345
  STA SelectedBank0                                      ;  1C92E C92E C 85 2A           F:001345
  INY                                             ;  1C930 C930 C C8              F:001345
  LDA (AreaDataPtr),Y                                  ;  1C931 C931 C B1 77           F:001345
  ORA #$0                                         ;  1C933 C933 C 09 00           F:001345
  STA SelectedBank1                                      ;  1C935 C935 C 85 2B           F:001345
  ldy #$7                                         ; offset used for chest
  jsr CheckIfAreaChestIsUsed                        ; check if the chest in the room has already been used
  lda #$0                                         ;
  bcc :+                                          ; skip to set 0 if chest is used
  lda (AreaDataPtr),y                             ; otherwise enable the chest if it exists
: sta RoomChestActive                             ;
  beq @ChestDone                                  ; skip to end if the chest is not active
  LDA #$1                                         ;
  STA RoomChestUnk4A2                             ;
  iny                                             ; set chest X position
  lda (AreaDataPtr),y                             ;
  sta RoomChestXTile                              ;
  lda #$0                                         ;
  sta RoomChestUnk4AC                             ;
  iny                                             ; set chest Y position
  lda (AreaDataPtr),y                             ;
  sta RoomChestYPx                                ;
  iny                                             ;
  lda (AreaDataPtr),y                             ; get chest contents
  cmp #DropType_DragonSlayer                     ; is this chest supposed to be a dragonslayer?
  bne :+                                          ; no - skip ahead
  LDA #$19                                        ; yes - the dragon slayer is not contained in a chest, so, handle that
  STA RoomChestActive                             ;
  LDA #$DD                                        ;
  JMP :++                                         ;  1C96B C96B C 4C 70 C9        F:067401
: lda #$E9                                        ;  1C96E C96E C A9 E9           F:001345
: sta RoomChestState                                      ;  1C970 C970 C 8D A0 04        F:001345
@ChestDone:
  LDX CurrentMusic                                      ;  1C973 C973 C A6 8E           F:001345
  CPX #$5                                         ;  1C975 C975 C E0 05           F:001345
  BCS @SetMusic                                  ;  1C977 C977 C B0 0D           F:001345
  LDA #$0                                         ;  1C979 C979 C A9 00           F:001471
  SEC                                             ;  1C97B C97B C 38              F:001471
: ROL                                             ;  1C97C C97C C 2A              F:001471
  DEX                                             ;  1C97D C97D C CA              F:001471
  BPL :-                                  ;  1C97E C97E C 10 FC           F:001471
  LDY #$15                                        ;  1C980 C980 C A0 15           F:001471
  AND (AreaDataPtr),Y                                  ;  1C982 C982 C 31 77           F:001471
  BNE @CopyShopData                                  ;  1C984 C984 C D0 07           F:001471
@SetMusic:
  LDY #$B                                         ;  1C986 C986 C A0 0B           F:001345
  LDA (AreaDataPtr),Y                                  ;  1C988 C988 C B1 77           F:001345
  JSR ChangeMusicIfNeeded                                  ;  1C98A C98A C 20 2E D0        F:001345
@CopyShopData:
  ldy #$10                                        ; copy shop data
  lda (AreaDataPtr),y                             ;
  sta ShopItem1Type                               ;
  iny                                             ;
  lda (AreaDataPtr),y                             ;
  sta ShopItem1Cost                               ;
  iny                                             ;
  lda (AreaDataPtr),y                             ;
  sta ShopItem2Type                               ;
  iny                                             ;
  lda (AreaDataPtr),y                             ;
  sta ShopItem2Cost                               ;
  ldy #$14                                        ;
  lda (AreaDataPtr),Y                             ; set spawn rate
  sta EnemySpawnRate                              ;
  rts                                             ; done!

AreaDataLoad:
  lda AreaBlockDataPtrLo                          ; copy pointer
  sta AreaDataPtr                                 ; 
  lda AreaBlockDataPtrHi                          ; 
  sta AreaDataPtr+1                               ; 
  ldy #$0                                         ; clear y to copy pages
: lda (AreaDataPtr),y                             ; copy next byte
  sta CurrentAreaData,y                           ;
  iny                                             ;
  bne :-                                          ; advance until whole page copied
  inc AreaDataPtr+1                               ; advance to load next page
: lda (AreaDataPtr),y                             ; copy next byte
  sta CurrentAreaData2,y                          ;
  iny                                             ;
  bne :-                                          ; advance until whole page copied
  inc AreaDataPtr+1                               ; advance to load next page
: lda (AreaDataPtr),y                             ; copy next byte
  sta CurrentAreaData3,y                          ;
  iny                                             ;
  bne :-                                          ; advance until whole page copied
  inc AreaDataPtr+1                               ; advance to load next page
  rts                                             ; done!

AreaDataLocate:
  lda CurrentAreaY                                ; check if we're changing Y areas
  lsr a                                           ;
  cmp SelectedBank6                               ;
  beq :+                                          ; if not - skip ahead
  sta SelectedBank6                               ; otherwise delay until next frame to give us more time
  lda #PPUOps_Default                             ;
  jsr RunPPUOp                                    ;
: lda CurrentAreaY                                ; ptr = (((Y & 1) << 2 | X) << 2) + $80
  and #$1                                         ;
  asl a                                           ;
  asl a                                           ;
  ora CurrentAreaX                                ;
  asl a                                           ;
  asl a                                           ;
  clc                                             ;
  adc #$80                                        ;
  sta AreaBlockDataPtrHi                          ; update pointer to area data
  clc                                             ;
  adc #$3                                         ; and pointer to the end of the area data
  sta AreaDataPtr+1                               ;
  lda #$0                                         ; area data is always $100-aligned
  sta AreaDataPtr                                 ;
  sta AreaBlockDataPtrLo                          ;
  rts                                             ; done!

AreaPaletteSetup:
  ldy #$E0                                        ; we want to load data from the palette portion of the area
: lda (AreaDataPtr),y                             ;
  sta a:PaletteRAMCopy-$E0,Y                      ; copy it to the RAM palette
  iny                                             ;
  bmi :-                                          ;
  lda PlayerCharacter                             ; check selected player character
  cmp #$6                                         ; if invalid character (no character selected yet)
  bcs @Done                                       ; then skip ahead, we use the default palette
  asl a                                           ; otherwise we multiply up to the characters palette
  asl a                                           ;
  clc                                             ;
  adc #$3                                         ; shift to the end of the palette
  tax                                             ;
  ldy #$3                                         ;
: lda CharacterPalettes,x                         ; and copy palette colors for the selected character
  sta PaletteRAMCopy+$10,y                        ;
  dex                                             ;
  dey                                             ;
  bpl :-                                          ; loop until done
@Done:
  rts                                             ; done!

CheckIfAreaChestIsUsed:
  lda CurrentAreaY                                ; get area Y position
  asl a                                           ; and multiply by X width of game
  asl a                                           ;
  and #%00000100                                  ; keep low bit
  ora CurrentAreaX                                ; and add in area X position
  tax                                             ;
  lda ChestUsedState,x                            ; fetch used state of chests in this segment
  pha                                             ; and put it on the stack
  lda CurrentAreaY                                ; get area Y position again
  lsr a                                           ; and divide it by 2
  tax                                             ; use that+1 for bit lookup
  inx                                             ;
  pla                                             ; restore used state
: asl a                                           ; shift until we've found the bit for our area
  dex                                             ;
  bne :-                                          ;
  rts                                             ; done!

MarkAreaChestAsUsed:
  lda CurrentAreaY                                ; get area Y position again
  lsr a                                           ; and divide it by 2
  tax                                             ; use that+1 for bit lookup
  inx                                             ;
  lda #$FF                                        ; set all the bits
  clc                                             ; clear bit so we'll shift in a 0
: ror a                                           ; shift the 0 bit to the correct spot
  dex                                             ;
  bne :-                                          ; loop until done
  pha                                             ; and store new masking value on stack
  lda CurrentAreaY                                ; get area Y position
  asl a                                           ; and multiply by X width of game
  asl a                                           ;
  and #%00000100                                  ; keep low bit
  ora CurrentAreaX                                ; and add in area X position
  tax                                             ;
  pla                                             ; pull bit mask from stack
  and ChestUsedState,x                            ; mark the chest as used
  sta ChestUsedState,x                            ;
  rts                                             ; done!

; takes an X tile and Y pixel, converts that to block data offset
PositionToBlock:
  lda PositionToBlock_YPx                         ; store the Y coordinate on stack for now
  pha                                             ;
  jsr MultiplyBy12                                ; and multiply X by 12 to get the block offset
  lda PositionToBlock_YPx                         ;
  sta BlockPtr2Hi                                 ; 
  pla                                             ; restore Y pixel coordinate
  lsr a                                           ; shift high nibble to low
  lsr a                                           ;
  lsr a                                           ;
  lsr a                                           ;
  clc                                             ;
  adc MultiplyBy12_ResultLo                       ; and add it to the X value
  sta MultiplyBy12_ResultLo                       ;
  sta BlockPtr2Lo                                 ; set result value
  bcc :+                                          ; skip ahead unless we need to carry
  inc MultiplyBy12_ResultHi                       ; carry result
  inc BlockPtr2Hi                                 ;
: clc                                             ;
  lda MultiplyBy12_ResultHi                       ; adjust result by 5.. TODO - why
  adc #$5                                         ;
  sta MultiplyBy12_ResultHi                       ;
  clc                                             ;
  lda BlockPtr2Lo                                 ; shift block result by the base data pointer
  adc AreaBlockDataPtrLo                          ;
  sta BlockPtr2Lo                                 ;
  lda BlockPtr2Hi                                 ;
  adc AreaBlockDataPtrHi                          ;
  sta BlockPtr2Hi                                 ;
  rts                                             ; done!

; areas are 12 Y tiles high, so we need to be able to multiply by that.
MultiplyBy12:
  @OutLo = MultiplyBy12_ResultLo
  @OutHi = MultiplyBy12_ResultHi
  lda #$0                                         ; clear high output
  sta @OutHi                                      ;
  asl @OutLo                                      ; multiply by 4
  rol @OutHi                                      ; ...
  asl @OutLo                                      ; ...
  rol @OutHi                                      ; ...
  ldx @OutHi                                      ; copy current results
  ldy @OutLo                                      ; ...
  asl @OutLo                                      ; muliply by 2 (so, x8)
  rol @OutHi                                      ; ...
  tya                                             ; add multiply by 4 result (so, x12!)
  clc                                             ;
  adc @OutLo                                      ;
  sta @OutLo                                      ;
  txa                                             ;
  adc @OutHi                                      ;
  sta @OutHi                                      ;
  rts                                             ; done!

UpdateStatusbar:
  jsr WaitForPPUOp                                ; wait for any pending ppu operation to complete
  lda #<$2360                                     ; set ppu target position
  sta PPUUpdateAddrLo                             ;
  lda #>$2360                                     ;
  sta PPUUpdateAddrHi                             ;
  lda #PPUOps_UpdateStatusbar                     ; then trigger the ppu update next frame
  JSR RunPPUOp                                    ;
  rts                                             ; done!

UpdateHPDisplay:
  lda PlayerHP                                    ; check how much health the player has
  cmp #109                                        ; is it >= 109?
  bcc :+                                          ; no - skip ahead
  lda #109                                        ; yes - change to 109!
: sta PlayerHP                                    ;
  sta TmpDivideBy10                               ; prepare for division operation to update statusbar
  ldx #$0                                         ; update the statusbar hp tiles
  jsr UpdateStatusbarTiles                        ;
  lda #$1                                         ; mark that the status bar needs to redraw
  sta StatusbarUpdatePending                      ;
  rts                                             ; done!

UpdateMPDisplay:
  lda PlayerMP                                    ; check how much magic the player has
  cmp #109                                        ; is it >= 109?
  bcc :+                                          ; no - skip ahead
  lda #109                                        ; yes - change to 109!
: sta PlayerMP                                    ;
  sta TmpDivideBy10                               ; prepare for division operation to update statusbar
  ldx #$6                                         ; update the statusbar mp tiles
  jsr UpdateStatusbarTiles                        ;
  lda #$1                                         ; mark that the status bar needs to redraw
  sta StatusbarUpdatePending                      ;
  rts                                             ; done!

UpdateKeysDisplay:
  lda PlayerKeys                                  ; check how many keys the player has
  cmp #109                                        ; is it >= 109?
  bcc :+                                          ; no - skip ahead
  lda #109                                        ; yes - change to 109!
: sta PlayerKeys                                  ;
  sta TmpDivideBy10                               ; prepare for division operation to update statusbar
  ldx #$C                                         ; update the statusbar key tiles
  jsr UpdateStatusbarTiles                        ;
  lda #$1                                         ; mark that the status bar needs to redraw
  sta StatusbarUpdatePending                      ;
  rts                                             ; done!

UpdateGoldDisplay:
  LDA PlayerGold                                  ; check how much gold the player has
  cmp #109                                        ; is it >= 109?
  bcc :+                                          ; no - skip ahead
  lda #109                                        ; yes - change to 109!
: sta PlayerGold                                  ;
  sta TmpDivideBy10                               ; prepare for division operation to update statusbar
  ldx #$12                                        ; update the statusbar gold tiles
  jsr UpdateStatusbarTiles                        ;
  lda #$1                                         ; mark that the status bar needs to redraw
  sta StatusbarUpdatePending                      ;
  rts                                             ; done!

UpdateStatusbarTiles:
  txa                                             ; copy tile offset to stack
  pha                                             ;
  ldy #$5                                         ; start by writing 5 empty top tiles
  lda #$DC                                        ;
: sta StatusbarNTTiles,x                          ;
  inx                                             ;
  dey                                             ;
  bne :-                                          ;
  pla                                             ; restore X from stack, and repush
  pha                                             ;
  tax                                             ;
  ldy #$5                                         ; then write 5 empty bottom tiles
  lda #$DF                                        ;
: STA StatusbarNTTiles+$20,X                      ;
  inx                                             ;
  dey                                             ;
  bne :-                                          ;
  pla                                             ; restore X from stack
  tax                                             ;
  jsr DivideBy10                                  ; divide value by 10, to get number of top and bottom bars to fill
  txa                                             ;
: dey                                             ;
  beq @Singles                                    ; if we've reached the end, skip ahead
  dec StatusbarNTTiles,x                          ; fill partial tile
  dey                                             ;
  beq @Singles                                    ; if we've reached the end, skip ahead
  dec StatusbarNTTiles,x                          ; fill partial tile
  inx                                             ; advance to next tile
  jmp :-                                          ; and loop until we're done!
@Singles:
  tax                                             ;
  ldy TmpDivideBy10                               ; get modulo result
: dey                                             ;
  beq @Done                                       ; if we've reached the end, skip ahead
  dec StatusbarNTTiles+$20,x                      ; fill partial tile
  dey                                             ;
  beq @Done                                       ; if we've reached the end, skip ahead
  dec StatusbarNTTiles+$20,x                      ; fill partial tile
  inx                                             ; advance to next tile
  jmp :-                                          ; and loop until we're done!
@Done:
  rts                                             ; done!

.byte $AD,$05,$04,$C9,$6D,$90,$02,$A9             ;  1CB53 CB53 ........ ????m??? 
.byte $6D,$85,$08,$A9,$00,$85,$09,$A2             ;  1CB5B CB5B ........ m??????? 
.byte $A5,$A0,$AB,$4C,$94,$CB,$AD,$05             ;  1CB63 CB63 ........ ???L???? 
.byte $04,$C9,$6D,$90,$02,$A9,$6D,$85             ;  1CB6B CB6B ........ ??m???m? 
.byte $08,$A9,$00,$85,$09,$A2,$65,$A0             ;  1CB73 CB73 ........ ??????e? 
.byte $6B,$4C,$94,$CB,$A5,$58,$C9,$6D             ;  1CB7B CB7B ........ kL???X?m 
.byte $90,$02,$A9,$6D,$85,$08,$A9,$80             ;  1CB83 CB83 ........ ???m???? 
.byte $85,$09,$A2,$65,$A0,$6B,$4C,$94             ;  1CB8B CB8B ........ ???e?kL? 
.byte $CB,$8A,$A6,$09,$9D,$59,$02,$9D             ;  1CB93 CB93 ........ ?????Y?? 
.byte $5D,$02,$9D,$61,$02,$9D,$65,$02             ;  1CB9B CB9B ........ ]??a??e? 
.byte $9D,$69,$02,$98,$9D,$6D,$02,$9D             ;  1CBA3 CBA3 ........ ?i???m?? 
.byte $71,$02,$9D,$75,$02,$9D,$79,$02             ;  1CBAB CBAB ........ q??u??y? 
.byte $9D,$7D,$02,$20,$FA,$CB,$A5,$09             ;  1CBB3 CBB3 ........ ?}? ???? 
.byte $18,$69,$18,$AA,$88,$F0,$16,$DE             ;  1CBBB CBBB ........ ?i?????? 
.byte $41,$02,$DE,$41,$02,$88,$F0,$0D             ;  1CBC3 CBC3 ........ A??A???? 
.byte $DE,$41,$02,$DE,$41,$02,$E8,$E8             ;  1CBCB CBCB ........ ?A??A??? 
.byte $E8,$E8,$4C,$BF,$CB,$A5,$09,$18             ;  1CBD3 CBD3 ........ ??L????? 
.byte $69,$2C,$AA,$A4,$08,$88,$F0,$16             ;  1CBDB CBDB ........ i,?????? 
.byte $DE,$41,$02,$DE,$41,$02,$88,$F0             ;  1CBE3 CBE3 ........ ?A??A??? 
.byte $0D,$DE,$41,$02,$DE,$41,$02,$E8             ;  1CBEB CBEB ........ ??A??A?? 
.byte $E8,$E8,$E8,$4C,$E0,$CB,$60                 ;  1CBF3 CBF3 .......  ???L??`  

DivideBy10:
  lda TmpDivideBy10                               ; get the value to divide from temp location
  ldy #$0                                         ;
  sec                                             ;
: iny                                             ; advance result
  sbc #10                                         ; subtract 10 as long as we can
  bcs :-                                          ;
  adc #11                                         ; then add back remainder
  sta TmpDivideBy10                               ; store modulo result
  rts                                             ; done!

WaitForNewInputRelease:
  jsr WaitUntilNoInputsHeld                       ; wait until the user stops pressing any inputs
  jsr WaitUntilInputsHeld                         ; then wait until a button is pressed
  pha                                             ; and store the inputs
  jsr WaitUntilNoInputsHeld                       ; wait until the user stops pressing any inputs
  pla                                             ; restore the inputs that were pressed
  sta JoypadInput                                 ; and store those as our inputs
  rts                                             ; done!

WaitUntilNoInputsHeld:
: lda #$1                                         ; prepare to delay until next frame
  sta FrameCountdownTimer                         ;
  jsr UpdatePlayerSprites                         ; redraw everything
  jsr UpdateEntitySprites                         ;
  jsr UpdateInventorySprites                      ;
  jsr WaitForCountdownTimer                       ; delay
  jsr ReadJoypad                                  ; get the inputs held
  bne :-                                          ; if any inputs held - loop back around
  rts                                             ; no inputs are pressed, we're done!

WaitUntilInputsHeld:
: lda #$1                                         ; prepare to delay until next frame
  sta FrameCountdownTimer                         ;
  jsr UpdatePlayerSprites                         ; redraw everything
  jsr UpdateEntitySprites                         ;
  jsr UpdateInventorySprites                      ;
  jsr WaitForCountdownTimer                       ; delay
  jsr ReadJoypad                                  ; get the inputs held
  beq :-                                          ; if no inputs held - loop back around
  rts                                             ; some inputs are pressed, we're done!

ReadJoypad:
  ldx #1                                          ; start reading joypad
  stx JOYPAD1                                     ; 
  dex                                             ; 
  stx JOYPAD1                                     ; 
  ldx #8                                          ; reading 8 inputs
: lda JOYPAD1                                     ; combine first and second controller inputs
  ora JOYPAD2_FrameCtr                            ;
  lsr a                                           ; shift input into carry
  rol JoypadInput                                 ; add it to inputs
  lsr a                                           ; shift expansion port input into carry
  rol JoypadInputExp                              ; add it to expansion slot inputs
  dex                                             ; advance to next input
  bne :-                                          ; loop until done
  lda JoypadInput                                 ; combine inputs with expansion inputs
  ora JoypadInputExp                              ;
  sta JoypadInput                                 ;
  rts                                             ; done!

StepRNG:
  sta RNGUpperBound                               ; set the upper bound we want of our rng
  beq @Done                                       ; if we don't actually want RNG, exit immediately
  ldx RNGValue+2                                  ; get initial rng state
  ldy RNGValue+1                                  ;
@KeepRolling:
  sty RNGValue                                    ; copy state
  tya                                             ; shift Y by 1
  asl a                                           ;
  tay                                             ;
  txa                                             ; shift X by 1
  rol a                                           ;
  tax                                             ;
  iny                                             ; and increment rng by 1
  bne :+                                          ; carry into X if needed
  inx                                             ;
: clc                                             ;
  tya                                             ; add previous rng value
  adc RNGValue+1                                  ;
  tay                                             ;
  txa                                             ;
  adc RNGValue+2                                  ;
  clc                                             ;
  adc RNGValue                                    ;
  and #$7F                                        ; clamp to positive result
  tax                                             ;
  stx RNGValue+2                                  ; and store result
  sty RNGValue+1                                  ;
  cmp RNGUpperBound                               ; check if we're within the requested range
  bcs @KeepRolling                                ; if not, keep rolling.
@Done:
  rts                                             ; done!

RunPPUOp:
  pha                                             ; store requested operation on stack
: lda PPUOperation                                ; wait for previous NMI operation to clear
  bne :-                                          ;
  pla                                             ; restore requested operation
  sta PPUOperation                                ; and set NMI flag
WaitForPPUOp:
: lda PPUOperation                                ; wait for flag to clear
  bne :-                                          ;
  rts                                             ; done!

BankCallMenu:
  lda SelectedBank6                               ; store current banks
  sta SelectedBank6_Prev                          ;
  lda SelectedBank7                               ;
  sta SelectedBank7_Prev                          ;
  LDA #$CC                                        ;  1CCA4 CCA4 C A9 CC           F:000004
  PHA                                             ;  1CCA6 CCA6 C 48              F:000004
  LDA #$C7                                        ;  1CCA7 CCA7 C A9 C7           F:000004
  PHA                                             ;  1CCA9 CCA9 C 48              F:000004
  LDY #$6                                         ;  1CCAA CCAA C A0 06           F:000004
  STY MMC3LastBankSelect                                      ;  1CCAC CCAC C 84 25           F:000004
  STY MMC3_RegBankSelect                                   ;  1CCAE CCAE C 8C 00 80        F:000004
  LDA #$C                                         ;  1CCB1 CCB1 C A9 0C           F:000004
  STA SelectedBank6                                      ;  1CCB3 CCB3 C 85 30           F:000004
  STA MMC3_RegBankData                                   ;  1CCB5 CCB5 C 8D 01 80        F:000004
  INY                                             ;  1CCB8 CCB8 C C8              F:000004
  STY MMC3LastBankSelect                                      ;  1CCB9 CCB9 C 84 25           F:000004
  STY MMC3_RegBankSelect                                  ;  1CCBB CCBB C 8C 00 80        F:000004
  LDA #$D                                         ;  1CCBE CCBE C A9 0D           F:000004
  STA SelectedBank7                                      ;  1CCC0 CCC0 C 85 31           F:000004
  STA MMC3_RegBankData                                  ;  1CCC2 CCC2 C 8D 01 80        F:000004
  JMP (TmpE)                                    ;  1CCC5 CCC5 C 6C 0E 00        F:000004

  LDY #$7                                         ;  1CCC8 CCC8 C A0 07           F:000172
  STY MMC3LastBankSelect                                      ;  1CCCA CCCA C 84 25           F:000172
  STY MMC3_RegBankSelect                                  ;  1CCCC CCCC C 8C 00 80        F:000172
  LDA SelectedBank7_Prev                                      ;  1CCCF CCCF C A5 33           F:000172
  STA SelectedBank7                                      ;  1CCD1 CCD1 C 85 31           F:000172
  STA MMC3_RegBankData                                  ;  1CCD3 CCD3 C 8D 01 80        F:000172
  DEY                                             ;  1CCD6 CCD6 C 88              F:000172
  STY MMC3LastBankSelect                                      ;  1CCD7 CCD7 C 84 25           F:000172
  STY MMC3_RegBankSelect                                  ;  1CCD9 CCD9 C 8C 00 80        F:000172
  LDA SelectedBank6_Prev                                      ;  1CCDC CCDC C A5 32           F:000172
  STA SelectedBank6                                      ;  1CCDE CCDE C 85 30           F:000172
  STA MMC3_RegBankData                                  ;  1CCE0 CCE0 C 8D 01 80        F:000172
  RTS                                             ;  1CCE3 CCE3 C 60              F:000172

CommonBankJSR:
  lda #>(MMC3UseCommonBank-1)                     ; put bank restore on stack for callees rts
  pha                                             ;
  lda #<(MMC3UseCommonBank-1)                     ;
  pha                                             ;
  ldy #$7                                         ; select bank 7
  sty MMC3LastBankSelect                          ;
  sty MMC3_RegBankSelect                          ;
  lda SelectedBank7_Prev                          ; swap to stored bank
  sta SelectedBank7                               ;
  sta MMC3_RegBankData                            ;
  dey                                             ;
  sty MMC3LastBankSelect                          ; select bank 6
  sty MMC3_RegBankSelect                          ;
  lda SelectedBank6_Prev                          ; swap to stored bank
  sta SelectedBank6                               ;
  sta MMC3_RegBankData                            ;
  jmp (TmpE)                                      ; and call the requested routine

MMC3UseCommonBank:
  lda SelectedBank6                               ; copy back previous bank selections
  sta SelectedBank6_Prev                          ;
  lda SelectedBank7                               ;
  sta SelectedBank7_Prev                          ;
  ldy #$6                                         ; select bank 6
  sty MMC3LastBankSelect                          ;
  sty MMC3_RegBankSelect                          ;
  lda #$C                                         ; swap to common bank
  sta SelectedBank6                               ;
  sta MMC3_RegBankData                            ;
  iny                                             ; select bank 7
  sty MMC3LastBankSelect                          ;
  sty MMC3_RegBankSelect                          ;
  lda #$D                                         ; swap to common bank
  sta SelectedBank7                               ;
  sta MMC3_RegBankData                            ;
  rts                                             ; done!

L_14_1CD2C:
  sty Tmp9                                        ; store and reload player speed.
  ldy Tmp9                                        ;
  BEQ B_14_1CD67                                  ;  1CD30 CD30 C F0 35           F:001373
  lda JoypadInput                                 ; get directional inputs
  and #CtlDPad                        ;
  asl a                                           ; and multiply into table offset
  tax                                             ;
  lda #$0                                         ;
: clc                                             ; add speed once per active speed boost
  adc PlayerDirections,x                     ;
  dey                                             ;
  bne :-                                          ; loop
  PHA                                             ;  1CD41 CD41 C 48              F:001373
  AND #$F                                         ;  1CD42 CD42 C 29 0F           F:001373
  STA PlayerMovingDirection                                      ;  1CD44 CD44 C 85 49           F:001373
  LDY #$0                                         ;  1CD46 CD46 C A0 00           F:001373
  PLA                                             ;  1CD48 CD48 C 68              F:001373
  BPL B_14_1CD4D                                  ;  1CD49 CD49 C 10 02           F:001373
  LDY #$F0                                        ;  1CD4B CD4B C A0 F0           F:001373
B_14_1CD4D:
  STY R_0008                                      ;  1CD4D CD4D C 84 08           F:001373
  AND #$F0                                        ;  1CD4F CD4F C 29 F0           F:001373
  LSR                                             ;  1CD51 CD51 C 4A              F:001373
  LSR                                             ;  1CD52 CD52 C 4A              F:001373
  LSR                                             ;  1CD53 CD53 C 4A              F:001373
  LSR                                             ;  1CD54 CD54 C 4A              F:001373
  ORA R_0008                                      ;  1CD55 CD55 C 05 08           F:001373
  STA PlayerFacingDirection                                      ;  1CD57 CD57 C 85 4A           F:001373
  LDY Tmp9                                      ;  1CD59 CD59 C A4 09           F:001373
  LDA #$0                                         ;  1CD5B CD5B C A9 00           F:001373
B_14_1CD5D:
  CLC                                             ;  1CD5D CD5D C 18              F:001373
  ADC PlayerDirections+1,X                                ;  1CD5E CD5E C 7D 8C FE        F:001373
  DEY                                             ;  1CD61 CD61 C 88              F:001373
  BNE B_14_1CD5D                                  ;  1CD62 CD62 C D0 F9           F:001373
  STA PlayerYPxSpeed                                      ;  1CD64 CD64 C 85 4B           F:001373
  RTS                                             ;  1CD66 CD66 C 60              F:001373

B_14_1CD67:
  LDA #$0                                         ;  1CD67 CD67 . A9 00           
  STA PlayerMovingDirection                                      ;  1CD69 CD69 . 85 49           
  STA PlayerFacingDirection                                      ;  1CD6B CD6B . 85 4A           
  STA PlayerYPxSpeed                                      ;  1CD6D CD6D . 85 4B           
  RTS                                             ;  1CD6F CD6F . 60              

SetWorksetDirectionSpeed:
  @Tmp8 = $08
  @Tmp9 = $09
  sty @Tmp9                                       ; store multiplication factor
  ldy @Tmp9                                       ;
  beq @Zero                                       ; multiply by 0 is easy enough
  and #%00001111                                  ;
  ASL                                             ;  1CD78 CD78 C 0A              F:001379
  TAX                                             ;  1CD79 CD79 C AA              F:001379
  LDA #$0                                         ;  1CD7A CD7A C A9 00           F:001379
: clc                                             ;
  adc PlayerDirections,x                          ; add direction
  dey                                             ;
  bne :-                                          ; keep adding until multiplied
  pha                                             ; store result on stack
  and #%00001111                                  ; get sub-tile result
  sta Workset+Ent_XPxSpeed                        ; store as pixel speed
  ldy #$00                                        ; set Y to moving right
  pla                                             ; restore full speed result
  bpl :+                                          ; skip ahead if moving left
  ldy #$F0                                        ; otherwise set Y to moving left
: sty @Tmp8                                       ; store direction bits
  and #$F0                                        ; remove pixel bits for no reason
  lsr a                                           ; then shift high nybble to low
  lsr a                                           ;
  lsr a                                           ;
  lsr a                                           ;
  ora @Tmp8                                       ; and combine with direction
  sta Workset+Ent_XTileSpeed                      ; and use as the tile speed
  ldy @Tmp9                                       ; now multiply y direction
  lda #$0                                         ;
: clc                                             ;
  adc PlayerDirections+1,x                        ;
  dey                                             ;
  bne :-                                          ; loop until done multiplying
  STA Workset+Ent_YPxSpeed                        ; store as y speed
  rts                                             ; done!
@Zero:
  lda #$0                                         ; clear speeds
  sta Workset+Ent_XPxSpeed                        ;
  sta Workset+Ent_XTileSpeed                      ;
  sta Workset+Ent_YPxSpeed                        ;
  rts                                             ; done!

L_14_1CDB2:
  LDY #$9                                         ;  1CDB2 CDB2 C A0 09           F:001389
  LDX #$90                                        ;  1CDB4 CDB4 C A2 90           F:001389
B_14_1CDB6:
  CPY ActiveEntity                                      ;  1CDB6 CDB6 C C4 E3           F:001389
  BEQ B_14_1CE0A                                  ;  1CDB8 CDB8 C F0 50           F:001389
  LDA Ent0Data+Ent_State,X                                    ;  1CDBA CDBA C BD 01 04        F:001389
  BMI B_14_1CE0A                                  ;  1CDBD CDBD C 30 4B           F:001389
  CMP #$1                                         ;  1CDBF CDBF C C9 01           F:001389
  BEQ B_14_1CDC7                                  ;  1CDC1 CDC1 C F0 04           F:001389
  CMP #$1A                                        ;  1CDC3 CDC3 C C9 1A           F:001389
  BCC B_14_1CE0A                                  ;  1CDC5 CDC5 C 90 43           F:001389
B_14_1CDC7:
  LDA Ent0Data,X                                    ;  1CDC7 CDC7 C BD 00 04        F:001389
  AND #$F9                                        ;  1CDCA CDCA C 29 F9           F:001389
  CMP #$E1                                        ;  1CDCC CDCC C C9 E1           F:001389
  BEQ B_14_1CE0A                                  ;  1CDCE CDCE C F0 3A           F:001389
  LDA Ent0Data+Ent_SprAttr,X                                    ;  1CDD0 CDD0 C BD 02 04        F:001389
  AND #$20                                        ;  1CDD3 CDD3 C 29 20           F:001389
  BNE B_14_1CE0A                                  ;  1CDD5 CDD5 C D0 33           F:001389
  LDA TmpA                                      ;  1CDD7 CDD7 C A5 0A           F:001389
  SEC                                             ;  1CDD9 CDD9 C 38              F:001389
  SBC Ent0Data+Ent_YPx,X                                    ;  1CDDA CDDA C FD 0E 04        F:001389
  CMP #$10                                        ;  1CDDD CDDD C C9 10           F:001389
  BCC B_14_1CDE5                                  ;  1CDDF CDDF C 90 04           F:001389
  CMP #$F1                                        ;  1CDE1 CDE1 C C9 F1           F:001389
  BCC B_14_1CE0A                                  ;  1CDE3 CDE3 C 90 25           F:001389
B_14_1CDE5:
  LDA TmpF                                      ;  1CDE5 CDE5 C A5 0F           F:001389
  SEC                                             ;  1CDE7 CDE7 C 38              F:001389
  SBC Ent0Data+Ent_XTile,X                                    ;  1CDE8 CDE8 C FD 0D 04        F:001389
  BEQ B_14_1CE14                                  ;  1CDEB CDEB C F0 27           F:001389
  CMP #$2                                         ;  1CDED CDED C C9 02           F:001389
  BCC B_14_1CE02                                  ;  1CDEF CDEF C 90 11           F:001389
  CMP #$FF                                        ;  1CDF1 CDF1 C C9 FF           F:001389
  BCC B_14_1CE0A                                  ;  1CDF3 CDF3 C 90 15           F:001389
  LDA TmpE                                      ;  1CDF5 CDF5 C A5 0E           F:001537
  SEC                                             ;  1CDF7 CDF7 C 38              F:001537
  SBC Ent0Data+Ent_XPx,X                                    ;  1CDF8 CDF8 C FD 0C 04        F:001537
  BEQ B_14_1CE0A                                  ;  1CDFB CDFB C F0 0D           F:001537
  BMI B_14_1CE0A                                  ;  1CDFD CDFD C 30 0B           F:001537
  JMP B_14_1CE14                                  ;  1CDFF CDFF C 4C 14 CE        F:001542

B_14_1CE02:
  LDA TmpE                                      ;  1CE02 CE02 C A5 0E           F:001554
  SEC                                             ;  1CE04 CE04 C 38              F:001554
  SBC Ent0Data+Ent_XPx,X                                    ;  1CE05 CE05 C FD 0C 04        F:001554
  BMI B_14_1CE14                                  ;  1CE08 CE08 C 30 0A           F:001554
B_14_1CE0A:
  TXA                                             ;  1CE0A CE0A C 8A              F:001389
  SEC                                             ;  1CE0B CE0B C 38              F:001389
  SBC #$10                                        ;  1CE0C CE0C C E9 10           F:001389
  TAX                                             ;  1CE0E CE0E C AA              F:001389
  DEY                                             ;  1CE0F CE0F C 88              F:001389
  BPL B_14_1CDB6                                  ;  1CE10 CE10 C 10 A4           F:001389
  CLC                                             ;  1CE12 CE12 C 18              F:001389
  RTS                                             ;  1CE13 CE13 C 60              F:001389

B_14_1CE14:
  STY R_0008                                      ;  1CE14 CE14 C 84 08           F:001542
  STX Tmp9                                      ;  1CE16 CE16 C 86 09           F:001542
  SEC                                             ;  1CE18 CE18 C 38              F:001542
  RTS                                             ;  1CE19 CE19 C 60              F:001542

L_14_1CE1A:
  LDY #$A                                         ;  1CE1A CE1A C A0 0A           F:001373
  LDX #$A0                                        ;  1CE1C CE1C C A2 A0           F:001373
B_14_1CE1E:
  CPY ActiveEntity                                      ;  1CE1E CE1E C C4 E3           F:001373
  BEQ B_14_1CE6C                                  ;  1CE20 CE20 C F0 4A           F:001373
  LDA Ent0Data+Ent_State,X                                    ;  1CE22 CE22 C BD 01 04        F:001373
  BEQ B_14_1CE6C                                  ;  1CE25 CE25 C F0 45           F:001373
  BMI B_14_1CE6C                                  ;  1CE27 CE27 C 30 43           F:001373
  LDA Ent0Data,X                                    ;  1CE29 CE29 C BD 00 04        F:001373
  AND #$F9                                        ;  1CE2C CE2C C 29 F9           F:001373
  CMP #$E1                                        ;  1CE2E CE2E C C9 E1           F:001373
  BEQ B_14_1CE6C                                  ;  1CE30 CE30 C F0 3A           F:001373
  LDA Ent0Data+Ent_SprAttr,X                                    ;  1CE32 CE32 C BD 02 04        F:001373
  AND #$20                                        ;  1CE35 CE35 C 29 20           F:001373
  BNE B_14_1CE6C                                  ;  1CE37 CE37 C D0 33           F:001373
  LDA TmpA                                      ;  1CE39 CE39 C A5 0A           F:001373
  SEC                                             ;  1CE3B CE3B C 38              F:001373
  SBC Ent0Data+Ent_YPx,X                                    ;  1CE3C CE3C C FD 0E 04        F:001373
  CMP #$10                                        ;  1CE3F CE3F C C9 10           F:001373
  BCC B_14_1CE47                                  ;  1CE41 CE41 C 90 04           F:001373
  CMP #$F1                                        ;  1CE43 CE43 C C9 F1           F:001373
  BCC B_14_1CE6C                                  ;  1CE45 CE45 C 90 25           F:001373
B_14_1CE47:
  LDA TmpF                                      ;  1CE47 CE47 C A5 0F           F:001374
  SEC                                             ;  1CE49 CE49 C 38              F:001374
  SBC Ent0Data+Ent_XTile,X                                    ;  1CE4A CE4A C FD 0D 04        F:001374
  BEQ B_14_1CE76                                  ;  1CE4D CE4D C F0 27           F:001374
  CMP #$2                                         ;  1CE4F CE4F C C9 02           F:001374
  BCC B_14_1CE64                                  ;  1CE51 CE51 C 90 11           F:001374
  CMP #$FF                                        ;  1CE53 CE53 C C9 FF           F:001374
  BCC B_14_1CE6C                                  ;  1CE55 CE55 C 90 15           F:001374
  LDA TmpE                                      ;  1CE57 CE57 C A5 0E           F:001535
  SEC                                             ;  1CE59 CE59 C 38              F:001535
  SBC Ent0Data+Ent_XPx,X                                    ;  1CE5A CE5A C FD 0C 04        F:001535
  BEQ B_14_1CE6C                                  ;  1CE5D CE5D C F0 0D           F:001535
  BMI B_14_1CE6C                                  ;  1CE5F CE5F C 30 0B           F:001535
  JMP B_14_1CE76                                  ;  1CE61 CE61 C 4C 76 CE        F:001542

B_14_1CE64:
  LDA TmpE                                      ;  1CE64 CE64 C A5 0E           F:001554
  SEC                                             ;  1CE66 CE66 C 38              F:001554
  SBC Ent0Data+Ent_XPx,X                                    ;  1CE67 CE67 C FD 0C 04        F:001554
  BMI B_14_1CE76                                  ;  1CE6A CE6A C 30 0A           F:001554
B_14_1CE6C:
  TXA                                             ;  1CE6C CE6C C 8A              F:001373
  SEC                                             ;  1CE6D CE6D C 38              F:001373
  SBC #$10                                        ;  1CE6E CE6E C E9 10           F:001373
  TAX                                             ;  1CE70 CE70 C AA              F:001373
  DEY                                             ;  1CE71 CE71 C 88              F:001373
  BPL B_14_1CE1E                                  ;  1CE72 CE72 C 10 AA           F:001373
  CLC                                             ;  1CE74 CE74 C 18              F:001373
  RTS                                             ;  1CE75 CE75 C 60              F:001373

B_14_1CE76:
  STY R_0008                                      ;  1CE76 CE76 C 84 08           F:001542
  STX Tmp9                                      ;  1CE78 CE78 C 86 09           F:001542
  SEC                                             ;  1CE7A CE7A C 38              F:001542
  RTS                                             ;  1CE7B CE7B C 60              F:001542

L_14_1CE7C:
  LDA #$0                                         ;  1CE7C CE7C C A9 00           F:001373
  STA R_00EA                                      ;  1CE7E CE7E C 85 EA           F:001373
  JSR L_14_1CEB6                                  ;  1CE80 CE80 C 20 B6 CE        F:001373
  BCC B_14_1CE8F                                  ;  1CE83 CE83 C 90 0A           F:001373
  JSR L_14_1CE90                                  ;  1CE85 CE85 C 20 90 CE        F:001373
  BCC B_14_1CE8F                                  ;  1CE88 CE88 C 90 05           F:001373
  LDA #$1                                         ;  1CE8A CE8A C A9 01           F:001544
  STA R_00EA                                      ;  1CE8C CE8C C 85 EA           F:001544
  SEC                                             ;  1CE8E CE8E C 38              F:001544
B_14_1CE8F:
  RTS                                             ;  1CE8F CE8F C 60              F:001373

L_14_1CE90:
  SEC                                             ;  1CE90 CE90 C 38              F:001373
  LDA TmpF                                      ;  1CE91 CE91 C A5 0F           F:001373
  SBC PlayerXTile                                      ;  1CE93 CE93 C E5 44           F:001373
  BEQ B_14_1CEB4                                  ;  1CE95 CE95 C F0 1D           F:001373
  CMP #$2                                         ;  1CE97 CE97 C C9 02           F:001373
  BCC B_14_1CEAB                                  ;  1CE99 CE99 C 90 10           F:001373
  CMP #$FF                                        ;  1CE9B CE9B C C9 FF           F:001373
  BCC B_14_1CEB2                                  ;  1CE9D CE9D C 90 13           F:001373
  SEC                                             ;  1CE9F CE9F C 38              F:001553
  LDA TmpE                                      ;  1CEA0 CEA0 C A5 0E           F:001553
  SBC PlayerXPx                                      ;  1CEA2 CEA2 C E5 43           F:001553
  BEQ B_14_1CEB2                                  ;  1CEA4 CEA4 C F0 0C           F:001553
  BMI B_14_1CEB2                                  ;  1CEA6 CEA6 C 30 0A           F:001553
  JMP B_14_1CEB4                                  ;  1CEA8 CEA8 C 4C B4 CE        F:001553

B_14_1CEAB:
  LDA TmpE                                      ;  1CEAB CEAB C A5 0E           F:001535
  SEC                                             ;  1CEAD CEAD C 38              F:001535
  SBC PlayerXPx                                      ;  1CEAE CEAE C E5 43           F:001535
  BMI B_14_1CEB4                                  ;  1CEB0 CEB0 C 30 02           F:001535
B_14_1CEB2:
  CLC                                             ;  1CEB2 CEB2 C 18              F:001373
  RTS                                             ;  1CEB3 CEB3 C 60              F:001373

B_14_1CEB4:
  SEC                                             ;  1CEB4 CEB4 C 38              F:001544
  RTS                                             ;  1CEB5 CEB5 C 60              F:001544

L_14_1CEB6:
  LDA TmpA                                      ;  1CEB6 CEB6 C A5 0A           F:001373
  SEC                                             ;  1CEB8 CEB8 C 38              F:001373
  SBC PlayerYPx                                      ;  1CEB9 CEB9 C E5 45           F:001373
  CMP #$10                                        ;  1CEBB CEBB C C9 10           F:001373
  BCC B_14_1CEC3                                  ;  1CEBD CEBD C 90 04           F:001373
  CMP #$F1                                        ;  1CEBF CEBF C C9 F1           F:001373
  BCC B_14_1CEC5                                  ;  1CEC1 CEC1 C 90 02           F:001373
B_14_1CEC3:
  SEC                                             ;  1CEC3 CEC3 C 38              F:001373
  RTS                                             ;  1CEC4 CEC4 C 60              F:001373

B_14_1CEC5:
  CLC                                             ;  1CEC5 CEC5 C 18              F:001373
  RTS                                             ;  1CEC6 CEC6 C 60              F:001373

.byte $A9,$00,$85,$EA,$A5,$0A,$38,$E5             ;  1CEC7 CEC7 ........ ??????8? 
.byte $45,$C9,$10,$90,$04,$C9,$E1,$90             ;  1CECF CECF ........ E??????? 
.byte $28,$38,$A5,$0F,$E5,$44,$F0,$23             ;  1CED7 CED7 ........ (8???D?# 
.byte $C9,$FF,$F0,$1F,$C9,$02,$90,$11             ;  1CEDF CEDF ........ ???????? 
.byte $C9,$FE,$90,$15,$38,$A5,$0E,$ED             ;  1CEE7 CEE7 ........ ????8??? 
.byte $43,$00,$F0,$0D,$30,$0B,$4C,$02             ;  1CEEF CEEF ........ C???0?L? 
.byte $CF,$A5,$0E,$38,$ED,$43,$00,$30             ;  1CEF7 CEF7 ........ ???8?C?0 
.byte $02,$18,$60,$A9,$01,$85,$EA,$38             ;  1CEFF CEFF ........ ??`????8 
.byte $60                                         ;  1CF07 CF07 .        `        

EnsureNextPositionIsValid:
  lda TmpA                                        ; get the new Y position
  cmp #$C0                                        ; is it going to be off screen?
  bcs @DoneSEC                                    ; if so - exit function
  lda TmpF                                        ; get the new X tile
  cmp #$3F                                        ; compare against max allowed value
  bcc @DoneCLC                                    ; if not above max tile, exit
  lda TmpE                                        ; 
  beq @DoneCLC                                    ;  1CF16 CF16 C F0 02           F:005352
@DoneSEC:
  sec                                             ;  1CF18 CF18 C 38              F:001470
  rts                                             ;  1CF19 CF19 C 60              F:001470
@DoneCLC:
  CLC                                             ;  1CF1A CF1A C 18              F:001373
  RTS                                             ;  1CF1B CF1B C 60              F:001373

L_14_1CF1C:
  LDA TmpA                                      ;  1CF1C CF1C C A5 0A           F:007626
  CMP #$B0                                        ;  1CF1E CF1E C C9 B0           F:007626
  BCS B_14_1CF2C                                  ;  1CF20 CF20 C B0 0A           F:007626
  LDA TmpF                                      ;  1CF22 CF22 C A5 0F           F:007626
  CMP #$3F                                        ;  1CF24 CF24 C C9 3F           F:007626
  BCC B_14_1CF2E                                  ;  1CF26 CF26 C 90 06           F:007626
  LDA TmpE                                      ;  1CF28 CF28 . A5 0E           
  BEQ B_14_1CF2E                                  ;  1CF2A CF2A . F0 02           
B_14_1CF2C:
  SEC                                             ;  1CF2C CF2C . 38              
  RTS                                             ;  1CF2D CF2D . 60              

B_14_1CF2E:
  CLC                                             ;  1CF2E CF2E C 18              F:007626
  RTS                                             ;  1CF2F CF2F C 60              F:007626

PauseMenu_DrawInventory:
  LDX #$F                                         ;  1CF30 CF30 C A2 0F           F:000826
B_14_1CF32:
  TXA                                             ;  1CF32 CF32 C 8A              F:000826
  PHA                                             ;  1CF33 CF33 C 48              F:000826
  LDY PlayerInventory,X                                    ;  1CF34 CF34 C B4 60           F:000826
  JSR L_14_1CF3F                                  ;  1CF36 CF36 C 20 3F CF        F:000826
  PLA                                             ;  1CF39 CF39 C 68              F:000827
  TAX                                             ;  1CF3A CF3A C AA              F:000827
  DEX                                             ;  1CF3B CF3B C CA              F:000827
  BPL B_14_1CF32                                  ;  1CF3C CF3C C 10 F4           F:000827
  RTS                                             ;  1CF3E CF3E C 60              F:000842

L_14_1CF3F:
  TXA                                             ;  1CF3F CF3F C 8A              F:000826
  PHA                                             ;  1CF40 CF40 C 48              F:000826
  TXA                                             ;  1CF41 CF41 C 8A              F:000826
  AND #$7                                         ;  1CF42 CF42 C 29 07           F:000826
  ASL                                             ;  1CF44 CF44 C 0A              F:000826
  ASL                                             ;  1CF45 CF45 C 0A              F:000826
  STA PPUUpdateAddrLo                                      ;  1CF46 CF46 C 85 16           F:000826
  TXA                                             ;  1CF48 CF48 C 8A              F:000826
  AND #$8                                         ;  1CF49 CF49 C 29 08           F:000826
  ASL                                             ;  1CF4B CF4B C 0A              F:000826
  ASL                                             ;  1CF4C CF4C C 0A              F:000826
  ASL                                             ;  1CF4D CF4D C 0A              F:000826
  ASL                                             ;  1CF4E CF4E C 0A              F:000826
  ORA PPUUpdateAddrLo                                      ;  1CF4F CF4F C 05 16           F:000826
  STA PPUUpdateAddrLo                                      ;  1CF51 CF51 C 85 16           F:000826
  LDA #$0                                         ;  1CF53 CF53 C A9 00           F:000826
  STA PPUUpdateAddrHi                                      ;  1CF55 CF55 C 85 17           F:000826
  CLC                                             ;  1CF57 CF57 C 18              F:000826
  LDA #$C2                                        ;  1CF58 CF58 C A9 C2           F:000826
  ADC PPUUpdateAddrLo                                      ;  1CF5A CF5A C 65 16           F:000826
  STA PPUUpdateAddrLo                                      ;  1CF5C CF5C C 85 16           F:000826
  LDA #$20                                        ;  1CF5E CF5E C A9 20           F:000826
  ADC PPUUpdateAddrHi                                      ;  1CF60 CF60 C 65 17           F:000826
  STA PPUUpdateAddrHi                                      ;  1CF62 CF62 C 85 17           F:000826
  TYA                                             ;  1CF64 CF64 C 98              F:000826
  JSR WriteNumberToPPUUpdateData                                  ;  1CF65 CF65 C 20 F9 CF        F:000826
  PLA                                             ;  1CF68 CF68 C 68              F:000826
  JSR CanPlayerEquipItem                                  ;  1CF69 CF69 C 20 17 D0        F:000826
  BCS B_14_1CF7C                                  ;  1CF6C CF6C C B0 0E           F:000826
  LDA PPUUpdateData                                      ;  1CF6E CF6E C A5 18           F:000826
  SEC                                             ;  1CF70 CF70 C 38              F:000826
  SBC #$40                                        ;  1CF71 CF71 C E9 40           F:000826
  STA PPUUpdateData                                      ;  1CF73 CF73 C 85 18           F:000826
  LDA PPUUpdateData+1                                      ;  1CF75 CF75 C A5 19           F:000826
  SEC                                             ;  1CF77 CF77 C 38              F:000826
  SBC #$40                                        ;  1CF78 CF78 C E9 40           F:000826
  STA PPUUpdateData+1                                      ;  1CF7A CF7A C 85 19           F:000826
B_14_1CF7C:
  LDA #PPUOps_WriteBuffer                                       ;  1CF7C CF7C C A9 06           F:000826
  JSR RunPPUOp                                  ;  1CF7E CF7E C 20 8F CC        F:000826
  RTS                                             ;  1CF81 CF81 C 60              F:000827

PauseMenuAttrStrength = $21DE
PauseMenuAttrJump     = $221E
PauseMenuAttrDistance = $225E
PauseMenu_DrawCharacterAttributes:
  lda #<PauseMenuAttrStrength                     ; prepare to move ppu to next attribute position
  sta PPUUpdateAddrLo                             ;
  lda #>PauseMenuAttrStrength                     ;
  sta PPUUpdateAddrHi                             ;
  jsr GetCurrentPlayerStrength                    ; get the attribute value 
  jsr WriteNumberToPPUUpdateData                  ; and write it to the update data
  lda #PPUOps_WriteBuffer                         ;
  jsr RunPPUOp                                    ; then write it to the ppu!
  lda #<PauseMenuAttrJump                         ; prepare to move ppu to next attribute position
  sta PPUUpdateAddrLo                             ;
  lda #>PauseMenuAttrJump                         ;
  sta PPUUpdateAddrHi                             ;
  jsr GetCurrentPlayerJump                        ; get the attribute value 
  jsr WriteNumberToPPUUpdateData                  ; and write it to the update data
  lda #PPUOps_WriteBuffer                         ;
  jsr RunPPUOp                                    ; then write it to the ppu!
  lda #<PauseMenuAttrDistance                     ; prepare to move ppu to next attribute position
  sta PPUUpdateAddrLo                             ;
  lda #>PauseMenuAttrDistance                     ;
  sta PPUUpdateAddrHi                             ;
  jsr GetCurrentPlayerDistance                    ; get the attribute value 
  jsr WriteNumberToPPUUpdateData                  ; and write it to the update data
  lda #PPUOps_WriteBuffer                         ;
  jsr RunPPUOp                                    ; then write it to the ppu!
  rts                                             ; done!

L_14_1CFBC:
  LDA #$47                                        ;  1CFBC CFBC C A9 47           F:017567
  STA PPUUpdateAddrLo                                      ;  1CFBE CFBE C 85 16           F:017567
  LDA #$22                                        ;  1CFC0 CFC0 C A9 22           F:017567
  STA PPUUpdateAddrHi                                      ;  1CFC2 CFC2 C 85 17           F:017567
  LDA CameraXTile                                      ;  1CFC4 CFC4 C A5 7C           F:017567
  AND #$10                                        ;  1CFC6 CFC6 C 29 10           F:017567
  BEQ B_14_1CFD7                                  ;  1CFC8 CFC8 C F0 0D           F:017567
  CLC                                             ;  1CFCA CFCA C 18              F:053598
  LDA #$0                                         ;  1CFCB CFCB C A9 00           F:053598
  ADC PPUUpdateAddrLo                                      ;  1CFCD CFCD C 65 16           F:053598
  STA PPUUpdateAddrLo                                      ;  1CFCF CFCF C 85 16           F:053598
  LDA #$4                                         ;  1CFD1 CFD1 C A9 04           F:053598
  ADC PPUUpdateAddrHi                                      ;  1CFD3 CFD3 C 65 17           F:053598
  STA PPUUpdateAddrHi                                      ;  1CFD5 CFD5 C 85 17           F:053598
B_14_1CFD7:
  LDA ShopItem1Cost                                      ;  1CFD7 CFD7 C A5 81           F:017567
  JSR WriteNumberToPPUUpdateData                                  ;  1CFD9 CFD9 C 20 F9 CF        F:017567
  LDA #PPUOps_WriteBuffer                               ;  1CFDC CFDC C A9 06           F:017567
  JSR RunPPUOp                                  ;  1CFDE CFDE C 20 8F CC        F:017567
  CLC                                             ;  1CFE1 CFE1 C 18              F:017568
  LDA #$E                                         ;  1CFE2 CFE2 C A9 0E           F:017568
  ADC PPUUpdateAddrLo                                      ;  1CFE4 CFE4 C 65 16           F:017568
  STA PPUUpdateAddrLo                                      ;  1CFE6 CFE6 C 85 16           F:017568
  LDA #$0                                         ;  1CFE8 CFE8 C A9 00           F:017568
  ADC PPUUpdateAddrHi                                      ;  1CFEA CFEA C 65 17           F:017568
  STA PPUUpdateAddrHi                                      ;  1CFEC CFEC C 85 17           F:017568
  LDA ShopItem2Cost                                      ;  1CFEE CFEE C A5 83           F:017568
  JSR WriteNumberToPPUUpdateData                                  ;  1CFF0 CFF0 C 20 F9 CF        F:017568
  LDA #PPUOps_WriteBuffer                            ;  1CFF3 CFF3 C A9 06           F:017568
  JSR RunPPUOp                                  ;  1CFF5 CFF5 C 20 8F CC        F:017568
  RTS                                             ;  1CFF8 CFF8 C 60              F:017569

WriteNumberToPPUUpdateData:
  ldx #$D0                                        ; place 0 character
  stx PPUUpdateData+1                             ;
: cmp #10                                         ; check if value is greater than 10
  bcc :+                                          ; if not - skip ahead
  sbc #10                                         ; otherwise we reduce by 10
  inc PPUUpdateData+1                             ; and increment the high byte of ppudata to write
  jmp :-                                          ; then loop until we're lower than 10!
: adc #$D0                                        ; shift up to number tiles
  sta PPUUpdateData                               ;
  lda PPUUpdateData+1                             ; check the 10s digit
  cmp #$D0                                        ; is it 0?
  bne :+                                          ; nope - we were above 10, so we can continue
  lda #$C0                                        ; otherwise set it to a space
  sta PPUUpdateData+1                             ;
: rts                                             ; done!

CanPlayerEquipItem:
  pha                                             ; put item type on stack
  lda PlayerCharacter                             ; get the current selected player
  asl a                                           ;
  tax                                             ; and use as offset to item table
  pla                                             ;
  cmp #$8                                         ; 
  bcc :+                                          ;
  inx                                             ; adjust index for certain types
: and #%111                                       ;
  tay                                             ;
  iny                                             ;
  lda CharacterUsableItems,x                      ; get the list of usable items for the player
: asl a                                           ; shift through enough bits to get to the selected item
  dey                                             ; this will set the carry based on if the player can use the item
  bne :-                                          ;
  rts                                             ; done!

ChangeMusicIfNeeded:
  cmp CurrentMusic                                ; check if requested track is what we are playing
  beq :+                                          ; if so - just keep playing that
  sta CurrentMusic                                ; otherwise update track
  jsr Audio_StartMusic                            ; and start playing it!
: rts                                             ; done!

GetCurrentPlayerJump:
  ldx PlayerSelectedItemSlot                       ; check if player is using the boost item
  lda PlayerActiveItems,x                         ;
  cmp #ItemType_JumpShoes                         ;
  bne @Nope                                       ; if not - use normal attribute
  lda PlayerMP                                    ; yes! do we have magic?
  beq @Nope                                       ; if not - use normal attribute
  lda PlayerAttrJump                              ; otherwise we add 1/4 of the attribute
  lsr a                                           ;
  lsr a                                           ;
  clc                                             ;
  adc PlayerAttrJump                              ;
  clc                                             ; clear carry to mark that we are using an item
  rts                                             ; done!
@Nope:
  lda PlayerAttrJump                              ;
  sec                                             ; set carry to mark that we are not using an item
  rts                                             ; done!

GetCurrentPlayerStrength:
  ldx PlayerSelectedItemSlot                       ; check if player is using the power knuckle
  lda PlayerActiveItems,x                         ;
  cmp #ItemType_PowerKnuckle                      ;
  bne @Nope                                       ; if not - use normal attribute
  lda PlayerMP                                    ; yes! do we have magic?
  beq @Nope                                       ; if not - use normal attribute
  lda PlayerAttrStrength                          ; otherwise we multiply by 4
  asl a                                           ;
  asl a                                           ;
  clc                                             ; clear carry to mark that we are using an item
  rts                                             ; done!
@Nope:
  lda PlayerAttrStrength                          ;
  sec                                             ; set carry to mark that we are not using an item
  rts                                             ; done!

GetCurrentPlayerDistance:
  ldx PlayerSelectedItemSlot                       ; check if player is using the fire rod
  lda PlayerActiveItems,x                         ;
  cmp #ItemType_FireRod                           ;
  bne @Nope                                       ; if not - use normal attribute
  lda PlayerMP                                    ; yes! do we have magic?
  beq @Nope                                       ; if not - use normal attribute
  lda PlayerAttrDistance                          ; otherwise we multiply by 2
  asl a                                           ;
  clc                                             ; clear carry to mark that we are using an item
  rts                                             ; done!
@Nope:
  lda PlayerAttrDistance                          ;
  sec                                             ; set carry to mark that we are not using an item
  rts                                             ; done!          

ClearEntitySprites:
  lda #$EF                                        ; off screen y position
  ldx #$80                                        ; start at entity sprite list
: sta SprY,x                                      ; move sprite off screen
  inx                                             ; then advance to next sprite
  inx                                             ;
  inx                                             ;
  inx                                             ;
  bne :-                                          ; loop!
  rts                                             ; done

DisableAllEntities:
  ldy #$10                                        ; max 16 entities
  ldx #$0                                         ;
: lda #$0                                         ; unset entity flags
  sta Ent0Data+Ent_State,x                               ;
  LDA #$2                                         ;
  STA Ent0Data+Ent_AnimTimer,X                                    ;
  txa                                             ; advance to next entity
  clc                                             ;
  adc #$10                                        ;
  tax                                             ;
  dey                                             ;
  bne :-                                          ; loop until all entities checked
  lda #$0                                         ;
  STA R_00E9                                      ;  1D0A2 D0A2 C 85 E9           F:001344
  rts                                             ; done

.byte $A2,$07,$BD,$00,$03,$9D,$08,$03             ;  1D0A5 D0A5 ........ ???????? 
.byte $CA,$10,$F7,$A2,$0F,$B5,$60,$9D             ;  1D0AD D0AD ........ ??????`? 
.byte $10,$03,$CA,$10,$F8,$A5,$5A,$8D             ;  1D0B5 D0B5 ........ ??????Z? 
.byte $21,$03,$A5,$5B,$8D,$20,$03,$60             ;  1D0BD D0BD ........ !??[? ?` 

L_14_1D0C5:
.byte $A2,$07,$BD,$08,$03,$9D,$00,$03             ;  1D0C5 D0C5 ........ ???????? 
.byte $CA,$10,$F7,$A2,$0F,$BD,$10,$03             ;  1D0CD D0CD ........ ???????? 
.byte $95,$60,$CA,$10,$F8,$AD,$21,$03             ;  1D0D5 D0D5 ........ ?`????!? 
.byte $85,$5A,$AD,$20,$03,$85,$5B,$60             ;  1D0DD D0DD ........ ?Z? ??[` 

L_14_1D0E5:
  LDY #$1F                                        ;  1D0E5 D0E5 C A0 1F           F:000330
  LDX #$26                                        ;  1D0E7 D0E7 C A2 26           F:000330
B_14_1D0E9:
  LDA PasswordEntry,Y                                    ;  1D0E9 D0E9 C B9 22 03        F:000330
  ORA #$80                                        ;  1D0EC D0EC C 09 80           F:000330
  CMP #$A0                                        ;  1D0EE D0EE C C9 A0           F:000330
  BCC B_14_1D0F4                                  ;  1D0F0 D0F0 C 90 02           F:000330
  LDA #$7F                                        ;  1D0F2 D0F2 C A9 7F           F:000330
B_14_1D0F4:
  STA R_0362,X                                    ;  1D0F4 D0F4 C 9D 62 03        F:000330
  DEX                                             ;  1D0F7 D0F7 C CA              F:000330
  DEY                                             ;  1D0F8 D0F8 C 88              F:000330
  LDA PasswordEntry,Y                                    ;  1D0F9 D0F9 C B9 22 03        F:000330
  ORA #$80                                        ;  1D0FC D0FC C 09 80           F:000330
  CMP #$A0                                        ;  1D0FE D0FE C C9 A0           F:000330
  BCC B_14_1D104                                  ;  1D100 D100 C 90 02           F:000330
  LDA #$7F                                        ;  1D102 D102 C A9 7F           F:000330
B_14_1D104:
  STA R_0362,X                                    ;  1D104 D104 C 9D 62 03        F:000330
  DEX                                             ;  1D107 D107 C CA              F:000330
  DEY                                             ;  1D108 D108 C 88              F:000330
  LDA PasswordEntry,Y                                    ;  1D109 D109 C B9 22 03        F:000330
  ORA #$80                                        ;  1D10C D10C C 09 80           F:000330
  CMP #$A0                                        ;  1D10E D10E C C9 A0           F:000330
  BCC B_14_1D114                                  ;  1D110 D110 C 90 02           F:000330
  LDA #$7F                                        ;  1D112 D112 C A9 7F           F:000330
B_14_1D114:
  STA R_0362,X                                    ;  1D114 D114 C 9D 62 03        F:000330
  DEX                                             ;  1D117 D117 C CA              F:000330
  DEY                                             ;  1D118 D118 C 88              F:000330
  LDA PasswordEntry,Y                                    ;  1D119 D119 C B9 22 03        F:000330
  ORA #$80                                        ;  1D11C D11C C 09 80           F:000330
  CMP #$A0                                        ;  1D11E D11E C C9 A0           F:000330
  BCC B_14_1D124                                  ;  1D120 D120 C 90 02           F:000330
  LDA #$7F                                        ;  1D122 D122 C A9 7F           F:000330
B_14_1D124:
  STA R_0362,X                                    ;  1D124 D124 C 9D 62 03        F:000330
  DEX                                             ;  1D127 D127 C CA              F:000330
  DEY                                             ;  1D128 D128 C 88              F:000330
  DEX                                             ;  1D129 D129 C CA              F:000330
  BPL B_14_1D0E9                                  ;  1D12A D12A C 10 BD           F:000330
  LDA #$13                                        ;  1D12C D12C C A9 13           F:000330
  STA PPUUpdateLen                                      ;  1D12E D12E C 85 1A           F:000330
  LDA #$0                                         ;  1D130 D130 C A9 00           F:000330
  STA R_001B                                      ;  1D132 D132 C 85 1B           F:000330
  LDA #$E6                                        ;  1D134 D134 C A9 E6           F:000330
  STA PPUUpdateAddrLo                                      ;  1D136 D136 C 85 16           F:000330
  LDA #$24                                        ;  1D138 D138 C A9 24           F:000330
  STA PPUUpdateAddrHi                                      ;  1D13A D13A C 85 17           F:000330
  LDA #$62                                        ;  1D13C D13C C A9 62           F:000330
  STA PPUUpdateData                                      ;  1D13E D13E C 85 18           F:000330
  LDA #$3                                         ;  1D140 D140 C A9 03           F:000330
  STA PPUUpdateData+1                                      ;  1D142 D142 C 85 19           F:000330
  LDA #PPUOps_DrawRowFromStack                               ;  1D144 D144 C A9 05           F:000330
  JSR RunPPUOp                                  ;  1D146 D146 C 20 8F CC        F:000330
  LDA #$6                                         ;  1D149 D149 C A9 06           F:000331
  STA PPUUpdateAddrLo                                      ;  1D14B D14B C 85 16           F:000331
  LDA #$25                                        ;  1D14D D14D C A9 25           F:000331
  STA PPUUpdateAddrHi                                      ;  1D14F D14F C 85 17           F:000331
  LDA #$76                                        ;  1D151 D151 C A9 76           F:000331
  STA PPUUpdateData                                      ;  1D153 D153 C 85 18           F:000331
  LDA #$3                                         ;  1D155 D155 C A9 03           F:000331
  STA PPUUpdateData+1                                      ;  1D157 D157 C 85 19           F:000331
  LDA #PPUOps_DrawRowFromStack                               ;  1D159 D159 C A9 05           F:000331
  JSR RunPPUOp                                  ;  1D15B D15B C 20 8F CC        F:000331
  RTS                                             ;  1D15E D15E C 60              F:000332

L_14_1D15F:
  LDX #$1F                                        ;  1D15F D15F C A2 1F           F:000330
  LDA #$7F                                        ;  1D161 D161 C A9 7F           F:000330
B_14_1D163:
  STA PasswordEntry,X                                    ;  1D163 D163 C 9D 22 03        F:000330
  DEX                                             ;  1D166 D166 C CA              F:000330
  BPL B_14_1D163                                  ;  1D167 D167 C 10 FA           F:000330
  RTS                                             ;  1D169 D169 C 60              F:000330

RefillPlayerHP:
  LDA InvincibilityFramesTimer                                      ;  1D16A D16A C A5 85           F:010159
  PHA                                             ;  1D16C D16C C 48              F:010159
  LDA #$0                                         ;  1D16D D16D C A9 00           F:010159
  STA InvincibilityFramesTimer                                      ;  1D16F D16F C 85 85           F:010159
  JSR UpdatePlayerSprites                                  ;  1D171 D171 C 20 D8 C1        F:010159
B_14_1D174:
  INC PlayerHP                                      ;  1D174 D174 C E6 58           F:010159
  JSR UpdateHPDisplay                                  ;  1D176 D176 C 20 B6 CA        F:010159
  LDA #$16                                        ;  1D179 D179 C A9 16           F:010159
  STA PendingSFX                                      ;  1D17B D17B C 85 8F           F:010159
  LDA #$2                                         ;  1D17D D17D C A9 02           F:010159
  STA FrameCountdownTimer                                      ;  1D17F D17F C 85 36           F:010159
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  LDX PlayerHP                                      ;  1D184 D184 C A6 58           F:010161
  CPX #$63                                        ;  1D186 D186 C E0 63           F:010161
  BCC B_14_1D174                                  ;  1D188 D188 C 90 EA           F:010161
  LDA #$17                                        ;  1D18A D18A C A9 17           F:010169
  STA PendingSFX                                      ;  1D18C D18C C 85 8F           F:010169
  LDA #$10                                        ;  1D18E D18E C A9 10           F:010169
  STA FrameCountdownTimer                                      ;  1D190 D190 C 85 36           F:010169
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  PLA                                             ;  1D195 D195 C 68              F:010185
  STA InvincibilityFramesTimer                                      ;  1D196 D196 C 85 85           F:010185
  RTS                                             ;  1D198 D198 C 60              F:010185

RefillPlayerMana:
  LDA InvincibilityFramesTimer                                      ;  1D199 D199 C A5 85           F:003223
  PHA                                             ;  1D19B D19B C 48              F:003223
  LDA #$0                                         ;  1D19C D19C C A9 00           F:003223
  STA InvincibilityFramesTimer                                      ;  1D19E D19E C 85 85           F:003223
  JSR UpdatePlayerSprites                                  ;  1D1A0 D1A0 C 20 D8 C1        F:003223
B_14_1D1A3:
  INC PlayerMP                                      ;  1D1A3 D1A3 C E6 59           F:003223
  JSR UpdateMPDisplay                                  ;  1D1A5 D1A5 C 20 CC CA        F:003223
  LDA #$16                                        ;  1D1A8 D1A8 C A9 16           F:003223
  STA PendingSFX                                      ;  1D1AA D1AA C 85 8F           F:003223
  LDA #$2                                         ;  1D1AC D1AC C A9 02           F:003223
  STA FrameCountdownTimer                                      ;  1D1AE D1AE C 85 36           F:003223
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  LDX PlayerMP                                      ;  1D1B3 D1B3 C A6 59           F:003225
  CPX #$63                                        ;  1D1B5 D1B5 C E0 63           F:003225
  BCC B_14_1D1A3                                  ;  1D1B7 D1B7 C 90 EA           F:003225
  LDA #$17                                        ;  1D1B9 D1B9 C A9 17           F:003295
  STA PendingSFX                                      ;  1D1BB D1BB C 85 8F           F:003295
  LDA #$10                                        ;  1D1BD D1BD C A9 10           F:003295
  STA FrameCountdownTimer                                      ;  1D1BF D1BF C 85 36           F:003295
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  PLA                                             ;  1D1C4 D1C4 C 68              F:003311
  STA InvincibilityFramesTimer                                      ;  1D1C5 D1C5 C 85 85           F:003311
  RTS                                             ;  1D1C7 D1C7 C 60              F:003311

SetupDefaultRAMState:
  ldx #$0                                         ; set up default zeropage data
: lda InitRAM000,x                                ;
  sta $000,x                                      ;
  inx                                             ;
  bne :-                                          ;
  ldx #$3F                                        ; set up some more default ram state
: lda InitRAM100,x                                ;
  sta $100,x                                      ;
  dex                                             ;
  bpl :-                                          ;
  lda #$F                                         ; set starting black palette
  ldx #$1F                                        ;
: sta PaletteRAMCopy,x                            ;
  dex                                             ;
  bpl :-                                          ;
  ldx #$0                                         ; set up some initial ram state
: lda InitRAM300,x                                ;
  sta $300,x                                      ;
  inx                                             ;
  bne :-                                          ;
  ldx #$0                                         ;
: lda InitRAM400,x                                ;
  sta $400,x                                      ;
  inx                                             ;
  bne :-                                          ;
  rts                                             ; done!

VNMI:
  @Tmp26 = $26
  pha                                             ; store previous operation state
  txa                                             ;
  pha                                             ;
  tya                                             ;
  pha                                             ;
  lda PPU_STATUS                                  ; flip-flop
  sta @Tmp26                                      ; seemingly unused store of ppu status - TODO - used?
  lda #$0                                         ; update ppu sprites
  sta PPU_OAMADDR                                 ;
  lda #$2                                         ;
  sta APU_DMA                                     ;
  lda PPUOperation                                ; check if there's a queued ppu update
  beq :+                                          ; if not - skip ahead
  ldx #0                                          ; otherwise mark the operation as complete
  stx PPUOperation                                ;
  cmp #$7                                         ; was the operation in a valid range?
  bcc @RunPPUOperation                            ; if so - run that operation
: jmp CommonNMI                                   ; otherwise continue to default nmi
@RunPPUOperation:
  @TmpPtr = $6
  asl a                                           ; get offset into jump table
  tax                                             ;
  lda @PPUOperations,x                            ; and fetch the operation to run
  sta @TmpPtr                                     ;
  lda @PPUOperations+1,x                          ;
  sta @TmpPtr+1                                   ;
  lda PPU_STATUS                                  ; flip flop
  ldx PPUUpdateAddrHi                             ; move ppu to update location
  ldy PPUUpdateAddrLo                             ;
  stx PPU_ADDR                                    ;
  sty PPU_ADDR                                    ;
  lda PPUCTRLCopy                                 ; clear ppuctrl, aside from increment mode
  and #%00000100                                  ;
  sta PPU_CTRL                                    ;
  jmp (@TmpPtr)                                   ; run the pending operation

@PPUOperations:
.addr CommonNMI                                   ;
.addr PPUOp_RepeatByte                                     ;
.addr PPUOp_UpdatePalette                      ;
.addr PPUOp_DrawAreaColumn                                     ;
.addr PPUOp_DrawRowFromStack                                     ;
.addr PPUOp_WriteBuffer                                     ;
.addr PPUOp_Write2Bytes                                     ;

PPUOp_RepeatByte:
  ldx PPUUpdateLen                                ; get number of bytes to write
  lda PPUUpdateData                               ; and which byte to write
: sta PPU_DATA                                    ; then write that byte to the PPU!
  dex                                             ;
  bne :-                                          ; loop until done
  jmp CommonNMI                                   ; then continue with NMI

PPUOp_UpdatePalette:
  lda PPU_STATUS                                  ; flip flop
  lda #$3F                                        ; set ppu to 3F00
  sta PPU_ADDR                                    ;
  lda #$0                                         ;
  sta PPU_ADDR                                    ;
  ldx #$20                                        ; copying 32 bytes
  ldy #$0                                         ;
: lda PaletteRAMCopy,y                            ; write next byte to ppu
  STA PPU_DATA                                    ;
  iny                                             ;
  dex                                             ;
  bne :-                                          ; copy until all done
  lda PPU_STATUS                                  ; flip flop
  lda #$3F                                        ; move ppu to $0000
  sta PPU_ADDR                                    ;
  lda #$0                                         ;
  sta PPU_ADDR                                    ;
  sta PPU_ADDR                                    ;
  sta PPU_ADDR                                    ;
  jmp CommonNMI                                   ; then continue with NMI

PPUOp_DrawAreaColumn:
  lda PPUCTRLCopy                                 ; set vertical rendering
  ora #%00000100                                  ;
  sta PPU_CTRL                                    ;
  ldx #$17                                        ;
: lda PPUDrawColumn0,X                            ;
  sta PPU_DATA                                    ;
  dex                                             ;
  bpl :-                                          ;
  LDX PPUUpdateAddrHi                                      ;  1D2A2 D2A2 C A6 17           F:001673
  STX PPU_ADDR                                    ;  1D2A4 D2A4 C 8E 06 20        F:001673
  LDX PPUUpdateAddrLo                                      ;  1D2A7 D2A7 C A6 16           F:001673
  INX                                             ;  1D2A9 D2A9 C E8              F:001673
  STX PPU_ADDR                                    ;  1D2AA D2AA C 8E 06 20        F:001673
  LDX #$17                                        ;  1D2AD D2AD C A2 17           F:001673
B_14_1D2AF:
  LDA PPUDrawColumn1,X                                    ;  1D2AF D2AF C BD 58 01        F:001673
  STA PPU_DATA                                    ;  1D2B2 D2B2 C 8D 07 20        F:001673
  DEX                                             ;  1D2B5 D2B5 C CA              F:001673
  BPL B_14_1D2AF                                  ;  1D2B6 D2B6 C 10 F7           F:001673
  LDX #$A                                         ;  1D2B8 D2B8 C A2 0A           F:001673
B_14_1D2BA:
  LDY PPUUpdateData+1                                      ;  1D2BA D2BA C A4 19           F:001673
  STY PPU_ADDR                                    ;  1D2BC D2BC C 8C 06 20        F:001673
  LDY R_0170,X                                    ;  1D2BF D2BF C BC 70 01        F:001673
  STY PPU_ADDR                                    ;  1D2C2 D2C2 C 8C 06 20        F:001673
  LDA PPU_DATA                                    ;  1D2C5 D2C5 C AD 07 20        F:001673
  LDA PPU_DATA                                    ;  1D2C8 D2C8 C AD 07 20        F:001673
  AND PPUUpdateData                                      ;  1D2CB D2CB C 25 18           F:001673
  ORA R_0171,X                                    ;  1D2CD D2CD C 1D 71 01        F:001673
  LDY PPUUpdateData+1                                      ;  1D2D0 D2D0 C A4 19           F:001673
  STY PPU_ADDR                                    ;  1D2D2 D2D2 C 8C 06 20        F:001673
  LDY R_0170,X                                    ;  1D2D5 D2D5 C BC 70 01        F:001673
  STY PPU_ADDR                                    ;  1D2D8 D2D8 C 8C 06 20        F:001673
  STA PPU_DATA                                    ;  1D2DB D2DB C 8D 07 20        F:001673
  DEX                                             ;  1D2DE D2DE C CA              F:001673
  DEX                                             ;  1D2DF D2DF C CA              F:001673
  BPL B_14_1D2BA                                  ;  1D2E0 D2E0 C 10 D8           F:001673
  JMP CommonNMI                                  ;  1D2E2 D2E2 C 4C 51 D3        F:001673

PPUOp_DrawRowFromStack:
  tsx                                             ; copy current stack pointer to X
  txa                                             ; and to A
  ldx #$FF                                        ; move stack to end
  txs                                             ;
  tax                                             ; and put original stack pointer back in X
  ldy #$4                                         ; draw 4 rows of 16 bytes
@KeepCopying:
.repeat 16
  pla                                             ; pop byte from stack
  sta PPU_DATA                                    ; and write to ppu
.endrepeat
  dey                                             ;
  bne @KeepCopying                                ;
  txs                                             ; restore original stack pointer
  jmp CommonNMI                                   ; then continue with NMI

PPUOp_WriteBuffer:
  ldx PPUUpdateLen                                ; get number of bytes in buffer
  ldy #$0                                         ;
: lda (PPUUpdateData),y                           ; write full buffer to ppu
  sta PPU_DATA                                    ;
  iny                                             ;
  dex                                             ;
  bne :-                                          ;
  jmp CommonNMI                                   ; then continue with NMI

; unused?
PPUOp_Write2Bytes:
  lda PPUUpdateData+1                             ; write 2 bytes from buffer to ppu
  sta PPU_DATA                                    ;
  lda PPUUpdateData                               ;
  sta PPU_DATA                                    ;
  JMP CommonNMI                                   ; then continue with NMI

CommonNMI:
  jsr MMC3SetBanksToSelection                     ; re-set mmc3 to whatever was last used
  lda PPU_STATUS                                  ; flip-flop
  jsr @HandleNMI                                  ; call this part as a subroutine for no reason
  lda FrameCountdownTimer                         ; check if the game is waiting for a timer to finish
  beq :+                                          ; if not - skip ahead
  dec FrameCountdownTimer                         ; otherwise advance the timer
: jsr RunIntervalTimers                           ; step all the interval timers down
  lda MMC3LastBankSelect                          ; restore selected bank in case the caller needs it
  sta MMC3_RegBankSelect                          ;
  pla                                             ; restore caller state
  tay                                             ;
  pla                                             ;
  Tax                                             ;
  pla                                             ;
  rti                                             ; get back to the game!
@HandleNMI:
  lda PPUMASKCopy                                 ; set ppu state to ram copy values
  Sta PPU_MASK                                    ;
  lda PPUCTRLCopy                                 ;
  and #$FE                                        ;
  ora PPUActiveNametable                          ;
  sta PPUCTRLCopy                                 ;
  sta PPU_CTRL                                    ;
  ldx PPUHScrollCopy                              ;
  ldy PPUVScrollCopy                              ;
  stx PPU_SCROLL                                  ;
  sty PPU_SCROLL                                  ;
  lda StatusBarEnabled                            ; are we using the status bar?
  beq @PostStatusbar                              ; if not - skip ahead
  lda PPU_STATUS                                  ; otherwise we need to prepare for statusbar drawing
  lda PPUCTRLCopy                                 ;
  and #$FE                                        ; clear nametable bit
  ldx #$0                                         ; and set ppu scroll to correct position
  ldy #$C4                                        ;
  sta PPU_CTRL                                    ;
  stx PPU_SCROLL                                  ;
  sty PPU_SCROLL                                  ;
  LDA #$1                                         ; set ppu $0800-$0FFF
  STA MMC3_RegBankSelect                          ;
  LDA #$16                                        ;
  STA MMC3_RegBankData                            ;
  LDA #$4                                         ; set ppu $1800-$1BFF
  STA MMC3_RegBankSelect                          ;
  LDA #$3E                                        ;
  STA MMC3_RegBankData                            ;
  LDA #$5                                         ; set ppu $1C00-$1FFF
  STA MMC3_RegBankSelect                          ;
  LDA #$3F                                        ;
  STA MMC3_RegBankData                            ;
@PostStatusbar:
  jsr Audio_RunFrame                              ; update audio engine
  lda StatusBarEnabled                            ; are we using the status bar?
  bne :+                                          ; if so - skip ahead to wait for spr0
  rts                                             ; otherwise just return to the game
: bit PPU_STATUS                                  ; wait for spr0 to clear
  bvs :-                                          ;
: bit PPU_STATUS                                  ; have we hit spr0?
  bvs :+                                          ; if so - skip ahead
  bit PPU_STATUS                                  ; have we hit spr0?
  bvc :-                                          ; if not - keep looping
: ldx #$12                                        ; we're at spr0, waste a few cycles to move the seam
: dex                                             ;
  bne :-                                          ;
  lda #$1                                         ; prepare mmc3 banking
  sta MMC3_RegBankSelect                          ;
  lda PPUCTRLCopy                                 ; prepare data to update scroll position
  ldx PPUHScrollCopy                              ;
  ldy PPUVScrollCopy                              ;
  sta PPU_CTRL                                    ; and quickly perform the update
  stx PPU_SCROLL                                  ;
  sty PPU_SCROLL                                  ;
  lda SelectedBank1                               ; then set the mmc3 banks that the game was using last frame
  sta MMC3_RegBankData                            ;
  lda #$4                                         ;
  sta MMC3_RegBankSelect                          ;
  lda SelectedBank4                               ;
  sta MMC3_RegBankData                            ;
  lda #$5                                         ;
  sta MMC3_RegBankSelect                          ;
  lda SelectedBank5                               ;
  sta MMC3_RegBankData                            ;
  rts                                             ; and get back to the action!

RunIntervalTimers:
  dec IntervalTimer                               ; advance the 60 frame interval timer
  beq :+                                          ; skip ahead if timer expired
  rts                                             ; otherwise - nothing else to do
: ldx #EndOfIntervalTimers-IntervalTimers         ; step through each interval timer
: lda IntervalTimers,x                            ;
  beq @SkipTimer                                  ; skip ahead unless timer is active
  dec IntervalTimers,x                            ; active timer - decrement by 1
@SkipTimer:
  dex                                             ;
  bpl :-                                          ; keep looping until all timers checked
  lda #60                                         ; reset 60 frame interval
  sta IntervalTimer                               ;
  rts                                             ; done!

MMC3SetBanksToSelection:
  ldx #$7                                         ; updating 7 banks
: lda SelectedBank0,x                             ;
  stx MMC3_RegBankSelect                          ; update next bank from selected value
  sta MMC3_RegBankData                            ;
  dex                                             ;
  bpl :-                                          ; loop until all banks have been set
  rts                                             ; done!

HandlePlayerControls:
  lda #$FF                                        ; clear entity select
  sta ActiveEntity                                ;
  lda IsPlayerWarping                             ; check if the player is warping away
  beq :+                                          ; if not - skip ahead
  jmp HandleWarpingInputs                         ; otherwise run the warp animation
: jsr CheckIfEncounteringDragon                   ; detect possible dragon encounter!
  lda JoypadInput                                 ; check for start press
  and #CtlT                                       ;
  beq :+                                          ; no start press - continue
  jmp RunPauseMenu                                ; start press - run pause menu
: jsr RunPerFrameItemChecks                       ; deal with active items that need to be checked often
  lda PlayerStunTimer                             ; is the player current stunned?
  beq @CheckFire                                  ; no - continue to check inputs
  dec PlayerStunTimer                             ; otherwise decrement the timer
  lda #0                                          ; and clear player inputs
  sta JoypadInput                                 ;
@CheckFire:
  lda PlayerCharacter                             ; are we playing as the best character in the game?
  cmp #Character_Pochi                            ;
  bne @NonPochi                                   ; nope - sad.
  lda IntervalTimer                               ; yep, pochi can autofire every 16 frames!
  and #%0111                                      ;
  beq @ClearFireActions                           ;
@NonPochi:
  bit JoypadInput                                 ; is A button held?
  bvs @CheckDPad                                  ; yep - skip ahead, we can't refire until release
@ClearFireActions:
  lda JoypadLastAction                            ; clear fire action
  and #%00001111                                  ;
  sta JoypadLastAction                            ;
@CheckDPad:
  lda JoypadInput                                 ; check if d-pad held
  and #CtlDPad                        ;
  beq @CheckInGamePause                           ; nope - continue
  sta Tmp8                                        ; temp store d-pad inputs
  lda JoypadLastAction                            ; and combine it with the player actions
  and #%11110000                                  ;
  ora Tmp8                                        ;
  sta JoypadLastAction                            ; and set new d-pad actions
@CheckInGamePause:
  lda JoypadInput                                 ; if select button pressed?
  and #CtlS                                       ;
  beq @CheckDoorEntry                             ; no - skip ahead
  jmp RunInGamePause                              ; otherwise run in-game pause
@CheckDoorEntry:
  lda JoypadInput                                 ; is the player holding up?
  and #CtlU                                       ;
  beq @CheckScrollSpeed                           ; if not - continue
  jsr EnterDoorIfFound                            ; otherwise attempt to enter a door
@CheckScrollSpeed:
  ldy #$1                                         ; start at speed 1
: lda a:PlayerSpeedBoostTimer1-1,y                ; then loop through each possible speed boost
  beq @HandleMovement                             ; if it is zero, we stop here.
  iny                                             ;
  cpy #$5                                         ;
  bcc :-                                          ; loop until all speed boosts checked
  ldy #$6                                         ; max out at 6
@HandleMovement:
  JSR L_14_1CD2C                                  ;  1D495 D495 C 20 2C CD        F:001373
  LDA PlayerFallHeight                                      ;  1D498 D498 C A5 4E           F:001373
  BNE B_14_1D4C2                                  ;  1D49A D49A C D0 26           F:001373
  lda PlayerJumpProgress                          ; check if jump is in progress
  bne @B_14_1D4A4                                  ; if so - skip ahead
  lda JoypadInput                                 ; otherwise check if A button is held
  bpl @ClearJumpFlag                              ; if not - clear jumping state so we can jump again
@B_14_1D4A4:
  JSR HandlePlayerJumping                                  ;  1D4A4 D4A4 C 20 DF D4        F:001373
  LDA #$0                                         ;  1D4A7 D4A7 C A9 00           F:001404
  JMP L_14_1D4B0                                  ;  1D4A9 D4A9 C 4C B0 D4        F:001404

@ClearJumpFlag:
  lda #$0                                         ;
  sta PlayerIsJumping                             ; clear jumping flag
L_14_1D4B0:
  STA PlayerJumpProgress                                      ;  1D4B0 D4B0 C 85 4F           F:001404
  JSR L_14_1D991                                  ;  1D4B2 D4B2 C 20 91 D9        F:001404
  BCC B_14_1D4BF                                  ;  1D4B5 D4B5 C 90 08           F:001404
  JSR L_14_1DF90                                  ;  1D4B7 D4B7 C 20 90 DF        F:001509
  BCC B_14_1D4BF                                  ;  1D4BA D4BA C 90 03           F:001509
  JMP L_14_1D54E                                  ;  1D4BC D4BC C 4C 4E D5        F:001509

B_14_1D4BF:
  JMP L_14_1D536                                  ;  1D4BF D4BF C 4C 36 D5        F:001404

B_14_1D4C2:
  LSR                                             ;  1D4C2 D4C2 C 4A              F:001390
  LSR                                             ;  1D4C3 D4C3 C 4A              F:001390
  CLC                                             ;  1D4C4 D4C4 C 18              F:001390
  ADC #$1                                         ;  1D4C5 D4C5 C 69 01           F:001390
  STA PlayerYPxSpeed                                      ;  1D4C7 D4C7 C 85 4B           F:001390
  JSR L_14_1D991                                  ;  1D4C9 D4C9 C 20 91 D9        F:001390
  BCS B_14_1D4D1                                  ;  1D4CC D4CC C B0 03           F:001390
  JMP L_14_1D536                                  ;  1D4CE D4CE C 4C 36 D5        F:001403

B_14_1D4D1:
  LDA #$0                                         ;  1D4D1 D4D1 C A9 00           F:001390
  STA PlayerMovingDirection                                      ;  1D4D3 D4D3 C 85 49           F:001390
  STA PlayerFacingDirection                                      ;  1D4D5 D4D5 C 85 4A           F:001390
  JSR L_14_1D991                                  ;  1D4D7 D4D7 C 20 91 D9        F:001390
  BCC L_14_1D536                                  ;  1D4DA D4DA C 90 5A           F:001390
  JMP L_14_1D54E                                  ;  1D4DC D4DC C 4C 4E D5        F:024808

HandlePlayerJumping:
  ldx PlayerJumpProgress                          ; check if we are currently jumping
  bne @UpdateProgress                             ; if so - skip ahead to update jump status
  lda PlayerIsJumping                             ; otherwise check if the jump flag is set
  beq @StartJumping                               ; if not - start a new jump!
  rts                                             ; otherwise we can't jump, exit.
@StartJumping:
  lda #SFX_Jump                                   ; play jumping sound
  sta PendingSFX                                  ;
  lda PlayerAttrJump                              ; get character jump stat
  sta PlayerJumpProgress                          ; and store it as our jump progress
  ldx PlayerSelectedItemSlot                       ; does the character have jump shoes on?
  lda PlayerActiveItems,X                         ;
  cmp #ItemType_JumpShoes                         ;
  BNE @UpdateProgress                                  ;  1D4F6 D4F6 C D0 0E           F:001373
  JSR UsePlayerMana                               ;  1D4F8 D4F8 . 20 F0 E7        
  BCS @UpdateProgress                                  ;  1D4FB D4FB . B0 09           
  LDA PlayerJumpProgress                                      ;  1D4FD D4FD . A5 4F           
  LSR                                             ;  1D4FF D4FF . 4A              
  LSR                                             ;  1D500 D500 . 4A              
  CLC                                             ;  1D501 D501 . 18              
  ADC PlayerJumpProgress                                      ;  1D502 D502 . 65 4F           
  STA PlayerJumpProgress                                      ;  1D504 D504 . 85 4F           
 
@UpdateProgress:
  PLA                                             ;  1D506 D506 C 68              F:001373
  PLA                                             ;  1D507 D507 C 68              F:001373
  LDA #$1                                         ;  1D508 D508 C A9 01           F:001373
  STA PlayerIsJumping                                      ;  1D50A D50A C 85 22           F:001373
  LDA PlayerJumpProgress                                      ;  1D50C D50C C A5 4F           F:001373
  DEC PlayerJumpProgress                                      ;  1D50E D50E C C6 4F           F:001373
  LSR                                             ;  1D510 D510 C 4A              F:001373
  LSR                                             ;  1D511 D511 C 4A              F:001373
  EOR #$FF                                        ;  1D512 D512 C 49 FF           F:001373
  CLC                                             ;  1D514 D514 C 18              F:001373
  ADC #$1                                         ;  1D515 D515 C 69 01           F:001373
  STA PlayerYPxSpeed                                      ;  1D517 D517 C 85 4B           F:001373
  JSR L_14_1D991                                  ;  1D519 D519 C 20 91 D9        F:001373
  BCS @B_14_1D521                                  ;  1D51C D51C C B0 03           F:001373
  JMP L_14_1D536                                  ;  1D51E D51E C 4C 36 D5        F:001373

@B_14_1D521:
  LDA #$0                                         ;  1D521 D521 C A9 00           F:001384
  STA PlayerMovingDirection                                      ;  1D523 D523 C 85 49           F:001384
  STA PlayerFacingDirection                                      ;  1D525 D525 C 85 4A           F:001384
  JSR L_14_1D991                                  ;  1D527 D527 C 20 91 D9        F:001384
  BCC L_14_1D536                                  ;  1D52A D52A C 90 0A           F:001384
  INC PlayerJumpProgress                                      ;  1D52C D52C C E6 4F           F:001384
  JSR L_14_1DF90                                  ;  1D52E D52E C 20 90 DF        F:001384
  BCC L_14_1D536                                  ;  1D531 D531 C 90 03           F:001384
  JMP L_14_1D54E                                  ;  1D533 D533 C 4C 4E D5        F:001389

L_14_1D536:
  LDA TmpE                                      ;  1D536 D536 C A5 0E           F:001373
  STA PlayerXPx                                      ;  1D538 D538 C 85 43           F:001373
  LDA TmpF                                      ;  1D53A D53A C A5 0F           F:001373
  STA PlayerXTile                                      ;  1D53C D53C C 85 44           F:001373
  LDA TmpA                                      ;  1D53E D53E C A5 0A           F:001373
  CMP #$EF                                        ;  1D540 D540 C C9 EF           F:001373
  BCC B_14_1D546                                  ;  1D542 D542 C 90 02           F:001373
  LDA #$0                                         ;  1D544 D544 . A9 00           
B_14_1D546:
  STA PlayerYPx                                      ;  1D546 D546 C 85 45           F:001373
  JSR L_14_1DBDD                                  ;  1D548 D548 C 20 DD DB        F:001373
  JMP L_14_1D8AF                                  ;  1D54B D54B C 4C AF D8        F:001373

L_14_1D54E:
  LDA #$0                                         ;  1D54E D54E C A9 00           F:001389
  STA PlayerJumpProgress                                      ;  1D550 D550 C 85 4F           F:001389
  STA PlayerFallHeight                                      ;  1D552 D552 C 85 4E           F:001389
  JSR L_14_1DBDD                                  ;  1D554 D554 C 20 DD DB        F:001389
  JMP L_14_1D8AF                                  ;  1D557 D557 C 4C AF D8        F:001389

RunInGamePause:
  LDA #$10                                        ;  1D55A D55A C A9 10           F:027558
  STA PendingSFX                                      ;  1D55C D55C C 85 8F           F:027558
B_14_1D55E:
  JSR WaitForNewInputRelease                                  ;  1D55E D55E C 20 09 CC        F:027558
  AND #$F0                                        ;  1D561 D561 C 29 F0           F:027608
  BNE B_14_1D58F                                  ;  1D563 D563 C D0 2A           F:027608
  LDA JoypadInput                                      ;  1D565 D565 . A5 20           
  AND #$3                                         ;  1D567 D567 . 29 03           
  BEQ B_14_1D55E                                  ;  1D569 D569 . F0 F3           
  ASL JoypadInput                                      ;  1D56B D56B . 06 20           
  ASL JoypadInput                                      ;  1D56D D56D . 06 20           
  LDY #$1                                         ;  1D56F D56F . A0 01           
  JSR $CD2C                                       ;  1D571 D571 . 20 2C CD        
  LDA PlayerYPxSpeed                                      ;  1D574 D574 . A5 4B           
  CLC                                             ;  1D576 D576 . 18              
  ADC PlayerSelectedItemSlot                                      ;  1D577 D577 . 65 55           
  BMI B_14_1D584                                  ;  1D579 D579 . 30 09           
  CMP #$4                                         ;  1D57B D57B . C9 04           
  BCC B_14_1D586                                  ;  1D57D D57D . 90 07           
  LDA #$0                                         ;  1D57F D57F . A9 00           
  JMP $D586                                       ;  1D581 D581 . 4C 86 D5        

B_14_1D584:
  LDA #$3                                         ;  1D584 D584 . A9 03           
B_14_1D586:
  STA PlayerSelectedItemSlot                                      ;  1D586 D586 . 85 55           
  LDA #$C                                         ;  1D588 D588 . A9 0C           
  STA PendingSFX                                      ;  1D58A D58A . 85 8F           
  JMP $D55E                                       ;  1D58C D58C . 4C 5E D5        

B_14_1D58F:
  LDA #$10                                        ;  1D58F D58F C A9 10           F:027608
  STA PendingSFX                                      ;  1D591 D591 C 85 8F           F:027608
  JMP L_14_1D8AF                                  ;  1D593 D593 C 4C AF D8        F:027608

RunPerFrameItemChecks:
  ldy PlayerSelectedItemSlot                       ; check players equipped item
  ldx PlayerActiveItems,y                         ;
  cpx #ItemType_Mattock                           ;
  bcs @CheckMagicPotion                           ; check items unless using wings or armor
  lda GameIntervalTimer1,x                        ; otherwise get item-based timer
  beq :+                                          ; if expired - skip ahead
  rts                                             ; otherwise we're done!
: jsr UsePlayerMana                               ; discharge a bit of mana
  bcc @ResetTimer                                 ; restart the timer and exit if we still have mana
  lda CheatsEnabled                               ; we are out of mana - cheating time!
  beq @Done                                       ; cheats not enabled, bail
  bmi @Done                                       ; cheat already used! bail
  lda #$FD                                        ; set cheat state so we won't rerun
  sta CheatsEnabled                               ;
  lda #$1A                                        ;
  sta PendingSFX                                  ;
@Done:
  rts                                             ; done!

@ResetTimer:
  lda #$2                                         ; reset interval timer for item
  sta GameIntervalTimer1,x                        ;
  rts                                             ;

@CheckMagicPotion:
  cpx #ItemType_MagicPotion                       ; is selected item the magic potion?
  bne @CheckCrystal                               ; no - skip to check crystal
  lda PlayerMP                                    ; yes - are we out of mana?
  beq :+                                          ; yes! skip ahead to refill mana
  rts                                             ; otherwise exit
: ldx PlayerSelectedItemSlot                       ; remove mana potion
  lda #ItemType_None                              ;
  sta PlayerActiveItems,x                         ;
  JSR UpdateInventorySprites                      ;
  jsr RefillPlayerMana                            ;
  rts                                             ; done!

@CheckCrystal:
  cpx #ItemType_Crystal                           ; do we have the crystal equipped?
  beq :+                                          ; yes - skip ahead
  rts                                             ; no - done checking items
: lda CurrentAreaY                                ; are we in the boss areas?
  cmp #BossYDepth                                 ;
  bcc :+                                          ; no - skip ahead to use the crystal
  lda #$3                                         ; otherwise deselect the item
  sta PlayerSelectedItemSlot                       ;
  rts                                             ; done.

: ldx PlayerSelectedItemSlot                       ; start by removing the item from the players inventory
  lda #ItemType_None                              ;
  sta PlayerActiveItems,x                         ;
  jsr UpdateInventorySprites                                  ; run some inventory cleanup
  lda #$12                                        ;  1D5EB D5EB . A9 12           
  sta PendingSFX                                      ;  1D5ED D5ED . 85 8F           
  jmp RunCrystalWarp                                       ;  1D5EF D5EF . 4C 66 D8        

.byte $60

EnterPrincessDoor:
  ldy #$0C                                        ; target X area
  lda (AreaDataPtr),Y                             ;
  sta CurrentAreaX                                ;
  iny                                             ;
  lda (AreaDataPtr),Y                             ; target Y area
  sta CurrentAreaY                                ;
  iny                                             ;
  lda (AreaDataPtr),Y                             ; target X position
  sta PlayerXTile                                 ;
  sec                                             ;
  sbc #$08                                        ; fix up positioning
  bcs :+                                          ;
  lda #$00                                        ;
: cmp #$31                                        ;
  bcc :+                                          ;
  lda #$30                                        ;
: sta CameraXTile                                 ;
  lda #$00                                        ;
  sta PlayerXPx                               ;
  sta CameraXPx                                   ;
  iny                                             ;
  lda (AreaDataPtr),Y                             ; target Y position
  sta PlayerYPx                                   ;
  jmp LoadNewArea                                 ; load new area data from ROM

WarpToBossEncounter:
  jsr RunWarpScreenAnimation                      ; play the warp animation
  lda #BossYDepth                                 ; move player to boss depth
  sta CurrentAreaY                                ;
  ldx PlayerInventory_Crown                       ; and select boss room based on number of crowns
  dex                                             ;
  stx CurrentAreaX                                ;
  lda #$12                                        ; put player in the starting position for boss rooms
  sta CameraXTile                                 ;
  lda #$10                                        ;
  sta PlayerYPx                                   ;
  lda #$1A                                        ;
  sta PlayerXTile                                 ;
  lda #$00                                        ;
  sta PlayerXPx                                   ;
  sta CameraXPx                                   ;
  jmp LoadNewArea                                 ; then load the boss area

HandleWarpingInputs:                              ; clear warping flag
  lda #0                                          ;
  sta IsPlayerWarping                             ;
  jsr RunWarpScreenAnimation                      ; and run the warp animation
  lda #$3E                                        ; 
  sta SelectedBank4                               ;
  jmp RunCrystalWarp                              ; then run the warping code used for the crystal

CheckIfEncounteringDragon:
  ldx PlayerSelectedItemSlot                      ; is the player using the dragon slayer?
  lda PlayerActiveItems,x                         ;
  cmp #ItemType_DragonSlayer                      ;
  bne @Nope                                       ; if not - bail out
  lda CurrentAreaX                                ; is the player in horizontal area 1?
  cmp #$1                                         ;
  bne @Nope                                       ; if not - bail out
  lda CurrentAreaY                                ; is the player in vertical area 5?
  cmp #$5                                         ;
  bne @Nope                                       ; if not - bail out
  lda CameraXTile                                 ; is the player at the encounter tile?
  cmp #$10                                        ;
  bne @Nope                                       ; if not - bail out
  lda CameraXPx                                   ; is the player at the correct horizontal pixel?
  cmp #$0                                         ;
  bne @Nope                                       ; if not - bail out
  lda PlayerYPx                                   ; is the player at the correct vertical pixel?
  cmp #$A0                                        ;
  beq @BeginEncounter                             ; is so - begin the encounter!
@Nope:
  rts                                             ; bail out
@BeginEncounter:
  lda #$1                                         ; mark encounter as active
  sta DragonEncounterActive                       ;
  pla                                             ; pop caller off the stack
  pla                                             ;
  rts                                             ; done!

RunWarpScreenAnimation:
  jsr SetupSpr0AndClearSprites                    ; clear sprites
  lda #$00                                        ; clear any pending iframes
  sta InvincibilityFramesTimer                    ;
  jsr UpdatePlayerSprites                         ; and make sure the player is drawn during cutscene
  jsr UpdateInventorySprites                      ;
  lda CameraXTile                                 ; make sure the camera is in a good spot for the cutscene
  cmp #$21                                        ;
  bcc :+                                          ;
  lda #$20                                        ;
: sta CameraXTile                                 ;
  JSR L_14_1C76C                                  ;
  lda CameraXTile                                 ; move camera right 1 tile
  clc                                             ;
  adc #$10                                        ;
  sta CameraXTile                                 ;
  JSR L_14_1C76C                                  ;
  lda #$01                                        ; set warping background scroll speed
  sta Tmp8                                        ;
@RunScrollAnimation:
  ldx #12                                         ; run the animation for 12 frames
@ScrollBackground:
  lda PPUHScrollCopy                              ; keep scrolling background
  clc                                             ;
  adc Tmp8                                        ;
  sta PPUHScrollCopy                              ;
  bcc :+                                          ;
  LDA PPUActiveNametable                          ; invert nametable when scroll overflows
  eor #$01                                        ;
  sta PPUActiveNametable                          ;
: lda #$FF                                        ; delay until next frame
  jsr RunPPUOp                                    ;
  dex                                             ;
  bne @ScrollBackground                           ; and loop until animation step complete
  inc Tmp8                                        ; increment outer loop counter
  ldx Tmp8                                        ;
  cpx #$20                                        ;
  bcc @RunScrollAnimation                         ; loop until we've run 32 times
  LDA #SFX_Warp                                   ; play warp sound
  STA PendingSFX                                  ;
  LDA #$FF                                        ;  
  STA R_0090                                      ;  1D6..
  ldx #$08                                        ;  1D6..
  jsr LightningFlashScreen                        ; flash the screen white 8 times, epic!
  rts                                             ; done!

L_14_1D6D4:
  LDA PlayerYPx                                      ;  1D6D4 D6D4 C A5 45           F:001470
  CMP #$10                                        ;  1D6D6 D6D6 C C9 10           F:001470
  BCC B_14_1D739                                  ;  1D6D8 D6D8 C 90 5F           F:001470
  CMP #$A1                                        ;  1D6DA D6DA C C9 A1           F:001470
  BCS B_14_1D750                                  ;  1D6DC D6DC C B0 72           F:001470
  LDX CurrentAreaY                                      ;  1D6DE D6DE C A6 48           F:018875
  CPX #$10                                        ;  1D6E0 D6E0 C E0 10           F:018875
  BEQ B_14_1D731                                  ;  1D6E2 D6E2 C F0 4D           F:018875
  JSR L_14_1DBDD                                  ;  1D6E4 D6E4 C 20 DD DB        F:018875
  LDA #$0                                         ;  1D6E7 D6E7 C A9 00           F:018875
  STA InvincibilityFramesTimer                                      ;  1D6E9 D6E9 C 85 85           F:018875
  LDA PlayerSpriteTile                                      ;  1D6EB D6EB C A5 56           F:018875
  AND #$7                                         ;  1D6ED D6ED C 29 07           F:018875
  STA PlayerSpriteTile                                      ;  1D6EF D6EF C 85 56           F:018875
  LDA PlayerXTile                                      ;  1D6F1 D6F1 C A5 44           F:018875
  BEQ B_14_1D714                                  ;  1D6F3 D6F3 C F0 1F           F:018875
  CMP #$3E                                        ;  1D6F5 D6F5 C C9 3E           F:018991
  BCC B_14_1D731                                  ;  1D6F7 D6F7 C 90 38           F:018991
  LDX CurrentAreaX                                      ;  1D6F9 D6F9 C A6 47           F:018991
  INX                                             ;  1D6FB D6FB C E8              F:018991
  CPX #$4                                         ;  1D6FC D6FC C E0 04           F:018991
  BCS B_14_1D731                                  ;  1D6FE D6FE C B0 31           F:018991
  STX CurrentAreaX                                      ;  1D700 D700 C 86 47           F:018991
  LDA #$40                                        ;  1D702 D702 C A9 40           F:018991
  STA PlayerSpriteAttr                                      ;  1D704 D704 C 85 57           F:018991
  JSR UpdatePlayerSprites                                  ;  1D706 D706 C 20 D8 C1        F:018991
  LDA #$0                                         ;  1D709 D709 C A9 00           F:018991
  STA CameraXTile                                      ;  1D70B D70B C 85 7C           F:018991
  STA PlayerXPx                                      ;  1D70D D70D C 85 43           F:018991
  STA PlayerXTile                                      ;  1D70F D70F C 85 44           F:018991
  JMP L_14_1D772                                  ;  1D711 D711 C 4C 72 D7        F:018991

B_14_1D714:
  LDX CurrentAreaX                                      ;  1D714 D714 C A6 47           F:018875
  DEX                                             ;  1D716 D716 C CA              F:018875
  BMI B_14_1D731                                  ;  1D717 D717 C 30 18           F:018875
  STX CurrentAreaX                                      ;  1D719 D719 C 86 47           F:018875
  LDA #$0                                         ;  1D71B D71B C A9 00           F:018875
  STA PlayerSpriteAttr                                      ;  1D71D D71D C 85 57           F:018875
  JSR UpdatePlayerSprites                                  ;  1D71F D71F C 20 D8 C1        F:018875
  LDA #$30                                        ;  1D722 D722 C A9 30           F:018875
  STA CameraXTile                                      ;  1D724 D724 C 85 7C           F:018875
  LDA #$3F                                        ;  1D726 D726 C A9 3F           F:018875
  STA PlayerXTile                                      ;  1D728 D728 C 85 44           F:018875
  LDA #$0                                         ;  1D72A D72A C A9 00           F:018875
  STA PlayerXPx                                      ;  1D72C D72C C 85 43           F:018875
  JMP L_14_1D772                                  ;  1D72E D72E C 4C 72 D7        F:018875

B_14_1D731:
  CLC                                             ;  1D731 D731 . 18              
  RTS                                             ;  1D732 D732 . 60              

B_14_1D733:
  JMP RunCrystalWarp                                       ;  1D733 D733 . 4C 66 D8        

B_14_1D736:
  JMP EnterNewArea                                  ;  1D736 D736 C 4C 83 D8        F:001540

B_14_1D739:
  JSR L_14_1DC87                                  ;  1D739 D739 C 20 87 DC        F:007534
  BCC B_14_1D731                                  ;  1D73C D73C C 90 F3           F:007534
  LDX CurrentAreaY                                      ;  1D73E D73E C A6 48           F:007534
  BEQ B_14_1D733                                  ;  1D740 D740 C F0 F1           F:007534
  CPX #$10                                        ;  1D742 D742 C E0 10           F:007534
  BEQ B_14_1D731                                  ;  1D744 D744 C F0 EB           F:007534
  DEX                                             ;  1D746 D746 C CA              F:007534
  STX CurrentAreaY                                      ;  1D747 D747 C 86 48           F:007534
  LDA #$B0                                        ;  1D749 D749 C A9 B0           F:007534
  STA PlayerYPx                                      ;  1D74B D74B C 85 45           F:007534
  JMP L_14_1D761                                  ;  1D74D D74D C 4C 61 D7        F:007534

B_14_1D750:
  LDX CurrentAreaY                                      ;  1D750 D750 C A6 48           F:001470
  CPX #$10                                        ;  1D752 D752 C E0 10           F:001470
  BEQ B_14_1D736                                  ;  1D754 D754 C F0 E0           F:001470
  INX                                             ;  1D756 D756 C E8              F:001470
  CPX #$10                                        ;  1D757 D757 C E0 10           F:001470
  BCS B_14_1D731                                  ;  1D759 D759 C B0 D6           F:001470
  STX CurrentAreaY                                      ;  1D75B D75B C 86 48           F:001470
  LDA #$0                                         ;  1D75D D75D C A9 00           F:001470
  STA PlayerYPx                                      ;  1D75F D75F C 85 45           F:001470
L_14_1D761:
  JSR DisableAllEntities                                  ;  1D761 D761 C 20 8A D0        F:001470
  JSR ClearEntitySprites                                  ;  1D764 D764 C 20 7C D0        F:001470
  JSR LoadNewAreaData                                  ;  1D767 D767 C 20 F2 C8        F:001470
  JSR DrawLeftAreaDataColumn                                  ;  1D76A D76A C 20 CB C5        F:001471
  JSR UpdatePaletteFromCopy                                  ;  1D76D D76D C 20 69 C5        F:001472
  SEC                                             ;  1D770 D770 C 38              F:001473
  RTS                                             ;  1D771 D771 C 60              F:001473

L_14_1D772:
  JSR DisableAllEntities                                  ;  1D772 D772 C 20 8A D0        F:018875
  JSR ClearEntitySprites                                  ;  1D775 D775 C 20 7C D0        F:018875
  LDA #$0                                         ;  1D778 D778 C A9 00           F:018875
  STA CameraXPx                                      ;  1D77A D77A C 85 7B           F:018875
  JSR LoadNewAreaData                                  ;  1D77C D77C C 20 F2 C8        F:018875
  JSR L_14_1C76C                                  ;  1D77F D77F C 20 6C C7        F:018875
  JSR UpdatePaletteFromCopy                                  ;  1D782 D782 C 20 69 C5        F:018891
  LDA PlayerXTile                                      ;  1D785 D785 C A5 44           F:018892
  BNE B_14_1D7F8                                  ;  1D787 D787 C D0 6F           F:018892
  LDA #$FC                                        ;  1D789 D789 C A9 FC           F:019008
  STA a:PPUHScrollCopy                                    ;  1D78B D78B C 8D 1C 00        F:019008
  LDA #$1                                         ;  1D78E D78E C A9 01           F:019008
  STA a:PPUActiveNametable                                    ;  1D790 D790 C 8D 1D 00        F:019008
  LDA #$F0                                        ;  1D793 D793 C A9 F0           F:019008
  STA PlayerSpr0X                                      ;  1D795 D795 C 8D 13 02        F:019008
  LDA #$F8                                        ;  1D798 D798 C A9 F8           F:019008
  STA PlayerSpr1X                                      ;  1D79A D79A C 8D 17 02        F:019008
  LDA #$F                                         ;  1D79D D79D C A9 0F           F:019008
  STA TmpA                                      ;  1D79F D79F C 85 0A           F:019008
B_14_1D7A1:
  LDA #$3                                         ;  1D7A1 D7A1 C A9 03           F:019008
  STA BlockOffset                                      ;  1D7A3 D7A3 C 85 0B           F:019008
B_14_1D7A5:
  BNE B_14_1D7C3                                  ;  1D7A5 D7A5 C D0 1C           F:019008
  INC PlayerSpr0X                                      ;  1D7A7 D7A7 C EE 13 02        F:019011
  INC PlayerSpr1X                                      ;  1D7AA D7AA C EE 17 02        F:019011
  LDA PlayerFallHeight                                      ;  1D7AD D7AD C A5 4E           F:019011
  ORA PlayerJumpProgress                                      ;  1D7AF D7AF C 05 4F           F:019011
  BNE B_14_1D7C3                                  ;  1D7B1 D7B1 C D0 10           F:019011
  LDA PlayerSpr0Tile                                      ;  1D7B3 D7B3 C AD 11 02        F:019011
  EOR #$4                                         ;  1D7B6 D7B6 C 49 04           F:019011
  STA PlayerSpr0Tile                                      ;  1D7B8 D7B8 C 8D 11 02        F:019011
  LDA PlayerSpr1Tile                                      ;  1D7BB D7BB C AD 15 02        F:019011
  EOR #$4                                         ;  1D7BE D7BE C 49 04           F:019011
  STA PlayerSpr1Tile                                      ;  1D7C0 D7C0 C 8D 15 02        F:019011
B_14_1D7C3:
  LDA PlayerSpr0X                                      ;  1D7C3 D7C3 C AD 13 02        F:019008
  SEC                                             ;  1D7C6 D7C6 C 38              F:019008
  SBC #$4                                         ;  1D7C7 D7C7 C E9 04           F:019008
  STA PlayerSpr0X                                      ;  1D7C9 D7C9 C 8D 13 02        F:019008
  CLC                                             ;  1D7CC D7CC C 18              F:019008
  ADC #$8                                         ;  1D7CD D7CD C 69 08           F:019008
  STA PlayerSpr1X                                      ;  1D7CF D7CF C 8D 17 02        F:019008
  LDA PPUHScrollCopy                                      ;  1D7D2 D7D2 C A5 1C           F:019008
  CLC                                             ;  1D7D4 D7D4 C 18              F:019008
  ADC #$4                                         ;  1D7D5 D7D5 C 69 04           F:019008
  STA PPUHScrollCopy                                      ;  1D7D7 D7D7 C 85 1C           F:019008
  LDA #PPUOps_Default                             ;  1D7D9 D7D9 C A9 FF           F:019008
  JSR RunPPUOp                                  ;  1D7DB D7DB C 20 8F CC        F:019008
  DEC BlockOffset                                      ;  1D7DE D7DE C C6 0B           F:019009
  BPL B_14_1D7A5                                  ;  1D7E0 D7E0 C 10 C3           F:019009
  DEC TmpA                                      ;  1D7E2 D7E2 C C6 0A           F:019012
  BPL B_14_1D7A1                                  ;  1D7E4 D7E4 C 10 BB           F:019012
  LDA #$0                                         ;  1D7E6 D7E6 C A9 00           F:019072
  STA PPUUpdateAddrLo                                      ;  1D7E8 D7E8 C 85 16           F:019072
  LDA #$24                                        ;  1D7EA D7EA C A9 24           F:019072
  STA PPUUpdateAddrHi                                      ;  1D7EC D7EC C 85 17           F:019072
  LDA #$10                                        ;  1D7EE D7EE C A9 10           F:019072
  STA BlockPtrLo                                      ;  1D7F0 D7F0 C 85 0C           F:019072
  JSR BankAndDrawMetatileColumn                                  ;  1D7F2 D7F2 C 20 33 C8        F:019072
  JMP L_14_1D864                                  ;  1D7F5 D7F5 C 4C 64 D8        F:019073

B_14_1D7F8:
  LDA #$1                                         ;  1D7F8 D7F8 C A9 01           F:018892
  STA a:PPUActiveNametable                                    ;  1D7FA D7FA C 8D 1D 00        F:018892
  LDA #$0                                         ;  1D7FD D7FD C A9 00           F:018892
  STA a:PPUHScrollCopy                                    ;  1D7FF D7FF C 8D 1C 00        F:018892
  LDA #$0                                         ;  1D802 D802 C A9 00           F:018892
  STA PlayerSpr0X                                      ;  1D804 D804 C 8D 13 02        F:018892
  LDA #$8                                         ;  1D807 D807 C A9 08           F:018892
  STA PlayerSpr1X                                      ;  1D809 D809 C 8D 17 02        F:018892
  LDA #$F                                         ;  1D80C D80C C A9 0F           F:018892
  STA TmpA                                      ;  1D80E D80E C 85 0A           F:018892
B_14_1D810:
  LDA #$3                                         ;  1D810 D810 C A9 03           F:018892
  STA BlockOffset                                      ;  1D812 D812 C 85 0B           F:018892
B_14_1D814:
  BNE B_14_1D832                                  ;  1D814 D814 C D0 1C           F:018892
  DEC PlayerSpr0X                                      ;  1D816 D816 C CE 13 02        F:018895
  DEC PlayerSpr1X                                      ;  1D819 D819 C CE 17 02        F:018895
  LDA PlayerFallHeight                                      ;  1D81C D81C C A5 4E           F:018895
  ORA PlayerJumpProgress                                      ;  1D81E D81E C 05 4F           F:018895
  BNE B_14_1D832                                  ;  1D820 D820 C D0 10           F:018895
  LDA PlayerSpr0Tile                                      ;  1D822 D822 C AD 11 02        F:018895
  EOR #$4                                         ;  1D825 D825 C 49 04           F:018895
  STA PlayerSpr0Tile                                      ;  1D827 D827 C 8D 11 02        F:018895
  LDA PlayerSpr1Tile                                      ;  1D82A D82A C AD 15 02        F:018895
  EOR #$4                                         ;  1D82D D82D C 49 04           F:018895
  STA PlayerSpr1Tile                                      ;  1D82F D82F C 8D 15 02        F:018895
B_14_1D832:
  LDA PlayerSpr0X                                      ;  1D832 D832 C AD 13 02        F:018892
  CLC                                             ;  1D835 D835 C 18              F:018892
  ADC #$4                                         ;  1D836 D836 C 69 04           F:018892
  STA PlayerSpr0X                                      ;  1D838 D838 C 8D 13 02        F:018892
  CLC                                             ;  1D83B D83B C 18              F:018892
  ADC #$8                                         ;  1D83C D83C C 69 08           F:018892
  STA PlayerSpr1X                                      ;  1D83E D83E C 8D 17 02        F:018892
  LDA PPUHScrollCopy                                      ;  1D841 D841 C A5 1C           F:018892
  SEC                                             ;  1D843 D843 C 38              F:018892
  SBC #$4                                         ;  1D844 D844 C E9 04           F:018892
  STA PPUHScrollCopy                                      ;  1D846 D846 C 85 1C           F:018892
  LDA #PPUOps_Default                              ;  1D848 D848 C A9 FF           F:018892
  JSR RunPPUOp                                  ;  1D84A D84A C 20 8F CC        F:018892
  DEC BlockOffset                                      ;  1D84D D84D C C6 0B           F:018893
  BPL B_14_1D814                                  ;  1D84F D84F C 10 C3           F:018893
  DEC TmpA                                      ;  1D851 D851 C C6 0A           F:018896
  BPL B_14_1D810                                  ;  1D853 D853 C 10 BB           F:018896
  LDA #$1E                                        ;  1D855 D855 C A9 1E           F:018956
  STA PPUUpdateAddrLo                                      ;  1D857 D857 C 85 16           F:018956
  LDA #$20                                        ;  1D859 D859 C A9 20           F:018956
  STA PPUUpdateAddrHi                                      ;  1D85B D85B C 85 17           F:018956
  LDA #$2F                                        ;  1D85D D85D C A9 2F           F:018956
  STA BlockPtrLo                                      ;  1D85F D85F C 85 0C           F:018956
  JSR BankAndDrawMetatileColumn                                  ;  1D861 D861 C 20 33 C8        F:018956
L_14_1D864:
  SEC                                             ;  1D864 D864 C 38              F:018957
  RTS                                             ;  1D865 D865 C 60              F:018957

RunCrystalWarp:
.byte $A9,$10,$85,$48,$A9,$03,$85,$47             ;  1D866 D866 ........ ???H???G 
.byte $A9,$12,$85,$7C,$A9,$B0,$85,$45             ;  1D86E D86E ........ ???|???E 
.byte $A9,$1A,$85,$44,$A9,$00,$85,$43             ;  1D876 D876 ........ ???D???C 
.byte $85,$7B,$4C,$95,$D8                         ;  1D87E D87E .....    ?{L??    

EnterNewArea:
  LDA #$0                                         ;  1D883 D883 C A9 00           F:001540
  STA CurrentAreaY                                      ;  1D885 D885 C 85 48           F:001540
  STA CurrentAreaX                                      ;  1D887 D887 C 85 47           F:001540
  STA CameraXTile                                      ;  1D889 D889 C 85 7C           F:001540
  STA PlayerYPx                                      ;  1D88B D88B C 85 45           F:001540
  STA PlayerXPx                                      ;  1D88D D88D C 85 43           F:001540
  STA CameraXPx                                      ;  1D88F D88F C 85 7B           F:001540
  LDA #$1                                         ;  1D891 D891 C A9 01           F:001540
  STA PlayerXTile                                      ;  1D893 D893 C 85 44           F:001540

LoadNewArea:
  JSR L_14_1C3E5                                  ;  1D895 D895 C 20 E5 C3        F:001540
  JSR DisableAllEntities                                  ;  1D898 D898 C 20 8A D0        F:001560
  JSR LoadNewAreaData                                  ;  1D89B D89B C 20 F2 C8        F:001560
  JSR DrawLeftAreaDataColumn                                  ;  1D89E D89E C 20 CB C5        F:001561
  JSR ClearEntitySprites                                  ;  1D8A1 D8A1 C 20 7C D0        F:001562
  JSR UpdateCameraPPUScroll                                  ;  1D8A4 D8A4 C 20 C7 C1        F:001562
  JSR UpdatePlayerSprites                                  ;  1D8A7 D8A7 C 20 D8 C1        F:001562
  JSR FadeInAreaPalette                                  ;  1D8AA D8AA C 20 92 C4        F:001562
  SEC                                             ;  1D8AD D8AD C 38              F:001588
  RTS                                             ;  1D8AE D8AE C 60              F:001588

L_14_1D8AF:
  JSR SelectPlayerSprite1                                  ;  1D8AF D8AF C 20 E3 D8        F:001373
  JSR L_14_1D94E                                  ;  1D8B2 D8B2 C 20 4E D9        F:001373
  RTS                                             ;  1D8B5 D8B5 C 60              F:001373

L_14_1D8B6:
  LDA PlayerXPx                                      ;  1D8B6 D8B6 C A5 43           F:001373
  STA TmpE                                      ;  1D8B8 D8B8 C 85 0E           F:001373
  LDA PlayerXTile                                      ;  1D8BA D8BA C A5 44           F:001373
  STA TmpF                                      ;  1D8BC D8BC C 85 0F           F:001373
  LDA PlayerYPx                                      ;  1D8BE D8BE C A5 45           F:001373
  STA TmpA                                      ;  1D8C0 D8C0 C 85 0A           F:001373
  LDA PlayerYPxSpeed                                      ;  1D8C2 D8C2 C A5 4B           F:001373
  BEQ B_14_1D8CB                                  ;  1D8C4 D8C4 C F0 05           F:001373
  CLC                                             ;  1D8C6 D8C6 C 18              F:001373
  ADC TmpA                                      ;  1D8C7 D8C7 C 65 0A           F:001373
  STA TmpA                                      ;  1D8C9 D8C9 C 85 0A           F:001373
B_14_1D8CB:
  LDA PlayerMovingDirection                                      ;  1D8CB D8CB C A5 49           F:001373
  BEQ B_14_1D8E2                                  ;  1D8CD D8CD C F0 13           F:001373
  CLC                                             ;  1D8CF D8CF C 18              F:001373
  ADC TmpE                                      ;  1D8D0 D8D0 C 65 0E           F:001373
  PHA                                             ;  1D8D2 D8D2 C 48              F:001373
  AND #$F                                         ;  1D8D3 D8D3 C 29 0F           F:001373
  STA TmpE                                      ;  1D8D5 D8D5 C 85 0E           F:001373
  PLA                                             ;  1D8D7 D8D7 C 68              F:001373
  ASL                                             ;  1D8D8 D8D8 C 0A              F:001373
  ASL                                             ;  1D8D9 D8D9 C 0A              F:001373
  ASL                                             ;  1D8DA D8DA C 0A              F:001373
  ASL                                             ;  1D8DB D8DB C 0A              F:001373
  LDA TmpF                                      ;  1D8DC D8DC C A5 0F           F:001373
  ADC PlayerFacingDirection                                      ;  1D8DE D8DE C 65 4A           F:001373
  STA TmpF                                      ;  1D8E0 D8E0 C 85 0F           F:001373
B_14_1D8E2:
  RTS                                             ;  1D8E2 D8E2 C 60              F:001373

SelectPlayerSprite1:
  ldx #$3D                                        ; stunned sprite
  lda PlayerStunTimer                             ; check if the player is stunned.
  bne @Select                                     ; if so - use the stunned sprite
  ldx #$9                                         ; firing sprite
  lda PlayerIsFiring                              ; is the player firing a projectile?
  bne @Select                                     ; if so - use the firing sprite
  lda JoypadInput                                 ; check all held buttons except B
  and #CtlA|CtlS|CtlT|CtlR|CtlL|CtlD|CtlU         ;
  cmp #CtlA                                       ; are we holding A and no direction?
  beq @Select                                     ; if so - showing the shooting sprite
  lda PlayerYPxSpeed                              ; check vertical speed
  beq @NotJumpingOrFalling                        ;
  bmi @Jumping                                    ; if negative we are jumping upward
  lda PlayerFallHeight                            ; otherwise check current fall height
  bne @JumpOrFallSprites                          ; if it's non-zero, skip ahead
  lda JoypadInput                                 ; otherwise we have not begun to fall
  and #CtlD                                       ; is the player holding down?
  beq @NotJumpingOrFalling                        ; no - skip ahead
  ldx #$D                                         ; yes - select fixed sprite
  jmp @Select                                     ;

@Jumping:
  lda PlayerJumpProgress                          ; check current jump height
  beq @Select                                     ; if we've just started jumping, use the current sprite
  jmp @JumpOrFallSprites                          ; otherwise, skip ahead

@NotJumpingOrFalling:
  ldx #$1                                         ; regular standing sprite
  ldy #$0                                         ; sprite attributes for facing left
  lda PlayerFacingDirection                       ; check direction the player is facing
  bmi :+                                          ; use attributes if player is facing left
  lda PlayerMovingDirection                              ; is the player moving?
  beq @Done                                       ; if not - don' update the sprite
  ldy #$40                                        ; otherwise flip sprite horizontally
: stx Tmp8                                        ; store selected sprite away for a bit
  lda PlayerSpriteTile                            ; then get the current player sprite
  and #%0111                                      ; keep the animation bits
  ora Tmp8                                        ; combine with the new selected sprite
  sta PlayerSpriteTile                            ; and use it
  sty PlayerSpriteAttr                            ; set sprite attributes
  rts                                             ; done
@Select:
  stx PlayerSpriteTile                            ; set new player sprite
@Done:
  rts                                             ; done!

@JumpOrFallSprites:
  ldx #$39                                        ; get default sprite
  ldy #$0                                         ;
  lda PlayerFacingDirection                       ; get players direction
  ora PlayerMovingDirection                       ;
  BMI B_14_1D941                                  ;  1D939 D939 C 30 06           F:001373
  BNE B_14_1D93F                                  ;  1D93B D93B C D0 02           F:001390
  LDX #$9                                         ;  1D93D D93D C A2 09           F:001390
B_14_1D93F:
  LDY #$40                                        ;  1D93F D93F C A0 40           F:001390
B_14_1D941:
  STX R_0008                                      ;  1D941 D941 C 86 08           F:001373
  LDA PlayerSpriteTile                                      ;  1D943 D943 C A5 56           F:001373
  AND #$3                                         ;  1D945 D945 C 29 03           F:001373
  ORA R_0008                                      ;  1D947 D947 C 05 08           F:001373
  STA PlayerSpriteTile                                      ;  1D949 D949 C 85 56           F:001373
  STY PlayerSpriteAttr                                      ;  1D94B D94B C 84 57           F:001373
  RTS                                             ;  1D94D D94D C 60              F:001373

L_14_1D94E:
  LDA PlayerStunTimer                                      ;  1D94E D94E C A5 46           F:001373
  BNE B_14_1D967                                  ;  1D950 D950 C D0 15           F:001373
  LDA PlayerSpriteTile                                      ;  1D952 D952 C A5 56           F:001373
  CMP #$20                                        ;  1D954 D954 C C9 20           F:001373
  BCS B_14_1D967                                  ;  1D956 D956 C B0 0F           F:001373
  LDA PlayerSpriteTile                                      ;  1D958 D958 C A5 56           F:001384
  BIT JoypadInput                                      ;  1D95A D95A C 24 20           F:001384
  BVS B_14_1D963                                  ;  1D95C D95C C 70 05           F:001384
  AND #$EF                                        ;  1D95E D95E C 29 EF           F:001384
  JMP L_14_1D965                                  ;  1D960 D960 C 4C 65 D9        F:001384

B_14_1D963:
  ORA #$10                                        ;  1D963 D963 C 09 10           F:001756
L_14_1D965:
  STA PlayerSpriteTile                                      ;  1D965 D965 C 85 56           F:001384
B_14_1D967:
  LDA JoypadInput                                      ;  1D967 D967 C A5 20           F:001373
  AND #$F                                         ;  1D969 D969 C 29 0F           F:001373
  BEQ B_14_1D990                                  ;  1D96B D96B C F0 23           F:001373
  LDA PlayerJumpProgress                                      ;  1D96D D96D C A5 4F           F:001373
  ORA PlayerFallHeight                                      ;  1D96F D96F C 05 4E           F:001373
  BNE B_14_1D990                                  ;  1D971 D971 C D0 1D           F:001373
  INC PlayerAnimationCycle                                      ;  1D973 D973 C E6 4D           F:001403
  LDA PlayerAnimationCycle                                      ;  1D975 D975 C A5 4D           F:001403
  AND #$7                                         ;  1D977 D977 C 29 07           F:001403
  BNE B_14_1D990                                  ;  1D979 D979 C D0 15           F:001403
  LDA PlayerSpriteTile                                      ;  1D97B D97B C A5 56           F:001410
  AND #$8                                         ;  1D97D D97D C 29 08           F:001410
  BNE B_14_1D98A                                  ;  1D97F D97F C D0 09           F:001410
  LDA PlayerSpriteTile                                      ;  1D981 D981 C A5 56           F:001410
  EOR #$4                                         ;  1D983 D983 C 49 04           F:001410
  STA PlayerSpriteTile                                      ;  1D985 D985 C 85 56           F:001410
  JMP B_14_1D990                                  ;  1D987 D987 C 4C 90 D9        F:001410

B_14_1D98A:
  LDA PlayerSpriteAttr                                      ;  1D98A D98A C A5 57           F:003472
  EOR #$40                                        ;  1D98C D98C C 49 40           F:003472
  STA PlayerSpriteAttr                                      ;  1D98E D98E C 85 57           F:003472
B_14_1D990:
  RTS                                             ;  1D990 D990 C 60              F:001373

L_14_1D991:
  LDA PlayerYPxSpeed                                      ;  1D991 D991 C A5 4B           F:001373
  PHA                                             ;  1D993 D993 C 48              F:001373
  LDA PlayerMovingDirection                                      ;  1D994 D994 C A5 49           F:001373
  PHA                                             ;  1D996 D996 C 48              F:001373
B_14_1D997:
  JSR L_14_1D8B6                                  ;  1D997 D997 C 20 B6 D8        F:001373
  JSR EnsureNextPositionIsValid                                  ;  1D99A D99A C 20 08 CF        F:001373
  BCC B_14_1D9A7                                  ;  1D99D D99D C 90 08           F:001373
  JSR L_14_1D6D4                                  ;  1D99F D99F C 20 D4 D6        F:001470
  BCC B_14_1D9EB                                  ;  1D9A2 D9A2 C 90 47           F:001473
  JMP L_14_1DA13                                  ;  1D9A4 D9A4 C 4C 13 DA        F:001473

B_14_1D9A7:
  JSR L_14_1DD42                                  ;  1D9A7 D9A7 C 20 42 DD        F:001373
  BCS B_14_1D9EB                                  ;  1D9AA D9AA C B0 3F           F:001373
  JSR L_14_1CE1A                                  ;  1D9AC D9AC C 20 1A CE        F:001373
  BCC B_14_1DA14                                  ;  1D9AF D9AF C 90 63           F:001373
  LDA R_0008                                      ;  1D9B1 D9B1 C A5 08           F:001542
  CMP #$9                                         ;  1D9B3 D9B3 C C9 09           F:001542
  BEQ B_14_1D9EB                                  ;  1D9B5 D9B5 C F0 34           F:001542
  BCC B_14_1D9D1                                  ;  1D9B7 D9B7 C 90 18           F:001542
  LDX Tmp9                                      ;  1D9B9 D9B9 C A6 09           F:024681
  LDA Ent0Data+Ent_State,X                                    ;  1D9BB D9BB C BD 01 04        F:024681
  CMP #$1                                         ;  1D9BE D9BE C C9 01           F:024681
  BNE B_14_1D9C8                                  ;  1D9C0 D9C0 C D0 06           F:024681
  JSR L_14_1DA31                                  ;  1D9C2 D9C2 C 20 31 DA        F:024681
  JMP B_14_1DA14                                  ;  1D9C5 D9C5 C 4C 14 DA        F:024681

B_14_1D9C8:
  JSR L_14_1DA86                                  ;  1D9C8 D9C8 C 20 86 DA        F:003223
  JSR MarkAreaChestAsUsed                                  ;  1D9CB D9CB C 20 36 CA        F:003311
  JMP L_14_1DA13                                  ;  1D9CE D9CE C 4C 13 DA        F:003311

B_14_1D9D1:
  LDX Tmp9                                      ;  1D9D1 D9D1 C A6 09           F:001542
  LDA Ent0Data+Ent_State,X                                    ;  1D9D3 D9D3 C BD 01 04        F:001542
  CMP #$1                                         ;  1D9D6 D9D6 C C9 01           F:001542
  BEQ B_14_1D9E4                                  ;  1D9D8 D9D8 C F0 0A           F:001542
  CMP #$1A                                        ;  1D9DA D9DA C C9 1A           F:067566
  BCS B_14_1D9E7                                  ;  1D9DC D9DC C B0 09           F:067566
  JSR L_14_1DAAA                                  ;  1D9DE D9DE C 20 AA DA        F:001781
  JMP L_14_1DA13                                  ;  1D9E1 D9E1 C 4C 13 DA        F:001781

B_14_1D9E4:
  JSR L_14_1DA1B                                  ;  1D9E4 D9E4 C 20 1B DA        F:001542
B_14_1D9E7:
  CLC                                             ;  1D9E7 D9E7 C 18              F:001542
  JMP B_14_1DA14                                  ;  1D9E8 D9E8 C 4C 14 DA        F:001542

B_14_1D9EB:
  LDA PlayerSpeedBoostTimer1                                      ;  1D9EB D9EB C A5 88           F:001384
  BEQ B_14_1DA02                                  ;  1D9ED D9ED C F0 13           F:001384
  LDA PlayerMovingDirection                                      ;  1D9EF D9EF C A5 49           F:007088
  BEQ B_14_1DA02                                  ;  1D9F1 D9F1 C F0 0F           F:007088
  TAX                                             ;  1D9F3 D9F3 C AA              F:007088
  AND #$8                                         ;  1D9F4 D9F4 C 29 08           F:007088
  BNE B_14_1D9FA                                  ;  1D9F6 D9F6 C D0 02           F:007088
  DEX                                             ;  1D9F8 D9F8 C CA              F:007088
  DEX                                             ;  1D9F9 D9F9 C CA              F:007088
B_14_1D9FA:
  INX                                             ;  1D9FA D9FA C E8              F:007088
  TXA                                             ;  1D9FB D9FB C 8A              F:007088
  AND #$F                                         ;  1D9FC D9FC C 29 0F           F:007088
  STA PlayerMovingDirection                                      ;  1D9FE D9FE C 85 49           F:007088
  BNE B_14_1D997                                  ;  1DA00 DA00 C D0 95           F:007088
B_14_1DA02:
  PLA                                             ;  1DA02 DA02 C 68              F:001384
  PHA                                             ;  1DA03 DA03 C 48              F:001384
  STA PlayerMovingDirection                                      ;  1DA04 DA04 C 85 49           F:001384
  LDX PlayerYPxSpeed                                      ;  1DA06 DA06 C A6 4B           F:001384
  BEQ L_14_1DA13                                  ;  1DA08 DA08 C F0 09           F:001384
  BMI B_14_1DA0E                                  ;  1DA0A DA0A C 30 02           F:001384
  DEX                                             ;  1DA0C DA0C C CA              F:001390
  DEX                                             ;  1DA0D DA0D C CA              F:001390
B_14_1DA0E:
  INX                                             ;  1DA0E DA0E C E8              F:001384
  STX PlayerYPxSpeed                                      ;  1DA0F DA0F C 86 4B           F:001384
  BNE B_14_1D997                                  ;  1DA11 DA11 C D0 84           F:001384
L_14_1DA13:
  SEC                                             ;  1DA13 DA13 C 38              F:001384
B_14_1DA14:
  PLA                                             ;  1DA14 DA14 C 68              F:001373
  STA PlayerMovingDirection                                      ;  1DA15 DA15 C 85 49           F:001373
  PLA                                             ;  1DA17 DA17 C 68              F:001373
  STA PlayerYPxSpeed                                      ;  1DA18 DA18 C 85 4B           F:001373
  RTS                                             ;  1DA1A DA1A C 60              F:001373

L_14_1DA1B:
  LDA SelectedBank3                                      ;  1DA1B DA1B C A5 2D           F:001542
  CMP #$30                                        ;  1DA1D DA1D C C9 30           F:001542
  BCS B_14_1DA30                                  ;  1DA1F DA1F C B0 0F           F:001542
  LDA GameIntervalTimer2                                      ;  1DA21 DA21 C A5 87           F:001542
  BEQ B_14_1DA30                                  ;  1DA23 DA23 C F0 0B           F:001542
  LDA PlayerMP                                      ;  1DA25 DA25 . A5 59           
  BEQ B_14_1DA30                                  ;  1DA27 DA27 . F0 07           
  LDX Tmp9                                      ;  1DA29 DA29 . A6 09           
  LDA #$80                                        ;  1DA2B DA2B . A9 80           
  STA Ent0Data+Ent_State,X                                    ;  1DA2D DA2D . 9D 01 04        
B_14_1DA30:
  RTS                                             ;  1DA30 DA30 C 60              F:001542

L_14_1DA31:
  JSR UsePlayerKey                                  ;  1DA31 DA31 C 20 6F E8        F:024681
  BCC B_14_1DA3C                                  ;  1DA34 DA34 C 90 06           F:024681
  LDA #$6                                         ;  1DA36 DA36 C A9 06           F:024681
  STA PendingSFX                                      ;  1DA38 DA38 C 85 8F           F:024681
  CLC                                             ;  1DA3A DA3A C 18              F:024681
  RTS                                             ;  1DA3B DA3B C 60              F:024681

B_14_1DA3C:
  LDY #$A                                         ;  1DA3C DA3C C A0 0A           F:003103
  LDA (AreaDataPtr),Y                                  ;  1DA3E DA3E C B1 77           F:003103
  CMP #$8                                         ;  1DA40 DA40 C C9 08           F:003103
  BCS B_14_1DA49                                  ;  1DA42 DA42 C B0 05           F:003103
  LDY #$0                                         ;  1DA44 DA44 C A0 00           F:003103
  STY RoomChestUnk4A2                                      ;  1DA46 DA46 C 8C A2 04        F:003103
B_14_1DA49:
  PHA                                             ;  1DA49 DA49 C 48              F:003103
  CLC                                             ;  1DA4A DA4A C 18              F:003103
  ADC #$2                                         ;  1DA4B DA4B C 69 02           F:003103
  STA RoomChestActive                                      ;  1DA4D DA4D C 8D A1 04        F:003103
  PLA                                             ;  1DA50 DA50 C 68              F:003103
  ASL                                             ;  1DA51 DA51 C 0A              F:003103
  ASL                                             ;  1DA52 DA52 C 0A              F:003103
  CLC                                             ;  1DA53 DA53 C 18              F:003103
  ADC #$81                                        ;  1DA54 DA54 C 69 81           F:003103
  STA RoomChestState                                      ;  1DA56 DA56 C 8D A0 04        F:003103
  LDA #$1F                                        ;  1DA59 DA59 C A9 1F           F:003103
  STA PendingSFX                                      ;  1DA5B DA5B C 85 8F           F:003103
  JSR UpdateEntitySprites                                  ;  1DA5D DA5D C 20 B1 C2        F:003103
  LDA InvincibilityFramesTimer                                      ;  1DA60 DA60 C A5 85           F:003103
  PHA                                             ;  1DA62 DA62 C 48              F:003103
  LDA #$0                                         ;  1DA63 DA63 C A9 00           F:003103
  STA InvincibilityFramesTimer                                      ;  1DA65 DA65 C 85 85           F:003103
  JSR UpdatePlayerSprites                                  ;  1DA67 DA67 C 20 D8 C1        F:003103
  LDA CurrentMusic                                      ;  1DA6A DA6A C A5 8E           F:003103
  PHA                                             ;  1DA6C DA6C C 48              F:003103
  LDA #$E                                         ;  1DA6D DA6D C A9 0E           F:003103
  STA CurrentMusic                                      ;  1DA6F DA6F C 85 8E           F:003103
  JSR Audio_StartMusic                                  ;  1DA71 DA71 C 20 08 FC        F:003103
  LDA #$78                                        ;  1DA74 DA74 C A9 78           F:003103
  STA FrameCountdownTimer                                      ;  1DA76 DA76 C 85 36           F:003103
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  PLA                                             ;  1DA7B DA7B C 68              F:003223
  STA CurrentMusic                                      ;  1DA7C DA7C C 85 8E           F:003223
  JSR Audio_StartMusic                                  ;  1DA7E DA7E C 20 08 FC        F:003223
  PLA                                             ;  1DA81 DA81 C 68              F:003223
  STA InvincibilityFramesTimer                                      ;  1DA82 DA82 C 85 85           F:003223
  SEC                                             ;  1DA84 DA84 C 38              F:003223
  RTS                                             ;  1DA85 DA85 C 60              F:003223

L_14_1DA86:
  SEC                                             ;  1DA86 DA86 C 38              F:003223
  SBC #$2                                         ;  1DA87 DA87 C E9 02           F:003223
  PHA                                             ;  1DA89 DA89 C 48              F:003223
  LDA #$0                                         ;  1DA8A DA8A C A9 00           F:003223
  STA RoomChestActive                                      ;  1DA8C DA8C C 8D A1 04        F:003223
  PLA                                             ;  1DA8F DA8F C 68              F:003223
  cmp #DropType_DragonSlayer+1                    ; are we picking up a valid item?
  bcc @CheckPickup                                ; if so - skip ahead
  JMP HandleInvalidItemPickup                     ; otherwise deal with invalid pickup

@CheckPickup:
  @TmpRoutine = $C
  cmp #DropType_Wings                             ; check if we're a permanent item chest
  bcs AddItemToPlayerInventory                    ; if so - add the item to player inventory
  asl a                                           ; otherwise get offset into effect table
  tax                                             ;
  lda ChestPickupActions,x                        ; and get our routine pointer
  sta @TmpRoutine                                 ;
  lda ChestPickupActions+1,x                      ;
  sta @TmpRoutine+1                               ;
  jmp (@TmpRoutine)                               ; and call it!

L_14_1DAAA:
  SEC                                             ;  1DAAA DAAA C 38              F:001781
  SBC #$2                                         ;  1DAAB DAAB C E9 02           F:001781
  CMP #$18                                        ;  1DAAD DAAD C C9 18           F:001781
  BCC B_14_1DAB2                                  ;  1DAAF DAAF C 90 01           F:001781
  RTS                                             ;  1DAB1 DAB1 . 60              

B_14_1DAB2:
  PHA                                             ;  1DAB2 DAB2 C 48              F:001781
  LDA #$0                                         ;  1DAB3 DAB3 C A9 00           F:001781
  STA Ent0Data+Ent_State,X                                    ;  1DAB5 DAB5 C 9D 01 04        F:001781
  LDA #$F0                                        ;  1DAB8 DAB8 C A9 F0           F:001781
  STA Ent0Data+Ent_AnimTimer,X                                    ;  1DABA DABA C 9D 06 04        F:001781
  LDA R_0008                                      ;  1DABD DABD C A5 08           F:001781
  ASL                                             ;  1DABF DABF C 0A              F:001781
  ASL                                             ;  1DAC0 DAC0 C 0A              F:001781
  ASL                                             ;  1DAC1 DAC1 C 0A              F:001781
  ORA #$80                                        ;  1DAC2 DAC2 C 09 80           F:001781
  TAX                                             ;  1DAC4 DAC4 C AA              F:001781
  LDA #$EF                                        ;  1DAC5 DAC5 C A9 EF           F:001781
  STA SprY,X                                    ;  1DAC7 DAC7 C 9D 00 02        F:001781
  STA R_0204,X                                    ;  1DACA DACA C 9D 04 02        F:001781
  PLA                                             ;  1DACD DACD C 68              F:001781
  CMP #$8                                         ;  1DACE DACE C C9 08           F:001781
  BCC B_14_1DAF2                                  ;  1DAD0 DAD0 C 90 20           F:001781
AddItemToPlayerInventory:
  sbc #DropType_InventoryStart                    ; reduce by offset to inventory pickups
  tax                                             ;
  lda PlayerInventory,x                           ; check how many of the item the player has
  cmp #11                                         ; 
  bcs @TooManyItems                               ; whoa - too many, play bad sound!
  inc PlayerInventory,x                           ; otherwise add to the player inventory
  lda #SFX_InventoryPickup                        ; and play a good sound
  sta PendingSFX                                  ;
  cpx #ItemType_Crown                             ; did we pick up a crown?
  beq @WarpToBoss                                 ; yes - boss time!
  rts                                             ; otherwise we're done here.

@WarpToBoss:
  JSR MarkAreaChestAsUsed                                  ;  1DAE6 DAE6 . 20 36 CA        
  JMP WarpToBossEncounter                   ;  1DAE9 DAE9 . 4C 20 D6        

@TooManyItems:
  lda #SFX_ItemOverflowPickup                     ; play power down sound
  sta a:PendingSFX                                ;
  rts                                             ; done!

B_14_1DAF2:
  @TmpPtr = $C
  asl a                                           ; get offset into drop table
  tax                                             ;
  lda DropPickupActions,x                         ; copy routine pointer
  sta @TmpPtr                                     ;
  lda DropPickupActions+1,x                       ;
  sta @TmpPtr+1                                   ;
  jmp (@TmpPtr)                                   ; and call the routine

HandleInvalidItemPickup:
  lda #SFX_PowerDown                              ; invalid item id picked up
  sta PendingSFX                                  ; play power down sound
  rts                                             ; and that's it.. boring.

DropPickupActions:
.addr GivePlayer5HP                               ; HP
.addr GivePlayer5MP                               ; Mana
.addr GivePlayer2Gold                             ; Gold
.addr HurtPlayerBy5                               ; Poison
.addr GivePlayer1Key                              ; Key
.addr GivePlayer10SecondsIFrames                  ; Ring
.addr KillAllEnemies                              ; Cross
.addr GivePlayerSpeedBoost                        ; Scroll

ChestPickupActions:
.addr RefillPlayerHP                              ; HP
.addr RefillPlayerMana                            ; Mana
.addr GivePlayer50Gold                            ; Gold
.addr HurtPlayerBy5                               ; Poison
.addr GivePlayer20Keys                            ; Key
.addr GivePlayer30SecondsIFrames                  ; Ring
.addr KillAllEnemies                              ; Cross
.addr GivePlayerChestSpeedBoost                   ; Scroll

GivePlayer5HP:
  lda #SFX_HealthPickup                                 ; play pickup sound
  sta a:PendingSFX                                ;
  lda #5                                          ; and add some health
  jsr AddPlayerHP                                 ;
  rts                                             ; done!

GivePlayer5MP:
  lda #SFX_ManaPickup                                   ; play pickup sound
  sta a:PendingSFX                                ;
  lda #5                                          ; and add some mana
  jsr AddPlayerMana                               ;
  rts                                             ; done!

GivePlayer2Gold:
  LDA #SFX_GoldPickup                             ; play pickup sound
  STA a:PendingSFX                                ;
  LDA #2                                          ; and add some gold
  JSR AddPlayerGold                               ;
  RTS                                             ; done!

GivePlayer50Gold:
  lda #SFX_GoldPickup                            ; play pickup sound
  sta a:PendingSFX                               ;
  lda #50                                        ; and add some gold
  jsr AddPlayerGold                              ;
  rts                                            ; done!

HurtPlayerBy5:
  lda #SFX_PoisonPickup                                 ; play pickup sound
  sta a:PendingSFX                                ;
  lda #$5                                         ; and apply damage
  jsr ApplyDamageToPlayer                         ;
  rts                                             ; done!

GivePlayer1Key:
  lda #SFX_KeyPickup                                    ; play pickup sound
  sta a:PendingSFX                                ;
  jsr AddPlayerKey                                ; and give key
  rts                                             ; done!

GivePlayer20Keys:
  lda #SFX_KeyPickup                                    ; play pickup sound
  sta a:PendingSFX                                ;
  lda #20                                         ; and give some keys
  jsr AddPlayerKeys                               ;
  rts                                             ; done!

GivePlayer10SecondsIFrames:
  lda #SFX_RingPickup                          ; play pickup sound
  sta a:PendingSFX                                ;
  lda #10                                         ; set 10 seconds of invincibility
  sta InvincibilityFramesTimer                    ;
  rts                                             ; done!

GivePlayer30SecondsIFrames:
  lda #SFX_RingPickup                          ; play pickup sound
  sta a:PendingSFX                                ;
  lda #30                                         ; set 30 seconds of invincibility
  sta InvincibilityFramesTimer                    ;
  rts                                             ; done!

GivePlayerSpeedBoost:
  lda #SFX_ScrollPickup                          ; enqueue pickup sound
  sta a:PendingSFX                                ;
  ldx #30                                         ; we want to set the remaining time to 60 seconds
  lda PlayerSpeedBoostTimer1                      ; check how many boosts are active, and jump to the correct offset
  beq @SetBoost1                                  ;
  lda PlayerSpeedBoostTimer2                      ;
  beq @SetBoost2                                  ;
  stx PlayerSpeedBoostTimer3                      ;
@SetBoost2:                                       ;
  stx PlayerSpeedBoostTimer2                      ;
@SetBoost1:                                       ;
  stx PlayerSpeedBoostTimer1                      ;
  rts                                             ; done!

GivePlayerChestSpeedBoost:
  lda #SFX_ScrollPickup                          ; enqueue pickup sound
  sta a:PendingSFX                                ;
  ldx #60                                         ; we want to set the remaining time to 60 seconds
  lda PlayerSpeedBoostTimer1                      ; check how many boosts are active, and jump to the correct offset
  beq @SetBoost1                                  ;
  lda PlayerSpeedBoostTimer2                      ;
  beq @SetBoost2                                  ;
  lda PlayerSpeedBoostTimer3                      ;
  beq @SetBoost3                                  ;
  stx PlayerSpeedBoostTimer4                      ; and set the appropriate boost
@SetBoost3:                                       ;
  stx PlayerSpeedBoostTimer3                      ;
@SetBoost2:                                       ;
  stx PlayerSpeedBoostTimer2                      ;
@SetBoost1:                                       ;
  stx PlayerSpeedBoostTimer1                      ;
  rts                                             ; done!

KillAllEnemies:
  ldx #9                                          ; loop through each enemy
  ldy #0                                          ;
: lda Ent0Data+Ent_State,y                               ; check if enemy is active
  cmp #1                                          ;
  bne @Skip                                       ; if not - skip ahead
  lda #$80                                        ; otherwise set dead flag
  sta Ent0Data+Ent_State,y                               ;
@Skip:
  tya                                             ; advance pointer to next entity
  clc                                             ;
  adc #$10                                        ;
  tay                                             ;
  dex                                             ; and decrement counter
  bne :-                                          ; loop until done
  lda #SFX_CrossPickup                                  ; play sound effect
  sta PendingSFX                                  ;
  lda #$FF                                        ;
  sta R_0090                                      ;
  ldx #2                                          ;
  jsr LightningFlashScreen                        ; flash the screen a couple of times
  rts                                             ; and done!

L_14_1DBDD:
  LDA GameIntervalTimer1                                      ;  1DBDD DBDD C A5 86           F:001373
  BNE B_14_1DBE5                                  ;  1DBDF DBDF C D0 04           F:001373
  LDA PlayerJumpProgress                                      ;  1DBE1 DBE1 C A5 4F           F:001373
  BEQ B_14_1DBEC                                  ;  1DBE3 DBE3 C F0 07           F:001373
B_14_1DBE5:
  LDA #$0                                         ;  1DBE5 DBE5 C A9 00           F:001373
  STA PlayerIsFiring                                      ;  1DBE7 DBE7 C 85 50           F:001373
  JMP L_14_1DC82                                  ;  1DBE9 DBE9 C 4C 82 DC        F:001373

B_14_1DBEC:
  lda PlayerXTile                                 ; get player x pos for lookup
  sta PositionToBlock_XTile                       ;
  STA TmpF                                    ;  1DBF0 DBF0 C 85 0F           F:001389
  LDA PlayerXPx                               ;
  STA TmpE                                      ;  1DBF4 DBF4 C 85 0E           F:001389
  ldx PlayerYPx                                   ; use player y pos for lookup
  stx PositionToBlock_YPx                         ;
  inx                                             ;
  STX TmpA                             ;  1DBFB DBFB C 86 0A           F:001389
  jsr PositionToBlock                             ; find pointer to block
  LDA PlayerXPx                               ;  1DC00 DC00 C A5 43           F:001389
  BNE @B_14_1DC10                                  ;  1DC02 DC02 C D0 0C           F:001389
  LDA #$1                                         ;  1DC04 DC04 C A9 01           F:001389
  STA PlayerIsFiring                                      ;  1DC06 DC06 C 85 50           F:001389
  ldy #$0                                         ; check block we are landing on
  lda (BlockPtrLo),y                                ;
  and #%00111111                                  ; without the palette bits
  beq @ProcessFalling                             ; if there is no tile we can just keep falling
@B_14_1DC10:
  LDA #$0                                         ;  1DC10 DC10 C A9 00           F:001389
  STA PlayerIsFiring                                      ;  1DC12 DC12 C 85 50           F:001389
  lda PlayerYPx                                   ; are we very close to the top of the screen?
  cmp #$B0                                        ;
  bcs @Done                                       ; exit without damage
  JSR L_14_1CDB2                                  ;  1DC1A DC1A C 20 B2 CD        F:001389
  BCC @B_14_1DC38                                 ;  1DC1D DC1D C 90 19           F:001389
  lda SelectedBank3                               ; use enemy gfx to determine if we are in a boss encounter
  cmp #$30                                        ;
  bcs @ProcessFalling                             ; if we are - skip directly to handling fall
  ldy PlayerSelectedItemSlot                       ; if we are not fighting a boss
  ldx PlayerActiveItems,y                         ;
  cpx #ItemType_PowerBoots                        ; check if we have the power boots on
  bne @ProcessFalling                             ; if not - regular fall
  lda PlayerFallHeight                            ; have we begun falling?
  beq @ProcessFalling                             ; if not - regular fall
  LDX Tmp9                                      ;  1DC31 DC31 . A6 09           
  LDA #$80                                        ;  1DC33 DC33 . A9 80           
  STA Ent0Data+Ent_State,X                                    ;  1DC35 DC35 . 9D 01 04        
@B_14_1DC38:
  LDY #$1                                         ;  1DC38 DC38 C A0 01           F:001389
  JSR L_14_1DCCC                                  ;  1DC3A DC3A C 20 CC DC        F:001389
  BCS @ProcessFalling                                  ;  1DC3D DC3D C B0 0E           F:001389
  LDA PlayerXPx                                      ;  1DC3F DC3F C A5 43           F:001389
  BEQ @Done                                  ;  1DC41 DC41 C F0 07           F:001389
  LDY #$D                                         ;  1DC43 DC43 C A0 0D           F:001403
  JSR L_14_1DCCC                                  ;  1DC45 DC45 C 20 CC DC        F:001403
  BCS @ProcessFalling                                  ;  1DC48 DC48 C B0 03           F:001403
@Done:
  INC PlayerFallHeight                                      ;  1DC4A DC4A C E6 4E           F:001389
  RTS                                             ;  1DC4C DC4C C 60              F:001389

@ProcessFalling:
  LDA PlayerFallHeight                                      ;  1DC4D DC4D C A5 4E           F:001403
  CMP PlayerAttrJump                                      ;  1DC4F DC4F C C5 5C           F:001403
  BCC B_14_1DC6E                                  ;  1DC51 DC51 C 90 1B           F:001403
  SEC                                             ;  1DC53 DC53 C 38              F:001477
  SBC #$7                                         ;  1DC54 DC54 C E9 07           F:001477
  CMP PlayerAttrJump                                      ;  1DC56 DC56 C C5 5C           F:001477
  BCC B_14_1DC5C                                  ;  1DC58 DC58 C 90 02           F:001477
  LDA PlayerAttrJump                                      ;  1DC5A DC5A C A5 5C           F:001477
B_14_1DC5C:
  SEC                                             ;  1DC5C DC5C C 38              F:001477
  SBC #$1                                         ;  1DC5D DC5D C E9 01           F:001477
  STA PlayerJumpProgress                                      ;  1DC5F DC5F C 85 4F           F:001477
  CLC                                             ;  1DC61 DC61 C 18              F:001477
  ADC #$A                                         ;  1DC62 DC62 C 69 0A           F:001477
  STA PlayerStunTimer                                      ;  1DC64 DC64 C 85 46           F:001477
  LDA #$A                                         ;  1DC66 DC66 C A9 0A           F:001477
  STA a:PendingSFX                                    ;  1DC68 DC68 C 8D 8F 00        F:001477
  JSR DecrementPlayerHealth                                  ;  1DC6B DC6B C 20 CE E7        F:001477
B_14_1DC6E:
  LDA PlayerFallHeight                                      ;  1DC6E DC6E C A5 4E           F:001403
  BNE L_14_1DC82                                  ;  1DC70 DC70 C D0 10           F:001403
  LDY #$1                                         ;  1DC72 DC72 C A0 01           F:001404
  JSR L_14_1DCA8                                  ;  1DC74 DC74 C 20 A8 DC        F:001404
  BCS L_14_1DC82                                  ;  1DC77 DC77 C B0 09           F:001404
  LDA PlayerXPx                                      ;  1DC79 DC79 C A5 43           F:001404
  BEQ L_14_1DC82                                  ;  1DC7B DC7B C F0 05           F:001404
  LDY #$D                                         ;  1DC7D DC7D C A0 0D           F:001404
  JSR L_14_1DCA8                                  ;  1DC7F DC7F C 20 A8 DC        F:001404
L_14_1DC82:
  LDA #$0                                         ;  1DC82 DC82 C A9 00           F:001373
  STA PlayerFallHeight                                      ;  1DC84 DC84 C 85 4E           F:001373
  RTS                                             ;  1DC86 DC86 C 60              F:001373

L_14_1DC87:
  LDA GameIntervalTimer1                                      ;  1DC87 DC87 C A5 86           F:007534
  ORA PlayerJumpProgress                                      ;  1DC89 DC89 C 05 4F           F:007534
  BNE B_14_1DCA6                                  ;  1DC8B DC8B C D0 19           F:007534
  LDA TmpE                                      ;  1DC8D DC8D C A5 0E           F:014254
  BNE B_14_1DCA4                                  ;  1DC8F DC8F C D0 13           F:014254
  LDA TmpF                                      ;  1DC91 DC91 C A5 0F           F:014254
  STA PositionToBlock_XTile                                      ;  1DC93 DC93 C 85 0C           F:014254
  LDA #$0                                         ;  1DC95 DC95 C A9 00           F:014254
  STA PositionToBlock_YPx                                      ;  1DC97 DC97 C 85 0D           F:014254
  JSR PositionToBlock                                  ;  1DC99 DC99 C 20 54 CA        F:014254
  LDY #$0                                         ;  1DC9C DC9C C A0 00           F:014254
  LDA (BlockPtrLo),Y                                  ;  1DC9E DC9E C B1 0C           F:014254
  AND #$3F                                        ;  1DCA0 DCA0 C 29 3F           F:014254
  BEQ B_14_1DCA6                                  ;  1DCA2 DCA2 C F0 02           F:014254
B_14_1DCA4:
  CLC                                             ;  1DCA4 DCA4 . 18              
  RTS                                             ;  1DCA5 DCA5 . 60              

B_14_1DCA6:
  SEC                                             ;  1DCA6 DCA6 C 38              F:007534
  RTS                                             ;  1DCA7 DCA7 C 60              F:007534

L_14_1DCA8:
  LDA (BlockPtrLo),Y                                  ;  1DCA8 DCA8 C B1 0C           F:001404
  AND #$3F                                        ;  1DCAA DCAA C 29 3F           F:001404
  CMP #$30                                        ;  1DCAC DCAC C C9 30           F:001404
  BNE B_14_1DCCA                                  ;  1DCAE DCAE C D0 1A           F:001404
  LDA PlayerJumpProgress                                      ;  1DCB0 DCB0 C A5 4F           F:001509
  BNE B_14_1DCB8                                  ;  1DCB2 DCB2 C D0 04           F:001509
  LDA #$A                                         ;  1DCB4 DCB4 C A9 0A           F:001509
  STA PlayerJumpProgress                                      ;  1DCB6 DCB6 C 85 4F           F:001509
B_14_1DCB8:
  LDA InvincibilityFramesTimer                                      ;  1DCB8 DCB8 C A5 85           F:001509
  BNE B_14_1DCC8                                  ;  1DCBA DCBA C D0 0C           F:001509
  JSR DecrementPlayerHealth                                  ;  1DCBC DCBC C 20 CE E7        F:001509
  LDA #$A                                         ;  1DCBF DCBF C A9 0A           F:001509
  STA a:PendingSFX                                    ;  1DCC1 DCC1 C 8D 8F 00        F:001509
  LDA #$1                                         ;  1DCC4 DCC4 C A9 01           F:001509
  STA InvincibilityFramesTimer                                      ;  1DCC6 DCC6 C 85 85           F:001509
B_14_1DCC8:
  SEC                                             ;  1DCC8 DCC8 C 38              F:001509
  RTS                                             ;  1DCC9 DCC9 C 60              F:001509

B_14_1DCCA:
  CLC                                             ;  1DCCA DCCA C 18              F:001404
  RTS                                             ;  1DCCB DCCB C 60              F:001404

L_14_1DCCC:
  LDA (BlockPtrLo),Y                                  ;  1DCCC DCCC C B1 0C           F:001389
  AND #$3F                                        ;  1DCCE DCCE C 29 3F           F:001389
  TAX                                             ;  1DCD0 DCD0 C AA              F:001389
  BEQ B_14_1DCDA                                  ;  1DCD1 DCD1 C F0 07           F:001389
  CPX #$2                                         ;  1DCD3 DCD3 C E0 02           F:001389
  BEQ B_14_1DCE0                                  ;  1DCD5 DCD5 C F0 09           F:001389
  CPX #$30                                        ;  1DCD7 DCD7 C E0 30           F:001389
  RTS                                             ;  1DCD9 DCD9 C 60              F:001389

B_14_1DCDA:
  LDA PlayerXPx                                      ;  1DCDA DCDA C A5 43           F:001477
  BEQ B_14_1DCE0                                  ;  1DCDC DCDC C F0 02           F:001477
  CLC                                             ;  1DCDE DCDE C 18              F:001477
  RTS                                             ;  1DCDF DCDF C 60              F:001477

B_14_1DCE0:
  SEC                                             ;  1DCE0 DCE0 C 38              F:007542
  RTS                                             ;  1DCE1 DCE1 C 60              F:007542

EnterDoorIfFound:
  @TmpLookup = $C
  ldx PlayerYPx                                   ; check player y position
  beq @Exit                                       ; if invalid, exit
  dex                                             ; decrement by 1 so we get the tile just above us
  stx @TmpLookup+1                                ; and use that as low byte for our lookup
  ldx PlayerXTile                                 ; get player x pixel / 0x10
  stx @TmpLookup                                  ; and use that as our high byte
  jsr PositionToBlock                          ; take player position and convert to block pointer
  ldy #$0                                         ;
  lda (@TmpLookup),y                              ; load the tile at the player position
  and #%00111111                                  ; strip off palette bits
  cmp #Tile_InnSign                               ; branch off if we're entering an inn
  beq @EnterInnDoor                               ;
  cmp #Tile_ShopSign                              ; or a shop
  beq @EnterShopDoor                              ;
  cmp #Tile_Princess                          ; or a princess door
  beq @EnterPrincessDoor                          ;
  lda PlayerXPx                               ; ok.. no doors were found above us. check x pixel within tile
  beq @Exit                                       ; if we're perfectly aligned with the tile, exit
  ldy #12                                         ; shift over block lookup by 1 horizontal tile
  lda (@TmpLookup),y                              ;
  and #%00111111                                  ; strip off palette bits
  cmp #Tile_InnSign                               ; branch off if we're entering an inn
  beq @EnterInnDoor                               ;
  cmp #Tile_ShopSign                              ; or a shop
  beq @EnterShopDoor                              ;
  cmp #Tile_Princess                          ; or a princess door
  beq @EnterPrincessDoor                          ;
@Exit:
  rts                                             ; nothing left for us to do now but give up.
@EnterInnDoor:
  pla                                             ; strip off our caller routine
  pla                                             ;
  jmp EnterInnDoor                                ; and enter the door
@EnterShopDoor:
  pla                                             ; strip off our caller routine
  pla                                             ;
  jmp EnterShopDoor                               ; and enter the door
@EnterPrincessDoor:
  ldx PlayerSelectedItemSlot                       ; check which item the player has equipped
  lda PlayerActiveItems,X                         ;
  cmp #ItemType_Crown                             ;
  bne @Exit                                       ; bail out unless it's the crown
  ldx #$2                                         ; 
  ldy PlayerInventory_Crown                       ; check number of crowns in inventory
  lda #ItemType_Crown                             ;
: cmp PlayerActiveItems,x                         ; check if each equipped item is a crown
  bne :+                                          ;
  iny                                             ; increment Y to figure out how many crowns the player has
: dex                                             ;
  bpl :--                                         ; loop through each equipped item
  cpy #$4                                         ; do we have 4 crowns total?
  bne @Exit                                       ; if not - bail out
  pla                                             ;
  pla                                             ;
  jmp EnterPrincessDoor                           ; otherwise run princess door warp

L_14_1DD42:
  LDA #$90                                        ;  1DD42 DD42 C A9 90           F:001373
  STA WorksetPtr                                      ;  1DD44 DD44 C 85 E5           F:001373
  LDA #$4                                         ;  1DD46 DD46 C A9 04           F:001373
  STA WorksetPtr+1                                      ;  1DD48 DD48 C 85 E6           F:001373
  LDA TmpE                                      ;  1DD4A DD4A C A5 0E           F:001373
  PHA                                             ;  1DD4C DD4C C 48              F:001373
  LDA TmpF                                      ;  1DD4D DD4D C A5 0F           F:001373
  PHA                                             ;  1DD4F DD4F C 48              F:001373
  LDA TmpA                                      ;  1DD50 DD50 C A5 0A           F:001373
  PHA                                             ;  1DD52 DD52 C 48              F:001373
  LDA TmpF                                      ;  1DD53 DD53 C A5 0F           F:001373
  STA PositionToBlock_XTile                                      ;  1DD55 DD55 C 85 0C           F:001373
  LDA TmpA                                      ;  1DD57 DD57 C A5 0A           F:001373
  STA PositionToBlock_YPx                                      ;  1DD59 DD59 C 85 0D           F:001373
  JSR PositionToBlock                                  ;  1DD5B DD5B C 20 54 CA        F:001373
  LDY #$0                                         ;  1DD5E DD5E C A0 00           F:001373
  JSR L_14_1DD97                                  ;  1DD60 DD60 C 20 97 DD        F:001373
  BCS B_14_1DD8D                                  ;  1DD63 DD63 C B0 28           F:001373
  LDA TmpE                                      ;  1DD65 DD65 C A5 0E           F:001373
  BEQ B_14_1DD70                                  ;  1DD67 DD67 C F0 07           F:001373
  LDY #$C                                         ;  1DD69 DD69 C A0 0C           F:001373
  JSR L_14_1DD97                                  ;  1DD6B DD6B C 20 97 DD        F:001373
  BCS B_14_1DD8D                                  ;  1DD6E DD6E C B0 1D           F:001373
B_14_1DD70:
  LDA TmpA                                      ;  1DD70 DD70 C A5 0A           F:001373
  CMP #$B0                                        ;  1DD72 DD72 C C9 B0           F:001373
  BCS B_14_1DD8C                                  ;  1DD74 DD74 C B0 16           F:001373
  AND #$F                                         ;  1DD76 DD76 C 29 0F           F:001373
  BEQ B_14_1DD8C                                  ;  1DD78 DD78 C F0 12           F:001373
  LDY #$1                                         ;  1DD7A DD7A C A0 01           F:001373
  JSR L_14_1DD97                                  ;  1DD7C DD7C C 20 97 DD        F:001373
  BCS B_14_1DD8D                                  ;  1DD7F DD7F C B0 0C           F:001373
  LDA TmpE                                      ;  1DD81 DD81 C A5 0E           F:001373
  BEQ B_14_1DD8C                                  ;  1DD83 DD83 C F0 07           F:001373
  LDY #$D                                         ;  1DD85 DD85 C A0 0D           F:001373
  JSR L_14_1DD97                                  ;  1DD87 DD87 C 20 97 DD        F:001373
  BCS B_14_1DD8D                                  ;  1DD8A DD8A C B0 01           F:001373
B_14_1DD8C:
  CLC                                             ;  1DD8C DD8C C 18              F:001373
B_14_1DD8D:
  PLA                                             ;  1DD8D DD8D C 68              F:001373
  STA TmpA                                      ;  1DD8E DD8E C 85 0A           F:001373
  PLA                                             ;  1DD90 DD90 C 68              F:001373
  STA TmpF                                      ;  1DD91 DD91 C 85 0F           F:001373
  PLA                                             ;  1DD93 DD93 C 68              F:001373
  STA TmpE                                      ;  1DD94 DD94 C 85 0E           F:001373
  RTS                                             ;  1DD96 DD96 C 60              F:001373

L_14_1DD97:
  LDA (BlockPtrLo),Y                                  ;  1DD97 DD97 C B1 0C           F:001373
  AND #$3F                                        ;  1DD99 DD99 C 29 3F           F:001373
  CMP AreaBlockSwapFrom                                      ;  1DD9B DD9B C C5 70           F:001373
  BNE B_14_1DDA2                                  ;  1DD9D DD9D C D0 03           F:001373
  JMP L_14_1DDB3                                  ;  1DD9F DD9F C 4C B3 DD        F:011209

B_14_1DDA2:
  CMP #$2                                         ;  1DDA2 DDA2 C C9 02           F:001373
  BNE B_14_1DDA9                                  ;  1DDA4 DDA4 C D0 03           F:001373
  JMP L_14_1DDE0                                  ;  1DDA6 DDA6 C 4C E0 DD        F:077168

B_14_1DDA9:
  CMP #$3E                                        ;  1DDA9 DDA9 C C9 3E           F:001373
  BNE B_14_1DDB0                                  ;  1DDAB DDAB C D0 03           F:001373
  JMP L_14_1DE1A                                  ;  1DDAD DDAD C 4C 1A DE        F:003318

B_14_1DDB0:
  CMP #$30                                        ;  1DDB0 DDB0 C C9 30           F:001373
  RTS                                             ;  1DDB2 DDB2 C 60              F:001373

L_14_1DDB3:
  LDA Ent9Data+Ent_State                                      ;  1DDB3 DDB3 C AD 91 04        F:011209
  BNE B_14_1DDD9                                  ;  1DDB6 DDB6 C D0 21           F:011209
  STY BlockOffset                                      ;  1DDB8 DDB8 C 84 0B           F:011209
  LDA #$E1                                        ;  1DDBA DDBA C A9 E1           F:011209
  STA Workset+Ent_Gfx                                      ;  1DDBC DDBC C 85 ED           F:011209
  LDA #$1                                         ;  1DDBE DDBE C A9 01           F:011209
  STA Workset+Ent_State                                      ;  1DDC0 DDC0 C 85 EE           F:011209
  LDA #$1                                         ;  1DDC2 DDC2 C A9 01           F:011209
  STA Workset+Ent_SprAttr                                      ;  1DDC4 DDC4 C 85 EF           F:011209
  LDA AreaBlockSwapTo                                      ;  1DDC6 DDC6 C A5 71           F:011209
  STA Workset+Ent_SwapBlock                                      ;  1DDC8 DDC8 C 85 F0           F:011209
  LDA #$A                                         ;  1DDCA DDCA C A9 0A           F:011209
  STA Workset+Ent_AnimTimer                                      ;  1DDCC DDCC C 85 F3           F:011209
  JSR L_14_1DF37                                  ;  1DDCE DDCE C 20 37 DF        F:011209
  JSR CopyWorksetToData                                  ;  1DDD1 DDD1 C 20 9A E9        F:011209
  LDA #$6                                         ;  1DDD4 DDD4 C A9 06           F:011209
  STA a:PendingSFX                                    ;  1DDD6 DDD6 C 8D 8F 00        F:011209
B_14_1DDD9:
  LDA AreaBlockSwapTo                                      ;  1DDD9 DDD9 C A5 71           F:011209
  AND #$3F                                        ;  1DDDB DDDB C 29 3F           F:011209
  CMP #$30                                        ;  1DDDD DDDD C C9 30           F:011209
  RTS                                             ;  1DDDF DDDF C 60              F:011209

L_14_1DDE0:
  lda Ent9Data+Ent_State                    ; is there a door to unlock?
  bne @Done                                       ; nope - bail!
  STY BlockOffset                                      ;  1DDE5 DDE5 C 84 0B           F:077168
  ldx PlayerSelectedItemSlot                       ; check if the player is using a keystick
  lda PlayerActiveItems,x                         ;
  cmp #ItemType_KeyStick                          ;
  bne :+                                          ; otherwise hop ahead
  jsr UsePlayerMana                               ; they are - attempt to use a magic point
  bcc @OpenDoor                                   ; if we succeeded it's time to open the door
: jsr UsePlayerKey                                ; attempt to use one of the players keys
  bcs @Done                                       ; if not possible, we can't open the door
@OpenDoor:
  lda #$E1                                        ; update entity graphics
  STA Workset+Ent_Gfx                                 ;  1DDFB DDFB C 85 ED           F:021470
  LDA #$1                                         ;  1DDFD DDFD C A9 01           F:021470
  STA Workset+Ent_State                                      ;  1DDFF DDFF C 85 EE           F:021470
  LDA #$1                                         ;  1DE01 DE01 C A9 01           F:021470
  STA Workset+Ent_SprAttr                                      ;  1DE03 DE03 C 85 EF           F:021470
  LDA AreaBlockBreakTo                            ;  1DE05 DE05 C A5 74           F:021470
  STA Workset+Ent_SwapBlock                                      ;  1DE07 DE07 C 85 F0           F:021470
  LDA #$F                                         ;  1DE09 DE09 C A9 0F           F:021470
  STA Workset+Ent_AnimTimer                                      ;  1DE0B DE0B C 85 F3           F:021470
  JSR L_14_1DF37                                  ;  1DE0D DE0D C 20 37 DF        F:021470
  JSR CopyWorksetToData                           ;  1DE10 DE10 C 20 9A E9        F:021470
  LDA #$6                                         ;  1DE13 DE13 C A9 06           F:021470
  STA a:PendingSFX                                    ;  1DE15 DE15 C 8D 8F 00        F:021470
@Done:
  sec                                             ;
  rts                                             ; done!

L_14_1DE1A:
  bit JoypadInput                                 ; check if A button is pressed
  bpl @Done                                       ; if not - do nothing
  lda Ent9Data+Ent_State                          ; check if there is a block to interact with
  bne @Done                                       ; nope - nothing to do
  STY BlockOffset                                      ;  1DE23 DE23 C 84 0B           F:003318
  LDA #$1                                         ;  1DE25 DE25 C A9 01           F:003318
  STA Workset_F4                                  ;  1DE27 DE27 C 85 F4           F:003318
  ldy PlayerSelectedItemSlot                       ; check which item the player is using
  ldx PlayerActiveItems,y                         ;
  dex                                             ;
  dex                                             ; is the player using the mattock?
  beq @UseMattock                                 ; if so - skip to handling code
  dex                                             ; is the player using the glove?
  beq @UseGlove                                   ; if so - skip to handling code
  dex                                             ; is the player using the rod?
  beq @UseRod                                     ; if so - skip to handling code
@Done:
  sec                                             ; mark that we failed to interact
  rts                                             ; and exit

@UseGlove:
  JMP UseGloveOnBlock                             ; jump to glove code

@UseRod:
  JMP UseRodOnBlock                               ; jump to do code

@UseMattock:
  lda PlayerMP                                    ; check if player has magic
  beq SharedSECRTS                                ; if not - fail
  lda PlayerYPx                                   ; check so player is perfectly aligned with a tile
  and #$F                                         ;
  ora PlayerXPx                               ;
  bne SharedSECRTS                                ; if not - fail
  lda JoypadLastAction                            ; get target block based on players held direction
  and #CtlDPad                        ;
  asl a                                           ;
  tax                                             ;
  clc                                             ;
  lda PlayerXTile                                 ; get players x tile position
  adc MattockTileDirections,x                     ; offset for target direction
  sta Ent9Data+Ent_XTile                          ; position smoke puff
  sta PositionToBlock_XTile                       ; and use for block pointer calculation
  lda #$0                                         ;
  sta Ent9Data+Ent_XPx                            ; move smoke puff to 0px offset from tile
  clc                                             ;
  lda PlayerYPx                                   ; get players y pixel
  adc MattockTileDirections+1,X                   ; offset for target direction
  sta Ent9Data+Ent_YPx                            ; position smoke puff
  sta PositionToBlock_YPx                         ; and use for block pointer calculation
  jsr PositionToBlock                             ; find pointer to block
  ldy #$0                                         ; use 0 as offset for fetching the block
  sty BlockOffset                                 ;
  lda (BlockPtrLo),y                              ; get found block
  and #%00111111                                  ; filter out palette bits
  cmp #Tile_BreakBlock                            ; check if it's the breakable block
  bne SharedSECRTS                                ; if not we can't break it!
  lda #GfxTile_SmokePuff                          ; use smoke puff tile
  sta Ent9Data+Ent_Gfx                            ;
  lda #$1                                         ; activate entity
  STA Ent9Data+Ent_State                          ;
  lda #$1                                         ;
  STA Ent9Data+Ent_SprAttr                         ;
  lda #$F                                         ; duration of smoke puff animation
  sta Ent9Data+Ent_AnimTimer                      ;
  jsr GetBlockTypeAfterBreak                      ; get the new block we'll be swapping to
  sta Ent9Data+Ent_SwapBlock                      ; and store it on the smoke puff entity
  jsr UsePlayerMana                               ; consume a point of mana
  lda #SFX_BreakBlock                             ; play mattock sound
  sta a:PendingSFX                                ;
SharedSECRTS:
  sec                                             ;
  RTS                                             ; done!

UseGloveOnBlock:
  LDA JoypadLastAction                                      ;  1DE9F DE9F C A5 FD           F:007625
  AND #$F                                         ;  1DEA1 DEA1 C 29 0F           F:007625
  BEQ B_14_1DEE0                                  ;  1DEA3 DEA3 C F0 3B           F:007625
  LDY #$1                                         ;  1DEA5 DEA5 C A0 01           F:007625
  JSR SetWorksetDirectionSpeed                                  ;  1DEA7 DEA7 C 20 70 CD        F:007625
  LDY #$F8                                        ;  1DEAA DEAA C A0 F8           F:007625
  LDA (AreaBGGfxSet),Y                                  ;  1DEAC DEAC C B1 79           F:007625
  AND #$FE                                        ;  1DEAE DEAE C 29 FE           F:007625
  STA Workset+Ent_Gfx                                      ;  1DEB0 DEB0 C 85 ED           F:007625
  LDA #$1                                         ;  1DEB2 DEB2 C A9 01           F:007625
  STA Workset+Ent_State                                      ;  1DEB4 DEB4 C 85 EE           F:007625
  LDA #$3                                         ;  1DEB6 DEB6 C A9 03           F:007625
  STA Workset+Ent_SprAttr                                      ;  1DEB8 DEB8 C 85 EF           F:007625
  LDY BlockOffset                                      ;  1DEBA DEBA C A4 0B           F:007625
  LDA (BlockPtrLo),Y                                  ;  1DEBC DEBC C B1 0C           F:007625
  STA Workset+Ent_SwapBlock                                      ;  1DEBE DEBE C 85 F0           F:007625
  LDA #$10                                        ;  1DEC0 DEC0 C A9 10           F:007625
  STA Workset+Ent_AnimTimer                                      ;  1DEC2 DEC2 C 85 F3           F:007625
  JSR GetBlockTypeAfterBreak                                  ;  1DEC4 DEC4 C 20 80 DF        F:007625
  STA (BlockPtrLo),Y                                  ;  1DEC7 DEC7 C 91 0C           F:007625
  JSR L_14_1DF37                                  ;  1DEC9 DEC9 C 20 37 DF        F:007625
  JSR L_14_1DF5E                                  ;  1DECC DECC C 20 5E DF        F:007625
  JSR L_15_1F7F7                                  ;  1DECF DECF C 20 F7 F7        F:007626
  LDA #$FF                                        ;  1DED2 DED2 C A9 FF           F:007626
  STA ActiveEntity                                      ;  1DED4 DED4 C 85 E3           F:007626
  LDA Ent9Data+Ent_State                                      ;  1DED6 DED6 C AD 91 04        F:007626
  BEQ B_14_1DEE0                                  ;  1DED9 DED9 C F0 05           F:007626
  LDA #$6                                         ;  1DEDB DEDB C A9 06           F:007626
  STA a:PendingSFX                                    ;  1DEDD DEDD C 8D 8F 00        F:007626
B_14_1DEE0:
  LDA #$0                                         ;  1DEE0 DEE0 C A9 00           F:007626
  STA PlayerYPxSpeed                                      ;  1DEE2 DEE2 C 85 4B           F:007626
  STA PlayerFallHeight                                      ;  1DEE4 DEE4 C 85 4E           F:007626
  SEC                                             ;  1DEE6 DEE6 C 38              F:007626
  RTS                                             ;  1DEE7 DEE7 C 60              F:007626

UseRodOnBlock:
  lda PlayerMP                                    ; do we have mana?
  beq SharedSECRTS                                ; no - bail out
  lda JoypadLastAction                            ; get held direction
  and #CtlDPad                        ;
  beq @Done                                       ; if none - we can't do anything.
  ldy #$8                                         ; set movement speed to 8px
  jsr SetWorksetDirectionSpeed                    ;
  ldy #Tile_BreakBlock*4                          ; get metatile for breakable block
  lda (AreaBGGfxSet),y                            ;
  and #%11111110                                  ; clear bit to get sprite tile
  sta Workset+Ent_Gfx                             ; and use as sprite
  lda #$1                                         ; activate entity
  sta Workset+Ent_State                           ;
  lda #%00000011                                  ;
  sta Workset+Ent_SprAttr                          ;
  ldy BlockOffset                                 ;
  lda (BlockPtrLo),y                              ; get current block type
  sta Workset+Ent_SwapBlock                       ; set this block type as the 'return state' of our sprite
  lda #$0                                         ; clear state
  sta Workset+Ent_AnimTimer                       ;
  jsr GetBlockTypeAfterBreak                      ; get the tile to break the current block into
  sta (BlockPtrLo),y                              ; and write the new value
  JSR L_14_1DF37                                  ;  1DF16 DF16 C 20 37 DF        F:026887
  JSR L_14_1DF5E                                  ;  1DF19 DF19 C 20 5E DF        F:026887
  JSR L_15_1F7F7                                  ;  1DF1C DF1C C 20 F7 F7        F:026888
  lda #$FF                                        ; deselect entity
  sta ActiveEntity                                ;
  lda Workset+Ent_State                           ; did the block immediately halt?
  beq @Done                                       ; yep - don't actually use any mana
  lda #SFX_BreakBlock                             ; play break block sound
  sta a:PendingSFX                                ;
  jsr UsePlayerMana                               ; and use a point of mana
@Done:
  lda #$0                                         ; prevent player from falling
  sta PlayerYPxSpeed                              ;
  sta PlayerFallHeight                            ;
  sec                                             ;
  rts                                             ; done!

L_14_1DF37:
  LDA BlockOffset                                      ;  1DF37 DF37 C A5 0B           F:007625
  CMP #$C                                         ;  1DF39 DF39 C C9 0C           F:007625
  BCC B_14_1DF41                                  ;  1DF3B DF3B C 90 04           F:007625
  SBC #$C                                         ;  1DF3D DF3D C E9 0C           F:036381
  INC TmpF                                      ;  1DF3F DF3F C E6 0F           F:036381
B_14_1DF41:
  TAY                                             ;  1DF41 DF41 C A8              F:007625
  BEQ B_14_1DF4B                                  ;  1DF42 DF42 C F0 07           F:007625
  LDA TmpA                                      ;  1DF44 DF44 C A5 0A           F:007663
  CLC                                             ;  1DF46 DF46 C 18              F:007663
  ADC #$10                                        ;  1DF47 DF47 C 69 10           F:007663
  STA TmpA                                      ;  1DF49 DF49 C 85 0A           F:007663
B_14_1DF4B:
  LDA TmpA                                      ;  1DF4B DF4B C A5 0A           F:007625
  AND #$F0                                        ;  1DF4D DF4D C 29 F0           F:007625
  STA Workset+Ent_YPx                                      ;  1DF4F DF4F C 85 FB           F:007625
  LDA #$0                                         ;  1DF51 DF51 C A9 00           F:007625
  STA Workset_FC                                      ;  1DF53 DF53 C 85 FC           F:007625
  LDA TmpF                                      ;  1DF55 DF55 C A5 0F           F:007625
  STA Workset+Ent_XTile                                      ;  1DF57 DF57 C 85 FA           F:007625
  LDA #$0                                         ;  1DF59 DF59 C A9 00           F:007625
  STA Workset+Ent_XPx                                      ;  1DF5B DF5B C 85 F9           F:007625
  RTS                                             ;  1DF5D DF5D C 60              F:007625

L_14_1DF5E:
  LDA Workset+Ent_XTile                                      ;  1DF5E DF5E C A5 FA           F:007625
  STA BlockPtrLo                                      ;  1DF60 DF60 C 85 0C           F:007625
  ASL                                             ;  1DF62 DF62 C 0A              F:007625
  AND #$1F                                        ;  1DF63 DF63 C 29 1F           F:007625
  STA PPUUpdateAddrLo                                      ;  1DF65 DF65 C 85 16           F:007625
  LDA Workset+Ent_XTile                                      ;  1DF67 DF67 C A5 FA           F:007625
  AND #$10                                        ;  1DF69 DF69 C 29 10           F:007625
  LSR                                             ;  1DF6B DF6B C 4A              F:007625
  LSR                                             ;  1DF6C DF6C C 4A              F:007625
  STA PPUUpdateAddrHi                                      ;  1DF6D DF6D C 85 17           F:007625
  CLC                                             ;  1DF6F DF6F C 18              F:007625
  LDA #$0                                         ;  1DF70 DF70 C A9 00           F:007625
  ADC PPUUpdateAddrLo                                      ;  1DF72 DF72 C 65 16           F:007625
  STA PPUUpdateAddrLo                                      ;  1DF74 DF74 C 85 16           F:007625
  LDA #$20                                        ;  1DF76 DF76 C A9 20           F:007625
  ADC PPUUpdateAddrHi                                      ;  1DF78 DF78 C 65 17           F:007625
  STA PPUUpdateAddrHi                                      ;  1DF7A DF7A C 85 17           F:007625
  JSR BankAndDrawMetatileColumn                                  ;  1DF7C DF7C C 20 33 C8        F:007625
  RTS                                             ;  1DF7F DF7F C 60              F:007626

GetBlockTypeAfterBreak:
  ldy BlockOffset                           ; get block at lookup offset
  lda (BlockPtr2Lo),y                        ;
  and #%00111111                                  ; clear palette bits
  tax                                             ;
  lda AreaBlockBreakTo                            ; get the tile we will be breaking this tile into
  cpx #Tile_BreakBlock                            ; is our target the breakable block?
  beq :+                                          ; if so - return the replacement block
  lda (BlockPtr2Lo),y                        ; otherwise return the current block
: rts                                             ; done!

L_14_1DF90:
  LDA PlayerMovingDirection                                      ;  1DF90 DF90 C A5 49           F:001384
  PHP                                             ;  1DF92 DF92 C 08              F:001384
  LDA #$0                                         ;  1DF93 DF93 C A9 00           F:001384
  STA PlayerMovingDirection                                      ;  1DF95 DF95 C 85 49           F:001384
  STA PlayerFacingDirection                                      ;  1DF97 DF97 C 85 4A           F:001384
  PLP                                             ;  1DF99 DF99 C 28              F:001384
  BEQ B_14_1DFCF                                  ;  1DF9A DF9A C F0 33           F:001384
  LDA PlayerYPx                                      ;  1DF9C DF9C C A5 45           F:001763
  AND #$F                                         ;  1DF9E DF9E C 29 0F           F:001763
  BEQ B_15_1E00D                                  ;  1DFA0 DFA0 C F0 6B           F:001763
  CMP #$6                                         ;  1DFA2 DFA2 C C9 06           F:005376
  BCC B_14_1DFBE                                  ;  1DFA4 DFA4 C 90 18           F:005376
  CMP #$B                                         ;  1DFA6 DFA6 C C9 0B           F:007543
  BCS B_14_1DFAD                                  ;  1DFA8 DFA8 C B0 03           F:007543
  JMP B_15_1E00D                                  ;  1DFAA DFAA C 4C 0D E0        F:042308

B_14_1DFAD:
  lda JoypadInput                                      ;  1DFAD DFAD C A5 20           F:007543
  and #%00001000                                         ;  1DFAF DFAF C 29 08           F:007543
  BNE B_15_1E00D                                  ;  1DFB1 DFB1 C D0 5A           F:007543
  LDA #$1                                         ;  1DFB3 DFB3 C A9 01           F:007543
  STA PlayerYPxSpeed                                      ;  1DFB5 DFB5 C 85 4B           F:007543
  LDA #$0                                         ;  1DFB7 DFB7 C A9 00           F:007543
  STA PlayerXPxSpeed                                      ;  1DFB9 DFB9 C 85 4C           F:007543
  JMP L_15_1E009                                  ;  1DFBB DFBB C 4C 09 E0        F:007543

B_14_1DFBE:
  LDA JoypadInput                                      ;  1DFBE DFBE C A5 20           F:005376
  AND #$4                                         ;  1DFC0 DFC0 C 29 04           F:005376
  BNE B_15_1E00D                                  ;  1DFC2 DFC2 C D0 49           F:005376
  LDA #$FF                                        ;  1DFC4 DFC4 C A9 FF           F:005376
  STA PlayerYPxSpeed                                      ;  1DFC6 DFC6 C 85 4B           F:005376
  LDA #$FF                                        ;  1DFC8 DFC8 C A9 FF           F:005376
  STA PlayerXPxSpeed                                      ;  1DFCA DFCA C 85 4C           F:005376
  JMP L_15_1E009                                  ;  1DFCC DFCC C 4C 09 E0        F:005376

B_14_1DFCF:
  LDA PlayerYPxSpeed                                      ;  1DFCF DFCF C A5 4B           F:001384
  PHP                                             ;  1DFD1 DFD1 C 08              F:001384
  LDA #$0                                         ;  1DFD2 DFD2 C A9 00           F:001384
  STA PlayerYPxSpeed                                      ;  1DFD4 DFD4 C 85 4B           F:001384
  STA PlayerXPxSpeed                                      ;  1DFD6 DFD6 C 85 4C           F:001384
  PLP                                             ;  1DFD8 DFD8 C 28              F:001384
  BEQ B_15_1E00D                                  ;  1DFD9 DFD9 C F0 32           F:001384
  LDA PlayerXPx                                      ;  1DFDB DFDB C A5 43           F:001384
  BEQ B_15_1E00D                                  ;  1DFDD DFDD C F0 2E           F:001384
  CMP #$6                                         ;  1DFDF DFDF C C9 06           F:001384
  BCC B_14_1DFFB                                  ;  1DFE1 DFE1 C 90 18           F:001384
  CMP #$B                                         ;  1DFE3 DFE3 C C9 0B           F:001509
  BCS B_14_1DFEA                                  ;  1DFE5 DFE5 C B0 03           F:001509
  JMP B_15_1E00D                                  ;  1DFE7 DFE7 C 4C 0D E0        F:001509

B_14_1DFEA:
  LDA JoypadInput                                      ;  1DFEA DFEA C A5 20           F:011200
  AND #$2                                         ;  1DFEC DFEC C 29 02           F:011200
  BNE B_15_1E00D                                  ;  1DFEE DFEE C D0 1D           F:011200
  LDA #$1                                         ;  1DFF0 DFF0 C A9 01           F:013070
  STA PlayerMovingDirection                                      ;  1DFF2 DFF2 C 85 49           F:013070
  LDA #$0                                         ;  1DFF4 DFF4 C A9 00           F:013070
  STA PlayerFacingDirection                                      ;  1DFF6 DFF6 C 85 4A           F:013070
  JMP L_15_1E009                                  ;  1DFF8 DFF8 C 4C 09 E0        F:013070

B_14_1DFFB:
  LDA JoypadInput                                      ;  1DFFB DFFB C A5 20           F:001384
  AND #$1                                         ;  1DFFD DFFD C 29 01           F:001384
.byte $D0                                         ;  1DFFF DFFF .        ?        
L_15_1E000:
  .byte $0C,$A9,$0F                               ;  1E000 E000 C 0C A9 0F        F:000000
  STA PlayerMovingDirection                                      ;  1E003 E003 C 85 49           F:001384
  LDA #$FF                                        ;  1E005 E005 C A9 FF           F:001384
  STA PlayerFacingDirection                                      ;  1E007 E007 C 85 4A           F:001384
L_15_1E009:
  JSR L_14_1D991                                  ;  1E009 E009 C 20 91 D9        F:001384
  RTS                                             ;  1E00C E00C C 60              F:001384

B_15_1E00D:
  SEC                                             ;  1E00D E00D C 38              F:001389
  RTS                                             ;  1E00E E00E C 60              F:001389

RunPauseMenu:
  lda #SFX_PauseMenu                              ;
  sta PendingSFX                                  ;
  INC R_008D                                      ;  1E013 E013 C E6 8D           F:024130
  lda SelectedBank3                               ; use enemy gfx to determine if we are in a boss encounter
  cmp #$30                                        ;
  bcs @HandleBossPause                            ; if we are - go to a non-pause screen pause
  jsr PutPlayerLocationOnStack                    ; store the players location when entering the pause menu
  lda #$8                                         ;  1E01E E01E C A9 08           F:024130
  JSR L_15_1E660                                  ;  1E020 E020 C 20 60 E6        F:024130
  JSR PauseMenu_DrawActiveItems                                  ;  1E023 E023 C 20 B7 E6        F:024152
  JSR PauseMenu_DrawInventory                                  ;  1E026 E026 C 20 30 CF        F:024152
  JSR PauseMenu_DrawCharacterAttributes                                  ;  1E029 E029 C 20 82 CF        F:024168
  LDA #$8                                         ;  1E02C E02C C A9 08           F:024171
  STA CameraXPx                                      ;  1E02E E02E C 85 7B           F:024171
  JSR UpdateCameraPPUScroll                                  ;  1E030 E030 C 20 C7 C1        F:024171
  JSR UpdatePlayerSprites                                  ;  1E033 E033 C 20 D8 C1        F:024171
  JSR FadeInAreaPalette                                  ;  1E036 E036 C 20 92 C4        F:024171
@HandleBossPause:
  JSR ReadJoypad                                  ;  1E039 E039 C 20 43 CC        F:024197
  BNE @HandleBossPause                                  ;  1E03C E03C C D0 FB           F:024197
B_15_1E03E:
  JSR ReadJoypad                                  ;  1E03E E03E C 20 43 CC        F:024197
  AND #$10                                        ;  1E041 E041 C 29 10           F:024197
  BEQ B_15_1E03E                                  ;  1E043 E043 C F0 F9           F:024197
B_15_1E045:
  JSR ReadJoypad                                  ;  1E045 E045 C 20 43 CC        F:024221
  BNE B_15_1E045                                  ;  1E048 E048 C D0 FB           F:024221
  LDA #$4                                         ;  1E04A E04A C A9 04           F:024227
  STA PendingSFX                                      ;  1E04C E04C C 85 8F           F:024227
  LDA SelectedBank3                                      ;  1E04E E04E C A5 2D           F:024227
  CMP #$30                                        ;  1E050 E050 C C9 30           F:024227
  BCS B_15_1E074                                  ;  1E052 E052 C B0 20           F:024227
  JSR RestorePlayerLocationFromStack                                  ;  1E054 E054 C 20 42 E6        F:024227
  JSR L_14_1C3E5                                  ;  1E057 E057 C 20 E5 C3        F:024227
  JSR L_15_1E79D                                  ;  1E05A E05A C 20 9D E7        F:024247
  LDA Workset_FE                                      ;  1E05D E05D C A5 FE           F:024247
  JSR ChangeMusicIfNeeded                                  ;  1E05F E05F C 20 2E D0        F:024247
  JSR ReloadAreaConfig                                  ;  1E062 E062 C 20 FF C8        F:024247
  JSR DrawLeftAreaDataColumn                                  ;  1E065 E065 C 20 CB C5        F:024248
  JSR UpdatePlayerSprites                                  ;  1E068 E068 C 20 D8 C1        F:024249
  JSR UpdateEntitySprites                                  ;  1E06B E06B C 20 B1 C2        F:024249
  JSR UpdateCameraPPUScroll                                  ;  1E06E E06E C 20 C7 C1        F:024249
  JSR FadeInAreaPalette                                  ;  1E071 E071 C 20 92 C4        F:024249
B_15_1E074:
  DEC R_008D                                      ;  1E074 E074 C C6 8D           F:024275
  RTS                                             ;  1E076 E076 C 60              F:024275

EnterInnDoor:
  lda CurrentAreaY                                  ; is the player at the map depth with the home in it?
  cmp #$10                                          ;
  bne :+                                            ; if not - skip ahead
  jmp EnterHomeDoor                                 ; otherwise load up the home area
: JSR PutPlayerLocationOnStack                                  ;  1E080 E080 C 20 20 E6        F:009106
  LDA #$4                                         ;  1E083 E083 C A9 04           F:009106
  JSR L_15_1E660                                  ;  1E085 E085 C 20 60 E6        F:009106
  JSR UpdateInnSprites                                  ;  1E088 E088 C 20 78 E7        F:009128
  JSR FadeInAreaPalette                                  ;  1E08B E08B C 20 92 C4        F:009128
L_15_1E08E:
  JSR L_15_1E514                                  ;  1E08E E08E C 20 14 E5        F:009154
  BCC B_15_1E096                                  ;  1E091 E091 C 90 03           F:009155
  JMP L_15_1E5FD                                  ;  1E093 E093 C 4C FD E5        F:009155

B_15_1E096:
  LDA PlayerGold                                      ;  1E096 E096 C A5 5A           F:041168
  CMP #$A                                         ;  1E098 E098 C C9 0A           F:041168
  BCS B_15_1E0A3                                  ;  1E09A E09A C B0 07           F:041168
  LDA #$6                                         ;  1E09C E09C C A9 06           F:047750
  STA PendingSFX                                      ;  1E09E E09E C 85 8F           F:047750
  JMP L_15_1E08E                                  ;  1E0A0 E0A0 C 4C 8E E0        F:047750

B_15_1E0A3:
  LDX #$A                                         ;  1E0A3 E0A3 C A2 0A           F:041168
B_15_1E0A5:
  TXA                                             ;  1E0A5 E0A5 C 8A              F:041168
  PHA                                             ;  1E0A6 E0A6 C 48              F:041168
  DEC PlayerGold                                      ;  1E0A7 E0A7 C C6 5A           F:041168
  JSR UpdateGoldDisplay                                  ;  1E0A9 E0A9 C 20 F8 CA        F:041168
  LDA #$C                                         ;  1E0AC E0AC C A9 0C           F:041168
  STA PendingSFX                                      ;  1E0AE E0AE C 85 8F           F:041168
  LDA #$A                                         ;  1E0B0 E0B0 C A9 0A           F:041168
  STA FrameCountdownTimer                                      ;  1E0B2 E0B2 C 85 36           F:041168
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  PLA                                             ;  1E0B7 E0B7 C 68              F:041178
  TAX                                             ;  1E0B8 E0B8 C AA              F:041178
  DEX                                             ;  1E0B9 E0B9 C CA              F:041178
  BNE B_15_1E0A5                                  ;  1E0BA E0BA C D0 E9           F:041178
  JSR L_14_1C430                                  ;  1E0BC E0BC C 20 30 C4        F:041268
  JSR RefillPlayerHP                                  ;  1E0BF E0BF C 20 6A D1        F:041288
  JSR RefillPlayerMana                                  ;  1E0C2 E0C2 C 20 99 D1        F:041334
  LDA #$8                                         ;  1E0C5 E0C5 C A9 08           F:041476
  JSR L_15_1E667                                  ;  1E0C7 E0C7 C 20 67 E6        F:041476
  JSR PauseMenu_DrawActiveItems                                  ;  1E0CA E0CA C 20 B7 E6        F:041497
  JSR PauseMenu_DrawInventory                                  ;  1E0CD E0CD C 20 30 CF        F:041497
  JSR PauseMenu_DrawCharacterAttributes                                  ;  1E0D0 E0D0 C 20 82 CF        F:041513
  LDA #$8                                         ;  1E0D3 E0D3 C A9 08           F:041516
  STA CameraXPx                                      ;  1E0D5 E0D5 C 85 7B           F:041516
  JSR UpdateCameraPPUScroll                                  ;  1E0D7 E0D7 C 20 C7 C1        F:041516
  JSR UpdatePlayerSprites                                  ;  1E0DA E0DA C 20 D8 C1        F:041516
  JSR FadeInAreaPalette                                  ;  1E0DD E0DD C 20 92 C4        F:041516
  JSR RunPlayerControlInventory                                  ;  1E0E0 E0E0 C 20 AA E4        F:041542
  LDA #$4                                         ;  1E0E3 E0E3 C A9 04           F:041668
  JSR L_15_1E667                                  ;  1E0E5 E0E5 C 20 67 E6        F:041668
  JSR L_15_1E79D                                  ;  1E0E8 E0E8 C 20 9D E7        F:041689
  JSR UpdateInnSprites                                  ;  1E0EB E0EB C 20 78 E7        F:041689
  JSR FadeInAreaPalette                                  ;  1E0EE E0EE C 20 92 C4        F:041689
  JMP L_15_1E08E                                  ;  1E0F1 E0F1 C 4C 8E E0        F:041715

EnterHomeDoor:
  LDA #$0                                         ;  1E0F4 E0F4 C A9 00           F:000172
  STA PlayerHP                                      ;  1E0F6 E0F6 C 85 58           F:000172
  STA PlayerMP                                      ;  1E0F8 E0F8 C 85 59           F:000172
  LDA PlayerCharacter                                      ;  1E0FA E0FA C A5 40           F:000172
  CMP #$6                                         ;  1E0FC E0FC C C9 06           F:000172
  BCS B_15_1E112                                  ;  1E0FE E0FE C B0 12           F:000172
  LDY #$2                                         ;  1E100 E100 . A0 02           
B_15_1E102:
  LDX PlayerActiveItems,Y                                    ;  1E102 E102 . B6 51           
  BMI B_15_1E108                                  ;  1E104 E104 . 30 02           
  INC PlayerInventory,X                                    ;  1E106 E106 . F6 60           
B_15_1E108:
  LDX #$FF                                        ;  1E108 E108 . A2 FF           
  STX PlayerActiveItems,Y                                    ;  1E10A E10A . 96 51           
  DEY                                             ;  1E10C E10C . 88              
  BPL B_15_1E102                                  ;  1E10D E10D . 10 F3           
  JSR $D0A5                                       ;  1E10F E10F . 20 A5 D0        
B_15_1E112:
  JSR PutPlayerLocationOnStack                                  ;  1E112 E112 C 20 20 E6        F:000172
  LDA #$6                                         ;  1E115 E115 C A9 06           F:000172
  STA PlayerCharacter                                      ;  1E117 E117 C 85 40           F:000172
  LDA #$6                                         ;  1E119 E119 C A9 06           F:000172
  JSR L_15_1E660                                  ;  1E11B E11B C 20 60 E6        F:000172
  JSR UpdateHPDisplay                                  ;  1E11E E11E C 20 B6 CA        F:000193
  JSR UpdateMPDisplay                                  ;  1E121 E121 C 20 CC CA        F:000193
  LDA #$3                                         ;  1E124 E124 C A9 03           F:000193
  STA PlayerSelectedItemSlot                                      ;  1E126 E126 C 85 55           F:000193
  JSR UpdateInventorySprites                                  ;  1E128 E128 C 20 34 C2        F:000193
  LDA #$F1                                        ;  1E12B E12B C A9 F1           F:000193
  STA PlayerSpriteTile                                      ;  1E12D E12D C 85 56           F:000193
  LDA #$0                                         ;  1E12F E12F C A9 00           F:000193
  STA PlayerSpriteAttr                                      ;  1E131 E131 C 85 57           F:000193
  JSR UpdatePlayerSprites                                  ;  1E133 E133 C 20 D8 C1        F:000193
  JSR SetupHomeSprites                                  ;  1E136 E136 C 20 B2 E7        F:000193
  JSR DisableAllEntities                                  ;  1E139 E139 C 20 8A D0        F:000193
  JSR FadeInAreaPalette                                  ;  1E13C E13C C 20 92 C4        F:000193
B_15_1E13F:
  JSR L_15_1E5B4                                  ;  1E13F E13F C 20 B4 E5        F:000219
  LDA TmpA                                      ;  1E142 E142 C A5 0A           F:000314
  AND #$F0                                        ;  1E144 E144 C 29 F0           F:000314
  CMP #$50                                        ;  1E146 E146 C C9 50           F:000314
  BNE B_15_1E186                                  ;  1E148 E148 C D0 3C           F:000314
  LDA TmpF                                      ;  1E14A E14A . A5 0F           
  AND #$F                                         ;  1E14C E14C . 29 0F           
  CMP #$5                                         ;  1E14E E14E . C9 05           
  BNE B_15_1E13F                                  ;  1E150 E150 . D0 ED           
  LDA CheatsEnabled                                      ;  1E152 E152 . A5 37           
  BEQ B_15_1E13F                                  ;  1E154 E154 . F0 E9           
  LDX CurrentMusic                                      ;  1E156 E156 . A6 8E           
  INX                                             ;  1E158 E158 . E8              
  CPX #$10                                        ;  1E159 E159 . E0 10           
  BCC B_15_1E15F                                  ;  1E15B E15B . 90 02           
  LDX #$0                                         ;  1E15D E15D . A2 00           
B_15_1E15F:
  STX CurrentMusic                                      ;  1E15F E15F . 86 8E           
  JSR $FC08                                       ;  1E161 E161 . 20 08 FC        
  LDA CheatsEnabled                                      ;  1E164 E164 . A5 37           
  BPL B_15_1E13F                                  ;  1E166 E166 . 10 D7           
  LDA JoypadInput                                      ;  1E168 E168 . A5 20           
  CMP #$C3                                        ;  1E16A E16A . C9 C3           
  BNE B_15_1E13F                                  ;  1E16C E16C . D0 D1           
  ldx #$D                                         ; give 16 of each inventory item, except crowns and dragon slayers
  lda #$10                                        ;
: sta PlayerInventory,x                           ; update each item
  dex                                             ;
  bpl :-                                          ;
  lda #$80                                        ;
  sta CheatsEnabled                           ;  1E179 E179 . 85 37           
  sta PlayerGold                                  ;  1E17B E17B . 85 5A           
  sta PlayerKeys                                  ;  1E17D E17D . 85 5B           
  lda #$1A                                        ;  1E17F E17F . A9 1A           
  sta PendingSFX                                      ;  1E181 E181 . 85 8F           
  JMP $E13F                                       ;  1E183 E183 . 4C 3F E1        

B_15_1E186:
  LDX #$0                                         ;  1E186 E186 C A2 00           F:000314
  CMP #$70                                        ;  1E188 E188 C C9 70           F:000314
  BEQ B_15_1E1A8                                  ;  1E18A E18A C F0 1C           F:000314
  LDX #$2                                         ;  1E18C E18C C A2 02           F:000314
  CMP #$80                                        ;  1E18E E18E C C9 80           F:000314
  BEQ B_15_1E1B8                                  ;  1E190 E190 C F0 26           F:000314
  CMP #$90                                        ;  1E192 E192 C C9 90           F:000611
  BNE B_15_1E13F                                  ;  1E194 E194 C D0 A9           F:000611
  LDX #$3                                         ;  1E196 E196 C A2 03           F:000611
  LDA TmpF                                      ;  1E198 E198 C A5 0F           F:000611
  AND #$F                                         ;  1E19A E19A C 29 0F           F:000611
  CMP #$6                                         ;  1E19C E19C C C9 06           F:000611
  BEQ B_15_1E1DC                                  ;  1E19E E19E C F0 3C           F:000611
  INX                                             ;  1E1A0 E1A0 C E8              F:000611
  CMP #$A                                         ;  1E1A1 E1A1 C C9 0A           F:000611
  BEQ B_15_1E1DC                                  ;  1E1A3 E1A3 C F0 37           F:000611
  JMP $E13F                                       ;  1E1A5 E1A5 . 4C 3F E1        

B_15_1E1A8:
  LDA TmpF                                      ;  1E1A8 E1A8 . A5 0F           
  AND #$F                                         ;  1E1AA E1AA . 29 0F           
  CMP #$6                                         ;  1E1AC E1AC . C9 06           
  BEQ B_15_1E1DC                                  ;  1E1AE E1AE . F0 2C           
  INX                                             ;  1E1B0 E1B0 . E8              
  CMP #$8                                         ;  1E1B1 E1B1 . C9 08           
  BEQ B_15_1E1DC                                  ;  1E1B3 E1B3 . F0 27           
  JMP $E13F                                       ;  1E1B5 E1B5 . 4C 3F E1        

B_15_1E1B8:
  LDA TmpF                                      ;  1E1B8 E1B8 C A5 0F           F:000314
  AND #$F                                         ;  1E1BA E1BA C 29 0F           F:000314
  CMP #$4                                         ;  1E1BC E1BC C C9 04           F:000314
  BEQ B_15_1E1DC                                  ;  1E1BE E1BE C F0 1C           F:000314
  CMP #$A                                         ;  1E1C0 E1C0 C C9 0A           F:000314
  BNE @CheckIfSelectingGrandpa                                  ;  1E1C2 E1C2 C D0 0A           F:000314
  LDA #$3                                         ;  1E1C4 E1C4 C A9 03           F:000437
  STA PendingSFX                                      ;  1E1C6 E1C6 C 85 8F           F:000437
  JSR L_15_1E27D                                  ;  1E1C8 E1C8 C 20 7D E2        F:000437
  JMP B_15_1E13F                                  ;  1E1CB E1CB C 4C 3F E1        F:000499

@CheckIfSelectingGrandpa:
  cmp #$C                                         ; check if hovering over grandpa in X
  bne @NoneSelected                               ; nope - skip ahead
  lda #$3                                         ; yes - go to password input
  sta PendingSFX                                      ;
  jsr RunPasswordInputScreen                      ;
@NoneSelected:
  JMP B_15_1E13F                                  ;  1E1D9 E1D9 C 4C 3F E1        F:000373

B_15_1E1DC:
  STX PlayerCharacter                                      ;  1E1DC E1DC C 86 40           F:000611
  TXA                                             ;  1E1DE E1DE C 8A              F:000611
  ASL                                             ;  1E1DF E1DF C 0A              F:000611
  ASL                                             ;  1E1E0 E1E0 C 0A              F:000611
  CLC                                             ;  1E1E1 E1E1 C 18              F:000611
  ADC #$3                                         ;  1E1E2 E1E2 C 69 03           F:000611
  TAY                                             ;  1E1E4 E1E4 C A8              F:000611
  LDX #$3                                         ;  1E1E5 E1E5 C A2 03           F:000611
B_15_1E1E7:
  LDA CharacterAttributeData,Y                                ;  1E1E7 E1E7 C B9 A7 FF        F:000611
  STA PlayerAttributes,X                                    ;  1E1EA E1EA C 95 5C           F:000611
  DEY                                             ;  1E1EC E1EC C 88              F:000611
  DEX                                             ;  1E1ED E1ED C CA              F:000611
  BPL B_15_1E1E7                                  ;  1E1EE E1EE C 10 F7           F:000611
  LDA #$18                                        ;  1E1F0 E1F0 C A9 18           F:000611
  STA PendingSFX                                      ;  1E1F2 E1F2 C 85 8F           F:000611
  LDA #$FF                                        ;  1E1F4 E1F4 C A9 FF           F:000611
  STA R_0090                                      ;  1E1F6 E1F6 C 85 90           F:000611
  LDA #$4                                         ;  1E1F8 E1F8 C A9 04           F:000611
  STA FrameCountdownTimer                                      ;  1E1FA E1FA C 85 36           F:000611
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  LDX #$5                                         ;  1E1FF E1FF C A2 05           F:000615
  JSR LightningFlashScreen                                  ;  1E201 E201 C 20 40 C5        F:000615
  LDA PlayerCharacter                                      ;  1E204 E204 C A5 40           F:000640
  CLC                                             ;  1E206 E206 C 18              F:000640
  ADC #$38                                        ;  1E207 E207 C 69 38           F:000640
  STA SelectedBank2                                      ;  1E209 E209 C 85 2C           F:000640
  LDA #$3D                                        ;  1E20B E20B C A9 3D           F:000640
  STA SelectedBank3                                      ;  1E20D E20D C 85 2D           F:000640
  LDA #$3E                                        ;  1E20F E20F C A9 3E           F:000640
  STA SelectedBank4                                      ;  1E211 E211 C 85 2E           F:000640
  LDA #$3F                                        ;  1E213 E213 C A9 3F           F:000640
  STA SelectedBank5                                      ;  1E215 E215 C 85 2F           F:000640
  LDA #$D                                         ;  1E217 E217 C A9 0D           F:000640
  STA PlayerSpriteTile                                      ;  1E219 E219 C 85 56           F:000640
  LDA #$0                                         ;  1E21B E21B C A9 00           F:000640
  STA PlayerSpriteAttr                                      ;  1E21D E21D C 85 57           F:000640
  LDA PlayerYPx                                      ;  1E21F E21F C A5 45           F:000640
  AND #$F0                                        ;  1E221 E221 C 29 F0           F:000640
  STA PlayerYPx                                      ;  1E223 E223 C 85 45           F:000640
  LDA #$4                                         ;  1E225 E225 C A9 04           F:000640
  STA PlayerXPx                                      ;  1E227 E227 C 85 43           F:000640
  JSR ClearEntitySprites                                  ;  1E229 E229 C 20 7C D0        F:000640
  JSR UpdatePlayerSprites                                  ;  1E22C E22C C 20 D8 C1        F:000640
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  LDX #$5                                         ;  1E232 E232 C A2 05           F:000640
  JSR LightningFlashScreen                                  ;  1E234 E234 C 20 40 C5        F:000640
  LDA #$78                                        ;  1E237 E237 C A9 78           F:000665
  STA FrameCountdownTimer                                      ;  1E239 E239 C 85 36           F:000665
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  JSR L_14_1C3E5                                  ;  1E23E E23E C 20 E5 C3        F:000785
  LDA #$8                                         ;  1E241 E241 C A9 08           F:000805
  STA PlayerSpriteTile                                      ;  1E243 E243 C 85 56           F:000805
  LDA #$0                                         ;  1E245 E245 C A9 00           F:000805
  STA PlayerSpriteAttr                                      ;  1E247 E247 C 85 57           F:000805
  LDA #$63                                        ;  1E249 E249 C A9 63           F:000805
  STA PlayerHP                                      ;  1E24B E24B C 85 58           F:000805
  STA PlayerMP                                      ;  1E24D E24D C 85 59           F:000805
  JSR UpdateHPDisplay                                  ;  1E24F E24F C 20 B6 CA        F:000805
  JSR UpdateMPDisplay                                  ;  1E252 E252 C 20 CC CA        F:000805
  LDA #$2                                         ;  1E255 E255 C A9 02           F:000805
  STA PlayerSelectedItemSlot                                      ;  1E257 E257 C 85 55           F:000805
  JSR UpdateInventorySprites                                  ;  1E259 E259 C 20 34 C2        F:000805
  LDA #$8                                         ;  1E25C E25C C A9 08           F:000805
  JSR L_15_1E660                                  ;  1E25E E25E C 20 60 E6        F:000805
  JSR PauseMenu_DrawActiveItems                                  ;  1E261 E261 C 20 B7 E6        F:000826
  JSR PauseMenu_DrawInventory                                  ;  1E264 E264 C 20 30 CF        F:000826
  JSR PauseMenu_DrawCharacterAttributes                                  ;  1E267 E267 C 20 82 CF        F:000842
  LDA #$8                                         ;  1E26A E26A C A9 08           F:000845
  STA CameraXPx                                      ;  1E26C E26C C 85 7B           F:000845
  JSR UpdateCameraPPUScroll                                  ;  1E26E E26E C 20 C7 C1        F:000845
  JSR UpdatePlayerSprites                                  ;  1E271 E271 C 20 D8 C1        F:000845
  JSR FadeInAreaPalette                                  ;  1E274 E274 C 20 92 C4        F:000845
  JSR RunPlayerControlInventory                                  ;  1E277 E277 C 20 AA E4        F:000871
  JMP L_15_1E5FD                                  ;  1E27A E27A C 4C FD E5        F:000915

L_15_1E27D:
  LDA #$10                                        ;  1E27D E27D C A9 10           F:000437
  STA CameraXTile                                      ;  1E27F E27F C 85 7C           F:000437
  JSR L_14_1C7B5                                  ;  1E281 E281 C 20 B5 C7        F:000437
  JSR UpdateCameraPPUScroll                                  ;  1E284 E284 C 20 C7 C1        F:000453
  LDA #$D4                                        ;  1E287 E287 C A9 D4           F:000453
  STA TmpE                                      ;  1E289 E289 C 85 0E           F:000453
  LDA #$B4                                        ;  1E28B E28B C A9 B4           F:000453
  STA TmpF                                      ;  1E28D E28D C 85 0F           F:000453
  JSR BankCallMenu                                  ;  1E28F E28F C 20 9C CC        F:000453
  JSR L_14_1D0E5                                  ;  1E292 E292 C 20 E5 D0        F:000453
B_15_1E295:
  JSR ReadJoypad                                  ;  1E295 E295 C 20 43 CC        F:000455
  BNE B_15_1E295                                  ;  1E298 E298 C D0 FB           F:000455
B_15_1E29A:
  JSR ReadJoypad                                  ;  1E29A E29A C 20 43 CC        F:000455
  BEQ B_15_1E29A                                  ;  1E29D E29D C F0 FB           F:000455
  LDA #$20                                        ;  1E29F E29F C A9 20           F:000512
  STA CameraXTile                                      ;  1E2A1 E2A1 C 85 7C           F:000512
  JSR L_14_1C7B5                                  ;  1E2A3 E2A3 C 20 B5 C7        F:000512
  JSR UpdateCameraPPUScroll                                  ;  1E2A6 E2A6 C 20 C7 C1        F:000499
  RTS                                             ;  1E2A9 E2A9 C 60              F:000499

RunPasswordInputScreen:
  LDA #$30                                        ;  1E2AA E2AA C A9 30           F:000314
  STA CameraXTile                                      ;  1E2AC E2AC C 85 7C           F:000314
  JSR L_14_1C7B5                                  ;  1E2AE E2AE C 20 B5 C7        F:000314
  JSR L_14_1D15F                                  ;  1E2B1 E2B1 C 20 5F D1        F:000330
  JSR L_14_1D0E5                                  ;  1E2B4 E2B4 C 20 E5 D0        F:000330
  JSR UpdateCameraPPUScroll                                  ;  1E2B7 E2B7 C 20 C7 C1        F:000332
B_15_1E2BA:
  JSR ReadJoypad                                  ;  1E2BA E2BA C 20 43 CC        F:000332
  BNE B_15_1E2BA                                  ;  1E2BD E2BD C D0 FB           F:000332
  LDA #$0                                         ;  1E2BF E2BF C A9 00           F:000332
  STA Workset+Ent_XPx                                      ;  1E2C1 E2C1 C 85 F9           F:000332
  STA Workset+Ent_XPxSpeed                                      ;  1E2C3 E2C3 C 85 F5           F:000332
  STA Workset+Ent_YPxSpeed                                      ;  1E2C5 E2C5 C 85 F7           F:000332
  LDA #$F5                                        ;  1E2C7 E2C7 C A9 F5           F:000332
  STA R_0281                                      ;  1E2C9 E2C9 C 8D 81 02        F:000332
  STA R_0291                                      ;  1E2CC E2CC C 8D 91 02        F:000332
  LDA #$F7                                        ;  1E2CF E2CF C A9 F7           F:000332
  STA R_0285                                      ;  1E2D1 E2D1 C 8D 85 02        F:000332
  STA R_0295                                      ;  1E2D4 E2D4 C 8D 95 02        F:000332
  LDA #$0                                         ;  1E2D7 E2D7 C A9 00           F:000332
  STA R_0282                                      ;  1E2D9 E2D9 C 8D 82 02        F:000332
  STA R_0286                                      ;  1E2DC E2DC C 8D 86 02        F:000332
  STA R_0292                                      ;  1E2DF E2DF C 8D 92 02        F:000332
  STA R_0296                                      ;  1E2E2 E2E2 C 8D 96 02        F:000332
  JSR L_15_1E3D6                                  ;  1E2E5 E2E5 C 20 D6 E3        F:000332
  JSR L_15_1E400                                  ;  1E2E8 E2E8 C 20 00 E4        F:000332
L_15_1E2EB:
  LDA #$1                                         ;  1E2EB E2EB C A9 01           F:000332
  STA FrameCountdownTimer                                      ;  1E2ED E2ED C 85 36           F:000332
  JSR ReadJoypad                                  ;  1E2EF E2EF C 20 43 CC        F:000332
  BIT JoypadInput                                      ;  1E2F2 E2F2 C 24 20           F:000332
  BMI B_15_1E32D                                  ;  1E2F4 E2F4 C 30 37           F:000332
  BVS B_15_1E333                                  ;  1E2F6 E2F6 C 70 3B           F:000332
  LDA JoypadInput                                      ;  1E2F8 E2F8 C A5 20           F:000332
  LSR                                             ;  1E2FA E2FA C 4A              F:000332
  BCS B_15_1E31B                                  ;  1E2FB E2FB C B0 1E           F:000332
  LSR                                             ;  1E2FD E2FD C 4A              F:000332
  BCS B_15_1E321                                  ;  1E2FE E2FE C B0 21           F:000332
  LSR                                             ;  1E300 E300 C 4A              F:000332
  BCS B_15_1E315                                  ;  1E301 E301 C B0 12           F:000332
  LSR                                             ;  1E303 E303 C 4A              F:000332
  BCS B_15_1E327                                  ;  1E304 E304 C B0 21           F:000332
  LSR                                             ;  1E306 E306 C 4A              F:000332
  BCS B_15_1E30F                                  ;  1E307 E307 C B0 06           F:000332
  LSR                                             ;  1E309 E309 C 4A              F:000332
  BCS B_15_1E364                                  ;  1E30A E30A C B0 58           F:000332
  JMP B_15_1E333                                  ;  1E30C E30C C 4C 33 E3        F:000332

B_15_1E30F:
  JSR $E347                                       ;  1E30F E30F . 20 47 E3        
  JMP $E333                                       ;  1E312 E312 . 4C 33 E3        

B_15_1E315:
  JSR $E3C7                                       ;  1E315 E315 . 20 C7 E3        
  JMP $E333                                       ;  1E318 E318 . 4C 33 E3        

B_15_1E31B:
  JSR $E39E                                       ;  1E31B E31B . 20 9E E3        
  JMP $E333                                       ;  1E31E E31E . 4C 33 E3        

B_15_1E321:
  JSR $E3AD                                       ;  1E321 E321 . 20 AD E3        
  JMP $E333                                       ;  1E324 E324 . 4C 33 E3        

B_15_1E327:
  JSR $E3BA                                       ;  1E327 E327 . 20 BA E3        
  JMP $E330                                       ;  1E32A E32A . 4C 30 E3        

B_15_1E32D:
  JSR $E372                                       ;  1E32D E32D . 20 72 E3        
  JSR $D0E5                                       ;  1E330 E330 . 20 E5 D0        
B_15_1E333:
  LDA JoypadInput                                      ;  1E333 E333 C A5 20           F:000332
  AND #$CF                                        ;  1E335 E335 C 29 CF           F:000332
  BEQ B_15_1E341                                  ;  1E337 E337 C F0 08           F:000332
  LDA #$C                                         ;  1E339 E339 . A9 0C           
  STA PendingSFX                                      ;  1E33B E33B . 85 8F           
  LDA #$A                                         ;  1E33D E33D . A9 0A           
  STA FrameCountdownTimer                                      ;  1E33F E33F . 85 36           
B_15_1E341:
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  JMP L_15_1E2EB                                  ;  1E344 E344 C 4C EB E2        F:000333


  LDA #$77
  STA TmpE
  LDA #$B5
  STA TmpF
  JSR BankCallMenu
  BCC :+
  RTS 
: LDA #$10
  STA PendingSFX
  JSR L_14_1D0C5
  JSR UpdateKeysDisplay
  JSR UpdateGoldDisplay
  PLA
  PLA

B_15_1E364:
  LDA #$20                                        ;  1E364 E364 C A9 20           F:000357
  STA CameraXTile                                      ;  1E366 E366 C 85 7C           F:000357
  JSR L_14_1C7B5                                  ;  1E368 E368 C 20 B5 C7        F:000357
  JSR UpdateCameraPPUScroll                                  ;  1E36B E36B C 20 C7 C1        F:000373
  JSR SetupHomeSprites                                  ;  1E36E E36E C 20 B2 E7        F:000373
  RTS                                             ;  1E371 E371 C 60              F:000373

.byte $A5,$F5,$0A,$0A,$65,$F5,$65,$F7             ;  1E372 E372 ........ ????e?e? 
.byte $C9,$20,$F0,$14,$C9,$21,$F0,$16             ;  1E37A E37A ........ ? ???!?? 
.byte $C9,$22,$F0,$C1,$48,$20,$1E,$E4             ;  1E382 E382 ........ ?"??H ?? 
.byte $68,$9D,$22,$03,$E0,$1F,$F0,$B5             ;  1E38A E38A ........ h?"????? 
.byte $E6,$F9,$20,$D6,$E3,$60,$C6,$F9             ;  1E392 E392 ........ ?? ??`?? 
.byte $20,$D6,$E3,$60,$A6,$F5,$E8,$E0             ;  1E39A E39A ........  ??`???? 
.byte $07,$90,$02,$A2,$00,$86,$F5,$20             ;  1E3A2 E3A2 ........ ???????  
.byte $00,$E4,$60,$A6,$F5,$CA,$10,$02             ;  1E3AA E3AA ........ ??`????? 
.byte $A2,$06,$86,$F5,$20,$00,$E4,$60             ;  1E3B2 E3B2 ........ ???? ??` 
.byte $A6,$F7,$CA,$10,$02,$A2,$04,$86             ;  1E3BA E3BA ........ ???????? 
.byte $F7,$20,$00,$E4,$60,$A6,$F7,$E8             ;  1E3C2 E3C2 ........ ? ??`??? 
.byte $E0,$05,$90,$02,$A2,$00,$86,$F7             ;  1E3CA E3CA ........ ???????? 
.byte $20,$00,$E4,$60                             ;  1E3D2 E3D2 ....      ??`     
L_15_1E3D6:
  LDX #$61                                        ;  1E3D6 E3D6 C A2 61           F:000332
  LDA Workset+Ent_XPx                                      ;  1E3D8 E3D8 C A5 F9           F:000332
  AND #$1F                                        ;  1E3DA E3DA C 29 1F           F:000332
  CMP #$10                                        ;  1E3DC E3DC C C9 10           F:000332
  BCC B_15_1E3E4                                  ;  1E3DE E3DE C 90 04           F:000332
  SBC #$10                                        ;  1E3E0 E3E0 . E9 10           
  LDX #$69                                        ;  1E3E2 E3E2 . A2 69           
B_15_1E3E4:
  STX R_0280                                      ;  1E3E4 E3E4 C 8E 80 02        F:000332
  STX R_0284                                      ;  1E3E7 E3E7 C 8E 84 02        F:000332
  STA R_0008                                      ;  1E3EA E3EA C 85 08           F:000332
  LSR                                             ;  1E3EC E3EC C 4A              F:000332
  LSR                                             ;  1E3ED E3ED C 4A              F:000332
  CLC                                             ;  1E3EE E3EE C 18              F:000332
  ADC R_0008                                      ;  1E3EF E3EF C 65 08           F:000332
  ASL                                             ;  1E3F1 E3F1 C 0A              F:000332
  ASL                                             ;  1E3F2 E3F2 C 0A              F:000332
  ASL                                             ;  1E3F3 E3F3 C 0A              F:000332
  ADC #$36                                        ;  1E3F4 E3F4 C 69 36           F:000332
  STA R_0287                                      ;  1E3F6 E3F6 C 8D 87 02        F:000332
  SEC                                             ;  1E3F9 E3F9 C 38              F:000332
  SBC #$8                                         ;  1E3FA E3FA C E9 08           F:000332
  STA R_0283                                      ;  1E3FC E3FC C 8D 83 02        F:000332
  RTS                                             ;  1E3FF E3FF C 60              F:000332

L_15_1E400:
  LDA Workset+Ent_XPxSpeed                                      ;  1E400 E400 C A5 F5           F:000332
  ASL                                             ;  1E402 E402 C 0A              F:000332
  ASL                                             ;  1E403 E403 C 0A              F:000332
  ASL                                             ;  1E404 E404 C 0A              F:000332
  ADC #$36                                        ;  1E405 E405 C 69 36           F:000332
  STA R_0297                                      ;  1E407 E407 C 8D 97 02        F:000332
  SEC                                             ;  1E40A E40A C 38              F:000332
  SBC #$8                                         ;  1E40B E40B C E9 08           F:000332
  STA R_0293                                      ;  1E40D E40D C 8D 93 02        F:000332
  LDA Workset+Ent_YPxSpeed                                      ;  1E410 E410 C A5 F7           F:000332
  ASL                                             ;  1E412 E412 C 0A              F:000332
  ASL                                             ;  1E413 E413 C 0A              F:000332
  ASL                                             ;  1E414 E414 C 0A              F:000332
  ADC #$81                                        ;  1E415 E415 C 69 81           F:000332
  STA R_0290                                      ;  1E417 E417 C 8D 90 02        F:000332
  STA R_0294                                      ;  1E41A E41A C 8D 94 02        F:000332
  RTS                                             ;  1E41D E41D C 60              F:000332

.byte $A5,$F9,$29,$1F,$AA,$60                     ;  1E41E E41E ......   ??)??`   
EnterShopDoor:
  JSR PutPlayerLocationOnStack                                  ;  1E424 E424 C 20 20 E6        F:017545
  LDA ShopItem1Type                                      ;  1E427 E427 C A5 80           F:017545
  PHA                                             ;  1E429 E429 C 48              F:017545
  LDA ShopItem1Cost                                      ;  1E42A E42A C A5 81           F:017545
  PHA                                             ;  1E42C E42C C 48              F:017545
  LDA ShopItem2Type                                      ;  1E42D E42D C A5 82           F:017545
  PHA                                             ;  1E42F E42F C 48              F:017545
  LDA ShopItem2Cost                                      ;  1E430 E430 C A5 83           F:017545
  PHA                                             ;  1E432 E432 C 48              F:017545
  LDA CurrentAreaX                                      ;  1E433 E433 C A5 47           F:017545
  JSR L_15_1E660                                  ;  1E435 E435 C 20 60 E6        F:017545
  PLA                                             ;  1E438 E438 C 68              F:017567
  STA ShopItem2Cost                                      ;  1E439 E439 C 85 83           F:017567
  PLA                                             ;  1E43B E43B C 68              F:017567
  STA ShopItem2Type                                      ;  1E43C E43C C 85 82           F:017567
  PLA                                             ;  1E43E E43E C 68              F:017567
  STA ShopItem1Cost                                      ;  1E43F E43F C 85 81           F:017567
  PLA                                             ;  1E441 E441 C 68              F:017567
  STA ShopItem1Type                                      ;  1E442 E442 C 85 80           F:017567
  JSR L_15_1E6FF                                  ;  1E444 E444 C 20 FF E6        F:017567
  JSR L_14_1CFBC                                  ;  1E447 E447 C 20 BC CF        F:017567
  JSR UpdateInnSprites                                  ;  1E44A E44A C 20 78 E7        F:017569
  JSR FadeInAreaPalette                                  ;  1E44D E44D C 20 92 C4        F:017569
B_15_1E450:
  JSR L_15_1E514                                  ;  1E450 E450 C 20 14 E5        F:017595
  BCS B_15_1E4A7                                  ;  1E453 E453 C B0 52           F:017611
  LDX #$0                                         ;  1E455 E455 C A2 00           F:040772
  LDA PlayerXTile                                      ;  1E457 E457 C A5 44           F:040772
  AND #$F                                         ;  1E459 E459 C 29 0F           F:040772
  CMP #$3                                         ;  1E45B E45B C C9 03           F:040772
  BCC B_15_1E450                                  ;  1E45D E45D C 90 F1           F:040772
  CMP #$5                                         ;  1E45F E45F C C9 05           F:040772
  BCC B_15_1E46D                                  ;  1E461 E461 C 90 0A           F:040772
  LDX #$2                                         ;  1E463 E463 C A2 02           F:047425
  CMP #$A                                         ;  1E465 E465 C C9 0A           F:047425
  BCC B_15_1E450                                  ;  1E467 E467 C 90 E7           F:047425
  CMP #$C                                         ;  1E469 E469 C C9 0C           F:047425
  BCS B_15_1E450                                  ;  1E46B E46B C B0 E3           F:047425
B_15_1E46D:
  LDA ShopItem1Type,X                                    ;  1E46D E46D C B5 80           F:040772
  BMI B_15_1E489                                  ;  1E46F E46F C 30 18           F:040772
  PHA                                             ;  1E471 E471 C 48              F:040772
  TXA                                             ;  1E472 E472 C 8A              F:040772
  PHA                                             ;  1E473 E473 C 48              F:040772
  LDA ShopItem1Cost,X                                    ;  1E474 E474 C B5 81           F:040772
  JSR RemovePlayerGold                                  ;  1E476 E476 C 20 42 E8        F:040772
  BCS B_15_1E48E                                  ;  1E479 E479 C B0 13           F:040772
  PLA                                             ;  1E47B E47B C 68              F:056306
  PLA                                             ;  1E47C E47C C 68              F:056306
  CMP #ItemType_Crystal                           ;  1E47D E47D C C9 0D           F:056306
  BNE B_15_1E489                                  ;  1E47F E47F C D0 08           F:056306
  LDA CheatsEnabled                                      ;  1E481 E481 . A5 37           
  BEQ B_15_1E489                                  ;  1E483 E483 . F0 04           
  LDA #$1                                         ;  1E485 E485 . A9 01           
  STA PlayerInventory_Armor                                      ;  1E487 E487 . 85 61           
B_15_1E489:
  LDA #$6                                         ;  1E489 E489 C A9 06           F:056306
  JMP L_15_1E49D                                  ;  1E48B E48B C 4C 9D E4        F:056306

B_15_1E48E:
  PLA                                             ;  1E48E E48E C 68              F:040772
  TAX                                             ;  1E48F E48F C AA              F:040772
  LDA #$FF                                        ;  1E490 E490 C A9 FF           F:040772
  STA ShopItem1Type,X                                    ;  1E492 E492 C 95 80           F:040772
  JSR L_15_1E6FF                                  ;  1E494 E494 C 20 FF E6        F:040772
  PLA                                             ;  1E497 E497 C 68              F:040772
  TAX                                             ;  1E498 E498 C AA              F:040772
  INC PlayerInventory,X                                    ;  1E499 E499 C F6 60           F:040772
  LDA #$10                                        ;  1E49B E49B C A9 10           F:040772
L_15_1E49D:
  STA PendingSFX                                      ;  1E49D E49D C 85 8F           F:040772
B_15_1E49F:
  JSR ReadJoypad                                  ;  1E49F E49F C 20 43 CC        F:040772
  BNE B_15_1E49F                                  ;  1E4A2 E4A2 C D0 FB           F:040772
  JMP B_15_1E450                                  ;  1E4A4 E4A4 C 4C 50 E4        F:040781

B_15_1E4A7:
  JMP L_15_1E5FD                                  ;  1E4A7 E4A7 C 4C FD E5        F:017611

RunPlayerControlInventory:
  @TmpSelectedItemType = $8
  jsr RunPauseScreenMovement                      ; handle player movement
  BCS @B_15_1E504                                  ;  1E4AD E4AD C B0 55           F:000915
  ldx #$FF                                        ;
  lda PlayerYPx                                   ; check if player is too far down for the inventory
  cmp #$58                                        ;
  bcs @UnderInventoryArea                         ;
  ldx #0                                          ; set offset for first row
  cmp #$38                                        ; check if we should use the second row
  bcc :+                                          ;
  ldx #$8                                         ; if we're on the second row, offset X
: stx @TmpSelectedItemType                        ; store row value
  lda PlayerXTile                                 ; then get exact slot based on player x position
  lsr a                                           ;
  ora @TmpSelectedItemType                        ; and add back the row bit
  tax                                             ; use that as the offset into the inventory table
  lda PlayerInventory,x                           ; check how many of this item the player has
  beq @CannotEquip                                ; if we have none, we cannot equip the item
  txa                                             ; otherwise store the slot on the stack
  pha                                             ;
  jsr CanPlayerEquipItem                          ; check if the player can equip the item
  pla                                             ; restore slot index
  tax                                             ;
  bcs @Decrement                                  ; if we can equip the item, remove it from the inventory
@CannotEquip:
  lda #$6                                         ; play bad sound
  sta PendingSFX                                  ; 
  jmp RunPlayerControlInventory                   ;
@Decrement:
  dec PlayerInventory,x                           ; remove 1 copy of the item

@UnderInventoryArea:
  stx @TmpSelectedItemType                        ; store current item type
  ldx PlayerActiveItems                           ; check if the player has any items equipped
  bmi :+                                          ;
  inc PlayerInventory,x                           ; if so, we need to increment the item that will be shifted back into inventory
: lda PlayerActiveItems+1                         ; shift all the items up one slot
  sta PlayerActiveItems                           ;
  lda PlayerActiveItems+2                         ;
  sta PlayerActiveItems+1                         ;
  lda @TmpSelectedItemType                        ; then add our new item to the list!
  sta PlayerActiveItems+2                         ;
  lda #SFX_Equip                                  ; queue equipment sound
  sta PendingSFX                                  ;
  JSR PauseMenu_DrawActiveItems                                 ;  1E4F5 E4F5 C 20 B7 E6        F:041644
  JSR UpdateInventorySprites                     ;  1E4F8 E4F8 C 20 34 C2        F:041644
  JSR PauseMenu_DrawInventory                                 ;  1E4FB E4FB C 20 30 CF        F:041644
  JSR PauseMenu_DrawCharacterAttributes          ;  1E4FE E4FE C 20 82 CF        F:041660
: JMP RunPlayerControlInventory                  ;  1E501 E501 C 4C AA E4        F:041663

@B_15_1E504:
  ldx PlayerSelectedItemSlot                      ; check which item is selected
  lda PlayerActiveItems,x                         ;
  cmp #ItemType_Crystal                           ; if it's the crystal, we don't want to immediately warp on unpause
  bne :+                                          ;
  lda #$3                                         ; deselect crystal
  sta PlayerSelectedItemSlot                      ;
  jsr UpdateInventorySprites                      ; and redraw
: rts                                             ; exit

L_15_1E514:
  LDA #$1                                         ;  1E514 E514 C A9 01           F:009154
  STA FrameCountdownTimer                                      ;  1E516 E516 C 85 36           F:009154
  JSR ReadJoypad                                  ;  1E518 E518 C 20 43 CC        F:009154
  LDA JoypadInput                                      ;  1E51B E51B C A5 20           F:009154
  AND #$80                                        ;  1E51D E51D C 29 80           F:009154
  BNE B_15_1E55E                                  ;  1E51F E51F C D0 3D           F:009154
  LDA JoypadInput                                      ;  1E521 E521 C A5 20           F:009154
  AND #$F                                         ;  1E523 E523 C 29 0F           F:009154
  LDY #$1                                         ;  1E525 E525 C A0 01           F:009154
  JSR L_14_1CD2C                                  ;  1E527 E527 C 20 2C CD        F:009154
  JSR L_14_1D8B6                                  ;  1E52A E52A C 20 B6 D8        F:009154
  LDA TmpA                                      ;  1E52D E52D C A5 0A           F:009154
  CMP #$8C                                        ;  1E52F E52F C C9 8C           F:009154
  BCC B_15_1E54F                                  ;  1E531 E531 C 90 1C           F:009154
  CMP #$A1                                        ;  1E533 E533 C C9 A1           F:009154
  BCS B_15_1E560                                  ;  1E535 E535 C B0 29           F:009154
  LDA TmpF                                      ;  1E537 E537 C A5 0F           F:009154
  AND #$F                                         ;  1E539 E539 C 29 0F           F:009154
  CMP #$2                                         ;  1E53B E53B C C9 02           F:009154
  BCC B_15_1E54F                                  ;  1E53D E53D C 90 10           F:009154
  CMP #$D                                         ;  1E53F E53F C C9 0D           F:009154
  BCS B_15_1E54F                                  ;  1E541 E541 C B0 0C           F:009154
  LDA TmpE                                      ;  1E543 E543 C A5 0E           F:009154
  STA PlayerXPx                                      ;  1E545 E545 C 85 43           F:009154
  LDA TmpF                                      ;  1E547 E547 C A5 0F           F:009154
  STA PlayerXTile                                      ;  1E549 E549 C 85 44           F:009154
  LDA TmpA                                      ;  1E54B E54B C A5 0A           F:009154
  STA PlayerYPx                                      ;  1E54D E54D C 85 45           F:009154
B_15_1E54F:
  JSR SelectPlayerSprite1                                  ;  1E54F E54F C 20 E3 D8        F:009154
  JSR L_14_1D94E                                  ;  1E552 E552 C 20 4E D9        F:009154
  JSR UpdatePlayerSprites                                  ;  1E555 E555 C 20 D8 C1        F:009154
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  JMP L_15_1E514                                  ;  1E55B E55B C 4C 14 E5        F:009155

B_15_1E55E:
  CLC                                             ;  1E55E E55E C 18              F:040772
  RTS                                             ;  1E55F E55F C 60              F:040772

B_15_1E560:
  SEC                                             ;  1E560 E560 C 38              F:009155
  RTS                                             ;  1E561 E561 C 60              F:009155

RunPauseScreenMovement:
  LDA #$1                                         ;  1E562 E562 C A9 01           F:000871
  STA FrameCountdownTimer                                      ;  1E564 E564 C 85 36           F:000871
  JSR ReadJoypad                                  ;  1E566 E566 C 20 43 CC        F:000871
  LDA JoypadInput                                      ;  1E569 E569 C A5 20           F:000871
  AND #$80                                        ;  1E56B E56B C 29 80           F:000871
  BNE B_15_1E5B0                                  ;  1E56D E56D C D0 41           F:000871
  LDA JoypadInput                                      ;  1E56F E56F C A5 20           F:000871
  AND #$F                                         ;  1E571 E571 C 29 0F           F:000871
  LDY #$1                                         ;  1E573 E573 C A0 01           F:000871
  JSR L_14_1CD2C                                  ;  1E575 E575 C 20 2C CD        F:000871
  JSR L_14_1D8B6                                  ;  1E578 E578 C 20 B6 D8        F:000871
  LDA TmpA                                      ;  1E57B E57B C A5 0A           F:000871
  CMP #$20                                        ;  1E57D E57D C C9 20           F:000871
  BCC B_15_1E5A1                                  ;  1E57F E57F C 90 20           F:000871
  CMP #$A1                                        ;  1E581 E581 C C9 A1           F:000871
  BCS B_15_1E5B2                                  ;  1E583 E583 C B0 2D           F:000871
  LDA TmpF                                      ;  1E585 E585 C A5 0F           F:000871
  AND #$F                                         ;  1E587 E587 C 29 0F           F:000871
  CMP #$1                                         ;  1E589 E589 C C9 01           F:000871
  BCC B_15_1E5A1                                  ;  1E58B E58B C 90 14           F:000871
  CMP #$F                                         ;  1E58D E58D C C9 0F           F:000871
  BCC B_15_1E595                                  ;  1E58F E58F C 90 04           F:000871
  LDA TmpE                                      ;  1E591 E591 . A5 0E           
  BNE B_15_1E5A1                                  ;  1E593 E593 . D0 0C           
B_15_1E595:
  LDA TmpE                                      ;  1E595 E595 C A5 0E           F:000871
  STA PlayerXPx                                      ;  1E597 E597 C 85 43           F:000871
  LDA TmpF                                      ;  1E599 E599 C A5 0F           F:000871
  STA PlayerXTile                                      ;  1E59B E59B C 85 44           F:000871
  LDA TmpA                                      ;  1E59D E59D C A5 0A           F:000871
  STA PlayerYPx                                      ;  1E59F E59F C 85 45           F:000871
B_15_1E5A1:
  JSR SelectPlayerSprite1                                  ;  1E5A1 E5A1 C 20 E3 D8        F:000871
  JSR L_14_1D94E                                  ;  1E5A4 E5A4 C 20 4E D9        F:000871
  JSR UpdatePlayerSprites                                  ;  1E5A7 E5A7 C 20 D8 C1        F:000871
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  JMP RunPauseScreenMovement                                  ;  1E5AD E5AD C 4C 62 E5        F:000872

B_15_1E5B0:
  CLC                                             ;  1E5B0 E5B0 C 18              F:041644
  RTS                                             ;  1E5B1 E5B1 C 60              F:041644

B_15_1E5B2:
  SEC                                             ;  1E5B2 E5B2 C 38              F:000915
  RTS                                             ;  1E5B3 E5B3 C 60              F:000915

L_15_1E5B4:
  LDA #$1                                         ;  1E5B4 E5B4 C A9 01           F:000219
  STA FrameCountdownTimer                                      ;  1E5B6 E5B6 C 85 36           F:000219
  JSR ReadJoypad                                  ;  1E5B8 E5B8 C 20 43 CC        F:000219
  LDA JoypadInput                                      ;  1E5BB E5BB C A5 20           F:000219
  AND #$80                                        ;  1E5BD E5BD C 29 80           F:000219
  BNE B_15_1E5FC                                  ;  1E5BF E5BF C D0 3B           F:000219
  LDA JoypadInput                                      ;  1E5C1 E5C1 C A5 20           F:000219
  AND #$F                                         ;  1E5C3 E5C3 C 29 0F           F:000219
  LDY #$1                                         ;  1E5C5 E5C5 C A0 01           F:000219
  JSR L_14_1CD2C                                  ;  1E5C7 E5C7 C 20 2C CD        F:000219
  JSR L_14_1D8B6                                  ;  1E5CA E5CA C 20 B6 D8        F:000219
  LDA TmpA                                      ;  1E5CD E5CD C A5 0A           F:000219
  CMP #$30                                        ;  1E5CF E5CF C C9 30           F:000219
  BCC B_15_1E5F3                                  ;  1E5D1 E5D1 C 90 20           F:000219
  CMP #$A1                                        ;  1E5D3 E5D3 C C9 A1           F:000219
  BCS B_15_1E5F3                                  ;  1E5D5 E5D5 C B0 1C           F:000219
  LDA TmpF                                      ;  1E5D7 E5D7 C A5 0F           F:000219
  AND #$F                                         ;  1E5D9 E5D9 C 29 0F           F:000219
  CMP #$2                                         ;  1E5DB E5DB C C9 02           F:000219
  BCC B_15_1E5F3                                  ;  1E5DD E5DD C 90 14           F:000219
  CMP #$D                                         ;  1E5DF E5DF C C9 0D           F:000219
  BCC B_15_1E5E7                                  ;  1E5E1 E5E1 C 90 04           F:000219
  LDA TmpE                                      ;  1E5E3 E5E3 . A5 0E           
  BNE B_15_1E5F3                                  ;  1E5E5 E5E5 . D0 0C           
B_15_1E5E7:
  LDA TmpE                                      ;  1E5E7 E5E7 C A5 0E           F:000219
  STA PlayerXPx                                      ;  1E5E9 E5E9 C 85 43           F:000219
  LDA TmpF                                      ;  1E5EB E5EB C A5 0F           F:000219
  STA PlayerXTile                                      ;  1E5ED E5ED C 85 44           F:000219
  LDA TmpA                                      ;  1E5EF E5EF C A5 0A           F:000219
  STA PlayerYPx                                      ;  1E5F1 E5F1 C 85 45           F:000219
B_15_1E5F3:
  JSR UpdatePlayerSprites                                  ;  1E5F3 E5F3 C 20 D8 C1        F:000219
  jsr WaitForCountdownTimer                       ; wait for timer to finish
  JMP L_15_1E5B4                                  ;  1E5F9 E5F9 C 4C B4 E5        F:000220

B_15_1E5FC:
  RTS                                             ;  1E5FC E5FC C 60              F:000314

L_15_1E5FD:
  JSR RestorePlayerLocationFromStack                                  ;  1E5FD E5FD C 20 42 E6        F:000915
  JSR L_14_1C3E5                                  ;  1E600 E600 C 20 E5 C3        F:000915
  JSR L_15_1E79D                                  ;  1E603 E603 C 20 9D E7        F:000935
  LDA Workset_FE                                      ;  1E606 E606 C A5 FE           F:000935
  JSR ChangeMusicIfNeeded                                  ;  1E608 E608 C 20 2E D0        F:000935
  JSR ReloadAreaConfig                                  ;  1E60B E60B C 20 FF C8        F:000935
  JSR DrawLeftAreaDataColumn                                  ;  1E60E E60E C 20 CB C5        F:000935
  JSR UpdatePlayerSprites                                  ;  1E611 E611 C 20 D8 C1        F:000936
  JSR UpdateEntitySprites                                  ;  1E614 E614 C 20 B1 C2        F:000936
  JSR UpdateCameraPPUScroll                                  ;  1E617 E617 C 20 C7 C1        F:000936
  JSR FadeInAreaPalette                                  ;  1E61A E61A C 20 92 C4        F:000936
  JMP L_14_1D8AF                                  ;  1E61D E61D C 4C AF D8        F:000962

PutPlayerLocationOnStack:
  pla                                             ; pull caller off stack into X/Y
  tax                                             ;
  pla                                             ;
  tay                                             ;
  lda CurrentMusic                            ; copy music to temp location
  sta Workset_FE                                  ;
  lda PlayerXPx                               ; push player location to stack
  pha                                             ;
  lda PlayerXTile                                 ;
  pha                                             ;
  lda PlayerYPx                                   ;
  pha                                             ;
  lda CameraXPx                                   ;
  pha                                             ;
  lda CameraXTile                                 ;
  pha                                             ;
  lda CurrentAreaX                                ;
  pha                                             ;
  lda CurrentAreaY                                ;
  pha                                             ;
  tya                                             ; push caller back onto stack
  pha                                             ;
  txa                                             ;
  pha                                             ;
  rts                                             ; done!

RestorePlayerLocationFromStack:
  pla                                             ; pull caller off stack into X/Y
  tax                                             ;
  pla                                             ;
  tay                                             ;
  pla                                             ; pull player location from stack
  sta CurrentAreaY                                ;
  pla                                             ;
  sta CurrentAreaX                                ;
  pla                                             ;
  sta CameraXTile                                 ;
  pla                                             ;
  sta CameraXPx                                   ;
  pla                                             ;
  sta PlayerYPx                                   ;
  pla                                             ;
  sta PlayerXTile                                 ;
  pla                                             ;
  sta PlayerXPx                               ;
  tya                                             ; push caller back onto stack
  pha                                             ;
  txa                                             ;
  pha                                             ;
  rts                                             ; done!

L_15_1E660:
  PHA                                             ;  1E660 E660 C 48              F:000172
  JSR L_14_1C3E5                                  ;  1E661 E661 C 20 E5 C3        F:000172
  JMP L_15_1E66B                                  ;  1E664 E664 C 4C 6B E6        F:000192

L_15_1E667:
  PHA                                             ;  1E667 E667 C 48              F:041476
  JSR L_14_1C430                                  ;  1E668 E668 C 20 30 C4        F:041476
L_15_1E66B:
  PLA                                             ;  1E66B E66B C 68              F:000192
  PHA                                             ;  1E66C E66C C 48              F:000192
  STA R_0008                                      ;  1E66D E66D C 85 08           F:000192
  AND #$C                                         ;  1E66F E66F C 29 0C           F:000192
  LSR                                             ;  1E671 E671 C 4A              F:000192
  LSR                                             ;  1E672 E672 C 4A              F:000192
  STA CurrentAreaX                                      ;  1E673 E673 C 85 47           F:000192
  LDA R_0008                                      ;  1E675 E675 C A5 08           F:000192
  AND #$3                                         ;  1E677 E677 C 29 03           F:000192
  ASL                                             ;  1E679 E679 C 0A              F:000192
  ASL                                             ;  1E67A E67A C 0A              F:000192
  ASL                                             ;  1E67B E67B C 0A              F:000192
  ASL                                             ;  1E67C E67C C 0A              F:000192
  STA CameraXTile                                      ;  1E67D E67D C 85 7C           F:000192
  CLC                                             ;  1E67F E67F C 18              F:000192
  ADC #$7                                         ;  1E680 E680 C 69 07           F:000192
  STA PlayerXTile                                      ;  1E682 E682 C 85 44           F:000192
  LDA #$10                                        ;  1E684 E684 C A9 10           F:000192
  STA CurrentAreaY                                      ;  1E686 E686 C 85 48           F:000192
  LDA #$8                                         ;  1E688 E688 C A9 08           F:000192
  STA PlayerXPx                                      ;  1E68A E68A C 85 43           F:000192
  LDA #$A0                                        ;  1E68C E68C C A9 A0           F:000192
  STA PlayerYPx                                      ;  1E68E E68E C 85 45           F:000192
  LDA #$0                                         ;  1E690 E690 C A9 00           F:000192
  STA PlayerJumpProgress                                      ;  1E692 E692 C 85 4F           F:000192
  STA PlayerFallHeight                                      ;  1E694 E694 C 85 4E           F:000192
  STA CameraXPx                                      ;  1E696 E696 C 85 7B           F:000192
  JSR ClearEntitySprites                                  ;  1E698 E698 C 20 7C D0        F:000192
  JSR ReloadAreaConfig                                  ;  1E69B E69B C 20 FF C8        F:000192
  PLA                                             ;  1E69E E69E C 68              F:000192
  CMP #$4                                         ;  1E69F E69F C C9 04           F:000192
  BNE B_15_1E6AA                                  ;  1E6A1 E6A1 C D0 07           F:000192
  LDA #$1F                                        ;  1E6A3 E6A3 C A9 1F           F:009127
  CLC                                             ;  1E6A5 E6A5 C 18              F:009127
  ADC #$A0                                        ;  1E6A6 E6A6 C 69 A0           F:009127
  STA AreaBGGfxSet+1                                      ;  1E6A8 E6A8 C 85 7A           F:009127
B_15_1E6AA:
  JSR L_14_1C5DC                                  ;  1E6AA E6AA C 20 DC C5        F:000192
  JSR SelectPlayerSprite1                                  ;  1E6AD E6AD C 20 E3 D8        F:000193
  JSR UpdatePlayerSprites                                  ;  1E6B0 E6B0 C 20 D8 C1        F:000193
  JSR UpdateCameraPPUScroll                                  ;  1E6B3 E6B3 C 20 C7 C1        F:000193
  RTS                                             ;  1E6B6 E6B6 C 60              F:000193

PauseMenu_DrawActiveItems:
  LDA #$58                                        ;  1E6B7 E6B7 C A9 58           F:000826
  STA R_0008                                      ;  1E6B9 E6B9 C 85 08           F:000826
  LDX #$2                                         ;  1E6BB E6BB C A2 02           F:000826
  LDY #$10                                        ;  1E6BD E6BD C A0 10           F:000826
B_15_1E6BF:
  LDA PlayerActiveItems,X                                    ;  1E6BF E6BF C B5 51           F:000826
  BMI B_15_1E6D6                                  ;  1E6C1 E6C1 C 30 13           F:000826
  ASL                                             ;  1E6C3 E6C3 . 0A              
  ASL                                             ;  1E6C4 E6C4 . 0A              
  CLC                                             ;  1E6C5 E6C5 . 18              
  ADC #$A1                                        ;  1E6C6 E6C6 . 69 A1           
  STA R_0241,Y                                    ;  1E6C8 E6C8 . 99 41 02        
  CLC                                             ;  1E6CB E6CB . 18              
  ADC #$2                                         ;  1E6CC E6CC . 69 02           
  STA R_0245,Y                                    ;  1E6CE E6CE . 99 45 02        
  LDA #$BB                                        ;  1E6D1 E6D1 . A9 BB           
  JMP $E6D8                                       ;  1E6D3 E6D3 . 4C D8 E6        

B_15_1E6D6:
  LDA #$EF                                        ;  1E6D6 E6D6 C A9 EF           F:000826
  STA R_0240,Y                                    ;  1E6D8 E6D8 C 99 40 02        F:000826
  STA R_0244,Y                                    ;  1E6DB E6DB C 99 44 02        F:000826
  LDA R_0008                                      ;  1E6DE E6DE C A5 08           F:000826
  STA R_0243,Y                                    ;  1E6E0 E6E0 C 99 43 02        F:000826
  CLC                                             ;  1E6E3 E6E3 C 18              F:000826
  ADC #$8                                         ;  1E6E4 E6E4 C 69 08           F:000826
  STA R_0247,Y                                    ;  1E6E6 E6E6 C 99 47 02        F:000826
  SEC                                             ;  1E6E9 E6E9 C 38              F:000826
  SBC #$28                                        ;  1E6EA E6EA C E9 28           F:000826
  STA R_0008                                      ;  1E6EC E6EC C 85 08           F:000826
  LDA #$1                                         ;  1E6EE E6EE C A9 01           F:000826
  STA R_0242,Y                                    ;  1E6F0 E6F0 C 99 42 02        F:000826
  STA R_0246,Y                                    ;  1E6F3 E6F3 C 99 46 02        F:000826
  TYA                                             ;  1E6F6 E6F6 C 98              F:000826
  SEC                                             ;  1E6F7 E6F7 C 38              F:000826
  SBC #$8                                         ;  1E6F8 E6F8 C E9 08           F:000826
  TAY                                             ;  1E6FA E6FA C A8              F:000826
  DEX                                             ;  1E6FB E6FB C CA              F:000826
  BPL B_15_1E6BF                                  ;  1E6FC E6FC C 10 C1           F:000826
  RTS                                             ;  1E6FE E6FE C 60              F:000826

L_15_1E6FF:
  LDA #$EF                                        ;  1E6FF E6FF C A9 EF           F:017567
  LDX ShopItem1Type                                      ;  1E701 E701 C A6 80           F:017567
  BMI B_15_1E72D                                  ;  1E703 E703 C 30 28           F:017567
  LDA PlayerInventory,X                                    ;  1E705 E705 C B5 60           F:017567
  CMP #$B                                         ;  1E707 E707 C C9 0B           F:017567
  BCC B_15_1E712                                  ;  1E709 E709 C 90 07           F:017567
  LDA #$EF                                        ;  1E70B E70B . A9 EF           
  STA ShopItem1Type                                      ;  1E70D E70D . 85 80           
  JMP $E72D                                       ;  1E70F E70F . 4C 2D E7        

B_15_1E712:
  TXA                                             ;  1E712 E712 C 8A              F:017567
  ASL                                             ;  1E713 E713 C 0A              F:017567
  ASL                                             ;  1E714 E714 C 0A              F:017567
  CLC                                             ;  1E715 E715 C 18              F:017567
  ADC #$A1                                        ;  1E716 E716 C 69 A1           F:017567
  STA R_0241                                      ;  1E718 E718 C 8D 41 02        F:017567
  CLC                                             ;  1E71B E71B C 18              F:017567
  ADC #$2                                         ;  1E71C E71C C 69 02           F:017567
  STA R_0245                                      ;  1E71E E71E C 8D 45 02        F:017567
  LDA #$40                                        ;  1E721 E721 C A9 40           F:017567
  STA R_0243                                      ;  1E723 E723 C 8D 43 02        F:017567
  LDA #$48                                        ;  1E726 E726 C A9 48           F:017567
  STA R_0247                                      ;  1E728 E728 C 8D 47 02        F:017567
  LDA #$A4                                        ;  1E72B E72B C A9 A4           F:017567
B_15_1E72D:
  STA R_0240                                      ;  1E72D E72D C 8D 40 02        F:017567
  STA R_0244                                      ;  1E730 E730 C 8D 44 02        F:017567
  LDA #$1                                         ;  1E733 E733 C A9 01           F:017567
  STA R_0242                                      ;  1E735 E735 C 8D 42 02        F:017567
  STA R_0246                                      ;  1E738 E738 C 8D 46 02        F:017567
  LDA #$EF                                        ;  1E73B E73B C A9 EF           F:017567
  LDX ShopItem2Type                                      ;  1E73D E73D C A6 82           F:017567
  BMI B_15_1E769                                  ;  1E73F E73F C 30 28           F:017567
  LDA PlayerInventory,X                                    ;  1E741 E741 C B5 60           F:017567
  CMP #$B                                         ;  1E743 E743 C C9 0B           F:017567
  BCC B_15_1E74E                                  ;  1E745 E745 C 90 07           F:017567
  LDA #$EF                                        ;  1E747 E747 . A9 EF           
  STA ShopItem2Type                                      ;  1E749 E749 . 85 82           
  JMP $E769                                       ;  1E74B E74B . 4C 69 E7        

B_15_1E74E:
  TXA                                             ;  1E74E E74E C 8A              F:017567
  ASL                                             ;  1E74F E74F C 0A              F:017567
  ASL                                             ;  1E750 E750 C 0A              F:017567
  CLC                                             ;  1E751 E751 C 18              F:017567
  ADC #$A1                                        ;  1E752 E752 C 69 A1           F:017567
  STA R_0249                                      ;  1E754 E754 C 8D 49 02        F:017567
  CLC                                             ;  1E757 E757 C 18              F:017567
  ADC #$2                                         ;  1E758 E758 C 69 02           F:017567
  STA R_024D                                      ;  1E75A E75A C 8D 4D 02        F:017567
  LDA #$B0                                        ;  1E75D E75D C A9 B0           F:017567
  STA R_024B                                      ;  1E75F E75F C 8D 4B 02        F:017567
  LDA #$B8                                        ;  1E762 E762 C A9 B8           F:017567
  STA R_024F                                      ;  1E764 E764 C 8D 4F 02        F:017567
  LDA #$A0                                        ;  1E767 E767 C A9 A0           F:017567
B_15_1E769:
  STA R_0248                                      ;  1E769 E769 C 8D 48 02        F:017567
  STA R_024C                                      ;  1E76C E76C C 8D 4C 02        F:017567
  LDA #$1                                         ;  1E76F E76F C A9 01           F:017567
  STA R_024A                                      ;  1E771 E771 C 8D 4A 02        F:017567
  STA R_024E                                      ;  1E774 E774 C 8D 4E 02        F:017567
  RTS                                             ;  1E777 E777 C 60              F:017567

UpdateInnSprites:
  lda #$98                                        ; create sprites for the inn
  sta SprY + ($14 * 4)                            ;
  sta SprY + ($15 * 4)                            ;
  lda #$F1                                        ;
  sta SprX + ($14 * 4)                            ;
  lda #$F3                                        ;
  sta SprX + ($15 * 4)                            ;
  lda #$2                                         ;
  sta SprAttr + ($14 * 4)                         ;
  sta SprAttr + ($15 * 4)                         ;
  lda #$78                                        ;
  sta SprTile + ($14 * 4)                         ;
  lda #$80                                        ;
  sta SprTile + ($15 * 4)                         ;
  rts                                             ; done!

L_15_1E79D:
  LDA #$EF                                        ;  1E79D E79D C A9 EF           F:000935
  STA R_0240                                      ;  1E79F E79F C 8D 40 02        F:000935
  STA R_0244                                      ;  1E7A2 E7A2 C 8D 44 02        F:000935
  STA R_0248                                      ;  1E7A5 E7A5 C 8D 48 02        F:000935
  STA R_024C                                      ;  1E7A8 E7A8 C 8D 4C 02        F:000935
  STA R_0250                                      ;  1E7AB E7AB C 8D 50 02        F:000935
  STA R_0254                                      ;  1E7AE E7AE C 8D 54 02        F:000935
  RTS                                             ;  1E7B1 E7B1 C 60              F:000935

SetupHomeSprites:
  ldx #HomeSpritesEnd-HomeSprites-1               ; number of bytes to copy
: lda HomeSprites,x                               ; copy each byte
  sta SprY+(4*32),x                               ;
  dex                                             ;
  bpl :-                                          ; loop until done
  LDA #$34                                        ; set mmc3 banks for house area
  STA SelectedBank2                               ;
  LDA #$35                                        ;
  STA SelectedBank3                               ;
  LDA #$36                                        ;
  STA SelectedBank4                               ;
  LDA #$37                                        ;
  STA SelectedBank5                               ;
  RTS                                             ;

DecrementPlayerHealth:
  lda PlayerHP                                    ;
  beq @Fail                                       ; exit if player is at 0 health
  dec PlayerHP                                    ; damage player by 1 health
  jsr UpdateHPDisplay                             ; make sure our new health is good and update the statusbar
  clc                                             ;
  rts                                             ; done!
@Fail:
  sec                                             ; mark as failed
  rts                                             ; done!

ApplyDamageToPlayer:
  @TmpDamage = $8
  sta @TmpDamage                                  ; store damage being taken
  lda PlayerHP                                    ; remove damage from hitpoints
  sec                                             ;
  sbc @TmpDamage                                  ;
  sta PlayerHP                                    ; and store new health value
  php                                             ;
  bcs :+                                          ; skip ahead unless we underflowed
  lda #$0                                         ; if so, force health to 0
  sta PlayerHP                                    ;
: jsr UpdateHPDisplay                                  ; make sure new health is a valid value
  plp                                             ;
  rts                                             ; done!

UsePlayerMana:
  txa                                             ; store callers X
  pha                                             ;
  lda PlayerMP                                    ; check so we have mana
  sec                                             ;
  beq @Nope                                       ; if not - bail
  dec PlayerMP                                    ; otherwise decrement mana
  jsr UpdateMPDisplay                             ; and update the StatusBar
  clc                                             ;
@Nope:
  pla                                             ; restore X
  tax                                             ;
  rts                                             ; done!

AddPlayerHP:
  clc                                             ; add current value onto A
  adc PlayerHP                                    ;
  bcc @Store                                      ; if we're not overflowing, continue
  lda #109                                        ; otherwise cap value
  jmp @Update                                     ;
@Store:
  cmp #110                                        ; check if we have too much
  bcc @Update                                     ; if not - update
  lda #109                                        ; otherwise set capped value
@Update:
  sta PlayerHP                                    ; update resource
  jsr UpdateHPDisplay                             ; and update the background tiles
  rts                                             ; done!

AddPlayerMana:
  clc                                             ; add current value onto A
  adc PlayerMP                                    ;
  bcc @Store                                      ; if we're not overflowing, continue
  lda #109                                        ; otherwise cap value
  jmp @Update                                     ;
@Store:
  cmp #110                                        ; check if we have too much
  bcc @Update                                     ; if not - update
  lda #109                                        ; otherwise set capped value
@Update:
  sta PlayerMP                                    ; update resource
  jsr UpdateMPDisplay                             ; and update the background tiles
  rts                                             ; done!

AddPlayerGold:
  clc                                             ; add current value onto A
  adc PlayerGold                                  ;
  bcc @Store                                      ; if we're not overflowing, continue
  lda #109                                        ; otherwise cap value
  jmp @Update                                     ;
@Store:
  cmp #110                                        ; check if we have too much
  bcc @Update                                     ; if not - update
  lda #109                                        ; otherwise set capped value
@Update:
  sta PlayerGold                                  ; update resource
  jsr UpdateGoldDisplay                           ; and update the background tiles
  rts                                             ; done!

RemovePlayerGold:
  @Tmp8 = $8
  sta @Tmp8                                       ; store value to decrement
  lda PlayerGold                                  ; subtract value from current
  sec                                             ;
  sbc @Tmp8                                       ;
  bcc @Done                                       ; if we would drop under 0, fail
  sta PlayerGold                                  ; update resource
  jsr UpdateGoldDisplay                           ; and update the background tiles
  sec                                             ; mark success
@Done:
  rts                                             ; done!

AddPlayerKey:
  inc PlayerKeys                                  ; give player a new key
  jsr UpdateKeysDisplay                            ; and update the background tiles
  clc                                             ; mark success
  rts                                             ; done!

AddPlayerKeys:
  clc                                             ; add current value onto A
  adc PlayerKeys                                  ;
  bcc @Store                                      ; if we're not overflowing, continue
  lda #109                                        ; otherwise cap value
  jmp @Update                                     ;
@Store:
  cmp #110                                        ; check if we have too much
  bcc @Update                                     ; if not - update
  lda #109                                        ; otherwise set capped value
@Update:
  sta PlayerKeys                                  ; update resource
  jsr UpdateKeysDisplay                           ; and update the background tiles
  rts                                             ; done!

UsePlayerKey:
  lda PlayerKeys                                  ; check if we have keys
  beq :+                                          ; skip ahead if we do not
  dec PlayerKeys                                  ; yep - remove a key
  jsr UpdateKeysDisplay                            ; check so we're in a safe range of keys
  clc                                             ; mark success
  rts                                             ; done!
: sec                                             ; we have no keys, mark failure
  RTS                                             ; done!

RunEnemyEntities:
  lda CurrentAreaY                                ; check if we're in the menu scenes (pause, shop, home)
  cmp #$10                                        ;
  bne :+                                          ; if not - continue
  rts                                             ; otherwise we're done
: lda SelectedBank3                               ; use enemy gfx to determine if we are in a boss encounter
  cmp #$30                                        ;
  bcc :+                                          ; if not, skip ahead
  JMP $E901                                       ;  1E889 E889 . 4C 01 E9        
: LDA R_00E9                                      ;  1E88C E88C C A5 E9           F:001373
  ASL                                             ;  1E88E E88E C 0A              F:001373
  CLC                                             ;  1E88F E88F C 18              F:001373
  ADC R_00E9                                      ;  1E890 E890 C 65 E9           F:001373
  STA ActiveEntity                                      ;  1E892 E892 C 85 E3           F:001373
  CLC                                             ;  1E894 E894 C 18              F:001373
  ADC #$3                                         ;  1E895 E895 C 69 03           F:001373
  STA R_00E4                                      ;  1E897 E897 C 85 E4           F:001373
  LDA ActiveEntity                                      ;  1E899 E899 C A5 E3           F:001373
  ASL                                             ;  1E89B E89B C 0A              F:001373
  ASL                                             ;  1E89C E89C C 0A              F:001373
  ASL                                             ;  1E89D E89D C 0A              F:001373
  ASL                                             ;  1E89E E89E C 0A              F:001373
  STA WorksetPtr                                  ;  1E89F E89F C 85 E5           F:001373
  CLC                                             ;  1E8A1 E8A1 C 18              F:001373
  ADC #$20                                        ;  1E8A2 E8A2 C 69 20           F:001373
  STA ActiveEntityAreaDataPtr                     ;  1E8A4 E8A4 C 85 E7           F:001373
  lda #$4                                         ; the entity data is always in $400
  sta WorksetPtr+1                                ;
  lda AreaDataPtr+1                               ; copy base pointer to area data
  sta ActiveEntityAreaDataPtr+1                   ;
B_15_1E8AE:
  JSR CopyDataToWorkset                                  ;  1E8AE E8AE C 20 8F E9        F:001373
  LDA Workset+Ent_State                                      ;  1E8B1 E8B1 C A5 EE           F:001373
  BEQ B_15_1E8CB                                  ;  1E8B3 E8B3 C F0 16           F:001373
  BMI B_15_1E8D7                                  ;  1E8B5 E8B5 C 30 20           F:001376
  CMP #$1                                         ;  1E8B7 E8B7 C C9 01           F:001376
  BEQ B_15_1E8C5                                  ;  1E8B9 E8B9 C F0 0A           F:001376
  CMP #$18                                        ;  1E8BB E8BB C C9 18           F:001376
  BCS B_15_1E8D1                                  ;  1E8BD E8BD C B0 12           F:001376
  JSR L_15_1EABF                                  ;  1E8BF E8BF C 20 BF EA        F:027025
  JMP L_15_1E8DA                                  ;  1E8C2 E8C2 C 4C DA E8        F:027025

B_15_1E8C5:
  JSR RunEntityRoutine                                  ;  1E8C5 E8C5 C 20 94 EA        F:001379
  JMP L_15_1E8DA                                  ;  1E8C8 E8C8 C 4C DA E8        F:001379

B_15_1E8CB:
  JSR L_15_1E9A5                                  ;  1E8CB E8CB C 20 A5 E9        F:001373
  JMP L_15_1E8DA                                  ;  1E8CE E8CE C 4C DA E8        F:001373

B_15_1E8D1:
  JSR L_15_1EA2E                                  ;  1E8D1 E8D1 C 20 2E EA        F:001376
  JMP L_15_1E8DA                                  ;  1E8D4 E8D4 C 4C DA E8        F:001376

B_15_1E8D7:
  JSR L_15_1EF1C                                  ;  1E8D7 E8D7 C 20 1C EF        F:026947
L_15_1E8DA:
  JSR CopyWorksetToData                                  ;  1E8DA E8DA C 20 9A E9        F:001373
  INC ActiveEntity                                      ;  1E8DD E8DD C E6 E3           F:001373
  LDA WorksetPtr                                      ;  1E8DF E8DF C A5 E5           F:001373
  CLC                                             ;  1E8E1 E8E1 C 18              F:001373
  ADC #$10                                        ;  1E8E2 E8E2 C 69 10           F:001373
  STA WorksetPtr                                      ;  1E8E4 E8E4 C 85 E5           F:001373
  LDA ActiveEntityAreaDataPtr                                      ;  1E8E6 E8E6 C A5 E7           F:001373
  CLC                                             ;  1E8E8 E8E8 C 18              F:001373
  ADC #$10                                        ;  1E8E9 E8E9 C 69 10           F:001373
  STA ActiveEntityAreaDataPtr                                      ;  1E8EB E8EB C 85 E7           F:001373
  LDA ActiveEntity                                      ;  1E8ED E8ED C A5 E3           F:001373
  CMP R_00E4                                      ;  1E8EF E8EF C C5 E4           F:001373
  BCC B_15_1E8AE                                  ;  1E8F1 E8F1 C 90 BB           F:001373
  LDA R_00E9                                      ;  1E8F3 E8F3 C A5 E9           F:001373
  CLC                                             ;  1E8F5 E8F5 C 18              F:001373
  ADC #$1                                         ;  1E8F6 E8F6 C 69 01           F:001373
  CMP #$3                                         ;  1E8F8 E8F8 C C9 03           F:001373
  BCC B_15_1E8FE                                  ;  1E8FA E8FA C 90 02           F:001373
  LDA #$0                                         ;  1E8FC E8FC C A9 00           F:001375
B_15_1E8FE:
  STA R_00E9                                      ;  1E8FE E8FE C 85 E9           F:001373
  RTS                                             ;  1E900 E900 C 60              F:001373

.byte $A5,$E9,$29,$01,$F0,$03,$4C,$45             ;  1E901 E901 ........ ??)???LE 
.byte $E9,$A9,$00,$85,$E5,$A9,$04,$85             ;  1E909 E909 ........ ???????? 
.byte $E6,$A9,$00,$85,$E3,$A9,$20,$85             ;  1E911 E911 ........ ?????? ? 
.byte $E7,$A5,$78,$85,$E8,$20,$8F,$E9             ;  1E919 E919 ........ ??x?? ?? 
.byte $A5,$EE,$F0,$14,$10,$0C,$20,$30             ;  1E921 E921 ........ ?????? 0 
.byte $F4,$20,$3B,$F5,$20,$52,$F5,$4C             ;  1E929 E929 ........ ? ;? R?L 
.byte $3C,$E9,$20,$B0,$F3,$4C,$3C,$E9             ;  1E931 E931 ........ <? ??L<? 
.byte $20,$49,$F3,$20,$9A,$E9,$20,$5E             ;  1E939 E939 ........  I? ?? ^ 
.byte $F5,$4C,$88,$E9,$A9,$04,$85,$E3             ;  1E941 E941 ........ ?L?????? 
.byte $A9,$40,$85,$E5,$A9,$04,$85,$E6             ;  1E949 E949 ........ ?@?????? 
.byte $A9,$60,$85,$E7,$A5,$78,$85,$E8             ;  1E951 E951 ........ ?`???x?? 
.byte $20,$8F,$E9,$A5,$EE,$F0,$08,$30             ;  1E959 E959 ........  ??????0 
.byte $06,$20,$94,$EA,$4C,$6F,$E9,$A9             ;  1E961 E961 ........ ? ??Lo?? 
.byte $00,$85,$EE,$20,$4F,$EA,$20,$9A             ;  1E969 E969 ........ ??? O? ? 
.byte $E9,$E6,$E3,$A5,$E5,$18,$69,$10             ;  1E971 E971 ........ ??????i? 
.byte $85,$E5,$A5,$E7,$18,$69,$10,$85             ;  1E979 E979 ........ ?????i?? 
.byte $E7,$A5,$E3,$C9,$09,$90,$D1,$A5             ;  1E981 E981 ........ ???????? 
.byte $E9,$49,$01,$85,$E9,$60                     ;  1E989 E989 ......   ?I???`   

CopyDataToWorkset:
  ldy #$F                                         ; copy $10 bytes to workset
: lda (WorksetPtr),Y                              ;
  sta a:Workset,Y                                 ;
  dey                                             ;
  bpl :-                                          ;
  rts                                             ; done!

CopyWorksetToData:
  ldy #$F                                         ; copy $10 bytes from workset
: lda a:Workset,Y                                 ;
  sta (WorksetPtr),Y                              ;
  dey                                             ;
  bpl :-                                          ;
  rts                                             ; done!

L_15_1E9A5:
  DEC Workset+Ent_AnimTimer                                      ;  1E9A5 E9A5 C C6 F3           F:001373
  LDX Workset+Ent_AnimTimer                                      ;  1E9A7 E9A7 C A6 F3           F:001373
  CPX #$3C                                        ;  1E9A9 E9A9 C E0 3C           F:001373
  BCS B_15_1E9E6                                  ;  1E9AB E9AB C B0 39           F:001373
  LDY #$2                                         ;  1E9AD E9AD C A0 02           F:001373
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1E9AF E9AF C B1 E7           F:001373
  INY                                             ;  1E9B1 E9B1 C C8              F:001373
  ORA (ActiveEntityAreaDataPtr),Y                                  ;  1E9B2 E9B2 C 11 E7           F:001373
  BNE B_15_1E9CB                                  ;  1E9B4 E9B4 C D0 15           F:001373
  LDA #$C                                         ;  1E9B6 E9B6 C A9 0C           F:007537
  JSR StepRNG                                  ;  1E9B8 E9B8 C 20 64 CC        F:007537
  ASL                                             ;  1E9BB E9BB C 0A              F:007537
  ASL                                             ;  1E9BC E9BC C 0A              F:007537
  ASL                                             ;  1E9BD E9BD C 0A              F:007537
  ASL                                             ;  1E9BE E9BE C 0A              F:007537
  STA TmpA                                      ;  1E9BF E9BF C 85 0A           F:007537
  LDA #$40                                        ;  1E9C1 E9C1 C A9 40           F:007537
  JSR StepRNG                                  ;  1E9C3 E9C3 C 20 64 CC        F:007537
  STA TmpF                                      ;  1E9C6 E9C6 C 85 0F           F:007537
  JMP L_15_1E9D6                                  ;  1E9C8 E9C8 C 4C D6 E9        F:007537

B_15_1E9CB:
  LDY #$3                                         ;  1E9CB E9CB C A0 03           F:001373
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1E9CD E9CD C B1 E7           F:001373
  STA TmpA                                      ;  1E9CF E9CF C 85 0A           F:001373
  DEY                                             ;  1E9D1 E9D1 C 88              F:001373
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1E9D2 E9D2 C B1 E7           F:001373
  STA TmpF                                      ;  1E9D4 E9D4 C 85 0F           F:001373
L_15_1E9D6:
  LDA #$0                                         ;  1E9D6 E9D6 C A9 00           F:001373
  STA TmpE                                      ;  1E9D8 E9D8 C 85 0E           F:001373
  STA BlockOffset                                      ;  1E9DA E9DA C 85 0B           F:001373
  JSR L_14_1CE7C                                  ;  1E9DC E9DC C 20 7C CE        F:001373
  BCS B_15_1E9E6                                  ;  1E9DF E9DF C B0 05           F:001373
  JSR L_15_1F23A                                  ;  1E9E1 E9E1 C 20 3A F2        F:001373
  BCC B_15_1E9E7                                  ;  1E9E4 E9E4 C 90 01           F:001373
B_15_1E9E6:
  RTS                                             ;  1E9E6 E9E6 C 60              F:001474

B_15_1E9E7:
  LDA TmpE                                      ;  1E9E7 E9E7 C A5 0E           F:001373
  STA Workset+Ent_XPx                                      ;  1E9E9 E9E9 C 85 F9           F:001373
  LDA TmpF                                      ;  1E9EB E9EB C A5 0F           F:001373
  STA Workset+Ent_XTile                                      ;  1E9ED E9ED C 85 FA           F:001373
  LDA TmpA                                      ;  1E9EF E9EF C A5 0A           F:001373
  STA Workset+Ent_YPx                                      ;  1E9F1 E9F1 C 85 FB           F:001373
  LDA #$0                                         ;  1E9F3 E9F3 C A9 00           F:001373
  STA Workset+Ent_Damage                                      ;  1E9F5 E9F5 C 85 F1           F:001373
  STA Workset+Ent_SwapBlock                                      ;  1E9F7 E9F7 C 85 F0           F:001373
  STA Workset_F4                                      ;  1E9F9 E9F9 C 85 F4           F:001373
  STA Workset_FC                                      ;  1E9FB E9FB C 85 FC           F:001373
  LDY #$4                                         ;  1E9FD E9FD C A0 04           F:001373
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1E9FF E9FF C B1 E7           F:001373
  STA Workset+Ent_HP                                      ;  1EA01 EA01 C 85 F2           F:001373
  INY                                             ;  1EA03 EA03 C C8              F:001373
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1EA04 EA04 C B1 E7           F:001373
  STA PlayerActiveStrength                                      ;  1EA06 EA06 C 85 F8           F:001373
  LDX PlayerCharacter                                      ;  1EA08 EA08 C A6 40           F:001373
  LDA #$0                                         ;  1EA0A EA0A C A9 00           F:001373
  SEC                                             ;  1EA0C EA0C C 38              F:001373
B_15_1EA0D:
  ROL                                             ;  1EA0D EA0D C 2A              F:001373
  DEX                                             ;  1EA0E EA0E C CA              F:001373
  BPL B_15_1EA0D                                  ;  1EA0F EA0F C 10 FC           F:001373
  AND EnemySpawnRate                                      ;  1EA11 EA11 C 25 41           F:001373
  BNE B_15_1EA1D                                  ;  1EA13 EA13 C D0 08           F:001373
  ASL PlayerActiveStrength                                      ;  1EA15 EA15 . 06 F8           
  BCC B_15_1EA1D                                  ;  1EA17 EA17 . 90 04           
  LDA #$FF                                        ;  1EA19 EA19 . A9 FF           
  STA PlayerActiveStrength                                      ;  1EA1B EA1B . 85 F8           
B_15_1EA1D:
  LDA #$7F                                        ;  1EA1D EA1D C A9 7F           F:001373
  STA Workset+Ent_State                                      ;  1EA1F EA1F C 85 EE           F:001373
  LDA #$F9                                        ;  1EA21 EA21 C A9 F9           F:001373
  STA Workset+Ent_Gfx                                      ;  1EA23 EA23 C 85 ED           F:001373
  LDA #$1                                         ;  1EA25 EA25 C A9 01           F:001373
  STA Workset+Ent_SprAttr                                      ;  1EA27 EA27 C 85 EF           F:001373
  LDA Workset+Ent_AnimTimer                                      ;  1EA29 EA29 C A5 F3           F:001373
  JMP L_15_1EA30                                  ;  1EA2B EA2B C 4C 30 EA        F:001373

L_15_1EA2E:
  DEC Workset+Ent_AnimTimer                                      ;  1EA2E EA2E C C6 F3           F:001376
L_15_1EA30:
  BNE B_15_1EA42                                  ;  1EA30 EA30 C D0 10           F:001373
  LDA #$1                                         ;  1EA32 EA32 C A9 01           F:001376
  STA Workset+Ent_State                                      ;  1EA34 EA34 C 85 EE           F:001376
  LDY #$0                                         ;  1EA36 EA36 C A0 00           F:001376
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1EA38 EA38 C B1 E7           F:001376
  STA Workset+Ent_Gfx                                      ;  1EA3A EA3A C 85 ED           F:001376
  INY                                             ;  1EA3C EA3C C C8              F:001376
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1EA3D EA3D C B1 E7           F:001376
  STA Workset+Ent_SprAttr                                      ;  1EA3F EA3F C 85 EF           F:001376
  RTS                                             ;  1EA41 EA41 C 60              F:001376

B_15_1EA42:
  LDA Workset+Ent_AnimTimer                                      ;  1EA42 EA42 C A5 F3           F:001373
  AND #$3                                         ;  1EA44 EA44 C 29 03           F:001373
  BNE B_15_1EA4E                                  ;  1EA46 EA46 C D0 06           F:001373
  LDA Workset+Ent_SprAttr                                      ;  1EA48 EA48 C A5 EF           F:002217
  EOR #$40                                        ;  1EA4A EA4A C 49 40           F:002217
  STA Workset+Ent_SprAttr                                      ;  1EA4C EA4C C 85 EF           F:002217
B_15_1EA4E:
  RTS                                             ;  1EA4E EA4E C 60              F:001373

.byte $A9,$1E,$20,$64,$CC,$AA,$D0,$3C             ;  1EA4F EA4F ........ ?? d???< 
.byte $A2,$03,$A0,$03,$AD,$02
.byte $04,$29             ;  1EA57 EA57 ........ ???????) 
.byte $40,$F0,$02,$A0,$13,$B9,$0C,$04             ;  1EA5F EA5F ........ @??????? 
.byte $95,$F9,$88,$CA,$10,$F7,$A9,$00             ;  1EA67 EA67 ........ ???????? 
.byte $85,$F1,$85,$F0,$85,$F4,$A0,$04             ;  1EA6F EA6F ........ ???????? 
.byte $B1,$E7,$85,$F2,$C8,$B1,$E7,$85             ;  1EA77 EA77 ........ ???????? 
.byte $F8,$A9,$01,$85,$EE,$A9,$81,$85             ;  1EA7F EA7F ........ ???????? 
.byte $ED,$A9,$04,$20,$64,$CC,$85,$EF             ;  1EA87 EA87 ........ ??? d??? 
.byte $A9,$80,$85,$F1,$60                         ;  1EA8F EA8F .....    ????`    

RunEntityRoutine:
  ldy #$8                                         ; fetch routine
  lda (ActiveEntityAreaDataPtr),y                                  ;
  cmp #$9                                         ; make sure it's in range
  bcc :+                                          ;
  lda #$0                                         ; otherwise use the first handler
: asl a                                           ;
  tax                                             ;
  lda @Routines,X                                 ; fetch routine
  sta TmpE                                      ;
  lda @Routines+1,X                               ;
  sta TmpF                                    ;
  jmp (TmpE)                                    ; and run it!

@Routines:
.addr L_15_1EAFD                                  ;
.addr L_15_1EB69                                  ;
.addr L_15_1EB90                                  ;
.addr L_15_1EBD8                                  ;
.addr L_15_1EC76                                  ;
.addr L_15_1ECA8                                  ;
.addr L_15_1ED2A                                  ;
.addr L_15_1ED6F                                  ;
.addr L_15_1ED95                                  ;

L_15_1EABF:
  LDA Workset+Ent_SwapBlock                                      ;  1EABF EABF C A5 F0           F:027025
  BNE B_15_1EACF                                  ;  1EAC1 EAC1 C D0 0C           F:027025
  LDA Workset+Ent_Damage                                      ;  1EAC3 EAC3 C A5 F1           F:027025
  BEQ B_15_1EAD7                                  ;  1EAC5 EAC5 C F0 10           F:027025
  JSR L_15_1EEDA                                  ;  1EAC7 EAC7 C 20 DA EE        F:028247
  BCS B_15_1EAD7                                  ;  1EACA EACA C B0 0B           F:028247
  JSR L_15_1EF04                                  ;  1EACC EACC C 20 04 EF        F:028247
B_15_1EACF:
  JSR L_15_1EEBB                                  ;  1EACF EACF C 20 BB EE        F:007053
  BCS B_15_1EAD7                                  ;  1EAD2 EAD2 C B0 03           F:007053
  JSR L_15_1EF04                                  ;  1EAD4 EAD4 C 20 04 EF        F:007053
B_15_1EAD7:
  LDX Workset+Ent_AnimTimer                                      ;  1EAD7 EAD7 C A6 F3           F:027025
  DEX                                             ;  1EAD9 EAD9 C CA              F:027025
  BNE B_15_1EAE5                                  ;  1EADA EADA C D0 09           F:027025
  LDA #$0                                         ;  1EADC EADC . A9 00           
  STA Workset+Ent_State                                      ;  1EADE EADE . 85 EE           
  LDA #$F0                                        ;  1EAE0 EAE0 . A9 F0           
  STA Workset+Ent_AnimTimer                                      ;  1EAE2 EAE2 . 85 F3           
  RTS                                             ;  1EAE4 EAE4 . 60              

B_15_1EAE5:
  STX Workset+Ent_AnimTimer                                      ;  1EAE5 EAE5 C 86 F3           F:027025
  CPX #$3C                                        ;  1EAE7 EAE7 C E0 3C           F:027025
  BCS B_15_1EAF9                                  ;  1EAE9 EAE9 C B0 0E           F:027025
  LDX #$EF                                        ;  1EAEB EAEB C A2 EF           F:026559
  LDA Workset+Ent_YPx                                      ;  1EAED EAED C A5 FB           F:026559
  CMP #$EF                                        ;  1EAEF EAEF C C9 EF           F:026559
  BNE B_15_1EAF5                                  ;  1EAF1 EAF1 C D0 02           F:026559
  LDX Workset_FC                                      ;  1EAF3 EAF3 C A6 FC           F:026562
B_15_1EAF5:
  STX Workset+Ent_YPx                                      ;  1EAF5 EAF5 C 86 FB           F:026559
  STA Workset_FC                                      ;  1EAF7 EAF7 C 85 FC           F:026559
B_15_1EAF9:
  JSR L_15_1F179                                  ;  1EAF9 EAF9 C 20 79 F1        F:027025
  RTS                                             ;  1EAFC EAFC C 60              F:027025

L_15_1EAFD:
  LDA Workset+Ent_AnimTimer                                      ;  1EAFD EAFD C A5 F3           F:001379
  CMP #$20                                        ;  1EAFF EAFF C C9 20           F:001379
  BCS B_15_1EB0D                                  ;  1EB01 EB01 C B0 0A           F:001379
  LDA Workset+Ent_Damage                                      ;  1EB03 EB03 C A5 F1           F:001379
  BNE B_15_1EB2C                                  ;  1EB05 EB05 C D0 25           F:001379
  LDA Workset+Ent_XPxSpeed                                      ;  1EB07 EB07 C A5 F5           F:001379
  ORA Workset+Ent_YPxSpeed                                      ;  1EB09 EB09 C 05 F7           F:001379
  BNE B_15_1EB2C                                  ;  1EB0B EB0B C D0 1F           F:001379
B_15_1EB0D:
  LDA #$0                                         ;  1EB0D EB0D C A9 00           F:001382
  STA Workset+Ent_AnimTimer                                      ;  1EB0F EB0F C 85 F3           F:001382
  JSR L_15_1EEA6                                  ;  1EB11 EB11 C 20 A6 EE        F:001382
  LDA #$6                                         ;  1EB14 EB14 C A9 06           F:001382
  JSR StepRNG                                  ;  1EB16 EB16 C 20 64 CC        F:001382
  CLC                                             ;  1EB19 EB19 C 18              F:001382
  ADC #$1                                         ;  1EB1A EB1A C 69 01           F:001382
  STA Workset+Ent_XTileSpeed                                      ;  1EB1C EB1C C 85 F6           F:001382
  LDA #$4                                         ;  1EB1E EB1E C A9 04           F:001382
  JSR StepRNG                                  ;  1EB20 EB20 C 20 64 CC        F:001382
  TAX                                             ;  1EB23 EB23 C AA              F:001382
  BNE B_15_1EB2C                                  ;  1EB24 EB24 C D0 06           F:001382
  LDA #$80                                        ;  1EB26 EB26 C A9 80           F:001384
  ORA Workset_F4                                      ;  1EB28 EB28 C 05 F4           F:001384
  STA Workset_F4                                      ;  1EB2A EB2A C 85 F4           F:001384
B_15_1EB2C:
  LDA Workset+Ent_XTileSpeed                                      ;  1EB2C EB2C C A5 F6           F:001379
  PHA                                             ;  1EB2E EB2E C 48              F:001379
  TAY                                             ;  1EB2F EB2F C A8              F:001379
  LDA Workset_F4                                      ;  1EB30 EB30 C A5 F4           F:001379
  JSR SetWorksetDirectionSpeed                                  ;  1EB32 EB32 C 20 70 CD        F:001379
  LDA Workset+Ent_SwapBlock                                      ;  1EB35 EB35 C A5 F0           F:001379
  BNE B_15_1EB55                                  ;  1EB37 EB37 C D0 1C           F:001379
  LDA Workset+Ent_Damage                                      ;  1EB39 EB39 C A5 F1           F:001379
  BNE B_15_1EB41                                  ;  1EB3B EB3B C D0 04           F:001379
  LDA Workset_F4                                      ;  1EB3D EB3D C A5 F4           F:001379
  BPL B_15_1EB46                                  ;  1EB3F EB3F C 10 05           F:001379
B_15_1EB41:
  JSR L_15_1EEDA                                  ;  1EB41 EB41 C 20 DA EE        F:001384
  BCC B_15_1EB5A                                  ;  1EB44 EB44 C 90 14           F:001384
B_15_1EB46:
  LDA #$0                                         ;  1EB46 EB46 C A9 00           F:001379
  STA Workset+Ent_Damage                                      ;  1EB48 EB48 C 85 F1           F:001379
  JSR L_15_1F0E1                                  ;  1EB4A EB4A C 20 E1 F0        F:001379
  BCC B_15_1EB5A                                  ;  1EB4D EB4D C 90 0B           F:001379
  JSR L_15_1EF11                                  ;  1EB4F EB4F C 20 11 EF        F:001383
  JMP L_15_1EB5D                                  ;  1EB52 EB52 C 4C 5D EB        F:001383

B_15_1EB55:
  JSR L_15_1EEBB                                  ;  1EB55 EB55 C 20 BB EE        F:001405
  BCS L_15_1EB5D                                  ;  1EB58 EB58 C B0 03           F:001405
B_15_1EB5A:
  JSR L_15_1EF04                                  ;  1EB5A EB5A C 20 04 EF        F:001379
L_15_1EB5D:
  JSR L_15_1F179                                  ;  1EB5D EB5D C 20 79 F1        F:001379
  JSR L_15_1F01E                                  ;  1EB60 EB60 C 20 1E F0        F:001379
  PLA                                             ;  1EB63 EB63 C 68              F:001379
  STA Workset+Ent_XTileSpeed                                      ;  1EB64 EB64 C 85 F6           F:001379
  JMP DoNothing                                  ;  1EB66 EB66 C 4C F0 EF        F:001379

L_15_1EB69:
  LDA Workset+Ent_XPxSpeed                                      ;  1EB69 EB69 C A5 F5           F:005264
  ORA Workset+Ent_YPxSpeed                                      ;  1EB6B EB6B C 05 F7           F:005264
  BNE B_15_1EB72                                  ;  1EB6D EB6D C D0 03           F:005264
  JSR L_15_1EE9A                                  ;  1EB6F EB6F C 20 9A EE        F:005267
B_15_1EB72:
  LDY #$9                                         ;  1EB72 EB72 C A0 09           F:005264
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1EB74 EB74 C B1 E7           F:005264
  TAY                                             ;  1EB76 EB76 C A8              F:005264
  LDA Workset_F4                                      ;  1EB77 EB77 C A5 F4           F:005264
  JSR SetWorksetDirectionSpeed                                  ;  1EB79 EB79 C 20 70 CD        F:005264
  JSR L_15_1F11B                                  ;  1EB7C EB7C C 20 1B F1        F:005264
  BCC B_15_1EB87                                  ;  1EB7F EB7F C 90 06           F:005264
  JSR L_15_1EF11                                  ;  1EB81 EB81 C 20 11 EF        F:005651
  JMP L_15_1EB8A                                  ;  1EB84 EB84 C 4C 8A EB        F:005651

B_15_1EB87:
  JSR L_15_1EF04                                  ;  1EB87 EB87 C 20 04 EF        F:005264
L_15_1EB8A:
  JSR L_15_1F01E                                  ;  1EB8A EB8A C 20 1E F0        F:005264
  JMP DoNothing                                  ;  1EB8D EB8D C 4C F0 EF        F:005264

L_15_1EB90:
  LDA Workset+Ent_XPxSpeed                                      ;  1EB90 EB90 C A5 F5           F:001379
  ORA Workset+Ent_YPxSpeed                                      ;  1EB92 EB92 C 05 F7           F:001379
  BNE B_15_1EB99                                  ;  1EB94 EB94 C D0 03           F:001379
  JSR L_15_1EE8D                                  ;  1EB96 EB96 C 20 8D EE        F:001382
B_15_1EB99:
  LDA Workset+Ent_SwapBlock                                      ;  1EB99 EB99 C A5 F0           F:001379
  BEQ B_15_1EBA5                                  ;  1EB9B EB9B C F0 08           F:001379
  JSR L_15_1EEBB                                  ;  1EB9D EB9D C 20 BB EE        F:036344
  BCC B_15_1EBC6                                  ;  1EBA0 EBA0 C 90 24           F:036344
  JMP $EBCF                                       ;  1EBA2 EBA2 . 4C CF EB        

B_15_1EBA5:
  LDY #$9                                         ;  1EBA5 EBA5 C A0 09           F:001379
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1EBA7 EBA7 C B1 E7           F:001379
  TAY                                             ;  1EBA9 EBA9 C A8              F:001379
  LDA Workset_F4                                      ;  1EBAA EBAA C A5 F4           F:001379
  JSR SetWorksetDirectionSpeed                                  ;  1EBAC EBAC C 20 70 CD        F:001379
  JSR L_15_1F0E1                                  ;  1EBAF EBAF C 20 E1 F0        F:001379
  BCS B_15_1EBCC                                  ;  1EBB2 EBB2 C B0 18           F:001379
  LDY #$1                                         ;  1EBB4 EBB4 C A0 01           F:001379
  JSR CheckIfBlockIsSolid                                  ;  1EBB6 EBB6 C 20 33 F2        F:001379
  BCC B_15_1EBCC                                  ;  1EBB9 EBB9 C 90 11           F:001379
  LDA TmpE                                      ;  1EBBB EBBB C A5 0E           F:001379
  BEQ B_15_1EBC6                                  ;  1EBBD EBBD C F0 07           F:001379
  LDY #$D                                         ;  1EBBF EBBF C A0 0D           F:001382
  JSR CheckIfBlockIsSolid                                  ;  1EBC1 EBC1 C 20 33 F2        F:001382
  BCC B_15_1EBCC                                  ;  1EBC4 EBC4 C 90 06           F:001382
B_15_1EBC6:
  JSR L_15_1EF04                                  ;  1EBC6 EBC6 C 20 04 EF        F:001379
  JMP L_15_1EBCF                                  ;  1EBC9 EBC9 C 4C CF EB        F:001379

B_15_1EBCC:
  JSR L_15_1EF11                                  ;  1EBCC EBCC C 20 11 EF        F:001382
L_15_1EBCF:
  JSR L_15_1F179                                  ;  1EBCF EBCF C 20 79 F1        F:001379
  JSR L_15_1F01E                                  ;  1EBD2 EBD2 C 20 1E F0        F:001379
  JMP DoNothing                                  ;  1EBD5 EBD5 C 4C F0 EF        F:001379

L_15_1EBD8:
  LDA Workset_F4                                      ;  1EBD8 EBD8 C A5 F4           F:003323
  AND #$F                                         ;  1EBDA EBDA C 29 0F           F:003323
  STA Workset_F4                                      ;  1EBDC EBDC C 85 F4           F:003323
  LDA Workset+Ent_XPxSpeed                                      ;  1EBDE EBDE C A5 F5           F:003323
  ORA Workset+Ent_YPxSpeed                                      ;  1EBE0 EBE0 C 05 F7           F:003323
  BNE B_15_1EC2E                                  ;  1EBE2 EBE2 C D0 4A           F:003323
  LDA Workset+Ent_XPx                                      ;  1EBE4 EBE4 C A5 F9           F:003326
  BNE B_15_1EC02                                  ;  1EBE6 EBE6 C D0 1A           F:003326
  LDA Workset+Ent_XTile                                      ;  1EBE8 EBE8 C A5 FA           F:003326
  STA PositionToBlock_XTile                                      ;  1EBEA EBEA C 85 0C           F:003326
  LDA Workset+Ent_YPx                                      ;  1EBEC EBEC C A5 FB           F:003326
  STA PositionToBlock_YPx                                      ;  1EBEE EBEE C 85 0D           F:003326
  JSR PositionToBlock                                  ;  1EBF0 EBF0 C 20 54 CA        F:003326
  LDY #$0                                         ;  1EBF3 EBF3 C A0 00           F:003326
  LDA (BlockPtrLo),Y                                  ;  1EBF5 EBF5 C B1 0C           F:003326
  AND #$3F                                        ;  1EBF7 EBF7 C 29 3F           F:003326
  BEQ B_15_1EC34                                  ;  1EBF9 EBF9 C F0 39           F:003326
  INY                                             ;  1EBFB EBFB C C8              F:003326
  LDA (BlockPtrLo),Y                                  ;  1EBFC EBFC C B1 0C           F:003326
  AND #$3F                                        ;  1EBFE EBFE C 29 3F           F:003326
  BEQ B_15_1EC34                                  ;  1EC00 EC00 C F0 32           F:003326
B_15_1EC02:
  LDA Workset_F4                                      ;  1EC02 EC02 C A5 F4           F:003326
  AND #$3                                         ;  1EC04 EC04 C 29 03           F:003326
  BNE B_15_1EC0C                                  ;  1EC06 EC06 C D0 04           F:003326
  LDA #$1                                         ;  1EC08 EC08 C A9 01           F:003326
  STA Workset_F4                                      ;  1EC0A EC0A C 85 F4           F:003326
B_15_1EC0C:
  LDX Workset+Ent_AnimTimer                                      ;  1EC0C EC0C C A6 F3           F:003326
  LDA #$0                                         ;  1EC0E EC0E C A9 00           F:003326
  STA Workset+Ent_AnimTimer                                      ;  1EC10 EC10 C 85 F3           F:003326
  DEX                                             ;  1EC12 EC12 C CA              F:003326
  BNE B_15_1EC22                                  ;  1EC13 EC13 C D0 0D           F:003326
  LDA Workset_F4                                      ;  1EC15 EC15 C A5 F4           F:003326
  AND #$3                                         ;  1EC17 EC17 C 29 03           F:003326
  BEQ B_15_1EC34                                  ;  1EC19 EC19 C F0 19           F:003326
  EOR #$3                                         ;  1EC1B EC1B C 49 03           F:003326
  STA Workset_F4                                      ;  1EC1D EC1D C 85 F4           F:003326
  JMP L_15_1EC3B                                  ;  1EC1F EC1F C 4C 3B EC        F:003326

B_15_1EC22:
  JSR L_15_1EE19                                  ;  1EC22 EC22 C 20 19 EE        F:003354
  LDA #$80                                        ;  1EC25 EC25 C A9 80           F:003354
  ORA Workset_F4                                      ;  1EC27 EC27 C 05 F4           F:003354
  STA Workset_F4                                      ;  1EC29 EC29 C 85 F4           F:003354
  JMP L_15_1EC3B                                  ;  1EC2B EC2B C 4C 3B EC        F:003354

B_15_1EC2E:
  LDA Workset+Ent_AnimTimer                                      ;  1EC2E EC2E C A5 F3           F:003323
  CMP #$10                                        ;  1EC30 EC30 C C9 10           F:003323
  BCC L_15_1EC3B                                  ;  1EC32 EC32 C 90 07           F:003323
B_15_1EC34:
  LDA #$0                                         ;  1EC34 EC34 C A9 00           F:003374
  STA Workset+Ent_AnimTimer                                      ;  1EC36 EC36 C 85 F3           F:003374
  JSR L_15_1EE19                                  ;  1EC38 EC38 C 20 19 EE        F:003374
L_15_1EC3B:
  LDY #$9                                         ;  1EC3B EC3B C A0 09           F:003323
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1EC3D EC3D C B1 E7           F:003323
  TAY                                             ;  1EC3F EC3F C A8              F:003323
  LDA Workset_F4                                      ;  1EC40 EC40 C A5 F4           F:003323
  JSR SetWorksetDirectionSpeed                                  ;  1EC42 EC42 C 20 70 CD        F:003323
  LDA Workset+Ent_SwapBlock                                      ;  1EC45 EC45 C A5 F0           F:003323
  BNE B_15_1EC65                                  ;  1EC47 EC47 C D0 1C           F:003323
  LDA Workset+Ent_Damage                                      ;  1EC49 EC49 C A5 F1           F:003323
  BNE B_15_1EC51                                  ;  1EC4B EC4B C D0 04           F:003323
  LDA Workset_F4                                      ;  1EC4D EC4D C A5 F4           F:003323
  BPL B_15_1EC56                                  ;  1EC4F EC4F C 10 05           F:003323
B_15_1EC51:
  JSR L_15_1EEDA                                  ;  1EC51 EC51 C 20 DA EE        F:003354
  BCC B_15_1EC6A                                  ;  1EC54 EC54 C 90 14           F:003354
B_15_1EC56:
  LDA #$0                                         ;  1EC56 EC56 C A9 00           F:003323
  STA Workset+Ent_Damage                                      ;  1EC58 EC58 C 85 F1           F:003323
  JSR L_15_1F0E1                                  ;  1EC5A EC5A C 20 E1 F0        F:003323
  BCC B_15_1EC6A                                  ;  1EC5D EC5D C 90 0B           F:003323
  JSR L_15_1EF11                                  ;  1EC5F EC5F C 20 11 EF        F:003351
  JMP L_15_1EC6D                                  ;  1EC62 EC62 C 4C 6D EC        F:003351

B_15_1EC65:
  JSR L_15_1EEBB                                  ;  1EC65 EC65 C 20 BB EE        F:003399
  BCS L_15_1EC6D                                  ;  1EC68 EC68 C B0 03           F:003399
B_15_1EC6A:
  JSR L_15_1EF04                                  ;  1EC6A EC6A C 20 04 EF        F:003323
L_15_1EC6D:
  JSR L_15_1F179                                  ;  1EC6D EC6D C 20 79 F1        F:003323
  JSR L_15_1F01E                                  ;  1EC70 EC70 C 20 1E F0        F:003323
  JMP DoNothing                                  ;  1EC73 EC73 C 4C F0 EF        F:003323

L_15_1EC76:
  LDA Workset+Ent_XPxSpeed                                      ;  1EC76 EC76 C A5 F5           F:007543
  ORA Workset+Ent_YPxSpeed                                      ;  1EC78 EC78 C 05 F7           F:007543
  BEQ B_15_1EC82                                  ;  1EC7A EC7A C F0 06           F:007543
  LDA Workset+Ent_AnimTimer                                      ;  1EC7C EC7C C A5 F3           F:007543
  CMP #$20                                        ;  1EC7E EC7E C C9 20           F:007543
  BCC B_15_1EC85                                  ;  1EC80 EC80 C 90 03           F:007543
B_15_1EC82:
  JSR L_15_1EE53                                  ;  1EC82 EC82 C 20 53 EE        F:007546
B_15_1EC85:
  LDY #$9                                         ;  1EC85 EC85 C A0 09           F:007543
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1EC87 EC87 C B1 E7           F:007543
  TAY                                             ;  1EC89 EC89 C A8              F:007543
  LDA Workset_F4                                      ;  1EC8A EC8A C A5 F4           F:007543
  JSR SetWorksetDirectionSpeed                                  ;  1EC8C EC8C C 20 70 CD        F:007543
  JSR L_15_1F11B                                  ;  1EC8F EC8F C 20 1B F1        F:007543
  BCC B_15_1EC9F                                  ;  1EC92 EC92 C 90 0B           F:007543
  JSR L_15_1F2DA                                  ;  1EC94 EC94 C 20 DA F2        F:007624
  BCC B_15_1EC9F                                  ;  1EC97 EC97 C 90 06           F:007624
  JSR L_15_1EF11                                  ;  1EC99 EC99 C 20 11 EF        F:007624
  JMP L_15_1ECA2                                  ;  1EC9C EC9C C 4C A2 EC        F:007624

B_15_1EC9F:
  JSR L_15_1EF04                                  ;  1EC9F EC9F C 20 04 EF        F:007543
L_15_1ECA2:
  JSR L_15_1F01E                                  ;  1ECA2 ECA2 C 20 1E F0        F:007543
  JMP DoNothing                                  ;  1ECA5 ECA5 C 4C F0 EF        F:007543

L_15_1ECA8:
  LDA Workset+Ent_SwapBlock                                      ;  1ECA8 ECA8 C A5 F0           F:014982
  BNE B_15_1ECFA                                  ;  1ECAA ECAA C D0 4E           F:014982
  LDA Workset+Ent_Damage                                      ;  1ECAC ECAC C A5 F1           F:014982
  BNE B_15_1ED16                                  ;  1ECAE ECAE C D0 66           F:014982
  LDA Workset+Ent_XTile                                      ;  1ECB0 ECB0 C A5 FA           F:014982
  STA TmpF                                      ;  1ECB2 ECB2 C 85 0F           F:014982
  LDA Workset+Ent_XPx                                      ;  1ECB4 ECB4 C A5 F9           F:014982
  STA TmpE                                      ;  1ECB6 ECB6 C 85 0E           F:014982
  LDA Workset+Ent_YPx                                      ;  1ECB8 ECB8 C A5 FB           F:014982
  STA TmpA                                      ;  1ECBA ECBA C 85 0A           F:014982
  JSR L_15_1EDF0                                  ;  1ECBC ECBC C 20 F0 ED        F:014982
  BCS B_15_1ECC8                                  ;  1ECBF ECBF C B0 07           F:014982
  INC Workset+Ent_SwapBlock                                      ;  1ECC1 ECC1 C E6 F0           F:014517
  INC Workset+Ent_SwapBlock                                      ;  1ECC3 ECC3 C E6 F0           F:014517
  JMP B_15_1ECFA                                  ;  1ECC5 ECC5 C 4C FA EC        F:014517

B_15_1ECC8:
  LDA Workset+Ent_XPxSpeed                                      ;  1ECC8 ECC8 C A5 F5           F:014982
  ORA Workset+Ent_YPxSpeed                                      ;  1ECCA ECCA C 05 F7           F:014982
  BNE B_15_1ECD1                                  ;  1ECCC ECCC C D0 03           F:014982
  JSR L_15_1EE8D                                  ;  1ECCE ECCE C 20 8D EE        F:014985
B_15_1ECD1:
  JSR L_14_1CE90                                  ;  1ECD1 ECD1 C 20 90 CE        F:014982
  BCS B_15_1ECED                                  ;  1ECD4 ECD4 C B0 17           F:014982
  LDY #$9                                         ;  1ECD6 ECD6 C A0 09           F:014982
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1ECD8 ECD8 C B1 E7           F:014982
  TAY                                             ;  1ECDA ECDA C A8              F:014982
  LDA Workset_F4                                      ;  1ECDB ECDB C A5 F4           F:014982
  JSR SetWorksetDirectionSpeed                                  ;  1ECDD ECDD C 20 70 CD        F:014982
  JSR L_15_1F0E1                                  ;  1ECE0 ECE0 C 20 E1 F0        F:014982
  BCS B_15_1ED21                                  ;  1ECE3 ECE3 C B0 3C           F:014982
  JSR L_15_1EDF0                                  ;  1ECE5 ECE5 C 20 F0 ED        F:014982
  BCC B_15_1ED21                                  ;  1ECE8 ECE8 C 90 37           F:014982
  JMP L_15_1ED10                                  ;  1ECEA ECEA C 4C 10 ED        F:014982

B_15_1ECED:
  LDA #$0                                         ;  1ECED ECED C A9 00           F:048362
  STA Workset+Ent_XPxSpeed                                      ;  1ECEF ECEF C 85 F5           F:048362
  STA Workset+Ent_XTileSpeed                                      ;  1ECF1 ECF1 C 85 F6           F:048362
  JSR L_15_1F179                                  ;  1ECF3 ECF3 C 20 79 F1        F:048362
  LDA Workset+Ent_SwapBlock                                      ;  1ECF6 ECF6 C A5 F0           F:048362
  BCS B_15_1ED21                                  ;  1ECF8 ECF8 C B0 27           F:048362
B_15_1ECFA:
  JSR L_15_1EEBB                                  ;  1ECFA ECFA C 20 BB EE        F:048362
  JSR L_15_1EF04                                  ;  1ECFD ECFD C 20 04 EF        F:048362
  LDA Workset+Ent_SwapBlock                                      ;  1ED00 ED00 C A5 F0           F:048362
  PHA                                             ;  1ED02 ED02 C 48              F:048362
  JSR L_15_1F179                                  ;  1ED03 ED03 C 20 79 F1        F:048362
  PLA                                             ;  1ED06 ED06 C 68              F:048362
  BCC L_15_1ED10                                  ;  1ED07 ED07 C 90 07           F:048362
  ADC #$5                                         ;  1ED09 ED09 C 69 05           F:048413
  STA Workset+Ent_Damage                                      ;  1ED0B ED0B C 85 F1           F:048413
  JMP L_15_1ED24                                  ;  1ED0D ED0D C 4C 24 ED        F:048413

L_15_1ED10:
  JSR L_15_1EF04                                  ;  1ED10 ED10 C 20 04 EF        F:014982
  JMP L_15_1ED24                                  ;  1ED13 ED13 C 4C 24 ED        F:014982

B_15_1ED16:
  JSR L_15_1EEDA                                  ;  1ED16 ED16 C 20 DA EE        F:048416
  BCS B_15_1ED21                                  ;  1ED19 ED19 C B0 06           F:048416
  JSR L_15_1EF04                                  ;  1ED1B ED1B C 20 04 EF        F:048416
  JMP L_15_1ED24                                  ;  1ED1E ED1E C 4C 24 ED        F:048416

B_15_1ED21:
  JSR L_15_1EF11                                  ;  1ED21 ED21 C 20 11 EF        F:015012
L_15_1ED24:
  JSR L_15_1F01E                                  ;  1ED24 ED24 C 20 1E F0        F:014982
  JMP DoNothing                                  ;  1ED27 ED27 C 4C F0 EF        F:014982

L_15_1ED2A:
  LDA Workset_F4                                      ;  1ED2A ED2A C A5 F4           F:007208
  BEQ B_15_1ED31                                  ;  1ED2C ED2C C F0 03           F:007208
  JMP L_15_1EBD8                                  ;  1ED2E ED2E C 4C D8 EB        F:013669

B_15_1ED31:
  LDA #$1                                         ;  1ED31 ED31 C A9 01           F:007208
  JSR L_15_1ED5D                                  ;  1ED33 ED33 C 20 5D ED        F:007208
  BCS B_15_1ED58                                  ;  1ED36 ED36 C B0 20           F:007208
  LDA #$2                                         ;  1ED38 ED38 C A9 02           F:007208
  JSR L_15_1ED5D                                  ;  1ED3A ED3A C 20 5D ED        F:007208
  BCS B_15_1ED58                                  ;  1ED3D ED3D C B0 19           F:007208
  LDA #$4                                         ;  1ED3F ED3F C A9 04           F:007208
  JSR L_15_1ED5D                                  ;  1ED41 ED41 C 20 5D ED        F:007208
  BCS B_15_1ED58                                  ;  1ED44 ED44 C B0 12           F:007208
  LDA #$8                                         ;  1ED46 ED46 C A9 08           F:007208
  JSR L_15_1ED5D                                  ;  1ED48 ED48 C 20 5D ED        F:007208
  BCS B_15_1ED58                                  ;  1ED4B ED4B C B0 0B           F:007208
  LDY #$4                                         ;  1ED4D ED4D C A0 04           F:007208
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1ED4F ED4F C B1 E7           F:007208
  STA Workset+Ent_HP                                      ;  1ED51 ED51 C 85 F2           F:007208
  LDA #$0                                         ;  1ED53 ED53 C A9 00           F:007208
  STA Workset_FC                                      ;  1ED55 ED55 C 85 FC           F:007208
  RTS                                             ;  1ED57 ED57 C 60              F:007208

B_15_1ED58:
  LDA #$1                                         ;  1ED58 ED58 C A9 01           F:013666
  STA Workset_F4                                      ;  1ED5A ED5A C 85 F4           F:013666
  RTS                                             ;  1ED5C ED5C C 60              F:013666

L_15_1ED5D:
  LDY #$1                                         ;  1ED5D ED5D C A0 01           F:007208
  JSR SetWorksetDirectionSpeed                                  ;  1ED5F ED5F C 20 70 CD        F:007208
  JSR CalcNextPosition                                  ;  1ED62 ED62 C 20 F1 EF        F:007208
  JSR L_14_1CE7C                                  ;  1ED65 ED65 C 20 7C CE        F:007208
  BCC B_15_1ED6E                                  ;  1ED68 ED68 C 90 04           F:007208
  JSR L_15_1F136                                  ;  1ED6A ED6A C 20 36 F1        F:013666
  SEC                                             ;  1ED6D ED6D C 38              F:013666
B_15_1ED6E:
  RTS                                             ;  1ED6E ED6E C 60              F:007208

L_15_1ED6F:
  LDA Workset+Ent_XPxSpeed                                      ;  1ED6F ED6F C A5 F5           F:026629
  ORA Workset+Ent_YPxSpeed                                      ;  1ED71 ED71 C 05 F7           F:026629
  BNE B_15_1ED78                                  ;  1ED73 ED73 C D0 03           F:026629
  JSR L_15_1EE9A                                  ;  1ED75 ED75 C 20 9A EE        F:026632
B_15_1ED78:
  LDY #$9                                         ;  1ED78 ED78 C A0 09           F:026629
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1ED7A ED7A C B1 E7           F:026629
  TAY                                             ;  1ED7C ED7C C A8              F:026629
  LDA Workset_F4                                      ;  1ED7D ED7D C A5 F4           F:026629
  JSR SetWorksetDirectionSpeed                                  ;  1ED7F ED7F C 20 70 CD        F:026629
  JSR L_15_1F11B                                  ;  1ED82 ED82 C 20 1B F1        F:026629
  BCC B_15_1ED91                                  ;  1ED85 ED85 C 90 0A           F:026629
  LDA R_00EA                                      ;  1ED87 ED87 C A5 EA           F:026797
  BNE B_15_1ED9A                                  ;  1ED89 ED89 C D0 0F           F:026797
  JSR L_15_1EF11                                  ;  1ED8B ED8B C 20 11 EF        F:026797
  JMP L_15_1ED94                                  ;  1ED8E ED8E C 4C 94 ED        F:026797

B_15_1ED91:
  JSR L_15_1EF04                                  ;  1ED91 ED91 C 20 04 EF        F:026629
L_15_1ED94:
  JSR L_15_1F01E                                  ;  1ED94 ED94 C 20 1E F0        F:026629
  JMP DoNothing                                  ;  1ED97 ED97 C 4C F0 EF        F:026629

B_15_1ED9A:
  LDA #$80                                        ;  1ED9A ED9A C A9 80           F:028112
  STA Workset+Ent_State                                      ;  1ED9C ED9C C 85 EE           F:028112
  RTS                                             ;  1ED9E ED9E C 60              F:028112

L_15_1ED95:
.byte $C6,$F1,$F0,$48,$A5,$F4,$D0,$06             ;  1ED9F ED9F ........ ???H???? 
.byte $20,$53,$EE,$4C,$D0,$ED,$A5,$F3             ;  1EDA7 EDA7 ........  S?L???? 
.byte $C9,$08,$90,$1D,$A5,$F4,$85,$08             ;  1EDAF EDAF ........ ???????? 
.byte $20,$53,$EE,$A5,$F4,$45,$08,$A0             ;  1EDB7 EDB7 ........  S???E?? 
.byte $00,$A2,$04,$4A,$90,$01,$C8,$CA             ;  1EDBF EDBF ........ ???J???? 
.byte $D0,$F9,$88,$F0,$04,$A5,$08,$85             ;  1EDC7 EDC7 ........ ???????? 
.byte $F4,$A0,$09,$B1,$E7,$A8,$A5,$F4             ;  1EDCF EDCF ........ ???????? 
.byte $20,$70,$CD,$20,$1B,$F1,$90,$03             ;  1EDD7 EDD7 ........  p? ???? 
.byte $4C,$EB,$ED,$20,$04,$EF,$20,$1E             ;  1EDDF EDDF ........ L?? ?? ? 
.byte $F0,$4C,$F0,$EF,$A9,$00,$85,$EE             ;  1EDE7 EDE7 ........ ?L?????? 
.byte $60                                         ;  1EDEF EDEF .        `        
L_15_1EDF0:
  LDA TmpA                                      ;  1EDF0 EDF0 C A5 0A           F:014982
  AND #$F                                         ;  1EDF2 EDF2 C 29 0F           F:014982
  BNE B_15_1EE17                                  ;  1EDF4 EDF4 C D0 21           F:014982
  LDA TmpF                                      ;  1EDF6 EDF6 C A5 0F           F:014982
  STA PositionToBlock_XTile                                      ;  1EDF8 EDF8 C 85 0C           F:014982
  LDA TmpA                                      ;  1EDFA EDFA C A5 0A           F:014982
  SEC                                             ;  1EDFC EDFC C 38              F:014982
  SBC #$10                                        ;  1EDFD EDFD C E9 10           F:014982
  STA PositionToBlock_YPx                                      ;  1EDFF EDFF C 85 0D           F:014982
  JSR PositionToBlock                                  ;  1EE01 EE01 C 20 54 CA        F:014982
  LDY #$0                                         ;  1EE04 EE04 C A0 00           F:014982
  JSR CheckIfBlockIsSolid2                                  ;  1EE06 EE06 C 20 D3 F2        F:014982
  BCC B_15_1EE17                                  ;  1EE09 EE09 C 90 0C           F:014982
  LDA TmpE                                      ;  1EE0B EE0B C A5 0E           F:014982
  BEQ B_15_1EE16                                  ;  1EE0D EE0D C F0 07           F:014982
  LDY #$C                                         ;  1EE0F EE0F C A0 0C           F:014985
  JSR CheckIfBlockIsSolid2                                  ;  1EE11 EE11 C 20 D3 F2        F:014985
  BCC B_15_1EE17                                  ;  1EE14 EE14 C 90 01           F:014985
B_15_1EE16:
  RTS                                             ;  1EE16 EE16 C 60              F:014982

B_15_1EE17:
  CLC                                             ;  1EE17 EE17 C 18              F:036487
  RTS                                             ;  1EE18 EE18 C 60              F:036487

L_15_1EE19:
  LDX #$0                                         ;  1EE19 EE19 C A2 00           F:003354
  LDA Workset+Ent_XTile                                      ;  1EE1B EE1B C A5 FA           F:003354
  SEC                                             ;  1EE1D EE1D C 38              F:003354
  SBC PlayerXTile                                      ;  1EE1E EE1E C E5 44           F:003354
  BEQ B_15_1EE26                                  ;  1EE20 EE20 C F0 04           F:003354
  INX                                             ;  1EE22 EE22 C E8              F:003354
  BCC B_15_1EE26                                  ;  1EE23 EE23 C 90 01           F:003354
  INX                                             ;  1EE25 EE25 C E8              F:003354
B_15_1EE26:
  STX Workset_F4                                      ;  1EE26 EE26 C 86 F4           F:003354
  LDA Workset+Ent_YPx                                      ;  1EE28 EE28 C A5 FB           F:003354
  SEC                                             ;  1EE2A EE2A C 38              F:003354
  SBC PlayerYPx                                      ;  1EE2B EE2B C E5 45           F:003354
  BCC B_15_1EE46                                  ;  1EE2D EE2D C 90 17           F:003354
  LDY #$9                                         ;  1EE2F EE2F C A0 09           F:003354
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1EE31 EE31 C B1 E7           F:003354
  BEQ B_15_1EE52                                  ;  1EE33 EE33 C F0 1D           F:003354
  LDA #$3                                         ;  1EE35 EE35 C A9 03           F:003354
  JSR StepRNG                                  ;  1EE37 EE37 C 20 64 CC        F:003354
  TAX                                             ;  1EE3A EE3A C AA              F:003354
  BNE B_15_1EE52                                  ;  1EE3B EE3B C D0 15           F:003354
  LDA #$80                                        ;  1EE3D EE3D C A9 80           F:003396
  ORA Workset_F4                                      ;  1EE3F EE3F C 05 F4           F:003396
  STA Workset_F4                                      ;  1EE41 EE41 C 85 F4           F:003396
  JMP B_15_1EE52                                  ;  1EE43 EE43 C 4C 52 EE        F:003396

B_15_1EE46:
  LDA #$3                                         ;  1EE46 EE46 C A9 03           F:003516
  JSR StepRNG                                  ;  1EE48 EE48 C 20 64 CC        F:003516
  TAX                                             ;  1EE4B EE4B C AA              F:003516
  BNE B_15_1EE52                                  ;  1EE4C EE4C C D0 04           F:003516
  LDA #$4                                         ;  1EE4E EE4E C A9 04           F:003516
  STA Workset_F4                                      ;  1EE50 EE50 C 85 F4           F:003516
B_15_1EE52:
  RTS                                             ;  1EE52 EE52 C 60              F:003354

L_15_1EE53:
  LDA Workset+Ent_XTile                                      ;  1EE53 EE53 C A5 FA           F:007546
  STA TmpF                                      ;  1EE55 EE55 C 85 0F           F:007546
  LDA Workset+Ent_XPx                                      ;  1EE57 EE57 C A5 F9           F:007546
  STA TmpE                                      ;  1EE59 EE59 C 85 0E           F:007546
  LDA Workset+Ent_YPx                                      ;  1EE5B EE5B C A5 FB           F:007546
  STA TmpA                                      ;  1EE5D EE5D C 85 0A           F:007546
  JSR L_14_1CE90                                  ;  1EE5F EE5F C 20 90 CE        F:007546
  LDX #$0                                         ;  1EE62 EE62 C A2 00           F:007546
  BCS B_15_1EE6F                                  ;  1EE64 EE64 C B0 09           F:007546
  LDA Workset+Ent_XTile                                      ;  1EE66 EE66 C A5 FA           F:007546
  SEC                                             ;  1EE68 EE68 C 38              F:007546
  SBC PlayerXTile                                      ;  1EE69 EE69 C E5 44           F:007546
  INX                                             ;  1EE6B EE6B C E8              F:007546
  BCC B_15_1EE6F                                  ;  1EE6C EE6C C 90 01           F:007546
  INX                                             ;  1EE6E EE6E C E8              F:007546
B_15_1EE6F:
  STX Workset_F4                                      ;  1EE6F EE6F C 86 F4           F:007546
  JSR L_14_1CEB6                                  ;  1EE71 EE71 C 20 B6 CE        F:007546
  LDX #$0                                         ;  1EE74 EE74 C A2 00           F:007546
  BCS B_15_1EE83                                  ;  1EE76 EE76 C B0 0B           F:007546
  LDA Workset+Ent_YPx                                      ;  1EE78 EE78 C A5 FB           F:007546
  SEC                                             ;  1EE7A EE7A C 38              F:007546
  SBC PlayerYPx                                      ;  1EE7B EE7B C E5 45           F:007546
  LDX #$4                                         ;  1EE7D EE7D C A2 04           F:007546
  BCC B_15_1EE83                                  ;  1EE7F EE7F C 90 02           F:007546
  LDX #$8                                         ;  1EE81 EE81 C A2 08           F:042166
B_15_1EE83:
  TXA                                             ;  1EE83 EE83 C 8A              F:007546
  ORA Workset_F4                                      ;  1EE84 EE84 C 05 F4           F:007546
  STA Workset_F4                                      ;  1EE86 EE86 C 85 F4           F:007546
  LDA #$0                                         ;  1EE88 EE88 C A9 00           F:007546
  STA Workset+Ent_AnimTimer                                      ;  1EE8A EE8A C 85 F3           F:007546
  RTS                                             ;  1EE8C EE8C C 60              F:007546

L_15_1EE8D:
  LDA Workset_F4                                      ;  1EE8D EE8D C A5 F4           F:001382
  AND #$3                                         ;  1EE8F EE8F C 29 03           F:001382
  BNE B_15_1EE95                                  ;  1EE91 EE91 C D0 02           F:001382
  LDA #$1                                         ;  1EE93 EE93 C A9 01           F:001382
B_15_1EE95:
  EOR #$3                                         ;  1EE95 EE95 C 49 03           F:001382
  STA Workset_F4                                      ;  1EE97 EE97 C 85 F4           F:001382
  RTS                                             ;  1EE99 EE99 C 60              F:001382

L_15_1EE9A:
  LDA #$8                                         ;  1EE9A EE9A C A9 08           F:005267
  JSR StepRNG                                  ;  1EE9C EE9C C 20 64 CC        F:005267
  TAX                                             ;  1EE9F EE9F C AA              F:005267
  LDA D_15_1EEB3,X                                ;  1EEA0 EEA0 C BD B3 EE        F:005267
  STA Workset_F4                                      ;  1EEA3 EEA3 C 85 F4           F:005267
  RTS                                             ;  1EEA5 EEA5 C 60              F:005267

L_15_1EEA6:
  LDA #$3                                         ;  1EEA6 EEA6 C A9 03           F:001382
  JSR StepRNG                                  ;  1EEA8 EEA8 C 20 64 CC        F:001382
  ASL                                             ;  1EEAB EEAB C 0A              F:001382
  TAX                                             ;  1EEAC EEAC C AA              F:001382
  LDA D_15_1EEB3,X                                ;  1EEAD EEAD C BD B3 EE        F:001382
  STA Workset_F4                                      ;  1EEB0 EEB0 C 85 F4           F:001382
  RTS                                             ;  1EEB2 EEB2 C 60              F:001382

D_15_1EEB3:
.byte $01                                         ;  1EEB3 EEB3 D        ?        F:001389
.byte $05                                         ;  1EEB4 EEB4 D        ?        F:009156
.byte $04                                         ;  1EEB5 EEB5 D        ?        F:001384
.byte $06                                         ;  1EEB6 EEB6 D        ?        F:049934
.byte $02                                         ;  1EEB7 EEB7 D        ?        F:001382
.byte $0A                                         ;  1EEB8 EEB8 D        ?        F:007546
.byte $08                                         ;  1EEB9 EEB9 D        ?        F:051875
.byte $09                                         ;  1EEBA EEBA D        ?        F:042164
L_15_1EEBB:
  LDA Workset+Ent_SwapBlock                                      ;  1EEBB EEBB C A5 F0           F:001405
  LSR                                             ;  1EEBD EEBD C 4A              F:001405
  CLC                                             ;  1EEBE EEBE C 18              F:001405
  ADC #$2                                         ;  1EEBF EEBF C 69 02           F:001405
  STA Workset+Ent_YPxSpeed                                      ;  1EEC1 EEC1 C 85 F7           F:001405
  JSR L_15_1F0E1                                  ;  1EEC3 EEC3 C 20 E1 F0        F:001405
  BCS B_15_1EEC9                                  ;  1EEC6 EEC6 C B0 01           F:001405
  RTS                                             ;  1EEC8 EEC8 C 60              F:001405

B_15_1EEC9:
  LDA #$0                                         ;  1EEC9 EEC9 C A9 00           F:001446
  STA Workset+Ent_XPxSpeed                                      ;  1EECB EECB C 85 F5           F:001446
  STA Workset+Ent_XTileSpeed                                      ;  1EECD EECD C 85 F6           F:001446
  JSR L_15_1F0E1                                  ;  1EECF EECF C 20 E1 F0        F:001446
  BCS B_15_1EED5                                  ;  1EED2 EED2 C B0 01           F:001446
  RTS                                             ;  1EED4 EED4 C 60              F:001446

B_15_1EED5:
  LDA #$0                                         ;  1EED5 EED5 C A9 00           F:009206
  STA Workset+Ent_YPxSpeed                                      ;  1EED7 EED7 C 85 F7           F:009206
  RTS                                             ;  1EED9 EED9 C 60              F:009206

L_15_1EEDA:
  LDX Workset+Ent_Damage                                      ;  1EEDA EEDA C A6 F1           F:001384
  BNE B_15_1EEE0                                  ;  1EEDC EEDC C D0 02           F:001384
  LDX #$F                                         ;  1EEDE EEDE C A2 0F           F:001384
B_15_1EEE0:
  DEX                                             ;  1EEE0 EEE0 C CA              F:001384
  STX Workset+Ent_Damage                                      ;  1EEE1 EEE1 C 86 F1           F:001384
  TXA                                             ;  1EEE3 EEE3 C 8A              F:001384
  LSR                                             ;  1EEE4 EEE4 C 4A              F:001384
  EOR #$FF                                        ;  1EEE5 EEE5 C 49 FF           F:001384
  CLC                                             ;  1EEE7 EEE7 C 18              F:001384
  ADC #$1                                         ;  1EEE8 EEE8 C 69 01           F:001384
  STA Workset+Ent_YPxSpeed                                      ;  1EEEA EEEA C 85 F7           F:001384
  JSR L_15_1F0E1                                  ;  1EEEC EEEC C 20 E1 F0        F:001384
  BCS B_15_1EEF2                                  ;  1EEEF EEEF C B0 01           F:001384
  RTS                                             ;  1EEF1 EEF1 C 60              F:001384

B_15_1EEF2:
  LDA #$0                                         ;  1EEF2 EEF2 C A9 00           F:001395
  STA Workset+Ent_XPxSpeed                                      ;  1EEF4 EEF4 C 85 F5           F:001395
  STA Workset+Ent_XTileSpeed                                      ;  1EEF6 EEF6 C 85 F6           F:001395
  JSR L_15_1F0E1                                  ;  1EEF8 EEF8 C 20 E1 F0        F:001395
  BCS B_15_1EEFE                                  ;  1EEFB EEFB C B0 01           F:001395
  RTS                                             ;  1EEFD EEFD C 60              F:001395

B_15_1EEFE:
  INC Workset+Ent_Damage                                      ;  1EEFE EEFE C E6 F1           F:001402
  JSR L_15_1F2DA                                  ;  1EF00 EF00 C 20 DA F2        F:001402
  RTS                                             ;  1EF03 EF03 C 60              F:001402

L_15_1EF04:
  LDA TmpE                                      ;  1EF04 EF04 C A5 0E           F:001379
  STA Workset+Ent_XPx                                      ;  1EF06 EF06 C 85 F9           F:001379
  LDA TmpF                                      ;  1EF08 EF08 C A5 0F           F:001379
  STA Workset+Ent_XTile                                      ;  1EF0A EF0A C 85 FA           F:001379
  LDA TmpA                                      ;  1EF0C EF0C C A5 0A           F:001379
  STA Workset+Ent_YPx                                      ;  1EF0E EF0E C 85 FB           F:001379
  RTS                                             ;  1EF10 EF10 C 60              F:001379

L_15_1EF11:
  LDA #$0                                         ;  1EF11 EF11 C A9 00           F:001382
  STA Workset+Ent_XPxSpeed                                      ;  1EF13 EF13 C 85 F5           F:001382
  STA Workset+Ent_YPxSpeed                                      ;  1EF15 EF15 C 85 F7           F:001382
  STA Workset+Ent_Damage                                      ;  1EF17 EF17 C 85 F1           F:001382
  STA Workset+Ent_SwapBlock                                      ;  1EF19 EF19 C 85 F0           F:001382
  RTS                                             ;  1EF1B EF1B C 60              F:001382

L_15_1EF1C:
  lda Workset+Ent_State                           ; check if entity is active and not dead
  and #%01111111                                  ;
  bne B_15_1EF45                              ; if so - skip ahead
  inc a:Workset+Ent_State                         ; otherwise active the entity
  LDA #$E                                         ;  1EF25 EF25 C A9 0E           F:026947
  STA PendingSFX                                      ;  1EF27 EF27 C 85 8F           F:026947
  LDA #$8                                         ;  1EF29 EF29 C A9 08           F:026947
  STA Workset+Ent_Damage                          ;  1EF2B EF2B C 85 F1           F:026947
  lda #$0                                         ; set some defaults
  sta Workset+Ent_XPxSpeed                        ;
  sta Workset+Ent_XTileSpeed                      ;
  sta Workset+Ent_SwapBlock                       ;
  lda Workset+Ent_YPx                             ;
  STA Workset_FC                                  ;
  LDY #$6                                         ;  1EF39 EF39 C A0 06           F:026947
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1EF3B EF3B C B1 E7           F:026947
  STA Workset+Ent_Gfx                                      ;  1EF3D EF3D C 85 ED           F:026947
  LDA Workset+Ent_SprAttr                                      ;  1EF3F EF3F C A5 EF           F:026947
  AND #$3                                         ;  1EF41 EF41 C 29 03           F:026947
  STA Workset+Ent_SprAttr                                      ;  1EF43 EF43 C 85 EF           F:026947
B_15_1EF45:
  LDA Workset+Ent_SwapBlock                                      ;  1EF45 EF45 C A5 F0           F:026947
  BNE B_15_1EF6E                                  ;  1EF47 EF47 C D0 25           F:026947
  DEC Workset+Ent_Damage                                      ;  1EF49 EF49 C C6 F1           F:026947
  BEQ B_15_1EF63                                  ;  1EF4B EF4B C F0 16           F:026947
  LDA Workset+Ent_Damage                                      ;  1EF4D EF4D C A5 F1           F:026947
  EOR #$FF                                        ;  1EF4F EF4F C 49 FF           F:026947
  CLC                                             ;  1EF51 EF51 C 18              F:026947
  ADC #$1                                         ;  1EF52 EF52 C 69 01           F:026947
  STA Workset+Ent_YPxSpeed                                      ;  1EF54 EF54 C 85 F7           F:026947
  jsr CalcNextPosition                            ; add entity speeds onto position
  jsr EnsureNextPositionIsValid                   ; and make sure the position is valid
  bcs B_15_1EF63                            ; if not - skip ahead
  lda TmpA                                        ; otherwise move entity to next position
  sta Workset+Ent_YPx                             ;
  rts                                             ; done!
B_15_1EF63:
  LDA Workset+Ent_SprAttr                                      ;  1EF63 EF63 C A5 EF           F:026968
  ORA #$80                                        ;  1EF65 EF65 C 09 80           F:026968
  STA Workset+Ent_SprAttr                                      ;  1EF67 EF67 C 85 EF           F:026968
  LDA #$1                                         ;  1EF69 EF69 C A9 01           F:026968
  STA Workset+Ent_SwapBlock                                      ;  1EF6B EF6B C 85 F0           F:026968
  RTS                                             ;  1EF6D EF6D C 60              F:026968

B_15_1EF6E:
  INC Workset+Ent_SwapBlock                                      ;  1EF6E EF6E C E6 F0           F:026971
  LDA Workset+Ent_SwapBlock                                      ;  1EF70 EF70 C A5 F0           F:026971
  LSR                                             ;  1EF72 EF72 C 4A              F:026971
  CLC                                             ;  1EF73 EF73 C 18              F:026971
  ADC #$2                                         ;  1EF74 EF74 C 69 02           F:026971
  STA Workset+Ent_YPxSpeed                                      ;  1EF76 EF76 C 85 F7           F:026971
  JSR CalcNextPosition                                  ;  1EF78 EF78 C 20 F1 EF        F:026971
  JSR EnsureNextPositionIsValid                                  ;  1EF7B EF7B C 20 08 CF        F:026971
  BCS @SpawnDrop                                  ;  1EF7E EF7E C B0 05           F:026971
  LDA TmpA                                      ;  1EF80 EF80 C A5 0A           F:026971
  STA Workset+Ent_YPx                                      ;  1EF82 EF82 C 85 FB           F:026971
  RTS                                             ;  1EF84 EF84 C 60              F:026971

@SpawnDrop:
  ldx #DropType_HP                                ; set result type to health
  lda PlayerHP                                    ; do we have less than 20 health?
  cmp #20                                         ;
  bcc @DoSpawn                                    ; if so - spawn health
  inx                                             ; set result type to mp
  lda PlayerMP                                    ; do we have less than 30 mana?
  cmp #30                                         ;
  bcc @DoSpawn                                    ; if so - spawn mana
  ldx #DropType_Key                               ; set key drop
  lda PlayerKeys                                  ; do we have less than 2 keys?
  cmp #$2                                         ;
  bcc @DoSpawn                                    ; if so - spawn key
  lda #20                                         ; roll D20 rng
  jsr StepRNG                                     ;
  cmp #9                                          ; did we roll a 9 or higher?
  bcs @HP_MP_Gold_Spawn                           ; yes - skip ahead
  tay                                             ;
  ldx @SpecialDrops,y                             ; pick the result from the table
  jmp @DoSpawn                                    ; and spawn it!
@HP_MP_Gold_Spawn:
  ldx #DropType_HP                                ; set expected drop type
  lda PlayerHP                                    ; do we have more HP than MP?
  cmp PlayerMP                                    ;
  bcc @DecideOnGoldDrop                           ; no - decide between gold and hp
  inx                                             ; yes - check if we have more mp than gold
  lda PlayerMP                                    ;
  cmp PlayerGold                                  ;
  bcc @DoSpawn                                    ; if so - spawn mana
  jmp @SpawnGold                                  ; otherwise spawn gold
@DecideOnGoldDrop:
  cmp PlayerGold                                  ; do we have more hp than gold?
  bcc @DoSpawn                                    ; if not - spawn health
@SpawnGold:
  ldx #DropType_Gold                              ; spawn gold!
@DoSpawn:
  txa                                             ;
  clc                                             ;
  adc #$2                                         ;
  sta Workset+Ent_State                           ; set entity type to itemtype+2
  txa                                             ; restore type id
  asl a                                           ; and adjust it up to sprite tile index
  asl a                                           ;
  ora #%10000001                                  ;
  sta Workset+Ent_Gfx                             ; and use that as our tile
  lda #$1                                         ;
  STA Workset+Ent_SprAttr                         ; set sprite palette
  LDA Workset_FC                                      ;  1EFD5 EFD5 C A5 FC           F:027022
  STA Workset+Ent_YPx                             ; set y position for the drop
  LDA #$F0                                        ; set timer until the drop expires
  STA Workset+Ent_AnimTimer                       ;
  lda #$0                                         ; clear some state
  sta Workset+Ent_SwapBlock                       ;
  sta Workset+Ent_Damage                          ;
  JSR L_15_1F179                                  ;  1EFE3 EFE3 C 20 79 F1        F:027022
  rts                                             ; done!

@SpecialDrops:
.byte DropType_Poison
.byte DropType_Poison
.byte DropType_Poison
.byte DropType_Poison
.byte DropType_Key
.byte DropType_Key
.byte DropType_Ring
.byte DropType_Cross
.byte DropType_Scroll

DoNothing:
  rts                                           ; done!

CalcNextPosition:
  lda Workset+Ent_XPx                           ; copy entity position to temp values
  sta TmpE                                      ;
  lda Workset+Ent_XTile                         ;
  sta TmpF                                      ;
  lda Workset+Ent_YPx                           ;
  sta TmpA                                      ;
  lda Workset+Ent_YPxSpeed                      ; get entity vertical speed
  beq :+                                        ; skip ahead if zero
  clc                                           ;
  adc TmpA                                      ; otherwise add speed to position
  sta TmpA                                      ;
: lda Workset+Ent_XPxSpeed                      ; get entity horizontal speed
  beq :+                                        ; skip ahead if zero
  clc                                           ;
  adc TmpE                                      ; otherwise add speed to position
  pha                                           ; put result on stack
  and #%00001111                                ; and get the pixel position
  sta TmpE                                      ; update temp position
  pla                                           ; restore full position change
  asl a                                         ; shift up until we get the 16px bit into carry
  asl a                                         ; 
  asl a                                         ; 
  asl a                                         ; 
  lda TmpF                                      ; get the pixel position
  adc Workset+Ent_XTileSpeed                    ; and add full tile speed + tile carry
  sta TmpF                                      ; then update position
: rts                                           ; done!

L_15_1F01E:
  LDY #$7                                         ;  1F01E F01E C A0 07           F:001379
  LDA (ActiveEntityAreaDataPtr),Y                                  ;  1F020 F020 C B1 E7           F:001379
  AND #$3                                         ;  1F022 F022 C 29 03           F:001379
  ASL                                             ;  1F024 F024 C 0A              F:001379
  TAX                                             ;  1F025 F025 C AA              F:001379
  LDA D_15_1F033,X                                ;  1F026 F026 C BD 33 F0        F:001379
  STA TmpE                                      ;  1F029 F029 C 85 0E           F:001379
  LDA D_15_1F033+1,X                                ;  1F02B F02B C BD 34 F0        F:001379
  STA TmpF                                      ;  1F02E F02E C 85 0F           F:001379
  JMP (TmpE)                                    ;  1F030 F030 C 6C 0E 00        F:001379

D_15_1F033:
.addr B_15_1F03B                                ;  1F033 F033 N 3B F0
.addr B_15_1F04B                                ;  1F035 F035 N 4B F0
.addr B_15_1F071                                ;  1F037 F037 N 71 F0
.addr B_15_1F0B9                                ;  1F039 F039 N B9 F0

B_15_1F03B:
  INC Workset+Ent_AnimTimer                                      ;  1F03B F03B C E6 F3           F:013669
  LDA Workset+Ent_AnimTimer                                      ;  1F03D F03D C A5 F3           F:013669
  AND #$3                                         ;  1F03F F03F C 29 03           F:013669
  BEQ B_15_1F044                                  ;  1F041 F041 C F0 01           F:013669
  RTS                                             ;  1F043 F043 C 60              F:013669

B_15_1F044:
  LDA Workset+Ent_SprAttr                                      ;  1F044 F044 C A5 EF           F:052525
  EOR #$40                                        ;  1F046 F046 C 49 40           F:052525
  STA Workset+Ent_SprAttr                                      ;  1F048 F048 C 85 EF           F:052525
  RTS                                             ;  1F04A F04A C 60              F:052525

B_15_1F04B:
  LDA Workset+Ent_XPxSpeed                                      ;  1F04B F04B C A5 F5           F:001381
  BEQ B_15_1F061                                  ;  1F04D F04D C F0 12           F:001381
  LDY #$0                                         ;  1F04F F04F C A0 00           F:001384
  LDA Workset+Ent_XTileSpeed                                      ;  1F051 F051 C A5 F6           F:001384
  BMI B_15_1F057                                  ;  1F053 F053 C 30 02           F:001384
  LDY #$40                                        ;  1F055 F055 C A0 40           F:001411
B_15_1F057:
  STY R_0008                                      ;  1F057 F057 C 84 08           F:001384
  LDA Workset+Ent_SprAttr                                      ;  1F059 F059 C A5 EF           F:001384
  AND #$3F                                        ;  1F05B F05B C 29 3F           F:001384
  ORA R_0008                                      ;  1F05D F05D C 05 08           F:001384
  STA Workset+Ent_SprAttr                                      ;  1F05F F05F C 85 EF           F:001384
B_15_1F061:
  INC Workset+Ent_AnimTimer                                      ;  1F061 F061 C E6 F3           F:001381
  LDA Workset+Ent_AnimTimer                                      ;  1F063 F063 C A5 F3           F:001381
  AND #$3                                         ;  1F065 F065 C 29 03           F:001381
  BEQ B_15_1F06A                                  ;  1F067 F067 C F0 01           F:001381
  RTS                                             ;  1F069 F069 C 60              F:001381

B_15_1F06A:
  LDA Workset+Ent_Gfx                                      ;  1F06A F06A C A5 ED           F:001390
  EOR #$4                                         ;  1F06C F06C C 49 04           F:001390
  STA Workset+Ent_Gfx                                      ;  1F06E F06E C 85 ED           F:001390
  RTS                                             ;  1F070 F070 C 60              F:001390

B_15_1F071:
  LDA Workset+Ent_XPxSpeed                                      ;  1F071 F071 C A5 F5           F:001379
  BEQ B_15_1F090                                  ;  1F073 F073 C F0 1B           F:001379
  LDY #$0                                         ;  1F075 F075 C A0 00           F:001382
  LDA Workset+Ent_XTileSpeed                                      ;  1F077 F077 C A5 F6           F:001382
  BMI B_15_1F07D                                  ;  1F079 F079 C 30 02           F:001382
  LDY #$40                                        ;  1F07B F07B C A0 40           F:001385
B_15_1F07D:
  STY R_0008                                      ;  1F07D F07D C 84 08           F:001382
  LDA Workset+Ent_SprAttr                                      ;  1F07F F07F C A5 EF           F:001382
  AND #$3F                                        ;  1F081 F081 C 29 3F           F:001382
  ORA R_0008                                      ;  1F083 F083 C 05 08           F:001382
  STA Workset+Ent_SprAttr                                      ;  1F085 F085 C 85 EF           F:001382
  LDA Workset+Ent_Gfx                                      ;  1F087 F087 C A5 ED           F:001382
  AND #$F7                                        ;  1F089 F089 C 29 F7           F:001382
  STA Workset+Ent_Gfx                                      ;  1F08B F08B C 85 ED           F:001382
  JMP L_15_1F09C                                  ;  1F08D F08D C 4C 9C F0        F:001382

B_15_1F090:
  LDA Workset+Ent_YPxSpeed                                      ;  1F090 F090 C A5 F7           F:001379
  BEQ L_15_1F09C                                  ;  1F092 F092 C F0 08           F:001379
  LDA Workset+Ent_Gfx                                      ;  1F094 F094 C A5 ED           F:001384
  AND #$F3                                        ;  1F096 F096 C 29 F3           F:001384
  ORA #$8                                         ;  1F098 F098 C 09 08           F:001384
  STA Workset+Ent_Gfx                                      ;  1F09A F09A C 85 ED           F:001384
L_15_1F09C:
  INC Workset+Ent_AnimTimer                                      ;  1F09C F09C C E6 F3           F:001379
  LDA Workset+Ent_AnimTimer                                      ;  1F09E F09E C A5 F3           F:001379
  AND #$3                                         ;  1F0A0 F0A0 C 29 03           F:001379
  BEQ B_15_1F0A5                                  ;  1F0A2 F0A2 C F0 01           F:001379
  RTS                                             ;  1F0A4 F0A4 C 60              F:001379

B_15_1F0A5:
  LDA Workset+Ent_Gfx                                      ;  1F0A5 F0A5 C A5 ED           F:001388
  AND #$8                                         ;  1F0A7 F0A7 C 29 08           F:001388
  BNE B_15_1F0B2                                  ;  1F0A9 F0A9 C D0 07           F:001388
  LDA Workset+Ent_Gfx                                      ;  1F0AB F0AB C A5 ED           F:001388
  EOR #$4                                         ;  1F0AD F0AD C 49 04           F:001388
  STA Workset+Ent_Gfx                                      ;  1F0AF F0AF C 85 ED           F:001388
  RTS                                             ;  1F0B1 F0B1 C 60              F:001388

B_15_1F0B2:
  LDA Workset+Ent_SprAttr                                      ;  1F0B2 F0B2 C A5 EF           F:001393
  EOR #$40                                        ;  1F0B4 F0B4 C 49 40           F:001393
  STA Workset+Ent_SprAttr                                      ;  1F0B6 F0B6 C 85 EF           F:001393
  RTS                                             ;  1F0B8 F0B8 C 60              F:001393

B_15_1F0B9:
  LDA Workset+Ent_XPxSpeed                                      ;  1F0B9 F0B9 C A5 F5           F:014980
  BEQ B_15_1F0CF                                  ;  1F0BB F0BB C F0 12           F:014980
  LDY #$0                                         ;  1F0BD F0BD C A0 00           F:014981
  LDA Workset+Ent_XTileSpeed                                      ;  1F0BF F0BF C A5 F6           F:014981
  BMI B_15_1F0C5                                  ;  1F0C1 F0C1 C 30 02           F:014981
  LDY #$40                                        ;  1F0C3 F0C3 C A0 40           F:014986
B_15_1F0C5:
  STY R_0008                                      ;  1F0C5 F0C5 C 84 08           F:014981
  LDA Workset+Ent_SprAttr                                      ;  1F0C7 F0C7 C A5 EF           F:014981
  AND #$3F                                        ;  1F0C9 F0C9 C 29 3F           F:014981
  ORA R_0008                                      ;  1F0CB F0CB C 05 08           F:014981
  STA Workset+Ent_SprAttr                                      ;  1F0CD F0CD C 85 EF           F:014981
B_15_1F0CF:
  INC Workset+Ent_AnimTimer                                      ;  1F0CF F0CF C E6 F3           F:014980
  LDA Workset+Ent_AnimTimer                                      ;  1F0D1 F0D1 C A5 F3           F:014980
  AND #$6                                         ;  1F0D3 F0D3 C 29 06           F:014980
  ASL                                             ;  1F0D5 F0D5 C 0A              F:014980
  STA R_0008                                      ;  1F0D6 F0D6 C 85 08           F:014980
  LDA Workset+Ent_Gfx                                      ;  1F0D8 F0D8 C A5 ED           F:014980
  AND #$F3                                        ;  1F0DA F0DA C 29 F3           F:014980
  ORA R_0008                                      ;  1F0DC F0DC C 05 08           F:014980
  STA Workset+Ent_Gfx                                      ;  1F0DE F0DE C 85 ED           F:014980
  RTS                                             ;  1F0E0 F0E0 C 60              F:014980

L_15_1F0E1:
  LDA Workset+Ent_YPxSpeed                                      ;  1F0E1 F0E1 C A5 F7           F:001379
  PHA                                             ;  1F0E3 F0E3 C 48              F:001379
B_15_1F0E4:
  JSR CalcNextPosition                                  ;  1F0E4 F0E4 C 20 F1 EF        F:001379
  JSR EnsureNextPositionIsValid                                  ;  1F0E7 F0E7 C 20 08 CF        F:001379
  BCS B_15_1F10E                                  ;  1F0EA F0EA C B0 22           F:001379
  LDX Workset+Ent_State                                      ;  1F0EC F0EC C A6 EE           F:001379
  DEX                                             ;  1F0EE F0EE C CA              F:001379
  BNE B_15_1F0F9                                  ;  1F0EF F0EF C D0 08           F:001379
  JSR L_14_1CE7C                                  ;  1F0F1 F0F1 C 20 7C CE        F:001379
  BCC B_15_1F0F9                                  ;  1F0F4 F0F4 C 90 03           F:001379
  JSR L_15_1F136                                  ;  1F0F6 F0F6 C 20 36 F1        F:001544
B_15_1F0F9:
  JSR L_15_1F23A                                  ;  1F0F9 F0F9 C 20 3A F2        F:001379
  BCC B_15_1F117                                  ;  1F0FC F0FC C 90 19           F:001379
  LDX Workset+Ent_YPxSpeed                                      ;  1F0FE F0FE C A6 F7           F:001383
  BEQ B_15_1F116                                  ;  1F100 F100 C F0 14           F:001383
  BMI B_15_1F106                                  ;  1F102 F102 C 30 02           F:001395
  DEX                                             ;  1F104 F104 C CA              F:001429
  DEX                                             ;  1F105 F105 C CA              F:001429
B_15_1F106:
  INX                                             ;  1F106 F106 C E8              F:001395
  STX Workset+Ent_YPxSpeed                                      ;  1F107 F107 C 86 F7           F:001395
  BNE B_15_1F0E4                                  ;  1F109 F109 C D0 D9           F:001395
  JMP B_15_1F116                                  ;  1F10B F10B C 4C 16 F1        F:001395

B_15_1F10E:
  LDA #$0                                         ;  1F10E F10E C A9 00           F:001886
  STA Workset+Ent_State                                      ;  1F110 F110 C 85 EE           F:001886
  LDA #$F0                                        ;  1F112 F112 C A9 F0           F:001886
  STA Workset+Ent_AnimTimer                                      ;  1F114 F114 C 85 F3           F:001886
B_15_1F116:
  SEC                                             ;  1F116 F116 C 38              F:001383
B_15_1F117:
  PLA                                             ;  1F117 F117 C 68              F:001379
  STA Workset+Ent_YPxSpeed                                      ;  1F118 F118 C 85 F7           F:001379
  RTS                                             ;  1F11A F11A C 60              F:001379

L_15_1F11B:
  JSR CalcNextPosition                                  ;  1F11B F11B C 20 F1 EF        F:005264
  JSR L_14_1CE7C                                  ;  1F11E F11E C 20 7C CE        F:005264
  BCC B_15_1F128                                  ;  1F121 F121 C 90 05           F:005264
  JSR L_15_1F136                                  ;  1F123 F123 C 20 36 F1        F:023658
  SEC                                             ;  1F126 F126 C 38              F:023658
  RTS                                             ;  1F127 F127 C 60              F:023658

B_15_1F128:
  JSR EnsureNextPositionIsValid                                  ;  1F128 F128 C 20 08 CF        F:005264
  BCC B_15_1F135                                  ;  1F12B F12B C 90 08           F:005264
  LDA #$0                                         ;  1F12D F12D C A9 00           F:005651
  STA Workset+Ent_State                                      ;  1F12F F12F C 85 EE           F:005651
  LDA #$F0                                        ;  1F131 F131 C A9 F0           F:005651
  STA Workset+Ent_AnimTimer                                      ;  1F133 F133 C 85 F3           F:005651
B_15_1F135:
  RTS                                             ;  1F135 F135 C 60              F:005264

L_15_1F136:
  lda InvincibilityFramesTimer               ; bail out if player is in iframes
  bne @Done                                  ;
  ldx Workset+Ent_State                             ; get status flag of current entity
  dex                                        ;
  bne @Done                                  ; if flag was not 1, exit
  lda SelectedBank3                          ; use enemy gfx to determine if we are in a boss encounter
  cmp #$30                                   ;
  bcc @CheckCharacter                        ; if not, skip to check for pochi immunity
  lda ActiveEntity                           ; only run boss check on entity 0
  beq @ApplyDamage                           ;
  ldx PlayerSelectedItemSlot                  ; is the player using the shield?
  lda PlayerActiveItems,X                    ;
  cmp #ItemType_Shield                       ;
  beq @Exit                                  ; yep - bail out
  JMP @ApplyDamage                           ; nope - apply damage
@CheckCharacter:
  lda PlayerCharacter                             ; are we currently playing as pochi?
  cmp #Character_Pochi                            ;
  beq @Done                                  ; yep - skip ahead
@ApplyDamage:
  lda PlayerActiveStrength                        ; apply damage to player based on players strength
  jsr ApplyDamageToPlayer                         ;
  LDA #$21                                        ;  1F15F F15F C A9 21           F:001811
  STA a:PendingSFX                                    ;  1F161 F161 C 8D 8F 00        F:001811
  LDA #$1                                         ;  1F164 F164 C A9 01           F:001811
  STA R_0090                                      ;  1F166 F166 C 85 90           F:001811
  lda #$1                                         ; make player invincible for a little bit
  sta InvincibilityFramesTimer                    ;
  LDA Workset+Ent_SprAttr                                      ;  1F16C F16C C A5 EF           F:001811
  AND #%11011111                                  ;  1F16E F16E C 29 DF           F:001811
  STA Workset+Ent_SprAttr                                      ;  1F170 F170 C 85 EF           F:001811
  RTS                                             ;  1F172 F172 C 60              F:001811
@Exit:
  LDA #$1                                         ;  1F173 F173 . A9 01           
  STA a:PendingSFX                                    ;  1F175 F175 . 8D 8F 00        
@Done:
  rts                                             ; done!

L_15_1F179:
  LDA Workset+Ent_Damage                                      ;  1F179 F179 C A5 F1           F:001379
  BNE B_15_1F1D3                                  ;  1F17B F17B C D0 56           F:001379
  LDA Workset+Ent_XTile                                      ;  1F17D F17D C A5 FA           F:001379
  STA BlockPtrLo                                      ;  1F17F F17F C 85 0C           F:001379
  STA TmpF                                      ;  1F181 F181 C 85 0F           F:001379
  LDA Workset+Ent_XPx                                      ;  1F183 F183 C A5 F9           F:001379
  STA TmpE                                      ;  1F185 F185 C 85 0E           F:001379
  LDX Workset+Ent_YPx                                      ;  1F187 F187 C A6 FB           F:001379
  LDY Workset+Ent_State                                      ;  1F189 F189 C A4 EE           F:001379
  DEY                                             ;  1F18B F18B C 88              F:001379
  BEQ B_15_1F199                                  ;  1F18C F18C C F0 0B           F:001379
  CPX #$EF                                        ;  1F18E F18E C E0 EF           F:005352
  BNE B_15_1F194                                  ;  1F190 F190 C D0 02           F:005352
  LDX Workset_FC                                      ;  1F192 F192 C A6 FC           F:026559
B_15_1F194:
  STX BlockPtrHi                                      ;  1F194 F194 C 86 0D           F:005352
  JMP L_15_1F1A7                                  ;  1F196 F196 C 4C A7 F1        F:005352

B_15_1F199:
  CPX #$B0                                        ;  1F199 F199 C E0 B0           F:001379
  BCS B_15_1F1CF                                  ;  1F19B F19B C B0 32           F:001379
  STX BlockPtrHi                                      ;  1F19D F19D C 86 0D           F:001379
  INX                                             ;  1F19F F19F C E8              F:001379
  STX TmpA                                      ;  1F1A0 F1A0 C 86 0A           F:001379
  JSR L_14_1CE7C                                  ;  1F1A2 F1A2 C 20 7C CE        F:001379
  BCS B_15_1F1D3                                  ;  1F1A5 F1A5 C B0 2C           F:001379
L_15_1F1A7:
  JSR PositionToBlock                                  ;  1F1A7 F1A7 C 20 54 CA        F:001379
  LDA Workset+Ent_XPx                                      ;  1F1AA F1AA C A5 F9           F:001379
  BNE B_15_1F1BD                                  ;  1F1AC F1AC C D0 0F           F:001379
  LDY #$0                                         ;  1F1AE F1AE C A0 00           F:001379
  LDA (BlockPtrLo),Y                                  ;  1F1B0 F1B0 C B1 0C           F:001379
  AND #$3F                                        ;  1F1B2 F1B2 C 29 3F           F:001379
  BEQ B_15_1F1D3                                  ;  1F1B4 F1B4 C F0 1D           F:001379
  INY                                             ;  1F1B6 F1B6 C C8              F:001379
  LDA (BlockPtrLo),Y                                  ;  1F1B7 F1B7 C B1 0C           F:001379
  AND #$3F                                        ;  1F1B9 F1B9 C 29 3F           F:001379
  BEQ B_15_1F1D3                                  ;  1F1BB F1BB C F0 16           F:001379
B_15_1F1BD:
  LDY #$1                                         ;  1F1BD F1BD C A0 01           F:001379
  JSR CheckIfBlockIsSolid                                  ;  1F1BF F1BF C 20 33 F2        F:001379
  BCS B_15_1F1D3                                  ;  1F1C2 F1C2 C B0 0F           F:001379
  LDA Workset+Ent_XPx                                      ;  1F1C4 F1C4 C A5 F9           F:001402
  BEQ B_15_1F1CF                                  ;  1F1C6 F1C6 C F0 07           F:001402
  LDY #$D                                         ;  1F1C8 F1C8 C A0 0D           F:001431
  JSR CheckIfBlockIsSolid                                  ;  1F1CA F1CA C 20 33 F2        F:001431
  BCS B_15_1F1D3                                  ;  1F1CD F1CD C B0 04           F:001431
B_15_1F1CF:
  INC Workset+Ent_SwapBlock                                      ;  1F1CF F1CF C E6 F0           F:001402
  CLC                                             ;  1F1D1 F1D1 C 18              F:001402
  RTS                                             ;  1F1D2 F1D2 C 60              F:001402

B_15_1F1D3:
  LDA Workset+Ent_SwapBlock                                      ;  1F1D3 F1D3 C A5 F0           F:001379
  CMP #$C                                         ;  1F1D5 F1D5 C C9 0C           F:001379
  BCC B_15_1F1DE                                  ;  1F1D7 F1D7 C 90 05           F:001379
  SEC                                             ;  1F1D9 F1D9 C 38              F:001518
  SBC #$4                                         ;  1F1DA F1DA C E9 04           F:001518
  STA Workset+Ent_Damage                                      ;  1F1DC F1DC C 85 F1           F:001518
B_15_1F1DE:
  LDA #$0                                         ;  1F1DE F1DE C A9 00           F:001379
  STA Workset+Ent_SwapBlock                                      ;  1F1E0 F1E0 C 85 F0           F:001379
  SEC                                             ;  1F1E2 F1E2 C 38              F:001379
  RTS                                             ;  1F1E3 F1E3 C 60              F:001379

.byte $A5,$F1,$D0,$3B,$A5,$FA,$85,$0C             ;  1F1E4 F1E4 ........ ???;???? 
.byte $85,$0F,$A5,$F9,$85,$0E,$A6,$FB             ;  1F1EC F1EC ........ ???????? 
.byte $86,$0D,$E8,$86,$0A,$20,$54,$CA             ;  1F1F4 F1F4 ........ ????? T? 
.byte $A5,$FB,$C9,$A0,$B0,$1E,$20,$C7             ;  1F1FC F1FC ........ ?????? ? 
.byte $CE,$B0,$1C,$A0,$02,$20,$33,$F2             ;  1F204 F204 ........ ????? 3? 
.byte $B0,$15,$A0,$0E,$20,$33,$F2,$B0             ;  1F20C F20C ........ ???? 3?? 
.byte $0E,$A5,$F9,$F0,$07,$A0,$1A,$20             ;  1F214 F214 ........ ???????  
.byte $33,$F2,$B0,$03,$E6,$F0,$60,$A5             ;  1F21C F21C ........ 3?????`? 
.byte $F0,$C9,$0C,$90,$05,$38,$E9,$04             ;  1F224 F224 ........ ?????8?? 
.byte $85,$F1,$A9,$00,$85,$F0,$60                 ;  1F22C F22C .......  ??????`  

CheckIfBlockIsSolid:
  lda (BlockPtrLo),y                              ; get block type
  and #%00111111                                  ; clear palette bits
  cmp #$30                                        ; and compare against solid tile start offset
  rts                                             ; done!

L_15_1F23A:
  LDA TmpF                                      ;  1F23A F23A C A5 0F           F:001373
  STA PositionToBlock_XTile                                      ;  1F23C F23C C 85 0C           F:001373
  LDA TmpA                                      ;  1F23E F23E C A5 0A           F:001373
  STA PositionToBlock_YPx                                      ;  1F240 F240 C 85 0D           F:001373
  JSR PositionToBlock                                  ;  1F242 F242 C 20 54 CA        F:001373
  LDY #$0                                         ;  1F245 F245 C A0 00           F:001373
  JSR CheckIfBlockIsSolid2                                  ;  1F247 F247 C 20 D3 F2        F:001373
  BCS B_15_1F274                                  ;  1F24A F24A C B0 28           F:001373
  LDA TmpE                                      ;  1F24C F24C C A5 0E           F:001373
  BEQ B_15_1F257                                  ;  1F24E F24E C F0 07           F:001373
  LDY #$C                                         ;  1F250 F250 C A0 0C           F:001382
  JSR CheckIfBlockIsSolid2                                  ;  1F252 F252 C 20 D3 F2        F:001382
  BCS B_15_1F274                                  ;  1F255 F255 C B0 1D           F:001382
B_15_1F257:
  LDA TmpA                                      ;  1F257 F257 C A5 0A           F:001373
  CMP #$B0                                        ;  1F259 F259 C C9 B0           F:001373
  BCS B_15_1F273                                  ;  1F25B F25B C B0 16           F:001373
  AND #$F                                         ;  1F25D F25D C 29 0F           F:001373
  BEQ B_15_1F273                                  ;  1F25F F25F C F0 12           F:001373
  LDY #$1                                         ;  1F261 F261 C A0 01           F:001384
  JSR CheckIfBlockIsSolid2                                  ;  1F263 F263 C 20 D3 F2        F:001384
  BCS B_15_1F274                                  ;  1F266 F266 C B0 0C           F:001384
  LDA TmpE                                      ;  1F268 F268 C A5 0E           F:001384
  BEQ B_15_1F273                                  ;  1F26A F26A C F0 07           F:001384
  LDY #$D                                         ;  1F26C F26C C A0 0D           F:001389
  JSR CheckIfBlockIsSolid2                                  ;  1F26E F26E C 20 D3 F2        F:001389
  BCS B_15_1F274                                  ;  1F271 F271 C B0 01           F:001389
B_15_1F273:
  CLC                                             ;  1F273 F273 C 18              F:001373
B_15_1F274:
  RTS                                             ;  1F274 F274 C 60              F:001373

.byte $A5,$0F,$85,$0C,$A5,$0A,$85,$0D             ;  1F275 F275 ........ ???????? 
.byte $20,$54,$CA,$A0,$00,$20,$D3,$F2             ;  1F27D F27D ........  T??? ?? 
.byte $B0,$4B,$A0,$01,$20,$D3,$F2,$B0             ;  1F285 F285 ........ ?K?? ??? 
.byte $44,$A0,$0C,$20,$D3,$F2,$B0,$3D             ;  1F28D F28D ........ D?? ???= 
.byte $A0,$0D,$20,$D3,$F2,$B0,$36,$A5             ;  1F295 F295 ........ ?? ???6? 
.byte $0E,$F0,$0E,$A0,$18,$20,$D3,$F2             ;  1F29D F29D ........ ????? ?? 
.byte $B0,$2B,$A0,$19,$20,$D3,$F2,$B0             ;  1F2A5 F2A5 ........ ?+?? ??? 
.byte $24,$A5,$0A,$C9,$B0,$B0,$1D,$29             ;  1F2AD F2AD ........ $??????) 
.byte $0F,$F0,$19,$A0,$02,$20,$D3,$F2             ;  1F2B5 F2B5 ........ ????? ?? 
.byte $B0,$13,$A0,$0E,$20,$D3,$F2,$B0             ;  1F2BD F2BD ........ ???? ??? 
.byte $0C,$A5,$0E,$F0,$07,$A0,$1A,$20             ;  1F2C5 F2C5 ........ ???????  
.byte $D3,$F2,$B0,$01,$18,$60                     ;  1F2CD F2CD ......   ?????`   

CheckIfBlockIsSolid2:
  lda (BlockPtrLo),y                              ; get block type
  and #%00111111                                  ; clear palette bits
  cmp #$30                                        ; and compare against solid tile start offset
  rts                                             ; done!

L_15_1F2DA:
  LDA #$0                                         ;  1F2DA F2DA C A9 00           F:001402
  STA Workset+Ent_XTileSpeed                                      ;  1F2DC F2DC C 85 F6           F:001402
  LDX Workset+Ent_XPxSpeed                                      ;  1F2DE F2DE C A6 F5           F:001402
  BEQ B_15_1F30F                                  ;  1F2E0 F2E0 C F0 2D           F:001402
  STA Workset+Ent_XPxSpeed                                      ;  1F2E2 F2E2 C 85 F5           F:007624
  LDA Workset+Ent_YPx                                      ;  1F2E4 F2E4 C A5 FB           F:007624
  AND #$F                                         ;  1F2E6 F2E6 C 29 0F           F:007624
  BEQ B_15_1F347                                  ;  1F2E8 F2E8 C F0 5D           F:007624
  CMP #$6                                         ;  1F2EA F2EA C C9 06           F:007624
  BCC B_15_1F302                                  ;  1F2EC F2EC C 90 14           F:007624
  CMP #$B                                         ;  1F2EE F2EE C C9 0B           F:007624
  BCS B_15_1F2F5                                  ;  1F2F0 F2F0 C B0 03           F:007624
  JMP B_15_1F347                                  ;  1F2F2 F2F2 C 4C 47 F3        F:024833

B_15_1F2F5:
  LDA Workset_F4                                      ;  1F2F5 F2F5 C A5 F4           F:007624
  AND #$8                                         ;  1F2F7 F2F7 C 29 08           F:007624
  BNE B_15_1F347                                  ;  1F2F9 F2F9 C D0 4C           F:007624
  LDA #$1                                         ;  1F2FB F2FB C A9 01           F:007624
  STA Workset+Ent_YPxSpeed                                      ;  1F2FD F2FD C 85 F7           F:007624
  JMP L_15_1F343                                  ;  1F2FF F2FF C 4C 43 F3        F:007624

B_15_1F302:
  LDA Workset_F4                                      ;  1F302 F302 C A5 F4           F:025001
  AND #$4                                         ;  1F304 F304 C 29 04           F:025001
  BNE B_15_1F347                                  ;  1F306 F306 C D0 3F           F:025001
  LDA #$FF                                        ;  1F308 F308 C A9 FF           F:025001
  STA Workset+Ent_YPxSpeed                                      ;  1F30A F30A C 85 F7           F:025001
  JMP L_15_1F343                                  ;  1F30C F30C C 4C 43 F3        F:025001

B_15_1F30F:
  LDX Workset+Ent_YPxSpeed                                      ;  1F30F F30F C A6 F7           F:001402
  BEQ B_15_1F347                                  ;  1F311 F311 C F0 34           F:001402
  STA Workset+Ent_YPxSpeed                                      ;  1F313 F313 C 85 F7           F:001402
  LDA Workset+Ent_XPx                                      ;  1F315 F315 C A5 F9           F:001402
  BEQ B_15_1F347                                  ;  1F317 F317 C F0 2E           F:001402
  CMP #$6                                         ;  1F319 F319 C C9 06           F:001886
  BCC B_15_1F335                                  ;  1F31B F31B C 90 18           F:001886
  CMP #$B                                         ;  1F31D F31D C C9 0B           F:001886
  BCS B_15_1F324                                  ;  1F31F F31F C B0 03           F:001886
  JMP B_15_1F347                                  ;  1F321 F321 C 4C 47 F3        F:003642

B_15_1F324:
  LDA Workset_F4                                      ;  1F324 F324 C A5 F4           F:001886
  AND #$2                                         ;  1F326 F326 C 29 02           F:001886
  BNE B_15_1F347                                  ;  1F328 F328 C D0 1D           F:001886
  LDA #$1                                         ;  1F32A F32A C A9 01           F:001886
  STA Workset+Ent_XPxSpeed                                      ;  1F32C F32C C 85 F5           F:001886
  LDA #$0                                         ;  1F32E F32E C A9 00           F:001886
  STA Workset+Ent_XTileSpeed                                      ;  1F330 F330 C 85 F6           F:001886
  JMP L_15_1F343                                  ;  1F332 F332 C 4C 43 F3        F:001886

B_15_1F335:
  LDA Workset_F4                                      ;  1F335 F335 C A5 F4           F:003815
  AND #$1                                         ;  1F337 F337 C 29 01           F:003815
  BNE B_15_1F347                                  ;  1F339 F339 C D0 0C           F:003815
  LDA #$F                                         ;  1F33B F33B C A9 0F           F:003815
  STA Workset+Ent_XPxSpeed                                      ;  1F33D F33D C 85 F5           F:003815
  LDA #$FF                                        ;  1F33F F33F C A9 FF           F:003815
  STA Workset+Ent_XTileSpeed                                      ;  1F341 F341 C 85 F6           F:003815
L_15_1F343:
  JSR L_15_1F0E1                                  ;  1F343 F343 C 20 E1 F0        F:001886
  RTS                                             ;  1F346 F346 C 60              F:001886

B_15_1F347:
  SEC                                             ;  1F347 F347 C 38              F:001402
  RTS                                             ;  1F348 F348 C 60              F:001402

.byte $A9,$3D,$85,$2E,$A0,$03,$B1,$E7             ;  1F349 F349 ........ ?=?.???? 
.byte $85,$0A,$88,$B1,$E7,$85,$0F,$A9             ;  1F351 F351 ........ ???????? 
.byte $00,$85,$0E,$85,$0B,$20,$75,$F2             ;  1F359 F359 ........ ????? u? 
.byte $90,$01,$60,$A5,$0E,$85,$F9,$A5             ;  1F361 F361 ........ ??`????? 
.byte $0F,$85,$FA,$A5,$0A,$85,$FB,$A9             ;  1F369 F369 ........ ???????? 
.byte $00,$85,$F1,$85,$F0,$85,$F4,$A9             ;  1F371 F371 ........ ???????? 
.byte $01,$85,$EE,$A9,$81,$85,$ED,$A9             ;  1F379 F379 ........ ???????? 
.byte $02,$85,$EF,$A0,$05,$B1,$E7,$85             ;  1F381 F381 ........ ???????? 
.byte $F8,$A0,$04,$B1,$E7,$85,$F2,$8D             ;  1F389 F389 ........ ???????? 
.byte $15,$04,$8D,$25,$04,$8D,$35,$04             ;  1F391 F391 ........ ???%??5? 
.byte $A9,$E1,$85,$0E,$A9,$A7,$85,$0F             ;  1F399 F399 ........ ???????? 
.byte $20,$9C,$CC,$A9,$53,$85,$0E,$A9             ;  1F3A1 F3A1 ........  ???S??? 
.byte $CB,$85,$0F,$20,$9C,$CC,$60,$A5             ;  1F3A9 F3A9 ........ ??? ??`? 
.byte $F4,$29,$0F,$85,$F4,$A5,$F5,$05             ;  1F3B1 F3B1 ........ ?)?????? 
.byte $F7,$D0,$2C,$A5,$F4,$29,$03,$D0             ;  1F3B9 F3B9 ........ ??,??)?? 
.byte $04,$A9,$01,$85,$F4,$A6,$F3,$A9             ;  1F3C1 F3C1 ........ ???????? 
.byte $00,$85,$F3,$CA,$D0,$0D,$A5,$F4             ;  1F3C9 F3C9 ........ ???????? 
.byte $29,$03,$F0,$19,$49,$03,$85,$F4             ;  1F3D1 F3D1 ........ )???I??? 
.byte $4C,$F5,$F3,$20,$19,$EE,$A9,$80             ;  1F3D9 F3D9 ........ L?? ???? 
.byte $05,$F4,$85,$F4,$4C,$F5,$F3,$A5             ;  1F3E1 F3E1 ........ ????L??? 
.byte $F3,$C9,$32,$90,$07,$A9,$00,$85             ;  1F3E9 F3E9 ........ ??2????? 
.byte $F3,$20,$19,$EE,$A5,$F4,$A0,$02             ;  1F3F1 F3F1 ........ ? ?????? 
.byte $20,$70,$CD,$A5,$F0,$D0,$1C,$A5             ;  1F3F9 F3F9 ........  p?????? 
.byte $F1,$D0,$04,$A5,$F4,$10,$05,$20             ;  1F401 F401 ........ ???????  
.byte $E3,$F4,$90,$14,$A9,$00,$85,$F1             ;  1F409 F409 ........ ???????? 
.byte $20,$06,$F5,$90,$0B,$20,$11,$EF             ;  1F411 F411 ........  ???? ?? 
.byte $4C,$24,$F4,$20,$C3,$F4,$B0,$03             ;  1F419 F419 ........ L$? ???? 
.byte $20,$04,$EF,$20,$E4,$F1,$20,$3B             ;  1F421 F421 ........  ?? ?? ; 
.byte $F5,$20,$52,$F5,$4C,$F0,$EF,$A5             ;  1F429 F429 ........ ? R?L??? 
.byte $EE,$29,$7F,$D0,$3D,$A9,$18,$85             ;  1F431 F431 ........ ?)??=??? 
.byte $8F,$A9,$FF,$85,$90,$A2,$03,$20             ;  1F439 F439 ........ ???????  
.byte $40,$C5,$A9,$02,$85,$36,$20,$35             ;  1F441 F441 ........ @????6 5 
.byte $C1,$A2,$03,$20,$40,$C5,$A9,$05             ;  1F449 F449 ........ ??? @??? 
.byte $85,$36,$20,$35,$C1,$A2,$03,$20             ;  1F451 F451 ........ ?6 5???  
.byte $40,$C5,$EE,$EE,$00,$A9,$02,$8D             ;  1F459 F459 ........ @??????? 
.byte $8F,$00,$A9,$0F,$85,$F1,$A9,$00             ;  1F461 F461 ........ ???????? 
.byte $85,$F5,$85,$F6,$85,$F0,$A5,$FB             ;  1F469 F469 ........ ???????? 
.byte $85,$FC,$A5,$F0,$D0,$27,$C6,$F1             ;  1F471 F471 ........ ?????'?? 
.byte $F0,$18,$A5,$F1,$4A,$4A,$49,$FF             ;  1F479 F479 ........ ????JJI? 
.byte $18,$69,$01,$85,$F7,$20,$F1,$EF             ;  1F481 F481 ........ ?i??? ?? 
.byte $20,$08,$CF,$B0,$05,$A5,$0A,$85             ;  1F489 F489 ........  ??????? 
.byte $FB,$60,$A5,$EF,$09,$80,$85,$EF             ;  1F491 F491 ........ ?`?????? 
.byte $A9,$01,$85,$F0,$60,$E6,$F0,$A5             ;  1F499 F499 ........ ????`??? 
.byte $F0,$4A,$4A,$18,$69,$01,$85,$F7             ;  1F4A1 F4A1 ........ ?JJ?i??? 
.byte $20,$F1,$EF,$20,$08,$CF,$B0,$05             ;  1F4A9 F4A9 ........  ?? ???? 
.byte $A5,$0A,$85,$FB,$60,$A9,$00,$85             ;  1F4B1 F4B1 ........ ????`??? 
.byte $EE,$A9,$F0,$85,$F3,$A9,$01,$85             ;  1F4B9 F4B9 ........ ???????? 
.byte $EB,$60,$A5,$F0,$4A,$4A,$18,$69             ;  1F4C1 F4C1 ........ ?`??JJ?i 
.byte $01,$85,$F7,$20,$06,$F5,$B0,$01             ;  1F4C9 F4C9 ........ ??? ???? 
.byte $60,$A9,$00,$85,$F5,$85,$F6,$20             ;  1F4D1 F4D1 ........ `??????  
.byte $E1,$F0,$B0,$01,$60,$A9,$00,$85             ;  1F4D9 F4D9 ........ ????`??? 
.byte $F7,$60,$A6,$F1,$D0,$02,$A2,$19             ;  1F4E1 F4E1 ........ ?`?????? 
.byte $CA,$86,$F1,$8A,$4A,$4A,$49,$FF             ;  1F4E9 F4E9 ........ ????JJI? 
.byte $18,$69,$01,$85,$F7,$20,$06,$F5             ;  1F4F1 F4F1 ........ ?i??? ?? 
.byte $B0,$01,$60,$A9,$00,$85,$F5,$85             ;  1F4F9 F4F9 ........ ??`????? 
.byte $F6,$20,$06,$F5,$60,$A5,$F7,$48             ;  1F501 F501 ........ ? ??`??H 
.byte $20,$F1,$EF,$20,$08,$CF,$B0,$1D             ;  1F509 F509 ........  ?? ???? 
.byte $20,$C7,$CE,$90,$03,$20,$36,$F1             ;  1F511 F511 ........  ???? 6? 
.byte $20,$75,$F2,$90,$19,$A6,$F7,$F0             ;  1F519 F519 ........  u?????? 
.byte $14,$30,$02,$CA,$CA,$E8,$86,$F7             ;  1F521 F521 ........ ?0?????? 
.byte $D0,$DE,$4C,$36,$F5,$A9,$00,$85             ;  1F529 F529 ........ ??L6???? 
.byte $EE,$A9,$F0,$85,$F3,$38,$68,$85             ;  1F531 F531 ........ ?????8h? 
.byte $F7,$60,$A0,$00,$A5,$F6,$30,$06             ;  1F539 F539 ........ ?`????0? 
.byte $A5,$F5,$F0,$0C,$A0,$40,$84,$08             ;  1F541 F541 ........ ?????@?? 
.byte $A5,$EF,$29,$3F,$05,$08,$85,$EF             ;  1F549 F549 ........ ??)????? 
.byte $60,$E6,$F3,$A5,$F3,$29,$0C,$0A             ;  1F551 F551 ........ `????)?? 
.byte $09,$41,$85,$ED,$60,$A5,$FC,$8D             ;  1F559 F559 ........ ?A??`??? 
.byte $1F,$04,$8D,$2F,$04,$8D,$3F,$04             ;  1F561 F561 ........ ???/???? 
.byte $A5,$FB,$8D,$1E,$04,$18,$69,$10             ;  1F569 F569 ........ ??????i? 
.byte $8D,$2E,$04,$8D,$3E,$04,$A5,$F9             ;  1F571 F571 ........ ?.??>??? 
.byte $8D,$1C,$04,$8D,$2C,$04,$8D,$3C             ;  1F579 F579 ........ ????,??< 
.byte $04,$A6,$FA,$8E,$2D,$04,$E8,$8E             ;  1F581 F581 ........ ????-??? 
.byte $1D,$04,$8E,$3D,$04,$A6,$EE,$30             ;  1F589 F589 ........ ???=???0 
.byte $0D,$AD,$11,$04,$0D,$21,$04,$0D             ;  1F591 F591 ........ ?????!?? 
.byte $31,$04,$10,$02,$A2,$80,$8E,$01             ;  1F599 F599 ........ 1??????? 
.byte $04,$8E,$11,$04,$8E,$21,$04,$8E             ;  1F5A1 F5A1 ........ ?????!?? 
.byte $31,$04,$A5,$F2,$CD,$15,$04,$90             ;  1F5A9 F5A9 ........ 1??????? 
.byte $03,$AD,$15,$04,$CD,$25,$04,$90             ;  1F5B1 F5B1 ........ ?????%?? 
.byte $03,$AD,$25,$04,$CD,$35,$04,$90             ;  1F5B9 F5B9 ........ ??%??5?? 
.byte $03,$AD,$35,$04,$8D,$05,$04,$A5             ;  1F5C1 F5C1 ........ ??5????? 
.byte $ED,$09,$04,$8D,$10,$04,$09,$20             ;  1F5C9 F5C9 ........ ???????  
.byte $8D,$30,$04,$29,$FB,$8D,$20,$04             ;  1F5D1 F5D1 ........ ?0?)?? ? 
.byte $A5,$EF,$8D,$12,$04,$8D,$22,$04             ;  1F5D9 F5D9 ........ ??????"? 
.byte $8D,$32,$04,$29,$40,$F0,$18,$AD             ;  1F5E1 F5E1 ........ ?2?)@??? 
.byte $00,$04,$AE,$10,$04,$8D,$10,$04             ;  1F5E9 F5E9 ........ ???????? 
.byte $8E,$00,$04,$AD,$20,$04,$AE,$30             ;  1F5F1 F5F1 ........ ???? ??0 
.byte $04,$8D,$30,$04,$8E,$20,$04,$A5             ;  1F5F9 F5F9 ........ ??0?? ?? 
.byte $EF,$10,$18,$AD,$00,$04,$AE,$20             ;  1F601 F601 ........ ???????  
.byte $04,$8D,$20,$04,$8E,$00,$04,$AD             ;  1F609 F609 ........ ?? ????? 
.byte $10,$04,$AE,$30,$04,$8D,$30,$04             ;  1F611 F611 ........ ???0??0? 
.byte $8E,$10,$04,$A9,$53,$85,$0E,$A9             ;  1F619 F619 ........ ????S??? 
.byte $CB,$85,$0F,$20,$9C,$CC,$60                 ;  1F621 F621 .......  ??? ??`  

RunProjectileEntities:
  lda #MaxEnts                                    ; start at first projectile slot
  sta ActiveEntity                                ;
  lda #<ProjectileEnt0Data                        ; set pointer
  sta WorksetPtr                                  ;
  lda #>ProjectileEnt0Data                        ;
  sta WorksetPtr+1                                ;
@RunEntity:
  ldy #Ent_State                                  ; check entity state
  lda (WorksetPtr),y                              ;
  bne @HandleEntity                               ; skip ahead if active
  bit JoypadInput                                 ; check if player is pressing A 
  bvc @GoToNextEntity                             ; if not we skip ahead
  bit JoypadLastAction                            ; check if player has already fired
  bvs @GoToNextEntity                             ; if so we skip ahead
  jsr PlayerFireProjectile                        ; otherwise we fire a projectile
  jmp @GoToNextEntity                             ; then skip to the next entity
@HandleEntity:
  jsr RunSingleProjectile                         ; process this projectile
@GoToNextEntity:
  inc ActiveEntity                                ; advance slot
  clc                                             ;
  lda #$10                                        ; advance data pointer
  adc WorksetPtr                                  ;
  sta WorksetPtr                                  ;
  lda #$0                                         ;
  adc WorksetPtr+1                                ;
  sta WorksetPtr+1                                ;
  lda ActiveEntity                                ; check if we've reached the last projectile
  sec                                             ; for this character type
  sbc #$B                                         ;
  cmp PlayerAttrMaxProjectiles                    ;
  bcc @RunEntity                                  ; if not - keep running
  rts                                             ; otherwise we are done!

PlayerFireProjectile:
  JSR CopyDataToWorkset                                  ;  1F664 F664 C 20 8F E9        F:001756
  LDA JoypadInput                                      ;  1F667 F667 C A5 20           F:001756
  AND #$40                                        ;  1F669 F669 C 29 40           F:001756
  ORA JoypadLastAction                                      ;  1F66B F66B C 05 FD           F:001756
  STA JoypadLastAction                                      ;  1F66D F66D C 85 FD           F:001756
  LDY #$2                                         ;  1F66F F66F C A0 02           F:001756
  LDA PlayerSpeedBoostTimer1                                      ;  1F671 F671 C A5 88           F:001756
  BEQ :+                                  ;  1F673 F673 C F0 02           F:001756
  LDY #$4                                         ;  1F675 F675 C A0 04           F:033516
: LDA JoypadLastAction                                      ;  1F677 F677 C A5 FD           F:001756
  JSR SetWorksetDirectionSpeed                                  ;  1F679 F679 C 20 70 CD        F:001756
  JSR L_15_1F740                                  ;  1F67C F67C C 20 40 F7        F:001756
  JSR EnsureNextPositionIsValid                                  ;  1F67F F67F C 20 08 CF        F:001756
  BCS B_15_1F6B8                                  ;  1F682 F682 C B0 34           F:001756
  JSR UsePlayerMana                                  ;  1F684 F684 C 20 F0 E7        F:001756
  BCS B_15_1F6B8                                  ;  1F687 F687 C B0 2F           F:001756
  LDA TmpE                                      ;  1F689 F689 C A5 0E           F:001756
  STA Workset+Ent_XPx                                      ;  1F68B F68B C 85 F9           F:001756
  LDA TmpF                                      ;  1F68D F68D C A5 0F           F:001756
  STA Workset+Ent_XTile                                      ;  1F68F F68F C 85 FA           F:001756
  LDA TmpA                                      ;  1F691 F691 C A5 0A           F:001756
  STA Workset+Ent_YPx                                      ;  1F693 F693 C 85 FB           F:001756
  JSR GetCurrentPlayerDistance                                  ;  1F695 F695 C 20 67 D0        F:001756
  STA Workset+Ent_State                                      ;  1F698 F698 C 85 EE           F:001756
  BCS B_15_1F69F                                  ;  1F69A F69A C B0 03           F:001756
  JSR $E7F0                                       ;  1F69C F69C . 20 F0 E7        
B_15_1F69F:
  JSR GetCurrentPlayerStrength                                  ;  1F69F F69F C 20 51 D0        F:001756
  STA PlayerActiveStrength                                      ;  1F6A2 F6A2 C 85 F8           F:001756
  BCS B_15_1F6A9                                  ;  1F6A4 F6A4 C B0 03           F:001756
  JSR UsePlayerMana                                  ;  1F6A6 F6A6 C 20 F0 E7        F:017427
B_15_1F6A9:
  LDA #$0                                         ;  1F6A9 F6A9 C A9 00           F:001756
  STA Workset+Ent_SprAttr                                      ;  1F6AB F6AB C 85 EF           F:001756
  LDA #$21                                        ;  1F6AD F6AD C A9 21           F:001756
  STA Workset+Ent_Gfx                                      ;  1F6AF F6AF C 85 ED           F:001756
  lda #SFX_FireProjectile                         ; get offset for projectile sounds
  clc                                             ;
  adc PlayerCharacter                             ; and add character index to get a unique sound per character
  sta PendingSFX                                  ; then play that
B_15_1F6B8:
  JMP L_15_1F735                                  ;  1F6B8 F6B8 C 4C 35 F7        F:001756

RunSingleProjectile:
  jsr CopyDataToWorkset                           ; copy all entity data to our workset
  dec Workset+Ent_State                           ; reduce state by 1
  beq L_15_1F735                                  ; skip ahead if state was 1
  JSR CalcNextPosition                                  ;  1F6C2 F6C2 C 20 F1 EF        F:001757
  JSR EnsureNextPositionIsValid                                  ;  1F6C5 F6C5 C 20 08 CF        F:001757
  BCS B_15_1F722                                  ;  1F6C8 F6C8 C B0 58           F:001757
  JSR L_14_1CDB2                                  ;  1F6CA F6CA C 20 B2 CD        F:001757
  BCC B_15_1F729                                  ;  1F6CD F6CD C 90 5A           F:001757
  lda SelectedBank3                               ; use enemy gfx to determine if we are in a boss encounter
  cmp #$30                                        ;
  bcc @HandleRegularDamage                                  ;  1F6D3 F6D3 C 90 18           F:005270
  LDA R_0008                                      ;  1F6D5 F6D5 . A5 08           
  CMP #$4                                         ;  1F6D7 F6D7 . C9 04           
  BCC @HandleRegularDamage                              ;  1F6D9 F6D9 . 90 12           
  LDX Tmp9                                      ;  1F6DB F6DB . A6 09           
  LDA #$80                                        ;  1F6DD F6DD . A9 80           
  STA Ent0Data+Ent_State,X                                    ;  1F6DF F6DF . 9D 01 04        
  LDA #$1                                         ;  1F6E2 F6E2 . A9 01           
  STA Workset+Ent_State                                      ;  1F6E4 F6E4 . 85 EE           
  LDA #$C                                         ;  1F6E6 F6E6 . A9 0C           
  STA PendingSFX                                      ;  1F6E8 F6E8 . 85 8F           
  JMP $F71F                                       ;  1F6EA F6EA . 4C 1F F7        

@HandleRegularDamage:
  ldy Ent0Data+Ent_State,x                        ; check current entity state
  dey                                             ;
  bne B_15_1F729                                  ;  1F6F1 F6F1 C D0 36           F:005270
  ldx Tmp9                                        ; get entity data offset
  lda Workset+Ent_State                           ; check state of workset
  ldy #$FE                                        ;
  AND #EntState_Damaged                           ;  1F6F9 F6F9 C 29 01           F:005270
  BEQ B_15_1F6FF                                  ;  1F6FB F6FB C F0 02           F:005270
  LDY #$2                                         ;  1F6FD F6FD C A0 02           F:005271
B_15_1F6FF:
  TYA                                             ;  1F6FF F6FF C 98              F:005270
  STA Ent0Data+Ent_VibrateX,X                                    ;  1F700 F700 C 9D 0F 04        F:005270
  lda Ent0Data+Ent_HP,X                           ; get entity hitpoints
  sec                                             ;
  sbc PlayerActiveStrength                        ; damage by player strength
  sta Ent0Data+Ent_HP,x                           ; and update!
  bcs @Survived                                   ; if there is health left we keep going
  lda #EntState_Dying                             ; mark enemy as dying
  sta Ent0Data+Ent_State,x                        ;
  lda #$0                                         ; and clear hp
  sta Ent0Data+Ent_HP,x                           ;
  JMP L_15_1F71F                                  ;  1F718 F718 C 4C 1F F7        F:048485
@Survived:
  lda #SFX_EntityHurt                             ;  1F71B F71B C A9 06           F:005270
  sta PendingSFX                                  ;  1F71D F71D C 85 8F           F:005270
L_15_1F71F:
  JMP B_15_1F729                                  ;  1F71F F71F C 4C 29 F7        F:005270

B_15_1F722:
  LDA #$0                                         ;  1F722 F722 C A9 00           F:007547
  STA Workset+Ent_State                                      ;  1F724 F724 C 85 EE           F:007547
  JMP L_15_1F735                                  ;  1F726 F726 C 4C 35 F7        F:007547

B_15_1F729:
  LDA TmpE                                      ;  1F729 F729 C A5 0E           F:001757
  STA Workset+Ent_XPx                                      ;  1F72B F72B C 85 F9           F:001757
  LDA TmpF                                      ;  1F72D F72D C A5 0F           F:001757
  STA Workset+Ent_XTile                                      ;  1F72F F72F C 85 FA           F:001757
  LDA TmpA                                      ;  1F731 F731 C A5 0A           F:001757
  STA Workset+Ent_YPx                                      ;  1F733 F733 C 85 FB           F:001757
L_15_1F735:
  LDA Workset+Ent_State                                      ;  1F735 F735 C A5 EE           F:001756
  BEQ B_15_1F73C                                  ;  1F737 F737 C F0 03           F:001756
  JSR L_15_1F773                                  ;  1F739 F739 C 20 73 F7        F:001756
B_15_1F73C:
  JSR CopyWorksetToData                                  ;  1F73C F73C C 20 9A E9        F:001756
  RTS                                             ;  1F73F F73F C 60              F:001756

L_15_1F740:
  LDA PlayerXPx                                      ;  1F740 F740 C A5 43           F:001756
  STA TmpE                                      ;  1F742 F742 C 85 0E           F:001756
  LDA PlayerXTile                                      ;  1F744 F744 C A5 44           F:001756
  STA TmpF                                      ;  1F746 F746 C 85 0F           F:001756
  LDA PlayerYPx                                      ;  1F748 F748 C A5 45           F:001756
  STA TmpA                                      ;  1F74A F74A C 85 0A           F:001756
  LDA Workset+Ent_YPxSpeed                                      ;  1F74C F74C C A5 F7           F:001756
  BEQ B_15_1F757                                  ;  1F74E F74E C F0 07           F:001756
  ASL                                             ;  1F750 F750 C 0A              F:005601
  ASL                                             ;  1F751 F751 C 0A              F:005601
  CLC                                             ;  1F752 F752 C 18              F:005601
  ADC TmpA                                      ;  1F753 F753 C 65 0A           F:005601
  STA TmpA                                      ;  1F755 F755 C 85 0A           F:005601
B_15_1F757:
  LDA Workset+Ent_XPxSpeed                                      ;  1F757 F757 C A5 F5           F:001756
  BEQ B_15_1F772                                  ;  1F759 F759 C F0 17           F:001756
  ASL                                             ;  1F75B F75B C 0A              F:001756
  ASL                                             ;  1F75C F75C C 0A              F:001756
  AND #$F                                         ;  1F75D F75D C 29 0F           F:001756
  CLC                                             ;  1F75F F75F C 18              F:001756
  ADC TmpE                                      ;  1F760 F760 C 65 0E           F:001756
  PHA                                             ;  1F762 F762 C 48              F:001756
  AND #$F                                         ;  1F763 F763 C 29 0F           F:001756
  STA TmpE                                      ;  1F765 F765 C 85 0E           F:001756
  PLA                                             ;  1F767 F767 C 68              F:001756
  ASL                                             ;  1F768 F768 C 0A              F:001756
  ASL                                             ;  1F769 F769 C 0A              F:001756
  ASL                                             ;  1F76A F76A C 0A              F:001756
  ASL                                             ;  1F76B F76B C 0A              F:001756
  LDA TmpF                                      ;  1F76C F76C C A5 0F           F:001756
  ADC Workset+Ent_XTileSpeed                                      ;  1F76E F76E C 65 F6           F:001756
  STA TmpF                                      ;  1F770 F770 C 85 0F           F:001756
B_15_1F772:
  RTS                                             ;  1F772 F772 C 60              F:001756

L_15_1F773:
  LDA Workset+Ent_State                                      ;  1F773 F773 C A5 EE           F:001756
  AND #$C                                         ;  1F775 F775 C 29 0C           F:001756
  STA R_0008                                      ;  1F777 F777 C 85 08           F:001756
  LDA Workset+Ent_Gfx                                      ;  1F779 F779 C A5 ED           F:001756
  AND #$F3                                        ;  1F77B F77B C 29 F3           F:001756
  ORA R_0008                                      ;  1F77D F77D C 05 08           F:001756
  STA Workset+Ent_Gfx                                      ;  1F77F F77F C 85 ED           F:001756
  RTS                                             ;  1F781 F781 C 60              F:001756

RunBlockSwapEntity:
  lda Ent9Data+Ent_State                          ; is the entity active?
  bne :+                                          ; if so we run!
  rts                                             ; otherwise bail out.
: lda #<Ent9Data                                  ; activate entity slot 9 to be worked on
  sta WorksetPtr                                  ;
  lda #>Ent9Data                                  ;
  sta WorksetPtr+1                                ;
  jsr CopyDataToWorkset                           ;
  DEC Workset+Ent_AnimTimer                                      ;  1F793 F793 C C6 F3           F:003388
  BNE L_15_1F7F7                                  ;  1F795 F795 C D0 60           F:003388
  LDA Workset+Ent_Gfx                                      ;  1F797 F797 C A5 ED           F:003402
  AND #$1                                         ;  1F799 F799 C 29 01           F:003402
  BNE TryEntityBlockSwap                                  ;  1F79B F79B C D0 0D           F:003402
  LDA Workset+Ent_YPx                                      ;  1F79D F79D C A5 FB           F:007640
  AND #$F                                         ;  1F79F F79F C 29 0F           F:007640
  ORA Workset+Ent_XPx                                      ;  1F7A1 F7A1 C 05 F9           F:007640
  BEQ TryEntityBlockSwap                                  ;  1F7A3 F7A3 C F0 05           F:007640
  INC Workset+Ent_AnimTimer                                      ;  1F7A5 F7A5 . E6 F3           
  JMP L_15_1F7F7                      ;  1F7A7 F7A7 . 4C F7 F7        

TryEntityBlockSwap:
  lda #$0                                         ; disable workset entity
  sta Workset+Ent_State                           ;
  lda Workset+Ent_SwapBlock                       ; is there a related block swap?
  bne :+                                          ; if so - handle it!
  jmp CopyWorksetToData2                          ; otherwise just disable the entity
: lda Workset+Ent_XTile                    ; get block position for entity
  sta PositionToBlock_XTile                       ;
  lda Workset+Ent_YPx                      ;
  sta PositionToBlock_YPx                         ;
  jsr PositionToBlock                             ; and resolve its data pointer
  lda Workset+Ent_SwapBlock                       ; get tile we should swap to
  ldy #$0                                         ;
  sta (BlockPtrLo),y                                ; and perform the swap!
  lda Workset+Ent_XTile                    ; get x tile we swapped
  sec                                             ;
  sbc CameraXTile                                 ; and check distance from side of screen
  cmp #$11                                        ;
  bcc @Draw                                       ; show sprite if we're in a good position
  cmp #$FE                                        ;
  bcc @Done                                       ; just do nothing if it's going to look weird.
@Draw:
  LDA Workset+Ent_XTile                                      ;  1F7D3 F7D3 C A5 FA           F:003402
  STA BlockPtrLo                                      ;  1F7D5 F7D5 C 85 0C           F:003402
  ASL                                             ;  1F7D7 F7D7 C 0A              F:003402
  AND #$1F                                        ;  1F7D8 F7D8 C 29 1F           F:003402
  STA PPUUpdateAddrLo                                      ;  1F7DA F7DA C 85 16           F:003402
  LDA Workset+Ent_XTile                                      ;  1F7DC F7DC C A5 FA           F:003402
  AND #$10                                        ;  1F7DE F7DE C 29 10           F:003402
  LSR                                             ;  1F7E0 F7E0 C 4A              F:003402
  LSR                                             ;  1F7E1 F7E1 C 4A              F:003402
  STA PPUUpdateAddrHi                                      ;  1F7E2 F7E2 C 85 17           F:003402
  CLC                                             ;  1F7E4 F7E4 C 18              F:003402
  LDA #$0                                         ;  1F7E5 F7E5 C A9 00           F:003402
  ADC PPUUpdateAddrLo                                      ;  1F7E7 F7E7 C 65 16           F:003402
  STA PPUUpdateAddrLo                                      ;  1F7E9 F7E9 C 85 16           F:003402
  LDA #$20                                        ;  1F7EB F7EB C A9 20           F:003402
  ADC PPUUpdateAddrHi                                      ;  1F7ED F7ED C 65 17           F:003402
  STA PPUUpdateAddrHi                                      ;  1F7EF F7EF C 85 17           F:003402
  JSR BankAndDrawMetatileColumn                                  ;  1F7F1 F7F1 C 20 33 C8        F:003402
@Done:
  JMP CopyWorksetToData2                                  ;  1F7F4 F7F4 C 4C 96 F8        F:003403

L_15_1F7F7:
  LDA Workset+Ent_Gfx                                      ;  1F7F7 F7F7 C A5 ED           F:003388
  AND #$1                                         ;  1F7F9 F7F9 C 29 01           F:003388
  BEQ B_15_1F80C                                  ;  1F7FB F7FB C F0 0F           F:003388
  lda Workset+Ent_AnimTimer                       ; check if it's time to animate the entity
  and #$3                                         ;
  bne :+                                          ; if not - skip to save
  lda Workset+Ent_Gfx                                 ; swap sprite for animation
  eor #$4                                         ;
  sta Workset+Ent_Gfx                                 ;
: jmp CopyWorksetToData2                          ; update the entity

B_15_1F80C:
  LDA #$9                                         ;  1F80C F80C C A9 09           F:007626
  STA ActiveEntity                                      ;  1F80E F80E C 85 E3           F:007626
  JSR CalcNextPosition                                  ;  1F810 F810 C 20 F1 EF        F:007626
  JSR L_14_1CF1C                                  ;  1F813 F813 C 20 1C CF        F:007626
  BCS B_15_1F85A                                  ;  1F816 F816 C B0 42           F:007626
  JSR L_15_1F23A                                  ;  1F818 F818 C 20 3A F2        F:007626
  BCS B_15_1F85A                                  ;  1F81B F81B C B0 3D           F:007626
  JSR L_14_1CE7C                                  ;  1F81D F81D C 20 7C CE        F:007626
  BCS B_15_1F846                                  ;  1F820 F820 C B0 24           F:007626
  JSR L_14_1CDB2                                  ;  1F822 F822 C 20 B2 CD        F:007626
  BCC B_15_1F82E                                  ;  1F825 F825 C 90 07           F:007626
  LDX Tmp9                                      ;  1F827 F827 C A6 09           F:026945
  LDA #$80                                        ;  1F829 F829 C A9 80           F:026945
  STA Ent0Data+Ent_State,X                                    ;  1F82B F82B C 9D 01 04        F:026945
B_15_1F82E:
  LDA TmpE                                      ;  1F82E F82E C A5 0E           F:007626
  STA Workset+Ent_XPx                                      ;  1F830 F830 C 85 F9           F:007626
  LDA TmpF                                      ;  1F832 F832 C A5 0F           F:007626
  STA Workset+Ent_XTile                                      ;  1F834 F834 C 85 FA           F:007626
  LDA TmpA                                      ;  1F836 F836 C A5 0A           F:007626
  STA Workset+Ent_YPx                                      ;  1F838 F838 C 85 FB           F:007626
  LDA #$0                                         ;  1F83A F83A C A9 00           F:007626
  STA Workset_F4                                      ;  1F83C F83C C 85 F4           F:007626
  JMP CopyWorksetToData2                                  ;  1F83E F83E C 4C 96 F8        F:007626

.byte $E6,$F3,$4C,$96,$F8                         ;  1F841 F841 .....    ??L??    
B_15_1F846:
  LDA Workset_F4                                      ;  1F846 F846 C A5 F4           F:026913
  BNE B_15_1F886                                  ;  1F848 F848 C D0 3C           F:026913
  LDA InvincibilityFramesTimer                                      ;  1F84A F84A C A5 85           F:026913
  BNE B_15_1F85A                                  ;  1F84C F84C C D0 0C           F:026913
  JSR $E7CE                                       ;  1F84E F84E . 20 CE E7        
  LDA #$A                                         ;  1F851 F851 . A9 0A           
  STA a:PendingSFX                                    ;  1F853 F853 . 8D 8F 00        
  LDA #$2                                         ;  1F856 F856 . A9 02           
  STA InvincibilityFramesTimer                                      ;  1F858 F858 . 85 85           
B_15_1F85A:
  LDA Workset_F4                                      ;  1F85A F85A C A5 F4           F:007643
  BNE B_15_1F886                                  ;  1F85C F85C C D0 28           F:007643
  INC Workset_F4                                      ;  1F85E F85E C E6 F4           F:026901
  LDA Workset+Ent_XPxSpeed                                      ;  1F860 F860 C A5 F5           F:026901
  BEQ B_15_1F873                                  ;  1F862 F862 C F0 0F           F:026901
  EOR #$FF                                        ;  1F864 F864 C 49 FF           F:026901
  CLC                                             ;  1F866 F866 C 18              F:026901
  ADC #$1                                         ;  1F867 F867 C 69 01           F:026901
  AND #$F                                         ;  1F869 F869 C 29 0F           F:026901
  STA Workset+Ent_XPxSpeed                                      ;  1F86B F86B C 85 F5           F:026901
  LDA Workset+Ent_XTileSpeed                                      ;  1F86D F86D C A5 F6           F:026901
  EOR #$FF                                        ;  1F86F F86F C 49 FF           F:026901
  STA Workset+Ent_XTileSpeed                                      ;  1F871 F871 C 85 F6           F:026901
B_15_1F873:
  LDA Workset+Ent_YPxSpeed                                      ;  1F873 F873 C A5 F7           F:026901
  EOR #$FF                                        ;  1F875 F875 C 49 FF           F:026901
  TAX                                             ;  1F877 F877 C AA              F:026901
  INX                                             ;  1F878 F878 C E8              F:026901
  STX Workset+Ent_YPxSpeed                                      ;  1F879 F879 C 86 F7           F:026901
  LDA PendingSFX                                      ;  1F87B F87B C A5 8F           F:026901
  BNE B_15_1F883                                  ;  1F87D F87D C D0 04           F:026901
  LDA #$6                                         ;  1F87F F87F C A9 06           F:026901
  STA PendingSFX                                      ;  1F881 F881 C 85 8F           F:026901
B_15_1F883:
  JMP CopyWorksetToData2                                  ;  1F883 F883 C 4C 96 F8        F:026901

B_15_1F886:
  LDA Workset+Ent_YPx                                      ;  1F886 F886 C A5 FB           F:007643
  AND #$F                                         ;  1F888 F888 C 29 0F           F:007643
  ORA Workset+Ent_XPx                                      ;  1F88A F88A C 05 F9           F:007643
  BEQ B_15_1F893                                  ;  1F88C F88C C F0 05           F:007643
  INC Workset+Ent_AnimTimer                                      ;  1F88E F88E . E6 F3           
  JMP $F896                                       ;  1F890 F890 . 4C 96 F8        

B_15_1F893:
  JMP TryEntityBlockSwap                                  ;  1F893 F893 C 4C AA F7        F:007643

CopyWorksetToData2:
  jsr CopyWorksetToData                           ; not exactly a useful routine, but..
  rts                                             ; it is what it is.

InsertAudioEngineCode                             ; macro from audio.s

MMC3ActivateGamePRGBank:
  ldx #$6                                         ; start with $8000-9FFF
  ldy #$A                                         ; loading bank A
  stx MMC3_RegBankSelect                          ;
  sty MMC3_RegBankData                            ;
  inx                                             ; then $A000-BFFF
  iny                                             ; with bank B
  stx MMC3_RegBankSelect                          ;
  sty MMC3_RegBankData                            ;
  rts                                             ; done!

MMC3ActivateAudioPRGBank:
  lda #$6                                         ; change $8000-9FFF
  sta MMC3_RegBankSelect                          ;
  lda AudioDataBank                               ; to whatever audio data bank is active
  sta MMC3_RegBankData                            ;
  lda #$7                                         ; change $A000-BFFF
  sta MMC3_RegBankSelect                          ;
  lda AudioDataBank+1                             ; to whatever audio data bank is active
  sta MMC3_RegBankData                            ;
  rts                                             ; done!

MMC3ActivateAreaDataPRGBank:
  lda #$6                                         ; change $8000-9FFF
  sta MMC3_RegBankSelect                          ;
  lda SelectedBank6                               ; to the data bank for our current area
  sta MMC3_RegBankData                            ;
  lda #$7                                         ; change $A000-BFFF
  sta MMC3_RegBankSelect                          ;
  lda SelectedBank7                               ; to the data bank for our current area
  sta MMC3_RegBankData                            ;
  rts                                             ; done!

InsertAudioData2                                  ; from audio.s

PlayerDirections:
;       X   Y
.byte $00,$00 ; -
.byte $01,$00 ; R
.byte $FF,$00 ; L
.byte $00,$00 ; R+L
.byte $00,$01 ; D
.byte $01,$01 ; D+R
.byte $FF,$01 ; D+L
.byte $00,$01 ; D+R+L
.byte $00,$FF ; U
.byte $01,$FF ; U+R
.byte $FF,$FF ; U+L
.byte $00,$FF ; U+R+L
.byte $00,$00 ; U+D
.byte $01,$00 ; U+D+R
.byte $FF,$00 ; U+D+L
.byte $00,$00 ; U+D+R+L

MattockTileDirections:
;       X   Y
.byte $00,$00 ; -
.byte $01,$00 ; R
.byte $FF,$00 ; L
.byte $00,$00 ; R+L
.byte $00,$10 ; D
.byte $01,$10 ; D+R
.byte $FF,$10 ; D+L
.byte $00,$10 ; D+R+L
.byte $00,$F0 ; U
.byte $01,$F0 ; U+R
.byte $FF,$F0 ; U+L
.byte $00,$F0 ; U+R+L
.byte $00,$00 ; U+D
.byte $01,$00 ; U+D+R
.byte $FF,$00 ; U+D+L
.byte $00,$00 ; U+D+R+L


StatusBarBGData:
.byte $FD,$FC,$FC,$FC,$FC,$FC,$FD,$FC,$FC,$FC,$FC,$FC,$FD,$FC,$FC,$FC
.byte $FC,$FC,$FD,$FC,$FC,$FC,$FC,$FC,$FD,$FC,$FC,$FC,$FC,$FC,$FC,$FD
.byte $FB,$EC,$E9,$E6,$E5,$C0,$FB,$ED,$E1,$E7,$E9,$E3,$FB,$EB,$E5,$F9
.byte $C0,$C0,$FB,$E7,$EF,$EC,$E4,$C0,$FB,$E9,$F4,$E5,$ED,$C0,$C0,$FB
.byte $FB,$DD,$DD,$DE,$DF,$DF,$FB,$DD,$DD,$DD,$DE,$DF,$FB,$DD,$DE,$DF
.byte $DF,$DF,$FB,$DD,$DF,$DF,$DF,$DF,$FB,$C0,$C0,$C0,$C0,$C0,$C0,$FB
.byte $FB,$DA,$DA,$DA,$DA,$DC,$FB,$DB,$DF,$DF,$DF,$DF,$FB,$DA,$DA,$DA
.byte $DA,$DB,$FB,$DA,$DA,$DA,$DB,$DC,$FB,$C0,$C0,$C0,$C0,$C0,$C0,$FB
.byte $FE,$FC,$FC,$FC,$FC,$FC,$FE,$FC,$FC,$FC,$FC,$FC,$FE,$FC,$FC,$FC
.byte $FC,$FC,$FE,$FC,$FC,$FC,$FC,$FC,$FE,$FC,$FC,$FC,$FC,$FC,$FC,$FE
StatusBarBGDataEnd:

Spr0Data:
.byte StatusBarHeight-2                            ; clip spr0 into StatusBar a little
.byte $FD
.byte $23
.byte $D0

HomeSprites:
.byte $9B,$0D,$00,$64
.byte $9B,$0F,$00,$6C
.byte $9B,$2D,$00,$84
.byte $9B,$2F,$00,$8C
.byte $AB,$43,$40,$44
.byte $AB,$41,$40,$4C
.byte $BB,$63,$40,$64
.byte $BB,$61,$40,$6C
.byte $BB,$81,$00,$A4
.byte $BB,$83,$00,$AC
.byte $AB,$AD,$00,$A4
.byte $AB,$AF,$00,$AC
.byte $AB,$CD,$00,$C4
.byte $AB,$CF,$00,$CC
HomeSpritesEnd:

; Each character has 4 attributes,
; Jump, Strength, Max Projectiles, Projectile Distance
CharacterAttributeData:
.byte $12,$03,$01,$10                             ; Xemn
.byte $14,$02,$02,$18                             ; Meyna
.byte $14,$01,$03,$20                             ; Roas
.byte $1A,$01,$03,$20                             ; Lil
.byte $12,$03,$05,$08                             ; Pochi

CharacterUsableItems:
.dbyt %0101010011111100                           ; Xemn
.dbyt %1000101111111100                           ; Meyna
.dbyt %0100011011111111                           ; Roas
.dbyt %0010011011111100                           ; Lil
.dbyt %0000000001111100                           ; Pochi

CharacterPalettes:
.byte $0F,$0F,$2A,$36                             ; Xemn
.byte $0F,$0C,$25,$36                             ; Meyna
.byte $0F,$0C,$3C,$36                             ; Roas
.byte $0F,$06,$15,$36                             ; Lil
.byte $0F,$06,$30,$25                             ; Pochi

.byte $00,$00,$00,$00,$00,$00,$00                 ; unused padding

VReset:
  SEI                                             ; setup mmc3
  LDA #$0                                         ;
  STA MMC3_RegBankSelect                          ;
  STA MMC3_PRGRamProtect                          ;
  STA MMC3_IRQDisable                             ;
  JMP ResetGame                                   ; then start the game

.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00

.addr VNMI
.addr VReset
.addr VNMI
