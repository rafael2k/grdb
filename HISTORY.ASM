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
; HISTORY.ASM
;
; Function: Handle command line history
;
	;MASM MODE
	.MODEL SMALL
	.386
HISTSIZE EQU 1024	; MUST be longer than longest command line!!!!
			; but shorter than 32K

include	eprints.inc 
include	einput.inc 
include ainput.inc
include	emtrap.inc 
include	ebreaks.inc 
include	eloader.inc
include	edos.inc
include	eoptions.inc
include	eexec.inc
include	ememory.inc
include	elogging.inc
include esymbol.inc
include edpmi.inc

	PUBLIC CheckHistory, EnterHistory, LoadHistory, histoff,histon
        PUBLIC ResetHistory, histseg, cmdchanged

	.data
oldhistory	db	0	;to keep track of when history opt changes
		db	0	; safety net for pushing value
histlen		dw	0	;length of history segment
histseg 	dw	0	;history segment itself
histpos 	dw	0	;position in history segment
lastcmd         dw      0       ;last cmd done
nonext		db	0	; flag to not do first find next after new
                                ; command entered
cmdchanged      db      0       ; command has changed
histechobuf     db      IBSIZE + 1 DUP (?) 

	.code
histonm		db	13,10,"History enabled",0
histoffm		db	13,10,"History disabled",0
histerrm		db	13,10,"No mem for history",0
histmsg 	db	" (History access)",0
;
; turn history off temporarily
;
histoff proc
	mov	ax,word ptr [oldhistory]
	push	bp
	mov		bp,sp
	xchg	ax,[bp+2]
	pop		bp
	mov	[oldhistory],0
	jmp	ax
histoff endp
;
; turn history back on
;
histon	proc
	pop	ax
	pop	word ptr [oldhistory]
	jmp	ax
histon	endp
	
; log that we are doing a history access
;
CommandToLog PROC
        push    di
nobkspc:
	mov	bx,offset histmsg	; now log a message saying we
cllp:					; did this
	mov	al,cs:[bx]
	or	al,al
	jz	clnd
	inc	bx
	call	LogToFile
	jmp	cllp
clnd:
	pop	di
	ret
CommandToLog ENDP
;
; go back one history line
;
findprev proc
	mov	di,[histpos]	; start here
	or	di,di		; check if here is beginning
	jnz	prevnowrap
	add	di,[histlen]	; yes,start at end

prevnowrap:
	dec	di		; point back one char
	or	di,di
	jle	zerprev		; get out if past zero
	test	byte ptr es:[di-1],0ffh	; check for null terminator
	jnz	prevnowrap	; loop if not
	mov	[histpos],di	; else exit with pointer
	ret

zerprev:
	sub	di,di		; zero pointer
	mov	[histpos],di
	ret
findprev endp
;
; go forward one history line
;
findnext proc
	mov	di,[histpos]	; start here
	test	[nonext],1
	jnz	nofindnext
fnlp:
	inc	di		; inc di
	cmp	di,[histlen]	; see if past end
	jae	zernext		; yes, zero
	test	byte ptr es:[di-1],0ffh	; no, test for null term
	jnz	fnlp        	; loop until found
	mov	[histpos],di	; exit with pointer
	ret
zernext:
	sub	di,di       	;
	mov	[histpos],di
	ret
nofindnext:
	mov	[nonext],0
	ret
findnext endp
;
; compare two strings
;
compare1 proc
	jcxz	matches
	push	cx
	push	si
	push	di
	repe	cmpsb
	pop	di
	pop	si
	pop	cx
	ret
matches:
	sub	ax,ax
	ret
compare1 endp
;
; search to see if in history list
;
search1	proc
	push	es
	call	compatibleHistSeg
	mov		es,ax
	sub	di,di
	mov	[histpos],di
lp:
	call	stringsize
	mov	cx,ax
        dec     cx
	call	compare1
        jz      founds
nomatch:
	call	findnext
	or	di,di
	jnz	lp
	pop	es
	stc
	ret
founds:
        mov     bx,cx
        cmp     byte ptr [si+bx],0dh
        jnz     nomatch
	pop	es
	clc
	ret
search1	endp
;
; find the size of a string, including null terminator
;
stringsize proc
	push	di
	push	cx
	mov	cx,-1
	sub	al,al
	repne	scasb
	not	cx
	mov	ax,cx
	pop	cx
	pop	di
	ret
stringsize endp
;
; string copy back to main buffer
;
copystring proc
	lodsb
	stosb
	or	al,al
	jz	csend
	jmp	copystring
csend:
	dec	di
	ret
copystring endp


ResetHistory PROC
        push    es
        test    [lastcmd],0
        jz      rhx
		call	compatibleHistSeg
		mov		es,ax
        cmp     [lastcmd],5000h
        jz      upwind
downwind:
        call    findnext
        jmp     rhx
upwind:
        call    findprev
rhx:
        mov     [lastcmd],0
        pop     es
        ret
ResetHistory ENDP
CheckHistory PROC
	push	di
	push	si
	push	es
	test	[oldhistory],1	;history on?
	jz	okcheck
	test	[histlen],-1	; anything in history buf?
	jz	okcheck
	mov	cx,di		; calculate length of input
	sub	cx,si
        test    [cmdchanged],1
        jz      nochg
        push    si
        push    cx
        mov     si,offset InputBuffer
        mov     cx,IBSIZE
        mov     di,offset histechobuf
        cld
        rep     movsb
        pop     cx
        pop     si
        mov     [cmdchanged],0
nochg:
	cmp	ax,3d00h	; F3 key
	jz	dof3
	cmp	ax,5000h	; down arrow
	jz	up
	cmp	ax,4800h	; up arrow
	clc
	jnz	okcheck
down:
        mov     [lastcmd],ax
        mov     di,offset histechobuf
        mov     si,di
        call    stringsize
        mov     cx,ax
        dec     cx
		call	compatibleHistSeg
		mov		es,ax
        mov     di,[histpos]
        mov     ax,di
        or      di,di
        jz      dof3l
        test    byte ptr es:[di-1],0ffh
        jz      dof3l
        call    findprev
        mov     [histpos],di
        mov     ax,di
dof3l:
        push    ax
        call    findprev
        call    compare1
        pop     ax
        jz      found
        cmp     ax,[histpos]
        jnz     dof3l
        pop     es
        pop     si
        pop     di
        call    EndOfLine
        ret
dof3:
		call	compatibleHistSeg
		mov		es,ax
        mov     di,[histpos]
        jmp     found        
up:
        mov     [lastcmd],ax
        mov     di,offset histechobuf
        mov     si,di
        call    stringsize
        mov     cx,ax
        dec     cx
		call	compatibleHistSeg
		mov		es,ax
        mov     di,[histpos]
        mov     ax,di
        or      di,di
        jz      upl
        test    byte ptr es:[di-1],0ffh
        jz      upl
        call    findprev
        mov     [histpos],di
        mov     ax,di
upl:
        push    ax
        call    findnext
        call    compare1
        pop     ax
        jz      found
        cmp     ax,[histpos]
        jnz     upl
        pop     es
        pop     si
        pop     di
        call    EndOfLine
        ret
found:
	call	CommandToLog	; output the command
	pop	es		; found, swap seg regs
	push	di
	stc
	mov		di,[esp + 4]
	call	EraseLine
	pop		di
	push	es
	push	ds
	call	compatibleHistSeg
	mov		ds,ax
	mov	si,di           	; put string in input buffer
	mov	di,offset inputbuffer
	call	copystring
	pop	ds
	pop	es
	pop	si
	pop	di
	mov		di, offset inputbuffer
    call    PutLine
	stc
	ret
nokcheck:
	stc
okcheck:
	pop	es
	pop	si
	pop	di
	ret

CheckHistory ENDP

;
; add a new line to the history segment
;
EnterHistory PROC
	test	[oldhistory],1		; history on ?
	jz	noenter
	mov	cx,di			; yes, any chars besides CR?
	sub	cx,si
	cmp	cx,1
	jbe	noenter			; no, get out
	push	di     			; is in hist list?
	push	cx
	push	[histpos]
	call	search1
        jnc     foundx
        pop     [histpos]
	pop	cx
	pop	di
	push	es
	push	si
	call	compatibleHistSeg
	mov		es,ax
ehsl:
	sub	di,di			; di = pointer to first string
	mov	ax,HISTSIZE		; See if enough room for new string
	sub	ax,[histlen]
	sub	ax,cx
	jnc	enoughroom		; yes, go insert new string
	push	cx			; no, get size of first string
	call	stringsize
	mov	cx,HISTSIZE		; count to move = seg size - string size
	sub	cx,ax
	mov	si,di
	add	si,ax			; SI = second string
	push	ds
	push	ax
	call	compatibleHistSeg
	mov		ds,ax
	pop		ax
	rep	movsb			; cancel out first string
	pop	ds
	sub	[histlen],ax
	pop	cx
	jmp	ehsl			; loop
enoughroom:
	mov	di,[histlen]		; add new length to hist seg
        mov     [histpos],di
	pop	si
	push	si
	push	di
	add	[histlen],cx
	rep	movsb       		; concat new string
	mov	byte ptr es:[di-1],0	; null terminator
	pop	di
	pop	si
	pop	es
noenter:

        ret
foundx:
        pop     ax
	pop	cx
	pop	di
	ret
EnterHistory ENDP
;
; turn history on or off
;
LoadHistory PROC
	sub	ah,ah
	mov	al,[opthist]  		; see if history flag changed
	cmp	al,[oldhistory]
	jz	nochange		; get out if not
        call    CloseLogFile            ; close the log file
	call	KillFiles		; else clear mem state to allow
	call	ReleaseMemory		; the change
	test	[opthist],0ffh		; turning on?
	jnz	doload			; yes, turn on
	push	es
	call	compatibleHistSeg
	mov		es,ax
	mov	ah,49h
	int	21h
	mov	[oldhistory],0		; flag off
	pop	es
        call    unloadsym
        call    loadsym
	mov	bx,offset histoffm	; history off message
	jmp	reload
doload:
        call    unloadsym
	mov	bx,HISTSIZE SHR 4	; load history seg
	mov	ax,4800h
	int	21h
	mov	bx, offset histerrm
	mov	[opthist],0		; assume it didn't succeed
	jc	reload
	mov	[oldhistory],1		; turn on history
	mov	[opthist],1
	mov	[histseg],ax		; init the vars
	mov	[histlen],0
	mov	[histpos],0
	mov	[nonext],1
        call    loadsym
	mov	bx, offset histonm	; history on message
reload:
	call	olMessage
	mov	si,offset grdbname	; reload empty program
	call	MakeEmptyProg
	sub	ax,ax
	test	[loadfile],0ffh
	jz	nochange
	call	LoadProgram		; reload user program
	lahf
nochange:
	ret
LoadHistory ENDP

end