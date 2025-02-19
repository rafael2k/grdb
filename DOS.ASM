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
; DOS.ASM
;
; Function: DOS interfac
;
	;MASM MODE
	.MODEL SMALL
	.386


include eprints.inc 
include eenv.inc
include emtrap.inc 
include ememory.inc
include eoptions.inc
include eloader.inc
include eints.inc
include ebreaks.inc
include eswift.inc
include edpmi.inc

	PUBLIC SetUserPSP, SetDebugPSP, userpsp, userdta, UnloadProgram
	PUBLIC int20handle,int21handle, KillFiles
	PUBLIC int1bh,CtrlBrkPressedInDOS

        extrn   trapcount : dword, proceedcount : dword
ifndef NOFS
        extrn   optfs: byte, w_swapscreen : PROC
endif
	.data
CtrlBrkPressedInDOS	db	0	;flag this event
int20warn               db      0
userpsp			dw	0	;their PSp
userdta         dw  80h
                dw  0   ; their psp seg by default
	.CODE
spawncount      dw      0       ; nonzero if spawned
;
; PSP switching
;
SetDebugPSP	PROC
	test	cs:[indpmi],1
	jnz nodtaset
	mov	ah,51h		;undocumented call to get PSP
	int	21h
	mov	[userpsp],bx	;save user's psp segment
	mov	bx,[psp]	;and set up ours
	mov	ah,50h		;using another undocumented call
	int	21h
    push es         ; wipes ES
    mov ah,2fh      ; get DTA
    int 21h
    mov [userdta],bx    ; save it
    mov [userdta+2],es
    pop es
	push ds
	mov bx,80h		; set our DTA
	mov ds,[psp]
	mov ah,1ah
	int 21h
	pop ds
nodtaset:
	ret
SetDebugPSP	ENDP


SetUserPSP	PROC
	mov	bx,[userpsp]	;get target pgm PSP
	test	cs:[inDPMI],1
	jnz	noresetdta
	mov	ah,50h		;and set as current
	int	21h
    push ds             ; going to use ds
    lds dx,dword ptr [userdta]   ; get their DTA
    mov ah,1ah          ; write it back
    int 21h             ;
    pop ds
noresetdta:
	ret
SetUserPSP	ENDP
;
; ctrl-break handling
;
int1bh	PROC
	pushf
	push	es
	push	bp
	call	untrace
int1bcont:
	call	compatibleES
	mov	es:[CtrlBrkPressedInDOS],1	; assume in dos
	push	es			;save our data seg 
	les	bp,es:[indos]		;inDOS flag at ES:BP
	test	byte ptr es:[bp],0FFh	;see if any bits set
	pop	es			;restore our data seg
	jnz	int1bhid		; in dos is easy, break when it exits
					; via int 21h handler
	mov	es:[CtrlBrkPressedInDOS],0	; else start a single step handler
	push	0			;set ES to 0
	pop	es

;point int1 at our stepper routine

	mov	word ptr es:[4],offset cs:stepper ; don't worry about killing
	mov	word ptr es:[6],cs	; primary tracer, it will get fixed
	mov	bp,sp			;point BP at stack

;Um. [bp+6] points to the return address, so [bp+A] points to the flags
;pushed by the int.  Flag bit 8 is TF, and we set it to enable single-step
;debugging

	or	word ptr [bp+6+4],0100h	;set trap flag upon IRET
int1bhid:
	pop	bp
	pop	es
	popf
	iret
;
; ctrl-break single-stepper.  When ctrl-break comes in the IRET frame
; on the stack will point into the BIOS area.  The following routine
; single-steps the processor until we are out of the BIOS and back
; in the area bounded by GRDB's PSP and the EOM
;

stepper:
	pushf					
	push	es
	push	bp
	mov	bp,sp
	les	bp,[bp + 6]			;point ES:BP at return adr
	cmp	byte ptr es:[bp],0cfh		;see if next inst is IRET
	jne	int1bpopf			;jmp if it isn't
	mov	bp,sp				;point back at stack


;Let me think. If the next instruction is IRET, we must be nested inside an
;interrupt handler. So we skip past what we pushed, plus the 6 bytes pushed
;by the INT to get here, to the frame of the interrupt handler we are inside.
;We set HIS trap flag.
; Else, if the next instruction is POPF, we OR on a bit at [bp+C]. Now lets
;see. BP+6 points to the IP of this int, so BP+C points to the contents of
;the stack just past our int frame. Since the instruction is POPF, what must
;be on the stack is the flags (whatever it was, it will surely become the
;flags after the POPF). So we set the trap flag in those flags.
; Since POPF and IRET are the only instructions that might wipe our trace
;flag, these are the only cases we need to handle. All other instructions
;will cause this routine to be invoked immediately after execution. So this
;process continues until we're back from both DOS and BIOS and in the
;domain of ourselves or the program we are debugging.

	or	word ptr [bp+4+6+6],100h	; set trace flag in frame
	jmp	int1bhid
int1bpopf:
	cmp	byte ptr es:[bp],9dh		;if next instruction is POPF
	jne	stepperfin
	mov	bp,sp
	or	word ptr [bp+6+6],100h		;do the same thing to us
	jmp	int1bhid
stepperfin:
	call	compatibleES
	mov	bp,sp	 			;ES is our DS, BP is stack

;[BP+8] is the segment on the stack frame for the INT that invoked this
;routine.  See if it's our segment.

	mov	bp,[bp+2+6]			;get segment from stack
	cmp	bp,es:[psp]			;is it our PSP seg?
	jb	int1bhid			;nope, its bigger
	mov	es,es:[psp]			;else get our PSP into ES
	mov	bp,sp				;back to stack
	mov	bp,[bp+2+6]			;get that segment again
	cmp	bp,es:[2]			;??? in our PSP
	jae	int1bhid			;still not us?
	mov	bp,sp				;BP back to stack
	and	word ptr [bp+4+6],NOT 100h	;finally in bounds, off tracing
	call	compatibleES
	mov	es:[CtrlBrkPressedInDOS],1	;set flag
	les	bp,es:[indos]			; just make sure about DOS
	test	byte ptr es:[bp],0FFh		;see if in DOS now
	jnz	int1bhid			; run to completion if so
	push	ax				; else clear pending ints
	mov	al,20h
	out	20h,al				;ACK PIC
	pop	ax
	pop	bp
	pop	es
	popf
	jmp	entry1				; return to debugger

int1bh	ENDP
;
; int 20h exit - not understood yet. Need to determine what int20adr and
; int21adr really point to - our code, or the user's code.
;
int20handle     PROC
        test    [spawncount],-1         ; if they have spawned pass xit to dos
        jz      x20
        jmp     cs:[int20adr]           ;else let user's int20 handle it?
x20:
	call	compatibleDS
	call	compatibleES
	mov	bp,sp			;reach onto stack
	mov	ax,[bp+2]		;to get segment of int 20
	cmp	ax,[userbasepsp]	;is
	je	close20
        inc     [int20warn]
close20:
	JMP	int21exit0
int20handle	ENDP

;
; int 21h handler.  Hooks 4ch,00h, 2521,3521,
; and exits to debugger if ctrl-break pressed
;
int21handle	PROC
        cmp     ah,4bh                ; spawn 
        jnz     int21nospawn
        or      al,al                 ; standard spawn function
        jz      int21spawn
        cmp     al,4                  ; msc uses this for P_NOWAIT
        jz      int21nospawn
int21spawn:
        inc     [spawncount]          ; ok spawned, increment counter
	push	bx			; we have to get the ie flag back
	push	bp
	mov	bp,sp			; all this is a grandiose simulated
	mov	bx,[bp +4+4]		; interrupt
	xchg	bx,[bp+2]
	pop	bp
	call	cs:[int21adr]		; call DOS
	pushf				;save DOS return flags
        dec     [spawncount]            ; end of spawn
        jmp     int21join
int21nospawn:
        test    [spawncount],-1       ; if they spawned, pass to DOS
        jnz      spawned
	cmp	ah,4ch			;exit to DOS command
	je	int21exit4ch		;go if so
	cmp	ah,0			;old exit command
	je	int21exit0		;handle that
spawned:
	cmp	ax,2521h		; hook setting 21h
	jne	chk35			;nope, not doing that
	mov	word ptr cs:[int21adr],dx	;snag hook address
	mov	word ptr cs:[int21adr+2],ds	;from hooking app
	jmp	didvect			;and skip around

chk35:
	cmp	ax,3521h		; hooking reading int 21h
	jne	normchain		;nope, normal?
	mov	bx,word ptr cs:[int21adr]	;return OUR int21 address
	mov	es,word ptr cs:[int21adr+2]	;in this case

;We get here if the program being debugged was either setting or getting
;the DOS dispatch vector INT 21h.

didvect:
	push	bx			; we have to get the flags back now
	push	bp
	mov	bp,sp			;point to stack
	mov	bx,[bp+4+4]		;flags from int 21
	xchg	bx,[bp+2]		;xchg with our BX
	pop	bp			;flags now on top of stack
	jmp	int21join		;this will do popf, retf 2
int21handle	ENDP

normchain:
	push	bx			; we have to get the ie flag back
	push	bp
	mov	bp,sp			; all this is a grandiose simulated
	mov	bx,[bp +4+4]		; interrupt
	xchg	bx,[bp+2]
	pop	bp
	call	cs:[int21adr]		; call DOS
	pushf				;save DOS return flags
int21join:
	push	bp
	push	es
	call	compatibleES
	test	es:[CtrlBrkPressedInDOS],1
	pop	es
	jnz	i21brk			; yep- go to DOS
	pop	bp
	popf				; NO, RETURN
	retf	2

;Oh brother! Well, we pushed the DOS return flags, then BP. AX contains
;the DOS return value. We set bp to sp and push AX. NOW the stack
;contains flags, bp, ax. [bp+2] points to the flags. For reasons unknown,
;we DON'T just MOV ax,[bp+2], we XCHG! NOW the flags are in AX and [bp+2]
;contains the DOS return value. So we pop AX from the push, pop
;bp, and ADD SP,2 to THROW AWAY the AX value we carefully put on the stack
;using XCHG! WHY? Why not pop bp, pop ax and just leave out the push ax
;and the add sp,2? Thats why we used XCHG in the first place, right?
;  Anyway, we got here if control-break was pressed in DOS, so we are
;taking the DOS return flags from the REAL DOS and placing them on the
;stack for the debugger's return from this int21 handler.

i21brk:
	mov	bp,sp
	push	ax
	xchg	ax,[bp+2]		; get DOS return flags to stack
	mov	[bp+2+6],ax		; and hit the debugger
	pop	ax
	pop	bp
	add	sp,2
	jmp	entry1
;
; DOS exit request comes here
;
	
int21exit0	PROC
	sub	ax,ax
int21exit0	ENDP



int21exit4ch	PROC
	cld
	call	untrace
	call	compatibleDS
	call	compatibleES
	mov	ss,[stackseg]
	mov	sp,[stackofs]
	sti
	mov	[trapcount],0
        mov     [proceedcount],0
	mov	[CtrlBrkPressedInDOS],0
	push	ax
	mov	si,offset dgroup : veclist	; unhook ints
	call	ReleaseRMInts
	call	SetDebugPSP		; debug PSP
	call	disableBreaks	; Disable breakpoints if not
ifndef NOFS
        test    [optfs],255
        jz      nofsq
        mov     al,1
        call    w_swapscreen
nofsq:
endif
        test    [int20warn],255
        jz      noint20warn
	PRINT_MESSAGE	<13,10,"Warning : Int 20h with CS <> PSP (program will crash)">
        mov     [int20warn],0
noint20warn:
        PRINT_MESSAGE   <13,10,"Normal exit, exit code: ">
	pop	ax
	call	PrintByte	; error code
	call	crlf
	call	UnLoadProgram	; unload the program
        test    [exeflag],0ffh  ; see if was EXE
	jz	rex
	mov	ax,[lastcs]	; yep, refresh CS:EIP
	mov	[RegdumpCS],ax
	mov	eax,[lastip]
	mov	[RegdumpEIP],eax
rex:
	jmp	reentry
int21exit4ch	ENDP
;
; unload program
;
UnLoadProgram	PROC
	call	IntSnapShot	; reinit int table
	call	KillFiles	; kill their files
	call	ReleaseMemory	; release memory
	mov	si,offset dgroup : grdbname	; make an empty program
	call	MakeEmptyProg
	ret
UnLoadProgram	ENDP
;
; kill program files by reading the handle table and closing them all
;
KillFiles PROC
	call	SetUserPSP
	mov	fs,bx
	mov	cx,fs:[32h]
kf_lp:
	dec	cx
	mov	bx,cx
	mov	ah,3eh
	int	21h
	cmp	cx,6
	jae	kf_lp
	call	SetDebugPSP
	ret
KillFiles	ENDP
end