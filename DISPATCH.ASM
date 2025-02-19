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
; Dispatch.asm
;
; Function: OS Function dispatcher
;   Handles Call to Major function number
;   Handles generic call to function number
;   Handles keeping track of last known error
;
	;MASM MODE
	.model small
	.386
include  eprints.inc

	PUBLIC	TableDispatch, nofunction

	.code
;
; Core dispatch routine.  Calls the subfunction indicated in AL
; and then set the return address to after the dispatch table
; This expects a subfunction code to be on the stack
;
;	As whacked-out a technique as I've seen in awhile. If there's a
;more obscure way of doing something really simple, I don't want to see it.
;ANYWAY, in addition to a subfunction being on the stack whether we need
;one or not, we have the following input conditions:
;	AL contains the index of the routine to be called
;	Immediately following the call to this routine, the number of
;	table elements minus one must be stored right in the code as a
;	word. Immediately following that count, right in the code of the
;	routine itself, must be the addresses of all the routines that
;	can be called, finally followed by the continuing code!
;Processing:
;	1) Using the return address as a pointer, do a range check on the
;	   index to see if it's in range
;	2) Forge a return address to finishup and put it on the stack
;	3) Forge a return address to the routine to call, and stack that
;	4) Load the subfunction from the caller's stack into AX
;	5) Do a near return as a call alias to this function
;	6) When the function returns to finishup, get the original caller's
;	   return address back
;	7) Use it to get the number of entries in the table
;	8) Double the entry count, add 2 bytes for the count and two more
;	   because the count was minus one, and stick that on the stack
;	9) Return to the calculated return address, in the process stripping
;	   the subfunction off the stack.
;
;This entire amazing exercise could have been performed by a single, obvious
;instruction: call local_table[bx]
;sheeesh
;
TableDispatch	PROC	
	ENTER	0,0
	xchg	bx,[bp+2]		; xchg ret address & ebx
	cmp	al,cs:[bx]		; Limit check
	ja	short noaction		; Error if too big
					; Here we call the routine
	push	bp
	push	offset cs:finishup	; Return address
	movzx	eax,al
	movzx	ebx,bx
	push	WORD PTR cs:[ebx+2*eax+2]	; Get code address to stack
	xchg	bx,[bp+2]		; put things as they were
	mov	ax,[bp+4]		; Get the subkey
	cld				; Assume move dir up
	ret				; Go to subroutine
	
noaction:
	call	nofunction		; Register bad function error
finishup:
	; Now we have to find the return address
	pop		bp
	xchg	bx,[bp+2]		; Get return address
	push	eax
	movzx	eax,word ptr cs:[bx]
	movzx	ebx,bx
	lea	ebx,[ebx+2*eax+4]	; Get offset to return address
	pop	eax
	xchg	bx,[bp+2]		; Xchg with orig value of ebx
	LEAVE
	ret	2
TableDispatch	ENDP	
nofunction	PROC	
	stc				; Set carry flag
	ret
nofunction	ENDP	
END
	
	
	
	
	
	
