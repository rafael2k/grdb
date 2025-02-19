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
; mtrap.asm
;
; Function: handle the all traps.  Int 3 and Int 1 are debug traps and
; are handled specially
	;MASM MODE
	.model small
	.386

	.stack 1024

include iwindow.inc
include iasm.inc
include iopcodes.inc
include  eprints.inc 
include  eregs.inc 
include  einput.inc 
include  ebreaks.inc 
include	 eenv.inc
include  eloader.inc
include  elogging.inc
include  edos.inc
include  eMemory.inc
include  eints.inc
include  eexec.inc
include eoptions.inc
include eloader.inc
include ehistory.inc
include eswift.inc
include efp.inc
include ehbreak.inc
include easm.inc
include erm32.inc
include esymbol.inc
include edpmi.inc
include eansi.inc
	public  entry3,indos,entry1
	PUBLIC	RegdumpFLAGS,RegdumpEAX,RegdumpEBX,RegdumpECX,RegdumpEDX
	PUBLIC	RegdumpESI,RegdumpEDI,RegdumpEBP
	PUBLIC	RegdumpESP,RegdumpEIP
	PUBLIC	RegdumpCS,RegdumpES,RegdumpDS,RegdumpSS,RegdumpFS,RegdumpGS
	PUBLIC	TrapHandler, _exit, psp
	PUBLIC  reentry, grdbname, veclist, entry1
	PUBLIC	stackseg,stackofs, dosver
        PUBLIC  our1b,their1b, realCS, pleaseExit
	public entry13, entry14, entry6
	
        extrn PrintVersion : PROC
        extrn checkcpu : PROC, FileLoadErr : PROC
        extrn trapcount : dword, proceedcount : dword
        extrn ReTrap : PROC, proceedone : PROC
	EXTRN	initflatreal:PROC, rundownflatreal : PROC
        extrn wininit : PROC, winrundown : PROC
        extrn redump : PROC, optfs : byte, rediss : PROC
        extrn w_swapscreen: PROC


        .code
        extrn incs32:byte
;
; CPU instruction trap enable flag
;
TRAPFLAG = 100h

	.data
stackofs	dw	0	;to restore out stack in INT1
stackseg	dw	0
;
; Register image
;
veclist	dw	00h
	dw	entry0
	dw	1
	dw	entry1
	dw	3
	dw	entry3
	dw	1bh
	dw	int1bh
	dw	20h
	dw	int20handle
	dw	21h
	dw	int21handle
	dw	0ffffh	; trailer
RegdumpFLAGS	dd	0
RegdumpEAX      dd      0       ; order is important
RegdumpECX	dd	0
RegdumpEDX	dd	0
RegdumpEBX	dd	0
RegdumpESP      dd      0
RegdumpEBP      dd      0
RegdumpESI	dd	0
RegdumpEDI	dd	0
RegdumpEIP	dd	0
RegdumpES	dw	0
RegdumpCS	dw	0
RegdumpSS	dw	0
RegdumpDS	dw	0
RegdumpFS	dw	0
RegdumpGS	dw	0
;
run1b           dd      0
dosver	dw	0
haserr	dw	0	; If there is an error# on stack
errnum  dw      0       ; The error#
trapnum dw      0       ; The trap#
indos	dd	0	; pointer to indos flag
grdbname	db	'********',0
psp	dw	0	;debugger PSP
neederr	db	0	;flag for file load result from command line
realCS dw	0

trappop	dd	6790h	;traps that need to pop a value
pleaseExit	db	0

	.code
c32down dw      offset _text:cs32rundown,0
cpuerr	db	"GRDB requires a 386 or better processor",0
memerr	db	"not enough memory/corrupt arena",0
vererr	db	"GRDB requires MSDOS 4.0 or better"
nomsg	db	0

null1b: iret
        
our1b PROC
        push    es
		sub		ax,ax
        mov     es,ax
        mov     ax,es:[23h * 4]
        mov     word ptr [run1b],ax
        mov     ax,es:[23h * 4 + 2]
        mov     word ptr [run1b+2],ax
        mov     ax,offset _text:null1b
        mov     es:[23h * 4],ax
        mov     ax,_text
        mov     es:[23h * 4 + 2],ax
        pop     es
        ret
our1b ENDP
their1b PROC
        push    es
		sub		ax,ax
        mov     es,ax
        mov     ax,word ptr [run1b]
        mov     es:[23h * 4],ax
        mov     ax,word ptr [run1b + 2]
        mov     es:[23h * 4 + 2],ax
        pop     es
        ret
their1b ENDP
;This macro generates a front end for the interrupt handlers installed for
;int 0, 1 and 3.

entry	macro	num
        local   est, ir
entry&num:
        db      0e9h    ; test if in RM32 - this is a JMP
        db      2,0
        db      0,0
        jmp     short ir
        db      2eh,0ffh,15h ; call [c32down] - we are in a 32 bit CS here
        dw      offset _text:c32down,0
        ; back in real mode
ir:
if num EQ 1
	call	hdwechk
	jc	est
	call	swiftrace
ENDIF
IF num EQ 3
	call	dpmihandler ; doesn't return if entering DPMI
	call	swiftrace	; doesn't return if tracing
ENDIF
est:
	push	gs
	push	fs
	push	es
	push	ds
	pushad
	mov	al,num
	jmp	traphandler
endm

	entry	0
	entry	1
	entry	3
	entry	6
	entry	13
	entry	14
;
; Save an image of the regs
; This MUST BE the first thing the trap handler calls; it assumes
; there is ONE PUSH (return address) followed by the DS at the time
; of interrupt followed by the interrupt data
;
saveregs	PROC
	pop	cx	
	pop	[RegdumpEDI]
	pop	[RegdumpESI]
	pop	[RegdumpEBP]
	pop	eax
	pop	[RegdumpEBX]
	pop	[RegdumpEDX]
	pop	[RegdumpECX]
	pop	[RegdumpEAX]
	pop	[RegdumpDS]
	pop	[RegdumpES]
	pop	[RegdumpFS]
	pop	[RegdumpGS]
	bt	[haserr],0	; See if an error
	jnc	short noerr	;
	pop	eax		; Get the error #
	mov	[errnum],ax	;
noerr:
;        test    [incs32],1
;        jz      rmsf
;        pop     [RegdumpEip]    ; we were in a 32-bit seg, pop the wide versions
;        pop     [RegDumpCS]
;        add     sp,2
 ;        pop     [RegdumpFlags]
;        jmp     rmjn

	test	cs:[inDPMI],1
	jz		rmsf
	test	cs:[dpmiType],1
	jz		rmsf
	pop		dword ptr [RegdumpEIP]
	pop		eax
	mov		[regdumpCS],ax
        pop     eax
        mov     [RegdumpFLAGS],eax
	mov	ax,ss		; Otherwise just save the current
	mov	[RegdumpSS],ax	; stack pointer before we started pushing
	mov	[RegdumpESP],esp	;
	jmp cx
rmsf:
	pop	word ptr [RegdumpEIP]
	mov word ptr [RegdumpEIP + 2],0
	pop	[RegdumpCS]
        pushfd
        pop     eax
        pop     ax
        mov     [RegdumpFLAGS],eax
	mov	ax,ss		; Otherwise just save the current
	mov	[RegdumpSS],ax	; stack pointer before we started pushing
	movzx	eax,sp		; in dpmi16 the high word of ESP may be non-zero
	mov	[RegdumpESP],eax	; we get rid of it tho...
	jmp	cx
saveregs	ENDP	
;
; Adjust EIP to the trap if it's not int 3
;
adjusteip	PROC	
	cmp	[trapnum],3	; See if int 3
	jnz	short noadj	; No, get out
	mov	ebx,[RegdumpEIP]	;
	mov	fs,[RegdumpCS]	;
	cmp	BYTE PTR fs:[ebx-1],0cch ; See if is an INT 3
	jz	short nodecrement ; Get out if so
	dec	dword ptr [RegdumpEIP]		; Else point at trap
nodecrement:
noadj:
	ret
adjusteip	ENDP	
;
; Generic trap handler
;
traphandler	PROC
	cld
	sti
	call	compatibleDS
	call	compatibleES
	mov	[CtrlBrkPressedInDOS],0
	movzx	eax,al
	mov	[trapnum],ax
	bt	[trappop],eax
	jnc	noerr2
	inc	[haserr]	; Set the error flag
noerr2:
	mov	si,offset veclist
	call	ReleaseRMInts
	call	saveregs	; Save Regs
	and	[RegdumpFLAGS],NOT TRAPFLAG ; reset trap flag in flags image
	call	compatibleStackSeg
	mov	ss,ax	; load our stack
	movzx	esp,[stackofs]	; clear top of ESP just in case...
        test    [deferedBreaks],1 ; see if it was a trace over a breakpoint
        jz      realbreak       ; no, real break
        dec     [deferedbreaks] ;
        call    EnableBreaks    ; yes, enable breakpoints
        sub     ax,ax           ; and start running
        jmp     gotrap          ;
realbreak:
	call	disableBreaks	; Disable breakpoints if not
	call	adjusteip	; Adjust the EIP to point to the breakpoint
	call	SetDebugPSP
ifndef NOFS
        test    [optfs],255
        jz      re_nfs
        mov     al,1
        call    w_swapscreen
re_nfs:
endif
	call	crlf
	cmp     [trapnum],3	; No stats if it is int 3
	jz	short reentry	;
	cmp	[trapnum],1	; Or int 1
	jz	short reentry	;
	PRINT_MESSAGE	<'Trap: '>
	mov	ax,[trapnum]	; Say which one
	call	printbyte	;
	call	crlf
	btr	[haserr],0	; If has error 
	jnc	reentry		;
	PRINT_MESSAGE	<'Error: '>
	mov	ax,[errnum]	; Say which one
	call	printword
	call	crlf
; fall through
traphandler ENDP
reentry	PROC
        test    [slashcmd],-1
        jz      notslashcmd
        call    slashcont
notslashcmd:
	call	DisplayRegisters; Display registers
ifndef NOFS
        test    [optfs],255
        jz      re_nfs2
        call    redump
        call    rediss
re_nfs2:
endif
	test	[trapcount],-1
	jz	noretrace
        call    scankey         ; if they pressed a key stop
        jnz     noreproceed
	dec	[trapcount]
	jmp	ReTrap
noretrace:
        test    [proceedcount],-1
        jz      noreproceed
        call    scankey         ; if they pressed a key stop
        jnz     noreproceed
        dec     [proceedcount]
        jmp     proceedone
noreproceed:
        mov     [proceedcount],0
        mov     [trapcount],0
	call	initflatreal
	test	[neederr],-1
	jz	InputHandler
	mov	ah,[neederr]
	mov	[neederr],0
	sahf
	call	FileLoadErr
	jmp	InputHandler	; Go do input

reentry	ENDP	
;
; Monitor init routine, point all traps to point to the monitor handler
;

start:
        cld
	mov	bx,dgroup	; setup
	mov	ds,bx
	mov	[psp],es	; our PSP
	mov	es,bx		;set ES to DX
	mov	ax,ss		; have to adjust stack to be DS-relative
	sub	ax,bx		; the disassembler requires it
	shl	ax,4		;to segment
	add	ax,sp		;add in the stack pointer
	mov	ss,bx		;set SS to DS
        movzx   esp,ax           ;and new stack based on DS
	mov	[stackseg],ss
	mov	[stackofs],sp
	mov	[realCS], cs
ifndef NOFS
        call    wininit
endif
	mov	ah,30h				; dos version check
	int	21h
	cmp	al,4
	mov	dx,offset cs:vererr
	jc	errx
	xchg	ah,al
	mov	[dosver],ax
	push	es    				; get indos flag
	mov	ah,34h	
	int	21h
	mov	word ptr [indos],bx
	mov	word ptr [indos+2],es
	pop	es
	call	checkcpu			; validate CPU
	mov	dx,offset cs:cpuerr
	jc	errx
IFNDEF TEST1
	call	ResizeMem			; cut mem back
	mov	dx,offset cs:memerr
	jc	errx
        call    our1b                           ; point to null 1bh
	call	IntSnapshot			; grab the ints so we can
						; restoire context later
        call    cs32init                        ; initialize PM data areas
	call	ReadOptions			; read the options disk file
        call    PrintVersion
        PRINT_MESSAGE   <C_ADDRESS, "GRDB comes with ABSOLUTELY NO WARRANTY, for details type `?g'",13,10>
        PRINT_MESSAGE   <"This is free software, and you are welcome to redistribute it",13,10>
        PRINT_MESSAGE   <"under certain conditions; type `?gr' for details",13,10, C_DEFAULT>
        call    loadsym

	mov	dx,offset cs:memerr
	jc	errx2
	mov	si,offset grdbname	; create data spaces for
	call	MakeEmptyProg			; empty prog
	mov	dx,offset cs:memerr
	jc	errx2
        call    getcurshape
	call	FloatCheck			; check for an FP coprocessor
        push    ds                              ; parse command line params
	mov	ds,[psp]
	mov	si,81h
	call	ParseProgName
	pop	ds
	test	[loadfile],-1			; load program
        jz      dohist
	sub	ax,ax
	call	LoadProgram			; load the program
	lahf
	mov	[neederr],ah
dohist:
	test	[opthist],0ffh			; init history
        jz      reentry
    call    initDPMI                        ; init DPMI
	call	LoadHistory
ENDIF
	jmp	reentry				; get us started
;
; program exit
;
_exit:
	test	cs:[inDPMI],1
	jz		notexitingDPMI
	mov		si,offset veclist
	call	SetRMInts
	mov		es,cs:[codeAlias]
	mov		es:[inDPMI],0
	mov		[pleaseExit],1
	mov		ss,[regdumpSS]
	mov		esp,[regdumpESP]
	mov		es,[regdumpDS]
	mov		ds,[regdumpDS]
	sub		ax,ax
	mov		fs,ax
	mov		gs,ax
	mov		ax,4c00h
	int		21h
notexitingDPMI:
    call    underlinecurs
	test [optionWriteFlag],1
	jz	nooptionwrite
        call    WriteOptions
nooptionwrite:
ifndef NOFS
        call    winrundown
endif
IFNDEF TEST1
	call	CloseLogFile			; close our log file
	call	KillFiles			; close files they opened
	call	rundownflatreal			; no more flat real mode
	test	[optansi],1
	jz		noansi
	call	ansireset
noansi:
	mov	dx,offset cs:nomsg
ENDIF
errx2:
IFNDEF TEST1
	push	dx
        call    rundownDPMI                     ; unhook DPMI
        call    their1b                         ; restore int 1bh
	call	ReleaseMemory			; release any memory tagged
						; to them
	call	ReleaseDebugMem			; release any memory tagged
						; to us
        call    unloadsym
	pop	dx
ENDIF
errx:
	mov	bx,dx
	call	olMessage
	mov	bx,0				; close the input file
	mov	ah,3eh
	int	21h
	mov	ax,4c00h
	int	21h

	END	start