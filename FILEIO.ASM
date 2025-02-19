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
; FILEIO.ASM
;
; Function: Handle File read/wrote commands
;
	;MASM MODE
	.MODEL SMALL
	.386


include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include  ebreaks.inc 
include  eloader.inc
include  edos.inc
include eexec.inc
include eints.inc
include edpmi.inc

	PUBLIC dofileread, dofilewrite, FileLoadErr

	.data
EXEfileFlag	db	0		;if EXE file, can't write it
writelen	dd	0		;length to write
writeseg	dw	0		;segment and
writeofs	dw	0		; offset to write
newaddr		db	0		;if @addr used
writeFileName	db	256 DUP (0)	;name of file to write

	.CODE
;
; read from file
;
doFileRead PROC
	call	noCommandInDPMI
        push    0               ; any load ok
	call	WadeSpace
	jz	PureReadFile	; branch if reloading same program
	pop	ax		; else assume anything goes
	push	0
	cmp	byte ptr [si],'@' ; else see if the load-exe-as-com flag set
	jnz	comonly		; branch if so
	inc	si		; else anything goes
	pop	ax		; com only!!!
	push	1
comonly:
	cmp	byte ptr [si],'-' ; see if they want to unload
	jnz	newfile
	pop	ax		; clear stack
	call	UnLoadProgram	; yes do it
	clc
	ret
newfile:
	call	WadeSpace	; if no prog, go read the old one again
	jz	PureReadFile
	call	ParseProgName
PureReadFile:
	pop	ax		; com/exe flag
	call	LoadProgram	; call the com/exe loader
	call	FileLoadErr
	ret
doFileRead ENDP
FileLoadErr	PROC
	jc	lperr		; handle errors
	PRINT_MESSAGE	<10,13,"Size: ">
	mov	eax,FileLen
	call	Printdword
	clc
	ret
lperr:
	PRINT_MESSAGE	<10,13,"Read error">
	clc

	ret
FileLoadErr	ENDP
;
; file write subroutine
;
WriteProgram	PROC
	mov ax,3c00h			; Open the file
	mov dx,offset writeFileName
	sub	cx,cx
	int 21h
	mov bx,ax
	jc failure

	mov	ecx,[writelen]
	mov	si,[writeseg]
	mov	dx,[writeofs]
	push	ds
wdlp:
	push	ecx
	mov	ds,si
	mov ax,4000h			; Read the file
	cmp	ecx,8000h
	jc	cursize
	mov cx,8000h
cursize:
	call swapintpage
	int 21h
	call swapintpage
	jc failure2
	pop	ecx
	add	si,800h
	sub	ecx,8000h
	jnc	wdlp
	clc
failure2:
	pop	ds
failure:
	pushf
	mov	ax,3e00H
	int	21h
	popf
	ret
WriteProgram ENDP
;
; file write command
;
doFileWrite PROC
	call	noCommandInDPMI
	push	si
	mov	[newaddr],0
	mov	si,offset loadfile	; move the original file name
	mov	di,offset writeFileName
fnl_lp:
	lodsb
	stosb
	or	al,al
	jnz	fnl_lp
	mov	al,[exeflag] 			; set default params
	mov	[EXEfileFlag],al     		; can't write EXE
	mov	eax,[filelen]
	mov	[writelen],eax
	mov	ax,[userbasepsp]
	add	ax,10H
	mov	[writeseg],ax
	mov	[writeofs],0
	pop	si
	call	WadeSpace			; if no args go to write routine
	jz	dowrite
	cmp	al,'@'				; see if address
	jnz	gname
	mov	[EXEfileFlag],0			; yes update params
	mov	[writelen],0
	mov	[writeFileName],0
	mov	[newaddr],1
	inc	si
	call	ReadAddress
	jc	wn_err
	call	defDS				; get DS
	mov	eax,ebx
	shr	eax,4
	add	edx,eax
	and	ebx,15
	mov	[writeofs],bx
	mov	[writeseg],dx
	test	edx,0FFF00000H
	jnz	wn_err
gname:
	call	WadeSpace 			; now see if there is a name
	jz	dowrite
	cmp	al,','				; noname, get a length
	jz	getnum
	mov	[EXEfileFlag],0			; else get name
	mov	di,offset writeFileName
fclp:
	mov	byte ptr [di],0
	lodsb
	cmp	al,13
	jz	dowrite
	cmp	al,' '
	jz	getnum
	cmp	al,','
	jz	getnum
	stosb
	jmp	fclp
getnum:
	call	WadeSpace 			; now see if len
	jz	dowrite
	mov	[EXEfileFlag],0
	call	ReadNumber
	jc	wn_err
	mov	ebx,eax
	call	WadeSpace
	jnz	wn_err
	mov	[WriteLen],ebx
dowrite:
	test	[EXEfileFlag],0FFH		; all params got, see if exe
	jnz	noexewrite			; yes, can't write
	test	[writelen],0FFFFFFFFH		; see if anything
	jz	wn_err				; no,err
	movzx	eax,[writeseg]
	shl	eax,4
	add	eax,[writelen]
	add	eax,0FH
	test	eax,0FFF00000H			; 1 MB limit
	jnz	wn_err
	call	WriteProgram			; write prog
	jnc	nowriterr
	PRINT_MESSAGE	<10,13,"Write error">
nowriterr:
	test	[newaddr],1			; update params
	jnz	nochange
	mov	eax,[writelen]
	mov	[FileLen],eax
	mov	al,[EXEfileFlag]
	mov	[exeflag],al
	mov	si,offset writeFileName
	mov	di,offset loadfile
fnl_lp1:
	lodsb
	stosb
	or	al,al
	jnz	fnl_lp1

nochange:
	clc
	ret
noexewrite:
	PRINT_MESSAGE	<10,13,"Can't write back an EXE file">
	clc
	ret
wn_err:
	stc
	ret
doFileWrite ENDP
end