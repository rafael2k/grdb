;    GRDB - debugger for dos with 32-bit extensions
;    Copyright (C) 1997-2006  David Lindauer
;
; dual monitor support provided by
;
;	Lawrence E. Boothby
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
; prints.asm
;
;  Function: Print utilities.  All I/O with monitor is logged
;
;
	;MASM MODE
	.model small
	.386

include elogging.inc
include eoptions.inc
include iwindow.inc
include edpmi.inc
include eints.inc
include eansi.inc
        PUBLIC  printspace,printdword,printword,printbyte, printdecimal
	PUBLIC	PureChar, PutChar, GetKey, PrintFollowingMessage, scankey
	PUBLIC  crlf, olMessage, dgroupMessage
        public  getcurpos, setcurpos, blockcurs, underlinecurs, getcurshape
        public  getcurpos2, setcurpos2, clearscreen, basicputchar

		extrn wnd_full : BYTE, wnd_cmd : BYTE, gtb_mono : PROC
        extrn w_putcmdch : PROC, optfs : BYTE, w_putpurech : PROC, optstoponkey : BYTE
        extrn w_getcur: PROC, w_setcur:PROC, optfs: byte, w_putcur : PROC
        extrn w_setwind : PROC, w_clrwnd: proc
		extrn curwindow : WORD, w_framechar : PROC
        .data
curshape        dw      0
attrib  db	C_DEFAULT
dpmiregs	dw	25	dup (0)

	.code

;
; dump a message
; INPUT: BX points at message
;	NOTE: This proc is identical to olmessage below. Maybe this one
;	exists only for exercise in dreaming up labels.
;
dgroupMessage	PROC
	push	dx		;preserve DX
dil:
	mov	dl,[bx]
	inc	bx
	or	dl,dl
	jz	dix
	call	PutChar
	jmp	dil
dix:
	mov	al,C_DEFAULT
	mov	[attrib],al
	pop	dx
	ret
dgroupMessage	ENDP

PrintFollowingMessage	Proc
; had to use bp because in DPMI under WIN2K, if
; use ESP mode and the stack is not aligned to a 4-byte boundary,
; it crashes
	push	bp
	mov		bp,sp	
	xchg	bx,[bp + 2]
	call	olmessage
	xchg	bx,[bp + 2]
	pop		bp
	ret
PrintFollowingMessage	Endp

olMessage Proc
	push	dx
mlp:
	mov	dl,cs:[bx]
	inc	bx
	or	dl,dl
	jz	nomore
	call	putchar
	jmp	mlp
nomore:
	pop	dx
	ret
olMessage ENDP

;
; print a (pure) char
;
; chars are limited to ASCII unless the pure video option is set,
; in chich case we display everything but a few control chars the
; BIOS will try to interpret and wreck our display
;
purechar	PROC
	test	[optdosio],0ffh
        jnz     unpure
	test	[optpure],0ffh
        jnz     purefix
unpure:
	cmp	dl,20h
	jc	npure1
	cmp	dl,80h
	jc	PutChar
npure1:
	mov	dl,'.'
	jmp	PutChar

purefix:
	cmp	dl,20h
	jnc	putchar
	cmp	dl,13
	jz	ccr
	cmp	dl,10
	jz	ccr
	cmp	dl,7
	jz	ccr
	cmp	dl,8
	jz	ccr
	cmp	dl,9
	jz	ccr
	cmp	dl,10h
	jc	ccr	
	jmp	putchar
ccr:
	mov	dl,'.'
purechar	ENDP
;
; normal put char via bios or dos.  Also logs to disk
;
putchar	PROC
	push	bx
        mov     ah,0fh
        int     10h
        mov     bh,0
	mov	bl,15
	mov	al,dl
	cmp	al,9
	jz	dotab
	cmp	al,010h
	jc	occon
	cmp	al,20h
	jae	occon
	mov	[attrib],al
	call	isansimode
	jnc		ona
	call	ansicolor
ona:
	pop	bx
	ret
ocx:
	push	bx
occon:
	call	logtofile
	test	[optsyntaxcoloring],0ffh
	jnz		nodefaultcolor
	mov		ah,C_DEFAULT
	mov		[attrib],ah
nodefaultcolor:
ifndef NOFS
	test	[optfs],255
	jz		colornofs
	mov	bx,[curwindow]
	mov	ah,[attrib]
	sub	ah,10h
	mov	[bx].color,ah
	jmp	nocolor
colornofs:
endif
	test	[optdm],255
	jz		colornodm
	push	es
	push	ax
	call	gtb_mono
	mov		es,ax
	pop		ax
	mov		ah,[attrib]
	sub		ah,10h
	mov		es:[0fa1h], ah
	pop		es
	jmp		nocolor
colornodm:
	cmp	al,20h
	jnc	docolor
	cmp	al,13
	jz	nocolor
	cmp	al,10
	jz	nocolor
	cmp	al,7
	jz	nocolor
	cmp	al,8
	jz	nocolor
	cmp	al,9
	jz	nocolor
docolor:
	push	dx
	push	cx
	push	ax
	call	getcurpos
	mov		ah,[attrib]
	sub		ah,10h
	mov		al,' '
	call	w_framechar
	pop		ax
	pop		cx
	pop		dx
nocolor:
ifndef NOFS
        test    [optfs],255
        jz      pcq2
        call     w_putcmdch
        pop     bx
        ret
pcq2:
endif
dio:
	test	[optdosio],0ffh
	jnz	pcdos
	mov	ah,0eh
;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag, LEB 10-09-2005
        jz      int10
        int     2Bh
        db      3dh     ;cmp ax,10cdh (skips the INT 10h)
int10:  int     10h
;***********************************************************************
	pop	bx
	ret
pcdos:
	push	dx
	mov	dl,al
	mov	ah,2
	int	21h
	pop	dx
	pop	bx
	ret
basicputchar:
	push	bx
	jmp		dio
dotab:
	push	cx
;****************************** this code added for dual monitors ******
        call    getcurpos3              ;LEB 10-09-2005
;***********************************************************************
        movzx   cx,dl
	inc	cl
	and	cl,7
	neg	cl
	add	cl,8
dtl:
	mov	al,20h
	call	ocx
	loop	dtl
	pop	cx
	pop	bx
	ret
putchar	ENDP
;
; keyboard input via bios
;
getkey 	PROC
	test	[optdosio],0ffh
	jnz	dosgetkey
	sub	ax,ax
	int	16h
	ret
getkey ENDP
dosgetkey PROC
	test	cs:[indpmi],1
	jz	dgk_c
	; in dpmi, we just use the BIOS for keyboard input
	; windows didn't like the calldown to DOS
	sub	ax,ax
	int	16h
	ret
dgk_c:
	push	dx
dgkl:
	mov	ah,6
	mov	dl,0ffh
	int	21h
	jz	dgkl
	or	al,al
	pop	dx
        jnz     dgkr
dgkl2:
	mov	ah,6
	mov	dl,0ffh
	int	21h
        jz      dgkl2
        mov     ah,al
        sub     al,al
        ret
dgkr:
		cmp	al,10
		jz	dosgetkey
        sub     ah,ah
        ret
dosgetkey	ENDP

dosgetkey2	PROC
	push	dx
	jnz	dgknv
	test	cs:[indpmi],1
	jz	dgk2_c
	; in dpmi, we just use the BIOS for keyboard input
	sub	ax,ax
	int	16h
	jmp	dgknv
dgk2_c:
	mov	ah,6
	mov	dl,0ffh
	int	21h
dgknv:
	pop	dx
	cmp	al,10
	jz	dosgetkey
	ret
	
dosgetkey2	ENDP
;
; keyboard scan, used to halt long D and U commands
;
scankey	PROC
        test    [optstoponkey],0ffh
        jz      scandone
	test	[optdosio],0ffh
	jnz	dosscankey
	mov	ah,1
	int	16h
	jz	scandone
	pushf
	call	getkey
	popf
scandone:
	ret
dosscankey:
        push    dx
        mov     ah,6
        mov     dl,0ffh
        int     21h
        pop     dx
	ret

scankey	ENDP
;
; put out a space
;
printspace:
	push	dx
	mov	dl,20h		; Get a space
	call	PutChar
	pop	dx
	ret
;
; put out a CR/LF sequence
;
crlf:
	push	dx
	mov	dl,13		; Get a CR
	call	PutChar
	mov	dl,10		; Get a LF
	call	PutChar
	pop	dx
	ret
;
; print various hex numbers
;
printdword:
	push	eax		; To print a dword
	shr	eax,16		; Print the high 16 bits
	call	printword
	pop	eax		; And the low 16 bits
printword:
	push	ax		; To print a word
	mov	al,ah		; Print the high byte
	call	printbyte
	pop	ax		; And the low byte
printbyte:
	push	ax		; To print a byte
	shr	al,4		; Print the high nibble
	call	printnibble
	pop	ax		; And the low nibble
printnibble:
	and	al,0fh		; Get a nibble
	add	al,'0'		; Make it numeric
	cmp	al,'9'		; If supposed to be alphabetic
	jle	onib
	add	al,7		; Add 7
onib:
	push	dx		; Save DX through the call
	mov	dl,al
	call	PutChar
	pop	dx		;
	ret

printdecimal PROC
        push    bx
        push    dx
        push    cx
        mov     bx,10
        sub     cx,cx
pdl1:
        sub     dx,dx
        div     bx
        push    dx
        inc     cx
        or      ax,ax
        jnz     pdl1

pdl2:
        pop     ax
        add     al,'0'
        call    onib
        loop    pdl2
        pop     cx
        pop     dx
        pop     bx
        ret
printdecimal ENDP
getcurpos PROC
ifndef NOFS
        test    [optfs],255
        jz      getcurpos2
        push    bx
        sub     bx,bx
        call    w_setwind
        mov     bx,ax
        call    w_getcur
        pop     bx
        ret
endif
getcurpos ENDP
getcurpos2 PROC
        mov     bh,00
getcurpos3:                     ;bh may not be 00 from this entry
        push    si
        push    di
        mov     ah,03
;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag      LEB 10-09-2005
        jz      sm_getcurpos2        
        mov     dx,03b4h        ;secondary PCI video adapter index port
        mov     ax,0f0eh
        out     dx,al
        inc     dx              ;to data port
        in      al,dx
        xchg    al,ah           ;save al and get next index
        dec     dx              ;back to index port
        out     dx,al
        inc dx                  ;to data port again        
        in      al,dx
        mov     dl,50h          ;convert to column
        div     dl
        xchg    al,ah           ;get column of current row
        xchg    ax,dx           ;bios uses dx
        mov     cx,0d0eh        ;default cursor shape = underline
        db 3dh                  ;cmp ax,10cdh to skips int 10h
sm_getcurpos2:
        int     10h
;***********************************************************************
        pop     di
        pop     si
        ret
getcurpos2 ENDP
setcurpos PROC
ifndef NOFS
        test    [optfs],255
        jz      setcurpos2
        push    bx
        sub     bx,bx
        call    w_setwind
        mov     bx,ax
        call    w_setcur
        call    w_putcur
        pop     bx
        ret
endif
setcurpos ENDP
setcurpos2 PROC
        push    si
        push    di
		call	isansimode
		jnc		sc2na
		call	ansicursor
		pop		di
		pop		si
		ret
sc2na:
        mov     ah,2
        mov     bh,0
;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag      LEB 10-09-2005
        jz      sm_setcurpos2        
        int     2bh
        db 3dh                  ;cmp ax,10cdh saves a jmp and one byte
sm_setcurpos2:
        int     10h
;***********************************************************************
        pop     di
        pop     si
        ret
setcurpos2 ENDP
getcurshape PROC
        call    getcurpos2      ;LEB 10-08-2005 (had called getcurpos which
        mov     [curshape],cx   ;when FS mode never initializes cx)
        ret
getcurshape ENDP
blockcurs PROC
		call	isansimode
		jnc		bcna
		stc
		call	ansicursor
		ret
bcna:
        mov     cx,[curshape]
        mov     ch,0
;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag      LEB 10-09-2005
        jnz     dualcurs
;***********************************************************************
        mov     ah,1
        int     10h
        ret
blockcurs ENDP
;****************************** this code added for dual monitors ******
dualcurs      PROC              ;enter with ch = cursor start line
        push    dx
        mov     dx,03B4h        ;monochrome CRTC IO port
        mov     al,0Ah
        out     dx,al           ;index register
        inc     dx
        mov     al,ch           ;0=block, 0Dh=underline cursor start line
        out     dx,al
        pop     dx
        ret
dualcurs      ENDP
;***********************************************************************
underlinecurs PROC
		call	isansimode
		jnc		ucna
		clc
		call	ansicursor
		ret
ucna:
        mov     cx,[curshape]
;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag      LEB 10-09-2005
        jnz     dualcurs      
;***********************************************************************
        mov     ah,1
        int     10h
        ret
underlinecurs ENDP

clearscreen PROC
ifndef NOFS
        test    [optfs],0ffh
        jnz     csnofs
        mov     bx,offset wnd_full
        jmp     short csj
csnofs:
        mov     bx, offset wnd_cmd
csj:
		jmp     w_clrwnd	
else
        mov     ax,600h
        mov     ch,0
        mov     cl,0
        mov     dh,25
        mov     dl,80
        mov     bh,7   ;this destroys BX
;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag, LEB 10-09-2005
        jz      cscroll
        push    es
		push	ax
		call	gtb_mono
		mov		es,ax
		pop		ax
        xchg    ax,di           ;save AL
        mov     al,ch
        mov     bl,50h
        mul     bl
        xor     ch,ch           ;counting on ch=00 below too
        add     ax,cx 
        xchg    ax,di
        shl     di,1            ;es:di-->beginning of window in frame buffer
        or      al,al           ;al=00 or 01
        xchg    ax,bx           ;get color into ah
        mov     al,20h          ;space fill character
        jz      fill
        ;scroll dh rows and dl columns with es:di==>upper left corner
        dec     dh              ;last row is a fill
next_row:
        mov     cl,dl
        lea     si,[di+0a0h]
        push    si
        rep
        db 26h  ;es:            can override source segment  
        movsw 
        pop     di
        dec     dh
        jnz     next_row
        inc     dh              ;to do fill
fill:   mov     cl,dl           ;last line of window if finishing scroll
        push    di
        rep     stosw
        pop     di
        lea     di,[di+0a0h]
        dec     dh
        jnz     fill
        pop     es
        jmp     short w_scrollx
;***********************************************************************
w_scroll:
        add     dx,cx           ;moved down here so don't have to undo
        sub     dx,0101h        ;for dual monitor case
        int     10h
        ret
endif
clearscreen ENDP
END