

DragonRoutine1:
LDA #SFX_Warp
STA PendingSFX
LDA #$00
STA InvincibilityFramesTimer
JSR UpdatePlayerSprites
LDX #$02
jsl LightningFlashScreen
JSR DisableAllEntities
JSR UpdateEntitySprites
LDX #$03
jsl LightningFlashScreen
JSR $A5B5
LDA #SFX_DragonStart
STA PendingSFX
LDA #$3C
STA FrameCountdownTimer
JSR WaitForCountdownTimer
LDA #$13
STA CurrentAreaY
LDA #$02
STA CurrentAreaX
jsl LoadNewAreaData
JSR L_14_1C38B
LDA #$EF
STA SprY
LDA #$22
STA PPUVScrollCopy
LDA #$00
STA CameraXPx
STA PlayerXPx
LDA #$10
STA CameraXTile
jsl DrawLeftAreaDataColumn
LDX #$04
jsl LightningFlashScreen
LDA #$00
STA CameraXTile
jsl L_14_1C76C
LDA #$3D
STA SelectedBank3
LDX $1E
BNE :+
LDX #$F0
: CPX #$C2
BEQ :+
DEX
STX $1E
TXA
AND #$08
LSR A
LSR A
LSR A
STA $1D
LDA #PPUOps_Default
JSR RunPPUOp
JMP $A378
: LDX #$02
jsl LightningFlashScreen
jsl UpdateCameraPPUScroll
LDA #$00
STA $040C
STA $040D
STA $0406
STA $E9
STA CameraXPx
STA CameraXTile
LDA #$64
STA $0405
LDA #$08
STA $3E
LDA PlayerXTile
ASL A
ASL A
ASL A
ASL A
ORA PlayerXPx
STA PlayerXPx
JSR $AD7A
LDA #$EF
STA PlayerSpr0Y
STA PlayerSpr1Y
JSR $A7D2
JSR $A7F0
RTS

DragonRoutine5:
.byte $A9,$00,$85,$E5,$A9,$04,$85,$E6             ;  1A3E3 A3E3 ........ ???????? 
.byte $20,$8F,$E9,$A5,$F2,$D0,$03,$4C             ;  1A3EB A3EB ........  ??????L 
.byte $FF,$A7,$24,$26,$50,$43,$A6,$3E             ;  1A3F3 A3F3 ........ ??$&PC?> 
.byte $E8,$E8,$8A,$29,$06,$F0,$3A,$0A             ;  1A3FB A3FB ........ ???)??:? 
.byte $0A,$0A,$AA,$BD,$01,$04,$F0,$31             ;  1A403 A403 ........ ???????1 
.byte $A9,$00,$9D,$01,$04,$A5,$1C,$18             ;  1A40B A40B ........ ???????? 
.byte $7D,$0C,$04,$C9,$B0,$90,$1D,$C9             ;  1A413 A413 ........ }??????? 
.byte $D0,$B0,$19,$A5,$F2,$38,$E9,$02             ;  1A41B A41B ........ ?????8?? 
.byte $B0,$02,$A9,$00,$85,$F2,$20,$69             ;  1A423 A423 ........ ?????? i 
.byte $CB,$A9,$20,$85,$8F,$A9,$01,$85             ;  1A42B A42B ........ ?? ????? 
.byte $90,$4C,$3C,$A4,$A9,$01,$8D,$8F             ;  1A433 A433 ........ ?L<????? 
.byte $00,$A5,$FA,$F0,$03,$4C,$6D,$A5             ;  1A43B A43B ........ ?????Lm? 
.byte $A6,$F3,$F0,$18,$CA,$F0,$12,$CA             ;  1A443 A443 ........ ???????? 
.byte $F0,$0C,$CA,$F0,$06,$CA,$D0,$0C             ;  1A44B A44B ........ ???????? 
.byte $4C,$49,$A5,$4C,$F0,$A4,$4C,$CF             ;  1A453 A453 ........ LI?L??L? 
.byte $A4,$4C,$A6,$A4,$4C,$62,$A4,$A5             ;  1A45B A45B ........ ?L??Lb?? 
.byte $1C,$18,$65,$43,$B0,$23,$C9,$C0             ;  1A463 A463 ........ ??eC?#?? 
.byte $B0,$1F,$A6,$1C,$E0,$40,$B0,$19             ;  1A46B A46B ........ ?????@?? 
.byte $C9,$A0,$B0,$04,$C9,$80,$B0,$1C             ;  1A473 A473 ........ ???????? 
.byte $A5,$1E,$C9,$C3,$B0,$0B,$A9,$01             ;  1A47B A47B ........ ???????? 
.byte $85,$F3,$A9,$04,$85,$E9,$4C,$A6             ;  1A483 A483 ........ ??????L? 
.byte $A4,$A9,$03,$85,$F3,$A9,$02,$85             ;  1A48B A48B ........ ???????? 
.byte $E9,$4C,$F0,$A4,$A9,$02,$85,$F3             ;  1A493 A493 ........ ?L?????? 
.byte $A9,$08,$85,$E9,$A9,$B3,$85,$7A             ;  1A49B A49B ........ ???????z 
.byte $4C,$6D,$A5,$C6,$E9,$F0,$1E,$A5             ;  1A4A3 A4A3 ........ Lm?????? 
.byte $E9,$0A,$29,$01,$18,$69,$A0,$69             ;  1A4AB A4AB ........ ??)??i?i 
.byte $10,$85,$7A,$A5,$1C,$18,$69,$04             ;  1A4B3 A4B3 ........ ??z???i? 
.byte $85,$1C,$C9,$40,$B0,$07,$A9,$C2             ;  1A4BB A4BB ........ ???@???? 
.byte $85,$1E,$4C,$6D,$A5,$A9,$00,$85             ;  1A4C3 A4C3 ........ ??Lm???? 
.byte $F3,$4C,$6D,$A5,$C6,$E9,$F0,$12             ;  1A4CB A4CB ........ ?Lm????? 
.byte $A9,$B4,$85,$7A,$A5,$1E,$C9,$C3             ;  1A4D3 A4D3 ........ ???z???? 
.byte $90,$05,$38,$E9,$04,$85,$1E,$4C             ;  1A4DB A4DB ........ ??8????L 
.byte $6D,$A5,$A9,$B3,$85,$7A,$A9,$00             ;  1A4E3 A4E3 ........ m????z?? 
.byte $85,$F3,$4C,$6D,$A5,$C6,$E9,$F0             ;  1A4EB A4EB ........ ??Lm???? 
.byte $3D,$A9,$B2,$85,$7A,$A5,$1C,$F0             ;  1A4F3 A4F3 ........ =???z??? 
.byte $0D,$38,$E9,$04,$B0,$02,$A9,$00             ;  1A4FB A4FB ........ ?8?????? 
.byte $85,$1C,$C9,$11,$B0,$0E,$A5,$1E             ;  1A503 A503 ........ ???????? 
.byte $C9,$C3,$90,$1F,$38,$E9,$04,$85             ;  1A50B A50B ........ ????8??? 
.byte $1E,$4C,$2E,$A5,$A5,$1E,$C9,$D2             ;  1A513 A513 ........ ?L.????? 
.byte $90,$0C,$A5,$1C,$F0,$0D,$38,$E9             ;  1A51B A51B ........ ??????8? 
.byte $04,$85,$1C,$4C,$2E,$A5,$18,$69             ;  1A523 A523 ........ ???L.??i 
.byte $04,$85,$1E,$4C,$6D,$A5,$A5,$1C             ;  1A52B A52B ........ ???Lm??? 
.byte $F0,$07,$A9,$00,$85,$F3,$4C,$6D             ;  1A533 A533 ........ ??????Lm 
.byte $A5,$A9,$B0,$85,$7A,$E6,$F3,$A9             ;  1A53B A53B ........ ????z??? 
.byte $04,$85,$E9,$4C,$6D,$A5,$C6,$E9             ;  1A543 A543 ........ ???Lm??? 
.byte $F0,$15,$A5,$E9,$C9,$04,$D0,$04             ;  1A54B A54B ........ ???????? 
.byte $A9,$20,$85,$8F,$A9,$B5,$85,$7A             ;  1A553 A553 ........ ? ?????z 
.byte $A9,$C2,$85,$1E,$4C,$6D,$A5,$A9             ;  1A55B A55B ........ ????Lm?? 
.byte $B3,$85,$7A,$A9,$00,$85,$F3,$4C             ;  1A563 A563 ........ ??z????L 
.byte $6D,$A5,$20,$74,$A5,$20,$9A,$E9             ;  1A56B A56B ........ m? t? ?? 
.byte $60,$A5,$FA,$D0,$25,$A9,$0E,$85             ;  1A573 A573 ........ `???%??? 
.byte $16,$A9,$20,$85,$17,$A5,$1D,$49             ;  1A57B A57B ........ ?? ????I 
.byte $01,$0A,$0A,$05,$17,$85,$17,$A5             ;  1A583 A583 ........ ???????? 
.byte $1D,$49,$01,$0A,$0A,$0A,$0A,$18             ;  1A58B A58B ........ ?I?????? 
.byte $69,$07,$05,$7C,$85,$F9,$A9,$09             ;  1A593 A593 ........ i??|???? 
.byte $85,$FA,$A5,$F9,$85,$0C,$20,$33             ;  1A59B A59B ........ ?????? 3 
.byte $C8,$E6,$16,$E6,$16,$E6,$F9,$C6             ;  1A5A3 A5A3 ........ ???????? 
.byte $FA,$D0,$06,$A5,$1D,$49,$01,$85             ;  1A5AB A5AB ........ ?????I?? 
.byte $1D,$60,$A0,$04,$98,$48,$A9,$05             ;  1A5B3 A5B3 ........ ?`???H?? 
.byte $85,$36,$A2,$0C,$BD,$80,$01,$29             ;  1A5BB A5BB ........ ?6?????) 
.byte $0F,$85,$08,$BD,$80,$01,$29,$F0             ;  1A5C3 A5C3 ........ ??????)? 
.byte $38,$E9,$10,$B0,$05,$A9,$0F,$4C             ;  1A5CB A5CB ........ 8??????L 
.byte $D7,$A5,$05,$08,$9D,$80,$01,$CA             ;  1A5D3 A5D3 ........ ???????? 
.byte $10,$E2,$20,$35,$C1,$68,$A8,$88             ;  1A5DB A5DB ........ ?? 5?h?? 
.byte $D0,$D2,$60

DragonRoutine3:
.byte $A9,$01,$85,$E3,$A9             ;  1A5E3 A5E3 ........ ??`????? 
.byte $10,$85,$E5,$A9,$04,$85,$E6,$A0             ;  1A5EB A5EB ........ ???????? 
.byte $01,$B1,$E5,$D0,$0E,$24,$20,$50             ;  1A5F3 A5F3 ........ ?????$ P 
.byte $0D,$24,$FD,$70,$09,$20,$22,$A6             ;  1A5FB A5FB ........ ?$?p? "? 
.byte $4C,$09,$A6,$20,$57,$A6,$E6,$E3             ;  1A603 A603 ........ L?? W??? 
.byte $18,$A9,$10,$65,$E5,$85,$E5,$A9             ;  1A60B A60B ........ ???e???? 
.byte $00,$65,$E6,$85,$E6,$A5,$E3,$C9             ;  1A613 A613 ........ ?e?????? 
.byte $04,$90,$D4,$20,$E0,$A6,$60,$20             ;  1A61B A61B ........ ??? ??`  
.byte $8F,$E9,$A5,$20,$29,$40,$05,$FD             ;  1A623 A623 ........ ??? )@?? 
.byte $85,$FD,$A5,$FD,$A0,$02,$20,$B1             ;  1A62B A62B ........ ?????? ? 
.byte $A7,$20,$83,$A6,$20,$B1,$A6,$B0             ;  1A633 A633 ........ ? ?? ??? 
.byte $3C,$A5,$0E,$85,$F9,$A5,$0A,$85             ;  1A63B A63B ........ <??????? 
.byte $FB,$A9,$18,$85,$EE,$A9,$00,$85             ;  1A643 A643 ........ ???????? 
.byte $EF,$A9,$21,$85,$ED,$A9,$19,$85             ;  1A64B A64B ........ ??!????? 
.byte $8F,$4C,$78,$A6,$20,$8F,$E9,$C6             ;  1A653 A653 ........ ?Lx? ??? 
.byte $EE,$F0,$1A,$20,$C5,$A6,$20,$B1             ;  1A65B A65B ........ ??? ?? ? 
.byte $A6,$B0,$03,$4C,$70,$A6,$A9,$00             ;  1A663 A663 ........ ???Lp??? 
.byte $85,$EE,$4C,$78,$A6,$A5,$0E,$85             ;  1A66B A66B ........ ??Lx???? 
.byte $F9,$A5,$0A,$85,$FB,$A5,$EE,$F0             ;  1A673 A673 ........ ???????? 
.byte $03,$20

.byte $A2,$A6,$20,$9A,$E9,$60             ;  1A67B A67B ........ ? ?? ??` 
.byte $A5,$43,$85,$0E,$A5,$45,$85,$0A             ;  1A683 A683 ........ ?C???E?? 
.byte $A5,$F7,$F0,$07,$0A,$0A,$18,$65             ;  1A68B A68B ........ ???????e 
.byte $0A,$85,$0A,$A5,$F5,$F0,$07,$0A             ;  1A693 A693 ........ ???????? 
.byte $0A,$18,$65,$0E,$85,$0E,$60,$A5             ;  1A69B A69B ........ ??e???`? 
.byte $EE,$29,$0C,$85,$08,$A5,$ED,$29             ;  1A6A3 A6A3 ........ ?)?????) 
.byte $F3,$05,$08,$85,$ED,$60,$A5,$0A             ;  1A6AB A6AB ........ ?????`?? 
.byte $C9,$A1,$B0,$0A,$A5,$0E,$C9,$F1             ;  1A6B3 A6B3 ........ ???????? 
.byte $90,$06,$A5,$0E,$F0,$02,$38,$60             ;  1A6BB A6BB ........ ??????8` 
.byte $18,$60,$A5,$F9,$85,$0E,$A5,$FB             ;  1A6C3 A6C3 ........ ?`?????? 
.byte $85,$0A,$A5,$F7,$F0,$05,$18,$65             ;  1A6CB A6CB ........ ???????e 
.byte $0A,$85,$0A,$A5,$F5,$F0,$05,$18             ;  1A6D3 A6D3 ........ ???????? 
.byte $65,$0E,$85,$0E,$60,$A9,$88,$85             ;  1A6DB A6DB ........ e???`??? 
.byte $0F,$A9,$10,$85,$0E,$A9,$03,$48             ;  1A6E3 A6E3 ........ ???????H 
.byte $20,$03,$A7,$A5,$0F,$18,$69,$08             ;  1A6EB A6EB ........  ?????i? 
.byte $85,$0F,$A5,$0E,$18,$69,$10,$85             ;  1A6F3 A6F3 ........ ?????i?? 
.byte $0E,$68,$38,$E9,$01,$D0,$E8,$60             ;  1A6FB A6FB ........ ?h8????` 
.byte $A6,$0F,$A4,$0E,$B9,$01,$04,$F0             ;  1A703 A703 ........ ???????? 
.byte $48,$B9,$0E,$04,$C9,$BF,$B0,$41             ;  1A70B A70B ........ H??????A 
.byte $B9,$02,$04,$9D,$02,$02,$9D,$06             ;  1A713 A713 ........ ???????? 
.byte $02,$29,$40,$D0,$0F,$B9,$00,$04             ;  1A71B A71B ........ ?)@????? 
.byte $9D,$01,$02,$18,$69,$02,$9D,$05             ;  1A723 A723 ........ ????i??? 
.byte $02,$4C,$3B,$A7,$B9,$00,$04,$9D             ;  1A72B A72B ........ ?L;????? 
.byte $05,$02,$18,$69,$02,$9D,$01,$02             ;  1A733 A733 ........ ???i???? 
.byte $B9,$0C,$04,$9D,$03,$02,$18,$69             ;  1A73B A73B ........ ???????i 
.byte $08,$9D,$07,$02,$B9,$0E,$04,$18             ;  1A743 A743 ........ ???????? 
.byte $69,$2B,$9D,$00,$02,$9D,$04,$02             ;  1A74B A74B ........ i+?????? 
.byte $60,$A9,$EF,$9D,$00,$02,$9D,$04             ;  1A753 A753 ........ `??????? 
.byte $02,$60

DragonRoutine4:
.byte $C6,$3E,$10,$04,$A9,$07             ;  1A75B A75B ........ ?`?>???? 
.byte $85,$3E,$A5,$3E,$29,$06,$F0,$23             ;  1A763 A763 ........ ?>?>)??# 
.byte $A5,$3E,$0A,$0A,$AA,$BD,$80,$02             ;  1A76B A76B ........ ?>?????? 
.byte $8D,$00,$02,$BD,$81,$02,$8D,$01             ;  1A773 A773 ........ ???????? 
.byte $02,$BD,$82,$02,$8D,$02,$02,$BD             ;  1A77B A77B ........ ???????? 
.byte $83,$02,$8D,$03,$02,$A9,$EF,$9D             ;  1A783 A783 ........ ???????? 
.byte $80,$02,$60,$A5,$3E,$0A,$0A,$AA             ;  1A78B A78B ........ ??`?>??? 
.byte $BD,$10,$02,$8D,$00,$02,$BD,$11             ;  1A793 A793 ........ ???????? 
.byte $02,$8D,$01,$02,$BD,$12,$02,$8D             ;  1A79B A79B ........ ???????? 
.byte $02,$02,$BD,$13,$02,$8D,$03,$02             ;  1A7A3 A7A3 ........ ???????? 
.byte $A9,$EF,$9D,$10,$02,$60,$84,$09             ;  1A7AB A7AB ........ ?????`?? 
.byte $29,$0F,$0A,$AA,$A9,$00,$18,$7D             ;  1A7B3 A7B3 ........ )??????} 
.byte $8B,$FE,$88,$D0,$F9,$8D,$F5,$00             ;  1A7BB A7BB ........ ???????? 
.byte $A4,$09,$A9,$00,$18,$7D,$8C,$FE             ;  1A7C3 A7C3 ........ ?????}?? 
.byte $88,$D0,$F9,$8D,$F7,$00,$60,$A2             ;  1A7CB A7CB ........ ??????`? 
.byte $3F,$BD,$FC,$AA,$9D,$40,$02,$CA             ;  1A7D3 A7D3 ........ ?????@?? 
.byte $10,$F7,$20,$69,$CB,$60,$A2,$3F             ;  1A7DB A7DB ........ ?? i?`?? 
.byte $BD,$3C,$AB,$9D,$40,$02,$CA,$10             ;  1A7E3 A7E3 ........ ?<??@??? 
.byte $F7,$20,$53,$CB,$60,$A2,$3F,$BD             ;  1A7EB A7EB ........ ? S?`??? 
.byte $7C,$AB,$9D,$C0,$02,$CA,$10,$F7             ;  1A7F3 A7F3 ........ |??????? 
.byte $20,$7F,$CB,$60,$20,$69,$CB,$A9             ;  1A7FB A7FB ........  ??` i?? 
.byte $00,$8D,$11,$04,$8D,$21,$04,$8D             ;  1A803 A803 ........ ?????!?? 
.byte $31,$04,$85,$FA,$85,$85,$85,$88             ;  1A80B A80B ........ 1??????? 
.byte $20,$7A,$AD,$20,$E0,$A6,$A9,$EF             ;  1A813 A813 ........  z? ???? 
.byte $8D,$00,$02,$A5,$45,$C9,$A0,$B0             ;  1A81B A81B ........ ????E??? 
.byte $10,$E6,$45,$20,$7A,$AD,$A9,$01             ;  1A823 A823 ........ ??E z??? 
.byte $85,$36,$A5,$36,$D0,$FC,$4C,$1E             ;  1A82B A82B ........ ?6?6??L? 
.byte $A8,$A9,$00,$85,$4E,$85,$4F,$20             ;  1A833 A833 ........ ????N?O  
.byte $E0,$AC,$20,$7A,$AD,$A9,$20,$85             ;  1A83B A83B ........ ?? z?? ? 
.byte $7C,$A9,$01,$85,$1D,$A9,$20,$85             ;  1A843 A843 ........ |????? ? 
.byte $8F,$A9,$80,$85,$90,$A9,$B6,$85             ;  1A84B A84B ........ ???????? 
.byte $7A,$20,$74,$A5,$A5,$FA,$D0,$F9             ;  1A853 A853 ........ z t????? 
.byte $20,$74,$A5,$A5,$FA,$D0,$F9,$A9             ;  1A85B A85B ........  t?????? 
.byte $20,$85,$8F,$A9,$80,$85,$90,$A9             ;  1A863 A863 ........  ??????? 
.byte $B7,$85,$7A,$20,$74,$A5,$A5,$FA             ;  1A86B A86B ........ ??z t??? 
.byte $D0,$F9,$20,$74,$A5,$A5,$FA,$D0             ;  1A873 A873 ........ ?? t???? 
.byte $F9,$A9,$00,$85,$10,$A5,$84,$29             ;  1A87B A87B ........ ???????) 
.byte $07,$D0,$0E,$A5,$1D,$49,$01,$85             ;  1A883 A883 ........ ?????I?? 
.byte $1D,$A9,$20,$85,$8F,$A9,$80,$85             ;  1A88B A88B ........ ?? ????? 
.byte $90,$A9,$FF,$20,$8F,$CC,$24,$26             ;  1A893 A893 ........ ??? ??$& 
.byte $50,$08,$A9,$05,$20,$2F,$AE,$20             ;  1A89B A89B ........ P??? /?  
.byte $7F,$CB,$A5,$3E,$D0,$04,$A9,$02             ;  1A8A3 A8A3 ........ ???>???? 
.byte $85,$3E,$20,$7A,$AD,$20,$5D,$A7             ;  1A8AB A8AB ........ ?> z? ]? 
.byte $C6,$10,$D0,$C9,$A9,$01,$85,$1D             ;  1A8B3 A8B3 ........ ???????? 
.byte $A9,$FF,$20,$8F,$CC,$A5,$58,$D0             ;  1A8BB A8BB ........ ?? ???X? 
.byte $01,$60,$A9,$EF,$8D,$00,$02,$A9             ;  1A8C3 A8C3 ........ ?`?????? 
.byte $18,$85,$8F,$A9,$FF,$85,$90,$A9             ;  1A8CB A8CB ........ ???????? 
.byte $01,$85,$08,$A5,$45,$38,$E5,$08             ;  1A8D3 A8D3 ........ ????E8?? 
.byte $85,$45,$69,$2B,$C9,$EF,$B0,$0D             ;  1A8DB A8DB ........ ?Ei+???? 
.byte $20,$7A,$AD,$E6,$08,$A9,$FF,$20             ;  1A8E3 A8E3 ........  z?????  
.byte $8F,$CC,$4C,$D6,$A8,$A9,$EF,$8D             ;  1A8EB A8EB ........ ??L????? 
.byte $10,$02,$8D,$14,$02,$A9,$00,$85             ;  1A8F3 A8F3 ........ ???????? 
.byte $3E,$A9,$80,$85,$3F,$20,$8A,$D0             ;  1A8FB A8FB ........ >???? ?? 
.byte $20,$9B,$B2,$20,$61,$C4,$20,$8B             ;  1A903 A903 ........  ?? a? ? 
.byte $C3,$20,$75,$C3,$A9,$10,$85,$48             ;  1A90B A90B ........ ? u????H 
.byte $A9,$03,$85,$47,$A9,$F2,$85,$0E             ;  1A913 A913 ........ ???G???? 
.byte $A9,$C8,$85,$0F,$20,$E4,$CC,$A9             ;  1A91B A91B ........ ???? ??? 
.byte $12,$85,$7C,$A9,$C0,$85,$45,$A9             ;  1A923 A923 ........ ??|???E? 
.byte $1A,$85,$44,$A9,$01,$85,$43,$85             ;  1A92B A92B ........ ??D???C? 
.byte $7B,$A9,$09,$85,$56,$A9,$35,$85             ;  1A933 A933 ........ {???V?5? 
.byte $2C,$A9,$34,$85,$2D,$A9,$36,$85             ;  1A93B A93B ........ ,?4?-?6? 
.byte $2E,$A9,$37,$85,$2F,$A9,$01,$8D             ;  1A943 A943 ........ .?7?/??? 
.byte $11,$04,$8D,$21,$04,$8D,$31,$04             ;  1A94B A94B ........ ???!??1? 
.byte $8D,$41,$04,$A9,$A0,$8D,$1E,$04             ;  1A953 A953 ........ ?A?????? 
.byte $8D,$2E,$04,$8D,$3E,$04,$A9,$70             ;  1A95B A95B ........ ?.??>??p 
.byte $8D,$4E,$04,$A9,$33,$8D,$4D,$04             ;  1A963 A963 ........ ?N??3?M? 
.byte $20,$AE,$AA,$18,$A9,$2D,$8D,$10             ;  1A96B A96B ........  ????-?? 
.byte $04,$69,$20,$8D,$20,$04,$69,$20             ;  1A973 A973 ........ ?i ? ?i  
.byte $8D,$30,$04,$A9,$81,$8D,$40,$04             ;  1A97B A97B ........ ?0????@? 
.byte $A9,$40,$8D,$12,$04,$8D,$22,$04             ;  1A983 A983 ........ ?@????"? 
.byte $8D,$32,$04,$8D,$42,$04,$20,$7A             ;  1A98B A98B ........ ?2??B? z 
.byte $C5,$A9,$CB,$85,$0E,$A9,$C5,$85             ;  1A993 A993 ........ ???????? 
.byte $0F,$20,$E4,$CC,$20,$B6,$CA,$20             ;  1A99B A99B ........ ? ?? ??  
.byte $CC,$CA,$20,$F8,$CA,$20,$E2,$CA             ;  1A9A3 A9A3 ........ ?? ?? ?? 
.byte $20,$C7,$C1,$20,$7C,$D0,$20,$D8             ;  1A9AB A9AB ........  ?? |? ? 
.byte $C1,$20,$34,$C2,$20,$B1,$C2,$A9             ;  1A9B3 A9B3 ........ ? 4? ??? 
.byte $07,$85,$40,$A9,$92,$85,$0E,$A9             ;  1A9BB A9BB ........ ??@????? 
.byte $C4,$85,$0F,$20,$E4,$CC,$A9,$05             ;  1A9C3 A9C3 ........ ??? ???? 
.byte $85,$8C,$20,$EE,$AA,$A5,$8C,$D0             ;  1A9CB A9CB ........ ?? ????? 
.byte $F9,$A5,$45,$C9,$A0,$F0,$25,$C6             ;  1A9D3 A9D3 ........ ??E???%? 
.byte $45,$20,$EE,$AA,$20,$EE,$AA,$A5             ;  1A9DB A9DB ........ E ?? ??? 
.byte $45,$C9,$A0,$F0,$17,$C6,$45,$A5             ;  1A9E3 A9E3 ........ E?????E? 
.byte $57,$49,$40,$85,$57,$20,$D8,$C1             ;  1A9EB A9EB ........ WI@?W ?? 
.byte $20,$EE,$AA,$20,$EE,$AA,$20,$35             ;  1A9F3 A9F3 ........  ?? ?? 5 
.byte $C1,$4C,$D4,$A9,$A9,$0D,$85,$56             ;  1A9FB A9FB ........ ?L?????V 
.byte $20,$D8,$C1,$A9,$03,$85,$8C,$20             ;  1AA03 AA03 ........  ??????  
.byte $EE,$AA,$A5,$8C,$D0,$F9,$A9,$01             ;  1AA0B AA0B ........ ???????? 
.byte $85,$36,$A5,$7C,$85,$7E,$A9,$01             ;  1AA13 AA13 ........ ?6?|?~?? 
.byte $85,$20,$A9,$2B,$85,$0E,$A9,$D4             ;  1AA1B AA1B ........ ? ?+???? 
.byte $85,$0F,$20,$E4,$CC,$A9,$5D,$85             ;  1AA23 AA23 ........ ?? ???]? 
.byte $0E,$A9,$C1,$85,$0F,$20,$E4,$CC             ;  1AA2B AA2B ........ ????? ?? 
.byte $20,$AE,$AA,$20,$D8,$C1,$20,$B1             ;  1AA33 AA33 ........  ?? ?? ? 
.byte $C2,$A5,$7E,$C5,$7C,$F0,$02,$E6             ;  1AA3B AA3B ........ ??~?|??? 
.byte $3D,$20,$35,$C1,$A5,$44,$C9,$37             ;  1AA43 AA43 ........ = 5??D?7 
.byte $D0,$C4,$A9,$19,$85,$56,$A9,$39             ;  1AA4B AA4B ........ ?????V?9 
.byte $8D,$10,$04,$A9,$59,$8D,$20,$04             ;  1AA53 AA53 ........ ????Y? ? 
.byte $A9,$79,$8D,$30,$04,$A9,$91,$8D             ;  1AA5B AA5B ........ ?y?0???? 
.byte $40,$04,$A9,$14,$85,$8C,$A5,$56             ;  1AA63 AA63 ........ @??????V 
.byte $49,$04,$85,$56,$AD,$10,$04,$49             ;  1AA6B AA6B ........ I??V???I 
.byte $04,$8D,$10,$04,$AD,$20,$04,$49             ;  1AA73 AA73 ........ ????? ?I 
.byte $04,$8D,$20,$04,$AD,$30,$04,$49             ;  1AA7B AA7B ........ ?? ??0?I 
.byte $04,$8D,$30,$04,$AD,$40,$04,$49             ;  1AA83 AA83 ........ ??0??@?I 
.byte $04,$8D,$40,$04,$20,$EE,$AA,$20             ;  1AA8B AA8B ........ ??@? ??  
.byte $EE,$AA,$20,$EE,$AA,$20,$EE,$AA             ;  1AA93 AA93 ........ ?? ?? ?? 
.byte $20,$EE,$AA,$20,$EE,$AA,$20,$EE             ;  1AA9B AA9B ........  ?? ?? ? 
.byte $AA,$20,$EE,$AA,$A5,$8C,$D0,$BE             ;  1AAA3 AAA3 ........ ? ?????? 
.byte $4C,$3D,$B1,$A5,$56,$29,$1F,$85             ;  1AAAB AAAB ........ L=??V)?? 
.byte $08,$AD,$10,$04,$29,$E0,$05,$08             ;  1AAB3 AAB3 ........ ????)??? 
.byte $8D,$10,$04,$AD,$20,$04,$29,$E0             ;  1AABB AABB ........ ???? ?)? 
.byte $05,$08,$8D,$20,$04,$AD,$30,$04             ;  1AAC3 AAC3 ........ ??? ??0? 
.byte $29,$E0,$05,$08,$8D,$30,$04,$A5             ;  1AACB AACB ........ )????0?? 
.byte $43,$8D,$1C,$04,$8D,$2C,$04,$8D             ;  1AAD3 AAD3 ........ C????,?? 
.byte $3C,$04,$A6,$44,$E8,$8E,$2D,$04             ;  1AADB AADB ........ <??D??-? 
.byte $CA,$CA,$CA,$8E,$3D,$04,$CA,$8E             ;  1AAE3 AAE3 ........ ????=??? 
.byte $1D,$04,$60,$20,$D8,$C1,$20,$B1             ;  1AAEB AAEB ........ ??` ?? ? 
.byte $C2,$A9,$01,$85,$36,$20,$35,$C1             ;  1AAF3 AAF3 ........ ????6 5? 
.byte $60,$58,$51,$03,$A0,$58,$53,$03             ;  1AAFB AAFB ........ `XQ??XS? 
.byte $A8,$58,$55,$03,$B0,$58,$57,$03             ;  1AB03 AB03 ........ ?XU??XW? 
.byte $B8,$58,$59,$03,$C0,$58,$5B,$03             ;  1AB0B AB0B ........ ?XY??X[? 
.byte $C8,$64,$61,$03,$A8,$64,$61,$03             ;  1AB13 AB13 ........ ?da??da? 
.byte $B2,$64,$61,$03,$BC,$64,$61,$03             ;  1AB1B AB1B ........ ?da??da? 
.byte $C6,$64,$61,$03,$D0,$74,$67,$03             ;  1AB23 AB23 ........ ?da??tg? 
.byte $A8,$74,$67,$03,$B2,$74,$67,$03             ;  1AB2B AB2B ........ ?tg??tg? 
.byte $BC,$74,$67,$03,$C6,$74,$67,$03             ;  1AB33 AB33 ........ ?tg??tg? 
.byte $D0,$38,$9D,$03,$C0,$38,$9F,$03             ;  1AB3B AB3B ........ ?8???8?? 
.byte $C8,$38,$B9,$03,$D0,$38,$BB,$03             ;  1AB43 AB43 ........ ?8???8?? 
.byte $D8,$38,$BD,$03,$E0,$38,$BF,$03             ;  1AB4B AB4B ........ ?8???8?? 
.byte $E8,$44,$A1,$03,$C8,$44,$A1,$03             ;  1AB53 AB53 ........ ?D???D?? 
.byte $D2,$44,$A1,$03,$DC,$44,$A1,$03             ;  1AB5B AB5B ........ ?D???D?? 
.byte $E6,$44,$A1,$03,$F0,$54,$A7,$03             ;  1AB63 AB63 ........ ?D???T?? 
.byte $C8,$54,$A7,$03,$D2,$54,$A7,$03             ;  1AB6B AB6B ........ ?T???T?? 
.byte $DC,$54,$A7,$03,$E6,$54,$A7,$03             ;  1AB73 AB73 ........ ?T???T?? 
.byte $F0,$30,$6D,$03,$28,$30,$6F,$03             ;  1AB7B AB7B ........ ?0m?(0o? 
.byte $30,$30,$71,$03,$38,$30,$73,$03             ;  1AB83 AB83 ........ 00q?80s? 
.byte $40,$30,$75,$03,$48,$30,$77,$03             ;  1AB8B AB8B ........ @0u?H0w? 
.byte $50,$3C,$61,$03,$20,$3C,$61,$03             ;  1AB93 AB93 ........ P<a? <a? 
.byte $2A,$3C,$61,$03,$34,$3C,$61,$03             ;  1AB9B AB9B ........ *<a?4<a? 
.byte $3E,$3C,$61,$03,$48,$4C,$67,$03             ;  1ABA3 ABA3 ........ ><a?HLg? 
.byte $20,$4C,$67,$03,$2A,$4C,$67,$03             ;  1ABAB ABAB ........  Lg?*Lg? 
.byte $34,$4C,$67,$03,$3E,$4C,$67,$03             ;  1ABB3 ABB3 ........ 4Lg?>Lg? 
.byte $48

DragonRoutine2:
.byte $A5,$20,$29,$10,$F0,$03,$4C             ;  1ABBB ABBB ........ H? )???L 
.byte $11,$AE,$24,$20,$70,$06,$A5,$FD             ;  1ABC3 ABC3 ........ ??$ p??? 
.byte $29,$0F,$85,$FD,$A5,$20,$29,$0F             ;  1ABCB ABCB ........ )???? )? 
.byte $F0,$0A,$85,$08,$A5,$FD,$29,$F0             ;  1ABD3 ABD3 ........ ??????)? 
.byte $05,$08,$85,$FD,$A5,$85,$D0,$30             ;  1ABDB ABDB ........ ???????0 
.byte $24,$26,$50,$43,$A6,$3E,$E8,$8A             ;  1ABE3 ABE3 ........ $&PC?>?? 
.byte $29,$06,$D0,$3B,$A5,$1C,$18,$7D             ;  1ABEB ABEB ........ )??;???} 
.byte $0C,$04,$C9,$B0,$A9,$0A,$90,$02             ;  1ABF3 ABF3 ........ ???????? 
.byte $A9,$05,$20,$2F,$AE,$A9,$0A,$85             ;  1ABFB ABFB ........ ?? /???? 
.byte $4F,$A9,$21,$85,$8F,$A9,$02,$85             ;  1AC03 AC03 ........ O?!????? 
.byte $90,$A9,$01,$85,$85,$20,$7F,$CB             ;  1AC0B AC0B ........ ????? ?? 
.byte $A5,$4F,$D0,$0B,$A5,$4E,$D0,$07             ;  1AC13 AC13 ........ ?O???N?? 
.byte $A9,$00,$85,$85,$4C,$2A,$AC,$A5             ;  1AC1B AC1B ........ ????L*?? 
.byte $20,$29,$F0,$09,$02,$85,$20,$20             ;  1AC23 AC23 ........  )????   
.byte $51,$AE,$A5,$4E,$D0,$21,$A5,$4F             ;  1AC2B AC2B ........ Q??N?!?O 
.byte $D0,$04,$A5,$20,$10,$08,$20,$6D             ;  1AC33 AC33 ........ ??? ?? m 
.byte $AC,$A9,$00,$4C,$45,$AC,$A9,$00             ;  1AC3B AC3B ........ ???LE??? 
.byte $85,$22,$85,$4F,$20,$C7,$AD,$90             ;  1AC43 AC43 ........ ?"?O ??? 
.byte $03,$4C,$AF,$AC,$4C,$A1,$AC,$4A             ;  1AC4B AC4B ........ ?L??L??J 
.byte $4A,$18,$69,$01,$85,$4B,$20,$C7             ;  1AC53 AC53 ........ J?i??K ? 
.byte $AD,$B0,$03,$4C,$A1,$AC,$A9,$00             ;  1AC5B AC5B ........ ???L???? 
.byte $85,$49,$20,$C7,$AD,$90,$37,$4C             ;  1AC63 AC63 ........ ?I ???7L 
.byte $AF,$AC,$A6,$4F,$D0,$0D,$A5,$22             ;  1AC6B AC6B ........ ???O???" 
.byte $F0,$01,$60,$A9,$1B,$85,$8F,$A5             ;  1AC73 AC73 ........ ??`????? 
.byte $5C,$85,$4F,$68,$68,$A9,$01,$85             ;  1AC7B AC7B ........ \?Ohh??? 
.byte $22,$C6,$4F,$8A,$4A,$4A,$49,$FF             ;  1AC83 AC83 ........ "?O?JJI? 
.byte $18,$69,$01,$85,$4B,$20,$C7,$AD             ;  1AC8B AC8B ........ ?i??K ?? 
.byte $90,$0C,$A9,$00,$85,$49,$20,$C7             ;  1AC93 AC93 ........ ?????I ? 
.byte $AD,$90,$03,$4C,$AF,$AC,$A5,$0E             ;  1AC9B AC9B ........ ???L???? 
.byte $85,$43,$A5,$0A,$85,$45,$20,$E4             ;  1ACA3 ACA3 ........ ?C???E ? 
.byte $AD,$4C,$BB,$AC,$A9,$00,$85,$4F             ;  1ACAB ACAB ........ ?L?????O 
.byte $85,$4E,$20,$E4,$AD,$4C,$BB,$AC             ;  1ACB3 ACB3 ........ ?N ??L?? 
.byte $20,$E0,$AC,$20,$3B,$AD,$20,$7A             ;  1ACBB ACBB ........  ?? ;? z 
.byte $AD,$60,$A5,$43,$85,$0E,$A5,$45             ;  1ACC3 ACC3 ........ ?`?C???E 
.byte $85,$0A,$A5,$4B,$F0,$05,$18,$65             ;  1ACCB ACCB ........ ???K???e 
.byte $0A,$85,$0A,$A5,$49,$F0,$05,$18             ;  1ACD3 ACD3 ........ ????I??? 
.byte $65,$0E,$85,$0E,$60,$A2,$09,$A5             ;  1ACDB ACDB ........ e???`??? 
.byte $20,$29,$BF,$C9,$80,$F0,$35,$A5             ;  1ACE3 ACE3 ........  )????5? 
.byte $4B,$F0,$18,$30,$0F,$A5,$4E,$D0             ;  1ACEB ACEB ........ K??0??N? 
.byte $2E,$A5,$20,$29,$04,$F0,$0C,$A2             ;  1ACF3 ACF3 ........ .? )???? 
.byte $0D,$4C,$1F,$AD,$A5,$4F,$F0,$1C             ;  1ACFB ACFB ........ ?L???O?? 
.byte $4C,$22,$AD,$A2,$01,$A0,$00,$A5             ;  1AD03 AD03 ........ L"?????? 
.byte $49,$30,$04,$F0,$11,$A0,$40,$86             ;  1AD0B AD0B ........ I0????@? 
.byte $08,$A5,$56,$29,$07,$05,$08,$85             ;  1AD13 AD13 ........ ??V)???? 
.byte $56,$84,$57,$60,$86,$56,$60,$A2             ;  1AD1B AD1B ........ V?W`?V`? 
.byte $39,$A0,$00,$A5,$49,$30,$04,$F0             ;  1AD23 AD23 ........ 9???I0?? 
.byte $F5,$A0,$40,$86,$08,$A5,$56,$29             ;  1AD2B AD2B ........ ??@???V) 
.byte $03,$05,$08,$85,$56,$84,$57,$60             ;  1AD33 AD33 ........ ????V?W` 

  lda PlayerSpriteTile              ; are we in a normal movement sprite?
  cmp #$20                          ;
  bcs @SpriteUpdated                ; if not - skip ahead
  lda PlayerSpriteTile              ; otherwise set attacking sprite when A button pressed
  bit JoypadInput                   ;
  bvs :+                            ;
  and #%11101111                    ;
  jmp :++                           ;
: ora #%00010000                    ;
: sta PlayerSpriteTile              ;
@SpriteUpdated:
  lda JoypadInput                   ; is the player attempting to move?
  and #CtlR|CtlL|CtlD|CtlU          ;
  beq @Exit                         ; if not - skip to end
  lda PlayerJumpProgress            ; is the player jumping or falling?
  ora PlayerFallHeight              ;
  bne @Exit                         ; if so - skip to end
  inc PlayerAnimationCycle          ; advance animation cycle
  lda PlayerAnimationCycle          ;
  and #%00000111                    ;
  bne @Exit                         ; only change tile every 16th frame
  lda PlayerSpriteTile              ; check sprite direction
  and #%00001000                    ;
  bne @InvertDirection              ; invert attribute as needed
  lda PlayerSpriteTile              ; cycle animation tile
  eor #%00000100                    ;
  sta PlayerSpriteTile              ;
  jmp @Exit                         ; bail
@InvertDirection:
  lda PlayerSpriteAttr              ; flip horizontal
  eor #%01000000                    ;
  sta PlayerSpriteAttr              ;
@Exit:
  rts                               ; done dealing with movement animation


AD7A:
  lda InvincibilityFramesTimer      ; check if player is in iframes
  beq @Update                       ; nope - skip ahead to draw the player
  lda IntervalTimer                 ; yep - player will flash at 30hz, are we on an odd frame?
  and #$1                           ;
  bne @Update                       ; yep - draw player!
  lda #$EF                          ; no - move player sprite off screen
  sta PlayerSpr0Y                   ;
  sta PlayerSpr1Y                   ;
  rts
@Update:
  lda PlayerYPx                                   ; shift player down to account for the title bar
  clc                                             ;
  adc #StatusBarHeight                             ;
  sta PlayerSpr0Y                                 ; and set as sprite Y
  sta PlayerSpr1Y                                 ;
  lda PlayerXPx                               ;
  sta PlayerSpr0X                                 ; position player X sprites at determined location
  clc                                             ;
  adc #$8                                         ;
  sta PlayerSpr1X                                 ;
  lda PlayerSpriteAttr                            ; set sprite attributes
  ora #%00100000                                  ; force to background
  sta PlayerSpr0Attr                              ;
  sta PlayerSpr1Attr                              ;
  bit PlayerSpriteAttr                            ; are we inverting sprite order?
  bvs @Inverted                                   ; if so - skip ahead
  ldx PlayerSpriteTile                            ; get tile number of player sprite
  stx PlayerSpr0Tile                              ; set first sprite
  inx                                             ; advance 2 tiles to get next side
  inx                                             ;
  stx PlayerSpr1Tile                              ; and set second sprite
  rts                                             ; done!
@Inverted:
  ldx PlayerSpriteTile                            ; get tile number of player sprite
  stx PlayerSpr1Tile                              ; set second sprite
  inx                                             ; advance 2 tiles to get next side
  inx                                             ;
  stx PlayerSpr0Tile                              ; and set first sprite
  rts                                             ; done!


ADC7:
  lda PlayerYPxSpeed                              ; store current y pixel speed on stack
  pha                                             ;
@Continue:
  jsr $ACC5                                       ;
  jsr $AE41                                       ;
  bcc @Done                                       ; 
  ldx PlayerYPxSpeed                              ; get current y speed
  beq @Landed                                     ; if player is landed, we're done
  bmi @Fall                                       ; 
  dex                                             ; decrement twice, so we end up at -1
  dex                                             ;
@Fall:
  inx                                             ; increment one, to get 1 or -1 as new speed
  stx PlayerYPxSpeed                              ; and set speed
  bne @Continue
@Landed:
  sec                                             ; mark ending
@Done:
  pla                                             ; and restore the original speed
  sta PlayerYPxSpeed                              ;
  rts                                             ; done!

ADE4:
  lda PlayerJumpProgress                          ; are we jumpin?
  beq :+                                          ; nope - skip ahead
  clc                                             ; otherwise exit immediately!
  rts                                             ;
: lda PlayerYPx                                   ; check if player is a bit too high
  cmp #$A0                                        ;
  bcs :+                                          ; if not - continue
  inc PlayerFallHeight                            ; otherwise we won't process the landing
  rts                                             ;
: lda PlayerFallHeight                            ; check if we've fallen past our jump ability
  cmp PlayerAttrJump                              ;
  bcc @Done                                       ; if not - 
  sec                                             ;
  sbc #7                                          ;
  cmp PlayerAttrJump                              ; are we a low quality jumper?
  bcc :+                                          ; if so - skip ahead
  lda PlayerAttrJump                              ; otherwise use our actual jump attribute
: sec                                             ; reduced by 1
  sbc #1                                          ;
  sta PlayerJumpProgress                          ; set as jump progress for a stun bounce (which won't happen in dragon encounter)
  lda #SFX_JumpLand                               ;
  sta a:PendingSFX
@Done:
  lda #0                                          ; clear fall height
  sta PlayerFallHeight                            ;
  rts                                             ; done!
  
  
AE11:
  lda #SFX_PauseMenu                              ;
  sta PendingSFX                                  ;
  inc R_008D                                      ;  1E013 E013 C E6 8D           F:024130
: jsr ReadJoypad                                  ;  1E039 E039 C 20 43 CC        F:024197
  bne :-
: jsr ReadJoypad
  and #CtlT
  beq :-
: jsr ReadJoypad
  bne :-
  lda #SFX_Unpause
  sta PendingSFX
  dec R_008D
  rts

; AE2F
DE_ApplyDamageToPlayer:
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
: plp                                             ;
  rts   

AE41:
  lda $0A
  cmp #$A1
  bcs @ExitSec
  lda $0E
  cmp #$F1
  bcc @ExitClc
@ExitSec:
  sec
  rts
@ExitClc:
  clc
  rts

AE51:
  lda JoypadInput
  and #CtlR|CtlL|CtlD|CtlU          ;
  asl a
  tax
  lda PlayerDirections,x
  sta a:PlayerMovingDirection
  lda PlayerDirections+1,x
  sta a:PlayerYPxSpeed
  rts
