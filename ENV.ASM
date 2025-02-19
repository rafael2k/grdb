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
; ENV.ASM
;
; Function : environment handling
;
	.model small
	.386

include emtrap.inc
include ememory.inc

	public CopyEnv, TgtPgmEnvSeg, SetEnvName, QualifyName
	public TgtPgmEnvSpaceUsed,TgtPgmEnvSeg,TgtPgmEnvLen,TgtPgmNamePtr
	public QualifyWithGRDBPath

	.data
TgtPgmEnvSeg	dw	0	;their program's environment
TgtPgmEnvLen	dw	0	;and its length
TgtPgmEnvSpaceUsed dw	0	;how much of it is used
TgtPgmNamePtr dw	0	;where to put the program name
FullTgtPgmName	db	0,':\',77 DUP (0)	;bucket for fully qualified
						;filename
	.code
;
; create memory for their env
;
MakeEnv	PROC
	mov	fs,[psp]
	mov	ax,fs:[2ch]
	dec	ax
	mov	fs,ax
	mov	bx,fs:[3]
	add	bx,8		; add space so we can be sure prog path will fit
	mov	[TgtPgmEnvLen],bx
	shl	[TgtPgmEnvLen],4
	mov	ah,48h
	int	21h
	jc	me_err
	mov	[TgtPgmEnvSeg],ax
	clc
me_err:
	ret
MakeEnv	ENDP
;
; copy our env to their space
;
CopyEnv PROC
	push	si
	call	MakeEnv
	pop	si
	jc	cm_err
	push	es
	push	ds
	push	si
	mov	es,[TgtPgmEnvSeg]
	mov	ds,[psp]
	mov	ds,ds:[2ch]
	sub	di,di
	sub	si,si
ce_lp:
	lodsb
	stosb
	or	al,al
	jnz	ce_lp
	lodsb
	stosb
	or	al,al
	jnz	ce_lp
	mov	ax,1
	stosw
	pop	si
	pop	ds
	pop	es
	mov	[TgtPgmNamePtr],di
	call	SetEnvName
cm_err:
	ret
CopyEnv ENDP
SetEnvName	PROC
	mov	di,[TgtPgmNamePtr]	; subroutine to tag the name with the env
	push	es
	mov	es,[TgtPgmEnvSeg]
	push	si
sevl:
	lodsb
	stosb
	or	al,al
	jnz	sevl
	pop	si
	pop	es
	mov	[TgtPgmEnvSpaceUsed],di
       	clc
	ret
SetEnvName	ENDP
;
; qualify the name with a full path
;
; will parse '..' sequences if they come FIRST
;
QualifyName     PROC
	test	byte ptr [si],0ffh	; no file name, get out
        jz      qnx
        cmp     byte ptr [si+1],':'
        jz      qnx
	push	si 			; get drive
	mov	ah,19h
	int	21h
	add	al,'A'
	mov	[FullTgtPgmName],al
        cmp     byte ptr [si],'\'
        jnz     qnfp
        mov     di,offset FullTgtPgmName+2
qnl3:
        lodsb
        stosb
        or      al,al
        jnz     qnl3
        pop     di
        jmp     qnfin
qnfp:
	sub	dl,dl
	mov	ah,47h			; now get path
	mov	si,offset FullTgtPgmName+3
	int	21h
	mov	di,si
	sub	di,3
	mov	cx,-1
	sub	al,al
	repnz	scasb
	dec	di
        cmp     byte ptr [di-1],'\'
        jz      qnnoslash
	mov	al,'\'			; append '\' char
	stosb
qnnoslash:
	pop	si
	push	si
qnl1:
	cmp	byte ptr [si],'.'	; check for ..
	jnz	nback
	cmp	byte ptr [si+1],'.'
	jnz	nback
	dec	di   			; yep, scan back past last dir
	dec	di
	std
	mov	al,'\'
	repnz	scasb
	cld
	add	di,2			; and loop
	add	si,3
	jmp	qnl1
nback:
	lodsb				; now do string copy
	stosb
	or	al,al
	jnz	nback
	pop	di			; copy it back to the orig buf
qnfin:
	mov	si, offset FullTgtPgmName
qnl2:
	lodsb
	stosb
	or	al,al
	jnz	qnl2
qnx:
        ret
QualifyName     ENDP

QualifyWithGRDBPath PROC
	push	si
	push	ds
	push	di
	mov	ds,[psp]
	mov	ds,ds:[2ch]
	sub si,si
qwglp:
	lodsb
	or	al,al
	jnz	qwglp
	lodsb
	or	al,al
	jnz	qwglp
	inc	si
	inc si
	pop di
	mov	cx,di
qwglp2:
	lodsb
	stosb
	or al,al
	jnz qwglp2
	pop	ds
qwglp3:	
	cmp	byte ptr [di-1],'\'
	jz qwgf
	dec di
	cmp	di,cx
	jnz	qwglp3
qwgf:
	pop si
qwglp4:
	lodsb
	stosb
	or	al,al
	jnz	qwglp4
	ret
QualifyWithGRDBPath ENDP
	end
