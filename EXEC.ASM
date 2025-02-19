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
; EXEC.ASM
;
; Function: Handle T,G,P commands
;
	;MASM MODE
	.model small
	.386

include iasm.inc
include iopcodes.inc
include easm.inc
include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include  ebreaks.inc 
include  edos.inc
include  eints.inc
include eregs.inc
include eswift.inc
include erm32.inc
include edpmi.inc
include eoptions.inc

STEPFLAG = 100h                 ; 80386 single step enable flag

        PUBLIC go,trap, proceed, ReTrap, GoTrap, proceedone, proceedcount
        Public TrapCount, callcheck, cmpstring, wadeprefix

        extrn w_swapscreen : PROC

        .code
        extrn incs32:byte, traceon:byte

	.data
trapcount	dd	0	;number of traps left to do or zero for none
proceedcount    dd      0       ; number of proceeds left to do or zero for none
pfx67flag       dw      0       ;flag if 67h prefix found during call check

;All possible prefixes

pretab	db	0f0h,0f2h,0f3h,026h,02eh,036h,03eh,064h,065h,066h,067h

;String functions

stringtab db	0a6h,0a7h,6ch,6dh
	db	0ach,0adh,0a4h,0a5h
	db	06eh,06fh,0aeh,0afh
	db	0aah,0abh

	.code
;
	assume ds:nothing	; going to call from where DS is moot
;
callcheck	proc
	mov	ah,fs:[ebx]	; Load the first byte of the instruction
	cmp	ah,0ceh		; into?
	mov	al,1
	jz	chx
	cmp	ah,0cdh		; Interrupt ?
	mov	al,2		; two bytes
	jz	chx		; I do this because some int calls are
				; misbehaved and won't restore the trap flag
	cmp	ah,0e8h		; Near Call?
	mov	al,3		; Yes, this is 3 bytes
        jz      chxx            ; And execute it
	cmp	ah,09ah		; Far call
	mov	al,5		; This one is 5 bytes
        jz      chxx            ; Not either of these, just trap
	mov	ax,fs:[ebx]
	and	ax,038FFH
	cmp	ax,010ffh
	jz	gotind
	cmp	ax,018ffh
	jz	gotind
	ret
gotind:
	mov	al,2  		; two bytes base
	mov	ah,fs:[ebx+1]
       	and	ah,0c7h
	cmp	ah,0c0h		; mod 3, through reg is 2 bytes
	jnc	chx
        test    [incs32],1
        jnz     bkwds
	test	[pfx67flag],0ffh	; check 16/32 address mode flag
	jnz	call32
        jmp     call16
bkwds:
        test    [pfx67flag],0ffh
        jz      call32
call16:
	cmp	ah,8		; 16 bit, MOD=0
	jnc	chk16m1
	cmp	ah,6		; yes, direct offset?
	jnz	chx
	add	al,2		; yes 4 bytes total
	jmp	chx
chk16m1:
	and	ah,0c0h		; check for mod 1 or 2
	js	is16m2
	inc	al		; mod 1, add a byte for offset
	jmp	chx
is16m2:
	add	al,2		; else mod 2, two byte offset
	jmp	chx
call32:
	cmp	ah,6		; 32 bit mode, check for 32-bit offset
	jnz	ch32m0
	add	al,4		; yep, add 4
	jmp	ch32sib
ch32m0:
	cmp	ah,8   		; MOD = 0?
	jc	ch32sib		; yep, check for sib
ch32m1:
	or	ah,ah		; MOD = 1?
	js	ch32m2
	add	al,1   		; yep, 1 byte offset
	jmp	ch32sib
ch32m2:
	add	al,4   		; else mod 2
ch32sib:
	and	ah,7
	cmp	ah,4
	jnz	chx
	inc	al		; add in the SIB byte
	mov	ah,byte ptr fs:[ebx+1]	; test for MOD 3
	and	ah,0c0h
	cmp	ah,0c0h
	jz	chx		; yep, no further bytes
	mov	ah,byte ptr fs:[ebx+2] ; get SIB byte
	and	ah,7		; check for EBP special cases
	cmp	ah,5
	jnz	chx
	inc	al
	test	byte ptr fs:[ebx+1],40h ; check if one or 4 bytes disp
	jz	chx
	add	al,3		; MOD 1,3, need 4 bytes
chx:
	add	al,dl		; fix for prefixes
	sub	ah,ah		; clear Z flag...
	ret
chxx:
		test	cs:[inDPMI],1
		jz		chxx1
		test	cs:[dpmiType],1
		jnz		chxx2
chxx1:
        test    [incs32],1
        jz      chx
chxx2:
        add     al,2
        jmp     chx
callcheck	endp
; used by P command to wade through prefixes to find out if
; we have a string instruction
;
wadeprefix:
	mov	[pfx67flag],0
	sub	dx,dx
wp_lp:
	mov	al,fs:[ebx]
	mov	di,offset pretab
	mov	cx,11
	repnz	scasb
	jnz	wp_done
	inc	bx
	inc	dx
	cmp	al,67h
	jnz	wp_lp
	bts	[pfx67flag],0		; flag the addrsiz in case of call
	jmp	wp_lp
wp_done:
	ret
	
cmpstring:
	mov	al,fs:[ebx]
	mov	di,offset stringtab
	mov	cx,14
	repnz	scasb
	ret
;
	assume	ds:dgroup	; DS ok again
;
; Execute program
;
go	PROC	
	Call	WadeSpace	; Wade till address
	jz	dogo
	cmp	al,'='
	jnz	checkbreak
	inc	si
	call	ReadAddress
	jc	goerr
	mov	dword ptr [RegdumpEIP],ebx	; Fix CS:EIP for new routine
	call	defCS		; get CS
checkbreak:
	call	WadeSpace	; Wade
	jz	short dogo	;
	call	ReadAddress	; Read break address
	jc	goerr		; Quit if errir
dogo2:
	sub	ax,ax		; Break 0
	call	SetBreak	; Set the break
dogo:
        sub     al,al
        call    w_swapscreen
        call    CheckIfBreak
        jc      retrap          ; sitting on a breakpoint, just do a trap
                                ; and the trap routine will get things
                                ; going when it triggers
	call	EnableBreaks	; Enable breaks
	xor	ax,ax		; Not trapping
	jmp	gotrap	; Run the code
goerr:
	stc
	ret
go	ENDP	
;
;
; Limited and semi-buggy proced function
;
PROCEED	PROC	
	call	WadeSpace
        jz      proceedone
	cmp	al,'r'
        jnz     pcount
	inc	si
	call	WadeSpace
	jnz	perr
	push	es
	call	CSCompatibleDS
	mov		es,ax
    mov     es:[traceon],1
	pop		es
    sub     ax,ax
	jmp	gotrap
pcount:
        call    ReadNumber
        jc      perr
        dec     eax
        mov     [proceedcount],eax
        call    wadespace
        jnz     perr
PROCEED endp
proceedone PROC
	mov	ebx,dword ptr [RegdumpEIP]	;
	mov	fs,[RegdumpCS]	;
	call	wadeprefix	; wade through all prefixes
	call	callcheck  	; noew check for near  & far calls
	jz	short pgo	; and execute it
	mov	ah,fs:[ebx]
        mov     al,2
        add     al,dl
	cmp	ah,0e0h		; Check for loop instructions
	jz	short	pgo
	cmp	ah,0e1h
	jz	short	pgo
	cmp	ah,0e2h
	jz	short	pgo
	call    cmpstring	; see if is string instruction or loop
	jnz	short dotrap	; Not either of these, just trap
	mov	ax,dx
	inc	ax
pgo:
        push    ax
        sub     al,al
        call    w_swapscreen
        pop     ax
        sub     ah,ah
	mov	ebx,dword ptr [RegdumpEIP]	;
	add	ebx,eax		; Ebx = breakpoint
	mov	dx,[RegdumpCS]	; DX:EBX = position to break at
	sub	ax,ax		; Use the scratch breakpoint
	call	SetBreak	; Set a break
        call    CheckIfBreak
        jc      retrap          ; sitting on a breakpoint, just do a trap
                                ; and the trap routine will get things
                                ; going when it triggers
        test    [proceedcount],-1 ; if doing multiple proceed, ignore breaks
        jnz     pnb 
        test    [slashcmd],-1   ; if slash, same
        jnz     pnb
	call	EnableBreaks	; Enable breakpoints
	sub	ax,ax		; No trapping
	jmp	gotrap	; Run the code
pnb:
        sub     cx,cx           ; enable the temp breakpoint
        call    enableonebreak
	sub	ax,ax		; No trapping
	jmp	gotrap	; Run the code
perr:
	stc
	ret
proceedone ENDP    
;
; Trap command
;
trap	PROC	
	call	WadeSpace
	jz	dotrap
	call	ReadNumber
	jc	terr
	push	eax
	call	WadeSpace
	pop	eax
	jz	tnerr
terr:
	stc
	ret
tnerr:
       	or	eax,eax
	jz	dotrap
	dec	eax
	mov	[trapcount],eax
trap	ENDP
dotrap 	PROC
	mov	fs,[RegdumpCS]	;
	mov	ebx,dword ptr [RegdumpEIP]	;
	call	bit32Address
	jnz	ReTrap	;	can't go into an int in 32-bit mode
	mov	ah,fs:[ebx]	; Load the first byte of the instruction
	sub	al,al
	cmp	ah,0ceh		;int0
	jz	intjn
	cmp	ah,0cdh
	jnz	ReTrap
	mov	al,fs:[ebx+1]
intjn:
	push	ax
	call	compatibleIntPage
	mov		fs,ax
	pop		ax
	movzx	bx,al			; trying to trace through a
	shl	bx,2
	mov	ebx,fs:[ebx]
	push	es			; vector uses the program version
	mov	es,[RegdumpSS]
	mov	di,word ptr [RegdumpESP]
	sub	[RegdumpESP],6
	std
	scasw
	mov	ax,word ptr [RegdumpFLAGS]
	stosw
	mov	ax,[RegdumpCS]
	stosw
	mov	ax,word ptr [RegdumpEIP]
	add	ax,2
	stosw
	cld
	pop	es
	mov	word ptr [RegdumpEIP],bx
	shr	ebx,16
	mov	[RegdumpCS],bx
	call	DisplayRegisters; Display registers
	clc
	ret
dotrap	ENDP
ReTrap	PROC
        mov     ax,STEPFLAG     ; Are trapping on instruction
gotrap	PROC

	push	ax
	mov	si,offset dgroup : veclist	; enable ints
	call	SetRMInts
	call	SetUserPSP
	pop	ax
	mov	ss,[RegdumpSS]
	mov	esp,[RegdumpESP]	; Load toss
        movzx   eax,ax
        or      eax,dword ptr [RegdumpFLAGS]      ; Fill stack frame with FLAGS , CS:EIP
        test    [traceon],1
        jnz     deferrunup
        call    cs32runup       ; will only do it if it needs to, if not
                                ; will come back
deferrunup:
	test	cs:[indpmi],1
	jz		dpmi16orreal
	test	cs:[dpmitype],1
	jz		dpmi16orreal
	push	eax
	push	0		;
	push	[RegdumpCS]
	push	dword ptr [RegdumpEIP]
	jmp		dpmijoin
dpmi16orreal:
	push	ax		;
	push	[RegdumpCS]
	push	word ptr [RegdumpEIP]
dpmijoin:
	push	[RegdumpDS]
	mov	es,[RegdumpES]
	mov	fs,[RegdumpFS]
	mov	gs,[RegdumpGS]
	mov	eax,[RegdumpEAX]	; Load regs
	mov	ebx,[RegdumpEBX]	;
	mov	ecx,[RegdumpECX]	;
	mov	edx,[RegdumpEDX]	;
	mov	esi,[RegdumpESI]	;
	mov	edi,[RegdumpEDI]	;
	mov	ebp,[RegdumpEBP]	;
	pop	ds		; Load DS
        test    [traceon],1  ; if PR go handle first instruction
	jz	doiret
	call	swiftrace
	call	DisplayRegisters; if it was an int 3 come back
        jmp     reentry
doiret:
	test	cs:[inDPMI],1
	jz		real
	test	cs:[dpmitype],1
	jnz		dpmi32
dpmi16:
	push	es
	mov		es,cs:[codeAlias]
	mov		es:[inDPMI], 0
	pop		es
real:
	iret
dpmi32:
	push	es
	mov		es,cs:[codeAlias]
	mov		es:[inDPMI], 0
	pop		es
	iretd
gotrap	ENDP
Retrap	ENDP	
end