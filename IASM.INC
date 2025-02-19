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
asmop	struc
addrx	dd	0	;address of offset (or seg for segmented jump)
addrx2	dd	0	;offset for segmented jump if addrx is segment
mode	db	0	;AM flag showing addressing mode

	AM_NONE   = 0		;no mode, like [44h], or no arg, like CLI
	AM_REG	  = 1		;register, like AX
	AM_BASED  = 2		;based, as in [bx+label]
	AM_MEM	  = 3		;memory, as in byte ptr [44h], or label
	AM_IMM	  = 4		;immediate, as in mov ax,5
	AM_SEGOFFS = 5		;seg:ofs, as in es:[44h]
	AM_CR	= 6		;control register used
	AM_DR	= 7		;debug register used
	AM_TR	= 8		;test register used
	AM_FPREG = 9		;floating point register used
	AM_SEG	= 10		;segment, maybe as in mov ax,cs
  AM_MMX = 11   ; MMX register used
areg1	db	0	;base register
areg2	db	0	;index register (pertains to scale)

;These equates apply to areg1 and areg2. areg1 is a simple index register,
;like [bx+nnn], areg2 is for two cases: 1) two index registers used, as
;in [bx+si+nnn], and 2) scaled registers, like [ebx+eax*4+nnn]
;  In case 2), the scale applied to areg2 is in ascale

	isEAX	equ	0	;reference to this register in areg1,2
	isECX	equ	1
	isEDX	equ	2
	isEBX	equ	3
	isESP	equ	4
	isEBP	equ	5
	isESI	equ	6
	isEDI	equ	7

ascale	dw	0	;scale of areg2
	TIMES1	equ	1
	TIMES2	equ	2
	TIMES4	equ	4
	TIMES8	equ	8
asize	db	0	;size of memory/register 1=byte, 10-tbyte, etc
	NOSIZE		equ	0
	BYTESIZE	equ	1
	WORDSIZE	equ	2
	DWORDSIZE	equ	4
  PBYTESIZE equ 5
	FWORDSIZE	equ	6
	QWORDSIZE	equ	8
	TBYTESIZE	equ	10
msize	db	0	;addressing mode size 2=16-bit, 4=32-bit
	BYTEMODE	equ	1
	WORDMODE	equ	2
	DWORDMODE	equ	4
asmop	ends

TRUE	equ	1


;These next flags get put in the mode field


;These values are stored in RepPfxBitmap, and indicate which one of these
;prefixes was identified

AF_REP	= 1
AF_REPNE = 2
AF_REPE  = 4
AF_LOCK  = 8

;These are keyed to offsets of segment overrides (or 66h,67h overrides)
;in the string of possible override strings.  They work in reverse, so
;that AS is the first two chars of the string, OS is next, then GS etc.

AS_ES = 	00000001b
AS_CS = 	00000010b
AS_SS = 	00000100b
AS_DS = 	00001000b
AS_FS = 	00010000b
AS_GS = 	00100000b
AS_OPSIZE =   11000000b
AS_ADDRSIZE =   1100000000b
AS_OPSIZESET = 01000000b
AS_OPSIZETEST = 10000000b
AS_ADDRSIZESET = 0100000000b
AS_ADDRSIZETEST = 1000000000b