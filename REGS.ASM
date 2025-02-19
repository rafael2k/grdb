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
; Regs.asm
;
; Function: Handle register display and input
;
	;MASM MODE
	.model small
	.386


include  eprints.inc 
include  emtrap.inc 
include  einput.inc 
include  edis.inc 
include eoptions.inc
include  ehistory.inc
include emmx.inc
include efp.inc
include iwindow.inc

	PUBLIC	DisplayRegisters, ModifyRegisters, ReadReg
        extrn optfs: byte, w_setwind : PROC, wnd_reg : windstr, wnd_reg2 : windstr
	.code
;
; This is a list corresponding ASCII names for general purpose regs
; with the address the value can be found at;
;

peax	dw	offset RegdumpEAX
	db	13,10,"eax",0
pebx	dw	offset RegdumpEBX
	db	"ebx",0
pecx	dw	offset RegdumpECX
	db	"ecx",0
pedx	dw	offset RegdumpEDX
	db	"edx",0
pesi	dw	offset RegdumpESI
	db	"esi",0
pedi	dw	offset RegdumpEDI
	db	"edi",0
pebp	dw	offset RegdumpEBP
	db	13,10,"ebp",0
pesp	dw	offset RegdumpESP
	db	"esp",0
peip	dw	offset RegdumpEIP
	db	"eip",0
	dw	0
;
; a list of 8-bit register names
;
pal	dw	offset RegdumpEAX
	db	13,10,"al",0
	dw	offset RegdumpEAX+1
	db	"ah",0
	dw	offset RegdumpEBX
	db	"bl",0
	dw	offset RegdumpEBX+1
	db	"bh",0
	dw	offset RegdumpECX
	db	"cl",0
	dw	offset RegdumpECX+1
	db	"ch",0
	dw	offset RegdumpEDX
	db	13,10,"dl",0
	dw	offset RegdumpEDX+1
	db	"dh",0
	dw	0
;
; a list of 16-bit register names
;
pax	dw	offset RegdumpEAX
	db	13,10,"ax",0
	dw	offset RegdumpEBX
	db	"bx",0
	dw	offset RegdumpECX
	db	"cx",0
	dw	offset RegdumpEDX
	db	"dx",0
	dw	offset RegdumpESI
	db	"si",0
	dw	offset RegdumpEDI
	db	"di",0
	dw	offset RegdumpEBP
	db	13,10,"bp",0
	dw	offset RegdumpESP
	db	"sp",0
	dw	offset RegdumpEIP
	db	"ip",0
pds	dw	offset RegdumpDS
        db      13,10,"ds",0  
PES	dw	offset RegdumpES
	db	"es",0
pfs	dw	offset RegdumpFS
	db	"fs",0
pgs	dw	offset RegdumpGS
	db	"gs",0
Pss	dw	offset RegdumpSS
	db	"ss",0
pcs     dw      offset RegdumpCS
        db      "cs",0
	dw	0
peflags	dw	offset RegdumpFLAGS
        db      "flag",0
	dw	0
peflags2 dw      offset RegdumpFLAGS
        db      "fl",0
	dw	0
flm	label byte
	db	11
	dd	"NVOV"
	db	10
	dd	"UPDN"
	db	9
	dd	"DIEI"
	db	7
	dd	"PLMI"
	db	6
	dd	"NZZR"
	db	4
	dd	"NAAC"
	db	2
	dd	"POPE"
	db	0
	dd	"NCCY"
	db	-1
	db	0
jmptab label word
	dw	800h,800h	; jo
	dw	800h,0	; jno
	dw	1,1	; jb
	dw	1,0	; jnb
	dw	40h,40h	; jz
	dw	40h,0	; jnz
	dw	41h,41h	; jbe
	dw	41h,0	; ja
	dw	80h,80h; js
	dw	80h,0	; jns
	dw	4,4; jpe
	dw	4,0; jpo
	dw	000h,00h; jl
	dw	000h,00h	; jge
	dw	000h,000h	; jle
	dw	000h,0	; jg
;
; Print a general purpose reg and it's value
;
rPutDword	PROC	
	test	[optdword],0ffh
	jz	rPutWord
        push    cx
	lods	word ptr cs:[si]; Get pointer to val
	mov	bx,ax
	mov	eax,[bx]	; Get val
	push	eax		;
	mov	bx,si		; Get text pointer
ifndef NOFS
        test    [optfs],255
        jz      rpd_c2
rpd_l:
        test    byte ptr cs:[bx],0e0h
        jnz     rpd_c
        inc     bx
        jmp     rpd_l
rpd_c:
        push    dx
        mov     dx,cx
        call    setcurpos
        pop     dx
rpd_c2:
endif
	push	dx
	mov		dl,C_REGISTER
	call	PutChar
	call	olMessage
	mov		dl,C_DEFAULT
	call	PutChar
	mov		dl,':'
	call	PutChar
	mov		dl,C_NUMBER
	call	PutChar
	pop		dx
	pop	eax		;
	call	printdword	; Print value
	push	dx
	mov		dl,C_DEFAULT
	call	PutChar
	pop		dx
ifndef NOFS
        test    [optfs],255
        jnz      rpd_c3
endif
	call	printspace	;
rpd_c3:
        pop     cx
        inc     ch
	ret
rPutDword	ENDP	
;
; Print a segment reg and its value
;
rPutWord	PROC	
        push    cx
	lods	word ptr cs:[si]; Get pointer to value
	mov	bx,ax
	mov	ax,[bx]		; Get value
	push	ax		;
	mov	bx,si		; Pointer to text
ifndef NOFS
        test    [optfs],255
        jz      rpw_c2
rpw_l:
        test    byte ptr cs:[bx],0e0h
        jnz     rpw_c
        inc     bx
        jmp     rpw_l
rpw_c:
        push    dx
        mov     dx,cx
        call    setcurpos
        pop     dx
rpw_c2:
endif
	push	dx
	mov		dl,C_REGISTER
	call	PutChar
	call	olMessage
	mov		dl,C_DEFAULT
	call	PutChar
	mov		dl,':'
	call	PutChar
	mov		dl,C_NUMBER
	call	PutChar
	pop		dx
	pop	ax		;
	call	printword	; Print value
	push	dx
	mov		dl,C_DEFAULT
	call	PutChar
	pop		dx
ifndef NOFS
        test    [optfs],255
        jnz      rpw_c3
endif
rpw_c3:
	call	printspace	;
        pop     cx
        inc     ch
	ret
rPutWord	ENDP	
;
; Print either the GP regs or the SEG regs
; INPUT: DX has the address of the appropriate print routine
;	SI points to text
; By implication, two consecutive bytes of 0 exit the routine, else we
; print each string until we reach that 00 00
;

PrintaFew	PROC	
	call	dx		; Call the print routine
pf_lp:
	lods	byte ptr cs:[si]; Wade past the text
	or	al,al		;
	jnz	pf_lp		;
	test	WORD PTR cs:[si],-1 ; See if trailer found
	jnz	PrintAFew	; Go print another
	ret
PrintAFew	ENDP	
;
; try to find a match for a register spec
; INPUT: SI points at the input line where we might find a register by name
;	DI points to an EAX structure consisting of a pointer to a bucket
;		to put EAX into, followed by a display string of 'EAX'
; OUTPUT:SI is moved past the register if we found one, else same
;	DI points to bucket to hold this register value if register found
;
skimreg PROC
	push	di			;save address of structure
	push	si			;save address of input
	xchg	si,di			;di now input, si is structure
	add	si,2			;go past EAX bucket pointer to str
srlp:
	cmp	byte ptr cs:[si],' '	;anything below a space
	jnc	oktry			;is OK, so skip 0D, 0A at EAX
	inc	si			;goto next character
	jmp	srlp			;until letter is found
oktry:
	cmp	byte ptr cs:[si],0	;null follows all register names
	jz	match			;so if all alike, we found our reg
	cmps	byte ptr cs:[si],es:[di] ;else do a character match
	jz	oktry			;if a match, keep going to colon
	pop	di			;else pop address of input to di
	add	sp,2			;clear struct address off stack
srlp2:
	lods	byte ptr cs:[si]	;find terminating 0, following colon
	or	al,al			;is this it?
	jnz	srlp2			;keep looking until found
	test 	word ptr cs:[si],0ffffh	;table ends with word of 0
	xchg	si,di			;get our regs straightened out
	jnz	skimreg			;and examine next struct
	sub	al,al			;no find, so
	inc	al			;return no carry
	ret
match:
	add	sp,2			;clear input address off stack
	sub	eax,eax			;clear out EAX
	xchg	si,di			;SI now input past found register
	pop	di			;di points to top struct
	mov	di,cs:[di]		;point to his bucket
	stc				;indicate register found
	ret
skimreg ENDP
;
; search all the name tables for a match
; INPUT: SI points at the input line where we expect to find a register
; OUTPUT: ZR if found a non-segment register, NZ if we didn't
;	CY if the request was NOT for a segment register, NC if it was
;	SI moved past the register on the input line
;
FindRegister	PROC
	mov	di,offset cs:peax	;find pointer to EAX bucket
	call	skimreg			;look for register string match
	mov	cl,4			;used for dword length
	jc	frnoseg			;carry means we found dword reg
	mov	di,offset cs:pal	;else look for byte reg
	call	skimreg			;save technique
	mov	cl,1			;set byte length
	jc	frnoseg			;in case we found it
	mov	di,offset cs:peflags	;else maybe user doing flags?
	call	skimreg			;try 'eflags'
	mov	cl,4			;say 4 bytes for this
	jc	frnoseg			;if found
	mov	bl,[si+1]		;else bl=2d char in input string
	mov	di,offset cs:pax	;look for word regs
	call	skimreg			;in the table
	mov	cl,2			;assume word
	jnc	frnotfound		;if not found, bl is ???
	cmp	bl,'s'			;might it be a segment reg?
	stc				;assume not???
	jnz	frnoseg			;jmp if not
	clc				;else clear carry
frnoseg:
	mov	al,0ffH			;set ZF without affecting carry flag
	inc	al
	ret				;and return success
frnotfound:
	sub	ax,ax			;set NZ
	inc	ax
	stc				;and the carry
	ret
FindRegister	ENDP
;
; read the value of a reg (used by input routines)
; INPUT: SI points at the input line 
; OUTPUT:If we found a byte or word register, EAX holds the zero-extended
;	value that was in the corresponding bucket.
;	If we found a dword register, EAX holds the dword value
;	NZ if register not found by name, but still might be a number
;		Else, NC if segment reg, CY if non-segment reg found
;	SI moved past a register found by name, else not moved
;
ReadReg		PROC
	push	ecx			;ECX holds ???
	call	FindRegister		;see if we found a non-segment reg
	jnz	notreg			;if not, jmp
	pushf				;save flags (carry?)
	mov	eax,[di]		;get value from bucket
	cmp	cl,4			;was it a dword?
	jz	rr_exit			;if so, exit
	movzx	eax,ax			;else zero extend into EAX
	cmp	cl,2			;was it a word register
	jz	rr_exit			;if so, we have it
	movzx	eax,al			;else zero extend EAX
rr_exit:
	popf				;restore flags
notreg:
	pop	ecx			;and ECX
	ret
ReadReg	ENDP
;
; Read value for a register back into memory (R) command
;
ReadRegValue	PROC
	call	WadeSpace
	jz	doregprompt
	inc	si
	cmp	al,':'
	jz	ReadRegValue
	cmp	al,'='
	jz	ReadRegValue
	dec	si
	call	ReadNumber
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
	call	ReadNumber
	ret
rr_out:
	stc
	ret
ReadRegValue	ENDP	
;
; DisplayFlags command
;
EditFlags PROC
        sub     dx,dx
        inc     si                      ; past the 'f'
        call    wadespace
        jnz     readflags
        PRINT_MESSAGE   <13,10>
        call    putflags
        PRINT_MESSAGE   <"- ">
	call	histoff
	call	GetInputLine		; Get input line
	call	histon
        mov     dx,1
readflags:
        call    wadespace
        jz      efx
        cmp     al,','
        jz      efskipcomma
        mov     ax,[si]
        xchg    al,ah
        and     ax,0DFDFh               ; make upper case
        mov     bx,ax
        push    si
        mov     si,offset cs:flm
efl:
        lods    byte ptr cs:[si]
        test    al,al
        jns     efc
        pop     si
        add     si,2    ; bump for no prompt mode
        test    dx,1
        jz      efnoadd
        add     si,24   ; remainder of bump for prompt mode
efnoadd:
        stc
        ret
efc:
        movzx   ecx,al
        lods    dword ptr cs:[si]
        cmp     ax,bx
        jnz     nosetmatch
        bts     [RegDumpFlags],ecx
        jmp     short effin
nosetmatch:
        shr     eax,16
        cmp     ax,bx
        jnz     efl
        btr     [RegDumpFlags],ecx
effin:
        pop     si
        inc     si
efskipcomma:
        inc     si
        jmp     readflags

efx:
        clc
        ret
        
EditFlags ENDP
;
; main 'Reg' command
;
ModifyRegisters	PROC	
	call	wadespace		; Wade through spaces
	jz	DisplayRegisters	; Display regs
        cmp     al,'m'
        jnz     contmod
        inc     si
        jmp     ModifyMMXRegisters
contmod:
        cmp     al,'n'
        jnz     contmod2
        inc     si
        jmp     fpcommand
contmod2:
        cmp     al,'s'
        jnz     contmod3
        cmp     byte ptr [si+1],'t'
        jnz     contmod3
        inc     si
        inc     si
        jmp     fpcommand
contmod3:
        cmp     al,'f'
        jnz     nEditFlags
        cmp     byte ptr [si+1],'s'
        jnz     EditFlags
nEditFlags:
	call	FindRegister
	jnz	badreg
	push	di
	call	ReadRegValue
	pop	di
	jc	badreg2
	cmp	cl,4
	jnz	wordreg
	mov	[di],eax
	clc
	ret
wordreg:
	cmp	cl,2
	jnz	bytereg
	mov	[di],ax
badreg2:
	clc
	ret
badreg:
	stc
	ret
bytereg:
	mov	[di],al
        clc
	ret
ModifyRegisters ENDP
putflags PROC
ifndef NOFS
        test    [optfs],255
        jz      pf1
        mov     bx,offset wnd_reg2
        call    w_setwind
        push    ax
pf1:
endif
	mov	dl,C_RESERVEDWORD
	call	PutChar
	mov	si,offset cs:flm
putflags2:
	lods	byte ptr cs:[si]
	or	al,al
	js	pfdone
	movzx	ax,al
	bt	word ptr [RegdumpFLAGS],ax
	lods	dword ptr cs:[si]
	mov	edx,eax
	jc	isclr
	shr	edx,16
isclr:
	xchg	dh,dl
	call	PutChar
	xchg	dl,dh
	call	PutChar
ifndef NOFS
        test    [optfs],255
        jnz     pfns
endif
	call	PrintSpace
pfns:
	jmp	putflags2
pfdone:
	mov	dl,C_DEFAULT
	call	PutChar
ifndef NOFS
        test    [optfs],255
        jz      pf2
        pop     bx
        call    w_setwind
pf2:
endif
	ret
putflags ENDP

putjmps PROC
	push es
	mov eax,regdumpEIP
	mov es,regdumpCS
	mov ax,es:[eax]
	pop es
	push ax
	mov bl,ah
	and ax,0f0ffh
	cmp ax, 800fh
	pop ax
	jz  dojmp
	mov bl,al
	and ax,0f0h
	cmp ax, 70h
	jz dojmp
	ret
dojmp:
	and bx,0fh
	cmp bl, 0ch
	jae prs
	add bx,bx
	add bx,bx
	mov ax,word ptr [regdumpflags]
	and ax,[bx + jmptab + 0]
	cmp ax,[bx + jmptab + 2]
	jnz noprnt
prnt:
	call PrintFollowingMessage
	db "     (jumps)"
	db 0	
noprnt:
	ret
prs:
	mov bh,byte ptr [regdumpflags]
	and bh, 0c0h
	cmp bl,0ch ; jl
	jnz prs1
	cmp bh,80h
	jz	prnt
	jmp noprnt
	
prs1:
	cmp bl,0dh ; jge
	jnz prs2
	test bh,40h
	jnz	prnt
	test bh,80h
	jz prnt
	jmp noprnt	
prs2:
    cmp bl,0eh ; jle
 	jnz prs3
	or bh,bh
	jnz prnt
	jmp noprnt
prs3:	; jg
	or bh,bh
	jz	prnt
	jmp noprnt
	
putjmps ENDP
;
; Display the processor regs
;
DisplayRegisters	PROC	
ifndef NOFS
        test    [optfs],255
        jz      drnorm
        mov     bx,offset wnd_reg
        call    w_setwind
        push    ax
        mov     si, offset cs:peax
        mov     dx, offset cs:rPutDword
        sub     cx,cx
        call    PrintAFew
		mov	si,offset cs:pds		; Now put the segs
        mov     dx,offset cs:rPutWord   
        call    PrintAFew               
        mov     si,offset cs:peflags2            ;Put the flags
        call    rPutDword
        call    putflags
        pop     bx
        call    w_setwind
        ret
drnorm:
endif
	mov	si, offset cs:peax		; Print GP regs
	mov	dx,offset cs:rPutDword		; with the DWORD function
	call	PrintAFew			; Print them
	mov	si,offset cs:peflags		;Put the flags
	call    rPutDword		
	call	putflags
	mov	si,offset cs:pds		; Now put the segs
	mov	dx,offset cs:rPutWord	
	call	PrintAFew
	mov	ebx,dword ptr [RegdumpEIP]	; Dissassemble at current code pointer
	mov	dx,[RegdumpCS]		
        inc     DisWithAddr
	call	DisOneLine		
	call	putjmps		
	clc
	ret
DisplayRegisters	ENDP	
END