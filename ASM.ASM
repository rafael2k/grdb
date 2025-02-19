;    GRDB - debugger for dos with 32-bit extensions
;    Copyright (C) 1997-2006  David Lindauer
;
;    This program is free software; you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation; either version 2 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program; if not, write to the Free Software
;    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
;
;    (for GNU General public license see file COPYING)
;
;    you may contact the author at:  mailto::camille@bluegrass.net
; 
;    or by snail mail at:
;
;    David Lindauer
;    850 Washburn Ave.  Apt #99
;    Louisville, KY 40222
;
; ASM.ASM
;
; Function: Assembler parser
;
; not very efficient, but, fast enough!
;
	;MASM MODE
	.MODEL SMALL
	.386

include iasm.inc
include iopcodes.inc
include eaoperan.inc
include eopcodes.inc
include eopcom.inc
include eprints.inc
include einput.inc
include emtrap.inc
include	edispatc.inc
include eoperand.inc
include eoptions.inc
include ehistory.inc
include eexec.inc
include esymbol.inc
include edump.inc
include eentry.inc
include edpmi.inc
	PUBLIC	asm
	PUBLIC	arg1
	PUBLIC	arg2
	PUBLIC	arg3
	PUBLIC	RepPfxBitmap
	PUBLIC	lastofs
	PUBLIC	lastbyte
	PUBLIC	PrefixBitmapWord
        PUBLIC  EnteredMnemonic
        PUBLIC  farptr
        PUBLIC  slash, slashcont, slashcmd
		public lastseg, lastofs
		public asm32BitMode

        extrn incs32:byte                
	.data
mtoofew		db	"Not enough operands",0
slashcmd        db      0
lastbyte	db	0		;last char of valid mnemonic
lastofs		dd	0		;current disassembly offset
lastseg		dw	0		;and current segment
slastofs        dd      0
slastseg        dw      0
slasteip        dd      0
slastcs         dw      0
asmcount        dd      0
say_repne       db      "repnz",0       ;prefix strings to look for
say_repe        db      "repz",0
say_rep		db	"rep",0
say_lock        db      "lock",0
say_word	db	"word",0	;opcode size overrides
say_byte	db	"byte",0
say_ptr		db	"ptr"
say_far         db      "far"
arg1		asmop	<>		;three args
arg2		asmop	<>
arg3		asmop	<>
arg4		asmop	<>		;temp for base-mode register gathering
AsmbldInstrsBuf db      40 DUP (?)      ;temporary to hold assembled instructions
OpSizeTable	db	16 DUP (?)	;sizes returned by AOP routines
OpSizeTblIndex	dw	0		;pointer into OpSizeTable
RepPfxBitmap	db	?		;bitmap of which rep prefix found
EnteredMnemonic	db	16 DUP (?)	;bucket to hold mnemonic as typed
farptr          db      ?

;DefaultSeg appears to hold an index into SegmentPfxBytes.

DefaultSeg	db	0		;current default seg (DS or SS)
SegmentPfxBytes	db	26h,2eh,36h,3eh,64h,65h	;table of seg prefixes
	SEGPFXLISTSIZE	equ	$-SegmentPfxBytes
OverridePfxList db      "osasgsfsdssscses"      ;list of prefixes with colon
PrefixBitmapWord	dw	?	;bitmap of which prefix found
	.CODE
slashbuf        db      32 dup (0)
slash PROC
        mov     eax,[RegDumpEIP]
        mov     [slasteip],eax
        mov     ax,[RegDumpCS]
        mov     [slastcs],ax
        mov     ax,[lastseg]
        mov     [slastseg],ax
        mov     eax,[lastofs]
        mov     [slastofs],eax
        mov     [lastseg],cs
        mov     word ptr [lastofs],offset slashbuf
        mov     [RegDumpCS],cs
        mov     [RegDumpEIP],offset slashbuf
        mov     [asmcount],0
        push    fs
		mov		ax,[lastseg]
		call	compatibleUtilitySeg
		mov		fs,ax
        call    doasm2                   ; do assembly
        pop     fs
        inc     slashcmd
        call    proceedone
        ; never gets here
slash ENDP
slashcont PROC        
        dec     [slashcmd]
        mov     eax,[slasteip]
        mov     [RegDumpEIP],eax
        mov     ax,[slastcs]
        mov     [RegDumpCS],ax
        mov     ax,[slastseg]
        mov     [lastseg],ax
        mov     eax,[slastofs]
        mov     [lastofs],eax
        ret
slashcont  ENDP
;
; interpreter stub to get params
; INPUT: DS:SI points at the user input line, just past the command char.
; I am assuming that someone issued the A command.  This can be by itself, 
; or it can be followed by some addresses
; The syntax ins A [[segment:]offset]
;	where 
;	[segment:] can be any segment register, or it can be any hex
;		number of up to 4 digits.
;	[offset] can be any hex number of up to 8 digits
; OUTPUT: lastseg and lastofs set up to assemble at if user provided a legal 
;	address. Segment is also in FS
;	CY if invalid address
;	code address saved in case an unqualified 'A' command later
;
;
asm	PROC
	call	WadeSpace		; see if address given
	jnz	readaddr		; yep, get it (not CR past spaces)
	movzx	eax,lastseg		; else see if any last addr
	or	eax,lastofs
	jz	usehere			;if not, go from where we are
	mov	dx,lastseg		;else, get prior assemble address
	mov	ebx,lastofs
	jmp	gotaddr			;no need to set up our own
usehere:
	mov	ebx,RegdumpEIP		;else load our CS:IP
	mov	dx,RegdumpCS
	jmp	gotaddr			;and use that

readaddr:
	call	ReadAddress		; read address from input line
	jc	aserrm			; out on err
	call	WadeSpace		; make sure nothing else
	jnz	aserrm			; NZ means we didn't hit a CR
	call	defCS			; default CS
gotaddr:
	mov	esi,ebx			; load address
	mov	ax,dx
	call	compatibleUtilitySeg
	mov	fs,ax
;	and	esi,0ffffh		;force to 16-bit offset
	mov	lastseg,dx		;save current segment/selector
	mov	lastofs,esi		;and current 16-bit offset
	call	histoff
        mov     [asmcount],-1
	call	doasm			; do assembly
	call	histon
	clc				; exit
	ret
aserrm:
	stc				; exit with err
	ret
asm	ENDP
;
; prompt for a line, parse and assemble
;
; main assembler
;
; OK, the user pressed A <CR>. Here we solicit each entry, one line
; at a time, and convert the valid ones to opcodes. Invalid entries are
; complained about, and we return to the top of this routine to get
; another attempt.
; INPUT: address to assemble at is in FS (and lastseg): lastofs
; OUTPUT: Assembled code placed at target memory location and code ptr
;	  incremented
; PROCESSING: 
;	1) Display the segment:offset for the next line 
;	2) Get an instruction from the user
;		If CR only, we are done
;	3) If error, report and goto step 1, else assemble the instruction
;		into a temporary assembly buffer
;	4) Add any prefixes or overrides to the buffer as required
;	5) Copy the buffer to the target memory location
;	6) Return to step 1 until done.
; NOTES:
;	1) GetInputLine places the user input into InputBuffer, an 80-char
;		buffer. It handles backspacing. It returns with SI pointing
;		to the beginning of the edited input, which may not make
;		sense
;	2) getCode points DI at a 16-char bucket I call EnteredMnemonic,
;		and returns the first delineated string
;
doasm	PROC
        test    [asmcount],-1
        jz      doasx
        dec     [asmcount]
	call	crlf			;move to new line
	mov	ax,fs			;get segment address
	call	printword		;paint that
	mov	dl,':'			;and a colon
	call	putchar
	mov	eax,lastofs		;get last offset
	test	cs:[inDPMI],1
	jz		adr16
	test	cs:[dpmiType],1
	jz		adr16
	call	printdword
	jmp		adrjn
adr16:
	call	printword		;print it
adrjn:
	call	printspace		;and a couple of spaces
	call	printspace
	call	GetInputLine           	; get input line
doasm ENDP
doasm2 PROC
	call	WadeSpace		; if nothing there we are done
	jnz		doasm3
	cmp		al,';'
	jnz	doasx			;since we hit the CR
	inc		[asmcount]		; got a comment at beginning of line, skip current line
	jmp	doasm
doasm3:
        cmp     byte ptr [si+2],' '
        jnz     normproc
        cmp     word ptr [si],'dd'
        jz      dodd
        cmp     word ptr [si],'wd'
        jz      dodw
        cmp     word ptr [si],'bd'
        jz      dodb
normproc:
	sub	al,al			;clear out AL
	call	setsize			;put 0 into these 3 fields
	mov	PrefixBitmapWord,0	;say no prefix found
	mov	DefaultSeg,3
	call	getcode			; get the opcode
	jc	badop
	mov	di,offset arg1		; get first arg
	call	parsearg
	jc	badarg
	mov	di,offset arg2		; get second arg
	call	parsearg
	jc	badarg
	mov	di,offset arg3		; get third arg
	call	parsearg
	jc	badarg
	jz	assemble		;if no more, to assemble it
manyerr:
	Call	printAlignedErrorMsg	;else bitch about too many operands
	db	"Too many operands",0
	jmp	doasm
badarg:
	call	printAlignedErrorMsg	;complain about invalid operand
	db	"Unknown operand",0
	jmp	doasm
badop:		
	call	printAlignedErrorMsg	;complain about invalid opcode
	db	"Unknown opcode",0
	jmp	doasm
assemble:
	call	validops		;size check and set
	jc	doasm			;size mismatch, ignore
	mov	si,offset mnemonicMatchAddrTable	;find table we built
        movzx   ecx,[mnemonicMatchCount] ;number of valid table entries
	mov	OpSizeTblIndex,0	;init index to top of table

;mnemonicMatchAddrTable contains a list of up to 10h addresses. Each address
;points to a structure. Each structure contains (among other things) a
;pointer to a string for this mnemonic, the base opcode for the
;mnemonic, and an index to the routine used to assemble the code
;  This loop is examining every valid element of the table we build to
;isolate those instances of this mnemonic that are valid in this case (that
;is, valid for size, addressing mode, etc).

assl:
	push	cx			;save count
	push	si			;save table address
	mov	si,[si]			;find structure address
	mov	di,offset AsmbldInstrsBuf	;where to put binary 
	call	oneasm			;dispatch for this operand
					; copies opcode for this instruction
					; into the assembled code buffer
	mov	cl,0			;assume we didn't do anything
	jc	assx2			;and if true, cl is right
	mov	cx,di			;else get offset we ended up at
	sub	cx,offset AsmbldInstrsBuf	;minus starting offset
assx2:		   	
	mov	bx,OpSizeTblIndex	;pointer into opsize table
	mov	[bx+OpSizeTable],cl	;save how many we did
	inc	OpSizeTblIndex		;bump to next location
	pop	si			;restore mnemonic ptr table address
	pop	cx			;and how many to examine
	add	si,2			;point to next possibility
	loop	assl			;do them all
	movzx	ecx,byte ptr OpSizeTblIndex	;see if we did anything
	jcxz	nomatch			;nope, not found in table
	sub	bx,bx			;else init for next loop


;at this point we have at least one match between the disassembly
;strucutre and the mneominc/addressmode / size data we accrued earlier.
;We are going to search the matched entries for the one with the
;smallest possible byte sequence

szllp:
	or	bh,bh			;if bh is zero
	jz	szlg			;skip this stuff
	cmp	bh,[ecx+OpSizeTable-1]	;see if high byte of table value
					;is greater than bh
	jb	sslc			;go here if it is
	test	byte ptr [ecx+OpSizeTable-1],0FFh	;see if table value is 0
	jz	sslc			;and if it is, same place

;OK, BH is keeping track of the length of the sequence, and BL is keeping
;track of the table offset to that sequence.  We get here in case a) this
;is the only valid sequence we found, or b) this sequence is shorter than
;the prior shortest sequence we found.

szlg:
	mov	bh,[ecx+OpSizeTable-1]	;get high byte of tbl element->bh
	mov	bl,cl			;track the index to the shortest
sslc:
	loop	szllp			;do for as many valid match instances
					;as we found
ssgot:
	or	bh,bh			;did we find anything?
	jz	nomatch			;no, we did not
	sub	bh,bh			;convert BL into a word index
	shl	bx,1			;into the match table
	mov	si,[bx+mnemonicMatchAddrTable-2]	;get an address
	mov	di,offset AsmbldInstrsBuf	;point to buffer
	call	oneasm				;build our favorite sequence
	mov	cx,di				;DI is new buffer offset
	mov	si,offset AsmbldInstrsBuf	;switch top to SI
	sub	cx,si			;get buffer bytecount
	mov	edi,lastofs		;point to last assemble offset
	push	es			;save ES
	push	fs			;mov FS to ES
	pop	es
	push	cx			;save count

;Now DI points to the actual location in memory where we want to put our
;assembled buffer.  Since prefixes are not in the assembly buffer, we first
;stick in as many prefixes as we found, then paste the remainder of the
;buffer beyond them.

	call	InsertPrefixes
	pop	cx			;restore count
	jc	pfxerr			;if carry, too many prefixes
	movzx	ecx,cx
	movzx	esi,si
	db	67h
	rep	movsb			;copy to memory location for asm
	mov	lastofs,edi		;update assemble in mem location
doasmn:
	pop	es			;restore old ES
	jmp	doasm			;and get next instruction
pfxerr:
	pop	es			;rectify stack
	call	printAlignedErrorMsg
	db	"Too many prefixes",0
	jmp	doasm

nomatch:
	call	printAlignedErrorMsg
	db	"Invalid opcode/operand combo",0
	jmp	doasm
doasx:
	ret
doasm2  ENDP
dodd    proc
        mov     al,[memsize]
        push    ax
        mov     [memsize],2
        jmp     dbcont
dodd    endp

dodw    PROC
        mov     al,[memsize]
        push    ax
        mov     [memsize],1
        jmp     dbcont
dodw    ENDP

dodb    PROC
        mov     al,[memsize]
        push    ax
        mov     [memsize],0
dodb    ENDP
dbcont  PROC
        mov     al,2
        mov     cl,[memsize]
        shl     al,cl
        mov     [diglen],al
        push    fs
        push    ds
        pop     fs
        add     si,2
        mov     di,offset AsmbldInstrsBuf
        movzx   edi,di
        call    entrytobuf    
        pop     fs
        jnc     dbnoerr
        call    printAlignedErrorMsg
        db      "Invalid data",0
        jmp     dberrx
dbnoerr:
        mov     ecx,edi
        mov     si,offset AsmbldInstrsBuf
        sub     cx,si
        mov     edi,[lastofs]
        push    es
        push    fs
        pop     es
        cld
        rep     movsb
        pop     es
        mov     [lastofs],edi
dberrx:      
        pop     ax
        mov     [memsize],al
        jmp     doasm
dbcont  ENDP

;
;this routine is the shell which assembles an instruction based
;on the opcode/operand/size data
;
;INPUT: SI points to the opcode structure
;       DI points to a temp buffer into which we do the assembly
;OUTPUT: BUFFER FILLED.  This routine does the 0F prefix but none of the
;        other prefixes

oneasm	PROC
	test	[si+OPCODE.FLAGS],prefix0F	;0F prefix on this guy?
	jz	no386p				;nope
	mov	al,0fh				;else stash the 0F
	stosb					;into the buffer
no386p:

;The syntax here works, but it can be clarified a little. opcode.operands
;was never explicitly written to.  Instead, we build a table of pointers
;into a table of opcode structures. SI contains one of the pointers out
;of that table. Maybe it's just because I'm more used to it, but I prefer
;the MASM syntax to indicate this:
;	mov	al,(opcode ptr [si]).operands

	mov	al,[si+opcode.operands]		;get addressing mode
	push	0				;TableDispatch calls this subkey
	call	TableDispatch			;and dispatch it
        dw      70                              ;length of table

	dw	AOP0,  AOP1,  AOP2,  AOP3,  AOP4,  AOP5,  AOP6,  AOP7
	dw	AOP8,  AOP9,  AOP10, AOP11, AOP12, AOP13, AOP14, AOP15
	dw	AOP16, AOP17, AOP18, AOP19, AOP20, AOP21, AOP22, AOP23
	dw	AOP24, AOP25, AOP26, AOP27, AOP28, AOP29, AOP30, AOP31
	dw	AOP32, AOP33, AOP34, AOP35, AOP36, AOP37, AOP38, AOP39
	dw	AOP40, AOP41, AOP42, AOP43, AOP44, AOP45, AOP46, AOP47
        dw      AOP48, aop49, aop50, AOP51, AOP52, AOP53, AOP54, AOP55
        dw      AOP56, AOP57, AOP58, AOP59, AOP60, AOP61, AOP62, AOP63
        dw      AOP64, AOP65, AOP66, AOP67, AOP68, AOP69, AOP70
	ret
oneasm	ENDP

asm32Bitmode PROC
	test	[optass32],1
	jnz		finasm32bit
        test    cs:[incs32],1
        jnz     finasm32bit
	test	cs:[inDPMI],1
	jz		finasm32bit
	test	cs:[dpmiType],1
finasm32bit:
	ret
asm32bitmode ENDP
;
; inserts prefixes into buffer
;
;INPUT: ES:DI points to buffer
;OUTPUT: all prefixes inserted and DI updated
;
; now we do the remainder of the 8086 repeate and lock prefixes
;
;
;
; now comes the 386 prefixes

InsertPrefixes	PROC
	sub	dx,dx
	test	RepPfxBitmap,AF_LOCK	;see if lock set
	jz	nlock			;nope, no lock
	mov	al,0f0h			;else stash lock prefix
	stosb
nlock:
        test    RepPfxBitmap,AF_REPNE   ;see if REPNE set
	jz	nrepne			; nope, no REPNE
	mov	al,0f2h			;stick in repne prefix
	stosb
nrepne:
        test    RepPfxBitmap,AF_REPE OR AF_REP    ; See if REPE
	jz	nrepe			; noe, no repe
	mov	al,0f3h			;stick in repe prefix
	stosb
nrepe:
	call	asm32BitMode
        jz      ip_noinv
        xor     [PrefixBitmapWord],AS_OPSIZETEST + AS_ADDRSIZETEST
ip_noinv:
        test    [PrefixBitmapWord],AS_ADDRSIZESET  ;see if 67 override
        jz     naddrsizna
        test    [PrefixBitmapWord],AS_ADDRSIZETEST
        jz      naddrsizna
	mov	al,67h
	stosb

naddrsizna:
        test    [PrefixBitmapWord],AS_OPSIZESET    ;see if 66 override
        jz      nopsizna
        test    [PrefixBitmapWord],AS_OPSIZETEST
        jz      nopsizna
	mov	al,66h
	stosb
nopsizna:

;
; now we do segment overrid prefixes by scanning the prefix bitmap
; word
	sub	dx,dx			;start with no override byte count
	mov	dh,byte ptr [PrefixBitmapWord]	;get prefix bitmap lo byte
	mov	bx,offset SegmentPfxBytes	;list of prefix bytes
	mov	cx,SEGPFXLISTSIZE		;there are 6 of these

sl2:
	shr	dh,1			;see if this one required
	jnc	nsl2			; no, skip
	mov	al,[bx]			; else load the prefix from the table
	stosb				; save it
	inc	dx			; increment prefix count
nsl2:
	inc	bx			; point to next prefix
	loop	sl2			; next prefix
	
	cmp	dl,2			;count of segment prefixes added
	jb	lpnerr			;can't exceed 1
	stc
	ret
lpnerr:
	clc
	ret
InsertPrefixes	ENDP
;
; routine displays error if operands are mismatched
;
; INPUT: none
; OUTPUT: message displayed
operr	PROC
	call	printAlignedErrorMsg
	db	"Unusable operand combination",0
	stc
	ret
operr	ENDP
segdwordreg PROC
        cmp     [arg3.mode],AM_NONE
        jnz     sdrx
        cmp     [arg1.mode],AM_REG
        jnz     sdrb
        cmp     [arg1.asize],DWORDSIZE
        jnz     sdrx
        cmp     [arg2.mode],AM_SEG
        ret
sdrb:
        cmp     [arg2.mode],AM_REG
        jnz     sdrx
        cmp     [arg2.asize],DWORDSIZE
        jnz     sdrx
        cmp     [arg1.mode],AM_SEG
sdrx:
        ret
segdwordreg ENDP
;
; check for size mismatches and get a size.
; INPUT: SI points to user's input buffer/
; OK, a little bit of clarification has happened on this one, thankfully.
;  Turns out that opcodes fall into several categories with respect to this
; routine. In general, for any opcode with more than one operand, all
; subsequent operands must match one another in size except for the
; exceptions. The exceptions to be permitted are:
;	1) movzx and movsx, which by definition have mismatched operands
;	2) In and Out instructions, where DX holds the port, and we can
;	   read or write any size operand through that port
;	3) SHR,SAR,SHL,SAL,RCR,RCL CL, since any size operand can be shifted 
;	   by CL bits
;	4) Immediate operands, which can be smaller but not larger than
;	   their targets
;	5) Memory, if sizes to any memory mode are given they must match
;	   the rest of the arguments.
;

validops	PROC
	cmp	lastbyte,"x" 		;if movzx or movsx
	je	vox			;then this is OK


;OK, the logic here is really hosed. What it is supposed to say is this:
;IF any operand is provided
;	IF more than one operand
;		IF all operands are not equal in size
;			IF not an allowed exception
;				THEN error
;			ELSE OK
;		ELSE OK
;	ELSE OK
;ELSE OK

;The problem here appears to be, immediates have size 0 unless they are
;prefixed with byte ptr, word ptr, etc.  So for example, any size operand
;can be stuck into [44], like AL, AX, or EAX.  Furthermore, it was a
;conscious design decision that mov al,FFFF is allowed as an editing
;function. That is, you can enter as many hex digits as you want, if
; the number is too big then digits on the left are truncated.  This
; allows changing the number without using the backspace key.


chsize:					; collect a size
	mov	al,arg1.asize		;see if first arg size is 0
	or	al,al			;used later, so load into AL
	jnz	szch			;if non0 size, more checking
	mov	al,arg2.asize		;else load up size of 2d arg
	or	al,al			;used again
	jnz	szch			;if non0, keep checking?
	mov	al,arg3.asize		;check size of final arg
	or	al,al
	jnz	szch			;if it has non0 size
        mov     al,WORDSIZE
	call	asm32BitMode
        jz      szndw
        mov     al,DWORDSIZE
szndw:
        jmp     finalsize
szch:
	test	arg1.asize,0FFh		;if arg1 has a size
	jz	noa1			;
	cmp	al,arg1.asize		;it must match the collected size
	jnz	absx			; or check for special cases
noa1:
	test	arg2.asize,0FFh		; if arg2 has a size
	jz	noa2			
	cmp	al,arg2.asize		; it must match the collected size
	jne	absx  			; or we check for special cases
noa2:	
;Near as I can tell, we get here if:
;1) Both arg1.asize and arg2.asize are 0 
;2) Either or both is nonzero but matches the collected size
;
;We have to check the arg3 byte, this is necessary for example in
; the 386 imul instruction.  If both arg1 and arg2 had no size this
; extra compare makes no difference as there won't be an arg3 and the
; size will have been initialized to zero
	test	arg3.asize,0FFh		; if arg3 has a size
	jz	finalsize
	cmp	al,arg3.asize		; it must match the collect size
	jne	absx			; or we check for special cases
finalsize:
	call	setsize			;set the size we found in all ops
	jmp	chimmsize		;chk immediates and based addressing
;
; get here on size mismatch, must check for special cases
;
absx:
        call    segdwordreg
        jz      vox
	mov	eax,dword ptr [EnteredMnemonic] ; get ASCII for mnemonic
	and	eax,0ffffffh
	cmp	eax,"tuo"		; out?
	je	vox			; yes, no size error
	cmp	ax,"ni"			; in?
	je	vox			; yes, no size error
	mov	di,offset arg2		; is arg2 cl?
	call	chkcl			;
	jz	vox                     ; yes, no size error
	mov	di,offset arg3		; is arg3 cl?
	call	chkcl
	jz	vox
	call	printAlignedErrorMsg	; otherwise print an error and get out
	db	"Bad size",0
	stc
vox:
	ret
;
; get here if we had an immediate, must check sizing
;
chimmsize:
     	mov	di,offset arg1
	call	immsize			;see if immediate that will fit
        jc      badimm                     ;nope, won't fit
	call	chkbase			;else chk for valid based addressing
        jc      badbase                     ;not valid
     	mov	di,offset arg2		;
	call	immsize			; see if immed that will fit
        jc      badimm                     ; nope, won't fit
	call	chkbase			; check for valid based mode
        jc      badbase                     ; not valid
     	mov	di,offset arg3
	call	immsize			; see if immed that will fit
        jc      badimm                     ; nope, won't fit
	call	chkbase			; check for valid based mode
        jc      badbase                     ; not valid
	ret
badimm:
        call    printAlignedErrorMsg
        db      "Immediate out of range",0
        stc
        ret
badbase:
        call    printAlignedErrorMsg
        db      "Invalid based addressing",0
        stc
        ret
validops	ENDP


;One of the allowed exceptions is a shift or rotate of a register exceeding
;8 bits by CL, which is 8 bits.  Here we check for that CL, and allow the
;exception if we find it
;INPUT: DI points to this structure
;OUTPUT: ZF if we found CL, NZ if we didn't

chkcl	PROC
	cmp	[di+asmop.mode],AM_REG	; check if register involved
	jne	cclerr			; if not, can't be CL
	cmp	arg2.areg1,isECX	; else see if ECX involved at all
	jne	cclerr			; if not, can't be CL
	cmp	arg2.asize,BYTESIZE	; if ECX is byte, must be CL
cclerr:
	ret
chkcl	ENDP


;INPUT: AL is an argument size 1=byte, 2=word, 4=dword
;	EnteredMnemonic is a bucket containing what the user typed
;	PrefixBitmapWord containing a bit for each type of prefix allowed.
;		AS_OPSIZE is for operand size override prefix OS:, which
;		means stick in a 66h
;	arg1,2, and 3 are instances of structure ASMOP. asize is the size
;		of the operand.  An instruction can have up to 3 operands
; What we do here is set the passed size as the size of all 3 operands,
; setting the 66 override if dword size (and not FP), and returning ZF
; if it was a dword, and NZ if it was not

setsize	PROC
	cmp	byte ptr [EnteredMnemonic],'f'	; floating point instruction?
	je	ssnoop				; yes, no opsize prefix
	cmp	al,DWORDSIZE			; is it a dword?
        jne     ssnoop2                          ; no, no opsize checking
	or	[PrefixBitmapWord],AS_OPSIZE	;include 'OS:' prefix
ssnoop2:
        cmp     al,WORDSIZE
        jne     ssnoop
        or      [PrefixBitmapWord],AS_OPSIZESET
ssnoop:
	mov	arg1.asize,al			;set all sizes the same
	mov	arg2.asize,al
	mov	arg3.asize,al
	cmp	arg1.asize,DWORDSIZE		;rtn NZ if NOT a dword
	clc
	ret
setsize	ENDP
;
; Check the size of an immediate
;
;INPUT: DI points to structure built for this instruction
;	AL contains size of first argument
;If immediate operand, make sure that the size of the argument passed in
;AL is valid. Apparently an immediate dword is always OK, but it is necessary
;in that case to set a bit indicating the operand size prefix, 
;Otherwise, in cases of byte or word, it is necessary to make sure that
;the target offset (or segment if seg:ofs) does not exceed the immediate
;value in size.  This is not nearly well enough understood to draw any
;conclusions yet.
;  My guess is that if we have something like mov eax, immediate, then any
;immediate is OK.  If it is mov ax, immediate, then the value to be moved in
;must be a byte or word. Finally, if mov al, immediate, then the immediate
;value must be a byte
;OUTPUT: NC if immediate operand will fit in target, CY if not.

immsize	PROC
	cmp	[di+asmop.mode],AM_IMM		;see if immediate value
	clc					;assume not
	jne	immok				;and if not, we're OK
	cmp	al,DWORDSIZE			;else chk for dword size
	jae	immokl				;go if AL >=4 (dword)
	cmp	al,WORDSIZE			;else if AL is word size
	clc					;assume it is
	jne	bytech				;if not, go chk byte offset
	test	[di+asmop.addrx],0ffff0000h	;else test for word offset
	jz	immok				;if so, we're ok
        cmp     [di+asmop.addrx],0ffff0000h
        ; flags set right at this point
immok:
	ret
immokl:
	or	[PrefixBitmapWord],AS_OPSIZE	;set this
	ret
bytech:
	test	[di+asmop.addrx],0ffffff00h	;test for byte offset
	jz	immok				;OK if byte
        cmp     [di+asmop.addrx],0ffffff00h
        ; flags set right at this point
	ret
immsize	ENDP

;
; subroutine to verify that a based/indexed mode has a correct
; register combination
;
; INPUT: DI = pointer to operand (asmop) structure
; OUPUT: CY set on error, clear if ok
;
chkbase	PROC
	cmp	[di+asmop.mode],AM_BASED	;is it base+something?
	jne	cbxnb				;if not, get out
	cmp	[di+asmop.msize],BYTEMODE	;see if byte-mode addressing
	je	cberr				;no can do this
	cmp	[di+asmop.msize],DWORDMODE	;how about dword?
	je	cb32				;go check 32-bit addressing
;
; if we get here we have 16-bit addressing.  No scale factors allowed.

	cmp	[di+asmop.ascale],TIMES1	;check scale factor against 1
	jne	cberr				;error if not 1
	cmp	[di+asmop.areg1],isESP		;check for sp
	je	cberr				;error if trying to index off sp

	cmp	[di+asmop.areg1],isEBX		;Carry clear if eax,ecx,edx
	jb	cberr				;error if trying to index off those

;areg2 is any second register (like [bx+si+nnnn]

	cmp	[di+asmop.areg2],0FFh		;any second register

;A table is emerging from the following.  It tells us:
;

	je	cbx				;didn't get to second base
	cmp	[di+asmop.areg2],isESP		;is 2d base ESP
	je	cberr				;if so, illegal
	cmp	[di+asmop.areg2],isEBX		;compare with EBX value
	jb	cberr				;error is ax,cx,dx
	cmp	[di+asmop.areg1],isESI		;compare with ESI
	jae	cbdown				;ok for  si,di
cbup:
	cmp	[di+asmop.areg2],isESI		; check second if si or di
	jae	cbx				; ok if so
	jmp	cberr				;err if anything else

;
; we got here if the first arg is si/di, in which case the second arg
; must be bx or bp

cbdown:
	cmp	[di+asmop.areg2],isESI		;if bx or bp
	jb	cbx				;we're OK

;Errors go here. By implication, these errors are:
;1) using ESP at all for a base register
;2) using EAX, ECX or EDX as a base register
;3) using a register combo other than [si + bx] [si + bp] [di + bx] [di+bp]

cberr:
	call	printAlignedErrorMsg
	db	"Invalid base or index register",0
	stc
	ret

;
; we get here if we have a 32-bit address mode with based addressing
;

cb32:
	test	[Disassemble32Bit],TRUE		;dwords allowed at all?
	jz	cberr				;if not, bomb
	or	[PrefixBitmapWord],AS_ADDRSIZE	;else set addrsize prefix
	cmp	[di+asmop.areg1],isEBP		;see if EBP is first reg
	jne	cb32n2bp			;skip if not
	cmp	[ di+asmop.areg2],isEBP		;else if second is EBP
	je	cberr				;that's an error
cb32n2bp:
	cmp	[di+asmop.areg2],isESP		;check for [exx + esp]
	jne	cbx				; if not, accept it
	cmp	[di+asmop.ascale],TIMES1	; else check for a scale factor
	jne	cberr				; error if not 1
cbx:
	push	ax
	mov	al,[di+asmop.areg1]

;
; now we have to figure out whether DS or SS is the default segment

	and	al,6		; turn ebp into esp
	cmp	al,isESP	; is esp or ebp?
	jne	cbx1		; no
	mov	DefaultSeg,2	; else default to sseg
cbx1:
	mov	al,[di+asmop.areg2]

	and	al,6            ; turn ebp into esp
	cmp	al,isESP	; is esp or ebp?
	jne	cbxnb		; no
	mov	DefaultSeg,2	; else default to sseg
cbxnb:
	pop	ax

	clc
	ret
chkbase	ENDP


; print out error message
; INPUT: The error message is embedded in the code immediately following the
;	call to printAlignedErrorMsg
;
; this allows 32 characters for the input string.  It tabs the error
; message over to 32 columns beyond the first column of input.  If the
; input took more than 32 characters the error message cannot be aligned
; and is just tagged right after the input.

printAlignedErrorMsg	proc
	mov	cx,0FFFFh	;search a segment worth
	mov	di,offset inputbuffer	;in buffer
	mov	al,13		;for a CR
	repne	scasb		;find it
	add	cx,32		; space to line up errs
	jcxz	nospace
	jns	ok
	mov	cx,1		;if can't align, use single space
ok:
	call	printspace
	loop	ok
nospace:
	PRINT_MESSAGE	"??? "
	jmp	PrintFollowingMessage
printAlignedErrorMsg	ENDP
;
; get the opcode and scan the tables for it
;
;
getcode	PROC
	mov	RepPfxBitmap,0	;No Reps/locks found
getcode3:
	mov	di,offset EnteredMnemonic	;point to mnemonic buffer
getcode2:
	lodsb			;get input character
	cmp	al,' '		;see if space or below
	jbe	nomore		;if so, done, don't store
	stosb			;else store it
	cmp	al,':'		;was it a colon?
	je	nomore2		;if so, ignore it and end the name
	jmp	getcode2
nomore:
	dec	si   	       	; all done, backtrack
nomore2:
	mov	ah,[di-1]      	;get last char we stuffed in buffer
	mov	[lastbyte],ah	; last byte is used by some commands
				; string &c
	mov	al,0		; store the trailer
	stosb
	push	si		;save where we left off in input string
	mov	si,offset EnteredMnemonic	;point to buffer we just stuffed
	call	strlen		; length of name in buffer into AX
	inc	ax		; plus trailer
	mov	si,offset EnteredMnemonic	; check for repeats and lock
	mov	di,offset say_repne	;actual string 'repne'
	mov	cx,ax		;length to compare
	repe	cmpsb		;see if a match, lowercase
        mov     bl,AF_REPNE      ;this is 2
	jz	reps		;if a match, go to reps to stuff in RepPfxBitmap
	mov	si,offset EnteredMnemonic	;else lets look for repe
	mov	di,offset say_repe
	mov	cx,ax
	repe	cmpsb
	mov	bl,AF_REPE	;this is 4
	jz	reps
	mov	si,offset EnteredMnemonic
	mov	di,offset say_rep	;just look for rep
	mov	cx,ax
	repe	cmpsb
	mov	bl,AF_REP	;this is 1
	jz	reps
	mov	si,offset EnteredMnemonic	
	mov	di,offset say_lock	;look for lock
	mov	cx,ax
	repe	cmpsb
	mov	bl,AF_LOCK	;this is 8
	jz	reps
	cmp	ax,4		;is the length 4 (including 0-terminator?)
	jnz	npf		;if not, go look it up
	cmp	[EnteredMnemonic+2],':'	;else maybe segment override, so check colon
	jne	npf		;not a colon, so go look it up
	mov	ax,word ptr [EnteredMnemonic]	;else, get 1st 2 chars in AX
	mov	di,offset OverridePfxList	;point to string of possible prefixes
	mov	cx,8		;there are 8, 2 of which I've never heard of
	repne	scasw		;see if any match
	jnz	npf		;if not, go look it up the hard way
	bts	[PrefixBitmapWord],cx	;set prefix word bit for this prefix
	pop	si		;back to our input line
	call	WadeSpace	;find next string
	jnz	getcode3	;got one, so start over
	stc			;else we failed???
	ret
npf:
	mov	si,offset EnteredMnemonic	;point to buffer containing instruction
	call	LookupOpName	;and go look it up
	pop	si		;restore SI ptr to next input
	jc	gcx		; get out if nonexistant
	call	WadeSpace	; see if any more...
	clc
gcx:
	ret
reps:
	pop	si		;restore pointer to input
	or	RepPfxBitmap,bl	;set bitmap for rep prefix found
	call	WadeSpace	;find next
	jnz	getcode3	;if more, parse that
	stc			;else invalid - something must follow rep
	ret
getcode	ENDP
;
; get an operand
;
; INPUT: DI points to asmop structure for this arg
;	SI points to input buffer past opcode string
; OUTPUT: CY if arg is invalid
; PROCESSING:
;	1) init asmop structure
;
parsearg	PROC
	mov	[di+asmop.asize],NOSIZE
	mov	[di+asmop.areg1],0FFh
	mov	[di+asmop.areg2],0FFh
	mov	[di+asmop.ascale],1
	mov	[di+asmop.addrx],0
	mov	[di+asmop.mode],AM_NONE
	mov	[di+asmop.msize],0
	call	wadespace      		;see if any more???
	clc
	jz	gax	 		; comma taken care of by wadespace
	cmp	byte ptr [si],'['	;see if opening an indirect addr
	je	getbrack		;if so, look for contents
        call    parsecontrol            ;else chk for control register
	jc	gax			;error, bad ctrl reg
	jz	gaxc			;good ctrol reg, we got it
	call	parsesize		;set width, 1-10
	jc	gax			;bad width, bomb
	jz	getbrack		;else found width, get inside bracket
	call	parseseg		;else check for segment arg
	jc	gax			;bad seg arg
	jz	gaxc			;if good one, find more
	js	getbrack		;if SF, seg is inside brackets
	call	parsereg		;so find register
	jz	gaxc			;got it, find mire
	mov	[di+asmop.mode],AM_NONE	;assume it is just a number
	call	parseval		;look for an immediate
	jc	gax			;nope, bomb
        jz      gri1
		or		dx,dx
        jz      gri1
		cmp		dx,[lastseg]
        jz      gria
        mov     [di.asmop.mode],AM_SEGOFFS
        mov     [di +asmop.addrx],ebx
		movzx	edx,dx
        mov     [di + asmop.addrx2],edx
        jmp     gaxc
gria:
        mov     [di+asmop.addrx],ebx
        mov     [di+asmop.mode],AM_IMM
        jmp     gaxc
gri1:
	mov	[di+asmop.mode],AM_IMM	;else say it is an immediate
	mov	[di+asmop.addrx],ebx	;so save that
	call	wadespace  		;find next
	cmp	al,':'			;a colon?
	jnz	gaxc			;if not, done
	inc	si			;else move past colon
	call	parseval		;and get target value
	jc	gax			;sorry, no value found
gri2:
	mov	[di+asmop.addrx2],ebx	;else stash the value in addrx2

;Aha, I think I dig. This flag indicates that addrx1 contains a segment
;value and addrx2 has the offset.  If this flag is clear, addrx1 has an
;offset and addrx2 is inoperative.

	mov	[di+asmop.mode],AM_SEGOFFS	;set flag
gaxc:
	call	WadeSpace
	clc
gax:
	ret

;Handle the case where we have something in brackets.
;SI points to the opening bracket character


getbrack:
        or      [PrefixBitmapWord],AS_ADDRSIZESET
	lodsb			;consume the bracket
	mov	al,[di+asmop.areg1] ;see if any segment reg
	cmp	al,0ffh
	jz	brklp		; none
	mov	[di + asmop.areg1],0ffh ; set it back
	sub	ah,ah
	bts	[PrefixBitmapWord],ax	; set the prefix bit
brklp:
	call	wadespace	;get next string
	jz	brackerr	;found CR before closing bracket
	cmp	al,'+'		;see if plus sign
	jne	brnp		;might mean bracket-not-plus
	inc	si		;else move past plus sign
	call	wadespace	;and find next
	jz	brackerr	;oops, no closing bracket

;We have ignored any plus sign if it was there

brnp:
	cmp	al,'-'		;is it a minus sign?
	je	brmem		;if so, must be a value?
	cmp	al,']'		;if not, closing bracket already?
	je	brackx		;if so, go exit
	push	di		;save pointer to buffer
	mov	di,offset arg4	;point to arg4 for base-mode reg gathering
	call	parsereg	;see if a register?
	pop	di		;restore buffer pointer

;parsereg cannot return CY, and does no bracket check anyway. No idea why 
;this line is even here

	jc	brackerr	; if invalid fp or CRDRTR reg num
	jz	brreg		;ZF means we found a register
brmem:
	call	parseval		;glom a number into EBX
	jc	brackerr		;get out if no number
	add	[di+asmop.addrx],ebx	;stick in as offset or segment
	call	WadeSpace		;get next
	jz	brackerr		;still no closing bracket
        cmp     al,']'
        jz      brackx
        cmp     al,'+'
        jz      brklp
        cmp     al,'-'
        jz      brklp
        jmp     brackerr

;We get here if we found a named register inside the brackets, like [bx

brreg:
	mov	[di+asmop.mode],AM_BASED	;say base reg involved
	mov	ah,[arg4.areg1]		;get which register it is
	mov	bl,[arg4.asize]		;and width of register
	test	[di+asmop.msize],0FFh	;see if anything assigned yet
	jz	notszyet		;nope, not yet
	cmp	[di+asmop.msize],bl	;ok, bl is the size
	jnz	brackerr		;mismatch, I guess???
notszyet:
	mov	[di+asmop.msize],bl	;else set the size
	call	WadeSpace
	cmp	al,'*'			;multiply operation
	jne	notscale		;nope, no scaling
	cmp	bl,DWORDSIZE		;else dword scaling?
	jne	brackerr		;must be dword reg for multiply?
	inc	si			;move past *
	call	WadeSpace		;find next
	sub	al,'0'			;last char returned, cvt to decimal?
	cmp	al,TIMES1		;*1 is OK
	je	brackok1
	cmp	al,TIMES2		;*2 is OK
	je	brackok1
	cmp	al,TIMES4		;*4 is OK
	je	brackok1
	cmp	al,TIMES8		;*8 is OK
	jne	brackerr		;else, can't do it
brackok1:
	inc	si			;bump SI past scaling factor
	mov	byte ptr [di+asmop.ascale],al	;and set factor in struct
reg2x:
	test	[di+asmop.areg2],0FFh	;initialized to FF
	jns	brackerr		;so bit 7 better be set
	mov	[di+asmop.areg2],ah	;if so stick areg1=reg into it
	jmp	brklp			;get next thing inside brackets

;Found a register that was NOT followed by a scaling factor. The magic code
;for the found register is in AH. We stick this register into areg1 unless
;areg1 is already in use, in which case we stick it in areg2.

notscale:
	test	[di+asmop.areg1],0FFh	;has reg been assigned yet?
	jns	reg2x			;if not, stick reg into areg2
	mov	[di+asmop.areg1],ah	;else, stick reg into areg1
	jmp	brklp

;OK, we found the closing bracket.  Presumably everything between brackets
;was kosher. We also get here with the construct [], with nothing in there.

brackx:
	cmp	[di+asmop.msize],DWORDMODE	;addressing mode size=32?
	jne	brackn32			;if not, skip
	or	[PrefixBitmapWord],AS_ADDRSIZE	;else set addrsize prefix flag
brackn32:
	inc	si				;move past ]
	cmp	[di+asmop.mode],AM_NONE		;see if empty
	Jne	gaxc				;if not, cool
	mov	[di+asmop.mode],AM_MEM		;else set mode to memory
	mov	[di+asmop.msize],WORDMODE	;see if word mode
	call	asm32BitMode
        jnz     brackmdword
        test    [di+asmop.addrx],NOT 0FFFFH     ;see if any address
        jz      gaxc                            ;if not, skip out
brackmdword:
	or	[PrefixBitmapWord],AS_ADDRSIZE	;else set for ???
	mov	[di+asmop.msize],DWORDMODE	;and say dword assumed??
	jmp	gaxc				;and jmp
brackerr:
	stc
	ret
parsearg	ENDP

; Parse possible control register reference
;
; INPUT: SI points to buffer containing this argument (a string)
; OUTPUT: For this arg, the mode and areg1 fields of the structure are
;	filled in.
;	NZ if we can't recognize the register
;	CY if index for register is out of range
; PROCESSING: Look for any control reg, debug reg, FP reg or TR reg. The
;	TR regs are the Appendix H test registers.
;		Beyond this, we allow up to 8 of each of the ST, CR and DR
;	even though there is no DR1 or DR2, nor any CR4,5,6 or 7. I guess
;	these exist in opcode space, just not in the CPU!
;
parsecontrol	PROC
	mov	ax,word ptr [si]
	mov	cl,AM_CR
	cmp	ax,"rc"			;Control register CRx
	je	gotcontrol
	mov	cl,AM_DR
	cmp	ax,"rd"			;Debug register DRx
	je	gotcontrol
	mov	cl,AM_TR
	cmp	ax,"rt"			;Test registers, Appendix H
	je	gotcontrol
        mov     cl,AM_MMX
        cmp     ax,"mm"
        je      gotcontrol
	cmp	ax,"ts"			;ST(x for FP
	je	gotfpreg
	or	al,1
	ret

;Um. There are 8 each of the debug registers and FP stack registers, although
;DR1 and DR2 don't exist.  There are only 4 control registers, and I can't
;find any reference at all to any TRx registers.


gotcontrol:
	lodsw				;grab control reg 1st 2 chars
	lodsb				;and number
	sub	al,'0'			;convert to binary
	jc	gcerrx			;oops, below 0
	cmp	al,8			;see if register 8 or above
	jae	gcerrx			;error if so
	mov	[di+asmop.areg1],al	;save which one
        mov     al,[si]
        and     al,0dfh                 ; make uc
        cmp     al,'0'
        jc      gcg
        cmp     al,'9'
        jbe     gcerrx
        cmp     al,'@'
        jc      gcg
        cmp     al,'Z'
        jbe     gcerrx
        cmp     al,'_'
        je      gcerrx
gcg:
	mov	[di+asmop.mode],cl	;save CL 
	sub	ax,ax			;set ZF
	ret
gcerrx:
        sub     si,3
        or      al,1
        ret
gotfpreg:
        push    si
	lodsw				;consume the 'ST'
	call	wadespace		;find next 
	cmp	al,'('			;is it (
	jne	asmgotch		;if not, check for NASM syntax
	inc	si			;bump past (
	call	wadespace		;find next
	push	ax			;stack the char found
	inc	si			;move past it
	call	wadespace		;find the next
	cmp	al,')'			;end of stack reference?
	pop	ax			;restore char between ()
	jne	badfpreg		;no close, so bitch

;We get here in two cases: we found (x), or we didn't find (
;In the first case, x is in AL, in the second, AL has what we found instead
;By implication, we accept either ST(x) or STx

asmgotch:
	sub	al,'0'			;convert to binary
	jc	badfpreg		;must be some number
	cmp	al,8			;else see if in range
	jae	badfpreg		;if >=8, out of range
	inc	si			;move to next position anyway
	mov	[di+asmop.mode],AM_FPREG	;set flag for FP
	mov	[di+asmop.areg1],al	;save binary value of this reg
        add     sp,2
	sub	ax,ax			;and return ZF
	ret
badfpreg:
        pop     si
        or      al,1
	ret
parsecontrol	ENDP


;
; parse a size attribute.  the PTR keyword is optional.
;
; INPUT: SI points to buffer containing this argument (a string)
; OUTPUT: bl has size
;         CY set if error ins size
parsesize	PROC
        mov     [farptr],0
chkfar:
	push	si			;else look for 'ptr'
	push	di
	mov	cx,3
        mov     di,offset say_far
	repe	cmpsb
	pop	di
	pop	si
        jnz     fardone                    ;if not, we're ok
        or      [farptr],1              ; far keyword
	add	si,3			;else skip wasted 'ptr'
        call    wadespace
        jz      operrx
        cmp     al,'['
        je      opok
fardone:
	mov	ax,[PrefixBitmapWord]	;get bitmap into AX
	call	isbyte			;chk buffer for 'byte'
	mov	bl,BYTESIZE		;assume byte size
	jz	gotsize			;if match, fine
	call	isword			;else chk for word
	mov	bl,WORDSIZE		;assume it was
	jz	gotsize			;if so, fine
	inc	si			;go past first char (could be t)
	call	isbyte			;and check if it was 'tbyte'
	jnz	notbyte			;if not, really not a byte
	cmp	byte ptr [si-1],'t'	;else, was it a t
	mov	bl,TBYTESIZE		;assume it was a tbyte
	jz	gotsize			;yes, it was
        cmp     byte ptr [si-1],'p'     ; else, was it a p
        mov     bl,PBYTESIZE
        jz      gotsize
	or	bl,bl			;else return NZ
	ret

;OK, it's not 'byte', 'word' or 'tbyte'. Maybe it's 'dword'. To get here,
;SI has been moved past the first char, so see if it is dword, qword'or fword

notbyte:
	call	isword			;check for xword
	jnz	notsize			;nope, not it
	mov	al,[si-1]		;else get that x
	cmp	al,'d'			;was it dword
	mov	bl,DWORDSIZE		;assume it was
	je	gotsize			;yep, got it
	cmp	al,'q'			;was it qword
	mov	bl,QWORDSIZE		;assume it was
	je	gotsize			;yep, that's it
	cmp	al,'f'			;how about fword
	mov	bl,FWORDSIZE		;assume that
	je	gotsize			;yes
notsize:
	dec	si			;back to beginning of string
	or	bl,1			;set NZ
	ret
gotsize:
	mov	[di+asmop.asize],bl	;set requested size
	add	si,4			;move past string in buffer

;By implication here, it is legal to type 'ptr' as many times as you want.
;You can say mov word ptr ptr ptr ptr ptr [44],5

gs2:
	call	wadespace		;find next nonspace
	jz	operrx			;didn't find, so error
	cmp	al,'['			;'ptr' is optional, so chk bracket
	je	opok			;if so, fine
	push	si			;else look for 'ptr'
	push	di
	mov	cx,3
	mov	di,offset say_ptr
	repe	cmpsb
	pop	di
	pop	si
        clc
        jnz     opok                    ;if not, we're ok
	add	si,3			;else skip wasted 'ptr'
	jmp	gs2			;
operrx:
	stc
opok:
	ret
parsesize	ENDP

; compare input string with 'byte'
;
; INPUT: SI points to buffer containing this argument (a string)
; OUTPUT: ZF if the argument is 'byte' NZ otherwise
; PROCESSING: Simply compare
; NOTE: AX must be preserved
;
isbyte 	PROC
	push	si
	push	di
	mov	cx,4
	mov	di, offset say_byte
	repe	cmpsb
	pop	di
	pop	si
	ret
isbyte	endp
;
; compare input string with 'word'
;
; INPUT: SI points to buffer containing this argument (a string)
; OUTPUT: ZF if we matched 'word', else NZ
; PROCESSING: just compare
;	AX cannot be modified
;
isword 	PROC
	push	si
	push	di
	mov	cx,4
	mov	di, offset say_word
	repe	cmpsb
	pop	di
	pop	si
	ret
isword	endp

;
; INPUT: SI points to buffer containing this argument (a string)
; OUTPUT: CY if bad segment argument
;	ZF if good segment argument on its own
;		In this case, mode and size are set
;	SF if valid segment is followed by [
; PROCESSING: 
;	1) See if string matches list of seg names, return NZ if not
;	2) See if segment is only arg (like mov ax,cs. If so, return ZF
;	3) Else, see if it is seg:[ and if so, return SF
;	4) Else return carry, bad segment argument
;
parseseg	PROC
                                        ; the following screens out ESP and ESI
        mov     al,byte ptr [si+2]      ; get third char
        and     al,0dfh                 ; make upper case
        cmp     al,'@'                  ; is it a letter
        jc      pssearch                ; no, do search for seg
        cmp     al,'Z'                  ; ?
        jbe     noseg                   ; yes no seg
pssearch:
        cmp     al,'0'
        jc      pssearch2
        cmp     al,'9'
        jbe      noseg
pssearch2:
        cmp     al,'_'
        jz      noseg
        cmp     byte ptr [si+2],'i'
        jz      noseg
	mov	cx,6	  		;6 possible segments by name
	push	di			;save ptr to struct
	mov	di,offset psegs		;names of registers
	lodsw				;get what user entered
	repne	scasw			;find it in the strings list
	pop	di			;restore struct ptr
	jz	gotseg			;found a match
	sub	si,2			;not a seg, undo the lodsw
noseg:                          
        or      si,si
	ret				;return NZ

;Here we have a significant departure from debug.exe syntax.  If you want
;a segment override in debug, you must put the override like CS: or ES:
;on a separate line, and the remainder on the next line.  Debug requires you
;to say:
;xxxx:xxxx cs:
;xxxx:xxxx mov al,[44]
;
;Here you are NOT allowed to do this.  Instead, you must enter:
;xxxx:xxxx mov al,cs:[44]
;
;an earlier part of the program also accepted:
;
;xxxx:xxxx cs:mov al,[44]
;

gotseg:
	sub	cx,6			;sub starting value
	not	cx			;convert to index
	mov	[di+asmop.areg1],cl	;save that index in areg1
	call	wadespace		;find next non-0
	jz	segalone		;if nothing, fine, just seg
	cmp	al,':'			;else chk for colon
	jne	segalone		;if not, we just got the segment
	inc	si			;bump past colon
	call	wadespace		;find next stuff
	jz	segerr			;nothing else is error
	cmp	al,'['	 		;do we have a fixed address next?
	jne	segerr			;if not, real trouble
	or	al,80h			;else return SF
	ret
segalone:
	mov	[di+asmop.mode],AM_SEG	;say mode is just a segment
	mov	[di+asmop.asize],WORDSIZE	;so size is 2 (all segregs are word)
	sub	ax,ax			;return ZF
	ret
segerr:
	stc				;error so return CY
	ret
parseseg	ENDP

;
; parse a register name
;
; INPUT: SI points to input being parsed
;	DI points to structure for this argument, or to arg4 if we are
;	inside brackets.
; OUTPUT: ZF if reg found, and mode and size set
;	NZ if not a name
; PROCESSING: parse for all register names, set size and mode if found any,
;	else return NZ if not found
;NOTES:
;	1) If a register name was found, SI was bumped past it, else SI
;	   remained unmodified
;	2) At least one caller to this routine checks the carry. I can't
;	   find anything in here that would set or clear the carry as a
;	   return value...	
;
parsereg	PROC
	mov	bl,2			;set word size
	cmp	byte ptr [si],'e'	;is first char an e
	jne	nextreg			;if not, fine
	mov	bl,4			;else set dword size
	inc	si			;and move past the e
nextreg:
        mov     al,[si+2]
        and     al,0dfh                 ; make upper case
        cmp     al,'@'                  ; is it a letter
        jc      prnum                   ; no, do search for seg
        cmp     al,'Z'                  ; ?
        jbe     noreg                   ; yes no seg
prnum:
        cmp     al,'0'
        jc      prnum2
        cmp     al,'9'
        jbe      noreg
prnum2:
        cmp     al,'_'
        jz      noreg
nextreg3:
	lodsw				;get next 2 bytes
	mov	cx,16			;there are 16 2-char strings for regs
	push	di			;save di
        mov     di,offset regs          ;oto scan list of reg names
	repne	scasw
	pop	di
	jz	gotreg			;if ZF, we hit a match
	sub	si,2			;else back to beginning of input
noreg:
	cmp	bl,4			;unless we moved past an e
	jnz	nextreg2		;if bl=4, we did
	dec	si			;so back up to first char
nextreg2:
	or	si,si			;set NZ
	ret				;since not a reg

;It just so happens that the regs string has 16 2-char entries, the first 8
;are byte registers and the last 8 are word registers

gotreg:
        xor     cl,15                   ;really, how about 0Fh?
	mov	[di+asmop.asize],BYTESIZE	;say byte arg
	cmp	cx,8			;if found in positions 0-7
	jb	gr1			;then it was a byte
	mov	[di+asmop.asize],bl	;else word or dword depending on e
gr1:
	and	cl,7		   	;get mod8 for index
	mov	[di+asmop.areg1],cl	;and save that
	mov	[di+asmop.mode],AM_REG	;say a reg asked for by name
	sub	ax,ax			;return ZF
	ret
	
parsereg	ENDP
;
; Make sure that the next string is a number, and return in EBX if so
;
; INPUT: SI points to string to be parsed
; OUTPUT: NC if we find a number
;	EBX contains that number (0=extended if required)
;	CY if not a number, or not found???
; PROCESSING: DI points to the argument structure being built, and must
;	be preserved.
;NOTES: ReadNumber simply assumes that all bytes in the input buffer are
;	hex values up to some special character like space, comma, colon
;	or CR. So ReadNumber cannot return an error. In this case, we
;	already know that we have no named register at [si], which is
;	a good thing, because if we did, ReadNumber would return the
;	current contents of that logical register.
;
parseval	PROC
	call	wadespace	;find arg string
	jz	noval		;oops, not there
        push    si
        push    di
        call    symReadName
        push    es
        push    ecx
        push    si
        mov     si,offset dgroup:symname
        call    symLookupByName
        pop     si
        pop     ecx
        jc      ranosym
        mov     dx,word ptr es:[di+4] ; EBX has seg: offset
        mov     ebx,dword ptr es:[di]
		call	bit32Address
		jnz		is321
		movzx	ebx,bx
is321:
        pop     es
        pop     di
        add     sp,2 ; get rid of old si, also NZ means it was a symbol
        ret
ranosym:
        pop     es
        pop     di
        pop     si
        
	push	di		;else save location
	call	ReadNumber	;read a number into eax
	pop	di		;restore pointer
	mov	ebx,eax		;return number in ebx
;	call	bit32Address
;	jnz		is322
;	movzx	ebx,bx
is322:
        sub     eax,eax         ;ZR means it was a number
	ret
noval:
	stc
	ret
parseval	ENDP
end