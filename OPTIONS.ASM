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
; OPTIONS.ASM.ASM
;
; Function: Option input and display
;
	;MASM MODE
	.MODEL SMALL
	.386p

ifdef NOFS
NUMOPTS = 17+1                  ;LEB 10-09-2005 NEW OPTION FOR DUAL MONITORS 
else
NUMOPTS = 18+1                  ;LEB 10-09-2005
endif
include  iversion.inc
include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include  ebreaks.inc 
include  eints.inc
include  elogging.inc
include  eregs.inc
include  erm32.inc
include  esymbol.inc
include  iwindow.inc
include  edpmi.inc
include eansi.inc
include  eenv.inc
; define the symbol RAWA20 to run flat real mode with XMS
;
	PUBLIC doopt,optdword, optdwordcommand,optpure,opthist, optflat0, optsignedimm
        PUBLIC Disassemble32Bit, optdiv0, optflatinit
        PUBLIC optdosio, optass32, optsymname
        PUBLIC ReadOptions, WriteOptions, optstoponkey, writeopts
        PUBLIC optcisym
        PUBLIC optdm            ;LEB 10-09-2005 NEW OPTION FOR DUAL MONITORS
		PUBLIC optSyntaxColoring
		PUBLIC opthbreak;
		PUBLIC bit32Address
ifndef nOFS
        public optfs
endif
		public optansi
        extrn wininit : PROC, winrundown : PROC, redump : PROC, rediss : PROC
        extrn w_cmdset: PROC
		extrn inCS32 : byte

	.data
;
; optlist, optvals, and optvect MUST be kept in sync
;
optlst  db      "wrfr32zrbknvfif0sohimdddsk"
        db      "dm"            ;LEB 10-09-2005
		db		"sc"
ifndef NOFS
        db      "fs"
endif
		db		"si"
		db		"hb"
		db		"an"
;
writeopts db	0	;true if options have changed
;
optmark	dw	verid	; MUST preced optvals
optvals	label	BYTE
optdword db	1	;flag if user selected 32-bit registers (WR)
optdwordcommand db 0	;flag if user wants flat real mode (FR)
Disassemble32Bit db	1	;32-bit instructions enabled
	TRUE	equ	1
	FALSE	equ	0
optdiv0 db      1       ; these two options DEPEND on VECTLIST
optbrk  db	1	; having the upper bits of the ints set right
			; on a no-param file start
optpure db	1	;native video
optflatinit db	0	;causes init for flat real mode
optflat0 db	0	; flat real mode - default segs to zero
optsignedimm db	0	; set if want to see signed immediates on u command
opthist db	1	;flag if user enabled history
optdosio db     1       ; flag if using dos for command I/O
optass32 db     0       ; flag if disassembly/assembly should be 32 bit native
optstoponkey db 0       ; flag if we should stop various display functions
                        ; when a key is pressed
optdm   db      0               ;LEB 10-09-2005
optSyntaxColoring db 1	; turn on syntax coloring
ifndef NOFS
optfs   db      0       ; flag if full screen mode
endif
optcisym     db 1       ; case insensitive symbol lookups
opthbreak		db 1	; hardware break points
optansi			db 0	; ansi escape sequences

optsymname      db 0    ; symbol name size, K bytes
;
;
optbottom label byte
;
;
optvect dw      vsetopt,vsetopt,vsetopt
	dw	voptdiv0,voptbrk1b,vsetopt,vsetopt,vsetopt,vsetopt,vsetopt
        dw      vsetoptdosio    ;LEB 10-09-2005
        dw      vsetopt,vsetopt
        dw      vsetoptdm       ;LEB 10-09-2005
		dw		vsetopt
ifndef NOFS
        dw      voptfs
endif
		dw		vsetopt
		dw		vsetopt
		dw		voptansi
optname	db	"grdb.opt",0
	.CODE
;
; for display of states
;
optmsgs	label	BYTE
        db      13,10,"WR - wide registers              ",0
        db      13,10,"FR - flat real commands          ",0
        db      13,10,"32 - enable 386+ instructions    ",0
        db      13,10,"ZR - divide by zero trap         ",0
        db      13,10,"BK - ctrl-break trap             ",0
        db      13,10,"NV - native video                ",0
        db      13,10,"FI - flat real autoinit          ",0
        db      13,10,"F0 - flat real 0 default         ",0
        db      13,10,"SO - signed immediates           ",0
        db      13,10,"HI - command history             ",0
        db      13,10,"MD - msdos I/O                   ",0
        db      13,10,"DD - 32-bit default addressing   ",0
        db      13,10,"SK - stop display on keypress    ",0
        db      13,10,"DM - dual monitor mode           ",0  ;LEB 10-09-2005
		db		13,10,"SC - syntax coloring             ",0
ifndef NOFS
        db      13,10,"FS - full screen mode            ",0
endif
        db      13,10,"SI - case insensitive symbols    ",0
		db		13,10,"HB - hardware breakpoint enable  ",0
		db		13,10,"AN - ansi escape sequences       ",0
;
;****************************** DUAL MONITORS 10-09-2005 LEB ***********
dmcheck     PROC        ;checks signature of driver for dual monitors
        push    ds              ;save caller's ds
        DB 6Ah,00h              ;2 byte  version of push 0000h 
        pop     ds              ;segment of interrupt table
        mov     ds,ds:[2Bh*4 + 2] ;get segment of INT 2Bh
        cmp     dword ptr ds:[000Ah],3241444dh  ;"MDA2"
        ; checking for name of character device in header
        pop     ds              ;restore caller's ds
        ret
dmcheck     ENDP

bit32Address PROC
	test [optdwordCommand],1
	jnz	finbit32
	test cs:[inDPMI],1
	jz finbit32
	test cs:[dpmiType],1
	jz	finbit32
	test cs:[inCS32], 1
finbit32:
	ret
bit32Address ENDP
;
; option command
;
doopt	PROC	
	inc		si
dooptr:
	Call	WadeSpace	; Wade till address
	jnz	optlp
ifndef NOFS
        test    [optfs],255
        jz      nofsx
        mov     al,1
        call    w_cmdset
nofsx:
endif
	mov	si,offset _text : optmsgs	; no args, print all options
	mov	di,offset optvals
	mov	cx,NUMOPTS
polp:
	call	PrintOption
	loop	polp
	mov		dl,C_DEFAULT
	call	PutChar
	call	LoggingStat
	call	initflatreal
optxit:
	clc
	ret
;
; subroutine to print an option and its enabled/disabled value
;
PrintOption:
	mov	dl,C_OPTTEXT
	call	PutChar
        mov     bx,si
	call	olMessage
	test	byte ptr [di],-1
	jnz	dotype
	PRINT_MESSAGE	<9,C_ENABLE,"disabled">
	jmp	dojoin
dotype:
	PRINT_MESSAGE	<9,C_ENABLE,"enabled">
dojoin:
	inc	di
frs_lp:
	lods	byte ptr cs:[si]
	or	al,al
	jnz	frs_lp
	ret
;
; comes here to set/reset an option
;
optlp:
	cmp	al,13
	je	dooptr		; go back and show vals after the set
	cmp	al,'-'		; check for off command
	pushf
	jz	incpos
	cmp	al,'+'
	jne	noinc
incpos:
	inc	si
noinc:
	call	WadeSpace	; now get the option letters
	jz	opterr
	lodsw
	cmp	ah,13
	je	opterr
	mov	cx,NUMOPTS	; search for them
	mov	di,offset optlst
cmplp:
	scasw
	jz	dovect
	loop	cmplp
opterr:
	add	sp,2		; bad opt, exit with no display
        stc
	ret
dovect:
	mov	[writeopts],1	; changing, need disk update
	neg	cx
	add	cx,NUMOPTS
	movzx	ebx,cx
	popf
	lahf
	and	ah,40h
	xor	ah,40h
	shr	ah,6        	; ah = opt new val
	call	[optvect + ebx*2] ; call handler
	call	WadeSpace
	jmp	optlp    	; get another
doopt	ENDP
;
; option routines
; 
; this one is for basic bools
;
;****************************** DUAL MONITORS LEB 10-09-2005 ***********
vsetoptdosio:   mov optdm,00          ;disable dual monitors while          
                jmp short vsetopt     ;setting dos io

vsetoptdm:      call    dmcheck
                jnz     nodual  ;don't allow dual monitors unless
                                ;monochrome monitor has been initialized

                mov optdosio,00 ;disable dos io while setting dual
;MUST CONTINUE THROUGH vsetopt PROC, don't move from here LEB 10-09-2005
vsetopt PROC
        mov     [bx + optvals],ah       ;set or clear general option
nodual: ret
vsetopt	ENDP

voptansi PROC
		call	vsetopt
		or		ah,ah
		jz		noansist
		sub		ax,ax
		call	ansibackground
noansist:
		ret
voptansi ENDP
;***********************************************************************
ifndef NOFS
voptfs  PROC
        cmp     ah,[bx + optvals]
        jz      voptfsx
        test    ah,ah
        jz      fsout
        mov     [bx + optvals],1
        push    si
        push    di
        call    wininit
        call    DisplayRegisters
        call    redump
        call    rediss
        pop     di
        pop     si
        ret
fsout:
        push    bx
        push    si
        push    di
        call    winrundown
        pop     di
        pop     si
        pop     bx
        mov     [bx + optvals],0
voptfsx:
        ret
voptfs  ENDP
endif
;
; following this we have interrupt enables/disables.
; they run through VECLIST and set the high bit to match the
; bool value
;         
voptbrk1b	PROC
	mov	al,1bh
	jmp	vopttraps
voptbrk1b	ENDP
voptdiv0	PROC
	mov	al,0
voptdiv0	ENDP
vopttraps	PROC
	mov	[bx + optvals],ah
	mov	bl,ah
vopttraps	ENDP
voptrefresh	PROC
	push	si
	mov	si,offset veclist
	call	SetVectAttrib
	pop	si
	ret
voptrefresh	ENDP
;
; write options to disk file
;
WriteOptions	PROC
	mov	[optmark],verid
	test	[writeopts],0ffh
	jz	wo_x
	call	optcreat
	jc	wo_x
	mov	dx,offset optmark
        mov     cx,offset optbottom - offset optmark
	mov	ah,40h
	int	21h
	jc	wo_x2
	mov	[writeopts],0
wo_x2:
	call	optclose
wo_x:
	ret
WriteOptions	ENDP
;
; read options from disk file
;
ReadOptions	PROC
	mov	[writeopts],1
	mov	[optmark],-1
	call	optopen
	jc	ro_x
	mov	dx,offset optmark
	mov	cx,2
	mov	ah,3fh
	int	21h
	jc	ro_x2
	cmp	[optmark],verid
	jne	ro_x2
	mov	dx,offset optmark+2
        mov     cx,offset optbottom - offset optmark - 2 
	mov	ah,3fh
	int	21h
;****************************** DUAL MONITORS 10-09-2005 LEB ***********
        pushf
        call    dmcheck
        jz      dmcheckOK
        mov     optdm,0         ;don't allow dual monitors unless driver
        ;                        has already initialized secondary card
        ;                        don't modify GRDB.OPT because user may
        ;                        want dual monitors after exiting to
        ;                        initialize it.
dmcheckOK:
        popf
;***********************************************************************
	jc	ro_x2
        cmp     ax,offset optbottom - offset optmark - 2
	jne	ro_x2
	push	bx
	mov	[writeopts],0   ; the option file is read
	mov	bl,[optdiv0]	; now set the attrib bits in veclist
	mov	al,0
	call	voptRefresh
	mov	bl,[optbrk]
	mov	al,1bh
	call	voptRefresh
	call	initflatreal
	test	[optansi],1
	jz		noansist2
	sub		ax,ax
	call	ansibackground
noansist2:
	pop	bx
nd1bfix:
ro_x2:
	call	optclose
ro_x:
	ret
ReadOptions	ENDP


;
; generi disk file stuff.  Should probably merge with loader and logger
; routines...
;
OptOpen	PROC
	mov	ax,3d02h
	mov	dx,offset optname
	int	21h
	jnc	openedlocal
	enter	260, 0
	lea		di, [bp-260]
	mov		si,offset optName
	call	QualifyWithGRDBPath
	mov		ax,3d02h
	lea		dx,[bp-260]
	int		21h	
	leave
openedlocal:
	mov	bx,ax
	ret
OptOpen	ENDP
OptCreat	PROC
	mov	ax,3c00h
	mov	cx,0
	mov	dx,offset optname
	int	21h
	mov	bx,ax
	ret
OptCreat	ENDP
OptClose	PROC
	mov	ah,3eh
	int	21h
	ret
OptClose	ENDP

end
