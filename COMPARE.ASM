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
; COMPARE.ASM
;
; Function: compare memory regions
;
	;MASM MODE
	.MODEL SMALL
	.386

include iwindow.inc
include eprints.inc 
include einput.inc 
include emtrap.inc 
include eoptions.inc
include eints.inc

	PUBLIC	compare
	PUBLIC	paddr


	.CODE

	extrn	clearscreen : proc
;Set DS if valid address provided in input
; INPUT: SI points to input to parse
; OUTPUT: DX contains segment address to use
;	CY if

cra	PROC
	call	ReadAddress		; read source address
	jc	crax			; none found
	call	bit32address;
	jnz	nomvz			;if set, no zero extend
	movzx	ebx,bx			;else extend
nomvz:
	call	defDS			; get data seg
crax:
	ret
cra	ENDP

;INPUT: AL has byte (two hex chars) to print

pbyte	PROC
	call	PrintByte
	call	printspace
	ret
pbyte	ENDP

;INPUT: EDX has segment address
;	EAX has offset address
;If flat real mode, print 32-bit offset, else print 16-bit offset

paddr	PROC
	xchg	eax,edx			;now EDX=offset, EAX=segment
	call	printword		;display segment
	xchg	edx,ebx			;store offset in EBX
	mov	dl,':'			;putchar wants char in DL
	call	putchar			;print colon
	mov	eax,ebx			;put offset in EAX
	call	bit32address;
	jnz	pdw			;if so, do that
	call	printword		;else just 16 bits
	call	printspace
	ret
pdw:
	call	printdword		;print 32-bit offset
	call	printspace
	ret
paddr	ENDP
;
; compare command
; syntax is c start,end,start2
;
compare	PROC
	cmp 	byte ptr [si],'l'
	jnz  	compare1
	cmp		byte ptr [si+1],'s'
	jnz		compare1
	jmp		clearscreen
compare1:
	call	WadeSpace		;find source address
	jz	errx			;not found (end of input)
	call	cra 			;start seg in DX, offset in EBX
	jc	errx			;not found
	push	bp
	push	dx			;save segment
	push	ebx			;and starting offset
	call	WadeSpace		;see if any more
	jz	errx2			;nope, didn't find
        cmp     al,'l'
        jnz     compnl
        inc     si
        call    ReadNumber
        jc      errx2
        mov     ecx,eax
        jmp     compj
compnl:
	call	ReadNumber		; read ending offset
	jc	errx2			;not found
	mov	ecx,eax			;get ending offset into ECX
        inc     ecx
	sub	ecx,ebx			;subtract starting offset
	jb	errx2			;error if end < start
compj:
	call	WadeSpace		;else keep reading input
	jz	errx2			;need a destination
	call	cra			; read dest seg and ofs
	jc	errx2			;not found
	call	WadeSpace		;make sure no more
	jnz	errx2			;if more, syntax error
	call	bit32address;
	jnz	gotsz			;fine if so
	movzx	ebx,bx			;else zero extend dest offset
	movzx	ecx,cx			;and length to compare
	mov		bp,sp
	movzx	eax,word ptr [bp]	;and starting offset (on stack)
	mov	[bp],eax
gotsz:
	pop	esi    			;get start ofs from stack to ESI
	mov	edi,ebx			;and ending offset to EDI
	push	dx			;save segment
clp:
	push	ds			;save current DS
	push	es			;and ES
	mov		bp,sp
	mov	ds,[bp+6]		;pushed as DX just before clp:
	mov	es,[bp+4]		;pushed as DX on line 5 of routine
	cli
	call swapintpage
	db	67h			;dword override on operand
	repe	cmpsb			;cmp ds:[esi] with es:[edi]
	mov	al,ds:[esi-1]		;differing byte from source in AL
	mov	ah,es:[edi-1]		;and dest in AH
	call swapintpage
	sti
	pop	es			;back to our ds
	pop	ds			;and ES
	jz	cdone			;no difference in this case
	mov		bp,sp
	mov	dx,[bp+2]		;now dest segment into DX
	push	ax			;save differing bytes
	call	crlf			;new line
	push	dx
	mov		dl,C_ADDRESS
	call	PutChar
	pop		dx
	mov	eax,esi			;location where different
	dec	eax			;minus cmpsb moved ESI past it
	call	paddr			;show ESI where different
	push	dx
	mov		dl,C_CODEBYTES
	call	PutChar
	pop		dx
	pop	ax			;restore differing bytes
	push	ax			;and save them again
	call	pbyte			;show source byte
	pop	ax			;get them back
	mov	al,ah			;setup dest byte
	call	pbyte			;and show that
	push	dx
	mov		dl,C_ADDRESS
	call	PutChar
	pop		dx
	mov	eax,edi			;get dest offset
	mov		bp,sp
	mov	dx,[bp]		;and dest segment still on stack
	dec	eax			;minus correction for cmps
	call	paddr			;show dest seg:ofs
        jecxz    cdone
	jmp	clp			;find next difference
	
cdone:
	mov		dl,C_DEFAULT
	call	PutChar
	add	sp,4
	pop	bp
	clc				; to clean up stack
	ret
errx2:
	add	sp,6
	pop	bp
errx:
	stc
	ret
compare	endp
end