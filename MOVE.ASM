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
; MOVE.ASM
;
; Function: move memory regions
;
	;MASM MODE
	.MODEL SMALL
	.386


include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include eoptions.inc
include eints.inc

	PUBLIC move


	.CODE
mra	PROC
	call	ReadAddress		; read source address
	jc	mrax
	call	defDS			; get DS
mrax:
	ret
mra	ENDP
;
; move command
;
move	PROC
	call	WadeSpace
	jz	errx
	call	mra 			; read source
	jc	errx
	push	bp
	push	dx
	push	ebx
	call	WadeSpace
	jz	errx2
        cmp     al,'l'
        jnz     movenl
        inc     si
        call    ReadNumber
        jc      errx2
        mov     ecx,eax
        jmp     movej
movenl:
	call	ReadNumber		; read end of source
	jc	errx2
	mov	ecx,eax
	sub	ecx,ebx
	jb	errx2
movej:
	call	WadeSpace
	jz	errx2
	call	mra			; read dest
	jc	errx2
	call	WadeSpace
	jnz	errx2
	call	bit32Address
	jnz	gotsz
	movzx	ebx,bx
	movzx	ecx,cx
	mov		bp,sp
	movzx	eax,word ptr [bp]
	mov	[bp],eax
gotsz:
	movzx	eax,dx			; ok no compare the args
	shl	eax,4
	add	eax,ebx
	push	eax    			; TOS = dest
	mov		bp,sp
	movzx	eax,word ptr [bp+8]		; EAX = source
	shl	eax,4
	add	eax,[bp+4]
	cmp	eax,[bp]
	jz	noop
	jl	sld
sgd:
	cli
	call swapintpage
	push	es   			; when source greater than dest
	push	ds			; do a move down
	mov	edi,ebx
	mov	es,dx
	mov	bp,sp
	mov	esi,[bp+4+4]
	mov	ds,[bp+8+4]
        inc     ecx
	db	67h
	rep	movsb
	pop	ds
	pop	es
	call swapintpage
	sti
	jmp	noop
sld:
	cli
	call swapintpage
	push	es			; when dest greater than source
	push	ds			; do a move up
	mov	edi,ebx
	mov	es,dx
	mov	bp,sp
	mov	esi,[bp+4+4]
	mov	ds,[bp+8+4]
	lea	esi,[esi+ecx-1]
	lea	edi,[edi+ecx-1]
	std
	db	67h
	rep	movsb
	cld
	pop	ds
	pop	es
	call swapintpage
	sti
noop:
	add	sp,10			; come here when done
	pop	bp
	clc				; to clean up stack
	ret
errx2:
	add	sp,6
	pop	bp
errx:
	stc
	ret
move	endp
end