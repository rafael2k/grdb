;    GRDB - debugger for dos with 32-bit extensions
;    Copyright (C) 1997-2006  David Lindauer
;
; extension for word and doubleword dump donated by:
;
; Michael Stember              
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
; Function: Handle the Dump command
	;MASM MODE
	.model small
	.386
include  eprints.inc
include  einput.inc
include  emtrap.inc
include  eoptions.inc
include  iwindow.inc
include	 eints.inc

DUMPLEN = 80h
	PUBLIC	dump, redump
        PUBLIC  index,indexseg, memsizechk, memsize
	extrn w_setwind : PROC, optfs : BYTE
	extrn wnd_dump : windstr
	.data
index	  dd	0	; Default for next dump
indexseg  dw	0	;
charcount db	16
dcr	  db	13
memsize   db	0	;b/w/d = 0/1/2
;Debug reads each memory paragraph twice, once for the hex values and a
;second time for the ASCII values. This screws up at least two types of
;memory: memory-mapped IO when reads change the state of the device, and
;and FIFO devices with internal counters. So we read each location only once
;into this buffer, and then read the buffer to create the ASCII.
linedata db	64 DUP (0DEh)	   ;holds line so we read it only once
				;temporarily 64 to handle screwups, should be 16
	.code
blanklp        proc
blanklplab:
	call	PrintSpace	; Dump spaces
	loop	blanklplab
	ret
blanklp 	endp
;
; get the size of memory chunks to deal with
;
memsizechk  proc
	lodsb
	clc		;assume it will come out okay
	mov	bl,000h  ; might be a byte
	cmp	al,'b'
	jz	newsize
	mov	bl,001h  ; might be a word
	cmp	al,'w'
	jz	newsize
	mov	bl,002h  ; might be a doubleword
	cmp	al,'d'
	jz	newsize
	cmp	al,' '
	jz	oldsize
	cmp	al,13	   ; found CR after command letter
	je	memsizecr
	mov	bl,0h	   ; revert size to byte
	stc		   ; was not one of [CR,b,w,d,' '], flag error
newsize:
	mov	[memsize],bl
oldsize:
	ret
memsizecr:
	dec si	 ; back up pointer so rest of dump routine sees the CR
	ret
space PROC
	mov	al,[charcount]	; Get count of amount to space over
	sub	al,cl		;
	jz	short spw	; Don't space over any, just put out hex
	sub	ah,ah
	push	cx		; Else ecx = spacecount * 3
	mov	cx,ax		;
	imul	cx,dx		;  5/2	spaces per byte
	xchg	bx,cx
	shr		bx,cl
	xchg	bx,cx
	call	blanklp
	pop	cx
spw:
	ret
space ENDP
readlinedata PROC
	cli
	call swapintpage
	push	cx
	mov	di,offset linedata	; Now get the data to our buffer
	movzx	edi,di
	push	ds
	push	fs			; fs:si was source
	movzx	ecx,cx
	pop	ds
	db	67h		; addrsize
        rep     movsb
	pop	ds
	pop	cx
	call 	swapintpage
	sti
	mov	si,offset linedata
	ret
readlinedata ENDP
memsizechk endp
; Dump one line
dumpline	PROC
	push	esi
	push	dx
	push	ebx			; EBX MUST be on second of stack
	push	ecx			; ECX MUST be on top of stack
	push	dx
	mov		dl,C_CODEBYTES
	call	PutChar
	pop		dx
	
	cmp	ecx,16
        jl      doline
        mov     ecx,16
doline:
	sub	[esp],ecx	; Decrement count which is on stack
	add	[esp+4],ecx	; Increment address which is on stack
	cmp	[memsize],1	; 0/1/2 = byte/word/dword
	jl	dolineb
	je	dolinew
	jg	dolined
dolineb:
puthexb:
	call	readlinedata
	push	cx
hexlpb:
	test	cx,3
	jnz	hspb
	cmp	cl,[charcount]
	jae	hspb
	mov	dl,'-'
	call	putchar
	jmp	hjnb
hspb:
	call	PrintSpace	; Print a space
hjnb:
	lodsb
	call	PrintByte	; Print byte in hex
	loop	hexlpb		; Loop till done
        pop     cx              ;
        cmp     cx,16
        jz      duascii
	push cx
        mov     dx,3
	mov	bl,0
	call	space
	pop	cx	
	jmp	duascii

dolinew:
puthexw:
	call	readlinedata
	push	cx
	shr	ecx,1
	test	cx,cx
	jnz	hexlpw
        inc     cx
hexlpw:
	call	PrintSpace	; Print a space
hjnw:
	lodsw
	call	PrintWord	; Print byte in hex
	loop	hexlpw		; Loop till done
        pop     cx              ;
        cmp     cx,16
	jz		duascii
        push    cx
        shr     ecx,1
        test    cx,cx
        jnz     hjnw2
        inc     cx
hjnw2:
        sub     cx,8
        neg     cx
        mov     ax,5
        imul    cx,ax
        call    blanklp
	pop	cx	
	jmp	duascii

dolined:
puthexd:
	call	readlinedata
	push	cx
	shr	ecx,2
	test	cx,cx
	jnz	hexlpd
	inc		cx
hexlpd:
	call	PrintSpace	; Print a space
hjnd:
	lodsd
	call	PrintdWord	; Print byte in hex
	loop	hexlpd		; Loop till done
	pop	cx		;
        cmp     cx,16
        jz      duascii
        push    cx
        shr     ecx,2
        test    cx,cx
        jnz     hjnd2
        inc     cx
hjnd2:
        sub     cx,4
        neg     cx
        mov     ax,9
        imul    cx,ax
        call    blanklp
	pop	cx	
duascii:
	mov		dl,C_ASCII
	call	PutChar
	call	printSpace	; Print two spaces to seperate ASCII dump
	call	PrintSpace	;
	mov	si,offset linedata
	sub	ax,ax		; Calculate amoun to space over
putascii:
	mov	dl,[si] 	; Get char
	inc	si		; Increment buffer
	call	PureChar
	loop	putascii
	pop	ecx		; Get count from stack
	pop	ebx		; Get address from stack
	pop	dx
	pop	esi
	ret
dumpline	ENDP
;
; Main DUMP routine
redump	PROC
	mov	si,offset dcr
redump	ENDP
dump	PROC
	mov	ecx,DUMPLEN	; Default amount to dump
	mov	[charcount],16
ifndef NOFS
	test	[optfs],255
	jz	ndump
	mov	bx,offset wnd_dump
	call	w_setwind
	push	ax
	mov	[charcount],8
	mov	ecx, 6 * 8

ndump:
endif
	call	memsizechk	; parse for byte/word/dword
	jc	dudone		; bad syntax, leave
	call	WadeSpace	; Wade to end of spaces
	jz	short atindex	;
	call	ReadAddress	; Else read start address and put into ebx
	jc	dudone		; Quit on error
	call	WadeSpace	; Wade through spaces
	jz	short dodump	;
        cmp     al,'l'
        jnz     dumpnl
        inc     si
        call    ReadNumber
        jc      dudone
        mov     ecx,eax
        jmp     short dodump
dumpnl:
	call	ReadNumber	; Else read end offset and put into eax
	jc	dudone	  ;
	sub	eax,ebx 	; Calculate length of dump
	mov	ecx,eax 	;
        inc     ecx
	jmp	short dodump	; Go do dump
atIndex:
	mov	ebx,[index]	; Assume we want to dump from last index
	mov	dx,[indexseg]	;
dodump:
;	push	ecx
;	mov	cl,[memsize]	; round addresses down to nearest byte/word/dword
;	shr	ebx,cl
;	shl	ebx,cl
;	shr	eax,cl
;	shl	eax,cl
;	pop	ecx
ifndef NOFS
	mov	[index],ebx
	mov	[indexseg],dx
endif
	call	defDS		; get DS
	mov	fs,dx
	call	bit32Address
	jnz	dumpj
	mov	eax,10000h
	sub	eax,ebx
	cmp	eax,ecx
	jnc	dumpj
	mov	ecx,eax
dumpj:
	movzx	eax,[charcount]
	dec	al
;	test	bl,al
;	jz	dumplp
;	inc	al
;	sub	ecx,eax
dumplp:
	call	scankey
	jnz	dusetadr
	push	ebx		;
	call	crlf
	pop	ebx		;
	push	dx
	mov		dl,C_ADDRESS
	call	PutChar
	pop		dx
	mov	ax,dx		; Print the selector
	call	PrintWord	;
	push	dx		;
	mov	dl,':'          ; Print a ':'
	call	PutChar
	pop	dx		;
	mov	esi,ebx
        mov     eax,ebx
	call	bit32Address
	jz	adrword
	call	PrintdWord	; Print address
	jmp	adrcmb
adrword:
	call	PrintWord
adrcmb:
	call	dumpline	; Dump a line
	or	ecx,ecx 	; Continue while count > 0
	jg	dumplp
dusetadr:		;
ifndef NOFS
	test	[optfs],255
	jnz	dudone
endif
	mov	[index],ebx	; Save new index value
	mov	[indexseg],dx	;
	clc			; No errors
dudone:
	pushf
	mov		dl,C_DEFAULT
	call	PutChar
	popf
ifndef NOFS
	pushf			; remember the carry flag in case of error
	test	[optfs],255	; TEST clears the carry flag
	jz	dux
        popf
	pop	bx
        pushf
	call	w_setwind
dux:
	popf
endif
	ret
dump	ENDP
END