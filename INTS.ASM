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
; INTS.ASM
;
; Function: Interrupt table management
;
	.model small
	.386
	
include eoptions.inc
include eprints.inc
include emtrap.inc
include edpmi.inc

	public SetRMInts,IntSnapShot, ReleaseRMInts
	public SetVectAttrib, IntPage, int21adr, orgpic, int20adr
	public SwapIntPage
	.data
orgpic dw	0	; original pic masks (high byte = 21h)

	.code
intpage	dw	0	; segment of interrupt save page
int20adr	dd	0	;NOT fully implemented
int21adr	dd	0	; their version of int 21h
;
; keep the VECTLIST upper bit in sync with the options code
;
SetVectAttrib	PROC
	mov	ah,al
	lodsb
	add	si,3
	xchg	al,ah
	cmp	ah,0ffh
	jz	tv_End
	cmp	al,ah
	jnz	SetVectAttrib
	xor	bl,1
	mov	byte ptr [si-3],bl
tv_end:
	ret
SetVectAttrib	ENDP
;
; read vectlist and insert all our interrupts
;
; they are ONLY there during GO, tracing will bypass them
; and they won't be visible during idles
;
SetRMInts	PROC
	call swapintpage
	call	compatibleZeroPage
	mov		fs,ax
	cli
mi_lp:
	lodsw             		; vect num & addr
	mov		bx,ax
	lodsw
	test	bh,1
	jnz	testdone		; high bit means, don't modify
	sub	bh,bh
	shl	bx,2  			; else overwrite
	mov	fs:[bx],ax
	mov	ax,[realCS]
	mov	fs:[bx+2],ax
	jmp	mi_lp
testdone:
	cmp	bl,0ffh
	jnz	mi_lp
	sti
	ret
SetRMInts	ENDP
;
; read vectlist and restore the old interrupts from the int page
;
ReleaseRMInts	PROC
	call	compatibleZeroPage
	mov	fs,ax
	call	compatibleIntPage
	mov	gs,ax
	cli
rmi_lp:
	lodsw             		; vect num & addr
	mov		bx,ax
	lodsw
	test	bh,1
	jnz	testdone		; high bit means, don't modify
	sub	bh,bh
	shl	bx,2                    ; else overrwrite
	mov	ax,gs:[bx]
	mov	fs:[bx],ax
	mov	ax,gs:[bx+2]
	mov	fs:[bx+2],ax
	jmp	rmi_lp
rtestdone:
	cmp	bl,0ffh
	jnz	rmi_lp
	mov	eax,cs:[int20adr]	; now restore int20h in case they
	mov	fs:[20h*4],eax   	; changed it
	mov	eax,cs:[int21adr]	; now restore int21h in case they
	mov	fs:[21h*4],eax   	; changed it
	call swapintpage
	sti
	ret
ReleaseRMInts	ENDP
;
; generic swap int pages
; 
swapintpage PROC
	pushf
	pushad
	push	ds
	push	es
	call	compatibleIntPage
	mov		ds,ax
	call	compatibleZeroPage
	mov		es,ax
	mov		cx,256
	sub		si,si
	cld
sip_lp:
	lodsd
	xchg	es:[si-4],eax
	mov		[si -4],eax
	loop	sip_lp
	pop		es
	pop		ds
	popad
	popf
	ret
swapintpage ENDP
;
; take a snapshot of all interrupts at program start
;
; we will unload EVERYTHING when we exit or when the program ends
;
IntSnapShot PROC
	test	[intpage],-1
	jnz		gotpage
	mov	bx,40h
	mov	ah,48h
	int	21h
	jc	isn_err
	mov	[intpage],ax
gotpage:
	call	their1b
	in	al,21h			; get pic masks
	xchg	al,ah
	in	al,0a1h
	mov	[orgpic],ax
	sub	di,di
	mov	bx,[intpage]
	sub	si,si
	push	ds
	push	es
	mov	es,bx
	mov	ds,si
	mov	cx,100h
	rep	movsd
	mov	eax,ds:[21h*4]		; now back up int 21h
	mov	cs:[int21adr],eax	; to the changeable address
	mov	eax,ds:[20h*4]		; now back up int 21h
	mov	cs:[int20adr],eax	; to the changeable address
	pop	es
	pop	ds
	call	our1b
	clc
isn_err:
	ret
IntSnapShot ENDP
	end
