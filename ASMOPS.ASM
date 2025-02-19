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
; ASMOPS.ASM
;
; Function: Assembler operand parsers
;
	;MASM MODE
	.MODEL SMALL
	.386

include iasm.inc
include easm.inc
include iopcodes.inc
include eopcodes.inc
include eopcom.inc
include eprints.inc 
include einput.inc 
include emtrap.inc
include	edispatc.inc
include eoperand.inc
include eoptions.inc

	PUBLIC	AOP0,  AOP1,  AOP2,  AOP3,  AOP4,  AOP5,  AOP6,  AOP7
        PUBLIC  AOP8,  AOP9,  AOP10, AOP11, AOP12, AOP13, AOP14, AOP15
	PUBLIC	AOP16, AOP17, AOP18, AOP19, AOP20, AOP21, AOP22, AOP23
	PUBLIC	AOP24, AOP25, AOP26, AOP27, AOP28, AOP29, AOP30, AOP31
	PUBLIC	AOP32, AOP33, AOP34, AOP35, AOP36, AOP37, AOP38, AOP39
	PUBLIC	AOP40, AOP41, AOP42, AOP43, AOP44, AOP45, AOP46, AOP47
	PUBLIC	AOP48, AOP49, AOP50, AOP51, aop52, AOP53, AOP54, AOP55
        PUBLIC  AOP56, AOP57, AOP58, AOP59, AOP60, AOP61, AOP62, AOP63
        PUBLIC  AOP64, AOP65, AOP66, AOP67, AOP68, AOP69, AOP70

	.data
base16c	dw	0ff03h,0ff05h,0ff07h,0ff06h,0705h,0605h, 0703h,0603h
	dw	0ffffh,0ffffh,0ffffh,0ffffh,0507h,0506h, 0307h,0306h

	.code

;Check if arg1.asize is 4 or less.  If greater, return error to caller's
;caller by mucking with the stack.

intsize PROC
	cmp	[arg1.asize],DWORDSIZE	;maybe this means the first argument
	ja	rtnDirectlyToDispatcherWithCY	;can't exceed dword size
	ret
intsize	ENDP

;See if the mode field for this structure references a memory operand
;and return error to caller's caller if not

chkmem	PROC
	cmp	[bx+asmop.mode],AM_MEM		;this is 3
	jne	rtnDirectlyToDispatcherWithCY	;bomb if not memory operand
	ret
chkmem	ENDP

;See if the mode field for this structure references an immediate operand
;and return error to caller's caller if not

chkimm	PROC
	cmp	[bx+asmop.mode],AM_IMM		;check if immediate
	jne	rtnDirectlyToDispatcherWithCY	;if not, bomb
	ret
chkimm	ENDP

;See if the mode field for this structure references a segment
;and return error to caller's caller if not

chkseg	PROC
	cmp	[bx+asmop.mode],AM_SEG
	jne	rtnDirectlyToDispatcherWithCY
	ret
chkseg	ENDP

;This is a little more complicated. Let's hypothesize that chkregw is 
;shorthand for checking a 16-bit register type opcode. In this case,maybe the
;opcode must contain more than a single byte.  So before we check if it
;is a register-type opcode, we must make sure it has extra byte(s). So
;we stop here first, and if the length makes us happy, then we check mode
;  Next guess - if this is a byte argument, we bomb since a word register
;requires a word operand.

chkregw	PROC
	cmp	[bx+asmop.asize],BYTESIZE	;is this a byte opcode
	je	rtnDirectlyToDispatcherWithCY	;if so, bomb
	jmp	chkreg			;else check mode for register type
chkregw	ENDP

;Possibly this is used for in and out, where DX is the only register
;allowed?

chkdx	PROC
	cmp	[bx+asmop.asize],WORDSIZE	;if not a word register
	jne	rtnDirectlyToDispatcherWithCY	;then bomb
	cmp	[bx+asmop.areg1],isEDX		;else see if DX register
	jne	rtnDirectlyToDispatcherWithCY	;if not, bomb
	jmp	chkreg
chkdx	ENDP

;Not sure about the AX part of this, since all that is being checked is
;a size of byte

chkaxw	PROC
	cmp	[bx+asmop.asize],BYTESIZE	;if a byte register
	je	rtnDirectlyToDispatcherWithCY	;then bomb
chkaxw	ENDP

;This IS a check for AX (actually, 0 is EAX)

chkax	PROC
	cmp	[bx+asmop.areg1],0	    	;if not EAX (maybe AX or AL)
	jne	rtnDirectlyToDispatcherWithCY	;then bomb
chkax	ENDP

;Check for a register?  As opposed to ??

chkreg	PROC
	cmp	[bx+asmop.mode],AM_REG		;is this flag set?
	jne	rtnDirectlyToDispatcherWithCY	;if not, bomb
	ret
chkreg	ENDP

;Check for a mmx register?  As opposed to ??

chkmmx  PROC
        cmp     [bx+asmop.mode],AM_MMX          ;is this flag set?
	jne	rtnDirectlyToDispatcherWithCY	;if not, bomb
	ret
chkmmx  ENDP

;We bomb if arg3.mode isn't none, and if it is, we still bomb if arg2.mode
;is none.  So arg3 is required to have a 'mode', whatever that is, I guess

noarg3	PROC
	cmp	[arg3.mode],AM_NONE
	jne	rtnDirectlyToDispatcherWithCY
	cmp	[arg2.mode],AM_NONE
	je	rtnDirectlyToDispatcherWithCY
	ret
noarg3	ENDP

;Same as above, except it applies to arg2

noarg2	PROC
	cmp	[arg2.mode],AM_NONE
	jne	rtnDirectlyToDispatcherWithCY
	cmp	[arg1.mode],AM_NONE
	je	rtnDirectlyToDispatcherWithCY
	ret
noarg2	ENDP

;Whoa, lets see here.  If arg1.mode, whatever that is, is NOT 0, we jnz to
;rtnDirectlyToDispatcherWithCY. Since this routine was called, the return 
;address is on the stack. Which means rtnDirectlyToDispatcherWithCY strips 
;off the return address, and returns to the caller's caller. 

noarg1	PROC
	cmp	[arg1.mode],AM_NONE
	jne	rtnDirectlyToDispatcherWithCY
	ret
noarg1	ENDP
;
; pops the ret address from the AOP caller
; and goes directly back to the parser with a mismatch error
;
rtnDirectlyToDispatcherWithCY	PROC
	pop	ax
	stc
	ret
rtnDirectlyToDispatcherWithCY	ENDP


;see if size of this opcode is 1. If not, we are returning NZ and AL=1. I
;assume that 1 is important, since without the OR line, we would also be
;returning NZ if the size was not 1. In fact, several callers immediately
;do a stosb, so at the very least we are ensuring an odd number???
;  Next guess: AL will eventually be used as part of the stored, assembled
;byte.  So apparently the purpose of this routine is to set bit 0 of the
;untimate assembled value if this is NOT a byte operand.

sizeb0	PROC
	cmp	[bx+asmop.asize],BYTESIZE
	je	szb0x
	or	al,1
szb0x:
	ret
sizeb0	ENDP

;In which case, the purpose of this routine is to set bit 3 of AL if the
;operand is NOT a byte operand.

sizeb3	PROC
	cmp	[bx+asmop.asize],BYTESIZE
	je	szb3x
	or	al,8
szb3x:
	ret
sizeb3	ENDP
;
; main RM handler
;
; within this routine, CX = pointer to mod/RM byte and DX = flag for
; <e>bp based indexing
;
; all MOD/RM fields are set up assuming no offset and updated 
; later...
;
asmfrm	PROC
	cmp	[bx+asmop.mode],AM_FPREG ; check for register direct mode
	jne	asmrm2
	or	al,0c0h			; modrm = 0c0+al+regval
	or	al,[bx+asmop.areg1]
	stosb
	ret
	
asmfrm	ENDP

asmrmmmx PROC
        cmp     [bx+asmop.mode],AM_MMX
        jne     asmrm
        shl     al,3
        or      al,0c0h
        or      al,[bx + asmop.areg1]
        stosb
        ret
asmrmmmx ENDP


asmrm	PROC
	shl	al,3			; shift reg val into place
asmrm	ENDP


asmrm2	PROC
;
; registers are the same in both 16 & 32-bit
;
	cmp	[bx+asmop.mode],AM_REG	; 1check for register direct mode
	jne	rmnreg
	or	al,0c0h			; modrm = 0c0+al+regval
	or	al,[bx+asmop.areg1]
	stosb
	ret
rmnreg:
	cmp	[bx+asmop.msize],DWORDMODE	; see which style of addressing
	je	asmrm32
;
; 16-bit MEM handler
;
	cmp	[bx+asmop.mode],AM_MEM	; 16 bit, check for mem
	jne	rm16nmem
	or	al,6			; MODRM = 6+al
	stosb
	jmp	rmwoffs
rm16nmem:
	cmp	[bx+asmop.mode],AM_BASED ; check for 16 bit based
	jne	rtnDirectlyToDispatcherWithCY
;
; 16-bit base handler, restricted combos and no scaling
;
	push	ax			; yes, get the reg vals
	sub	ax,ax
	mov	al,[bx+asmop.areg1]
	mov	ah,[bx+asmop.areg2]
	mov	dx,ax
	push	di			; scan for a match and to get index
	mov	di,offset base16c
	mov	cx,16
	repne	scasw
	pop	di
	pop	ax
	jnz	rtnDirectlyToDispatcherWithCY	; scan failed, exit
	bt	cx,3
	jc	rm16nswap
	xchg	dl,dh
rm16nswap:
	and	cl,7
	or	al,cl
	mov	cx,di			; cx points at modrm byte
	stosb
	jmp	rmanyoffs		; check for offs
;
; 32-bit modes start here
;
asmrm32:
	cmp	[bx+asmop.mode],AM_MEM	; 32 bit, check for mem
	jne	rm32nmem
;
; generic mem handler
;
	or	al,5			; MODRM = 5+al
	stosb
	jmp	rmwoffs
rm32nmem:
	cmp	[bx+asmop.mode],AM_BASED 	; check for based
	jne	rtnDirectlyToDispatcherWithCY	; not legal if not
	cmp	[bx+asmop.areg2],0FFh	; else see if second reg defined
	je	rm32bbonly
	cmp	[bx+asmop.areg1],0FFh	; else see if first reg defined
	je	rm32bionly
;
; both a base AND an index
;
; the parser should have checked that ESP is not the scond arg
; and that we don't have two EBP args
;
	cmp	[bx+asmop.areg1],isEBP	; check for BP based
	je	rm32bbsebp
	or	al,4			; flag MOD for SIB
	mov	cx,di
	stosb
	bsf	ax,[bx+asmop.ascale]	; calculate SIB byte
	shl	ax,3
	or	al,[bx +asmop.areg2]
	shl	ax,3
	or	al,[bx+asmop.areg1]
	stosb
	sub	dx,dx
	jmp	rmanyoffs
;
; base and index, base is ebp
rm32bbsebp:
	or	al,4
	mov	cx,di
	stosb
	bsf	ax,[bx+asmop.ascale]	; calculate SIB byte
	shl	ax,3
	or	al,[bx+asmop.areg2]
	shl	ax,3
	or	al,5			; bp based
	stosb
	mov	dx,0ff05h
	jmp	rmanyoffs
;
; index only
rm32bionly:
	or	al,4 			; select SIB byte
	stosb
	bsf	ax,word ptr [bx+asmop.ascale] ; calculate scale factor
	shl	ax,3			; shift over
	or	ax,word ptr [bx+asmop.areg2] ; add in index
	shl	ax,3			; shift over
	or	ax,5			; base = 5, that is none since mod = 0
	stosb
	mov	eax,[bx+asmop.addrx]	; always 32-bit ofs in this mode
	stosd
	ret
;
; only a base reg
;
rm32bbonly:
	; shouldn't get here if no regs
	cmp	[ebx+asmop.areg1],isESP	; only one reg, check for ESP
	je	rm32besp
	cmp	[ebx+asmop.areg1],isEBP	; only one reg, check for EBP
	je	rm32bebp
	or	al,[ebx+asmop.areg1]	; no, normal MODRM byte with no SIB
	mov	cx,di
	stosb
	mov	dh,0FFh			; pretend 16 bit
	mov	dl,al
	and	dl,7
	jmp	rmanyoffs
;
; based ESP, no index
;
rm32besp:
	or	al,4    		; select SIB byte (sib needed
	mov	cx,di			; for indexing off ESP)
	stosb
	mov	al,24h			; sib byte for [esp] mode
	stosb
	sub	dx,dx
	jmp	rmanyoffs
;
; based ebp, no index
;
rm32bebp:
	or	al,5
	mov	cx,di			; so we can adjust mod later
	stosb
	mov	dx,0ff05h		; MUST have offset, this is BP base reg
	jmp	rmanyoffs
;
; now the auto offset routine.
; if (E)BP, we ALWAYS have an offset	
; otherwise we see if the offset is zero before encoding anything
	
asmrm2	ENDP
rmanyoffs PROC
	mov	eax,[bx+asmop.addrx]	; get offs
	cmp	dx,0ff05h		; BP reg ALWAYS has offs
	je	rmaomho

	or	eax,eax 		; else no offs if offs = 0
	jz	rmaook
;
; if we get here we have an offset, fix the RM field and embed the
; offset
;
rmaomho:
	xchg	cx,bx
	add	byte ptr [bx],40h	; else set MOD field = 1
	xchg	cx,bx
	and	eax,NOT 7FH		; else see if fits in a byte
	jz	rmboffs
	cmp	eax,NOT 7fh
	je	rmboffs    		; yep, go do it
	xchg	cx,bx
	add	byte ptr [bx],40h	; else MOD field = 2
	xchg	cx,bx
	jmp	rmwoffs			; and go do it

rmboffs:
	mov	eax,[bx+asmop.addrx]	; get offs
	stosb      			; store a byte offs
rmaook:
	clc
	ret
rmanyoffs	ENDP
rmszoffs	PROC
	mov	eax,[bx+asmop.addrx]
	cmp	[bx+asmop.msize],WORDMODE
	jae	rmwoffs
	stosb
	clc
	ret
rmszoffs	ENDP
rmwoffs	PROC
	mov	eax,[bx+asmop.addrx]	; check size
	cmp 	[bx+asmop.msize],WORDMODE
	ja	rmdwoffs
	stosw				; word offs
	clc
	ret
rmdwoffs:
	test	[Disassemble32Bit],1
	jz	rtnDirectlyToDispatcherWithCY
	stosd				; dword offs
	clc
	ret
rmwoffs	ENDP
rmszimm	PROC
	mov	eax,[bx+asmop.addrx]	; check size
	cmp	[bx+asmop.asize],WORDSIZE
	jae	rmszimmw
	stosb
	clc
	ret
rmszimmw:
	jne	rmszimmd
	stosw
	ret
rmszimmd:
	cmp	[bx+asmop.asize],DWORDSIZE
	jne	rtnDirectlyToDispatcherWithCY
	test	[Disassemble32Bit],1
	jz	rtnDirectlyToDispatcherWithCY
	stosd
	ret
rmszimm	ENDP

shiftopsize PROC
        cmp     [arg1.asize],DWORDSIZE
        jz      sozdword
        cmp     [arg1.asize],WORDSIZE
        jnz     sozret
        or      [PrefixBitmapWord],AS_OPSIZESET
sozret:
        ret
sozdword:
        or      [PrefixBitmapWord],AS_OPSIZE
        ret
shiftopsize ENDP
;
; no operands. In this case, the opcode length is 1, so we go through this
;	weird locution to rep mov a single byte out of the structure and
;	into [di], wherever that points. Apparently it points into an opcode
;	buffer somewhere. If the opcode length is greater than one, what
;	happens?
;
AOP0	PROC
	call	noarg1			;see if arg1.mode=0, whatever that means
	push	si			;only return here if it IS 0
	movzx	cx,[si+opcode.oclength]	;so get the length of the opcode
	lea	si,[si+opcode.compare]	;find the opcode in the structure
	rep	movsb			;copy from structure to buffer
	pop	si			;restore pointer to structure
	clc				;say no problem
	ret
AOP0	ENDP
;
; word reg, bits 0-2 of opcode = reg num
;
AOP1	PROC
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	call	chkregw
	mov	al,byte ptr [si+OPCODE.COMPARE]
	or	al,[arg1.areg1]
	stosb
	clc
	ret
AOP1	ENDP
;
; word acc,reg... reg = bits 0-2 of opcode
;
AOP2	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg1
	call	chkaxw
	mov	bx,offset arg2
	call	chkregw
	mov	al,byte ptr [si+opcode.compare]
	or	al,[arg2.areg1]
	stosb
	ret
AOP2	ENDP
;
; one arg, seg goes in b3-4 of opcode
;
AOP3	PROC
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	call	chkseg
	mov	ah,byte ptr [si+OPCODE.COMPARE]
	mov	al,[arg1.areg1]
	cmp	ah,8
	jae	aop3ext
	cmp	al,4
	jae	aop3errx
aop3c:
	shl	al,3
	or	al,ah
	stosb
	ret
aop3ext:
	sub	al,4
	jnc	aop3c
aop3errx:
	stc
	ret
	
AOP3	ENDP
;
; either combo of a reg & rm... bit 1 of opcode set if reg is dest
; bit 0 set if size = word
;
AOP4	PROC
	call	noarg3
	call	intsize
	sub	al,al
	mov	bx,offset arg1
	call	sizeb0
 	cmp	[arg1.mode],AM_REG
	jne	aop4rs
	or	al,2
	mov	bx,offset arg2
	mov	ah,[arg1.areg1]
	jmp	aop4j

aop4rs:
 	cmp	[arg2.mode],AM_REG
	jne	aop4err
	mov	bx,offset arg1
	mov	ah,[arg2.areg1]
aop4j:
	or	al,byte ptr [si+OPCODE.COMPARE]
	stosb
	mov	al,ah
	call	asmrm
	ret
aop4err:
	stc
	ret
AOP4	ENDP
;
; use only rm, bit 0 = size (exception : jmp/call)
;
AOP5	PROC
	call	noarg2
	call	intsize
        test    [farptr],1
        jnz     aop5err
	mov	bx,offset arg1
	mov	ax,[si+OPCODE.COMPARE]
	test	al,1
	jz	aop5cansize
        cmp     [bx+asmop.asize],DWORDSIZE
        je      aop5unsized
	cmp	[bx+asmop.asize],WORDSIZE
	je	aop5unsized
	cmp	[bx+asmop.asize],NOSIZE
	je	aop5unsized
aop5err:
	stc
	ret
aop5cansize:
	call	sizeb0
aop5unsized:
	stosb
	xchg	al,ah
	and	al,38h
	mov	bx,offset arg1
	call	asmrm2
	ret
AOP5	ENDP
;
; rm,count or rm,cl (shifts) bit 0 = size
; bit 1 set if size = 1, bit 4 set if size = cl, otherwise follow rm with
; a count byte
;
AOP6	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg1
	mov	ax,[si+opcode.compare]
	call	sizeb0
	cmp	[arg2.mode],AM_REG
	je	aop6cl
	cmp	[arg2.mode],AM_IMM
	je	aop6imm
aop6b:
	stc
	ret
aop6cl:
	cmp	[arg2.asize],BYTESIZE
	jne	aop6b
	cmp	[arg2.areg1],isECX
	jne	aop6b
	or	al,12h
	stosb
        call    shiftopsize
	jmp	aop6rm
aop6imm:
	cmp	[arg2.addrx],1
	je	aop6shift1
	stosb
	xchg	al,ah
	call	asmrm2
	mov	al,byte ptr [arg2.addrx]
	stosb
	ret
aop6shift1:
	or	al,10h
	stosb
aop6rm:
	xchg	al,ah
	call	asmrm2
	ret
AOP6	ENDP
;
; unordered version of AOP4.  (any combo of reg and RM)
; This is XCHG instructions,
; this is unordered, so, it doesn't
; need to know which comes first
;
; bit 0 = size
;
AOP7	PROC
	call	noarg3
	call	intsize
	sub	al,al
	mov	bx,offset arg1
	call	sizeb0
 	cmp	[arg1.mode],AM_REG
	jne	aop7rs
	mov	bx,offset arg2
	mov	ah,[arg1.areg1]
	jmp	aop7j

aop7rs:
 	cmp	[arg2.mode],AM_REG
	jne	aop7err
	mov	bx,offset arg1
	mov	ah,[arg2.areg1]
aop7j:
	or	al,byte ptr [si+OPCODE.COMPARE]
	stosb
	mov	al,ah
	call	asmrm
	ret
aop7err:
	stc
	ret
AOP7	ENDP
;
; word regrm, reg = dest.
;
AOP8	PROC
        call    noarg3
        call    intsize
	cmp	[arg1.asize],BYTESIZE
        je      aop8errx
	mov	bx,offset arg1
        call    chkregw
	mov	al,byte ptr [si+OPCODE.COMPARE]
	stosb
	mov	al,[bx+asmop.areg1]
	mov	bx,offset arg2
        call    asmrm
        clc
	ret
aop8errx:
        stc
        ret
AOP8	ENDP
;
; interrupts (imm byte)
;
AOP9	PROC
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	call	chkimm
	cmp	byte ptr [arg1.addrx],3
	je	aop9i3
        cmp     byte ptr [arg1.addrx],1
        je      aop9i1
	mov	al,byte ptr [si+OPCODE.COMPARE]
	or	al,1
	stosb
	mov	al,byte ptr [bx+asmop.addrx]
	stosb
	clc
	ret
aop9i3:
	mov	al,0cch
	stosb
	ret
aop9i1:
        mov     al,0f1h
        stosb
        ret
AOP9	ENDP
;
; short relative branches
;
AOP10	PROC
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	call	chkimm
	mov		eax,[lastofs]
	sub	eax,[bx+asmop.addrx]
	neg	eax
	sub	eax,2
	cmp	eax,-128
	jl	aop10errx
	cmp	eax,127
	jle	aop10ok
aop10errx:
	stc
	ret
aop10ok:
	push	ax
	mov	al,byte ptr [si+OPCODE.COMPARE]
	stosb
	pop	ax
	stosb
	clc
	ret
AOP10	ENDP
;
; RM, IMMEDIATE
; bit 0 = size
;
AOP11	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg2
	call	chkimm
	mov	bx,offset arg1
	mov	ax,[si+OPCODE.COMPARE]
	call	sizeb0
	stosb
	xchg	al,ah
	call	asmrm2
	mov	bx,offset arg2
	call	rmszimm
	ret
AOP11	ENDP
;
; ACC,immediate
; bit 0 = size
;
AOP12	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg1
	call	chkax
	mov	bx,offset arg2
	call	chkimm
	mov	al,byte ptr [si+OPCODE.COMPARE]
	call	sizeb0
	stosb
	call	rmszimm
	ret
AOP12	ENDP
;
; mem,acc
; bit 0 = size
;
AOP13	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg2
	call	chkax
	mov	bx,offset arg1
	call	chkmem
	mov	al,byte ptr [si+OPCODE.COMPARE]
	call	sizeb0
	stosb
	call	rmszoffs
	ret
AOP13	ENDP
;
; sign-extended RM/IMM
; b1 = 0, treat as normal RM/IMM (aop11)
; else b01=11 means sign-extend byte to word
;
AOP14	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg2
	call	chkimm
	cmp	[bx+asmop.asize],BYTESIZE
	je	aop11
	mov	eax,[bx +asmop.addrx]
	cmp	eax,-128
	jl	aop11
	cmp	eax,127
	jge	aop11
;
; get here for signed extension
;
	mov	bx,offset arg1
	mov	ax,[si+opcode.compare]
	or	al,3
	stosb
	xchg	al,ah
	call	asmrm2
	mov	al,byte ptr [arg2.addrx]
	stosb
	ret
AOP14	ENDP
;
; acc,imm
; b3 of opcode = size
; 
AOP15	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg1
        call    chkreg
	mov	al,byte ptr [si+OPCODE.COMPARE]
        or      al,[bx+asmop.areg1] 
	call	sizeb3
	stosb
	mov	bx,offset arg2
	call	chkimm
	call	rmszimm
	ret
AOP15	ENDP
;
; seg,regrm or regrm,seg
; b1 set if seg is dest
;
AOP16	PROC
	call	noarg3
        call    intsize
	mov	bx,offset arg1
	cmp	[bx+asmop.mode],AM_SEG
	jne	aop16seg2
	mov	al,byte ptr [si+OPCODE.COMPARE]
	or	al,2
	mov	ah,[bx+asmop.areg1]
	mov	bx,offset arg2
	cmp	[bx+asmop.mode],AM_REG		;is this flag set?
        jnz     aop16nw1
        cmp     [bx + asmop.asize],DWORDSIZE     ; auto prefixing on
        jne     aop16nw1                ; ins & outs is disabled
        or      [PrefixBitmapWord],AS_OPSIZE
aop16nw1:
	jmp	aop16rm
aop16seg2:
	mov	bx,offset arg2
	call	chkseg
	mov	al,byte ptr [si+OPCODE.COMPARE]
	mov	ah,[bx+asmop.areg1]
	mov	bx,offset arg1
	cmp	[bx+asmop.mode],AM_REG		;is this flag set?
        jnz     aop16nw2
        cmp     [bx + asmop.asize],DWORDSIZE     ; auto prefixing on
        jne     aop16nw2                ; ins & outs is disabled
        or      [PrefixBitmapWord],AS_OPSIZE
aop16nw2:
aop16rm:
	stosb
	xchg	al,ah
	call	asmrm
	ret
AOP16	ENDP
;
; returns which pop the stack
;
AOP17	PROC
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	call	chkimm
	mov	al,byte ptr [si+OPCODE.COMPARE]
	stosb
	mov	ax,word ptr [bx+asmop.addrx]
	stosw
	clc
	ret
AOP17	ENDP
;
; far branch or call
;
AOP18	PROC
	call	noarg2
	call	intsize
	cmp	[arg1.mode],AM_SEGOFFS
	jne	aop18bad
	mov	al,byte ptr [si+OPCODE.COMPARE]
	stosb
	mov	ax,word ptr [arg1.addrx2]
	call	asm32BitMode
        jnz     fbcw
	stosw
        jmp     fbcjoin
fbcw:
        stosd
fbcjoin:
	mov	ax,word ptr [arg1.addrx]
	stosw
	clc
	ret
aop18bad:
	stc
	ret
AOP18	ENDP
;
; ESC instruction
; imm,rm... imm is six bits and fills the low three bits of the
; opcode and the reg field
;
AOP19	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg1
	call	chkimm
	mov	al,byte ptr [bx+asmop.addrx]
	shr	al,3
	and	al,7
	or	al,byte ptr [si+OPCODE.compare]
	stosb
	mov	al,byte ptr [bx+asmop.addrx]
	and	al,7
	mov	bx,offset arg2
	call	asmrm
	ret
AOP19	ENDP
;
; long relative branch
;  (the parser fills in the 0f starter)
;
AOP20	PROC
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	call	chkimm
	mov		eax,[lastofs]
	sub	eax,[bx+asmop.addrx]
	neg	eax
	sub	eax,3
	call	asm32BitMode
        jz      lrbnot32
        sub     eax,2
lrbnot32:
	cmp	byte ptr [si+OPCODE.COMPARE],0e0h
	jae	aop20got
	dec	eax
aop20got:
	call	asm32BitMode
        jnz     aop20ok
        test    eax,0ffff0000h
        jz      aop20ok
        cmp     eax,0ffff0000h
        jnc     aop20ok
aop20errx:
	stc
	ret
aop20ok:
	push	ax
	mov	al,byte ptr [si+OPCODE.COMPARE]
	stosb
	pop	ax
	call	asm32BitMode
        jnz     lrbw
	stosw
        jmp     lrbjoin
lrbw:
        stosd
lrbjoin:
	clc
	ret
AOP20	ENDP
;
;	acc,dx (in instructions)
;	bit 0 = size
;
AOP21	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg2
	call	chkdx
	mov	bx,offset arg1
	call	chkax
	mov	al,byte ptr [ si+OPCODE.COMPARE]
	cmp	[bx+asmop.asize],BYTESIZE
	je	aop21nw
	or	al,1
aop21nw:
	cmp	[bx +asmop.asize],DWORDSIZE	; auto prefixing on
	jne	aop21nw2		; ins & outs is disabled
        or      [PrefixBitmapWord],AS_OPSIZE
aop21nw2:
	stosb
	clc
	ret
AOP21	ENDP
;
; dx,acc (out_)
; bit 0 = size
;
AOP22	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg1
	call	chkdx
	mov	bx,offset arg2
	call	chkax
	mov	al,byte ptr [ si+OPCODE.COMPARE]
	cmp	[bx+asmop.asize],BYTESIZE
	je	aop22nw
	or	al,1
aop22nw:
	cmp	[bx +asmop.asize],DWORDSIZE	; auto prefixing on
	jne	aop22nw2		; ins & outs is disabled
        or      [PrefixBitmapWord],AS_OPSIZE
aop22nw2:
	stosb
	clc
	ret
AOP22	ENDP
;
; port,acc or acc,port
; b0 =size, b1 = 1 if port is dest
;
AOP23	PROC
	call	noarg3
	call	intsize
	test	byte ptr [si+OPCODE.COMPARE],2
	jz	aop23in
	mov	bx,offset arg2
	call	chkax
	mov	bx,offset arg1
	call	chkimm
	jmp	aop23j
aop23in:
	mov	bx,offset arg1
	call	chkax
	mov	bx,offset arg2
	call	chkimm
aop23j:
	mov	al,byte ptr [si+OPCODE.compare]
	cmp	[bx +asmop.asize],WORDSIZE
	jb	aop23b
       	or	al,1
aop23b:
	clc
	stosb
	mov	al,byte ptr [bx +asmop.addrx]
	stosb
	ret
AOP23	ENDP
;
; acc,mem
; bit 0 = size
;
AOP24	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg1
	call	chkax
	mov	bx,offset arg2
	call	chkmem
	mov	al,byte ptr [si+OPCODE.COMPARE]
	call	sizeb0
	stosb
	call	rmszoffs
	ret
AOP24	ENDP
;
; immediate byte or word
; this is push imm, bit 1 set for byte
; we were about due for a departure from the standard...
; anyway the op is sign-extended if it is byte size
;
AOP25	PROC
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	call	chkimm
	mov	al,byte ptr [si+OPCODE.COMPARE]
	mov	ebx,[bx+asmop.addrx]
	call	asm32BitMode
        jnz     aop25bsft
        test    ebx,0ffff0000h
        jnz     aop25w
        cmp     bx,-128
        jl      aop25w
        cmp     bx,127
        jg      aop25w
        jmp     aop25bs
aop25bsft:
	cmp	ebx,-128
	jl	aop25w
	cmp	ebx,127
	jg	aop25w
;
; byte size
;
aop25bs:
	or	al,2
	stosb
	mov	al,bl
	stosb
	ret
aop25w:
	stosb
        test   [PrefixBitmapWord],AS_OPSIZETEST
        jnz     aop25dw
	call	asm32BitMode
        jnz     aop25dw
        cmp     ebx,0ffffh
        ja      aop25dw
	mov	ax,bx
	stosw
	clc
	ret
aop25dw:
	or	[PrefixBitmapWord],AS_OPSIZE
	mov	eax,ebx
	stosd
	clc
	ret
AOP25	ENDP
;
; enter command, we have a word then a byte
;
AOP26	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg1
	call	chkimm
	mov	[bx+asmop.asize],WORDSIZE
	mov	bx,offset arg2
	call	chkimm
	mov	[bx+asmop.asize],BYTESIZE
	mov	al,byte ptr [si+OPCODE.COMPARE]
	stosb
	mov	ax,word ptr [arg1.addrx]
	stosw
	mov	al,byte ptr [arg2.addrx]
	stosb
	ret
AOP26	ENDP
;
; stringu/w/d, pushaw,pushfw, etc
; explicit byte sizing handled elsewhere (aop0)
;
AOP27	PROC
	call	noarg1
	call	intsize
	mov	al,byte ptr [si+opcode.compare]
	cmp	[lastbyte],'w'
	je	aop27w
	cmp	[lastbyte],'d'
	je	aop27dw
;
; get here if no size specced.
	mov	al,byte ptr [si+opcode.compare]
	and	al,NOT 1
	cmp	al,60h		; default for push/pop is word
        je      aop27w2
	cmp	al,9ch
        je      aop27w2
	stosb		; else default is byte
	clc
	ret
aop27dw:
	or	[PrefixBitmapWord],AS_OPSIZE	; come here if specified dword
aop27w:
        or      [PrefixBitmapWord],AS_OPSIZESET
aop27w2:
	mov	al,byte ptr [si+opcode.compare] ; or here if specified word
	stosb
	clc
	ret
AOP27	ENDP
;
; rm,reg (test instruction)
; bit 0 = size
; 
AOP28	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg2
	call	chkreg
	mov	al,byte ptr [si+OPCODE.COMPARE]
	call	sizeb0
	stosb
	mov	al,[arg2.areg1]
	mov	bx,offset arg1
	call	asmrm
	ret
AOP28	ENDP
;
; rm, size don't care
;
AOP29	PROC
	call	noarg2
	mov	ax,[si+OPCODE.COMPARE]
	stosb
	xchg	al,ah
	mov	bx,offset arg1
	call	asmrm2
	ret
AOP29	ENDP
;
; RM, shift
; bit 0 & 1 of opcode set if uses CL
; bit 0 & 4 set if uses uses 1
; else nothing set
;
AOP30	PROC
	call	noarg3
	call	intsize
	mov	ax,word ptr [si+OPCODE.compare]
	and	al,0ech	; get rid of extraneous bits
	mov	bx,offset arg2
	cmp	[bx+asmop.areg1],isEBX
	je	aop30cl
	call	chkimm
	cmp	[bx+asmop.addrx],1
	jne	aop30xx
	or	al,11h
	stosb
	xchg	al,ah
	call	asmrm2
	ret
aop30xx:
	or	al,3
	stosb
	xchg	al,ah
	call	asmrm2
	mov	al,byte ptr [arg2.addrx]
	stosb
	ret
aop30cl:
	cmp	[bx+asmop.asize],BYTESIZE
	jne	aop30bad
	cmp	[bx+asmop.mode],AM_REG
	jne	aop30bad
	stosb
        call    shiftopsize
	xchg	al,ah
	call	asmrm2
	ret

aop30bad:
	stc
	ret
AOP30	ENDP
;
; reg,rm,imm or reg,imm (imul)
; bit 1 = set if immed = signed byte
;
AOP31	PROC
	cmp	[arg3.mode],AM_NONE
	jne	aop31three
	mov	bx,offset arg1
	call	chkreg
	mov	al,byte ptr [si+OPCODE.compare]
	mov	bx,offset arg2
	call	chkimm
	call	aop31sb
	stosb
	push	ax
	mov	al,[arg1.areg1]
	mov	ah,al
	shl	al,3
	or	al,ah
	or	al,0c0h
	stosb
	jmp	aop31sz
aop31three:
	mov	bx,offset arg1
	call	chkreg
	mov	al,byte ptr [si+OPCODE.compare]
	mov	bx,offset arg3
	call	chkimm
	call	aop31sb
	stosb
	push	ax
	push	bx
	mov	al,[arg1.areg1]
	mov	bx,offset arg2
	call	asmrm
	pop	bx
aop31sz:
	pop	ax
	test	al,2
	mov	eax,dword ptr [bx +asmop.addrx]
	jnz	aop31sb1
	test	[PrefixBitmapWord],AS_OPSIZE
	jz	aop31szw
	stosd
	clc
	ret
aop31szw:
	stosw
	clc
	ret
aop31sb1:
	stosb
	clc
	ret
aop31sb	PROC
	mov	ecx,[bx+asmop.addrx]
	test	ecx,NOT 7fh
	jnz	aop31sbx
	cmp	ecx,-80h
	jl	aop31sbx
	cmp	[bx+asmop.asize],BYTESIZE
	je	aop31sbx
	or	al,2
aop31sbx:
	ret
aop31sb	ENDP

AOP31	ENDP
;
; move to/from a special register
; bit 1 = set if spc reg is the dest
; bit 0 & 2 define the special reg
;
AOP32	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg1
	mov	cx,offset arg2
	mov	ax,[si+OPCODE.COMPARE]
	cmp	[arg1.asize],DWORDSIZE
	jne	aop32bad
	cmp	[arg1.mode],am_reg
	je	aop32crsource
	or	al,2
	xchg	bx,cx
aop32crsource:       		
	sub	dl,dl
	cmp	[ecx+asmop.mode],AM_CR
	je	aop32c
	mov	dl,1
	cmp	[ecx+asmop.mode],AM_DR
	je	aop32c
	mov	dl,4
	cmp	[ecx+asmop.mode],AM_TR
	jne	aop32bad
aop32c:
	or	al,dl
	stosb
	
	call	chkreg
	movzx	ecx,cx
	mov	al,[ecx+asmop.areg1]
	shl	al,3
	or	al,[bx +asmop.areg1]
	or	al,ah		; actually is a MOD/RM which is restricted
				; to regs
	stosb
	call	asm32BitMode
        jnz     aop32d
	and	[PrefixBitmapWord],NOT AS_OPSIZE	; don't need opsize for this
					; and there will be no clash
					; if we got this far
        or      [PrefixBitmapWord],AS_OPSIZESET        ; don't need opsize for this
	ret
aop32d:
        or      [PrefixBitmapWord],AS_OPSIZE        ; don't need opsize for this
        ret
aop32bad:
	stc
	ret
AOP32	ENDP
;
; rm,reg,count (shld/shrd)
; bit 0 = set if using CL for count
;
;
aop33	PROC
	mov	bx,offset arg2
	call	chkreg
	cmp	[bx+asmop.asize],BYTESIZE
	je	aop33bad
	mov	ah,[bx+asmop.areg1]
	mov	al,byte ptr [si+OPCODE.compare]
	mov	bx,offset arg3
	cmp	[bx+asmop.areg1],isECX
	je	aop33cl
	call	chkimm
	stosb
	xchg	al,ah
	mov	bx,offset arg1
	call	asmrm
	mov	al,byte ptr [arg3.addrx]
	stosb
	ret
aop33cl:
	cmp	[bx+asmop.mode],AM_REG
	jne	aop33bad
	or	al,1h
	stosb
        call    shiftopsize
	xchg	al,ah
	mov	bx,offset arg1
	call	asmrm
	ret

aop33bad:
	stc
	ret
AOP33	ENDP
;
; push & pop rm
;
AOP34	PROC
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	cmp	[bx+asmop.asize],BYTESIZE
	je	aop34bad
	mov	ax,[si+OPCODE.compare]
	stosb
	xchg	al,ah
	call	asmrm2
	ret
aop34bad:
	stc
	ret
AOP34	ENDP
;
; floating R/M
; bit two of opcode set if size is qword
; bit 3 of mod/rm set if last ch = 'p'
;
AOP35	PROC
        
     	call	noarg2
	mov	ax,[si+OPCODE.COMPARE]
	and	ax,010d8h
	cmp	[arg1.mode],AM_FPREG
	je	aop35fin
	cmp	[arg1.asize],QWORDSIZE
	jne	aop35fin
	or	al,4
aop35fin:
	cmp	[lastbyte],'p'
	jne	aop35fin2
	or	ah,8
aop35fin2:
	stosb
	xchg	al,ah
	mov	bx,offset arg1
	call	asmfrm
	ret
AOP35	ENDP
;
; fmathp
; sti),st(0) or nothing
;
AOP36	PROC
	cmp	[arg3.mode],AM_NONE
	jne	aop36errx
	mov	ax,100h
	cmp	[arg2.mode],AM_NONE
	jne	aop362arg
        cmp     [arg1.mode],AM_FPREG
        jnz     aop36errx
        mov     ah,[arg1.areg1]
	jmp	aop36fin
aop362arg:
	cmp	[arg1.mode],AM_FPREG
	jne	aop36errx
	cmp	[arg2.mode],AM_FPREG
	jne	aop36errx
	cmp	[arg2.areg1],isEAX
	jne	aop36errx
	mov	ah,[arg1.areg1]
aop36fin:
	or	ax,[si+OPCODE.COMPARE]
	stosw
	ret
aop36errx:
	stc
	ret
AOP36	ENDP
;
; fmath
; st(i),st(0) ; st(0), st(i), mem
; bit two of opcode set for i dest or qword mem
; bit 3 of mod/rm gets flipped if reg & al &6 & bit 5 of mod/rm set
; 
;
AOP37	PROC
	cmp	[arg3.mode],AM_NONE
	jne	aop37errx
	mov	ax,[si+OPCODE.COMPARE]
	and	al,NOT 4
	cmp	[arg2.mode], AM_NONE
	je	aop37mem
	cmp	[arg1.mode],AM_FPREG
	jne	AOP37mem
	cmp	[arg2.mode],AM_FPREG
	jne	AOP37errx
	mov	bl,[arg2.areg1]
	mov	bh,[arg1.areg1]
	cmp	bh,0
	je	aop37isrc
	cmp	bl,0
	jne	aop37errx
	xchg	bl,bh
	or	al,4
aop37isrc:
	test	al,6
	jz	aop371
	test	ah,20h
	jz	aop371
	xor	ah,8
aop371:
	or	ah,bl
	or	ah,0c0h
	stosw
	ret
aop37mem:
        cmp     [arg1.mode],AM_FPREG
        jne     aop37memr
        mov     ah,[arg1.areg1]
        or      ah,0c0h
        mov     al,4
        or      ax,[si+OPCODE.COMPARE]
        stosw
        ret
aop37memr:
        cmp     [arg2.mode],AM_NONE
	jne	aop37errx
	cmp	[arg1.asize],QWORDSIZE
	jne	aop37memnq
	or	al,4
aop37memnq:
	stosb
	xchg	al,ah
	mov	bx,offset [arg1]
	call	asmfrm
	ret
aop37errx:
	stc
	ret
AOP37	ENDP
;
; far RM
;
AOP38	PROC
	call	noarg2
        test    [farptr],1
        jz      aop38errx
	cmp	[arg1.mode],AM_REG
	je	aop38errx
	mov	ax,[si+opcode.compare]
	stosb
	xchg	al,ah
	mov	bx,offset arg1
	call	asmrm2
	ret
aop38errx:
	stc
	ret
AOP38	ENDP
;
; word regrm with reg  source
; bug: lets arpl [bx],eax through
;
AOP39	PROC
	cmp	[arg2.asize],BYTESIZE
	jne	AOP40
	stc
	ret
AOP39	ENDP
;
; regrm with reg source
; bit 0 = size
AOP40	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg2
	call	chkreg
	mov	al,byte ptr [si+opcode.compare]
	call	sizeb0
	stosb
	mov	al,[arg2.areg1]
	mov	bx,offset arg1
	call	asmrm
	ret
AOP40	ENDP
;
; rm,immediate
;
AOP41	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg2
	call	chkimm
	cmp	[arg1.asize],BYTESIZE
	je	aop41errx
	mov	ax,[si+OPCODE.COMPARE]
	stosb
	xchg	al,ah
	mov	bx,offset arg1
	call	asmrm2
	mov	al,byte ptr [arg2.addrx]
	stosb
	ret
aop41errx:
	stc
	ret
AOP41	ENDP
;
; regrm with reg dest & forced strictness (MOVZX & MOVSX)
; bit 0 of opcode set if size is word
;
AOP42	PROC
	call	noarg3
	call	intsize
	mov	bx,offset arg1
	call	chkreg
	cmp	[arg1.asize],BYTESIZE
	je	aop42errx
	cmp	[arg2.asize],NOSIZE
	je	aop42errx
	mov	bx,offset arg2
	mov	ax,[si+OPCODE.COMPARE]
	call	sizeb0
	stosb
        mov     al,[arg1.areg1]
        shl     al,3
        or      al,ah
	call	asmrm2
	cmp	[arg1.asize],DWORDSIZE	; another func for which
					; auto extend to dword doesn't work
	jne	aop42x
	or	[PrefixBitmapWord],AS_OPSIZE
aop42x:
        or      [PrefixBitmapWord],AS_OPSIZESET
	ret
aop42errx:
	stc
	ret
AOP42	ENDP
;
; not needed in assembler, same as no args
; 
AOP43	PROC
	call	asm32BitMode
        jz      aop43off
        or      [PrefixBitmapWord],AS_OPSIZESET
aop43off:
	jmp	aop0
AOP43	ENDP
;
; unused
;
AOP44	PROC
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	call	chkreg
	cmp	[bx+asmop.asize],DWORDSIZE
	jne	aop44errx
	or	[PrefixBitmapWord],AS_OPSIZE
	mov	al,byte ptr [si+OPCODE.COMPARE]
	or	al,[bx+asmop.areg1]
	stosb
	ret
aop44errx:
	stc
	ret
AOP44	ENDP
;
; any regrm with reg source
; same as aop40
;
AOP45	PROC
	jmp	aop40
AOP45	ENDP
;
; rm , size don't care, but no regs
;
AOP46	PROC
	cmp	[arg1.mode],AM_FPREG
	je	aop46err
	cmp	[arg1.mode],AM_REG
	jne	aop29
aop46err:
	stc
	ret
AOP46	ENDP
;
; ax reg only
;
AOP47	PROC
	call	noarg2
	mov	bx,offset arg1
	call	chkaxw
	mov	ax,[si+OPCODE.COMPARE]
	stosw
	clc
	ret
AOP47	ENDP
;
; bswap, 32-bit reg to bits 0-3 of opcode
;
AOP48	PROC
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	call	chkreg
	cmp	[bx+asmop.asize],DWORDSIZE
	jne	aop48errx
	or	[PrefixBitmapWord],AS_OPSIZE
	mov	al,byte ptr [si+OPCODE.COMPARE]
	or	al,[bx+asmop.areg1]
	stosb
	ret
aop48errx:
	stc
	ret
AOP48	ENDP
;
; fst
; same as next but no tbyte
;
AOP49	PROC
	cmp	[arg1.asize],TBYTESIZE
	jb	aop50
	stc
	ret
AOP49	ENDP
;
; fld/fstp
; freg
; dword,qword,tybe
; bit 1 of opcode set for tbyte
; bit 2 of opcode set for qword or store
; bit 5 of modrm set if tbyte
; bit 3 of modrm gets cleared if not tbyte && bit 4 set
;
AOP50	PROC
	call	noarg2
	mov	ax,[si+OPCODE.COMPARE]
	AND	ax,NOT 0e006h
	cmp	[arg1.mode],AM_FPREG
	je	aop50reg
	cmp	[arg1.asize],DWORDSIZE
	jb	aop50errx
aop502:
	cmp	[arg1.asize],TBYTESIZE
	jne	aop503
	or	ax,2802h
	jmp	aop505

aop503:
	
	cmp	[arg1.asize],QWORDSIZE
	jne	aop504
	or	al,4
aop504:
	test	ah,10h
	jnz	aop505
	and	ah,NOT 8
aop505:
	stosb
	xchg	al,ah
	mov	bx,offset arg1
	call	asmfrm
	ret
aop50reg:
	test	ah,10h
	jnz	aop506
	and	ah,NOT 8
	jmp	aop507
aop506:
	or	al,4
aop507:
	or	ah,0c0h
	or	ah,[arg1.areg1]
	stosw
	ret
aop50errx:
	stc
	ret
AOP50	ENDP
;
;
; fbld/fbstp
; tbyte ptr mem
;
AOP51	PROC
	call	noarg2
	cmp	[arg1.mode],AM_FPREG
	je	aop51errx
	cmp	[arg1.asize],NOSIZE
	je	aop51c
	cmp	[arg1.asize],TBYTESIZE
	jne	aop51errx
aop51c:
	mov	ax,[si+OPCODE.COMPARE]
	stosb
	xchg	al,ah
	mov	bx,offset arg1
	call	asmfrm
	ret
aop51errx:
	stc
	ret
AOP51	ENDP
;
; fild/fistp
; word,dword,qword mem
; bit 2 of opcode set if word or qword
; bit 3 of modrm gets cleared if not qword & bit 4 is set
; bit 5 or modrm set if qword
;
AOP52	PROC
	call	noarg2
	mov	ax,[si+OPCODE.COMPARE]
	and	ax,NOT 2004h
	cmp	[arg1.mode],AM_FPREG
	je	aop52errx
	cmp	[arg1.asize],DWORDSIZE
	je	aop522
       	or	al,4
aop522:
	cmp	[arg1.asize],QWORDSIZE
	ja	aop52errx
	jne	aop523
	or	ah,20h
	jmp	aop524
aop523:
	test	ah,10h
	jnz	aop524
	and	ah, NOT 8
aop524:	
	stosb
	xchg	al,ah
	mov	bx,offset arg1
	call	asmfrm
	ret
aop52errx:
	stc
	ret
AOP52	ENDP
;
; fist
; same as above but no qword mode
;
AOP53	PROC
	cmp	[arg1.asize],QWORDSIZE
	jb	aop52
	stc
	ret
AOP53	ENDP
;
; freg
; reg put in mod/rm byte
;
AOP54	PROC
	call	noarg2
	cmp	[arg1.mode],AM_FPREG
	jne	aop54errx
	mov	ax,[si+OPCODE.COMPARE]
	or	ah,[arg1.areg1]
	stosw
	ret
aop54errx:
	stc
	ret
AOP54	ENDP
;
; same as above, deault to reg 1 if no args
AOP55	PROC
	cmp	[arg3.mode],AM_NONE
	jne	aop55errx
	cmp	[arg2.mode],AM_NONE
	jne	aop55errx
	call	noarg2
	mov	ax,[si+OPCODE.COMPARE]
	cmp	[arg1.mode],AM_FPREG
	jne	aop55chknone
	or	ah,[arg1.areg1]
	stosw
	ret
aop55chknone:
	cmp	[arg1.mode],AM_NONE
	jne  	aop55errx
	or	ah,1
	stosw
	ret	
aop55errx:
	stc
	ret
AOP55	ENDP
;
; fimath
; word or dword arg
; bit two gets set if word
;
AOP56	PROC
	call	noarg2
	call	intsize
	cmp	[arg1.asize],BYTESIZE
	je	aop56errx
	cmp	[arg1.mode],AM_FPREG
	je	aop56errx
	mov	ax,[si+OPCODE.COMPARE]
	cmp	[arg1.asize],WORDSIZE
	jne	aop56c
	or	al,4
aop56c:
	stosb
	xchg	al,ah
	mov	bx,offset arg1
	call	asmfrm
	ret
aop56errx:
	ret

AOP56	ENDP

;
; addrsize prefix on one-byte
;
AOP57	PROC
	call	asm32BitMode
        jnz     aop57off
	or	[PrefixBitmapWord],AS_ADDRSIZE
	jmp	aop0
aop57off:
        and     [PrefixBitmapWord],NOT AS_ADDRSIZE
        or      [PrefixBitmapWord],AS_ADDRSIZESET 
        jmp     aop0
AOP57	ENDP
;
; opsize prefix on one-byte
;
AOP58	PROC
	call	asm32BitMode
        jnz     aop58off
	or	[PrefixBitmapWord],AS_OPSIZE
aop58off:
	jmp	aop0
AOP58	ENDP
;
; MMX standard
;              
aop59   proc
	call	noarg3
	call	intsize
        mov     bx,offset arg1
        call    chkmmx
	mov	al,byte ptr [si+opcode.compare]
	stosb
        mov     al,[arg1.areg1]
        mov     bx,offset arg2
        call    asmrmmmx
	ret
aop59   endp
;
; MMX MOVD LD
;
aop60   proc
	call	noarg3
	call	intsize
        mov     bx,offset arg1
        call    chkmmx
	mov	al,byte ptr [si+opcode.compare]
        and     [PrefixBitmapWord],NOT AS_OPSIZE
	stosb
        mov     al,[arg1.areg1]
        mov     bx,offset arg2
	call	asmrm
	ret
aop60   endp
;
; MMX MOVD ST
;
aop61   proc
	call	noarg3
	call	intsize
        mov     bx,offset arg2
        call    chkmmx
        and     [PrefixBitmapWord],NOT AS_OPSIZE
	mov	al,byte ptr [si+opcode.compare]
	stosb
        mov     al,[arg2.areg1]
        mov     bx,offset arg1
	call	asmrm
	ret
aop61   endp
;
; MMX MOVQ LD
;
aop62   proc
	call	noarg3
	call	intsize
        mov     bx,offset arg1
        call    chkmmx
	mov	al,byte ptr [si+opcode.compare]
	stosb
        mov     al,[arg1.areg1]
        mov     bx,offset arg2
        call    asmrmmmx
	ret
aop62   endp
;
; MMX MOVQ ST
;
aop63   proc
	call	noarg3
	call	intsize
        mov     bx,offset arg2
        call    chkmmx
	mov	al,byte ptr [si+opcode.compare]
	stosb
        mov     al,[arg2.areg1]
        mov     bx,offset arg1
        call    asmrmmmx
	ret
aop63   endp
;         
; MMX SHIFT
;
aop64   proc
	call	noarg3
        mov     bx,offset arg2
        call    chkimm
        mov     bx,offset arg1
        call    chkmmx
        mov     ax,word ptr [si+opcode.compare]
        or      ah,0c0h
        or      ah,[bx+asmop.areg1]
        stosw
        mov     al,byte ptr [arg2.addrx]
        stosb
	ret
aop64   endp

;
; loop
;
aop65   proc
	call	noarg2
	call	intsize
	mov	bx,offset arg1
	call	chkimm
        sub     edx,edx
        mov     al,[lastbyte]
        cmp     al,'d'
        jz      aop65dw
        cmp     al,'w'
        jz      aop65w
        mov     ax,word ptr [EnteredMnemonic]
        cmp     ax,"je"
        jz      aop65dw
        jmp     aop65okc
aop65w:
        or      [PrefixBitmaPword],AS_ADDRSIZESET
        jmp     short aop65join
aop65dw:
        or      [PrefixBitmaPword],AS_ADDRSIZE
        inc     edx
aop65join:
	call	asm32BitMode
        jz      aop65okc
        neg     edx
        inc     edx
aop65okc:
	mov		eax,[lastofs]
	sub	eax,[bx+asmop.addrx]
	neg	eax
        sub     eax,2
        sub     eax,edx
aop65lrbnot32:
        cmp     eax,-128
        jl      aop65as32
        cmp     eax,128
        jle     aop65ok
aop65as32:
        stc
        ret
aop65ok:
	push	ax
	mov	al,byte ptr [si+OPCODE.COMPARE]
	stosb
	pop	ax
        test    [PrefixBitmapWord],AS_OPSIZETEST
        jnz     aop65lrbw
        stosb
        jmp     aop65lrbjoin
aop65lrbw:
        stosd
aop65lrbjoin:
	clc
	ret
aop65   endp
;
; CWD
;
aop66   PROC
        call    noarg1
	call	asm32BitMode
        jz      aop66off
        or      [PrefixBitmapWord],AS_OPSIZESET
aop66off:
        jmp     aop0
aop66   ENDP
;
; AAM
;
aop67   PROC
	cmp	[arg2.mode],AM_NONE
        stc
        jne     aop67err
        mov     bl,0ah
        cmp     [arg1.mode],AM_NONE
        je      aop67fin
        mov     bx,offset arg1
        call    chkimm
        mov     bl,byte ptr [arg1.addrx]
aop67fin:
        mov     al,byte ptr [si + OPCODE.COMPARE]
        stosb
        mov     al,bl
        stosb
        clc
aop67err:
        ret
aop67   ENDP
;
; xlat
;
aop68   PROC
        cmp     [arg1.mode],AM_NONE
        jz      aop68to0
        call    noarg2        
        cmp     [arg1.areg1],3
        jnz     aop68err
        cmp     [arg1.areg2],0FFh   ; else see if second reg defined
        jnz     aop68err
        cmp     [arg1.mode],AM_BASED
        jnz     aop68err
        or      [PrefixBitmapWord],AS_ADDRSIZESET
        mov     al,byte ptr [si + OPCODE.COMPARE]
        stosb
        ret
aop68err:
        stc
        ret
aop68to0:
        jmp     aop0
aop68   ENDP
;
; sets
;
aop69 PROC          
        call    noarg2
        cmp     [arg1.asize],BYTESIZE  ;maybe this means the first argument
        ja      aop69err   ;can't exceed dword size
        jmp     aop29
aop69err:
        stc
        ret
aop69 ENDP
aop70 PROC
	call	noarg2
        cmp     [arg1.asize],FWORDSIZE
        jz      aop70dw
        cmp     [arg1.asize],PBYTESIZE
        jnz     aop70join
aop70w:
        or      [PrefixBitmaPword],AS_OPSIZESET
        jmp     short aop70join
aop70dw:
        or      [PrefixBitmaPword],AS_OPSIZE
aop70join:
	mov	ax,[si+OPCODE.COMPARE]
	stosb
	xchg	al,ah
	mov	bx,offset arg1
	call	asmrm2
	ret
aop70 ENDP
        end