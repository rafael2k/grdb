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
; DRIVE.ASM
;
; Function: Handle logical drive functions
;
	;MASM MODE
	.MODEL SMALL
	.386


include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include eints.inc
include edpmi.inc

	PUBLIC drive

	.data
int24ParmBlock	dd	0	;int 24/24 parameter block
		dw	0
		dd	0

	.CODE
drive	PROC
	call	noCommandInDPMI
	lodsb
	cmp	al,'r'		; verify subcommand
	jz	ok
	cmp	al,'w'
	jz	ok
	stc
	ret
ok:
	cmp	al,'r'
	pushf
	call	WadeSpace
	cmp	al,'a'		; get drive
	jc	err1
	cmp	al,'z'
	ja	err1
	sub	al,'a'
	inc	si
	push	ax
	cmp	byte ptr [si],':'
	jnz	noinc
	inc	si
noinc:
	call	WadeSpace
	jz	err2
	call	ReadAddress	; get buffer address
	jc	err2
	call	defDS		; get DS
	mov	word ptr [int24ParmBlock+6],bx	; set up parameter block
	mov	word ptr [int24ParmBlock+8],dx
	call	WadeSpace
	jz	err2
	call	ReadNumber		; get start
	jc	err2
	mov	dword ptr [int24ParmBlock],eax
	mov	word ptr [int24ParmBlock+4],1
	call	WadeSpace
	jz	nosize
	call	ReadNumber		; get size
	jc	err2
	mov	word ptr [int24ParmBlock+4],ax
	call	WadeSpace
	jnz	err2
nosize:
	pop	ax
	mov	cx,-1
	mov	bx,offset int24ParmBlock
	call	swapintpage
	popf                 		; figure out what to do
	jz	doread
	int	26h
	jmp	combine
doread:
	int	25h
combine:
	jnc	noerr
	call swapintpage
	push	ax
	PRINT_MESSAGE	<13,10,"Error: ">
	pop	ax
	call	printword
noerr:
	call swapintpage
	add	sp,2      		; stupid INT 25/26 leaves flags on stack
	clc
	ret
err2:
	pop	ax
err1:
	popf
	stc
	ret
drive	endp
end
