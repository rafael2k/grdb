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
; help.asm
;
; Function: Handle help and most of the status screens
;
;   Handles numbers
;   Handles segments
;   Handles trapping page faults
;   Handles command input
;
	;MASM MODE
	.model small
	.386

include  iwindow.inc
include  iversion.inc
include  eprints.inc 
include  emtrap.inc 
include  eenv.inc
include  eloader.inc
include  einput.inc
include edos.inc
include eoptions.inc
include eints.inc
include edpmi.inc
include emsr.inc

        extrn w_cmdset : proc, optfs: BYTE
	PUBLIC  doarena, dochain

	.data
memx	dw	0	; used to filter non-program stuff in arena dump (?m)
        
	.code
doarena PROC
	call	noCommandInDPMI
ifndef NOFS
        test    [optfs],255
        jz      nofsx5
        mov     al,1
        call    w_cmdset
nofsx5:
endif
	mov	ax,[userbasepsp]		; calc PSP match
	mov	[memx],ax
	inc	si
	call	WadeSpace
	jz	memok
	cmp	al,'x'
	jnz	herr
	inc	si
	call	WadeSpace
	jnz	herr
	mov	[memx],0
memok:
	PRINT_MESSAGE	<13,10,13,10,C_OPTTEXT, "Top of memory: ", C_NUMBER>
	mov	fs,[userbasepsp]
	mov	ax,fs:[2]
	call	PrintWord
	call	crlf
	push	es 				; get root of chain      			
	mov	ah,52h	
	int	21h
	mov	bx,es:[bx-2]
	pop	es
meml:
	mov	fs,bx
	test	[memx],0ffffh			; check match and jump around if not
	jz	memd
	mov	ax,fs:[1]
	cmp	ax,[memx]
	jnz	memnd
memd:
	PRINT_MESSAGE	<13,10,C_OPTTEXT,"Address: ",C_NUMBER>
	mov	ax,fs
	call	PrintWord
	PRINT_MESSAGE	<C_OPTTEXT, "  Owner: ", C_SYMBOL>
	test	word ptr fs:[1],-1
	jz	memu
	cmp	word ptr fs:[1],100h
	jc	memdos
	cmp	word ptr fs:[1],0f000h
	jnc	membios
	push	fs    				; not special
	mov	bx,fs:[1]			; display prog name owner
	dec	bx
	mov	fs,bx
	mov	si,8
	mov	cx,8
memns:
	lods	byte ptr fs:[si]
	or	al,al
	jz	memnsx
	mov	dl,al
	call	PutChar
	loop	memns
memnsx:
	pop	fs
	inc	cx
	push	cx
	mov	dl,C_DEFAULT
	call	PutChar
	mov	dl,'('
	call	PutChar
	mov		dl,C_NUMBER
	call	PutChar
	mov	ax,fs:[1]
	call	PrintWord
	mov		dl, C_DEFAULT
	call	PutChar
	mov	dl,')'
	call	PutChar
	jmp	memsz
memdos:                                         ; dos special case
	push	12
	PRINT_MESSAGE	"DOS"
	jmp	memmsg
membios:					; bios special case
	push	11
	PRINT_MESSAGE	"BIOS"
	jmp	memmsg

memu:						; free special case
	push	11
	PRINT_MESSAGE	"FREE"
memmsg:
memsz:
	pop	cx
memspl:
	mov	dl,' '				; field pad
	push	cx
	call	PutChar
	pop	cx
	loop	memspl
	PRINT_MESSAGE	<C_OPTTEXT, "  Size: ", C_NUMBER>
	mov	ax,fs:[3]
	call	PrintWord
	mov	bx,fs
memnd:
	add	bx,fs:[3]			; index to next entry
	inc	bx
	cmp	byte ptr fs:[0],'Z'		; quit if this entry was EOM
	jnz	meml
	mov	dl,C_DEFAULT
	call	putchar
	clc
	ret
doarena ENDP
herr PROC
	stc
	ret
herr ENDP
dochain PROC
	call	noCommandInDPMI
	inc	si
	call	wadespace
	jnz	herr
ifndef NOFS
        test    [optfs],255
        jz      nofsx6
        mov     al,1
        call    w_cmdset
nofsx6:
endif
	inc	si
	call	crlf
	push	es
	call	compatibleIntPage
	mov		es,ax
	sub	ax,ax
	mov	gs,ax
	mov	cx,256
	sub	si,si
	sub	di,di
chl:
	lods	dword ptr gs:[si]	; compare currint int page entry
	scasd
	jz	noch
	push	si
	push	di
	push	eax			; mismatch, print int #
	mov	al,cl
	neg	al
	push	ax
	call	printbyte
	pop	ax
	cmp	al,21h			; int 21h is modifiable
	jz	nostar
	or	al,al 			; so are all ints > 7FH
	js	nostar
	push	es
	push	ds
	pop	es
	mov	di,offset veclist
chlx:
	scasw
	jz	dostar
	inc	di
	inc	di
	cmp	byte ptr [di],0ffh
	jnz	chlx
	pop	es
nostar:
	call	printspace		; not overridden
	jmp	chj
dostar:
	pop	es
	mov	dl,'*'
	call	putchar
chj:                                    ; print int vect address
	mov	dl,':'
	call	putchar
	call	printspace
	pop	bx
	pop	ax
	call	printword
	mov	dl,':'
	call	putchar
	mov	ax,bx
	call	printword
	call	crlf
	pop	di
	pop	si
noch:
	loop	chl
	pop	es
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "PIC 0 mask: ", C_NUMBER>
	mov	dx,21h
	mov	ah,byte ptr [orgpic+1]
	call	picval
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "PIC 1 mask: ", C_NUMBER>
	mov	dx,0a1h
	mov	ah,byte ptr [orgpic]
	call	picval
	mov		dl,C_DEFAULT
	call	PutChar
	clc
	ret
picval:
	push	ax
	in	al,dx
	push	dx
	call	printbyte
	call	printspace
	mov	dl,'(' 
	call	putchar
	pop	dx
	pop	ax
	push	dx
	mov	al,ah
	call	printbyte
	mov	dl,',' 
	call	putchar
	pop	dx
	dec	dx
	mov	al,0bh
	out	dx,al
	in	al,dx
	call	printbyte
	mov	dl,')' 
	call	putchar
	ret
dochain ENDP
END