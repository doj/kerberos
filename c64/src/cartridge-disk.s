;
; Startup code for Kerberos cartridge disk extension
;

.include "regs.inc"

.export		loadCallback
.export 	openCallback
.export 	closeCallback
.export 	chkinCallback
.export 	chkoutCallback
.export 	chrinCallback
.export 	chroutCallback
.export 	getinCallback
.export		driveNumber1
.export		driveNumber2

zpStart = 2
ptr1 = 2
ptr2 = 4
ptr3 = 6
ptr4 = 8
tmp1 = 10
tmp2 = 11
tmp3 = 12
tmp4 = 13
zpEnd = 13

KERNAL_OPEN = $F34A
KERNAL_CLOSE = $F291
KERNAL_CHKIN = $F20E
KERNAL_CHKOUT = $F250
KERNAL_CHRIN = $F157 
KERNAL_CHROUT = $F1CA
KERNAL_LOAD = $F49E 
KERNAL_SAVE = $F5DD  
KERNAL_GETIN = $F13E

REU_STATUS = $df00
REU_COMMAND = $df01
REU_C64BASE = $df02
REU_REUBASE = $df04
REU_TANSLEN = $df07
REU_IRQMASK = $df09
REU_CONTROL = $df0a

TRACKS = 35

BAM_TRACK = 18
BAM_SECTOR = 0

DIR_TRACK = 18
DIR_SECTOR = 0

T_DEL = 0
T_SEQ = 1
T_PRG = 2
T_USR = 3
T_REL = 4
T_CBM = 5
T_DIR = 6


.segment "TRAMPOLINE"
trampolineStart:

openCallback:	jsr enableRom
		jmp openImpl
openCallback2:	jsr disableRom
		jmp KERNAL_OPEN
openCallback3:	jsr disableRom
		JMP $F70A
openCallback4:	jsr disableRom
		JMP $F6FE
openCallback5:	jsr disableRom
		JMP $F6FB

closeCallback:	jsr enableRom
		jmp closeImpl
closeCallback2: jsr disableRom		
		jmp $f29b
closeCallback3: jsr disableRom
		jmp $f2f1

chkinCallback:	jsr enableRom
		jmp chkinImpl
chkinCallback2:	jsr disableRom
		JMP $F701	
chkinCallback3:	jsr disableRom
		jmp $F219	
chkinCallback4:	jsr disableRom
		jmp $f233

chkoutCallback:	jsr enableRom
		jmp chkoutImpl
chkoutCallback2: jsr disableRom
		JMP $F701	
chkoutCallback3: jsr disableRom
		jmp $F25B	
chkoutCallback4: jsr disableRom
		jmp $f275

chrinCallback:	jsr enableRom
		jmp chrinImpl
chrinCallback2:	jsr disableRom
		jmp KERNAL_CHRIN

chroutCallback:	jsr enableRom
		jmp chroutImpl
chroutCallback2: jsr disableRom
		jmp KERNAL_CHROUT

loadCallback:	jsr enableRom
		jmp loadImpl
loadCallback2:	jsr disableRom
		jmp KERNAL_LOAD

getinCallback:	jsr enableRom
		jmp getinImpl
getinCallback2:	jsr disableRom
		jmp KERNAL_GETIN

enableRom:	sta accuBackup
		php
		pla
		; clear carry bit
		and #$fe
		sta statusBackup
		sei
		; enable cartridge ROM at $8000
		lda #CART_CONTROL_GAME_HIGH | CART_CONTROL_EXROM_LOW | CART_CONTROL_LED1_ON | CART_CONTROL_LED2_ON
		sta CART_CONTROL
		lda #4
		sta FLASH_ADDRESS_EXTENSION
		lda #0
		sta ADDRESS_EXTENSION2
		lda accuBackup
		rts


disableRom:	; save accu
		sta accuBackup
		; add carry bit to status register backup
		php
		pla
		and #1
		ora statusBackup
		sta statusBackup
		; restore current slot settings
		lda #CART_CONTROL_GAME_HIGH | CART_CONTROL_EXROM_HIGH
		sta CART_CONTROL
		lda statusBackup
		pha
		plp
		lda accuBackup
		rts


; copy block to diskbuf (self modifying code, address set from cartridge-disk)
copyFlashDisk:	; select flash disk bank
		sta FLASH_ADDRESS_EXTENSION
		lda #0
		sta CART_CONFIG
		; copy flash disk data
		ldx #0
copyFlashDisk2:	lda $8000,x
		sta diskbuf,x
		dex
		bne copyFlashDisk2

		; select cartridge disk ROM
		lda #4
		sta FLASH_ADDRESS_EXTENSION
		lda #CART_CONFIG_RAM_AS_ROM_ON | CART_CONFIG_KERNAL_HACK_ON | CART_CONFIG_HIRAM_HACK_ON
		sta CART_CONFIG
		rts

readFilename:	jsr disableRom
		lda ($bb),y
		jmp enableRom



driveNumber1:	.res 1
driveNumber2:	.res 1
flashDiskOffset: .res 1

accuBackup:	.res 1
statusBackup:	.res 1

.segment        "CARTRIDGE_DISK"


;
; copy a block to RAM and return a pointer to it
;
; Input: A = sector, X = track
; Output: A/X = low/high address
; Used registers: A, X, Y
;
_get_ts_addr:
; get start address in A/X (low/high)
	jsr _get_block_num
	
	sta flashAdr
	stx flashAdr+1
	
	; add flash disk offset (first disk 0x1.0000, second disk 0x4.0000)
	lda flashDiskOffset
	clc
	adc flashAdr+1
	sta flashAdr+1

	; calculate flash bank: /32 = /8192 (32*256)	
	lda flashAdr
	sta flashAdrBank
	lda flashAdr+1
	sta flashAdrBank+1
	ldx #5
div32:	lsr flashAdrBank+1
	ror flashAdrBank
	dex
	bne div32

	; set RAM address
	lda flashAdr
	and #$1f
	clc
	adc #$80
	sta copyFlashDisk2+2
	
	; copy block to RAM
	lda flashAdrBank
	jsr copyFlashDisk

; return pointer to buffer
	lda #<diskbuf
	ldx #>diskbuf
	rts


; select flash disk depending on drive number in accu
; C flag is set on error
selectFlashDisk:
	cmp driveNumber1
	beq selectFlashDisk1
	cmp driveNumber2
	beq selectFlashDisk2
	sec
	rts
selectFlashDisk1:
	pha
	lda #1
	sta flashDiskOffset
	pla
	clc
	rts
selectFlashDisk2:
	pha
	lda #4
	sta flashDiskOffset
	pla
	clc
	rts

openImpl:
	lda $ba
	jsr selectFlashDisk
	bcc openImpl2
	jmp openCallback2
openImpl2:
; KERNAL function for opening the file, but no IEC communication
	LDX $B8
	BNE openImpl3
	JMP openCallback3
openImpl3:
	JSR $F30F
	BNE openImpl4
	JMP openCallback4
openImpl4:
	LDX $98
	CPX #$0A
	BCC openImpl5
	JMP openCallback5
openImpl5:
	INC $98
	LDA $B8
	STA $0259,X
	LDA $B9
	ORA #$60
	STA $B9
	STA $026D,X
	LDA $BA
	STA $0263,X

	; open the file in the cartridge disk
	jsr prolog
	jsr di_open

	; restore registers
	jsr epilog
	
	; signal no error (TODO)
	clc
	jmp disableRom
	
	
closeImpl:
; KERNAL function for closing the file, but no IEC communication
	JSR $F314	; search in logical file table (input A instead of X)
	BEQ closeImpl2
	CLC
	RTS
closeImpl2:
	JSR $F31F	; set file parameters

; now test for cartridge disk
	lda $ba
	jsr selectFlashDisk
	bcc closeImpl3
	jmp closeCallback2  ; end with original KERNAL function

; close without IEC communication
closeImpl3:
	TXA
	PHA
	jmp closeCallback3



chkinImpl:
; start of the original KERNAL function
	JSR $F30F	; search in logical file table
	BEQ chkinImpl2
	jmp chkinCallback2  ; file not open error
chkinImpl2:
	JSR $F31F	; set file parameters
	
	; now test for cartridge disk
	lda $ba
	jsr selectFlashDisk
	bcc chkinImpl3
	jmp chkinCallback3  ; continue with original KERNAL function
chkinImpl3:	
	; set current input device
	lda $ba
	jmp chkinCallback4

	
chkoutImpl:
; start of the original KERNAL function
	JSR $F30F	; search in logical file table
	BEQ chkoutImpl2
	jmp chkoutCallback2  ; file not open error
chkoutImpl2:
	JSR $F31F	; set file parameters

	; now test for cartridge disk
	lda $ba
	jsr selectFlashDisk
	bcc chkoutImpl3
	jmp chkoutCallback3  ; continue with original KERNAL function
chkoutImpl3:
	; set current output device
	lda $ba
	jmp chkoutCallback4
	

chrinImpl:
	; test for cartridge disk
	lda $99
	jsr selectFlashDisk
	bcc chrinImpl2
	jmp chrinCallback2

chrinImpl2:
	; call the cartride disk implementation
	jsr prolog
	jsr di_chrin
	jsr epilog
	clc
	jmp disableRom
	
chroutImpl:
	; test for cartridge disk
	pha
	lda $9a
	jsr selectFlashDisk
	bcc chroutImpl2
	pla
	jmp chroutCallback2

chroutImpl2:
	; ignore, not implemented for cartridge disk
	pla
	clc
	jmp disableRom

getinImpl:
	; test for cartridge disk
	lda $99
	jsr selectFlashDisk
	bcc getinImpl2
	jmp getinCallback2

getinImpl2:
	; call the cartride disk implementation
	jsr prolog
	jsr di_chrin
	jsr epilog
	clc
	jmp disableRom


loadImpl:
; test for drive
		pha
		lda $ba
		jsr selectFlashDisk
		bcc loadImpl2
; original KERNAL load function
		pla
		jmp loadCallback2

loadImpl2:
		; no save support, so verify is always ok
		pla
		bne loadImpl4

		; call implementation, RAM address in X/Y, secondaryAddress in accu
		jsr prolog
		lda $b9
		jsr di_load
		jsr epilog

		; set carry flag and error code	
		cmp #0
		beq loadImpl4
		; return file not found error
		lda #4
		sec
		jmp disableRom
	
		; return no error
loadImpl4:	ldx ptr4
		ldy ptr4+1
		clc
		jmp disableRom




prolog:
	pha
	txa
	pha
	jsr swap
        pla
        tax
        pla
        rts

epilog:
	pha
	txa
	pha
	jsr swap
        pla
        tax
        pla
        rts

swap:	; swap zeropage
	lda #1
	sta RAM_ADDRESS_EXTENSION
        ldx #zpEnd-zpStart
swap2:  lda $df00,x
	pha
        lda zpStart,x
        sta $df00,x
        pla
        sta zpStart,x
        dex
        bpl swap2

	; swap data
	lda #2
	sta RAM_ADDRESS_EXTENSION
        ldx #diskDataEnd-diskDataStart
swap3: lda diskDataStart,x
	pha
        lda $df00,x
        sta diskDataStart,x
        pla
        sta $df00,x
        dex
        bpl swap3

	; swap diskbuf
	lda #3
	sta RAM_ADDRESS_EXTENSION
        ldx #0
swap4:	lda diskbuf,x
	pha
        lda $df00,x
        sta diskbuf,x
        pla
        sta $df00,x
        dex
        bne swap4

	; back to trampoline RAM bank
	lda #0
	sta RAM_ADDRESS_EXTENSION
        rts


blockStartLow:
	.byte $00, $00, $15, $2a, $3f, $54, $69, $7e, $93, $a8, $bd, $d2, $e7, $fc, $11, $26, $3b, $50, $65, $78
	.byte $8b, $9e, $b1, $c4, $d7, $ea, $fc, $0e, $20, $32, $44, $56, $67, $78, $89, $9a, $ab, $bc, $cd, $de
blockStartHigh:
	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01
	.byte $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02


;
; convert track/sector to blocknum
;
; Input: A = sector, X = track
; Output: A/X = low/high block number
; Used registers: A, X
;
_get_block_num:
; add track start to sector
	clc
	adc blockStartLow,x
	pha
	lda blockStartHigh,x
	adc #0
; return in A/X (low/high)
	tax
	pla
	rts


;
; return a pointer to the next block in the chain
;
; Input: A = sector, X = track
; Output: A/X = low/high block number
; Used registers: A, X, Y
;
_next_ts_in_chain:
; get start address in A/X (low/high)
	jsr _get_ts_addr
	sta ptr1
	stx ptr1+1
	ldy #0
	lda (ptr1),y
	sta _imgfileTrack
	iny
	lda (ptr1),y
	sta _imgfileSector
; set both to 0, if track is greater than max allowed track
	cmp #TRACKS+1
	bcc next_ts_in_chain2
	lda #0
	sta _imgfileTrack
	sta _imgfileSector
next_ts_in_chain2:
	rts


; count number of free blocks
;
; Input: -
; Output: A/X = low/high free blocks count
; Used registers: A, X, Y
;
_blocks_free:
	ldx #BAM_TRACK
	lda #BAM_SECTOR
	jsr _get_ts_addr
	sta ptr1
	stx ptr1+1
	lda #0
	sta ptr2
	lda #0
	sta ptr2+1
	ldx #1
_blocks_free2:
	cpx #DIR_TRACK
	beq _blocks_free3
	txa
	asl
	asl
	tay
	lda (ptr1),y
	clc
	adc ptr2
	sta ptr2
	lda #0
	adc ptr2+1
	sta ptr2+1
_blocks_free3:
	inx
	cpx #TRACKS+1
	bne _blocks_free2
	lda ptr2
	ldx ptr2+1
	rts


;
; match pattern in OS filename ($bb/$bc, with $b7 length) and return 1, if matched
;
; Input: A/X = low/high address of name to compare, filled with $a0, max size 16 chars
; Output: A = 1 if matched
; Used registers: A, X, Y
;
_match_pattern:
	; save pattern
	sta ptr1
	stx ptr1+1
	
	; limit filename size to 16
	lda $b7
	cmp #17
	bcc match_pattern2
	lda #16
match_pattern2:
	sta tmp1
	
	; compare filename with pattern
	ldy #0
	cpy match_pattern_end
	beq match_pattern_end
match_pattern3:
	; match always, if * is found
	jsr readFilename
	cmp #'*'
	bne match_pattern5
match_pattern4:
	lda #1
	rts
match_pattern5:	
	; rawname is filled with 0xa0, so it doesn't match, if fill character found
	lda (ptr1),y
	cmp #$a0
	bne match_pattern7
match_pattern6:
	lda #0
	rts
match_pattern7:	
	; '?' is always matched
	cmp #'?'
	beq match_pattern_next
	; test other character
	jsr readFilename
	cmp (ptr1),y
	bne match_pattern6
match_pattern_next:
	iny
	cpy tmp1
	bne match_pattern3
	
match_pattern_end:	
	cpy #16
	beq match_pattern4  ; all possible characters tested, matched
	; all characters of pattern tested, test if rawname is not longer
	lda (ptr1),y
	cmp #$a0
	beq match_pattern4
	bne match_pattern6  ; unconditional jump


;
; find file in directory
;
; Input: -
; Output: A = 1 if file was found, start stored in _imgfileTrack/_imgfileSector
; Used registers: A, X, Y
;
_find_file_entry:
	; get next BAM sector in imgfileTrack/imgfileSector
	ldx #BAM_TRACK
	lda #BAM_SECTOR
	jsr _next_ts_in_chain

	; test while imgfileTrack is not zero
find_file_entry_next:
	lda _imgfileTrack	
	beq find_file_entry_not_found
	
	; load sector
	tax
	lda _imgfileSector
	jsr _get_ts_addr
	sta ptr2
	stx ptr2+1
	
	; compare filename for all 8 slots
	lda #0
	sta tmp2
find_file_entry2:
	ldy tmp2
	iny
	iny
	lda (ptr2),y
	and #$bf
	cmp #T_PRG | $80
	bne find_file_entry_next_slot
	; compare filename, if it is a PRG file
	lda tmp2
	clc
	adc ptr2
	sta ptr1
	lda ptr2+1
	adc #0
	sta ptr1+1
	clc
	lda ptr1
	adc #5
	sta ptr1
	lda ptr1+1
	adc #0
	sta ptr1+1
	lda ptr1
	ldx ptr1+1
	jsr _match_pattern
	cmp #1
	bne find_file_entry_next_slot
	; file found, get start track and sector
	lda tmp2
	clc
	adc #3
	tay
	lda (ptr2),y
	sta _imgfileTrack
	iny
	lda (ptr2),y
	sta _imgfileSector
	lda #1
	rts
	
find_file_entry_next_slot:
	lda tmp2
	clc
	adc #32
	sta tmp2
	bne find_file_entry2

	; get next sector	
	ldy #0
	lda (ptr2),y
	tax
	iny
	lda (ptr2),y
	jsr _next_ts_in_chain
	jmp find_file_entry_next

find_file_entry_not_found:
	lda #0
	rts


;
; convert $a0 characters to spaces
;
; Input: A
; Output: A
; Used registers: A
;
_convertSpace:
	cmp #$a0
	bne convertSpace2
	lda #32
convertSpace2:
	rts


;
; open a file
;
; Input: A
; Output: A = 0 if ok
; Used registers: A
;
di_open:
	lda #0
	sta $90
	sta addBlocksFreeFlag
	sta _imgfileBuflen
	sta _imgfileBuflen+1
	sta _imgfileBufptr
	sta _imgfileBufptr+1
	sta bytesleft
	sta bytesleft+1

	; default mode is read
	lda #'r'
	sta _imgfileMode

	; test for directory filename "$"
	lda $b7
	cmp #1
	beq di_open_test1
	jmp di_open4
di_open_test1:
	ldy #0
	jsr readFilename
	cmp #'$'
	beq di_open_test2
	jmp di_open4
di_open_test2:
	
	; calculate block free
	jsr _blocks_free
	sta _blocksfree
	stx _blocksfree+1
	
	; set directory mode
	lda #'$'
	sta _imgfileMode

	; read directory header
	ldx #DIR_TRACK
	stx _imgfileTrack
	lda #DIR_SECTOR
	sta _imgfileSector
	jsr _get_ts_addr
	sta ptr1
	stx ptr1+1
	
	; create basic program
	; start address
	ldy #0
	lda #1
	sta (ptr1),y
	iny
	lda #4
	sta (ptr1),y
	iny
	; link address
	lda #1
	sta (ptr1),y
	iny
	sta (ptr1),y
	iny
	; line number
	lda #0
	sta (ptr1),y
	iny
	sta (ptr1),y
	iny
	; disk name
	lda #$12
	sta (ptr1),y
	iny
	lda #'"'
	sta (ptr1),y
	iny
	ldx #16
	sty tmp1
	ldy #$90
	sty tmp2
di_open2:
	ldy tmp2
	lda (ptr1),y
	inc tmp2
	jsr _convertSpace
	ldy tmp1
	sta (ptr1),y
	inc tmp1
	dex
	bne di_open2
	ldy tmp1
	lda #'"'
	sta (ptr1),y
	iny
	lda #' '
	sta (ptr1),y
	iny
	; disk id and DOS type
	ldx #5
	sty tmp1
	ldy #$a2
	sty tmp2
di_open3:
	ldy tmp2
	lda (ptr1),y
	inc tmp2
	jsr _convertSpace
	ldy tmp1
	sta (ptr1),y
	inc tmp1
	dex
	bne di_open3
	ldy tmp1
	; line end
	lda #0
	sta (ptr1),y
	iny
	
	lda ptr1
	sta _imgfileBuffer
	lda ptr1+1
	sta _imgfileBuffer+1
	lda #18
	sta _imgfileNextTrack
	lda #1
	sta _imgfileNextSector
	sty _imgfileBuflen
	bne di_open_end  ; unconditional jump
	
	; standard file read
di_open4:
	jsr _find_file_entry
	cmp #1
	beq di_open6
	; file not found
di_open5:
	lda #1
	rts
di_open6:
	lda _imgfileTrack
	cmp #TRACKS+1
	bcs di_open5  ; invalid track
	ldx _imgfileTrack
	lda _imgfileSector
	jsr _get_ts_addr
	sta ptr1
	stx ptr1+1
	clc
	lda ptr1
	adc #2
	sta _imgfileBuffer
	lda ptr1+1
	adc #0
	sta _imgfileBuffer+1
	ldx #254
	ldy #0
	lda (ptr1),y
	sta _imgfileNextTrack
	bne di_open7
	ldx _imgfileNextSector
	dex
di_open7:
	stx _imgfileBuflen
	iny
	lda (ptr1),y
	sta _imgfileNextSector
	
di_open_end:
	lda #0
	sta _imgfileBufptr
	sta _imgfileBufptr+1
	rts



;
; read all 8 slots of one directory sector and convert inline to basic PRG
;
; Input: A/X = low/high of slots start
; Output: -
; Used registers: A, X, Y
;
_readDirectorySlots:
	sta ptr1   ; read pointer
	stx ptr1+1
	sta ptr3   ; write pointer
	stx ptr3+1
	sta _imgfileBuffer
	stx _imgfileBuffer+1
	lda #8
	sta tmp2  ; number of slots
readDirectorySlotsStart:
	ldy #2
	lda (ptr1),y
	bne readDirectorySlotsNextSkip
	jmp readDirectorySlotsNext
readDirectorySlotsNextSkip:	
	pha  ; save type
	; get number of blocks for this file
	ldy #$1e
	lda (ptr1),y
	sta ptr2
	iny
	lda (ptr1),y
	sta ptr2+1
	; line link
	lda #1
	jsr storeNextByte
	jsr storeNextByte
	; file size as line number
	lda ptr2
	jsr storeNextByte
	lda ptr2+1
	jsr storeNextByte
	; move name to upper half
	ldx #15
readDirectorySlots2:
	txa
	clc
	adc #5
	tay
	lda (ptr1),y
	pha
	txa
	clc
	adc #16
	tay
	pla
	sta (ptr1),y
	dex
	bpl readDirectorySlots2
	; indention, depending on block size
	lda ptr2+1
	bne readDirectorySlots4
	lda ptr2
	cmp #10
	bcs readDirectorySlots3
	lda #' '
	jsr storeNextByte
readDirectorySlots3:
	lda ptr2
	cmp #100
	bcs readDirectorySlots4
	lda #' '
	jsr storeNextByte
readDirectorySlots4:
	lda #' '
	jsr storeNextByte
	lda #'"'
	jsr storeNextByte
	; append name to current position
	ldx #0
	stx tmp3  ; 1 = closing quote was set
readDirectorySlots5:
	txa
	clc
	adc #16
	tay
	lda (ptr1),y
	ldy tmp3
	bne readDirectorySlots7
	cmp #$a0
	bne readDirectorySlots7
	inc tmp3
	lda #'"'
readDirectorySlots6:	
	jsr storeNextByte
	jmp readDirectorySlots8
readDirectorySlots7:
	jsr _convertSpace
	jmp readDirectorySlots6
readDirectorySlots8:
	inx
	cpx #16
	bne readDirectorySlots5

	; closing quote, or space
	lda tmp3
	beq readDirectorySlots9
	lda #' '
	jsr storeNextByte
	jmp readDirectorySlots10
readDirectorySlots9:	
	lda #'"'
	jsr storeNextByte
readDirectorySlots10:

	; type
	pla
	pha
	and #$80
	beq readDirectorySlots11
	lda #' '
	jsr storeNextByte
	jmp readDirectorySlots12
readDirectorySlots11:
	lda #'*'  ; closed flag
	jsr storeNextByte
readDirectorySlots12:
	pla
	pha
	and #7
	tax
	lda filetype1,x
	jsr storeNextByte
	lda filetype2,x
	jsr storeNextByte
	lda filetype3,x
	jsr storeNextByte
	pla
	and #$40
	bne readDirectorySlots13
	lda #' '
	bne readDirectorySlots14  ; unconditional jump
readDirectorySlots13:
	lda #'<'  ; locked flag
readDirectorySlots14:
	jsr storeNextByte

	; aligned to 32 bytes
	lda ptr2+1
	bne readDirectorySlotsGreater255_1
	lda ptr2
	cmp #10
	bcc readDirectorySlots15
readDirectorySlotsGreater255_1:
	lda #' '
	jsr storeNextByte
readDirectorySlots15:
	lda ptr2+1
	bne readDirectorySlotsGreater255_2
	lda ptr2
	cmp #100
	bcc readDirectorySlots16
readDirectorySlotsGreater255_2:
	lda #' '
	jsr storeNextByte
readDirectorySlots16:
	lda #' '
	jsr storeNextByte
	; line end
	lda #0
	jsr storeNextByte

readDirectorySlotsNext:	
	dec tmp2
	beq readDirectorySlotsNextEnd
	clc
	lda ptr1
	adc #32
	sta ptr1
	lda ptr1+1
	adc #0
	sta ptr1+1
	jmp readDirectorySlotsStart
readDirectorySlotsNextEnd:

	; calculate buffer length
	lda ptr3
	sec
	sbc _imgfileBuffer
	sta _imgfileBuflen
	lda ptr3+1
	sbc _imgfileBuffer+1
	sta _imgfileBuflen+1
	
	lda #0
	sta _imgfileBufptr
	sta _imgfileBufptr+1

	rts

storeNextByte:
	sty tmp1
	ldy #0
	sta (ptr3),y
	ldy tmp1
	inc ptr3
	bne storeNextByte2
	inc ptr3+1
storeNextByte2:	
	rts
	

;
; add "blocks free" line and basic program end to the diskbuf
;
; Input: -
; Output: -
; Used registers: A, X, Y
;
_addBlocksFree:
	lda #<diskbuf
	ldx #>diskbuf
	sta ptr3   ; write pointer
	stx ptr3+1
	sta _imgfileBuffer
	stx _imgfileBuffer+1
	; link address
	lda #1
	jsr storeNextByte
	jsr storeNextByte
	; line number
	lda _blocksfree
	jsr storeNextByte
	lda _blocksfree+1
	jsr storeNextByte
	ldx #0
addBlocksFree2:	
	lda blocksFreeText,x
	jsr storeNextByte
	inx
	cpx #12
	bne addBlocksFree2
	ldx #13
	lda #' '
addBlocksFree3:
	jsr storeNextByte
	dex
	bne addBlocksFree3
	; basic program end
	lda #0
	jsr storeNextByte
	jsr storeNextByte
	jsr storeNextByte
	
	; calculate buffer length
	lda ptr3
	sec
	sbc _imgfileBuffer
	sta _imgfileBuflen
	lda ptr3+1
	sbc _imgfileBuffer+1
	sta _imgfileBuflen+1
	
	lda #0
	sta _imgfileBufptr
	sta _imgfileBufptr+1

	rts


;
; read data from disk
;
; Input: A = len, X/Y = load/high address of buffer
; Output: A/X = low/high block number
; Used registers: A, X
;
di_read:
buffer = ptr4
len = tmp4
	sta len
	stx buffer
	sty buffer+1
	lda #0
	sta addBlocksFreeFlag
di_read2:
	sec
	lda _imgfileBuflen
	sbc _imgfileBufptr
	sta bytesleft
	lda _imgfileBuflen+1
	sbc _imgfileBufptr+1
	sta bytesleft+1
	cmp #0
	bne di_read_trampoline
	lda bytesleft
	cmp #0
	beq di_read_fill_buffer
di_read_trampoline:
	jmp di_read_write

	; fill buffer
di_read_fill_buffer:
	lda #0
	sta _imgfileBuflen+1
	lda addBlocksFreeFlag
	beq di_read4
	cmp #1
	bne di_read3
	jsr _addBlocksFree
	lda #2
	sta addBlocksFreeFlag
	bne di_read2  ; unconditional jump
di_read3:
	rts
di_read4:
	lda _imgfileNextTrack
	beq di_read3
	; don't use the chain for first directory track, because it might be wrong
	lda _imgfileTrack
	cmp #18
	bne di_read5
	lda _imgfileSector
	cmp #0
	bne di_read5
	lda #18
	sta _imgfileTrack
	lda #1
	sta _imgfileSector
	bne di_read6  ; unconditional jump
di_read5:	
	ldx _imgfileTrack
	lda _imgfileSector
	jsr _next_ts_in_chain
di_read6:	
	; track = 0, end marker
	lda _imgfileTrack
	beq di_read3
	
	; load next sector
	ldx _imgfileTrack
	lda _imgfileSector
	jsr _get_ts_addr
	sta ptr1
	stx ptr1+1
	
	; first two bytes are next track/sector
	ldy #0
	lda (ptr1),y
	sta _imgfileNextTrack
	iny
	lda (ptr1),y
	sta _imgfileNextSector

	; test raw read or directory read
	lda _imgfileMode
	cmp #'$'
	bne di_read7

	; directory read
	lda ptr1
	ldx ptr1+1
	jsr _readDirectorySlots
	lda _imgfileNextTrack
	bne di_read_next
	lda #1
	sta addBlocksFreeFlag
	bne di_read_next  ; unconditional jump
di_read7:	
	; raw read, set buffer to data, starting after the two track/sector bytes
	lda ptr1
	clc
	adc #2
	sta _imgfileBuffer
	lda ptr1+1
	adc #0
	sta _imgfileBuffer+1
	
	lda _imgfileNextTrack
	bne di_read8
	ldx _imgfileNextSector
	dex
	stx _imgfileBuflen
	jmp di_read9
di_read8:
	lda #254
	sta _imgfileBuflen
di_read9:
	lda #0
	sta _imgfileBuflen+1
	sta _imgfileBufptr
	sta _imgfileBufptr+1

di_read_next:
	jmp di_read2

di_read_write:
	; copy buffer
	lda bytesleft
	bne di_read_dec
	lda bytesleft+1
	beq di_read_write_end
di_read_dec:
	dec bytesleft
	lda bytesleft
	cmp #$ff
	bne di_read10
	dec bytesleft+1
di_read10:
	lda _imgfileBuffer
	clc
	adc _imgfileBufptr
	sta ptr1
	lda _imgfileBuffer+1
	adc _imgfileBufptr+1
	sta ptr1+1
	ldy #0
	lda (ptr1),y
	sta (buffer),y
	
	inc _imgfileBufptr
	bne di_read11
	inc _imgfileBufptr+1
di_read11:

	inc buffer
	bne di_read12
	inc buffer+1
di_read12:

	lda len
	beq di_read_write
	dec len
	bne di_read_write
	rts
di_read_write_end:
	jmp di_read2



; extern void __fastcall__ di_close(void);
di_close:
	lda #0
	sta $90
	clc
	rts
	
	

; debugging
	
filename: .byte "filename:",0

; print null terminated string on stdout, address in X/Y
printString:
	lda ptr1
	pha
	lda ptr1+1
	pha
	stx ptr1
	sty ptr1+1
	ldy #0
printString2:	tya
	pha
	lda (ptr1),y
	beq printString3
	jsr $e716
	pla
	tay
	iny
	jmp printString2	
printString3: pla
	pla
	sta ptr1+1
	pla
	sta ptr1
	rts

; print filename on stdout
printFilename:
	ldx #<filename
	ldy #>filename
	jsr printString
	ldy #0
printFilename2:
	cpy $b7
	beq printFilename3
	tya
	pha
	jsr readFilename
	jsr $e716
	pla
	tay
	iny
	jmp printFilename2
printFilename3:
	lda #13
	jsr $e716
	rts
	

;
; load file to RAM
;
; Input: A = secondaryAddress, X/Y = load/high of start address
; Output: 0 if ok, otherwise KERNAL error code
; Used registers: A, X, Y
;
di_load:
	sta secondaryAddress
	stx address
	sty address+1

	; open file
	jsr di_open
	cmp #0
	beq di_load2
	; file open error
	lda #1
	rts
di_load2:
	; start address handling
	ldx #<data
	ldy #>data
	lda #2
	jsr di_read
	lda secondaryAddress
	beq di_load3
	; use start address in file
	lda data
	sta address
	lda data+1
	sta address+1
di_load3:
	; read file
	ldx address
	ldy address+1
	lda #0
	jsr di_read
	; no error
	lda #0
	sta $90
	rts
	
;
; read one byte from current open file
;
; Input: A = secondaryAddress, X/Y = load/high of start address
; Output: 0 if ok, otherwise KERNAL error code
; Used registers: A, X, Y
;
di_chrin:
	ldx #<data
	ldy #>data
	lda #1
	jsr di_read
	lda #0
	sta $90
	lda data
	rts


blocksFreeText: .byte "blocks free."

; read top-down
filetype1: .byte "dspurcd?"
filetype2: .byte "eersebi?"
filetype3: .byte "lqgrlmr?"


; ------------------------------------------------------------------------
; Data

.segment        "CARTRIDGE_DISK_DATA"

diskDataStart:

flashAdr: .res 2
flashAdrBank: .res 2
statusSave: .res 1
aSave: .res 1
xSave: .res 1
ySave: .res 1

address: .res 2
data: .res 2
secondaryAddress: .res 1

bytesleft: .res 2
addBlocksFreeFlag: .res 1

_imgfileMode: .res 1
_imgfileTrack: .res 1
_imgfileSector: .res 1
_imgfileNextTrack: .res 1
_imgfileNextSector: .res 1
_imgfileBuffer: .res 2
_imgfileBufptr: .res 2
_imgfileBuflen: .res 2
_blocksfree: .res 2

diskDataEnd:


.segment        "CARTRIDGE_DISK_BUF"
diskbuf: .res $100


.segment        "CARTRIDGE_DISK_ZPSAVE"
zpsave: .res $7f