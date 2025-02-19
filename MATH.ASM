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
; MATH.ASM
;
; Function: Handle hex math
;
	;MASM MODE
	.MODEL SMALL
	.386


include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include  ebreaks.inc 
include  eoptions.inc
        PUBLIC domath, mathoper, mathsub

	.CODE
;
; Do math
;
printx	PROC
	test	[optdword],1
	jnz	PrintDword
	jmp	PrintWord
printx	ENDP
mathoper PROC
	sub	ebx,ebx
	cmp	al,'*'
        jz      mogot
	inc	bl
	cmp	al,'/'
        jz      mogot
	inc	bl
	cmp	al,'+'
        jz      mogot
	inc	bl
	cmp	al,'-'
        jz      mogot
	inc	bl
	cmp	al,'%'
        jz      mogot
        stc
mogot:
        ret
mathoper ENDP
domath	PROC	
	Call	WadeSpace	; Wade till address
	jz	readerr
        call    ReadNumberLL      ; first number
	jc	readerr
	mov	edx,eax
	call	WadeSpace	; get operator
	jz	readerr
        call    mathoper
        jnc     got
        dec     si              ; no bump
        mov     bl,5            ; use default operator
got:
	inc	si
	call	WadeSpace
	jz	readerr
        call    ReadNumberLL      ; second number
	jc	readerr
	mov	ecx,eax
	call	WadeSpace
	jnz	readerr
	mov	eax,edx
	push	eax
	call	crlf
	pop	eax
        call    mathsub
	call	printx		; print result
	clc
	ret
domath ENDP
mathsub PROC
        shl     bl,1            ; execute operand
	call	cs:[bx + jumptab]
        ret
jumptab	dw	xmul,xdiv,xxadd,xsub,xmod,xdefault
xmul:
	mul	ecx
	ret
xmod:
	call	xdiv
	mov	eax,edx
	ret
xdiv:
        or      ecx,ecx
	jz	nodiv
	sub	edx,edx
	div	ecx
nodiv:
	ret
xxadd:
	add	eax,ecx
	ret
xsub:
	sub	eax,ecx
	ret

xdefault:		; by default act like debug
	push	eax
	push	ecx
	add	eax,ecx
	call	printx
	call	printspace
	pop	ecx
	pop	eax
	sub	eax,ecx
	ret

readerr:
	stc
	ret
mathsub  ENDP
end
