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

        extrn w_cmdset : proc, optfs: BYTE, incs32: byte
	PUBLIC  doprogram

	.data
none	db	"none",0
        
	.code
;
doprogram PROC
	inc	si
	call	WadeSpace
	jnz	herr
ifndef NOFS
        test    [optfs],255
        jz      nofsx4
        mov     al,1
        call    w_cmdset
nofsx4:
endif
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "DOS version: ", C_NUMBER>
	mov	al,byte ptr [dosver + 1]
	sub		ah,ah
	call	printdecimal
	mov	dl,'.'
	call	putchar
	mov	al,byte ptr [dosver]
	sub		ah,ah
	call	printdecimal
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "Processor Mode: ", C_RESERVEDWORD>
	test	cs:[incs32],1
	jz		notcs32
	PRINT_MESSAGE	<"RM32">
	jmp		tpjn
notcs32:
	test	cs:[inDPMI],1
	jnz		isdpmi
	.586p
	mov		eax,CR0
	.386
	test	al,1
	jz	isreal
	PRINT_MESSAGE	<"VM86">
	jmp	tpjn
isreal:
	PRINT_MESSAGE	<"Real">
	jmp	tpjn
isdpmi:
	test	cs:[dpmiType],1
	jnz		dpmi32
	PRINT_MESSAGE	<"DPMI/16">
	jmp	tpjn
dpmi32:
	PRINT_MESSAGE	<"DPMI/32">
tpjn:
        call    crlf

	mov	si,offset loadfile	; calc loadfile and command
	mov	di,offset loadcommand
	test	[filelen],-1
	jnz	okprog
	mov	si,offset none
	mov	di,si
okprog:
	test	byte ptr [di],-1
	jnz	okgotdi
	mov	di,offset none
okgotdi:
	test	byte ptr [si],-1
	jnz	okgotsi
	mov	si,offset none
okgotsi:
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "Program:   ", C_RESERVEDWORD>
	mov	bx,si
	call	DgroupMessage
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "Arguments: ", C_RESERVEDWORD>
	mov	bx,di
	call	DgroupMessage
	call	ExeStats			; put out EXE file stats
	call	crlf

	PRINT_MESSAGE	<13,10,C_OPTTEXT, "PSP at ", C_NUMBER>
	mov	ax,[userbasepsp]
	call	PrintWord
	mov	ax,[userpsp]
	cmp	ax,[userbasepsp]
	jz	normpsp
	push	ax              		; display if they have changed it
	call	printspace
	mov	dl,'('
	call	PutChar
	pop	ax
	call	PrintWord
	mov	dl,')'
	call	PutChar
	call	printspace
normpsp:
	PRINT_MESSAGE	<C_OPTTEXT, " with length ", C_NUMBER>
	mov	dx,[userbasepsp]
	dec	dx
	test	cs:[inDPMI],1
	jz		pspnotdpmi
	mov		ax,cs
	call	compatibleUtilitySeg
	mov		fs,ax
	mov		bx,ax
	sub		cx,cx
	shld	cx,dx,4
	shl		dx,4
	mov		ax,7		; set segment base
	int		31h
	jmp		pspjoin
pspnotdpmi:
	mov		fs,dx
pspjoin:
	mov	ax,fs:[3]
	call	PrintWord
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "Environment at ", C_NUMBER>
	mov	ax,[TgtPgmEnvSeg]
	call	PrintWord
	PRINT_MESSAGE	<C_OPTTEXT, " with ", C_NUMBER>
	mov	ax,[TgtPgmEnvSpaceUsed]
	call	Printword
	PRINT_MESSAGE	<C_OPTTEXT, " bytes used of ", C_NUMBER>
	mov	ax,[TgtPgmEnvLen]
	call	PrintWord
	mov		dl,C_DEFAULT
	call	PutChar
	clc
	ret		
herr:
	stc
	ret
doprogram endp
END