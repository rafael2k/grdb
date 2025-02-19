;    GRDB - debugger for dos with 32-bit extensions
;    Copyright (C) 1997-2006  David Lindauer
;
; dual monitor support provided by
;
;	Lawrence E. Boothby
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
; ansi.asm
;
; Function: ansi cursor sequences
;
	;MASM MODE
	.MODEL SMALL
	.386p

include  eprints.inc 
include eoptions.inc
ESC = 01bh

	.data
escape	db	0
	.code
	public ansisetcurpos, ansileft, ansiright, ansibackground, ansireset
	public ansicursor, ansicolor, ansigetkey, isansimode

isansimode PROC
	test	[optpure],1
	jnz		notansi
	test	[optdm],1
	jnz		notansi
	test	[optansi],1
	jz		notansi
	stc
	;return C for ansi mode
	ret
notansi:
	;return NC for not ansi mode
	clc
	ret
isansimode ENDP
ansisetcurpos PROC
	ret
	pusha
	push	dx
	mov	al, ESC
	call	basicputchar
	mov	al, '['
	call	basicputchar
	pop		ax
	push	ax
	movzx	eax,ah
	call	PrintDecimal
	mov al, ';'
	call 	basicputchar
	pop		ax
	movzx	eax,al
	call	PrintDecimal
	mov	al, 'H'
	call	basicputchar
	popa
	ret
ansisetcurpos ENDP

ansileft PROC
	pusha
	mov	al, ESC
	call	basicputchar
	mov	al, '['
	call	basicputchar
	mov	al, 'D'
	call	basicputchar	
	popa
	ret
ansileft ENDP

ansiright PROC
	pusha
	mov	al, ESC
	call	basicputchar
	mov	al, '['
	call	basicputchar
	mov	al, 'C'
	call	basicputchar	
	popa
	ret
ansiright ENDP

ansicursor PROC
	; block or line cursor, not supported
	ret
ansicursor ENDP

clrtab db 30, 34, 32, 36, 31, 35, 33, 37
		db 36, 34, 32, 36, 31, 35, 33, 37

ansibackground PROC
	pusha
	push ax
	mov	al, ESC
	call	basicputchar
	mov	al, '['
	call	basicputchar
	pop		bx
	and bx,15
	movzx eax,byte ptr [bx + clrtab]
	add		ax,10
	call	PrintDecimal
	mov	al, 'm'
	call	basicputchar	
	mov	al, ESC
	call	basicputchar
	mov	al, '['
	call	basicputchar
	mov	al, '2'
	call	basicputchar
	mov	al, 'J'
	call	basicputchar
	popa
	ret
ansibackground ENDP	
ansireset PROC
	pusha
	mov	al,ESC
	call	basicputchar
	mov	al,'c'
	call	basicputchar
	popa
	ret
ansireset ENDP
ansicolor PROC
	pusha
	push ax
	mov	al, ESC
	call	basicputchar
	mov	al, '['
	call	basicputchar
	pop		bx
	and bx,15
	movzx eax,byte ptr [bx + clrtab]
	call	PrintDecimal
	mov	al, 'm'
	call	basicputchar	
	popa
	ret
ansicolor ENDP

keys	dw	4800h,5000h,4d00h,4b00h ; UP, DOWN, RIGHT, LEFT
pfs		dw	5300h,6200h,4700h,4f00h ; DEL, CTRL-F5, HOME, END
ansigetkey PROC
	call	isansimode
	jc		agk
	call	GetKey
	ret
agk:
	push	si
	push	di
	push	cx
	push	bx
	push	dx
lp:
	sub		ah,ah
	int		16h
	test	[escape],1
	jz		chkesc
	sub		ah,ah
	cmp		al,'['
	jz		lp
	cmp		al,'O'
	jz		lp
	dec		[escape]
	cmp		al,ESC
	jz		rc
	cmp		al,'P'
	jae		pfkeys
	sub		al,'A'
	jc		lp
	cmp		al,4
	jnc		lp
	movzx	bx,al
	add		bx,bx
	mov		ax,[keys + bx]
	jmp		rc
pfkeys:
	sub		al,'P'
	jc		lp
	cmp		al,4
	jnc		lp
	movzx	bx,al
	add		bx,bx
	mov		ax,[pfs + bx]
	jmp		rc
chkesc:
	cmp	al,ESC
	jnz		rc
	inc		[escape]
	jmp		lp
rc:
	pop	dx
	pop	bx
	pop	cx
	pop	di
	pop	si
	ret
ansigetkey ENDP
	end
	