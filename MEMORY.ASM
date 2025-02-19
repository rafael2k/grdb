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
; MEMORY.ASM
;
; Function: Handle various memory-management tasks
;
	;MASM MODE
	.MODEL SMALL
	.386


include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include  ebreaks.inc 
include eloader.inc
include eoptions.inc

	PUBLIC ReleaseMemory,tagarena, ResizeMem, ReleaseDebugMem

        extrn endofcode : byte

	.data

	.CODE
;
; resize mem
;
ResizeMem PROC
        mov     ax,seg endofcode
	sub	ax,[psp]
        mov     bx,offset endofcode
        add     bx,15
	shr	bx,4
	add	bx,ax
	mov	ah,4ah
	push	es
	mov	es,[psp]
	int	21h
	pop	es
	ret
ResizeMem ENDP
;
; release all memory belonging to a given PSP
;
ReleaseDebugMem	PROC
	mov	cx,[psp]
	jmp	dorelease
ReleaseDebugMem	ENDP
ReleaseMemory PROC
	mov	cx,[userbasepsp]
dorelease	proc
	push	es
	mov	ah,52h	
	int	21h
	mov	bx,es:[bx-2]
	pop	es
	sub	dx,dx
rm_lp:
	mov	fs,bx
	inc	bx
	cmp	byte ptr fs:[0],'M'
	jz	rm_ok
	cmp	byte ptr fs:[0],'Z'
	jz	rm_ok
	PRINT_MESSAGE	<13,10,"Warning : Arena trashed">
rm_xit:
	ret
rm_ok:
	mov	ax,fs:[1]
	test	ax,-1
	jz	docombine
	cmp	cx,ax
	jnz	uncombine
	mov	word ptr fs:[1],0	
	sub	ax,ax
docombine:
	or	dx,dx
	jz	firstcombine
	mov	gs,dx
	mov	ax,fs:[3]
	inc	ax
	add	gs:[3],ax
	mov	al,fs:[0]
	mov	gs:[0],al
	jmp	join
uncombine:
	sub	dx,dx
	jmp	join
firstcombine:
	mov	dx,fs
join:
	cmp	byte ptr fs:[0],'Z'
	jz	rm_xit
	add	bx,fs:[3]
	jmp	rm_lp
dorelease	ENDP
ReleaseMemory ENDP
;
; tag an arena entry with a name
;
tagarena PROC
	push	es
	push	si
	push	di
	push	cx
	mov	es,bx
	mov	es:[1],ax
	push	si
taxl:
	lodsb
	or	al,al
	jz	taxx
	cmp	al,'\'
	jnz	taxl
	xchg	[esp],si
	jmp	taxl
taxx:
	pop	si
	mov	di,8
	mov	cx,8
talp:
	lodsb
	or	al,al
	jz	tadn
	cmp	al,'.'
	jz	tadn
	cmp	al,'a'
	jc	nouc
	sub	al,20h
nouc:
	stosb
	loop	talp
tadn:
	jcxz	noo
    	mov	byte ptr es:[di],0
noo:
	pop	cx
	pop	di
	pop	si
	pop	es
	ret
tagarena ENDP
end
