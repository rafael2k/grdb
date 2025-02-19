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
;
; Input.asm
;
; Function: Handle input
;
;   Handles numbers
;   Handles segments
;   Handles trapping page faults
;   Handles command input
;
	;MASM MODE
	.model small
	.386

include  edispatc.inc 
include  eprints.inc 
include  emtrap.inc 
include  eregs.inc 
include  edump.inc 
include  eentry.inc 
include  eexec.inc 
include  ebreaks.inc 
include  edis.inc 
include  einout.inc
include  eoptions.inc
include  ehistory.inc
include  elogging.inc
include  esymbol.inc
include ainput.inc
include edpmi.inc
include eansi.inc
	extrn _exit : PROC,domath : PROC, drive : PROC, fill : PROC
	extrn logging : PROC, help : PROC, pci : PROC
	extrn DoFileRead : PROC, DoFileWrite : PROC, search : PROC
	extrn fpcommand : PROC, move : proc, compare : proc, asm : PROC
        extrn w_swapscreen : PROC, infs : BYTE, optfs: byte
        extrn w_cmdset : PROC, fullcmd : BYTE
        extrn DisplayRegisters : PROC, redump : PROC, rediss : PROC
        extrn slash : PROC
        extrn mathsub : PROC, mathoper : PROC
		
	PUBLIC	qerr, ReadNumber, ReadAddress, Inputhandler
	PUBLIC	wadeSpace, GetInputLine, WadeSpaceOnly, inputbuffer
        PUBLIC  defDS,defCS, EraseLine, PutLine, EndOfLine
        PUBLIC  ReadNumberLL, crlfcount, crlfPause, optionWriteFlag

	.data

inputbuffer db  IBSIZE+1 DUP (?)                  ;Allocate Input buffer
Commands db     "abcdefghilmnopqrstuwxy@?/$"      ; List of commands
comlen	= $ - Commands				; Length of list
insert  db      0
lastcmd db      0
crlfcount       db      0
optionWriteFlag	db		0
	.code
crlfPause PROC
        call    crlf
        inc     crlfcount 
        push    es
        mov     ax,40h
        mov     es,ax
        mov     al,es:[84h]
        pop     es
        dec     al
ifndef NOFS
        test    [optfs],255
        jz      nofsx2
        sub     al,2
nofsx2:
endif    
        cmp     crlfcount,al
        jb      nopause
        mov     crlfcount,1
        pushad
        print_message <13,10,"Press any key to continue",13,10>
        call    AnsiGetKey
        popad
nopause:
        ret
crlfPause ENDP
;
; load defaults if dx is zero
; INPUT: EDX contains segment to use if not 0, OR if big real with offset 0
; OUTPUT: DX contains segment to use, could be default DX from bucket
;
defDS	PROC
	or	edx,edx		;if edx has a value
	jnz	ddsx		;then use it
	sub	dx,dx		; waste one instruction
	test	[optflat0],1	;see if default seg is 0
	jnz	ddsx		;if so, use EDX=0
	mov	dx,[RegdumpDS]	;else use default DS
	ret
ddsx:
	or	dx,dx
	jnz	ddsx2
	push ax
	call compatibleZeroPage
	mov	dx,ax
	pop ax
ddsx2:
	ret
defDS	ENDP
;
; for now we just default CS to the active CS, since it is only
; used on U and A commands and since we can't do linear addressing
; with those anyway right now. ???is this true???
;	If EDX <> 0, we are starting from a specified segment location,
; so use that instead of CS. (EDX contains the segment).
;
defCS	PROC
	or	edx,edx
	jnz	dcsx
	mov	dx,[RegdumpCS]
	ret
dcsx:
	or	dx,dx
	jnz	dcsx2
	push ax
	call compatibleZeroPage
	mov	dx,ax
	pop ax
dcsx2:
	ret
defCS	ENDP
;
; Print an error if command wrong
;	Apparently, SI points to some location in the input buffer. We
; need to determine how many spaces to print before we found the actual
; error to point to from the line below. I guess if the error is in the
; first or second positions, we print the character right at the start of
; the line, else we space over to where the error is found.
;
qerr	PROC	
	call	crlf			;new line for this
	sub	si,offset inputbuffer-2	; Calculate error pos
	mov	cx,si			;
	jcxz	short qestart		;
	dec	cx			;
	jcxz	short qestart		;
qelp:					
	call	printspace              ; Space over to error pos
     	loop	qelp
qestart:
	mov	dl,'^'			; Display error
	call	PutChar
	stc				; Did an error
	ret	
qerr	ENDP	
;
; Read in a number.
;  In at least some cases, we have ALREADY called ReadReg to find a register,
;and failed so we are looking for a number anyway.
;	SI points to the input line from the user.
; OUTPUT: CY if we found 0 digits and did NOT find a register by name
;	EAX contains number found if NC
;
ReadNumberLL      PROC    
	push	ebx
        push    cx
	push	dx
	call	ReadReg			;find a non-number (mnemonic)
	clc				;ignore which type or reg found
	jz	gotnum			;if 0, we have value of this reg

;We reach here if we found no mnemonic in our lookup table

	sub	ebx,ebx			; Number = 0
	sub	cx,cx			; digits = 0
	mov	al,[si]			;get next user character
	cmp	al,"'"			;if single or double quotes
	jz	getstring		;get a string input
	cmp	al,'"'
	jz	getstring
	cmp	al,'-'			;if a hyphen
	pushf				;save result of compare
	jnz	rnlp			;not a hyphen, so SI is ok
	inc	si			;else skip the hyphen
rnlp:
	lodsb				; Get char & convert to uppercase
	cmp	al,60h
	jc	notlower
	and	al,NOT 20h
notlower:
	sub	al,'0'    		; Convert to binary
	jc	short rn_done		; < '0' is an error
	cmp	al,10			; See if is a digit
	jc	short gotdigit		; Yes, got it
	sub	al,7			; Convert letters to binary
	cmp	al,16			; Make sure is < 'G'
	jnc	short rn_done		; Quit if not
	cmp	al,10			; MAke sure not < 'A'
	jc	short rn_done
gotdigit:
	shl	ebx,4			; It is a hex digit, add in
	or	bl,al			; OR in the digit
	inc	cx			; Set flag to indicate we got digits
	jmp	rnlp			; go get the next digit

;We have snagged all entered digits here, and in the process SI got bumped
;past the non-digit by lodsb, so back up to look at the first non-digit
;character. the Zero flag contains the result of our hyphen compare, ZF if
;we found a hyphen, NZ if we didn't.
;  NOTE also that if we found a string, EBX has up to 4 ASCII codes in it,
;NOT a value. Don't offhand see any way the caller can know this, though.

rn_done:
	dec	si			; Point at first non-digit
	popf			   	;did we find a hyphen?
	jnz	rm_done2		; check for negation
	neg	ebx			;yes, negative, so negate value
rm_done2:
	mov	eax,ebx			;final result into EAX
	test	cl,-1			; See if got any CX=digit count
	jnz	gotnum			;if non-0, we got at least one
	stc				; No, error
gotnum:
	pop	dx
	pop	cx
	pop	ebx
	ret				;return number/string in EAX

;We found a quote character at [SI], so we move past the quote to try to
;snag a quoted string. We keep sticking ASCII codes into EBX, shifting it
;left as we go, and losing all but the last 4 ASCII codes.

getstring:
	inc si				;bump past quote character
getstringl:
	lodsb				;get next char
	cmp	al,13			;if CR, end of input
	jz	rm_done2		;so leave SI alone?
	cmp	al,"'"			;find end of quotes already?
	jz	rm_done2		;if so, check if null string
	cmp	al,'"'
	jz	rm_done2
	inc	cl    			;else we got a char
	shl	ebx,8			;stick in BL
	mov	bl,al
	jmp	getstringl		;and get the next one
ReadNumberLL      ENDP    

ReadNumber PROC
        push    ebx
        push    ecx
        call    ReadNumberLL            ; get a real number
        jc      rnx
ReadNumberMath:
        mov     ecx,eax                 ; first operand in CX
        call    WadeSpace               ; get next char
        jz      rnx2
        call    mathoper                ; is it a math operator?
        jnc     rnf
        clc
rnx2:
        mov     eax,ecx                 ; no, return the number we got
rnx:
        pop     ecx
        pop     ebx
        ret
rnf:
        inc     si                      ; math oper - bump past operator
        call    WadeSpace
        stc
        jz      rnx
        call    ReadNumberLL            ; read second arg
        jc      rnx
        xchg    eax,ecx                 ; get args in right order
        call    mathsub                 ; do the math operation
        clc                             ; value is in EAX now
        jmp     ReadNumberMath
ReadNumber ENDP
;
; Read an address, composed of a number and a possible selector
; INPUT: SI points at the input line just following the U (for unassemble).
; OUTPUT: EBX contains the address, which came either from a current
;	register bucket or from a string or number
;
ReadAddress	PROC	
        push    si
        push    di
        call    symReadName
        push    es
        push    ecx
        push    si
        mov     si,offset symname
        call    symLookupByName
        pop     si
        pop     ecx
        jc      ranosym
        mov	    eax,dword ptr es:[di]
		call	bit32Address
		jnz		ra132
		movzx	eax,ax
ra132:
        mov     dx,es:[di+4]
        pop     es
        pop     di
        add     sp,2
        push    offset fin
        push    ebx
        push    ecx
        jmp     ReadNumberMath
fin:
        mov     ebx,eax
        jmp     gotaddr
ranosym:
        pop     es
        pop     di
        pop     si
rajoin:
        push    si
	sub	edx,edx			;EDX used for segment if found
	call	ReadReg			;chk for seg or non-seg register
					; mnemonic (like 'AX')

;ReadReg returns two flags: if NZ, we found nothing. if ZF, we found either
;a segment register or a non-segment register, so we examine the carry flag.
;CY means it was a non-segment register, and NC means we found a segment
;register.
;  If we found a register at all, the value returned is what was in the
;Regdump bucket for that register, and is returned in EAX unless it was not a
;32-bit register, in which case the low word is returned in AX and the high
;word of AX is zero. (undefined for segments)

	jnc	gotseg			;if NC, we snagged a segment reg
        pop     si

;We fall through here if we failed to find a register. The syntax from the
;user permits either REG:number, REG:REG, number:REG, number:number, or just 
;number. At this point, no register was asked for by name, so we check for a 
;number.

readseg:
	call	ReadNumber              ; Read a number or string
	jc	short raerr		; Quit if error - no input
	mov	ebx,eax			;move number/string to EBX
	call	WadeSpace		;find next input
	jz	gotaddr			;if no more, we're done
	cmp	al,':'			;if not a colon
	jnz	gotaddr			;we are also done
	inc	si			;else move past colon

;	We fell through above because the user did NOT ask for any
;register by name, then fell through to here because we found a colon after
;a number or quoted string.
;EBX now contains a number of up to the last 8 digits entered, or a string
;of up to the last 4 ASCII characters entered.  We take the low 4 digits or
;two characters and put them in DX, then set bit 16 of EDX

	mov	dx,bx			;low order num/string to DX
	or	edx,10000H		;set bit 16 for segment
	jmp	readofs			;and go read an offset

;EAX contains the value read out of the RegdumpREG bucket, with the high
;order word zeroed out.

gotseg:
        add     sp,2
        push    offset gsr
        push    ebx
        push    ecx
        jmp     ReadNumberMath
gsr:
	sub	ebx,ebx			;assume seg only, so offset is 0
	mov	dx,ax			;get segment value into DX
	or	edx,10000H		;set bit 16 for segment
	call	WadeSpace		;look for more input
	jz	gotaddr			;if no more, segment given only
	cmp	al,':'			;else see if colon for offset
	jnz	gotaddr			;if not, that's it
	inc	si			;else move past colon

;We get here if the input contained a colon, indicating that there might
;be an offset following.  If nothing follows the colon, assume an offset
;of 0.

readofs:
	call	WadeSpace		;any further input
	jz	gotaddr			;ZF means we found a CR
        push    edx
	call	ReadNumber		; Read in offset
        pop     edx
	jc	short raerr		; Quit if error - no number or
					; quoted string with endquotes
	mov	ebx,eax			;else set offset into EBX
gotaddr:
	call	bit32Address
	jnz		rafin
	movzx	ebx,bx
rafin:
	clc				; OK, exit
	ret
raerr:
	stc				; Error on number input
	ret
ReadAddress	ENDP	
;
; put a line to the screen
;
PutLine proc
		call	StartOfLine
        mov     si,offset InputBuffer
        mov     cx,IBSIZE
pllp:
        lodsb
		or		al,al
		jz		plx
        mov     dl,al
        call    PutChar
		inc		di
		jmp		pllp
plx:
		mov		si, di
        mov     dl,' '
        call    PutChar
		inc		di
		call	LeftArr
        ret
PutLine endp
inquote PROC
        push    ax
        mov     si,offset InputBuffer
offquote:
        sub     bx,bx
iql:
        lodsb
        or      al,al
        jz      iqx
        cmp     si,di
        ja      iqx
        cmp     al,bh
        jz      offquote
        cmp     al,'"'
        jz      onquote
        cmp     al,"'"
        jnz     iql
onquote:
        test    bh,bh
        jnz     iql
        mov     bh,al
        inc     bx
        jmp     iql
iqx:
        or      bl,bl
        pop     ax
        ret
inquote ENDP
StartOfLine PROC
		cmp		di,offset InputBuffer
		jz		solx
		call	LeftArr
		jmp		StartOfLine
solx:
		ret
StartOfLine ENDP
EndOfLine PROC
		test	byte ptr [di], 0ffh
		jz		eolx
		call	RightArr
		jmp		EndOfLine
eolx:
        ret
EndOfLine ENDP
RightArr PROC
		test	byte ptr [di],0ffh
		jz		raxx
		inc		di
		call	isansimode
		jnc		rana
		call	ansiright
		ret
rana:
		push	di
		call	getcurpos
		inc		dl
		call	setcurpos
		pop		di
raxx:
		ret
RightArr ENDP
LeftArr PROC
		cmp		di, offset InputBuffer
		jz		rlxx
		dec		di
		call	isansimode
		jnc		lana
		call	ansileft
		ret
lana:
		push	di
		call	getcurpos
		dec		dl
		call	setcurpos
		pop		di
rlxx:
		ret
LeftArr ENDP
WipeLine PROC
		cmp		byte ptr [di], 0
		jz		wlx
		mov		dl,' '
		call	PutChar
		inc		di
		jmp		WipeLine
wlx:
		ret
WipeLine ENDP
EraseLine PROC
        pushf
		call	StartOfLine
		call	WipeLine
		call	StartOfLine
        popf    
        jnc      noclear
        mov     cx,IBSIZE+1
        sub     al,al
        push    di
        rep     stosb
        pop     di
noclear:
        ret
EraseLine ENDP
DelChar PROC
		test byte ptr [di], 0ffh
		jz	dcx
		cld
		mov		cx,di
		mov		si,di
		inc		si
		push	cx
dcl:
		lodsb
		or		al,al
		jz		dclx
		stosb
		mov		dl,al
		call	PutChar
		jmp		dcl
dclx:
		stosb
		mov		dl,' '
		call	PutChar
		pop		cx
		sub		cx,di
		neg		cx
dcl2:
		push	cx
		call	LeftArr
		pop		cx
		loop	dcl2
dcx:
		ret
DelChar ENDP
InsertChar PROC
		push	ax
		mov		si,di
icl1:
		lodsb
		or		al,al
		jnz		icl1
		dec		si
		cmp		si, offset InputBuffer + IBSIZE
		jnc		icerr
		pop		dx
		push	dx
		call	PutChar
		mov		cx,si
		sub		cx,di
		jcxz	icnb
		mov		si,di
		push	cx
icl2:
		lodsb
		mov		dl,al
		call	PutChar
		inc		di
		Loop	icl2
		pop		cx
		push	cx
icl3:
		push	cx
		call	LeftArr
		pop		cx
		loop	icl3
		pop		cx
icnb:
		inc		cx
		push	di
		mov		di,si
		inc		di
		std
		rep		movsb
		cld
		pop		di
		pop		ax
		mov		[di],al
		inc		di
		clc
		ret

icerr:
		pop		ax
		cmc
		ret
InsertChar ENDP
OverwriteChar PROC
		cmp	di, offset InputBuffer + IBSIZE
		jnc		ocerr
		test	byte ptr [di], 0ffh
		jnz		ocnnull
		mov 	byte ptr [di+1], 0
		stosb
		mov		dl,al
		call	PutChar
ocnnull:
		clc		
		ret
ocerr:
		cmc
		ret
OverwriteChar ENDP
;
; Get an input line
; OUTPUT: SI points to the line of input.
;
GetInputLine	PROC	
        mov     [insert],1
        call    underlinecurs
        call    logoff
		mov		di, offset InputBuffer
Escape:
        mov     [cmdchanged],1
        stc
        call    EraseLine
moreinput:
	call	AnsiGetKey			;wait, return keystroke
	mov		si,offset InputBuffer
	call	CheckHistory		;check for history substitutions
	jc	MoreInput		;and go for more input if so
ifndef NOFS
        test    [optfs],255
        jz      gil_nofs
        cmp     ax,3F00h                ; F5 key
        jnz     gil_fscont
        push    di
        mov     al,[infs]               ; show output screen
        push    ax
        xor     al,1
        call    w_swapscreen
        call    AnsiGetKey
        pop     ax
        call    w_swapscreen
        pop     di
        jmp     moreinput
cmdwnd:
        mov     al,[fullcmd]            ; CTRL-F5
        xor     al,1
        push    di
        call    w_cmdset
        test    [fullcmd],1
        jnz     norereg
        call    DisplayRegisters
        call    rediss
        call    redump
norereg:
        pop     di
        jmp     moreinput
gil_fscont:
        cmp     ax,6200h                ; CTRL-F5
        jz      cmdwnd
gil_nofs:
endif
        cmp     ax,4b00h                ; left key
        jz      left
        cmp     ax,4d00h                ; right key
        jz      right
        cmp     ax,5300h                ; del key
        jz      delspc
        cmp     ax,4700h                ; home key
        jz      home
        cmp     ax,4f00h                ; end key
        jz      doend
        cmp     ax,5200h                ; insert key
        jz      toginsert
	or	al,al   		; ignore function keys
	jz	moreinput		; 
        cmp     al,27                   ; esc - delete contents of line
        jz      escape
	cmp	al,9			; is tab?
	jz	dotab
	cmp	al,8			; Is delete or rubout?
        jz      short bkspc             ; Yes - go do it
	cmp	al,7fh			;not on PC?
	jz	short bkspc		; yes - go do it
	cmp	al,13			; Is CR
	jz	short endinput		; Yes, return
	push	ax			;save keystroke
        call    inquote
        jnz     nolc                    ;if so, OK
	cmp	al,'A'			;see if below A
	jc	nolc
	cmp	al,'Z'			;or above Z
	ja	nolc
	or	al,20h			;if A-Z, force lowercase
nolc:
        mov     [cmdchanged],1
        test    [insert],1
        jz      overwrite
		pop		ax
		call	InsertChar
		jc		endinput
		jmp		moreinput
overwrite:
		pop		ax
		call	OverwriteChar
		jnc		moreinput
endinput:
        clc
        call    logon
        call    EndOfLine
        mov     al,13
        stosb
		mov		si,offset InputBuffer
        call    EnterHistory
		ret
toginsert:
        xor     [insert],1
        jnz     ulcurs
        call    blockcurs
        jmp     moreinput
ulcurs:
        call    underlinecurs
        jmp     moreinput
home:
		call	StartOfLine
        jmp     moreinput
doend:
        call    EndOfLine
        jmp     moreinput
bkspc:
        cmp     di,offset InputBuffer
        jz      moreinput
		call	LeftArr
delspc:
        mov     [cmdchanged],1
		call	DelChar
        jmp     moreinput
dotab:
        mov     [cmdchanged],1
	push	cx
	mov	cx,di			; cx = current pos
	sub	cx,si			; Minus start pos
	add	cl,7			; now it equals number of
	and	cx,7			; spaces per tab
	xor	cx,7
	inc	cl			; spaces = 1 to 8
tablp:
	mov	al,' '
	stosb
	mov	dl,' '
	call	PutChar
	loop	tablp
	pop	cx
jmi:
	jmp	moreinput
left:
        cmp     di,offset InputBuffer
        jz      jmi
		call	LeftArr
        jmp     jmi
right:
        test    byte ptr [di],255
        jz      jmi
		call	RightArr
        jmp     jmi
GetInputLine	ENDP	
;
; Wade past spaces
; Whoa! By subtle implication, the carry accidentally gets set if the non-
; space of comma character was less than 13 in ASCII sequence.  This means
; if we hit a tab (8), the carry gets returned set.
;   Turns out this is NO ACCIDENT, and callers rely on this somehow.
;
WadeSpace	PROC	
	lodsb				; Get char
	cmp	al,' '			; if ' ' or ',' go again
	je	short wadeSpace		;
	cmp	al,','			;
	je	short WadeSpace		;
	cmp	al,9	 		;ignore tab also
	je	WadeSpace
	dec	si			; Point at last space char
	cmp	al,13
	jz wsx
	cmp al,';'		; allow for comments :)
wsx:
	ret
WadeSpace	ENDP	
;
; Wade through spaces only
;
WadeSpaceOnly	PROC	
	lodsb			; Get a char
	cmp	al,' '		; Is space
	je	WadeSpaceOnly	; Loop if so
	cmp	al,9		; ignore tab also
	je	WadeSpaceOnly
	dec	si		; Else point at char
	cmp	al,13
	ret
WadeSpaceOnly   ENDP 
;
; quit routine
;
quit proc
        call    WadeSpace
        cmp     al,'s'
        jnz     nowrite
		inc		[optionWriteFlag]
nowrite:
        jmp     _exit
quit endp   
;
; Main Input routine
;
InputHandler	PROC
	test	[pleaseExit],1
	jnz		_exit
        call    ResetHistory
inputhandlelp:
	call	LoadHistory
	PRINT_MESSAGE	<13,10,"->">	; MONITOR prompt
	call	GetInputLine		; Get an input line
	call	WadeSpace		; Wade through spaces       
        jnz     docmd
        mov     byte ptr [si],13
        dec     si
        mov     al,[lastcmd]
        and     al,05fh
        or      al,20h
        cmp     al,'t'
        jz      docmd
        cmp     al,'p'
        jz      docmd
        cmp     al,'d'
        jz      docmd
        cmp     al,'u'
        jnz     InputHandleLp           ; blank line, so try again
docmd:
        mov     [lastcmd],al            ; 
	inc	si			; Point at first non-space char
	mov	di,offset commands	; Get command list
	mov	cx,comlen		; Length of list
	repne	scasb			; search for command in list
	jnz	ierr			; Error if not in list
	mov	ax,comlen-1		; Calculate position
	sub	ax,cx			;

;Dangerous practice - the list of commands is tightly coupled to the string
;of command characters. Some day, I should convert this to an array of
;structures, each containing the command and a pointer to its handler.
;Then we search through the structure list to find the command, and if found
;call the associated handler.

	push	0			; Command arg = 0
	call	TableDispatch		; Dispatch command
	dw	comlen-1
	dw	asm	     		;A command 
	dw	breaks			;B command
	dw	compare			;C command
	dw	Dump			;D command
	dw	entry			;E command
	dw	fill			;F command
	dw	go			;G command
	dw	domath			;H command
	dw	doin			;I command
	dw	DoFileRead		;L command
	dw	move			;M command
	dw	fpcommand		;N command
	dw	doout			;O command
	dw	proceed			;P command
        dw      quit                    ;Q command
	dw	ModifyRegisters		;R command
	dw	search			;S command
	dw	trap			;T command
	dw	diss			;U command
	dw	DoFileWrite		;W command
	dw	drive			;X command
	dw	pci			;Y command
	dw	logging			;@ command
	dw	help			;? command
        dw      slash                   ;/ command
        dw      symcmd                  ;$ command
	jnc	InputHandler		; Get more input if no err
ierr:
	call	qerr			; Display error
	jmp	InputHandler		; Get more input
InputHandler	ENDP
END