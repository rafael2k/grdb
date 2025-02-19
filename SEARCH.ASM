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
; SEARCH.ASM
;
; Function: Search memory
;
	;MASM MODE
	.MODEL SMALL
	.386

include iwindow.inc
include	eprints.inc 
include	einput.inc 
include	emtrap.inc 
include	eoptions.inc
include eints.inc

	PUBLIC	search
	EXTRN	paddr:PROC
	.data
inputbuf	db	128 DUP (?)
ArgLen	dw	0	;#bytes in input buffer
rolled  db      0               ; currently in upper half of segment

	.CODE
search	PROC
        mov     [rolled],0
	push	es
	mov	[ArgLen],0
	call	WadeSpace
	jz	errx
	call	ReadAddress	; read address
	jc	errx
	mov	ecx,ebx
	call	defDS		; get DS
	call	WadeSpace
	jz	errx
	mov	di,dx
	push	di
	push	ecx
        cmp     al,'l'
        jnz     searchnl
        inc     si
        call    ReadAddress
        pop     ecx
        jc      searchj
        add     ebx,ecx
        clc
        jmp     searchj
searchnl:
        call    ReadAddress     ; read end
	pop	ecx
searchj:
	pop	di
	jc	errx
	or	edx,edx
	jnz	hasseg2
	mov	dx,di		;default to first seg
hasseg2:
	push	di
	mov	di, offset dgroup:inputbuf
grablp:				; read rest of params
	call	WadeSpace
	jz	grabdone
	cmp	al,"'"
	jz	readstring
	cmp	al,'"'
	jnz	readnum
readstring:             	; read a quoted string
	mov ah,al
	inc	si
readstringlp:
	lodsb
	cmp	al,13
	jz	grabdone
	cmp al,ah
	jz	grablp
	stosb
	inc	[ArgLen]
	cmp	[ArgLen],080h
	jnc	errx
	jmp	readstringlp

readnum:			; read an (8-bit) number
	push	di
	push	cx
        push    es
        push    ds
        pop     es
	call	ReadNumber
        pop     es
	pop	cx
	pop	di
	jc	errx2
	stosb
	inc	[ArgLen]
	cmp	[ArgLen],080h
	jnc	errx
	jmp	grablp

grabdone:                       	; all params got now
	pop	di
	call	bit32Address
        jnz     gp2
        movzx   ebx,bx                  ; make them 16-bit
        movzx   ecx,cx
gp2:
	test	[ArgLen],0ffh		; see if any search
	jz	errx
	push	dx
	mov		dl,C_ADDRESS
	call	PutChar
	pop		dx
	movzx	edi,di
	movzx	eax,dx 			; calculate length
	shl	eax,4
	add	ebx,eax
	mov	edx,edi
	mov	eax,edx
	shl	eax,4
	add	eax,ecx
	sub	ebx,eax			; ds:cx = start, ebx = len
	push	ebx
	call	CRLF
	pop	ebx
	pop	es
	mov	esi,ecx
noseg:
	call	bit32Address
        jnz     go1
	cmp	si,8000h	; adjust DS to keep search in bounds
	jc	go1
        inc     [rolled]
	sub	si,8000h
    	add	dx,800h
go1:
;	call	ScanKey		; I put this in for debug, but,
;	jnz	nofill2		; good for mistakes too...
	push	es
	movzx	ecx,[ArgLen]
	push	ds
	mov	ds,dx
	push	esi
	mov	di,offset dgroup:inputbuf
	movzx	edi,di
	cli
	call swapintpage
	db	67h
	repe	cmpsb
	call swapintpage
	sti
	pop	esi
	pop	ds
	pop	es
	jnz	nomatch
	push	ebx
	push	dx
	mov	eax,esi
        test    [rolled],1
        jz      notrolled
        add     eax,8000h
        sub     dx,800h
notrolled:
	call	paddr
	pop	dx
	call	crlf
	pop	ebx
nomatch:
	inc	esi
	dec	ebx
        jns     noseg
	mov		dl,C_DEFAULT
	call	PutChar
	clc
	ret
nofill:
	pop	es
nofill2:
	clc
	ret
errx2:
	pop	di
errx:
	pop	es
	stc
	ret
search	endp
end