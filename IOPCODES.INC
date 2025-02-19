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
OP_CODEONLY =0
OP_WREG02 =1
OP_ACCREG02 =2
OP_SEG35 =3
OP_REGRMREG =4
OP_RM =5
OP_RMSHIFT =6
OP_REGRM =7
OP_WORDREGRM =8
OP_INTR =9
OP_SHORTBRANCH =10
OP_RMIMM =11
OP_ACCIMM =12
OP_ABSACC =13
OP_RMIMMSIGNED =14
OP_ACCIMMB3 =15
OP_SEGRMSEG =16
OP_RET =17
OP_SEGBRANCH =18
OP_ESC =19
OP_BRANCH =20
OP_ACCDX =21
OP_DXACC =22
OP_PORTACCPORT= 23
OP_ACCABS =24
OP_IMM =25
OP_ENTER =26
OP_INSWORDSIZE =27
OP_REGMOD =28
OP_NOSTRICTRM = 29
OP_RMSHIFTB3 =30
OP_IMUL =31
OP_386REG =32
OP_REGRMSHIFT =33
OP_PUSHW =34
OP_FLOATRM =35
OP_FLOATMATHP =36
OP_FLOATMATH =37
OP_FARRM =38
OP_WORDRMREG =39
OP_RMREG =40
OP_BITNUM =41
OP_MIXEDREGRM =42
OP_CBW = 43
OP_REG02 = 44
OP_BYTERMREG = 45
OP_FLOATNOPTR = 46
OP_AX	= 47
OP_BSWAP = 48
OP_FST = 49
OP_FLD = 50
OP_FBLD = 51
OP_FILD = 52
OP_FIST = 53
OP_FREG = 54
OP_FREGMAYBE = 55
OP_FLOATIMATH = 56
OP_ADDRSIZE1BYTE = 57 ; assembler only
OP_OPSIZE1BYTE = 58	; same
OP_MMXSTD = 59
OP_MMXMOVDLD = 60
OP_MMXMOVDST = 61
OP_MMXMOVQLD = 62
OP_MMXMOVQST = 63
OP_MMXSHIFT = 64
OP_LOOP = 65
OP_CWD = 66
OP_AAM = 67
OP_XLAT = 68
OP_SETS = 69
OP_LGDT = 70
 
opcode	STRUC
msk		dw	?		;mask value for opcode
compare		dw	?		;opcode itself after masking
mnemonic	dw	?		;pointer to mnemonic string
operands	db	?		;addressing mode
oclength	db	?		;base length of instruction
flags		db	?		
	x386_OPCODE	equ	1
	prefix0F	equ	2
opcd		db	?		;not used right now
opcode  ENDS

OPCODESIZE = SIZEOF opcode