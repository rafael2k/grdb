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
; FILL.ASM
;
; Function: Fill memory
;
	;MASM MODE
	.MODEL SMALL
	.386


include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include  eoptions.inc
include  eints.inc

	PUBLIC fill

	.data
fillbuf	db 256 dup (?)

	.CODE
;
; fill command
;
fill	PROC
	call	WadeSpace
	jz	errx
	call	ReadAddress		; read start address
	jc	errx
	call	defDS			; Get DS
	call	WadeSpace
	jz	errx
        cmp     al,'l'
        jnz     fillnl
        inc     si
        call    ReadNumber
        jc      errx
        mov     ecx,eax
        jmp     fillj
fillnl:
        call    ReadNumber              ; read end
	jc	errx
	mov	ecx,eax
        inc     ecx
	sub	ecx,ebx
	jc	errx
fillj:
	call	WadeSpace
	mov	al,0           		; default fill = 0
	jz	gotfill
	cmp	byte ptr [si], '"'
	jz	fillstr
	cmp byte ptr [si], "'"
	jz fillstr
	call	ReadNumber		; else read a fill val
	jc	errx
	push	ax
	call	WadeSpace
	pop	ax
	jnz	errx
	call	bit32Address
	jnz	gotfill
	movzx	ecx,cx
gotfill:
	push	es			; fill mem
	mov	es,dx
	mov	edi,ebx
	cli
	call swapintpage
	db	67h
	rep	stosb
	call swapintpage
	sti
	pop	es
	clc
	ret
errx:
	stc
	ret
fillstr:
	mov	di, offset dgroup:fillbuf
	mov	ah, [si]
	inc si
fsl:
	lodsb
	cmp al,13
	jz fsx
	cmp al,ah
	jz fsx
	stosb
	jmp fsl
fsx:
	call	WadeSpace
	jnz	errx
	call	bit32Address
	jnz	fsgotf
	movzx	ecx,cx
fsgotf:
	jecxz  fsleave
	call swapintpage
	push	es			; fill mem
	mov	es,dx
	xchg	edi,ebx
fslp1:
	mov  si, offset dgroup:fillbuf
fslp2:
	cmp	si,bx
	jz	fslp1
	db	67h
	movsb
	loop fslp2
	pop	es
	call swapintpage
fsleave:
	clc
	ret
fill	endp
end