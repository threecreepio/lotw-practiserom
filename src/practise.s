.macro PractiseCommonBank

WaitForCountdownTimer2:
  lda #0
  sta $6000
  jsr WaitForCountdownTimer
  lda #1
  sta $6000
  rts

PRAC_PPUOp_UpdatePalette:
  lda $6000
  beq :+
  jsr PRAC_DrawRNG
: jmp PPUOp_UpdatePalette

Practise_SelectPause:
  ldy #$E                                         ; switch to practise code bank
  jsr MMC3ActivatePRGBank                         ;
  jsr Practise_SelectPause_Inner                  ; and run the select pause code
  pha                                             ; store return value
  jsr AreaDataLocate                              ; select area data bank
  pla                                             ; restore return value
  rts                                             ; exit

Practise_ReloadAreaConfig:
  jsr ReloadAreaConfig
  jsr L_14_1C5DC
  ldy #$E
  jmp MMC3ActivatePRGBank

Practise_L_14_1D6D4:
  jsr L_14_1D6D4
  php
  ldy #$E
  jsr MMC3ActivatePRGBank
  plp
  rts

Practise_EnterMenuScreen:
  jsr PutPlayerLocationOnStack                    ; store players current location
  ldy #$E                                         ; and switch to the practise bank
  jsr MMC3ActivatePRGBank                         ; 
  jsr Practise_EnterMenuScreen_Inner              ; then run the actual menu screen
  jsr RestorePlayerLocationFromStack              ; restore player location from stack
  jsr L_15_1E5FD_2                                ; and transition back to the game
  lda #$F0                                        ; set this so the game will unpause
  rts                                             ; done!

DisableableRunIntervalTimers:
  lda IntervalTimer                               ; is the interval timer negative?
  bmi :+                                          ; yes - don't run interval timers
  jmp RunIntervalTimers                           ; otherwise run them!
: rts                                             ; wow!

PRAC_DrawRNG:
  lda #>$2359                                     ; write rng value to the top right
  sta PPU_ADDR                                    ; on any frame where nothing else is needed
  lda #<$2359                                     ;
  sta PPU_ADDR                                    ;
  lda RNGValue                                    ;
  jsr PRAC_HexToPPU                               ;
  lda RNGValue+1                                  ;
  jsr PRAC_HexToPPU                               ;
  lda RNGValue+2                                  ;
  jsr PRAC_HexToPPU                               ;
  rts

PRAC_CommonNMI:
  jsr PRAC_DrawRNG
  jmp CommonNMI                                   ; then continue to normal NMI code

PRAC_HexToPPU:
  pha                                             ;
  lsr a                                           ; write high nybble
  lsr a                                           ;
  lsr a                                           ;
  lsr a                                           ;
  jsr ToHexNybble2                                ;
  sta PPU_DATA                                    ;
  pla                                             ;
  and #$0F                                        ; write low nybble
  jsr ToHexNybble2                                ;
  sta PPU_DATA                                    ;
  rts                                             ; done

ToHexNybble2:
  cmp #$A                                         ; check if >= A
  bcc :+                                          ; if not, skip ahead
  adc #6                                          ; otherwise add 6 to move to the A character
: clc                                             ;
  adc #$D0                                        ; add offset to 0 character
  rts                                             ; done

.endmacro

Practise_SelectPause_Inner:
  ldx #0                                          ; clear temp value
  stx $1                                          ;
: lda #1                                          ;
  sta FrameCountdownTimer                         ;
  jsr UpdatePlayerSprites                         ; make sure graphics are updating
  jsr UpdateEntitySprites                         ;
  jsr UpdateInventorySprites                      ;
  jsr WaitForCountdownTimer                       ; delay for a frame
  jsr ReadJoypad                                  ; read controller state
  cmp #CtlT|CtlS                                  ; are we holding both Start and Select?
  beq @EnterPause                                 ; if so - enter the practise menu screen
  ldx $1                                          ; otherwise, increment temp value by 1
  inx                                             ;
  stx $1                                          ;
  cpx #60                                         ; check if select has been held for 1 second
  bcs @EnterNoClipMovement                        ; if so - branch out to allow moving through walls etc
  lda JoypadInput                                 ; check current held inputs
  bne :-                                          ; if we haven't released the inputs, loop back
  jsr WaitUntilInputsHeld                         ; then wait until a button is pressed
  pha                                             ; and store the inputs
  jsr WaitUntilNoInputsHeld                       ; wait until the user stops pressing any inputs
  pla                                             ; restore the inputs that were pressed
  sta JoypadInput                                 ; and store those as our inputs
  rts                                             ; done
@EnterPause:
  jmp Practise_EnterMenuScreen                    ; start the practise menu
@EnterNoClipMovement:
  jmp Practise_NoClipMovement                     ; start noclip movement


Practise_NoClipMovement:
  lda #SFX_Warp                                   ; play a little sound so the player knows they can move freely
  sta PendingSFX                                  ;
  jsr WaitUntilNoInputsHeld                       ; wait until the user releases any inputs
@Move:
  lda #1                                          ; delay for a frame
  sta FrameCountdownTimer                         ;
  jsr WaitForCountdownTimer                       ;
  jsr UpdateCameraPPUScroll
  jsr ReadJoypad                                  ; check player inputs
  cmp #CtlS                                       ; if player presses select, we return to game
  bne :+                                          ;
  jsr WaitUntilNoInputsHeld
  lda #$F0                                        ; set this so the game will unpause
  rts                                             ;
: and #CtlDPad                                    ; otherwise if the player is holding a d-pad button
  beq @Move                                       ; loop back up if not
  lda #$FF                                        ; clear selected entity
  sta ActiveEntity                                ;
  lda CameraXTile                                 ; and copy the current drawn column
  sta CurrentCameraXTile                          ;
  lda JoypadInput                                 ; set movement speed depending on B button
  and #CtlB                                       ;
  lsr a                                           ;
  lsr a                                           ;
  lsr a                                           ;
  ora #1                                          ;
  tay                                             ;
  jsr RunPlayerMovement                           ; run standard player movement
  jsr RunPlayerMovement2                          ;
  lda #1                                          ; set some values that are required
  sta PlayerFallHeight                            ; to detect moving between screens
  sta PlayerJumpProgress                          ;
  JSR CheckIfAtAreaTransition                     ; check if player is at an edge
  bcc @TransitionChecked                          ; if not - continue ahead
  JSR SafeCheckIfAtAreaTransition                 ; if so, double-check while not allowing transitions at the corners
  bcc @NoRenderNeeded                             ; if we are in a corner - block movement
  jsr Practise_L_14_1D6D4                         ; attempt to transition to a new screen
  bcc @NoRenderNeeded                             ; if we can't, block movement
  jsr L_14_1D991                                  ;
@TransitionChecked:
  jsr L_14_1D536                                  ; update movement
  jsr UpdateCameraPosition                        ; position camera relative to the player
  php                                             ;
  jsr UpdatePlayerSprites                         ; redraw player
  jsr UpdateEntitySprites                         ; redraw entities
  plp                                             ;
  bcs @NoRenderNeeded                             ; if we don't need to render new tiles, skip ahead
  lda CurrentCameraXTile                          ; have we changed tiles?
  cmp CameraXTile                                 ;
  beq @NoRenderNeeded                             ; if not - skip ahead
  inc ColumnWritePending                          ; otherwise mark that we need to write a new column to the ppu
@NoRenderNeeded:
  jmp @Move                                       ; and loop back around


SafeCheckIfAtAreaTransition:
  ldx #0                                          ;
  jsr @CheckX                                     ; check if at X edge
  jsr @CheckY                                     ; check if at Y edge
  cpx #1                                          ; are we at exactly 1 edge?
  beq @Done                                       ; if so - we're good to go
  clc                                             ; otherwise we fail the check.
@Done:                                            ;
  rts                                             ; done

@CheckX:                                          ;
  lda TmpF                                        ; are we at the leftmost tile?
  bne :+                                          ; if not - skip ahead
  lda TmpE                                        ; if so, are we right at the edge?
  cmp #$8                                         ;
  bcc @Move                                       ; if so we want to transition to the left
  rts                                             ;
: cmp #$3E                                        ; are we at the right edge?
  bcs @Move                                       ; if so we want to transition to the right
  rts                                             ; done

@CheckY:                                          ;
  lda TmpA                                        ; are we at the top edge?
  cmp #$10                                        ;
  bcc @Move                                       ; if so we want to transition upward
  cmp #$A0                                        ; are we at the bottom edge?
  bcs @Move                                       ; if so we want to transition downward
  rts                                             ; done

@Move:                                            ;
  inx                                             ; mark that a transition is wanted
  rts                                             ; done

Practise_EnterMenuScreen_Inner:
  lda IntervalTimer                               ; mark interval timer as negative
  ora #$80                                        ; to prevent counting down timers
  sta IntervalTimer                               ;
  jsr L_14_1C430                                  ; run screen transition
  lda #$8                                         ; position player for pause menu
  sta PlayerXTile                                 ;
  lda #0                                          ;
  sta PlayerXPx                                   ;
  sta PlayerJumpProgress                          ;
  sta PlayerFallHeight                            ;
  lda #$60                                        ;
  sta PlayerYPx                                   ;
  lda #$10                                        ; set practise pause area
  sta CurrentAreaY                                ;
  lda #2                                          ;
  sta CurrentAreaX                                ;
  lda #$20                                        ;
  sta CameraXTile                                 ;
  jsr ClearEntitySprites                          ; and remove any active entity sprites
  jsr Practise_ReloadAreaConfig
  lda #8                                          ; position camera
  sta CameraXPx                                   ;
  jsr UpdateCameraPPUScroll                       ;
  jsr UpdatePlayerSprites                         ; draw anything relevant for the menu
  jsr PauseMenu_DrawInventory                     ;
  jsr PauseMenu_DrawScrolls                       ;
  jsr PauseMenu_DrawRNG                           ;
  jsr @PractisePauseMenu                          ;
  lda IntervalTimer                               ; restore interval timer
  and #$7F                                        ;
  sta IntervalTimer                               ;
  rts                                             ; done!

@PractisePauseMenu:
  @TmpSelectedItemType = $8
  jsr WaitFrame                                   ; wait for a frame
  lda #0                                          ; clear temp value
  sta $1                                          ;
  lda PlayerXPx                                   ; copy player position to temp values
  sta TmpE                                        ;
  lda PlayerXTile                                 ;
  sta TmpF                                        ;
  lda PlayerYPx                                   ;
  sta TmpA                                        ;
  jsr ReadJoypad                                  ; check joypad
  cmp #CtlA                                       ; are we activating something?
  bne @NoAPress                                   ; if not - skip ahead
@HandleAPress:
  jsr ReadJoypad                                  ; otherwise read inputs again
  and #CtlA                                       ; are we still holding A?
  beq @ReleaseA                                   ; if not - skip ahead
  lda JoypadInput                                 ; are we holding a direction?
  and #CtlDPad                                    ;
  beq @APressWait                                 ; if not, do nothing
  jsr ModifySelectedItem                          ; otherwise modify whatever the player has selected
  lda #1                                          ; and mark the temp value as 1
  sta $1                                          ;
@WaitForDPadRelease:
  jsr ReadJoypad                                  ; loop until d-pad released
  and #CtlDPad                                    ;
  bne @WaitForDPadRelease                         ;
@APressWait:
  jmp @HandleAPress                               ; loop back around
@ReleaseA:
  lda $1                                          ; when A is released, check if temp value was set
  bne :+                                          ; if so - we can just exit
  jsr UseSelectedItem                             ; otherwise we tapped A, so, use the item
  bcc :+                                          ;
: jmp @PractisePauseMenu                          ; then loop back around
@NoAPress:
  lda JoypadInput                                 ; check if player pressed Start
  cmp #CtlT                                       ;
  beq @ExitSEC                                    ; if so - exit out of pause menu
  and #%00001111                                  ;
  ldy #$2                                         ; set speed on menu
  jsr RunPlayerMovement                           ; and run movement code
  jsr RunPlayerMovement2                          ;
  lda TmpA                                        ; get next player Y position
  cmp #$1                                         ; prevent moving off top of screen
  bcc @MovementDone                               ;
  cmp #$B1                                        ; prevent moving off bottom of screen
  bcs @MovementDone                               ;
  lda TmpF                                        ; check next player x tile
  and #%00001111                                  ;
  cmp #$1                                         ; prevent moving off left of screen
  bcc @MovementDone                               ;
  cmp #$F                                         ; prevent moving off right of screen
  bcc @UpdatePlayerPosition                       ;
  lda TmpE                                        ;
  bne @MovementDone                               ; prevent movement
@UpdatePlayerPosition:
  lda TmpE                                        ; copy temp values to player position
  sta PlayerXPx                                   ;
  lda TmpF                                        ;
  sta PlayerXTile                                 ;
  lda TmpA                                        ;
  sta PlayerYPx                                   ;
@MovementDone:
  jsr SelectPlayerSprite1                         ; update sprites
  jsr RunPlayerAnimation                          ;
  jsr UpdatePlayerSprites                         ;
  jmp @PractisePauseMenu                          ; and loop back around
@ExitSEC:
  rts

GetSelectedItemOffset:
  @TmpSelectedItemType = $8
  lda PlayerYPx                                   ; check if player is too far down for the inventory
  ldx #0                                          ; set offset for first row
  cmp #$38                                        ; check if we should use the second row
  bcc :+                                          ;
  ldx #$8                                         ; if we're on the second row, offset X
: stx @TmpSelectedItemType                        ; store row value
  lda PlayerXTile                                 ; then get exact slot based on player x position
  and #$0F
  lsr a                                           ;
  ora @TmpSelectedItemType                        ; and add back the row bit
  tax                                             ; use that as the offset into the inventory table
  rts

WaitFrame:
  lda #1                                          ; delay for 1 frame
  sta FrameCountdownTimer                         ;
  jmp WaitForCountdownTimer                       ;

GetSelectedMenuType:
  lda PlayerYPx                                   ; get offset into data based on player position
  and #$F0                                        ;
  sta $1                                          ;
  lda PlayerXTile                                 ;
  and #$F                                         ;
  ora $1                                          ;
  tax                                             ;
  lda PracPauseMap,x                              ; and load the type at that position
  rts                                             ; done!

UseSelectedItem:
  jsr GetSelectedMenuType                         ; get type at position
  beq @Skip                                       ; if none, do nothing
  asl a                                           ; otherwise get offset into table
  tax                                             ;
  lda @Ops,x                                      ;
  sta $1                                          ;
  lda @Ops+1,x                                    ;
  beq @Skip                                       ; if the address is $0000, do nothing
  sta $2                                          ;
  clc                                             ;
  lda $0                                          ;
  jmp ($1)                                        ; otherwise jump to handler
@Skip:
  rts
@Ops:
  .addr $0000
  .addr $0000
  .addr $0000
  .addr $0000
  .addr $0000
  .addr $0000
  .addr @Inventory
  .addr @Scrolls
  .addr $0000

@Inventory:
  jsr EquipSelectedInventoryItem                  ; attempt to equip item
  bcc @Done                                       ; exit if selection failed
  lda #SFX_Equip                                  ; otherwise play sound
  sta PendingSFX                                  ;
  jsr UpdateInventorySprites                      ; and redraw
  jmp PauseMenu_DrawInventory                     ;

@Scrolls:
  lda PlayerYPx                                   ; find selected scroll
  lsr a                                           ;
  lsr a                                           ;
  lsr a                                           ;
  lsr a                                           ;
  sec                                             ;
  sbc #$6                                         ;
  bcc @Done                                       ;
  and #%11                                        ;
  tax                                             ;
  lda @ScrollTimers,x                             ; get time to use based on selected scroll
: sta PlayerSpeedBoostTimer1,x                    ; and update each scroll as needed
  dex                                             ;
  bpl :-                                          ;
  lda #SFX_Equip                                  ; then play sound and redraw
  sta PendingSFX                                  ;
  jsr UpdateInventorySprites                      ;
  jmp PauseMenu_DrawScrolls                       ;
@ScrollTimers:
  .byte 30, 30, 30, 60
@Done:
  clc
  rts


ModifySelectedItem:
  tay                                             ; store d-pad inputs
  jsr GetSelectedMenuType                         ; get type at position
  beq @Skip                                       ; if none, do nothing
  asl a                                           ; otherwise get offset into table
  tax                                             ;
  lda @Ops,x                                      ;
  sta $1                                          ;
  lda @Ops+1,x                                    ;
  beq @Skip                                       ; if the address is $0000, do nothing
  sta $2                                          ;
  clc                                             ;
  lda $0                                          ;
  jmp ($1)                                        ; otherwise jump to handler
@Skip:
  rts
@Ops:
  .addr $0000
  .addr @UpdateHP
  .addr @UpdateMP
  .addr @UpdateKeys
  .addr @UpdateGold
  .addr @UpdateSelectedInv
  .addr @UpdateInventory
  .addr @UpdateScrolls
  .addr @UpdateRNG
  .addr $0000

@UpdateRNG:
  lda #SFX_CrossPickup                            ; play sound
  sta PendingSFX                                  ;
  lda PlayerXTile                                 ; get selected rng value from position
  lsr a                                           ;
  sec                                             ;
  sbc #$5                                         ;
  and #%11                                        ;
  tax                                             ;
  clc                                             ;
  lda RNGValue,x                                  ; and adjust based on d-pad inputs
  adc @ModValue16,y                               ;
  sta RNGValue,x                                  ;
  jmp PauseMenu_DrawRNG                           ; redraw

@UpdateScrolls:
  lda #SFX_Equip                                  ; play sound
  sta PendingSFX                                  ;
  lda PlayerYPx                                   ; find selected scroll
  lsr a                                           ;
  lsr a                                           ;
  lsr a                                           ;
  lsr a                                           ;
  sec                                             ;
  sbc #$6                                         ;
  bcc :+                                          ;
  and #%11                                        ;
  tax                                             ;
  clc                                             ;
  lda PlayerSpeedBoostTimer1,x                    ; adjust scroll timer
  adc @ModValue,y                                 ;
  sta PlayerSpeedBoostTimer1,x                    ;
  jmp PauseMenu_DrawScrolls                       ; redraw
: rts

@UpdateInventory:
  lda #SFX_Equip                                  ; play sound
  sta PendingSFX                                  ;
  jsr GetSelectedItemOffset                       ; get selected inventory item
  clc                                             ;
  lda @ModValue,y                                 ; adjust based on d-pad
  adc PlayerInventory,x                           ;
  sta PlayerInventory,x                           ;
  jmp PauseMenu_DrawInventory                     ; redraw

@UpdateHP:
  lda #SFX_HealthPickup                           ; play sound
  sta PendingSFX                                  ;
  lda @ModValue,y                                 ; adjust hp
  adc PlayerHP                                    ;
  sta PlayerHP                                    ;
  jsr UpdateHPDisplay                             ; redraw
  jmp WaitFrame                                   ;

@UpdateGold:
  lda #SFX_GoldPickup                             ; play sound
  sta PendingSFX                                  ;
  lda @ModValue,y                                 ; adjust gold
  adc PlayerGold                                  ;
  sta PlayerGold                                  ;
  jsr UpdateGoldDisplay                           ; redraw
  jmp WaitFrame                                   ;

@UpdateMP:
  lda #SFX_ManaPickup                             ; play sound
  sta PendingSFX                                  ;
  lda @ModValue,y                                 ; adjust mp
  adc PlayerMP                                    ;
  sta PlayerMP                                    ;
  jsr UpdateMPDisplay                             ; redraw
  jmp WaitFrame                                   ;

@UpdateKeys:
  lda #SFX_KeyPickup                              ; play sound
  sta PendingSFX                                  ;
  lda @ModValue,y                                 ; adjust keys
  adc PlayerKeys                                  ;
  sta PlayerKeys                                  ;
  jsr UpdateKeysDisplay                           ; redraw
  jmp WaitFrame                                   ;

@UpdateSelectedInv:
  lda @ModValue16,y                               ; change selected item slot based on d-pad
  adc PlayerSelectedItemSlot                      ;
  and #%11                                        ;
  sta PlayerSelectedItemSlot                      ;
  jsr UpdateInventorySprites                      ; redraw
  jmp WaitFrame                                   ;

@ModValue:
  .byte $00      ; -
  .byte $01      ; R
  .byte $FF      ; L
  .byte $00      ; R+L
  .byte $100-10  ; D
  .byte $01      ; D+R
  .byte $FF      ; D+L
  .byte $00      ; D+R+L
  .byte  10      ; U
  .byte $01      ; U+R
  .byte $FF      ; U+L

@ModValue16:
  .byte $00      ; -
  .byte $01      ; R
  .byte $FF      ; L
  .byte $00      ; R+L
  .byte $100-$10 ; D
  .byte $01      ; D+R
  .byte $FF      ; D+L
  .byte $00      ; D+R+L
  .byte $10      ; U
  .byte $01      ; U+R
  .byte $FF      ; U+L

PauseMenu_DrawScrolls:
  ldx #0                                        ; clear counter value
  stx $8                                        ;
  lda #<$2184                                   ; set starting location for draw
  sta PPUUpdateAddrLo                           ;
  lda #>$2184                                   ;
  sta PPUUpdateAddrHi                           ;
: clc                                           ; adjust drawing location by 2 rows
  lda PPUUpdateAddrLo                           ;
  adc #$40                                      ;
  sta PPUUpdateAddrLo                           ;
  lda PPUUpdateAddrHi                           ;
  adc #0                                        ;
  sta PPUUpdateAddrHi                           ;
  lda PlayerSpeedBoostTimer1,x                  ; get scroll speed for slot
  jsr WriteNumberToPPUUpdateData                ; and prepare to draw the number in BCD
  lda #PPUOps_WriteBuffer                       ;
  jsr RunPPUOp                                  ; draw!
  ldx $8                                        ; increment temp value
  inx                                           ;
  stx $8                                        ;
  cpx #4                                        ; loop until each scroll has drawn
  bne :-                                        ;
  rts                                           ; done

PauseMenu_DrawRNG:
  ldx #0                                        ; clear counter value
  stx $8                                        ;
  lda #<$21B2                                   ; set starting location for draw
  sta PPUUpdateAddrLo                           ;
  lda #>$21B2                                   ;
  sta PPUUpdateAddrHi                           ;
: clc                                           ; adjust drawing location by 4 columns
  lda PPUUpdateAddrLo                           ;
  adc #$04                                      ;
  sta PPUUpdateAddrLo                           ;
  lda PPUUpdateAddrHi                           ;
  adc #0                                        ;
  sta PPUUpdateAddrHi                           ;
  lda RNGValue,x                                ; get rng value for slot
  jsr WriteHexToPPUUpdateData                   ; and prepare to draw the number in hex
  lda #PPUOps_WriteBuffer                       ;
  jsr RunPPUOp                                  ; draw!
  ldx $8                                        ;
  inx                                           ;
  stx $8                                        ;
  cpx #3                                        ; loop until each rng value has drawn
  bne :-                                        ;
  rts                                           ; done

WriteHexToPPUUpdateData:
  pha                                           ;
  lsr a                                         ; write high nybble
  lsr a                                         ;
  lsr a                                         ;
  lsr a                                         ;
  jsr ToHexNybble2                              ;
  sta PPUUpdateData+1                           ;
  pla                                           ;
  and #$0F                                      ; write low nybble
  jsr ToHexNybble2                              ;
  sta PPUUpdateData                             ;
  rts                                           ; done

EquipSelectedInventoryItem:
  @TmpSelectedItemType = $8
  ldx #0                                        ; set offset for first row
  lda PlayerYPx                                 ;
  cmp #$38                                      ; check if we should use the second row
  bcc :+                                        ;
  ldx #$8                                       ; if we're on the second row, offset X
: stx @TmpSelectedItemType                      ; store row value
  lda PlayerXTile                               ; then get exact slot based on player x position
  and #$0F
  lsr a                                         ;
  ora @TmpSelectedItemType                      ; and add back the row bit
  tax                                           ; use that as the offset into the inventory table
  lda PlayerInventory,x                         ; check how many of this item the player has
  beq @CannotEquip                              ; if we have none, we cannot equip the item
  txa                                           ; otherwise store the slot on the stack
  pha                                           ;
  jsr CanPlayerEquipItem                        ; check if the player can equip the item
  pla                                           ; restore slot index
  tax                                           ;
  bcs @Decrement                                ; if we can equip the item, remove it from the inventory
@CannotEquip:
  lda #$6                                       ; play bad sound
  sta PendingSFX                                ;
  clc                                           ;
  rts                                           ;
@Decrement:
  dec PlayerInventory,x                         ; remove 1 copy of the item
  stx @TmpSelectedItemType                      ; store current item type
  ldx PlayerActiveItems                         ; check if the player has any items equipped
  bmi :+                                        ;
  inc PlayerInventory,x                         ; if so, we need to increment the item that will be shifted back into inventory
: lda PlayerActiveItems+1                       ; shift all the items up one slot
  sta PlayerActiveItems                         ;
  lda PlayerActiveItems+2                       ;
  sta PlayerActiveItems+1                       ;
  lda @TmpSelectedItemType                      ; then add our new item to the list!
  sta PlayerActiveItems+2                       ;
  sec                                           ;
  rts                                           ;

PracPauseMap:
;       0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
.byte $01,$01,$01,$02,$02,$02,$03,$03,$03,$04,$04,$04,$05,$05,$05,$05 ; $00
.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06 ; $10
.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06 ; $20
.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06 ; $30
.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06 ; $30
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; $90
.byte $07,$07,$07,$00,$00,$00,$00,$00,$08,$08,$08,$08,$08,$08,$08,$08 ; $50
.byte $07,$07,$07,$00,$00,$00,$00,$00,$08,$08,$08,$08,$08,$08,$08,$08 ; $60
.byte $07,$07,$07,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; $70
.byte $07,$07,$07,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; $80
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; $A0
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; $B0

