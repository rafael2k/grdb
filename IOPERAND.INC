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
FALSE = 0
TRUE = 1

TAB_ARGPOS =13
TAB_DISPOS =52

REG_eAX =0
REG_DX =2

OM_FSTREG =18
OM_CRX  =17
OM_DRX  =16
OM_TRX  =15
OM_SUD  =13
OM_PORT	  =    12
OM_INT    = 11
OM_SHIFT   =10
OM_RETURN  =9
OM_SHORTBRANCH  =8
OM_LONGBRANCH  =7
OM_FARBRANCH  =6
OM_ABSOLUTE  =5
OM_IMMEDIATE = 4
OM_REG  =3
OM_SEGMENT  =2
OM_BASED =1

;// Generic
OMF_ADR32 =0
OMF_OP32 =1
OMF_BYTE =2
OMF_FST =3
OMF_FSTTAB =4
OM_FTAB =5
OMF_MMXTAB = 8
OMF_XMMXTAB = 9
OMF_FARPTR = 10
OMF_PBYTE = 11
OMF_FWORD = 12
OMF_BASE = 13
;// base & immediate specific
OMF_SCALED =OMF_BASE
OMF_SIGNED_OFFSET = OMF_BASE + 1
OMF_WORD_OFFSET =(OMF_BASE + 2)
OMF_OFFSET =((1 SHL OMF_SIGNED_OFFSET) OR (1 SHL OMF_WORD_OFFSET))
;// shift specific
OMF_CL	=OMF_BASE
;// Port specific
OMF_DX  =OMF_BASE
;// Immediate specific
OMF_SIGNED =OMF_BASE

SG_ES =1
SG_CS =2
SG_SS =4
SG_DS =8
SG_FS =16
SG_GS =32
SG_OPSIZ =64
SG_ADRSIZ =128
SG_REPNZ =256
SG_REPZ =512
SG_REPNC =1024
SG_REPC =2048
SG_TWOBYTEOP =4096
SG_LOCK = 8192

SY_SIGNEDOFS =1
SY_WORDOFS =2
SY_BYTEOFS =3
SY_ABSOLUTE =4
SY_SIGNEDIMM =5
SY_WORDIMM =6
SY_BYTEIMM =7
SY_PORT =8
SY_INTR =9
SY_RETURN =10
SY_ABSBRANCH =11
SY_LONGBRANCH =12
SY_SHORTBRANCH =13
SY_SHIFT =14
SY_SEGMENT =15

MOD_NOOFS =0
MOD_SIGNED =1
MOD_ADDR =2
MOD_REG =3

RM_16_ABSOLUTE =6
RM_32_ABSOLUTE =5
RM_32_SCALED =4
RM_32_STACKINDEX =4

MODX	MACRO	rrr
	mov	al,fs:[rrr + 1]
	shr	al,6
ENDM

REG	MACRO	rrr
	mov	al,fs:[rrr + 1]
	shr	al,3
	and	al,7
ENDM

RM	MACRO	rrr
	mov	al,fs:[rrr + 1]
	and	al,7
ENDM

LONG	MACRO	rrr
	mov	eax,fs:[rrr]
ENDM

UINT	MACRO	rrr
	movzx	eax,word ptr fs:[rrr]
ENDM

SIGNEDOFS 	MACRO	rrr
	movsx	eax,fs:[rrr]
ENDM

B01	MACRO
	and	al,3
ENDM

B12	MACRO
	shr	eax,1
	and	al,3
ENDM

B02	MACRO
	and	al,7
ENDM

B35	MACRO
	shr	eax,3
	and	al,7
ENDM

B45	MACRO
	shr	eax,4
	and	al,3
ENDM

operand	STRUC
oeflags   dd  ?
override	dw	?
address		dd	?
oeseg		dw	?
code		db	?
thereg		db	?
scalereg 	db	?
scale		db	?
operand ENDS

OPERANDSIZE = SIZEOF operand