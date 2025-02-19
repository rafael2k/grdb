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
; Entry.asm
;
; Function: handle hex data entry
;
	;MASM MODE
	.model small
	.386


include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include eoptions.inc
include edump.inc
include eints.inc
include edpmi.inc
include eansi.inc
        PUBLIC  entry, entrytobuf, diglen

	.data
InsideQuote	db	0	;flag if we're inside a quote
diglen  db      0               ; number of digits

	.code
;
; function to read a string and fill a buf with bytes based on the string's
; data
;
entrytobuf PROC
        call    wadespace
readlp:
        inc     si
        mov     bl,al
        cmp     al,"'"
        jz      readstr
        cmp     al,'"'
        jz      readstr
        dec     si
        push    edi
	call	ReadNumber		; Else read number off command line
        pop     edi
        jc      eb_err                  ; Quit if error
        push    eax
		call	swapintpage
        pop     eax
        cmp     [memsize],1
        jl      rbyte
        je      rword
        jg      rdword
rbyte:
	mov	fs:[edi],al		; Save value
        jmp     rjoin
rword:
        mov     fs:[edi],ax
        jmp     rjoin
rdword:
        mov     fs:[edi],eax
rjoin:
		call	swapintpage
        sti
        movzx   eax,[diglen]
        shr     eax,1
        add     edi,eax
readclcont:
	call	WadeSpace		; Wade through spaces
        jz      eb_ret           ;
	jmp	readlp			; Else get next value
readstr:
        lodsb
        cmp     al,bl
        jz      readclcont
        cmp     al,13
        jz      eb_ret
        push    ax
        cli
		call	swapintpage
        pop     ax
        mov     fs:[edi],al
		call	swapintpage
        sti
        inc     edi
        jmp     readstr
eb_ret:
        clc
eb_err:
        ret
entrytobuf      endp
;
; Input function for a number
;
InputNumber	PROC	
	mov	[InsideQuote],0
	push	dx
	push	cx
        push    ebx
	sub	cx,cx 		; Number of digits = 0
        sub     ebx,ebx                   ; Data = 0
lp:
	call	AnsiGetKey
	mov	ah,al			; AH = data
	cmp	al,' '			; Space, data is complete
	jz	space		;
	cmp	al,13			;
	jz	isenter		; ENTER = quit entering data
	cmp	al,8			; BACKSPACE or RUBOUT, handle it
	jz	bckspc		;
	cmp	al,7fh			;
	jz	bckspc		;
	cmp	al,'"'
	jz	quote
	cmp	al,"'"
	jz	quote
	test	[InsideQuote],1
	jnz	isquote
	cmp	al,60h
	jc	notlower
	and	al,NOT 20h
notlower:
	sub	al,'0'			; Convert to binary, ignore if not valid
	jc	lp			;
	cmp	al,10			;
	jc	gotdigit		;
	sub	al,7			;
	cmp	al,10			;
	jc	lp			;
	cmp	al,16			;
	jnc	lp			;
gotdigit:
        cmp     cl,[diglen]             ; If got two digits don't accept
	jz	lp
        shl     ebx,4                    ; Add in the digit
        or      bl,al                   ;
writechar:
	mov	dl,ah			;
	call	PutChar
	inc	ecx			; Inc digit count
	jmp	lp			; Next digit
isquote:
        cmp     cl,[diglen]
	jz	lp
	mov	bl,al
	jmp	writechar
bckspc:
	or	cx,cx			; Get next digit if nothing in buffer
	jz	lp			;
	test	[InsideQuote],1
	jz	delnoquote
        cmp     cl,[diglen]
	jz	delnoquote
	xor	[InsideQuote],1
delnoquote:
        shr     ebx,4
	mov	dl,8			; Erase echoed char
	call	PutChar
	mov	dl,' '			;
	call	PutChar
	mov	dl,8			; Point at next echo space
	call	PutChar
	dec	cx			; Dec digit count
	jmp	lp
isenter:
	or	cx,cx			; Enter key, set carry and get out
	stc				;
	jmp	getout
quote:
	test	[InsideQuote],1
	jnz	lp
	xor	[InsideQuote],1
	jmp	writechar
space:
	or	cl,cl			; Space key, clear carry and get out
getout:
	pushf
        mov     al,[diglen]             ; Space to line up in columns
        inc     al
	sub	al,cl			;
	mov	cl,al			;
pslp:			
	call	printspace		;
	loop	pslp			;
	popf				;
        mov     eax,ebx                   ; AX = number input
        pop     ebx
	pop	cx
	pop	dx
	ret
InputNumber	ENDP	
;
; Number entry with prompt
;
entry	PROC	
        call    memsizechk              ; get size
        jc      enterr
        mov     al,2
        mov     cl,[memsize]
        shl     al,cl
        mov     [diglen],al
	call	WadeSpace		; Wade through commad spaces
	jz	enterr
	call	ReadAddress		; Read the address
	jc	enterr			; Bad address ,error
	call	defDS			; get DS
	mov		ax,dx
	call	compatibleUtilitySeg
	mov	fs,ax
	mov	edi,ebx
	mov	cx,-1			;
	call	WadeSpace		; Wade through spaces
	jz	promptx		; Go do prompt version
        call    entrytobuf
        jc      enterr2
        jmp     retok
promptx:
	call	crlf
	mov	ax,dx			; Print segment
	call	PrintWord		;
	push	dx			;
	mov	dl,':'			; Print ':'
	call	PutChar
	pop	dx			;
	mov	eax,ebx                 ;
	call	bit32Address
	jz	adrword
	call	PrintdWord	; Print address
	jmp	adrcmb
adrword:
	call	PrintWord
adrcmb:
elp:
	call	printspace		; Space over two spaces
	call	printspace		;
        cli
		call	swapintpage
        cmp     [memsize],1
        jl      r3byte
        je      r3word
        jg      r3dword
r3byte:
        mov     al,fs:[edi]             ; Save value
	call	printbyte		;
        jmp     r3join
r3word:
        mov     ax,fs:[edi]
        call    printword
        jmp     r3join
r3dword:
        mov     eax,fs:[edi]
        call    printdword
r3join:
		call	swapintpage
        sti
	push	dx			;
	mov	dl,'.'			; Print '.'
	call	PutChar
	pop	dx			;
	push	cx
	call	InputNumber		; Get a number
	pop	cx
	jz	nextitem		; No number, go do next
		pushfd
        push    eax
		call	swapintpage
        pop     eax
        cmp     [memsize],1
        jl      r2byte
        je      r2word
        jg      r2dword
r2byte:
	mov	fs:[edi],al		; Save value
        jmp     r2join
r2word:
        mov     fs:[edi],ax
        jmp     r2join
r2dword:
        mov     fs:[edi],eax
r2join:
		call	swapintpage
		popfd
nextitem:
	jc	retok		; Quit if ENTER key pressed
	dec	cx			; Quit if end of segment
	jz	retok		;
        movzx   eax,[diglen]
        shr     eax,1
        add     edi,eax
        add     eax,ebx                 ; new in eax,old in ebx
        xchg    ebx,eax
	call	bit32Address
	jnz	cont
	cmp	ebx,10000h
	jz	retok
cont:
        xor     eax,ebx                 ; pass a boundary where lower bits are 0?
        test    eax,8
        jnz     promptx
	jmp	elp
retok:
	clc				; No errors
	ret
enterr2:
enterr:		
	stc     			; Errors
dudone:
	ret
entry	ENDP	
END