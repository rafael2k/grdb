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
; Operands.asm
;
; Function: Handle 386 operands as dictated by the opcode table
;   Handle formatting output
;
; Sorry, I didn't have time to document this one yet
;
; years later:
;
; sorry, I STILL didn't have time to document this one yet :)
;
	;MASM MODE
	.MODEL SMALL
	.386

include iwindow.inc
include	edispatc.inc 
include	iopcodes.inc
include	ioperand.inc
include	eoptions.inc
include	eopcom.inc
include esymbol.inc
include emtrap.inc
include iasm.inc
include easm.inc

	PUBLIC TabTo, ReadOverrides, DispatchOperands
	PUBLIC	FormatDisassembly, FormatValue, Code_Address
        PUBLIC  PutDword, PutWord,PutByte, source,dest, segs
        PUBLIC  put2,put3,put4, strlen, GetSeg, putwordox,putbyte

	extrn x86pfx : byte
SZ_QWORD	=	2
SZ_TBYTE	=	4

	.DATA
code_address	dd	0		;disassembly address within segment
dest2		dw	0		;temps to aid decoding
source2		dw	0
segs		dw	0		
extraoperand	OPERAND <>		;third operand
source		OPERAND	<>		;second operand
dest		OPERAND	<>		;first operand
nmmnemonic      db      20 DUP (?)      ;mnemonic (may be modified here)
reqsPtrSizeOvride	db	0	;flag set if xxx ptr required
realopsize      db      0               ;flag set if 0x66 byte detected
unksse          db      "???SSE???",0
hasputoverride  db      0               ; flag set if an override has been displayed
	.CODE

;Find the length of a string in a buffer pointed to by SI, and return that
;length in AX.  This is a strange way to do this. I think I'll change it
;just a little.
;  If SI comes in pointing to a 0, we return a string length of 0

strlen	PROC	
	push	di
	push	si
	push	cx
	mov	di,si
	mov	cx,-1
	sub	al,al
	repnz	scasb
	mov	ax,cx
	not	ax
	dec	ax
	pop	cx
	pop	si
	pop	di
	ret
strlen	ENDP	




strcpy	PROC	
strcpylp:
	lodsb
	stosb
	or	al,al
	jnz	strcpylp
	ret
strcpy	ENDP	


strcat	PROC	
	mov	al,[di]
	inc	di
	or	al,al
	jnz	strcat
	dec	di
	jmp	strcpy
strcat	ENDP	


CopyExtra	PROC	
	push	si
	push	di
	mov	si,offset extraoperand
	xchg	si,di
	mov	cx,OPERANDSIZE
	rep	movsb
	pop	di
	pop	si
	ret
CopyExtra	ENDP	



put2	PROC	
	mov	[si],ah
	inc	si
	mov	[si],al
	inc	si
	mov	BYTE PTR [si],0
	ret
put2	ENDP	


put3	PROC	
	push	eax
	shr	eax,8
	mov	[si],ah
	inc	si
	pop	eax
	call	put2
	ret
put3	ENDP	


put4	PROC	
	push	eax
	shr	eax,16
	call	put2
	pop	eax
	call	put2
	ret
put4	ENDP	


SetSeg	PROC	
        mov     [reqsPtrSizeOvride],FALSE
	mov	[di+OPERAND.code],OM_SEGMENT
	mov	[di+OPERAND.THEREG],al
	ret
SetSeg	ENDP	


SetReg	PROC	
	mov	[reqsPtrSizeOvride],FALSE
	mov	[di+OPERAND.code],OM_REG
	mov	[di+OPERAND.THEREG],al
	ret
SetReg	ENDP	


ReadRM	PROC	
	push	cx
	sub	cx,cx
	mov	cl,2
	RM	esi
	mov	[di+OPERAND.THEREG],al
	MODX	esi
	mov	ch,al
	cmp	ch,MOD_REG
	jnz	short notregreg
	mov	[di+OPERAND.CODE],OM_REG
	mov	[reqsPtrSizeOvride],FALSE
	sub	ax,ax
	pop	cx
	ret
notregreg:
	bt	[di+OPERAND.OEFLAGS],OMF_ADR32
	jnc	adr16
	cmp	[di+OPERAND.THEREG],RM_32_SCALED
	jnz	notscaled
	inc	cl
	RM	esi+1
	mov	[di+OPERAND.THEREG],al
	REG	esi+1
	mov	[di+OPERAND.SCALEREG],al
	MODX	esi+1
	mov	[di+OPERAND.SCALE],al
	cmp	[di+OPERAND.SCALEREG],RM_32_STACKINDEX
	jz	hassp
	bts	[di+OPERAND.OEFLAGS],OMF_SCALED
hassp:
	cmp	[di+OPERAND.THEREG],RM_32_ABSOLUTE
	jnz	basedAndScaled
	cmp	ch,MOD_NOOFS
	jnz	short basedAndScaled
	mov	[di+OPERAND.CODE],OM_ABSOLUTE
	LONG	esi+3
	mov	[di+OPERAND.ADDRESS],eax
	sub	ax,ax
	mov	al,5
	pop	cx
	ret
notscaled:
	
	cmp	ch,MOD_NOOFS
	jnz	basedAndScaled
	cmp	[di+OPERAND.THEREG], RM_32_ABSOLUTE
	jnz	basedAndScaled
	mov	[di+OPERAND.CODE], OM_ABSOLUTE
	LONG	esi+2
	mov	[di+OPERAND.ADDRESS],eax
	sub	ax,ax
	sub	ax,ax
	mov	al,4
	pop	cx
	ret
adr16:
	cmp	ch,MOD_NOOFS
	jnz	basedAndScaled
	cmp	[di+OPERAND.THEREG], RM_16_ABSOLUTE
	jnz	basedAndScaled
	mov	[di+OPERAND.CODE], OM_ABSOLUTE
	UINT	esi+2
	mov	[di+OPERAND.ADDRESS],eax
	sub	ax,ax
	mov	al,2
	pop	cx
	ret
basedAndScaled:
	mov	[di+OPERAND.CODE], OM_BASED
	cmp	ch,MOD_ADDR
	jnz	short checksigned
	bts	[di+OPERAND.OEFLAGS], OMF_WORD_OFFSET
	push	cx
	sub	ch,ch
	movzx	ecx,cl
	mov	eax,fs:[esi+ecx]
	pop	cx
	bt	[di+OPERAND.OEFLAGS], OMF_ADR32
	jc	dwordx
	and	eax,0ffffh
	sub	cl,2
dwordx:
	mov	[di+OPERAND.ADDRESS],eax
	add	cl,4
	jmp	short readrmdone
checksigned:
	cmp	ch, MOD_SIGNED
	jnz	short readrmdone
	bts	[di+OPERAND.OEFLAGS],OMF_SIGNED_OFFSET
	movzx	ecx,cl
        movsx   eax,byte ptr fs:[esi+ecx]
	mov	[di+OPERAND.ADDRESS],eax
	inc	cl
readrmdone:
	movzx	ax,cl
	sub	al,2
	pop	cx
	ret
ReadRM	ENDP	


RegRM	PROC	
	mov	di,[dest2]
	REG	esi
	call	SetReg
	mov	di,[source2]
	call	ReadRM
	ret
RegRM	ENDP	


Immediate	PROC	
	push	cx
	sub	cx,cx
	mov	[di+OPERAND.CODE],OM_IMMEDIATE
	bt	[di+OPERAND.OEFLAGS],OMF_BYTE
	jnc	short inotbyte
	inc	cl
	sub	ax,ax
	mov	al,fs:[esi]
	jmp	short i_ret
inotbyte:
	bt	[di+OPERAND.OEFLAGS], OMF_OP32
	jnc	iword
	add	cl,4
	LONG	esi
	jmp	short i_ret
iword:
	add	cl,2
	UINT	esi
i_ret:
	mov	[di+OPERAND.ADDRESS],eax
	mov	ax,cx
	pop	cx
	ret
Immediate	ENDP	

;Find a binary 0, stick whatever is in AL there, and put a 0 after that.

MnemonicChar	PROC	
	push	di
	mov	di,offset nmmnemonic
mc2:
	inc	di
	cmp	BYTE PTR [di-1],0
	jnz	mc2
	mov	[di-1],al
	mov	BYTE PTR [di],0
	pop	di
	ret
MnemonicChar	ENDP	

issse PROC
        test    [realopsize],1
        jz      notsse
        push    si
        push    di
        mov     si,offset unksse
        mov     di,offset nmmnemonic
        call    strcpy
        pop     di
        pop     si
notsse:
        ret
issse ENDP

;/* op 1- word reg from bits 0 - 2 of opcode */

op1	PROC	
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	mov	al,fs:[esi]
	B02
	call	SetReg
	sub	ax,ax
	ret
op1	ENDP	


;/* Op2 acc, reg bits 0-2 of opcode */
op2	PROC	
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
	mov	al,REG_EAX
	call	SetReg
	mov	di,bx
	mov	al,fs:[esi]
	and	al,7
	call	SetReg
	sub	ax,ax
	ret
op2	ENDP	


;/* op3 - seg from b3-5 of opcode */
Op3	PROC	
	mov	al,fs:[esi]
	B35
	call	SetSeg
	sub	ax,ax
	ret
op3	ENDP	


;/* op4 - REGRM with b1 of opcode set reg is dest else source */
op4	PROC	
	bt	DWORD PTR fs:[esi],1
	jc	short op4nox
	xchg	bx,di
op4nox:
	mov	[dest2],di
	mov	[source2],bx
	call	RegRM
	ret
op4	ENDP	


;/* op5 - use RM only */
op5	PROC	
	call	ReadRM
	ret
op5	ENDP	


;/* op6 READRM for shift */
op6	PROC	
	call	ReadRM
	sub	cx,cx
	mov	cl,al
	mov	di,bx
	mov	[di+OPERAND.CODE],OM_SHIFT
	bt	DWORD PTR fs:[esi],4
	jnc	short op6cnt
	bt	DWORD PTR fs:[esi],1
        jnc     short op61a
	bts	[di+OPERAND.OEFLAGS],OMF_CL
	jmp	short op6done
op61a:
	mov	[di+OPERAND.ADDRESS],1
	jmp	short op6done
op6cnt:
	movzx	ecx,cx
	movzx	eax,BYTE PTR fs:[esi+ecx+2]
	inc	cl
	mov	[di+OPERAND.ADDRESS],eax
op6done:
	mov	ax,cx
	ret
op6	ENDP	


;/* op 7 regrm with reg dest */
op7	PROC	
	mov	[dest2],di
	mov	[source2],bx
	call	RegRM
	ret
op7	ENDP	


;/* OP8 - word regrm with reg dest */
op8	PROC	
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
	jmp	op7
op8	ENDP	


;/* op 9 - interrupts */
op9	PROC	
        btr     [di+OPERAND.OEFLAGS],OMF_ADR32
        btr     [di+OPERAND.OEFLAGS],OMF_OP32
	mov	[reqsPtrSizeOvride],FALSE
	sub	eax,eax
	mov	al,3
	bt	DWORD PTR fs:[esi],0
	jnc	short op9int3
	mov	al,fs:[esi+1]
op9int3:
	mov	[di+OPERAND.ADDRESS],eax
	mov	BYTE PTR [di+OPERAND.CODE],OM_INT
	sub	al,al
	ret
op9	ENDP	


;/* op 10, short relative branch */
op10	PROC	
	mov	[reqsPtrSizeOvride],FALSE
	mov	[di+OPERAND.CODE],OM_SHORTBRANCH
	movsx	eax,BYTE PTR fs:[esi+1]
        inc     eax
        inc     eax
        mov     edx,[code_address]
        add     eax,edx
	mov	[di+OPERAND.ADDRESS],eax
	bt	[di+OPERAND.OEFLAGS],OMF_OP32
	jc	short op10notword
	and	[di+OPERAND.ADDRESS],0ffffh
op10notword:
	sub	ax,ax
	ret
op10	ENDP	


;/* op 11 RM, immediate */
op11	PROC	
	call	ReadRM
	movzx	ecx,al
	mov	di,bx
	push	esi
	add	esi,ecx
	add	esi,2
	call	Immediate
	add	cl,al
	pop	esi
	mov	ax,cx
	ret
op11	ENDP	


;/* op 12 - acc, immediate */
op12	PROC	
	mov	al,REG_EAX
	call	SetReg
	mov	di,bx
	inc	esi
	call	Immediate
	dec	esi
	ret
op12	ENDP	


;/* op 13 absolute, acc*/
op13	PROC	
	sub	cx,cx
	mov	[di+OPERAND.CODE],OM_ABSOLUTE
	bt	[di+OPERAND.OEFLAGS],OMF_ADR32
	jnc	short op13word
	LONG	esi+1
	inc	cl
	inc	cl
	jmp	short op13fin
op13word:
	UINT	esi+1
op13fin:
	mov	[di+OPERAND.ADDRESS],eax
	mov	di,bx
	mov	al,REG_EAX
	call	SetReg
	mov	ax,cx
	ret
op13	ENDP	


;/* op 14 - RM, immediate, b01 of opcode != 1 for byte */
op14	PROC	
	call	ReadRM
	movzx	ecx,al
	mov	al,fs:[esi]
	B01
        test    al,1
	jnz	short op14checkbyte
	bts	[bx+OPERAND.OEFLAGS],OMF_BYTE
	bts	[di+OPERAND.OEFLAGS],OMF_BYTE
	jmp	short op14source
op14checkbyte:
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
	cmp	al,1
	jz	short op14check2
	bts	[bx+OPERAND.OEFLAGS],OMF_BYTE
op14check2:
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
op14source:
	mov	di,bx
	push	esi
	add	esi,ecx
	add	esi,2
	call	Immediate
	pop	esi
	add	cl,al
	mov	al,fs:[esi]
	B01
	cmp	al,3
	jnz	op14done
	bt	[di+OPERAND.OEFLAGS],OMF_BYTE
	jnc	op14done
	bts	[di+OPERAND.OEFLAGS],OMF_SIGNED
	movzx	eax,byte ptr [di+OPERAND.ADDRESS]
	mov	[di+OPERAND.ADDRESS],eax
op14done:
	mov	ax,cx
	ret
op14	ENDP	


;/* op 15 - acc, immediate, B3 of opcode clear for byte */
op15	PROC	
	mov	al,fs:[esi]
	B02
	call	SetReg
	bt	DWORD PTR fs:[esi],3
	jnc	op15byte
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
	jmp	short op15source
op15byte:
	bts	[di+OPERAND.OEFLAGS],OMF_BYTE
	bts	[bx+OPERAND.OEFLAGS],OMF_BYTE
op15source:
	mov	di,bx
	inc	esi
	call	Immediate
	dec	esi
	ret
op15	ENDP	


;/* op 16 - seg,readrm, if B1 of opcode seg is dest else source */
op16	PROC	
	bt	DWORD PTR fs:[esi],1
	jc	noswap
	xchg	bx,di
noswap:
	REG	esi
	call	SetSeg
	mov	di,bx
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	call	ReadRM
	ret
op16	ENDP	


;/* op 17, far return */
op17	PROC	
	mov	[reqsPtrSizeOvride],false
	mov	[di+OPERAND.CODE],OM_RETURN
	btr	[di+OPERAND.OEFLAGS],OMF_ADR32
	btr	[di+OPERAND.OEFLAGS],OMF_OP32
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	UINT	esi+1
	mov	[di+OPERAND.ADDRESS],eax
	sub	ax,ax
	ret
op17	ENDP	


;/* op 18, far branch/call */
op18	PROC	
	sub	cx,cx
	mov	[reqsPtrSizeOvride],FALSE
	mov	[di+OPERAND.CODE],OM_FARBRANCH
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	bt	[di+OPERAND.OEFLAGS],OMF_OP32
	jnc	short op18word
	inc	cl
	inc	cl
	LONG	esi+1
	jmp	short	op18fin
op18word:
	UINT	esi+1
op18fin:
	mov	[di+OPERAND.ADDRESS],eax
	movzx	ecx,cx
	UINT	esi+ecx+3
	mov	[di+OPERAND.OESEG],ax
	mov	ax,cx
	ret
op18	ENDP	


;/* op 19 - ESC, mnem of bits 0-2 of opcode, imm,readrm */
op19	PROC	
	mov	[di+OPERAND.CODE],OM_IMMEDIATE
	bts	[di+OPERAND.OEFLAGS],OMF_BYTE
	mov	al,fs:[esi]
	and	al,7
	shl	al,3
	mov	ah,fs:[esi+1]
	shr	ah,3
	and	ah,7
	or	al,ah
	sub	ah,ah
	cwde
	mov	[di+ OPERAND.ADDRESS],eax
	mov	di,bx
	call	ReadRM
	ret
op19	ENDP	


;/* op 20 - long branch */
op20	PROC	
	sub	eax,eax
	mov	[reqsPtrSizeOvride],FALSE
	sub	cx,cx
	mov	[di+OPERAND.CODE],OM_LONGBRANCH
	bt	[di+OPERAND.OEFLAGS],OMF_OP32
	jnc	short op20word
	LONG	esi+1
	inc	cl
	inc	cl
	jmp	short op20fin
op20word:
	UINT	esi+1
op20fin:

        mov     edx,[code_address]
        add     eax,edx
	test	[segs],SG_TWOBYTEOP
	jz	op20xx
	inc	ax
op20xx:
        test    [segs],SG_OPSIZ
        jz      op20xy
        inc     ax
op20xy:
	add	ax,cx
	add	ax,3
	bt	[di+OPERAND.OEFLAGS],OMF_OP32
	jc	op20done
	and	eax,0ffffh
op20done:
	mov	[di+OPERAND.ADDRESS],eax
	mov	ax,cx
	ret
op20	ENDP	


;/* op21 acc,dx */
op21	PROC	
	mov	al,REG_EAX
	call	SetReg
	mov	di,bx
	btr	[di+OPERAND.OEFLAGS],OMF_OP32
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	mov	al,REG_DX
	call	SetReg
	sub	ax,ax
	ret
op21	ENDP	


;/* op22 - dx,acc */
op22	PROC	
	btr	[di+OPERAND.OEFLAGS],OMF_OP32
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	mov	al,REG_DX
	call	SetReg
	mov	di,bx
	mov	al,REG_EAX
	call	SetReg
	sub	ax,ax
	ret
op22	ENDP	


;/* op23 - port,acc where B1 of opcode set is port dest */
op23	PROC	
	bt	DWORD PTR fs:[esi],1
	jc	short op20NoSwap
	xchg	bx,di
op20noswap:
	bts	[di+OPERAND.OEFLAGS],OMF_BYTE
	mov	[di+OPERAND.CODE],OM_PORT
	movzx	eax,BYTE PTR fs:[esi+1]
	mov	[di+OPERAND.ADDRESS],eax
	mov	di,bx
	mov	al,REG_EAX
	call	SetReg
	sub	ax,ax
	ret
op23	ENDP	


;/* op 24 acc, absolute */
op24	PROC	
	sub	cx,cx
	mov	al,REG_EAX
	call	SetReg
	mov	di,bx
	mov	[di+OPERAND.CODE],OM_ABSOLUTE
	bt	[di+OPERAND.OEFLAGS],OMF_ADR32
	jnc	short op24word
	inc	cl
	inc	cl
	LONG	esi+1
	jmp	short op24done
op24word:
	UINT	esi+1
op24done:
	mov	[di+OPERAND.ADDRESS],eax
	mov	ax,cx
	ret
op24	ENDP	


;/* op 25 - immediate byte or word */
op25	PROC	
	mov	[reqsPtrSizeOvride],false
	bts	[di+OPERAND.OEFLAGS],OMF_BYTE
	bt	DWORD PTR fs:[esi],1
	jc	short op25fin
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
op25fin:
	inc	esi
        call    Immediate
	dec esi
        bts     [di+OPERAND.OEFLAGS],OMF_SIGNED
	ret
op25	ENDP	


;/* op 26, immediate 2byte,byte */
op26	PROC	
	mov	[reqsPtrSizeOvride],false
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[di+OPERAND.OEFLAGS],OMF_OP32
	push	esi
	inc	esi
	call	Immediate
	mov	di,bx
	bts	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[di+OPERAND.OEFLAGS],OMF_OP32
	inc	esi
	inc	esi
	call	Immediate
	pop	esi
	sub	ax,ax
	ret
op26	ENDP	


;/* op 27 - string */
op27	PROC	
	mov	al,'d'
	bt	[di+OPERAND.OEFLAGS],OMF_OP32
	jc	short op27pc
	mov	al,'w'
op27pc:
	call	MnemonicChar
	sub	ax,ax
	ret
op27	ENDP	


;/* op 28 - source = REG, dest = RM */
op28	PROC	
	xchg	di,bx
	jmp	op7
op28	ENDP	


;/* op 29 - rm, size don't care */
op29	PROC	
	btr	[di+OPERAND.OEFLAGS],OMF_OP32
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
        mov     [reqsPtrSizeOvride],FALSE
	call	ReadRM
	ret
op29	ENDP	


;/* op30 - RM, shift with B3 of stream selecting COUNT or CL*/
op30	PROC	
	call	ReadRM
        movzx   cx,al
	mov	di,bx
	mov	[di+OPERAND.CODE],OM_SHIFT
	bt	DWORD PTR fs:[esi],3
	jnc	op30cl
	movzx	ecx,cx
	movzx	eax,byte ptr [esi+ecx+2]
	mov	[di+OPERAND.ADDRESS],eax
	inc	cx
	jmp	short op30done
op30cl:
	bts	[di+OPERAND.OEFLAGS],OMF_CL
op30done:
	mov	ax,cx
	ret
op30	ENDP	


;/* op 31- reg, rm, count where B1 of opcode = byte/word */
op31	PROC	
	call	copyextra
	REG	esi
	call	SetReg
	mov	di,bx
	call	ReadRM
        movzx   cx,al
	mov	di,offset extraoperand
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	bt	DWORD PTR fs:[esi],1
        jnc     short op31byte
	bts	[di+OPERAND.OEFLAGS],OMF_BYTE
        bts     [di+OPERAND.OEFLAGS],OMF_SIGNED
op31byte:
	movzx	ecx, cx
	push	esi
	inc	esi
        inc     esi
        add     esi,ecx
	call	Immediate
	pop	esi
	add	ax,cx
	ret
op31	ENDP	


;/* op32 - 386 special regs */
op32	PROC	
	mov	cx,WORD PTR fs:[esi]
	and	cx,0c005h
	cmp	cx,0c000h
	mov	al,OM_CRX
	jz	short op32gotype
	cmp	cx,0c001h
	mov	al,OM_DRX
	jz	short op32gotype
	cmp	cx,0c004h
	mov	al,OM_TRX
	jz	short op32gotype
	mov	al,OM_SUD
op32gotype:
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
        btr     [di+OPERAND.OEFLAGS],OMF_ADR32
        btr     [bx+OPERAND.OEFLAGS],OMF_ADR32
	bts	[di+OPERAND.OEFLAGS],OMF_OP32
	bts	[bx+OPERAND.OEFLAGS],OMF_OP32
	bt	DWORD PTR fs:[esi],1
	jc	op32noswap
	xchg	bx,di
op32noswap:
	mov	[di+OPERAND.CODE],al
	REG	esi
	mov	[di+OPERAND.THEREG],al
	mov	di,bx
	RM	esi
	call	SetReg
	sub	ax,ax
	ret
op32	ENDP	


;/* op33 - reg,rm,shiftcnt where B3 = reg source, b0 = shift cl */
op33	PROC	
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
	call	CopyExtra
	call	ReadRM
        movzx   cx,al
	REG	esi
	mov	di,bx
	call	SetReg
	mov	di,offset extraoperand
	mov	[di+OPERAND.CODE],OM_SHIFT
	bt	DWORD PTR fs:[esi],0
	jnc	short getofs
	bts	[di+OPERAND.OEFLAGS],OMF_CL
	jmp	short op33done
getofs:
	movzx	ecx,cx
	movzx	eax,BYTE PTR fs:[esi+ecx+2]
	mov	[di+OPERAND.ADDRESS],eax
op33done:
	mov	ax,cx
	ret
op33	ENDP	


;/* op 34 - push & pop word, also no reqsPtrSizeOvride single args */
op34	PROC	
	call	ReadRM
	ret
op34	ENDP	


;/* op 35 -floating RM */
op35	PROC	
	mov	[reqsPtrSizeOvride],FALSE
	MODX	esi
	cmp	al,3
	jnz	short op35fsttab
	bts	[di+OPERAND.OEFLAGS],OMF_FST
	call	ReadRM
	ret
op35	endp



op35fsttab	proc
	bts	[di+OPERAND.OEFLAGS],OMF_FSTTAB
	movzx	eax,BYTE PTR fs:[esi]
	B12
	shl	eax, OM_FTAB
        or      [di+OPERAND.OEFLAGS],eax
	call	ReadRM
	ret
op35fsttab	endp


;/* op 36 - floating math & pop */

op36	PROC	
	mov	[reqsPtrSizeOvride],FALSE
	mov	al,fs:[esi+1]
	and	al,0c7h
	cmp	al,0c1h
	jz	op36noarg
	bts	[di+OPERAND.OEFLAGS],OMF_FST
	and	al,7
	call	setreg
	sub	al,al
	xchg	bx,di
	bts	[di+OPERAND.OEFLAGS],OMF_FST
	call	setreg
op36noarg:
	sub	ax,ax
	ret
op36	ENDP	


;/* OP 37 - floating MATH */
op37	PROC	
	mov	[reqsPtrSizeOvride],FALSE
	MODX	esi
	cmp	al,3
	jc	op35fsttab
	test	byte ptr fs:[esi],4
	jnz	op37noflop
	xchg	di,bx
op37noflop:
	bts	[di+OPERAND.OEFLAGS],OMF_FST
	RM	esi
	call	setreg
	sub	al,al
	xchg	bx,di
	bts	[di+OPERAND.OEFLAGS],OMF_FST
	call	setreg
	sub	ax,ax
	ret
op37	ENDP	


;/* op38 - FAR RM */
op38	PROC	
;        mov     [reqsPtrSizeOvride],FALSE
;        bts     [di+OPERAND.OEFLAGS],OMF_FSTTAB
        bts     [di+OPERAND.OEFLAGS],OMF_FARPTR
	call	ReadRM
	ret
op38	ENDP	


;/* OP39 - word regrm with reg source */
op39	PROC	
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
	call	op40
	ret
op39	ENDP	


;/* op 40 regrm with reg source */
op40	PROC	
	mov	[dest2],bx
	mov	[source2],di
	call	RegRM
	ret
op40	ENDP	


;/* op 41 reg, bitnum */
op41	PROC	
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	call	ReadRM
        movzx   cx,al
	mov	di,bx
	bts	[di+OPERAND.OEFLAGS],OMF_BYTE
	push	esi
	movzx	ecx,cx
	add	esi,ecx
	add	esi,2
	call	Immediate
	pop	esi
	mov	ax,cx
	ret
op41	ENDP	


;/* op 42 mixed regrm with reg dest & reqsPtrSizeOvrideness enforced */

op42	PROC	
	mov	[dest2],di
	mov	[source2],bx
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_OP32
	call	RegRM
	mov	[reqsPtrSizeOvride],TRUE
	ret
op42	ENDP	



;/* op 43 CWDE

op43	PROC	
	bt	[di+OPERAND.OEFLAGS],OMF_OP32	
	jnc	short op43nochng		
	push	si				
	mov	si,offset nmmnemonic+1		
	mov	eax,"wde"			
	call	put3				
	mov	BYTE PTR [si],0			
	pop	si				
	sub	ax,ax				
op43nochng:
	ret
op43	ENDP	


;/* op 44 BSWAP

op44	PROC
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	mov	al,fs:[esi]
	and	al,7
	call	SetReg
	sub	ax,ax
	ret
op44	ENDP


;/* OP45 - any regrm with reg source */

op45	PROC	
	bt	word ptr fs:[esi-1],0
	jc	op45nb
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
op45nb:
        mov     [dest2],bx
        mov     [source2],di
        call    RegRM
;        XCHG    BX,DI
;        REG     esi
;        call    SetReg
;        XCHG    bx,di
;        call    ReadRM
        ret
op45	ENDP	


;/* op 46 - floating R/M, pointers to mem */
op46	PROC	
	jmp	op29
op46	ENDP	


;/* op47 - AX */
op47	PROC
	btr	[di+OPERAND.OEFLAGS],OMF_OP32
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	sub	al,al
	call	SetReg
	sub	ax,ax
	ret
op47	ENDP


;/* op48 - 32-bit reg to r02, no prefix (bswap) */
op48	PROC
	bts	[di+OPERAND.OEFLAGS],OMF_OP32
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	mov	al,fs:[esi]
	B02
	call	SetReg
	sub	ax,ax
	ret
op48	ENDP


;/* op 49, FST */
op49	PROC
	mov	[reqsPtrSizeOvride],FALSE
	MODX	esi
	cmp	al,3
	jnz	op49noreg
	bts	[di+OPERAND.OEFLAGS],OMF_FST
	jmp	short op49fin
op49noreg:
	bts	[di+OPERAND.OEFLAGS],OMF_FSTTAB
	movzx	eax,BYTE PTR fs:[esi]
	and	al,6
	jz	op49nxor
	xor	al,6
op49nxor:
	shl	eax, OM_FTAB
        or      [di+OPERAND.OEFLAGS],eax
op49fin:
	call	ReadRM
	ret
op49	ENDP


;/* op 50, FLD & FSTP */
op50	PROC
	jmp	op49
op50	ENDP


;/* op 51, FBLD/FBSTP */
op51	PROC
	mov	[reqsPtrSizeOvride],FALSE
	bts	[di+OPERAND.OEFLAGS],OMF_FSTTAB
	or	[di+OPERAND.OEFLAGS],4 SHL OM_FTAB
	call	readrm
	ret
op51	ENDP


;/* op 52, FILD & FISTP */
op52	PROC
	mov	[reqsPtrSizeOvride],FALSE
	mov	ah,1		; assume dword
	mov	al,fs:[esi]
	cmp	al,0dfh
	jnz	op52dw
	mov	ah,2		; assume qword
	test	byte ptr fs:[esi+1],20h
	jnz	op52dw
	mov	ah,3
op52dw:
	mov	al,ah
	sub	ah,ah
	bts	[di+OPERAND.OEFLAGS],OMF_FSTTAB
	shl	ax,OM_FTAB
        or      [di+OPERAND.OEFLAGS],eax
	call	readrm
	ret
op52	ENDP


;/* op 53, FIST & FISTP */
op53	PROC
	jmp	op52
op53	ENDP


;/* op 54, FREG */
op54	PROC
	mov	[reqsPtrSizeOvride],0
	bts	[di+OPERAND.OEFLAGS],OMF_FST
	call	ReadRM
	ret
op54	ENDP


;/* op 55, FREG if not one */
op55	PROC
	mov	al,fs:[esi+1]
	and	al,7
	cmp	al,1
	jnz	op54
	sub	ax,ax
	ret
op55	ENDP


;/* op 56, FIMATH */
op56	PROC
	mov	[reqsPtrSizeOvride],false
	mov	ax,1
	test	byte ptr fs:[esi],4
	jz	op56go
	mov	al,3
op56go:
	bts	[di+OPERAND.OEFLAGS],OMF_FSTTAB
	shl	ax,OM_FTAB
        or      [di+OPERAND.OEFLAGS],eax
	call	readrm
	ret
op56	ENDP

;/* op 59 MMXREG,RM */
op59    PROC
        call    issse
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
        bts     [di+OPERAND.OEFLAGS],OMF_MMXTAB
        bts     [bx+OPERAND.OEFLAGS],OMF_MMXTAB
        mov     [dest2],di
        mov     [source2],bx
        call    RegRM
	ret
op59    ENDP

;/* op60 MMXMOVDLD */
op60    PROC
        call    issse
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
        bts     [di+OPERAND.OEFLAGS],OMF_MMXTAB
        bts     [bx+OPERAND.OEFLAGS],OMF_OP32
        mov     [dest2],di
        mov     [source2],bx
        call    RegRM
	ret
op60    ENDP

;/* op61 MMXMOVDST */
op61    PROC
        call    issse
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
        bts     [bx+OPERAND.OEFLAGS],OMF_MMXTAB
        bts     [di+OPERAND.OEFLAGS],OMF_OP32
        mov     [dest2],bx
        mov     [source2],di
        call    RegRM
	ret
op61    ENDP

;/* op62 MMXMOVQLD */
op62    PROC
        call    issse
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
        bts     [di+OPERAND.OEFLAGS],OMF_MMXTAB
        bts     [bx+OPERAND.OEFLAGS],OMF_MMXTAB
        mov     [dest2],di
        mov     [source2],bx
        call    RegRM
	ret
op62    ENDP

;/* op63 MMXMOVQST */
op63    PROC
        call    issse
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	btr	[bx+OPERAND.OEFLAGS],OMF_BYTE
        bts     [bx+OPERAND.OEFLAGS],OMF_MMXTAB
        bts     [di+OPERAND.OEFLAGS],OMF_MMXTAB
        mov     [dest2],bx
        mov     [source2],di
        call    RegRM
	ret
op63    ENDP

;/* op64 MMXSHIFT */
op64    PROC
        call    issse
        bts     [di+OPERAND.OEFLAGS],OMF_MMXTAB
        bts     [bx+OPERAND.OEFLAGS],OMF_MMXTAB
        call    ReadRM
	sub	cx,cx
	mov	cl,al
	mov	di,bx
	mov	[di+OPERAND.CODE],OM_SHIFT
	movzx	ecx,cx
	movzx	eax,BYTE PTR fs:[esi+ecx+2]
	inc	cl
	mov	[di+OPERAND.ADDRESS],eax
	mov	ax,cx
	ret
op64    ENDP

;/* loop */
op65    proc
	mov	al,'d'
        bt      [di+OPERAND.OEFLAGS],OMF_ADR32
        jc      short op65pc
	mov	al,'w'
op65pc:
	call	MnemonicChar
	sub	eax,eax
	mov	[reqsPtrSizeOvride],FALSE
        mov     [di+OPERAND.CODE],OM_SHORTBRANCH
        movsx   eax,byte ptr fs:[esi+1]

        mov     edx,[code_address]
        add     eax,edx
        add     eax,2
        sub     edx,edx
        bt      [di+OPERAND.OEFLAGS],OMF_ADR32
        jnc     op65notas
        inc     edx
op65notas:
	call	asm32BitMode
        jz      op65t2
        neg     edx
        inc     edx
op65t2:
        add     eax,edx
	bt	[di+OPERAND.OEFLAGS],OMF_OP32
        jc      op65done
	and	eax,0ffffh
op65done:
	mov	[di+OPERAND.ADDRESS],eax
        sub     ax,ax
        clc
	ret
op65    endp

; CDW/CDQ

op66    PROC    
	bt	[di+OPERAND.OEFLAGS],OMF_OP32	
        jnc     short op66nochng                
	push	si				
	mov	si,offset nmmnemonic+1		
        mov     eax,"dq"                       
        call    put2                            
	mov	BYTE PTR [si],0			
	pop	si				
	sub	ax,ax				
op66nochng:
	ret
op66    ENDP    

;
; AAM
;
op67    PROC
        inc     esi
        mov     al,fs:[esi]
        bts     [di+OPERAND.OEFLAGS],OMF_BYTE
        call    Immediate
        sub     ax,ax
        ret
op67    ENDP

;
; XLAT
;
op68    PROC
        mov     [reqsPtrSizeOvride],FALSE
        mov     [di.OPERAND.CODE],OM_BASED
        mov     [di.OPERAND.THEREG],3 ; [ebx]
        bt      [di.OPERAND.OEFLAGS],OMF_ADR32
        jc      op68n32
        mov     [di.OPERAND.THEREG],7 ; [BX]
op68n32:
        sub     ax,ax  
        ret
op68    ENDP

;
; set xx
;
op69    PROC
	bts	[di+OPERAND.OEFLAGS],OMF_BYTE
	bts	[bx+OPERAND.OEFLAGS],OMF_BYTE
        jmp     op29
op69    endp
;
; lgdt/sgdt
;
op70    PROC
        btr     [di+OPERAND.OEFLAGS],OMF_BYTE
        bt      [di+OPERAND.OEFLAGS],OMF_OP32
        jc      op70_fword
        bts     [di+OPERAND.OEFLAGS],OMF_PBYTE
        jmp     op70_cont
op70_fword:
        bts     [di+OPERAND.OEFLAGS],OMF_FWORD
op70_cont:
	call	ReadRM
	ret
op70    ENDP

ReadOverrides   PROC    
        mov     [segs],0
      	
ro_lp:
	sub	ax,ax
	lods	BYTE PTR fs:[esi]
	test	[Disassemble32Bit],1
	jz	testseg
	cmp	al,64h
	jc	short testseg
	cmp	al,68h
	jnc	short testseg
	sub	al,64h
	mov	bx,SG_FS
ro_found:
	mov	cl,al
	shl	bx,cl
	or	[segs],bx
	jmp	short ro_lp
testseg:
	push	ax
	and	al,0e7h
	cmp	al,026h
	pop	ax
	jnz	testrep
	mov	bx,1
	shr	ax,3
	and	al,3
	jmp	ro_found
testrep:
        sub     al,0f0h         ; lock
        mov     bx,SG_LOCK
        jz      short ro_found
        sub     al,02h
	cmp	al,2
	jnc	ro_done
	mov	bx,SG_REPNZ
	jmp	short ro_found
ro_done:
	dec	esi
	ret
ReadOverrides	ENDP	


DispatchOperands	PROC	
	mov	dx,ax
	push	bx
	mov	di,offset nmmnemonic
	push	si
	mov	si,[bx+OPCODE.MNEMONIC]
	call	strcpy
	pop	si
	mov	[reqsPtrSizeOvride],TRUE
	movzx	ax,[bx+OPCODE.OPERANDS]
	push	ax
	mov	di,offset dest
	mov	bx,offset source
	test	[x86pfx],1
	jz	short notwobyte
	or	[segs],SG_TWOBYTEOP
notwobyte:
	mov	ax,offset extraoperand
	movzx	eax,ax
	mov	[eax+OPERAND.CODE],0
	mov	[di+OPERAND.CODE],0
	mov	[bx+OPERAND.CODE],0
	mov	[di+OPERAND.OEFLAGS],0
	mov	[bx+OPERAND.OEFLAGS],0
        mov     [di+OPERAND.ADDRESS],0
        mov     [bx+OPERAND.ADDRESS],0

	
	bt	DWORD PTR fs:[esi],0
	jc	notbyte
	bts	[di+OPERAND.OEFLAGS],OMF_BYTE
	bts	[bx+OPERAND.OEFLAGS],OMF_BYTE
notbyte:
	or	dx,dx
	jz	short xadr16
	bts	[di+OPERAND.OEFLAGS],OMF_ADR32
	bts	[bx+OPERAND.OEFLAGS],OMF_ADR32
	bts	[di+OPERAND.OEFLAGS],OMF_OP32
	bts	[bx+OPERAND.OEFLAGS],OMF_OP32
xadr16:
	test	[segs],SG_ADRSIZ
	jz	do_word1
	btc	[di+OPERAND.OEFLAGS],OMF_ADR32
	btc	[bx+OPERAND.OEFLAGS],OMF_ADR32
do_word1:
        mov     [realopsize],FALSE
	test	[segs],SG_OPSIZ
	jz	do_word2
        mov     [realopsize],TRUE
	btc	[di+OPERAND.OEFLAGS],OMF_OP32
	btc	[bx+OPERAND.OEFLAGS],OMF_OP32
do_word2:
	pop	ax
	or	ax,ax
	jz	nodispatch
	dec	al
	push	0
	call	TableDispatch
        dw      69
	dw	OP1,  OP2,  OP3,  OP4,  OP5,  OP6,  OP7,  OP8,  OP9,  OP10
	dw	OP11, OP12, OP13, OP14, OP15, OP16, OP17, OP18, OP19, OP20
	dw	OP21, OP22, OP23, OP24, OP25, OP26, OP27, OP28, OP29, OP30
	dw	OP31, OP32, OP33, OP34, OP35, OP36, OP37, OP38, OP39, OP40
	dw	OP41, OP42, OP43, OP44, OP45, OP46, OP47, OP48, OP49, OP50
        dw      OP51, OP52, OP53, OP54, OP55, OP56, OP59, OP59, OP59, OP60
        dw      OP61, OP62, OP63, OP64, OP65, OP66, OP67, OP68, OP69, OP70
	movzx	eax,al
	add	esi,eax
joindispatch:
	pop	bx
	movzx	eax,[bx+OPCODE.OCLENGTH]
	add	esi,eax
	ret
nodispatch:
        btr     [di+OPERAND.OEFLAGS],OMF_ADR32
        btr     [bx+OPERAND.OEFLAGS],OMF_ADR32
        btr     [di+OPERAND.OEFLAGS],OMF_OP32
        btr     [bx+OPERAND.OEFLAGS],OMF_OP32
        jmp     joindispatch
DispatchOperands	ENDP	


doreqsPtrSizeOvride	PROC	
	mov BYTE PTR [SI],C_RESERVEDWORD
	inc si
	mov byte ptr [si],0
	push	di
	push	si
	test	[reqsPtrSizeOvride],-1
	jz	short floatreqsPtrSizeOvride
        bt      [di+OPERAND.OEFLAGS],OMF_FARPTR
        jnc     drpso_nofar
        push    si
        push    di
        mov     di,si
        mov     si,offset opn_farptr
        call    strcat
        pop     di
        pop     si
drpso_nofar:

	bt	[di+OPERAND.OEFLAGS],OMF_BYTE
        jnc     chkfwptr
	mov	di,si
	mov	si,offset byptr
	jmp	short reqsPtrSizeOvrideend
chkfwptr:
        bt      [di+OPERAND.OEFLAGS],OMF_FWORD
        jnc     chkpbyteptr
	mov	di,si
        mov     si,offset fwptr
	jmp	short reqsPtrSizeOvrideend
chkpbyteptr:
        bt      [di+OPERAND.OEFLAGS],OMF_PBYTE
        jnc     chkdwptr
	mov	di,si
        mov     si,offset pbptr
	jmp	short reqsPtrSizeOvrideend
chkdwptr:
	bt	[di+OPERAND.OEFLAGS],OMF_OP32
	mov	di,si
        jnc     mkwordptr
	mov	si,offset dwptr
	jmp	short reqsPtrSizeOvrideend
mkwordptr:
	mov	si,offset woptr
  	jmp	short reqsPtrSizeOvrideend
floatreqsPtrSizeOvride:
	bt	[di+OPERAND.OEFLAGS],OMF_FSTTAB
	jnc	reqsPtrSizeOvridedone
        mov     eax,[di+OPERAND.OEFLAGS]
	shr	ax,OM_FTAB
	and	ax,7
	mov	di,si
	push	di
	mov	si,offset sts
	movzx	esi,si
	movzx	eax,ax
	mov	si,[esi+eax * 2]
	call	strcat
	mov	si,offset theptr
	pop	di
reqsPtrSizeOvrideend:
	call	strcat
reqsPtrSizeOvridedone:
	pop	si
	call	strlen
	add	si,ax
	mov BYTE PTR [SI],C_DEFAULT
	inc si
	mov BYTE PTR [SI],0
	pop	di
	ret
DoreqsPtrSizeOvride	ENDP	

;Tab over to the next location on the display
; INPUT: AL contains the number of positions to move 
;	SI points to a buffer aparently containing display strings?
; If the buffer contains a string whose length exceeds the passed tab
; position, we just add the requested tab position to SI, which now points
; into the middle of that string somewhere.  Otherwise, we stuff spaces into
; the buffer up to the requested tab position.

TabTo	PROC	
	movzx	cx,al		;convert length to dword
ttl:
	lodsb
	cmp	al,20h
	jae	notabcnt
	inc	cx
notabcnt:
	or	al,al
	loopne	ttl
	jcxz	ttns
	dec		si
	push	es
	push	ds
	pop		es
	mov		al,' '
	xchg	si,di
	cld
	rep		stosb
	xchg	si,di
	pop		es
ttns:
	mov		byte ptr [si], 0
	ret
TabTo	ENDP	


GetST	PROC	
	mov byte ptr [si],C_REGISTER
	inc si
	push	edi
	mov	al,[di+OPERAND.THEREG]
	push	ax
	xchg	si,di
	mov	si,offset stsreg
	call	strcpy
	pop	ax
	add	al,'0'
	dec	di
	stosb
	mov	al,')'
	stosb
	sub	al,al
	stosb
	dec	di
	xchg	si,di
	pop	edi
	mov byte ptr [si],C_DEFAULT
	inc si
	mov byte ptr [si], 0
	ret
GetST	ENDP	

GetMMX   PROC    
	mov byte ptr [si],C_REGISTER
	inc si
	push	edi
	mov	al,[di+OPERAND.THEREG]
	push	ax
	xchg	si,di
        mov     si,offset mmxreg
	call	strcpy
	pop	ax
	add	al,'0'
	dec	di
	stosb
	sub	al,al
	stosb
	dec	di
	xchg	si,di
	pop	edi
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
GetMMX   ENDP    

GetStdReg	PROC	
	mov byte ptr[si],C_REGISTER
	inc si
	push	edi
	or	al,al
	jnz	short gsrnoe
	mov	BYTE PTR [si],'e'
	inc	si
gsrnoe:
	mov	di,offset regs
	movzx	edi,di
	movzx	ecx,cx
	mov	ax,[edi+ecx *2]
	mov	[si],al
	inc	si
	mov	[si],ah
	inc	si
	mov byte ptr [si],C_DEFAULT
	inc si
	mov	BYTE PTR [si],0
	pop	edi
	ret
GetStdReg	ENDP	


GetReg	PROC	
	movzx	cx,al
	sub	al,al
	inc	al
	bt	[di+OPERAND.OEFLAGS],OMF_BYTE
	jc	short grno32
	bt	[di+OPERAND.OEFLAGS],OMF_OP32
	jnc	short grno32
	dec	al
grno32:
	bt	[di+OPERAND.OEFLAGS],OMF_BYTE
	jc	short isbyte
	or	cl,8
isbyte:
	call	GetStdReg
	ret
GetReg	ENDP	


GetSpecial	PROC	
	mov byte ptr [si],C_REGISTER
	inc si
	mov	al,[bx]
	mov	[si],al
	inc	si
	inc	bx
	mov	al,[bx]
	mov	[si],al
	inc	si
	inc	bx
	movzx	eax,[di+OPERAND.THEREG]
	movzx	ebx,bx
	mov	al,[ebx +eax]
	mov	[si],al
	inc	si
	mov byte ptr [si],C_DEFAULT
	inc si
	mov	BYTE PTR [si],0
	ret
GetSpecial	ENDP	


GetSeg	PROC	
	mov byte ptr [si],C_RESERVEDWORD
	inc si
	push	edi
	push	ax
	mov	di,offset psegs
	movzx	edi,di
	movzx	ecx,cx
	mov	ax,[edi+ecx *2]
	mov	[si],al
	inc	si
	mov	[si],ah
	inc	si
	mov BYTE PTR [SI],C_DEFAULT
	inc si
	pop	ax
	or	al,al
	mov	al,':'
	jz	short nocolon
	mov	[si],al
	inc	si
nocolon:
	mov	BYTE PTR [si],0
	pop	edi
	ret
GetSeg	ENDP	


SegOverride	PROC	
	mov	al,1
        mov     [hasputoverride],al
	sub	cx,cx
	test	[segs],SG_ES
	jz	short so_testcs
	call	GetSeg
so_testcs:
	inc	cx
	test	[segs],SG_CS
	jz	short so_testss
	call	GetSeg
so_testss:
	inc	cx
	test	[segs],SG_SS
	jz	short so_testds
	call	GetSeg
so_testds:
	inc	cx
	test	[segs],SG_DS
	jz	short so_testfs
	call	GetSeg
so_testfs:
	inc	cx
	test	[segs],SG_FS
	jz	short so_testgs
	call	GetSeg
so_testgs:
	inc	cx
	test	[segs],SG_GS
	jz	short so_done
	call	GetSeg
so_done:
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
SegOverride	ENDP	


Scaled	PROC	
	push	DWORD PTR [di+OPERAND.OEFLAGS]
	btr	[di+OPERAND.OEFLAGS],OMF_BYTE
	bts	[di+OPERAND.OEFLAGS],OMF_OP32
	or	al,al
	jz	short notbased
	sub	al,al
	mov	al,[di+OPERAND.THEREG]
	call	GetReg
notbased:
	bt	[di+OPERAND.OEFLAGS],OMF_SCALED
	jnc	short notscaled2
	mov	byte ptr [si],'+'
	inc	si
	mov	al,[di+OPERAND.SCALEREG]
	call	GetReg
	movzx	cx,[di+OPERAND.SCALE]
;        or      cx,cx
;        jz      notscaled2
	add	cx,cx
	mov byte ptr [si],C_NUMBER
	inc	si
	add	cx,offset scales
	movzx	ecx,cx
	mov	ax,[ecx]
	call	put2
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
notscaled2:
	pop	DWORD PTR [di+OPERAND.OEFLAGS]
	ret
Scaled	ENDP	


FOM_FSTREG	PROC	
	mov	di,offset stalone
	call	strcat
	ret
FOM_FSTREG	ENDP	


FOM_CRX	PROC	
	mov	bx,offset crreg
	call	GetSpecial
	ret
FOM_CRX	ENDP	


FOM_DRX	PROC	
	mov	bx,offset drreg
	call	GetSpecial
	ret
FOM_DRX	ENDP	


FOM_TRX	PROC	
	mov	bx,offset trreg
	call	GetSpecial
	ret
FOM_TRX	ENDP	


FOM_SUD	PROC	
	mov	bx,offset sudreg
	call	GetSpecial
	ret
FOM_SUD	ENDP	


FOM_PORT	PROC	
	mov	al,SY_PORT
	jmp	FormatValue
FOM_PORT	ENDP	


FOM_INT	PROC	
	mov	al,SY_INTR
	jmp	FormatValue
FOM_INT	ENDP	


FOM_SHIFT	PROC	
	bt	[di+OPERAND.OEFLAGS],OMF_CL
	jnc	fos_notcl
	mov byte ptr [si],C_REGISTER
	inc	si
	mov	ax,"cl"
	call	put2
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
fos_notcl:
	cmp	[di+OPERAND.ADDRESS],1
	mov	al,SY_SHIFT
	jnz	FormatValue
	mov	BYTE PTR [si],'1'
	inc	si
	mov	BYTE PTR [si],0
	ret
FOM_SHIFT	ENDP	


FOM_RETURN	PROC	
	mov	al,SY_RETURN
	jmp	FormatValue
FOM_RETURN	ENDP	


FOM_SHORTBRANCH	PROC	
	mov	al,SY_SHORTBRANCH
	jmp	FormatValue
FOM_SHORTBRANCH	ENDP	


FOM_LONGBRANCH	PROC	
	mov	al,SY_LONGBRANCH
	jmp	FormatValue
FOM_LONGBRANCH	ENDP	


FOM_FARBRANCH	PROC	
        push    ebx
        mov     dx,[di+OPERAND.OESEG]
        mov     ebx,[di + OPERAND.ADDRESS]
        push    es
        push    di
        call    symLookupByValue
        jc      psa_fb
	mov byte ptr [si],C_SYMBOL
	inc	si
        call    putsyms
	mov byte ptr [si],C_DEFAULT
	inc	si
        pop     di
        pop     es
        pop     ebx
        mov     byte ptr [si],'('
        inc     si
	mov	al,SY_SEGMENT
	call	FormatValue
	mov	BYTE PTR [si],':'
	inc	si
        mov     eax,[di + OPERAND.ADDRESS]
        call    putwordox
        mov     byte ptr [si],')'
        inc     si
	mov	byte ptr [si],0
        ret
psa_fb:
        pop     di
        pop     es
        pop     ebx
	mov	al,SY_SEGMENT
	call	FormatValue
	mov	BYTE PTR [si],':'
	inc	si
	mov	al,SY_ABSBRANCH
        jmp     FormatValue
FOM_FARBRANCH	ENDP	


FOM_ABSOLUTE	PROC	
	call	DoreqsPtrSizeOvride
	call	SegOverride
	mov	BYTE PTR [si],'['
	inc	si
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov	BYTE PTR [si],0
	bt	[di+OPERAND.OEFLAGS],OMF_SCALED
	jnc	foa_notscaled
	mov	al,SY_WORDOFS
	call	FormatValue
	sub	ax,ax
	call	Scaled
	jmp	short foa_finish
foa_notscaled:
	mov	al,SY_ABSOLUTE
	call	FormatValue
foa_finish:
	mov	BYTE PTR [si],']'
	inc	si
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov	BYTE PTR [si],0
	ret
FOM_ABSOLUTE	ENDP	


FOM_IMMEDIATE	PROC	
	bt	[di+OPERAND.OEFLAGS],OMF_BYTE
	mov	al,SY_WORDIMM
	jnc	short absformat
	test	[optsignedimm],1
	jnz	fi_signed
	mov	al,SY_BYTEIMM
	push	ebx
	movzx	ebx,byte ptr [di + OPERAND.ADDRESS]
        bt      [di + OPERAND.OEFLAGS],OMF_SIGNED
        jnc     fi_nsi
		mov	al,SY_WORDIMM
        movsx   ebx,bl
fi_nsi:
	mov	[di + OPERAND.ADDRESS],ebx
	pop	ebx
	jmp	FormatValue
fi_signed:
	mov	al,SY_BYTEOFS
	bt	[di+OPERAND.OEFLAGS],OMF_SIGNED
	jnc	short absformat
	mov	al,SY_SIGNEDIMM
	test	[optsignedimm],1
	jnz	absformat
        movsx   eax,byte ptr [di + OPERAND.ADDRESS]
	mov	[di + OPERAND.ADDRESS],eax
	mov	al,SY_WORDIMM
absformat:
	jmp	FormatValue
FOM_IMMEDIATE	ENDP	


FOM_REG	PROC	
        bt      [di+OPERAND.OEFLAGS],OMF_MMXTAB
        jnc     isfst
        call    GetMMX
        ret
isfst:
	bt	[di+OPERAND.OEFLAGS],OMF_FST
	jnc	short foreg
	call	GetST
	ret
foreg:
	mov	al,[di+OPERAND.THEREG]
	call	GetReg
	ret
FOM_REG	ENDP	


FOM_BASED	PROC	
	call	DoreqsPtrSizeOvride
	call	SegOverride
	mov	BYTE PTR [si],'['
	inc	si
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov	BYTE PTR [si],0
	bt	[di+OPERAND.OEFLAGS],OMF_ADR32
	jnc	fob_notscaled
	mov	al,1
	call	scaled
	jmp	short fob2
fob_notscaled:
	mov 	byte ptr [si],C_REGISTER
	inc		si
	push	di
	push	si
	movzx	eax,BYTE PTR [di+OPERAND.THEREG]
	xchg	si,di
	mov	si,offset based
	movzx	esi,si
	movzx	ecx,cx
	mov	si,[esi+eax * 2]
	call	strcpy
	pop	si
	pop	di
	call	strlen
	add	si,ax
	mov		byte ptr [si],C_DEFAULT
	inc si
	mov		byte ptr [si],0
fob2:
	test	[di+OPERAND.OEFLAGS],OMF_OFFSET
	jz	short fob_noofs
	bt	[di+OPERAND.OEFLAGS],OMF_SIGNED_OFFSET
	mov	al,SY_SIGNEDOFS
	jc	fob_format
	mov	al,SY_WORDOFS
	bt	[di+OPERAND.OEFLAGS],OMF_WORD_OFFSET
	jc	fob_format
	mov	al,SY_BYTEOFS
fob_format:
	call	FormatValue
fob_noofs:
	mov	BYTE PTR [si],']'
	inc	si
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov	BYTE PTR [si],0
	ret
FOM_BASED	ENDP	


FOM_SEGMENT	PROC	
	movzx	cx,[di+OPERAND.THEREG]
	sub	ax,ax
	call	GetSeg
	ret
FOM_SEGMENT	ENDP	


PutOperand	PROC	
	call	strlen
	add	si,ax
	mov	al,[di+OPERAND.CODE]
	dec	al
	js	short po_none
	push	0
	call	TableDispatch
	dw	17
	dw	fom_based
	dw	fom_segment
	dw	fom_reg
	dw	fom_immediate
	dw	fom_absolute
	dw	fom_farbranch
	dw	fom_longbranch
	dw	fom_shortbranch
	dw	fom_return
	dw	fom_shift
	dw	fom_int
	dw	fom_port
	dw	fom_sud
	dw	0
	dw	fom_trx
	dw	fom_drx
	dw	fom_crx
	dw	fom_fstreg
po_none:
	ret
PutOperand	ENDP	


FormatDisassembly	PROC	
	ENTER	256,0
        mov     [hasputoverride],0
	push	si
	lea	di,[bp-256]
	push	di
	mov	BYTE PTR [di],0
        test    [segs],SG_LOCK
        jz      fd_notlock
        mov     si,offset st_lock
        call    strcpy
fd_notlock:
	test	[segs],SG_REPZ
	jz	fd_notrepz
	mov	si,offset st_repz
        call    strcat
fd_notrepz:
	test	[segs],SG_REPNZ
	jz	fd_notrepnz
		mov	si,offset st_repnz
        call    strcat
fd_notrepnz:
	pop	di
	xchg	si,di
	call	strlen
	add	si,ax
	mov	byte ptr [si], C_INSTRUCTION
	inc si
	mov	byte ptr [si], 0
	xchg	si,di
	mov	si,offset nmmnemonic
	call	strcat
	lea	si,[bp-256]
	sub	ax,ax
	mov	al,TAB_ARGPOS
	call	TabTo
	mov	byte ptr [si], C_DEFAULT
	inc si
	mov	byte ptr [si], 0
	mov	di,offset dest
	call	PutOperand
	mov	di,offset source
	test	[di+OPERAND.CODE],-1
	jz	short nosource
	mov	BYTE PTR [si],','
	inc	si
	mov	BYTE PTR [si],0
	call	PutOperand
nosource:
	mov	di,offset extraoperand
	test	[di+OPERAND.CODE],-1
	jz	short noextra
	mov	BYTE PTR [si],','
	inc	si
	mov	BYTE PTR [si],0
	call	PutOperand
noextra:
	pop	si	
	mov	BYTE PTR [si],0
        test    [hasputoverride],255
        jnz     nonewover
	call	SegOverride
nonewover:
	mov	di,si
	lea	si,[bp-256]
	call	strcat
	LEAVE
	ret
FormatDisassembly	ENDP	


putdword:
	push	eax		; To print a dword
	shr	eax,16		; Print the high 16 bits
	call	putword
	pop	eax		; And the low 16 bits
putword:
	push	ax		; To print a word
	mov	al,ah		; Print the high byte
	call	putbyte
	pop	ax		; And the low byte
putbyte:
	push	ax		; To print a byte
	shr	ax,4		; Print the high nibble
	call	putnibble
	pop	ax		; And the low nibble
putnibble:
	and	al,0fh		; Get a nibble
	add	al,'0'		; Make it numeric
	cmp	al,'9'		; If supposed to be alphabetic
	jle	onib
	add	al,7		; Add 7
onib:
	mov	[si],al
	inc	si
	ret

putwordox:
	mov byte ptr [si],C_NUMBER
	inc	si
	bt	[di+OPERAND.OEFLAGS],OMF_OP32
	jnc	putword
	jmp	putdword
putwordax:
	mov byte ptr [si],C_NUMBER
	inc	si
	bt	[di+OPERAND.OEFLAGS],OMF_ADR32
	jnc	putword
	jmp	putdword

putsyms PROC
        push    cx
        xchg    si,di
        push    ds
        push    es
        push    ds
        push    es
        pop     ds
        pop     es
        add     si,6
        lodsb
        movzx   cx,al
        rep     movsb
        xchg    si,di
        pop     es
        pop     ds
        pop     cx
        ret
putsyms ENDP
defseg PROC
        test    [segs],SG_ES
        jnz     defes
        test    [segs],SG_DS
        jnz     defds
        test    [segs],SG_CS
        jnz     defcs
        test    [segs],SG_SS
        jnz     defss
        test    [segs],SG_FS
        jnz     deffs
        test    [segs],SG_GS
        jnz     defgs
defds:
        mov     dx,[RegDumpDS]
        ret
defes:
        mov     dx,[RegDumpES]
        ret
defcs:
        mov     dx,[RegDumpCS]
        ret
defss:
        mov     dx,[RegDumpSS]
        ret
deffs:
        mov     dx,[RegDumpFS]
        ret
defgs:
        mov     dx,[RegDumpGS]
        ret
        
defseg ENDP
putsymax PROC
        push    ebx
        mov     ebx,eax
        call    defseg
        push    es
        push    di
        call    symLookupByValue
        jc      psa_n
		mov byte ptr [si],C_SYMBOL
		inc	si
        call    putsyms
        pop     di
        pop     es
		mov byte ptr [si],C_NUMBER
		inc	si
        mov     byte ptr [si],'('
        inc     si
        mov     eax,ebx
        pop     ebx
        call    putwordax
        mov     byte ptr [si],')'
        inc     si
		mov byte ptr [si],C_DEFAULT
		inc	si
		mov byte ptr [si],0
        ret
psa_n:
        pop     di
        pop     es
        mov     eax,ebx
        pop     ebx
        jmp     putwordax
putsymax ENDP
putsymox PROC
        push    ebx
        mov     ebx,eax
        call    defseg
        push    es
        push    di
        call    symLookupByValue
        jc      pso_n
		mov byte ptr [si],C_SYMBOL
		inc	si
        call    putsyms
        pop     di
        pop     es
		mov byte ptr [si],C_NUMBER
		inc	si
        mov     byte ptr [si],'('
        inc     si
        mov     eax,ebx
        pop     ebx
        call    putwordox
        mov     byte ptr [si],')'
        inc     si
		mov byte ptr [si],C_DEFAULT
		inc	si
		mov byte ptr [si],0
        ret
pso_n:
        pop     di
        pop     es
        mov     eax,ebx
        pop     ebx
        jmp     putwordox
putsymox ENDP
putsymbr PROC
        push    ebx
        mov     ebx,eax
        mov     dx,[RegDumpCS]
        push    es
        push    di
        call    symLookupByValue
        jc      pso_b
		mov byte ptr [si],C_SYMBOL
		inc	si
        call    putsyms
        pop     di
        pop     es
		mov byte ptr [si],C_NUMBER
		inc	si
        mov     byte ptr [si],'('
        inc     si
        mov     eax,ebx
        pop     ebx
        call    putwordox
        mov     byte ptr [si],')'
        inc     si
		mov byte ptr [si],C_DEFAULT
		inc	si
		mov byte ptr [si],0
        ret
pso_b:
        pop     di
        pop     es
        mov     eax,ebx
        pop     ebx
        jmp     putwordox
putsymbr ENDP
FSY_SIGNEDOFS   PROC    
	push	bx
	mov	eax,[di+OPERAND.ADDRESS]
	bt	eax,7
	mov	bl,'+'
	jnc	fso_pos
	mov	bl,'-'
	neg	al
fso_pos:
	mov	byte ptr [si],bl
	inc si
	mov byte ptr [si],C_NUMBER
	inc	si
	call	putbyte
	pop	bx
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_SIGNEDOFS	ENDP	


FSY_WORDOFS	PROC	
	push	bx
	mov	eax,[di+OPERAND.ADDRESS]
        bt      [di + OPERAND.OEFLAGS],OMF_ADR32
        jnc     wordchk
        cmp     eax,-40000000h
        jmp     fwo_join
wordchk:
	cmp	ax,-4000h
fwo_join:
	mov	bl,'+'
	jc	fsy_wouseplus
        neg     eax
	mov	bl,'-'
fsy_wouseplus:
	mov	byte ptr [si],bl
	inc si
	mov byte ptr [si],C_NUMBER
	inc	si
    call    putsymax
	pop	bx
	ret
FSY_WORDOFS	ENDP	


FSY_BYTEOFS	PROC	
	mov byte ptr [si],C_NUMBER
	inc	si
	mov	eax,[di+OPERAND.ADDRESS]
	call	putbyte
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_BYTEOFS	ENDP	


FSY_ABSOLUTE	PROC	
	mov	eax,[di+OPERAND.ADDRESS]
        call    putsymax
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_ABSOLUTE	ENDP	


FSY_SIGNEDIMM	PROC	
	jmp	fsy_signedofs
FSY_SIGNEDIMM	ENDP	


FSY_WORDIMM	PROC	
	mov	eax,[di+OPERAND.ADDRESS]
        call    putsymox
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_WORDIMM	ENDP	


FSY_BYTEIMM	PROC	
	mov byte ptr [si],C_NUMBER
	inc	si
	mov	eax,[di+OPERAND.ADDRESS]
	call	putbyte
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_BYTEIMM	ENDP	


FSY_PORT	PROC	
	mov byte ptr [si],C_NUMBER
	inc	si
	mov	eax,[di+OPERAND.ADDRESS]
	call	putbyte
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_PORT	ENDP	


FSY_INTR	PROC	
	mov byte ptr [si],C_NUMBER
	inc	si
	mov	eax,[di+OPERAND.ADDRESS]
	call	putbyte
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_INTR	ENDP	


FSY_RETURN	PROC	
	mov byte ptr [si],C_NUMBER
	inc	si
	mov	eax,[di+OPERAND.ADDRESS]
	call	putword
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_RETURN	ENDP	


FSY_ABSBRANCH	PROC	
	mov	eax,[di+OPERAND.ADDRESS]
        call    putsymbr
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_ABSBRANCH	ENDP	


FSY_LONGBRANCH	PROC	
	mov	eax,[di+OPERAND.ADDRESS]
        call    putsymbr
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_LONGBRANCH	ENDP	


FSY_SHORTBRANCH	PROC	
	mov	eax,[di+OPERAND.ADDRESS]
        call    putsymbr
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_SHORTBRANCH	ENDP	


FSY_SHIFT	PROC	
	mov byte ptr [si],C_NUMBER
	inc	si
	mov	eax,[di+OPERAND.ADDRESS]
	call	putbyte
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_SHIFT	ENDP	


FSY_SEGMENT	PROC	
	mov byte ptr [si],C_NUMBER
	inc	si
	mov	ax,[di+OPERAND.OESEG]
	call	putword
	mov byte ptr [si],C_DEFAULT
	inc	si
	mov byte ptr [si],0
	ret
FSY_SEGMENT	ENDP	


FormatValue	PROC	
	dec	al
	push	0
	call	TableDispatch
	dw	14
	dw	FSY_SIGNEDOFS,FSY_WORDOFS,FSY_BYTEOFS,FSY_ABSOLUTE
	dw	FSY_SIGNEDIMM,FSY_WORDIMM,FSY_BYTEIMM,FSY_PORT
	dw	FSY_INTR,FSY_RETURN,FSY_ABSBRANCH,FSY_LONGBRANCH
	dw	FSY_SHORTBRANCH,FSY_SHIFT,FSY_SEGMENT
	mov	byte ptr [si],0
	ret
FormatValue	ENDP	

END
