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
; opthbreaks.asm
;
; handle hardware breakpoints
;
;
	;MASM MODE
	.model small
	.386p

include  eprints.inc 
include  emtrap.inc 
include  einput.inc 
include eoptions.inc
include edpmi.inc

	public hdwebreakcommand
	public hdwebreakenable
	public hdwebreakdisable
	public hdwechk
	.data
bkaddr	df	4 DUP (?)	;breakpoint address, seg:off
bkreg	dd	700h		;mirror of breakpoint enable register
bksets	dw	0		;track which breaks we have set
stacksave	df	?
	.code
;
; enable hardware breaks
;
hdwebreakenable PROC
	test	cs:[inDPMI],1
	jz		hbeo
        mov     ax,cs
        test    ax,3
        jnz     hbe
hbeo:
	test	[opthbreak],255
	jz		hbe
	mov	eax,bkreg	; copy our image to the bp enable reg
	mov	DR7,eax
hbe:
	ret
hdwebreakenable ENDP
;
; disable hardware breaks
;
hdwebreakdisable PROC
	test	cs:[inDPMI],1
	jz		hbdo
        mov     ax,cs
        test    ax,3
        jnz     hbd
hbdo:
	test	[opthbreak],255
	jz		hbd
	mov	eax,700h		; clear the BP enable reg
	mov	DR7,eax
hbd:
	ret
hdwebreakdisable ENDP
;
; display BP data
;
putbpdata2	PROC
	call	crlf		; CRlf #)
	add	dl,'0'
	call	putchar
	mov	dl,')'
	call	putchar
	bt	word ptr [bksets],cx
	jc	putbpdata
	PRINT_MESSAGE	" Not enabled"
	ret
putbpdata2	ENDP

;this routine prints strings based on the value in BX[1:0]. if 0, it prints
;'Execute', if 1, it prints 'Write' if 2 or 3 it prints 'Read/Write'. Then
;it prints 'at address', prints whatever is in [di+2], a colon, then whatever
;is in [di].
;  NOW, BX contains some kind of mode flags and DI points to the break
;address.

putbpdata PROC
	mov	al,bl    	; print mode
	and	al,3
	or	al,al
	jnz	npx
	PRINT_MESSAGE	" Execute   "
	jmp	pbc
npx:
	dec	al
	jnz	nrx
	PRINT_MESSAGE	" Write     "
	jmp	pbc
nrx:
	PRINT_MESSAGE	" Read/Write"
pbc:
	PRINT_MESSAGE	" at Address "	; print address
	mov	ax,[di+4]
	call	printword
	mov	dl,':'
	call	putchar
	mov	eax,[di]
	call	bit32Address
	jnz		putdword
	call	printword
	jmp		putjn
putdword:
	call	printdword
putjn:
	ret
putbpdata ENDP
;
; first thing called from BP routine (int 1)
;
hdwechk PROC
	push	eax
	push	ds
	test	cs:[inDPMI],1
	jz		hwdechko
        mov     ax,cs
        test    ax,3
        jnz     nohdwe
hwdechko:
	call	compatibleDS
	test	[opthbreak],255
	jz		nohdwe
	MOV	eax,DR6			; mask active breakpoints
	and	al,byte ptr [bksets]	; breakpoints set?
	and	al,0fh		;just 4 of them???
	jz	nohdwe		;none set, I guess

	mov	dword ptr [stacksave],esp
	mov word ptr [stacksave + 4],ss
	shl		eax,16
	call	compatibleStackSeg
	mov		ss,ax
	movzx	esp,[stackofs]
	shr		eax,16
	
	push	es		; got a Breakpoint, load regs
	call	compatibleES
	pushad			;save all registers
	push	eax		;ax contains the breakpoint bitmap?
	PRINT_MESSAGE	<10,13,"Hardware breakpoint #">	; message
	pop	eax		;restore bitmap
	mov	di,offset bkaddr	; get address
	mov	bx,word ptr [bkreg+2]	; and mode flags
	mov	cx,4		
hdwechks:
	shr	al,1		; find break - bit into carry flat
	jc	found		;yes, this was it
	shr	bx,4		;else BX has mode flags for this break?
	add	di,6		;and DI has break address pointer
	loop	hdwechks	;find the break

;Well, CX will contain the value 1, 2, 3, or 4. When we put this into DX and
;NEG it, DX will contain FFFF, FFFE, FFFD, or FFFC.  When we add 34h to this,
;DX contains the ASCII codes for 3,2,1 and 0 respectively for CX values of
;1,2,3 and 4.

found:
	mov	dx,cx		; set up for print
	neg	dx		;get 2s complement
	add	dx,'4'		;convert to ascii
	call	putchar		;paint it

;this routine prints strings based on the value in BX[1:0]. if 0, it prints
;'Execute', if 1, it prints 'Write' if 2 or 3 it prints 'Read/Write'. Then
;it prints 'at address', prints whatever is in [di+2], a colon, then whatever
;is in [di].
;  NOW, BX contains some kind of mode flags and DI points to the break
;address.


	call	PutBPData	; do it
	popad
	pop	es
	lss		esp,[stacksave]
	stc			; BP found, break unconditionally
nohdwe:
	pop	ds
	pop	eax
	ret
hdwechk ENDP
;
; command to set/clear breakpoints
;
; bd command comes here from breaks.asm
;
hdwebreakcommand PROC
	test	cs:[inDPMI],1
		jz		okhdwe
        mov     ax,cs
        test    ax,3
        jz      okhdwe
        PRINT_MESSAGE   <13,10,"Command not available in Ring 3 DPMI">
        clc
        ret

okhdwe:
	test	[opthbreak],255
	jnz		okhdwe2
    PRINT_MESSAGE   <13,10,"Command disabled with HB option">
    clc
    ret
	
okhdwe2:

	inc	si
	call	WadeSpace	; if no parms, print all
	jz	printhwd
	cmp	al,'-'		; check for clear
	pushf
	jnz	noinc
	inc	si
	call	WadeSpace
noinc:
	cmp	al,'*'		; clear all
	jz	clearall
	call	ReadNumber	
	jc	bccerr2         ; err?
	movzx	cx,al		; move tp cx
	cmp	al,4   		; check range
	jnc	bccerr2
	popf			; check set/clear
	jnz	doset
	call	WadeSpace
	jnz	bccerr
	btr	[bksets],cx	; reset the masks
	shl	cx,1
	inc	cx
	btr	word ptr [bkreg],cx
	clc
	ret
clearall:
	popf         		; make sure -
	jnz	bccerr
	mov	[bkreg],700h	; now kill all masks
	mov	[bksets],0
	clc
	ret
doset:
	call	WadeSpace	; if nothing else, print it
	jz	print1

	call	ReadAddress	; now read the address
	jc	bccerr
	push	si
	mov	di,0     	; assume exec
	call	WadeSpace
	jz	gotmode2
	cmp	al,'r'         	; check for r
	jnz	chkw
	mov	di,3		; is read/write
	jmp	hbrsize
chkw:
	cmp	al,'w'		; check for w
	jnz	chkx
	mov	di,1		; is write
	jmp	hbrsize
chkx:
	cmp	al,'x'
	jnz	bccerr3
	mov	di,0
hbrsize:
	inc	si		; now get the size
	call	WadeSpace
	jz	gotmode2		; no size, di already set
	call	ReadNumber
	jc	bccerr3
	push	ax
	call	WadeSpace
	pop	ax
	jnz	bccerr3
	movzx	si,al           ; check for size in range
	cmp	si, 4
	ja	bccerr3
	cmp	si,3
	je	bccerr3
	or	si,si
	jz	bccerr3
	dec	si   		; make correct for debug reg
	mov	ax,bx 		; check for alignment
	and	ax,si
	jnz	bccerr3
	or	di,di     	; EXEC size must be one
	jnz	gotmode
	or	si,si
	jnz	bccerr3
gotmode2:
	sub	si,si
gotmode:
	bts	[bksets],cx	; set the first mask
	mov	ax,cx
	shl	cx,1		; the second mask
	inc	cx
	bts	word ptr [bkreg],cx
	dec	cx
	shl	si,2 		; shift the length into place		
	shl	cx,1
	or	si,di		; length & mode shift into place
	shl	si,cl
	or	word ptr [bkreg + 2],si ; and set it up
	or	edx,edx		; check for selector
	jnz	gotsel
	or	di,di		; else si = 0 for xec
	jz	selcs
	sub	dx,dx 		; now assume zero selector (flat real)
	test	[optflat0],1	;
	jnz	gotsel          ;
	mov	dx,[RegdumpDS]	; not exec or flat, use data seg
	jmp	gotsel
selcs:
	mov	dx,[RegdumpCS]	; else exec, use cseg
gotsel:
	mov	si,ax
	add	si,si
	add	si,ax
	add	si,si
	mov	dword ptr [bkaddr+si],ebx
	mov	word ptr [bkaddr+4+si],dx
	test	cs:[inDPMI],1
	jnz		dpmilinear
	movzx	edx,dx		; calculate linear address
	shl	edx,4
	jmp		linearjn
dpmilinear:
	push	ebx
	push	cx
	mov		bx,dx
	mov		ax,6
	int		31h
	shl		ecx,16
	mov		cx,dx
	xchg	ecx,edx	
	pop		cx
	pop		ebx
linearjn:
	add	edx,ebx
	mov	bx,cx		; branch to routine to set appropriate bp addr reg
	add	bx,offset one
	call	bx
	pop	si
	clc
	ret
bccerr3:
	pop	si
	stc
	ret
one:
	mov	DR0,EDX
	ret
two:
	mov	DR1,EDX
	ret
three:
	mov	DR2,EDX
	ret
four:
	mov	DR3,EDX
	ret
;
; print command for one bp comes here
;
print1:
	mov	dx,cx			; get the mode to bl
	shl	cx,2
	mov	bx,word ptr [bkreg + 2]
	shr	bx,cl
	mov	cx,dx
	add	cx,cx
	add	cx,dx
	add	cx,cx
	mov	di,offset bkaddr	; di = ptr to address
	add	di,cx	
	mov	cx,dx
	call	putbpdata2		; print it
	clc
	ret
bccerr2:
	pop	ax
bccerr:
	stc
	ret
;
; print command for all bp comes here
;

printhwd:
	mov	cx,0			; index  = 0
	mov	di,offset bkaddr	; ptr to first bp
	mov	bx,word ptr [bkreg + 2]	; grab modes
phwl:
	push	cx		; display bp
	push	bx
	push	di
	mov	dl,cl		
	call	putbpdata2
	pop	di
	pop	bx
	pop	cx
	shr	bx,4		; shift to next BP
	add	di,6
	inc	cl
	cmp	cl,4
	jc	phwl
	ret
hdwebreakcommand ENDP

	end