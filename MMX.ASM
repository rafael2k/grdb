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
; mmx.asm
;
; Function: Handle MMX register display and input
;
include edpmi.inc
	;MASM MODE
        .model small
        .586

	EXTRN	printspace : PROC
	EXTRN	printdword:PROC
	EXTRN	printword:PROC
	EXTRN	printbyte:PROC
	EXTRN	scankey : PROC
	EXTRN	crlf : PROC

	EXTRN	PureChar : PROC
	EXTRN	PutChar : PROC
	EXTRN	GetKey : PROC
	EXTRN	PrintFollowingMessage : PROC
	EXTRN	olMessage : PROC
	EXTRN	dgroupMessage : PROC
include  emtrap.inc 
include  einput.inc 
include  edis.inc
include  eoptions.inc
include  ehistory.inc
include  eprints.inc
include  iwindow.inc

        extrn cpufeatures:dword
        public ModifyMMXRegisters

        .data
floatstat dw 47 dup (0)
readsel db      0
ten     dw      10

        .code
mmxdump proc
		push	es
		call	CSCompatibleDS
		mov		es,ax
        mov     al,cl
        or      al,30h
        mov     [es:mmdat],al
		pop		es
        push    cx
        call    PrintFollowingMessage
        db      13,10,C_REGISTER,"MM"
mmdat   db 0,C_DEFAULT,":",0
        
        pop     bx
        imul    bx,[ten]
        add     bx,offset floatstat+14
        mov     cx,8
mdl:
        test    cl,1
        jnz     msp
        cmp     cl,8
        jae     msp
        mov     dl,'-'
        call    putchar
        jmp     mjn
msp:
        call    printspace
mjn:
		mov		dl,C_NUMBER
		call	PutChar
        mov     di,cx
        mov     al,[bx+di-1]
        call    printbyte
		mov		dl,C_DEFAULT
		call	PutChar
        loop    mdl
        ret
mmxdump endp
readmmx proc
        movzx   bx,[readsel]
        imul    bx,[ten]
        add     bx,offset floatstat + 14
        fnsave  [floatstat]
        mov     cx,8
rmxl:
        call    ReadNumber
        jc      errx
        mov     di,cx
        mov     [bx+di-1],al
        call    wadespace
        jz      rmxret
        loop    rmxl
rmxret:
        frstor  [floatstat]
        clc
        ret
errx:
        stc
        ret        
readmmx endp
ModifyMMXRegisters proc
        test    [cpufeatures],0800000h
        jnz     mmxavail
        PRINT_MESSAGE <13,10,"Processor does not support MMX">
        clc
        ret
mmxavail:
        call    wadespace
        jnz     modreg
        fnsave  [floatstat]
        frstor  [floatstat]
        sub     cx,cx
mmxdl:
        push    cx
        call    mmxdump
        pop     cx
        inc     cl
        cmp     cl,8
        jc      mmxdl
        clc
        ret
modreg:
        lodsb
        cmp     al,'m'
        jnz      mrn
        lodsb
mrn:
        sub     al,'0'
        jc      rr_out
        cmp     al,8
        jnc     rr_out
        mov     [readsel],al
readregvalue:
	call	WadeSpace
	jz	doregprompt
	inc	si
	cmp	al,':'
	jz	ReadRegValue
	cmp	al,'='
	jz	ReadRegValue
	dec	si
        call    readmmx
	ret
doregprompt:
	push	bx			; Else put up prompt
	push	cx			;
	PRINT_MESSAGE	<13,10,": ">
	call	histoff
	call	GetInputLine		; Get input line
	call	histon
	pop	cx			;
	pop	bx			;
	call	WadeSpace		; Ignore spaces
	jz	short rr_out		; Quit if so
        call    readmmx
	ret
rr_out:
	stc
	ret
ModifyMMXRegisters endp
        end
