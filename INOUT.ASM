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
; INOUT.ASM
;
; Function: Handle I,O commands
;
	;MASM MODE
	.MODEL SMALL
	.386


include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include  ebreaks.inc 

	PUBLIC doin,doout

	.CODE
;
; get the size
;
iosize	proc
	sub	cx,cx
	lodsb
	cmp	al,13
	jz	szerr
	cmp	al,'b'
	jz	gotsize
	inc	cx
	cmp	al,'w'
	jz	gotsize
	inc	cx
	cmp	al,'d'
	jz	gotsize
	dec	si
	sub	cx,cx
gotsize:
	shl	cx,1
	clc
	ret
szerr:
	dec	si
	stc
	ret
iosize endp
;
; Read from a port
;
doin	PROC	
	call	iosize
	jc	inerr
	Call	WadeSpace	; Wade till address
	jz	inerr
	call	ReadNumber
	jc	inerr
	mov	edx,eax
	call	WadeSpace
	jnz	inerr
	mov	bx,cx
	jmp	word ptr [bx+intab]
intab	dw	offset inbyte, offset inword, offset indword
inbyte:
	call	crlf
	in	al,dx
      	call	printbyte	; Print data
	clc
	ret
inword:
	call	crlf
	in	ax,dx
      	call	printword	; Print data
	clc
	ret
indword:
	call	crlf
	in	eax,dx
      	call	printdword	; Print data
	clc
	ret
inerr:
	stc
	ret
doin	ENDP
;
; Write to a port
;
doout	PROC
	call	iosize
	jc	outerr
	Call	WadeSpace	; Wade till address
	jz	outerr
	call	ReadNumber
	jc	outerr
	mov	dx,ax
	call	WadeSpace
	jz	outerr
	call	ReadNumber
	jc	outerr
	mov	ebx,eax
	call	WadeSpace
	jnz	outerr
	mov	eax,ebx
	mov	bx,cx
	jmp	[bx + outtab]
outtab	dw	offset outbyte,offset outword, offset outdword
outbyte:
	out	dx,al
	clc
	ret
outword:
	out	dx,ax
	clc
	ret
outdword:
	out	dx,eax
	clc
	ret
outerr:
	ret
doout	ENDP
end
