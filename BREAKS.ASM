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
; breaks.asm
;
; handle breakpoint setting, resetting, enabling, commands
;
	;MASM MODE
	.model small
	.386

include  eprints.inc 
include  emtrap.inc 
include  einput.inc 
include  ehbreak.inc
include edpmi.inc
include eoptions.inc

        PUBLIC  setbreak, breaks, enableBreaks, disableBreaks, CheckIfBreak
        public  deferedbreaks, enableonebreak, breakenum, breaklist
	.data
breaklist dq 16 DUP (?)		; List of breakpoints
	; first dword offset
	; next word - cs (alias)
	; next word - cs (display)
breakhold db 16 dup (?)		; List of values where 'int 3' has covered
				; the opcode
breakenum dw	0		; Flags telling which breakpoints are set
deferedbreaks db 0              ; true if a single step should result in
                                ; breakpoints being set then a run
	
	.code
;
; Command to set a breakpoint comes here
; INPUT: AX contains break number
;	EBX contains break address
;
setbreak	PROC	
	push	ebx		;save break address
	call	defCS		; set default CS reg in DX
	and	ax,0fh		; Set the breakpoint set bit
	bts	[breakenum],ax	;set in breaknum bitmap
	shl	ax,3		;dword index into breaklist
	add	ax,offset breaklist	;plus offset
	xchg	eax,ebx		;AX=address,BX=break index
	mov	[bx],eax		;set break offset
	mov [bx+6],dx
	test 	cs:[inDPMI],1
	jz	nondpmi
	push bx
	mov	bx,dx	; dpmi, make an alias for the CS
	mov	ax,0ah
	int	31h	
	mov	dx,ax
	pop bx
nondpmi:
	mov	[bx + 4],dx	;and segment in list
	pop	ebx		;restore break address
	ret
setbreak	ENDP	
;
; Command to clear a breakpoint comes here
; INPUT: AX has break number to clear in bitmap
;
clearbreak	PROC	
	and	ax,0fh		; Reset the flag bit
	btr	[breakenum],ax	;
	test 	cs:[inDPMI],1
	jz	nondpm2
	push	bx			; dpmi; remove the CS alias
	mov	bx,ax
	shl	bx,3
	mov	bx,word ptr [bx + breaklist + 4]
	mov	ax,1
	int	31h
	pop	bx
nondpm2:
	ret
clearbreak	ENDP	
;
; Command to display a breakpoint comes here
; INPUT: AX contains index into breaknum bitmap
;
displaybreak	PROC	
	and	ax,0fh		; just in case (shouldn't happen)
	bt	[breakenum],ax	; see if this one is set
	jnc	short nodisplay	; Quit with no disp if this one not set
	push	ax		; save index
	call	crlf		; new line
	pop	ax		; restore index
	push	ax		; save again
	call	printbyte	; Print breakpoint #
	mov	dl,':'		; Print ':'
	call	PutChar
	call	printspace
	pop	bx		; restore index
	shl	bx,3		; cvt to dword index
	add	bx,offset breaklist	;offset from breaklist
	mov	ax,WORD PTR [bx + 6]	; Print segment
	call	printword	;
	mov	dl,':'		; Print ':'
	call	PutChar
	mov	eax,[bx]		; Print offset
	call	bit32Address
	jz		bpw
	call	printdword
	jmp		bpj
bpw:
	call	printword      
bpj:
nodisplay:
	ret
displaybreak	ENDP	
;
; When GO or TRAP or PROCEED commands execute, they call this to
; see if sitting on a breakpoint
;
CheckIfBreak    PROC    
        mov     cx,15
stblp:
        bt      [breakenum],cx
        jnc     stbnn
        mov     bx,cx
        shl     bx,3
        mov     eax,[regdumpEIP]
        cmp     eax,dword ptr [bx + breaklist]
        jnz     stbnn
        mov     ax,[regdumpCS]
        cmp     ax,word ptr [bx + breaklist + 6]
        jnz     stbnn
        or      [deferedbreaks],1
        stc
        ret
stbnn:
        dec     cx
        jns     stblp
        clc
        ret
CheckIfBreak    ENDP
;
; When GO or TRAP or PROCEED commands execute, they call this to
; enable breakpoints
;
enableonebreak PROC
	bt	[breakenum],cx	; If not set
	jnc	short ebnn	; Don't do anything
	mov	bx,cx
	shl	bx,3
	mov	fs,WORD PTR [bx + breaklist + 4]
	mov	esi,dword ptr [bx + breaklist]
	mov	al,fs:[esi]	; Get the byte at that location
	mov	BYTE PTR fs:[esi],0cch	; Put an int 3
	mov	bx,cx
	mov	[bx + breakhold],al	; Save it for restore
ebnn:
        ret
enableonebreak ENDP
EnableBreaks    PROC
	mov	cx,15		; For each breakpoint
eblp:
        call    enableonebreak 
	dec	cx		; Next breakpoint
	jns	eblp		;
        call    hdwebreakenable ; set DR7 for hardware break
	ret	
enableBreaks	ENDP	
;
; Int 3 or int 1 call this to disable breakpoints and restore the
; values covered by the int 3
;
disableBreaks	PROC	
	mov	cx,15		; For each breakpoint
dblp:
	bt	[breakenum],cx	; If not set
	jnc	short dbnn	; Go nothing
	mov	bx,cx
	mov	al,[bx + breakhold]	;get byte overwritten with CC
	shl	bx,3
	mov	esi,dword ptr [bx + breaklist]	;find break address in
	mov	fs,WORD PTR [bx + breaklist + 4]	;fs:si
	mov	fs:[esi],al	; and put original byte back
dbnn:
	dec	cx
	jns	dblp		; Next breakpoint
	mov	ax,0
	call	ClearBreak
	call	hdwebreakdisable ;turn off breaks in DR7
	ret
disableBreaks	ENDP	
;
; Handle breakpoint-related commands
; INPUT: SI points to input line text
;	
;
breaks	PROC	
	call	WadeSpace	; Wade through spaces
	jz	short showall	; Show all breakpoints
	cmp	al,'d'   	; branch off to hdwe routines
	je	hdwebreakcommand; if necessary
	cmp	al,'-'		; Else check for '-'
	pushf			;
	jne	noinc		;
	inc	si		; Skip to next arg
	call	WadeSpace	;
noinc:
	cmp	al,'*'		;clear everything?
	je	clearall	;do it if so
	call    ReadNumber	; Read break number
	jc	short badbreak2	; Exit if error
	cmp	ax,16		; Make sure in range
	jae	short badbreak2	; Exit if error
	or	ax,ax		; Can't do anything with break #0, it's automatic
	jz	short badbreak2	;
	popf			;
	push	ax		; save break number
	jz	short unmake	; If was '-', clear break
	call	WadeSpace	; Else wade to next arg
	jz	badbreak2	; error if not found
	call	ReadAddress	; Read the bp address
	pop	ax		; restore break number
	jc	short badbreak	; Quit if error
	call	setbreak	; Set breakpoint at this address
	jmp	short breakdone	; Get out
unmake:
	call	WadeSpace	; Wade to end
	pop	ax		; restore break number
	jnz	short badbreak	; If there is more we have an error
	call	clearbreak	; Clear breakpoint
	jmp	short breakdone	; Get out
clearall:
	popf			; ZF if -*, NZ if just * no -
	jnz	short badbreak	; not a clear
	inc	si		; next arg
	call	WadeSpace	; find it
	jnz	short	badbreak	;can't be more on line here
	mov	ax,15
cbl:
	push	ax
	call	clearbreak
	pop	ax
	dec	ax
	jns cbl
	jmp	breakdone	;and get out
showall:
	test	[breakenum],0ffffh	;are any breaks set now?
	jnz	doshow		; if so, show them
	PRINT_MESSAGE	<13,10,"No breakpoints enabled">
	clc
	ret

doshow:
	mov	cx,15		; For each breakpoint
salp:
	mov	ax,cx		; Display it if set
	call	displaybreak	;
	loop	salp		; for all possible 16 of them
breakdone:
	clc			; Exit, no errors
	ret
badbreak2:
	pop	ax		;
badbreak:
	stc			; Exit, errors
	ret
breaks	ENDP	
END
