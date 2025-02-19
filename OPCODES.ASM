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
; opcodes.asm
;
; Locate the opcode table entry for a given opcode byte
; ALSO, locate the opcode table entries for a given mnemonic
;
	;MASM MODE
	.model small
	.386p
include  iopcodes.inc
include  eoptions.inc
include  eopcom.inc

	PUBLIC	FindOpcode
	PUBLIC	mnemonicMatchCount
	PUBLIC	mnemonicMatchAddrTable
	PUBLIC	LookupOpName
	public  x86pfx

	.data

x86pfx	db	0
;
; Following is a table of opcodes.  Each entry consists of a mask value,
; a comparison value, a pointer to the name, the addressing mode to be
; used in dissassembly, and the base length of the instruction (possibly
; modified by the exact addressing mode encountered)
;
; added two new bytes: first is evalutation flags, second is unused
;
;  The groups are selected based on the high order 3 bits of the first
;  byte of the opcode, which are translated into a table offset. These
;  bits probably encode something that all opcodes have in common if the
;  high order 3 bits are the same, but I don't know what it might be.
;	In any case, from the lookup logic, it appears that these structures
;  are broken into groups only for performance, which is hardly necessary
;  since this program won't run on anything less than a P24T - it has a
;  CPUID instruction in it.

group000xxxxx	label	byte
	opcode	<0FCh,0,opn_add,OP_REGRMREG,2,0,0>	;ADD RM
	opcode	<0e7h,06h,opn_push,OP_SEG35,1,0,0>	;PUSH
	opcode	<0feh,04h,opn_add,OP_ACCIMM,1,0,0>	;ADD immediate
	opcode	<0e7h,07h,opn_pop,OP_SEG35,1,0,0>	;POP
	opcode	<0fch,08h,opn_or,OP_REGRMREG,2,0,0>	;OR RM
	opcode	<0feh,0ch,opn_or,OP_ACCIMM,1,0,0>	;OR immediate
	opcode	<0fch,010h,opn_adc,OP_REGRMREG,2,0,0>	;ADC RM
	opcode	<0feh,014h,opn_adc,OP_ACCIMM,1,0,0>	;ADC immediate
	opcode	<0fch,018h,opn_sbb,OP_REGRMREG,2,0,0>	;SBB RM
	opcode	<0feh,01ch,opn_sbb,OP_ACCIMM,1,0,0>	;SBB immediate
	opcode	<0,0,0,0,0,0,0>				;group terminator

group001xxxxx	label	byte
	opcode	<0fch,020h,opn_and,OP_REGRMREG,2,0,0>	;AND RM
	opcode	<0feh,024h,opn_and,OP_ACCIMM,1,0,0>	;AND immediate
	opcode	<0ffh,027h,opn_daa,OP_CODEONLY,1,0,0>	;DAA
	opcode	<0fch,028h,opn_sub,OP_REGRMREG,2,0,0>	;SUB RM
	opcode	<0feh,02ch,opn_sub,OP_ACCIMM,1,0,0>	;SUB immediate
	opcode	<0ffh,02fh,opn_das,OP_CODEONLY,1,0,0>	;DAS
	opcode	<0fch,030h,opn_xor,OP_REGRMREG,2,0,0>	;XOR RM
	opcode	<0feh,034h,opn_xor,OP_ACCIMM,1,0,0>	;XOR immediate
	opcode	<0ffh,037h,opn_aaa,OP_CODEONLY,1,0,0>	;AAA
	opcode	<0fch,038h,opn_cmp,OP_REGRMREG,2,0,0>	;CMP RM
	opcode	<0feh,03ch,opn_cmp,OP_ACCIMM,1,0,0>	;CMP immediate
	opcode	<0ffh,03fh,opn_aas,OP_CODEONLY,1,0,0>	;AAS
	opcode	<0,0,0,0,0,0,0>				;group terminator

group010xxxxx	label	byte
	opcode	<0f8h,040h,opn_inc,OP_WREG02,1,0,0>	;INC
	opcode	<0f8h,048h,opn_dec,OP_WREG02,1,0,0>	;DEC
	opcode	<0f8h,050h,opn_push,OP_WREG02,1,0,0>	;PUSH
	opcode	<0f8h,058h,opn_pop,OP_WREG02,1,0,0>	;POP
	opcode	<0,0,0,0,0,0,0>				;group terminator

group011xxxxx	label	byte
	opcode	<0ffh,060h,opn_pusha,OP_INSWORDSIZE,1,1,0>	;PUSHA
	opcode	<0ffh,061h,opn_popa,OP_INSWORDSIZE,1,1,0>	;POPA
	opcode	<0ffh,062h,opn_bound,OP_WORDREGRM,2,1,0>	;BOUND
	opcode	<0ffh,063h,opn_arpl,OP_WORDRMREG,2,1,0>		;ARPL
	opcode	<0fdh,068h,opn_push,OP_IMM,1,1,0>		;PUSH imm
	opcode	<0fdh,069h,opn_imul,OP_IMUL,2,0,0>		;IMUL
	opcode	<0ffh,06ch,opn_insb,OP_CODEONLY,1,1,0>		;INSB
	opcode	<0ffh,06dh,opn_ins,OP_INSWORDSIZE,1,1,0>	;INS
	opcode	<0ffh,06eh,opn_outsb,OP_CODEONLY,1,1,0>		;OUTSB
	opcode	<0ffh,06fh,opn_outs,OP_INSWORDSIZE,1,1,0>	;OUTS
	opcode	<0ffh,070h,opn_jo,OP_SHORTBRANCH,2,0,0>		;JO
	opcode	<0ffh,071h,opn_jno,OP_SHORTBRANCH,2,0,0>	;JNO
	opcode	<0ffh,072h,opn_jb,OP_SHORTBRANCH,2,0,0>		;JB
	opcode	<0ffh,073h,opn_jnb,OP_SHORTBRANCH,2,0,0>	;JNB
	opcode	<0ffh,074h,opn_jz,OP_SHORTBRANCH,2,0,0>		;JZ
	opcode	<0ffh,075h,opn_jnz,OP_SHORTBRANCH,2,0,0>	;JNZ
	opcode	<0ffh,076h,opn_jbe,OP_SHORTBRANCH,2,0,0>	;JBE
	opcode	<0ffh,077h,opn_ja,OP_SHORTBRANCH,2,0,0>		;JA
	opcode	<0ffh,078h,opn_js,OP_SHORTBRANCH,2,0,0>		;JS
	opcode	<0ffh,079h,opn_jns,OP_SHORTBRANCH,2,0,0>	;JNS
	opcode	<0ffh,07ah,opn_jp,OP_SHORTBRANCH,2,0,0>		;JP
	opcode	<0ffh,07bh,opn_jnp,OP_SHORTBRANCH,2,0,0>	;JNP
	opcode	<0ffh,07ch,opn_jl,OP_SHORTBRANCH,2,0,0>		;JL
	opcode	<0ffh,07dh,opn_jge,OP_SHORTBRANCH,2,0,0>	;JGE
	opcode	<0ffh,07eh,opn_jle,OP_SHORTBRANCH,2,0,0>	;JLE
	opcode	<0ffh,07fh,opn_jg,OP_SHORTBRANCH,2,0,0>		;JG
	opcode	<0,0,0,0,0,0,0>					;terminator

group100xxxxx	label	byte
	opcode	<038fch,080h,opn_add,OP_RMIMMSIGNED,2,0,0>	;ADD
	opcode	<038feh,0880h,opn_or,OP_RMIMMSIGNED,2,0,0>	;OR
	opcode	<038fch,0880h,opn_or,OP_RMIMMSIGNED,2,0,0>	;OR
	opcode	<038fch,01080h,opn_adc,OP_RMIMMSIGNED,2,0,0>	;ADC
	opcode	<038fch,01880h,opn_sbb,OP_RMIMMSIGNED,2,0,0>	;SBB
	opcode	<038feh,02080h,opn_and,OP_RMIMMSIGNED,2,0,0>	;AND
	opcode	<038fch,02080h,opn_and,OP_RMIMMSIGNED,2,0,0>	;AND
	opcode	<038fch,02880h,opn_sub,OP_RMIMMSIGNED,2,0,0>	;SUB
	opcode	<038feh,03080h,opn_xor,OP_RMIMMSIGNED,2,0,0>	;XOR
	opcode	<038fch,03080h,opn_xor,OP_RMIMMSIGNED,2,0,0>	;XOR
	opcode	<038fch,03880h,opn_cmp,OP_RMIMMSIGNED,2,0,0>	;CMP
	opcode	<0feh,084h,opn_test,OP_REGMOD,2,0,0>		;TEST
	opcode	<0feh,086h,opn_xchg,OP_REGRM,2,0,0>		;XCHG
	opcode	<0fch,088h,opn_mov,OP_REGRMREG,2,0,0>		;MOV
	opcode	<020fdh,08ch,opn_mov,OP_SEGRMSEG,2,0,0>		;MOV
	opcode	<0fdh,08ch,opn_mov,OP_SEGRMSEG,2,0,0>		;MOV
	opcode	<0ffh,08dh,opn_lea,OP_WORDREGRM,2,0,0>		;LEA
	opcode	<038ffh,08fh,opn_pop,OP_PUSHW,2,0,0>		;POP
	opcode	<0ffh,090h,opn_nop,OP_CODEONLY,1,0,0>		;NOP
	opcode	<0f8h,090h,opn_xchg,OP_ACCREG02,1,0,0>		;XCHG
	opcode	<0ffh,098h,opn_cbw,OP_CBW,1,0,0>		;CBW
        opcode  <0ffh,099h,opn_cwd,OP_CWD,1,0,0>                ;CWD
	opcode	<0ffh,09ah,opn_call,OP_SEGBRANCH,5,0,0>		;CALL
	opcode	<0ffh,09bh,opn_wait,OP_CODEONLY,1,0,0>		;WAIT
	opcode	<0ffh,09ch,opn_pushf,OP_INSWORDSIZE,1,0,0>	;PUSHF
	opcode	<0ffh,09dh,opn_popf,OP_INSWORDSIZE,1,0,0>	;POPF
	opcode	<0ffh,09eh,opn_sahf,OP_CODEONLY,1,0,0>		;SAHF
	opcode	<0ffh,09fh,opn_lahf,OP_CODEONLY,1,0,0>		;LAHF
	opcode	<0,0,0,0,0,0,0>					;terminator

group101xxxxx	label	byte
	opcode	<0feh,0a0h,opn_mov,OP_ACCABS,3,0,0>		;MOV
	opcode	<0feh,0a2h,opn_mov,OP_ABSACC,3,0,0>		;MOV
	opcode	<0ffh,0a5h,opn_movs,OP_INSWORDSIZE,1,0,0>	;MOVS
	opcode	<0ffh,0a7h,opn_cmps,OP_INSWORDSIZE,1,0,0>	;CMPS
	opcode	<0feh,0a8h,opn_test,OP_ACCIMM,1,0,0>		;TEST
	opcode	<0ffh,0abh,opn_stos,OP_INSWORDSIZE,1,0,0>	;STOS
	opcode	<0ffh,0adh,opn_lods,OP_INSWORDSIZE,1,0,0>	;LODS
	opcode	<0ffh,0afh,opn_scas,OP_INSWORDSIZE,1,0,0>	;SCAS
	opcode	<0ffh,0a4h,opn_movsb,OP_CODEONLY,1,0,0>		;MOVSB
	opcode	<0ffh,0a6h,opn_cmpsb,OP_CODEONLY,1,0,0>		;CMPSB
	opcode	<0ffh,0aah,opn_stosb,OP_CODEONLY,1,0,0>		;STOSB
	opcode	<0ffh,0ach,opn_lodsb,OP_CODEONLY,1,0,0>		;LODSB
	opcode	<0ffh,0aeh,opn_scasb,OP_CODEONLY,1,0,0>		;SCASB
	opcode	<0f0h,0b0h,opn_mov,OP_ACCIMMB3,1,0,0>		;MOV
	opcode	<0,0,0,0,0,0,0>					;terminator

group110xxxxx	label	byte
	opcode	<038feh,0c0h,opn_rol,OP_RMSHIFT,2,1,0>		;ROL
	opcode	<038feh,08c0h,opn_ror,OP_RMSHIFT,2,1,0>		;ROR
	opcode	<038feh,010c0h,opn_rcl,OP_RMSHIFT,2,1,0>	;RCL
	opcode	<038feh,018c0h,opn_rcr,OP_RMSHIFT,2,1,0>	;RCR
	opcode	<038feh,020c0h,opn_shl,OP_RMSHIFT,2,1,0>	;SHL
	opcode	<038feh,028c0h,opn_shr,OP_RMSHIFT,2,1,0>	;SHR
	opcode	<038feh,038c0h,opn_sar,OP_RMSHIFT,2,1,0>	;SAR
	opcode	<0ffh,0c2h,opn_ret,OP_RET,3,0,0>		;RET
	opcode	<0ffh,0c3h,opn_ret,OP_CODEONLY,1,0,0>		;RET
	opcode	<0ffh,0c4h,opn_les,OP_WORDREGRM,2,0,0>		;LES
	opcode	<0ffh,0c5h,opn_lds,OP_WORDREGRM,2,0,0>		;LDS
	opcode	<038feh,0c6h,opn_mov,OP_RMIMM,2,0,0>		;MOV
	opcode	<0ffh,0c8h,opn_enter,OP_ENTER,4,1,0>		;ENTER
	opcode	<0ffh,0cah,opn_retf,OP_RET,3,0,0>		;RETF
	opcode	<0ffh,0cbh,opn_retf,OP_CODEONLY,1,0,0>		;RETF
	opcode	<0ffh,0cch,opn_int,OP_INTR,1,0,0>		;INT
	opcode	<0ffh,0cdh,opn_int,OP_INTR,2,0,0>		;INT
	opcode	<0ffh,0ceh,opn_into,OP_CODEONLY,1,0,0>		;INTO
	opcode	<0ffh,0cfh,opn_iret,OP_CODEONLY,1,0,0>		;IRET
	opcode	<0ffh,0c9h,opn_leave,OP_CODEONLY,1,1,0>		;LEAVE
	opcode	<038fch,0d0h,opn_rol,OP_RMSHIFT,2,0,0>		;ROL
	opcode	<038fch,08d0h,opn_ror,OP_RMSHIFT,2,0,0>		;ROR
	opcode	<038fch,010d0h,opn_rcl,OP_RMSHIFT,2,0,0>	;RCL
	opcode	<038fch,018d0h,opn_rcr,OP_RMSHIFT,2,0,0>	;RCR
	opcode	<038fch,020d0h,opn_shl,OP_RMSHIFT,2,0,0>	;SHL
	opcode	<038fch,028d0h,opn_shr,OP_RMSHIFT,2,0,0>	;SHR
	opcode	<038fch,038d0h,opn_sar,OP_RMSHIFT,2,0,0>	;SAR
        opcode  <0ffh,0d4h,opn_aam,OP_AAM,1,0,0>                ;AAM
        opcode  <0ffh,0d5h,opn_aad,OP_AAM,1,0,0>                ;AAD
        opcode  <0ffh,0d6h,opn_salc,OP_CODEONLY,1,0,0>          ;SALC
        opcode  <0ffh,0d7h,opn_xlat,OP_XLAT,1,0,0>              ;XLAT
	opcode	<0,0,0,0,0,0,0>

group111xxxxx	label	byte
        opcode  <0ffh,0e0h,opn_loopnz,OP_LOOP,2,0,0>            ;LOOPNZ
        opcode  <0ffh,0e1h,opn_loopz,OP_LOOP,2,0,0>             ;LOOPZ
        opcode  <0ffh,0e2h,opn_loop,OP_LOOP,2,0,0>              ;LOOP
        opcode  <0ffh,0e3h,opn_jcxz,OP_LOOP,2,0,0>              ;JCXZ
	opcode	<0feh,0e4h,opn_in,OP_PORTACCPORT,2,0,0>		;IN
	opcode	<0feh,0e6h,opn_out,OP_PORTACCPORT,2,0,0>	;OUT
	opcode	<0ffh,0e8h,opn_call,OP_BRANCH,3,0,0>		;CALL
	opcode	<0ffh,0e9h,opn_jmp,OP_BRANCH,3,0,0>		;JMP
	opcode	<0ffh,0eah,opn_jmp,OP_SEGBRANCH,5,0,0>		;JMP
	opcode	<0ffh,0ebh,opn_jmp,OP_SHORTBRANCH,2,0,0>	;JMP
	opcode	<0feh,0ech,opn_in,OP_ACCDX,1,0,0>		;IN
	opcode	<0feh,0eeh,opn_out,OP_DXACC,1,0,0>		;OUT
;        opcode  <0ffh,0f0h,opn_lock,OP_CODEONLY,1,0,0>         ;LOCK
        opcode  <0ffh,0f1h,opn_icebp,OP_CODEONLY,1,0,0>         ;INT1
        opcode  <0ffh,0f2h,opn_repnz,OP_CODEONLY,1,0,0>         ;REPNZ
        opcode  <0ffh,0f3h,opn_repz,OP_CODEONLY,1,0,0>          ;REPZ
	opcode	<0ffh,0f4h,opn_hlt,OP_CODEONLY,1,0,0>		;HLT
	opcode	<0ffh,0f5h,opn_cmc,OP_CODEONLY,1,0,0>		;CMC
	opcode	<038feh,0f6h,opn_test,OP_RMIMM,2,0,0>		;TEST
	opcode	<038feh,010f6h,opn_not,OP_RM ,2,0,0>		;NOT
	opcode	<038feh,018f6h,opn_neg,OP_RM ,2,0,0>		;NEG
	opcode	<038feh,020f6h,opn_mul,OP_RM ,2,0,0>		;MUL
	opcode	<038feh,028f6h,opn_imul,OP_RM ,2,0,0>		;IMUL
	opcode	<038feh,030f6h,opn_div,OP_RM ,2,0,0>		;DIV
	opcode	<038feh,038f6h,opn_idiv,OP_RM ,2,0,0>		;IDIV
	opcode	<0ffh,0f8h,opn_clc,OP_CODEONLY,1,0,0>		;CLC
	opcode	<0ffh,0f9h,opn_stc,OP_CODEONLY,1,0,0>		;STC
	opcode	<0ffh,0fah,opn_cli,OP_CODEONLY,1,0,0>		;CLI
	opcode	<0ffh,0fbh,opn_sti,OP_CODEONLY,1,0,0>		;STI
	opcode	<0ffh,0fch,opn_cld,OP_CODEONLY,1,0,0>		;CLD
	opcode	<0ffh,0fdh,opn_std,OP_CODEONLY,1,0,0>		;STD
	opcode	<038feh,0feh,opn_inc,OP_RM ,2,0,0>		;INC
	opcode	<038feh,08feh,opn_dec,OP_RM ,2,0,0>		;DEC
	opcode	<038ffh,010ffh,opn_call,OP_RM ,2,0,0>		;CALL
	opcode	<038ffh,018ffh,opn_call,OP_FARRM ,2,0,0>	;CALL
	opcode	<038ffh,020ffh,opn_jmp,OP_RM ,2,0,0>		;JMP
	opcode	<038ffh,028ffh,opn_jmp,OP_FARRM ,2,0,0>		;JMP
	opcode	<038ffh,030ffh,opn_push,OP_PUSHW,2,0,0>		;PUSH
	opcode	<0,0,0,0,0,0,0>

groupx386	label	byte
        opcode  <0ffh,07,opn_loadall386,OP_CODEONLY,1,3,0>         ;LOADALL
        opcode  <0ffh,05,opn_loadall286,OP_CODEONLY,1,3,0>         ;LOADALL
	opcode	<0feh,0beh,opn_movsx,OP_MIXEDREGRM,2,3,0>	;MOVSX
	opcode	<0feh,0b6h,opn_movzx,OP_MIXEDREGRM,2,3,0>	;MOVZX
	opcode	<0f8h,0c8h,opn_bswap,OP_BSWAP,1,3,0>		;BSWAP
	opcode	<0f7h,0a0h,opn_push,OP_SEG35,1,3,0>		;PUSH
	opcode	<0f7h,0a1h,opn_pop,OP_SEG35,1,3,0>		;POP
	opcode	<0ffh,0b4h,opn_lfs,OP_WORDREGRM,2,3,0>		;LFS
	opcode	<0ffh,0b5h,opn_lgs,OP_WORDREGRM,2,3,0>		;LGS
	opcode	<0ffh,0b2h,opn_lss,OP_WORDREGRM,2,3,0>		;LSS
	opcode	<0ffh,06h,opn_clts,OP_CODEONLY,1,3,0>		;CLTS
	opcode	<0ffh,08h,opn_invd,OP_CODEONLY,1,3,0>		;INVD
	opcode	<0ffh,09h,opn_wbinvd,OP_CODEONLY,1,3,0>		;WBINVD
	opcode	<0ffh,0afh,opn_imul,OP_WORDREGRM,2,3,0>		;IMUL
	opcode	<0ffh,0a4h,opn_shld,OP_REGRMSHIFT,3,3,0>	;SHLD
	opcode	<0ffh,0a5h,opn_shld,OP_REGRMSHIFT,2,3,0>	;SHLD
	opcode	<0ffh,0ach,opn_shrd,OP_REGRMSHIFT,3,3,0>	;SHRD
	opcode	<0ffh,0adh,opn_shrd,OP_REGRMSHIFT,2,3,0>	;SHRD
	opcode	<0ffh,0bch,opn_bsf,OP_WORDREGRM,2,3,0>		;BSF
	opcode	<0ffh,0bdh,opn_bsr,OP_WORDREGRM,2,3,0>		;BSR
	opcode	<0ffh,0a3h,opn_bt,OP_WORDRMREG,2,3,0>		;BT
	opcode	<0ffh,0abh,opn_bts,OP_WORDRMREG,2,3,0>		;BTS
	opcode	<0ffh,0b3h,opn_btr,OP_WORDRMREG,2,3,0>		;BTR
	opcode	<0ffh,0bbh,opn_btc,OP_WORDRMREG,2,3,0>		;BTC
	opcode	<0ffh,040h,opn_cmovo,OP_WORDREGRM,2,3,0>	;CMOVO
	opcode	<0ffh,041h,opn_cmovno,OP_WORDREGRM,2,3,0>	;CMOVNO
	opcode	<0ffh,042h,opn_cmovb,OP_WORDREGRM,2,3,0>	;CMOVB
	opcode	<0ffh,043h,opn_cmovnb,OP_WORDREGRM,2,3,0>	;CMOVNB
	opcode	<0ffh,044h,opn_cmovz,OP_WORDREGRM,2,3,0>	;CMOVZ
	opcode	<0ffh,045h,opn_cmovnz,OP_WORDREGRM,2,3,0>	;CMOVNZ
	opcode	<0ffh,046h,opn_cmovbe,OP_WORDREGRM,2,3,0>	;CMOVBE
	opcode	<0ffh,047h,opn_cmova,OP_WORDREGRM,2,3,0>	;CMOVA
	opcode	<0ffh,048h,opn_cmovs,OP_WORDREGRM,2,3,0>	;CMOVS
	opcode	<0ffh,049h,opn_cmovns,OP_WORDREGRM,2,3,0>	;CMOVNS
	opcode	<0ffh,04ah,opn_cmovp,OP_WORDREGRM,2,3,0>	;CMOVP
	opcode	<0ffh,04bh,opn_cmovnp,OP_WORDREGRM,2,3,0>	;CMOVNP
	opcode	<0ffh,04ch,opn_cmovl,OP_WORDREGRM,2,3,0>	;CMOVL
	opcode	<0ffh,04dh,opn_cmovge,OP_WORDREGRM,2,3,0>	;CMOVGE
	opcode	<0ffh,04eh,opn_cmovle,OP_WORDREGRM,2,3,0>	;CMOVLE
	opcode	<0ffh,04fh,opn_cmovg,OP_WORDREGRM,2,3,0>	;CMOVG
	opcode	<038ffh,020bah,opn_bt,OP_BITNUM,3,3,0>		;BT
	opcode	<038ffh,028bah,opn_bts,OP_BITNUM,3,3,0>		;BTS
	opcode	<038ffh,030bah,opn_btr,OP_BITNUM,3,3,0>		;BTR
	opcode	<038ffh,038bah,opn_btc,OP_BITNUM,3,3,0>		;BTC
	opcode	<0ffh,0a7h,opn_ibts,OP_CODEONLY,1,3,0>		;IBTS
	opcode	<0ffh,0aah,opn_rsm,OP_CODEONLY,1,3,0>		;RSM
	opcode	<0ffh,0a6h,opn_xbts,OP_CODEONLY,1,3,0>		;XBTS
	opcode	<0ffh,0a2h,opn_cpuid,OP_CODEONLY,1,3,0>		;CPUID
	opcode	<0ffh,080h,opn_jo,OP_BRANCH,3,3,0>		;JO
	opcode	<0ffh,081h,opn_jno,OP_BRANCH,3,3,0>		;JNO
	opcode	<0ffh,082h,opn_jb,OP_BRANCH,3,3,0>		;JB
	opcode	<0ffh,083h,opn_jnb,OP_BRANCH,3,3,0>		;JNB
	opcode	<0ffh,084h,opn_jz,OP_BRANCH,3,3,0>		;JZ
	opcode	<0ffh,085h,opn_jnz,OP_BRANCH,3,3,0>		;JNZ
	opcode	<0ffh,086h,opn_jbe,OP_BRANCH,3,3,0>		;JBE
	opcode	<0ffh,087h,opn_ja,OP_BRANCH,3,3,0>		;JA
	opcode	<0ffh,088h,opn_js,OP_BRANCH,3,3,0>		;JS
	opcode	<0ffh,089h,opn_jns,OP_BRANCH,3,3,0>		;JNS
	opcode	<0ffh,08ah,opn_jp,OP_BRANCH,3,3,0>		;JP
	opcode	<0ffh,08bh,opn_jnp,OP_BRANCH,3,3,0>		;JNP
	opcode	<0ffh,08ch,opn_jl,OP_BRANCH,3,3,0>		;JL
	opcode	<0ffh,08dh,opn_jge,OP_BRANCH,3,3,0>		;JGE
	opcode	<0ffh,08eh,opn_jle,OP_BRANCH,3,3,0>		;JLE
	opcode	<0ffh,08fh,opn_jg,OP_BRANCH,3,3,0>		;JG
        opcode  <0ffh,031h,opn_rdtsc,OP_CODEONLY,1,3,0>         ;RDTSC
        opcode  <0ffh,033h,opn_rdpmc,OP_CODEONLY,1,3,0>         ;RDPMC
	opcode	<0ffh,032h,opn_rdmsr,OP_CODEONLY,1,3,0>		;RDMSR
	opcode	<0ffh,030h,opn_wrmsr,OP_CODEONLY,1,3,0>		;WRMSR
        opcode  <038ffh,000aeh,opn_fxsave,OP_FLOATNOPTR,2,3,0>  ;FXSAVE
        opcode  <038ffh,008aeh,opn_fxrstor,OP_FLOATNOPTR,2,3,0>  ;FXSAVE
        opcode  <038ffh,090h,opn_seto,OP_SETS ,2,3,0>     ;SETO
        opcode  <038ffh,091h,opn_setno,OP_SETS ,2,3,0>    ;SETNO
        opcode  <038ffh,092h,opn_setb,OP_SETS ,2,3,0>     ;SETB
        opcode  <038ffh,093h,opn_setnb,OP_SETS ,2,3,0>    ;SETNB
        opcode  <038ffh,094h,opn_setz,OP_SETS ,2,3,0>     ;SETZ
        opcode  <038ffh,095h,opn_setnz,OP_SETS ,2,3,0>    ;SETNZ
        opcode  <038ffh,096h,opn_setbe,OP_SETS ,2,3,0>    ;SETBE
        opcode  <038ffh,097h,opn_seta,OP_SETS ,2,3,0>     ;SETA
        opcode  <038ffh,098h,opn_sets,OP_SETS ,2,3,0>     ;SETS
        opcode  <038ffh,099h,opn_setns,OP_SETS ,2,3,0>    ;SETNS
        opcode  <038ffh,09ah,opn_setp,OP_SETS ,2,3,0>     ;SETP
        opcode  <038ffh,09bh,opn_setnp,OP_SETS ,2,3,0>    ;SETNP
        opcode  <038ffh,09ch,opn_setl,OP_SETS ,2,3,0>     ;SETL
        opcode  <038ffh,09dh,opn_setge,OP_SETS ,2,3,0>    ;SETGE
        opcode  <038ffh,09eh,opn_setle,OP_SETS ,2,3,0>    ;SETLE
        opcode  <038ffh,09fh,opn_setg,OP_SETS ,2,3,0>     ;SETG
	opcode	<0feh,0c0h,opn_xadd,OP_BYTERMREG,2,3,0>		;XADD
	opcode	<0feh,0b0h,opn_cmpxchg,OP_BYTERMREG,2,3,0>	;CMPXCHG
	opcode	<0c0fdh,0c020h,opn_mov,OP_386REG,2,3,0>		;MOV
	opcode	<0c0fdh,0c021h,opn_mov,OP_386REG,2,3,0>		;MOV
	opcode	<0c0fdh,0c024h,opn_mov,OP_386REG,2,3,0>		;MOV
	opcode	<0ffh,00bh,opn_ud2,OP_CODEONLY,1,3,0>		;UD2
	opcode	<0ffh,02h,opn_lar,OP_WORDREGRM,2,3,0>		;LAR
	opcode	<0ffh,03h,opn_lsl,OP_WORDREGRM,2,3,0>		;LSL
        opcode  <038ffh,01001h,opn_lgdt,OP_LGDT ,2,3,0>         ;LGDT
	opcode	<038ffh,01801h,opn_lidt,OP_NOSTRICTRM ,2,3,0>	;LIDT
	opcode	<038ffh,008c7h,opn_cmpxchg8b,OP_NOSTRICTRM,2,3,0> ;CMPXCHG8B
	opcode	<038ffh,01000h,opn_lldt,OP_NOSTRICTRM ,2,3,0>	;LIDT
	opcode	<038ffh,03001h,opn_lmsw,OP_NOSTRICTRM ,2,3,0>	;LMSW
	opcode	<038ffh,01800h,opn_ltr,OP_NOSTRICTRM ,2,3,0>	;LTR
        opcode  <038ffh,01h,opn_sgdt,OP_LGDT ,2,3,0>            ;SGDT
	opcode	<038ffh,0801h,opn_sidt,OP_NOSTRICTRM ,2,3,0>	;SIDT
	opcode	<038ffh,00h,opn_sldt,OP_NOSTRICTRM ,2,3,0>	;SLDT
	opcode	<038ffh,02001h,opn_smsw,OP_NOSTRICTRM ,2,3,0>	;SMSW
	opcode	<038ffh,0800h,opn_str,OP_NOSTRICTRM ,2,3,0>	;STR
	opcode	<038ffh,02000h,opn_verr,OP_NOSTRICTRM ,2,3,0>	;VERR
	opcode	<038ffh,02800h,opn_verw,OP_NOSTRICTRM ,2,3,0>	;VERW
;; mmx stuff here
        opcode <0ffh,77h,opn_emms,OP_CODEONLY,1,3,0>
        opcode <0ffh,7eh,opn_movd,OP_MMXMOVDST,2,3,0>
        opcode <0ffh,6eh,opn_movd,OP_MMXMOVDLD,2,3,0>
        opcode <0ffh,7fh,opn_movq,OP_MMXMOVQST,2,3,0>
        opcode <0ffh,6fh,opn_movq,OP_MMXMOVQLD,2,3,0>
        opcode <0ffh,6bh,opn_packssdw,OP_MMXSTD,2,3,0>
        opcode <0ffh,63h,opn_packsswb,OP_MMXSTD,2,3,0>
        opcode <0ffh,67h,opn_packuswb,OP_MMXSTD,2,3,0>
        opcode <0ffh,0fch,opn_paddb,OP_MMXSTD,2,3,0>
        opcode <0ffh,0feh,opn_paddd,OP_MMXSTD,2,3,0>
        opcode <0ffh,0ech,opn_paddsb,OP_MMXSTD,2,3,0>
        opcode <0ffh,0edh,opn_paddsw,OP_MMXSTD,2,3,0>
        opcode <0ffh,0dch,opn_paddusb,OP_MMXSTD,2,3,0>
        opcode <0ffh,0ddh,opn_paddusw,OP_MMXSTD,2,3,0>
        opcode <0ffh,0fdh,opn_paddw,OP_MMXSTD,2,3,0>
        opcode <0ffh,0dbh,opn_pand,OP_MMXSTD,2,3,0>
        opcode <0ffh,0dfh,opn_pandn,OP_MMXSTD,2,3,0>
        opcode <0ffh,74h,opn_pcmpeqb,OP_MMXSTD,2,3,0>
        opcode <0ffh,76h,opn_pcmpeqd,OP_MMXSTD,2,3,0>
        opcode <0ffh,75h,opn_pcmpeqw,OP_MMXSTD,2,3,0>
        opcode <0ffh,64h,opn_pcmpgtb,OP_MMXSTD,2,3,0>
        opcode <0ffh,66h,opn_pcmpgtd,OP_MMXSTD,2,3,0>
        opcode <0ffh,65h,opn_pcmpgtw,OP_MMXSTD,2,3,0>
        opcode <0ffh,0f5h,opn_pmaddwd,OP_MMXSTD,2,3,0>
        opcode <0ffh,0e5h,opn_pmulhw,OP_MMXSTD,2,3,0>
        opcode <0ffh,0d5h,opn_pmullw,OP_MMXSTD,2,3,0>
        opcode <0ffh,0ebh,opn_por,OP_MMXSTD,2,3,0>
        opcode <0ffh,0f2h,opn_pslld,OP_MMXSTD,2,3,0>
        opcode <0ffh,0f3h,opn_psllq,OP_MMXSTD,2,3,0>
        opcode <0ffh,0f1h,opn_psllw,OP_MMXSTD,2,3,0>
        opcode <0ffh,0e2h,opn_psrad,OP_MMXSTD,2,3,0>
        opcode <0ffh,0e1h,opn_psraw,OP_MMXSTD,2,3,0>
        opcode <0ffh,0d2h,opn_psrld,OP_MMXSTD,2,3,0>
        opcode <0ffh,0d3h,opn_psrlq,OP_MMXSTD,2,3,0>
        opcode <0ffh,0d1h,opn_psrlw,OP_MMXSTD,2,3,0>
        opcode <038ffh,03072h,opn_pslld,OP_MMXSHIFT,2,3,0>
        opcode <038ffh,03073h,opn_psllq,OP_MMXSHIFT,2,3,0>
        opcode <038ffh,03071h,opn_psllw,OP_MMXSHIFT,2,3,0>
        opcode <038ffh,02072h,opn_psrad,OP_MMXSHIFT,2,3,0>
        opcode <038ffh,02071h,opn_psraw,OP_MMXSHIFT,2,3,0>
        opcode <038ffh,01072h,opn_psrld,OP_MMXSHIFT,2,3,0>
        opcode <038ffh,01073h,opn_psrlq,OP_MMXSHIFT,2,3,0>
        opcode <038ffh,01071h,opn_psrlw,OP_MMXSHIFT,2,3,0>
        opcode <0ffh,0f8h,opn_psubb,OP_MMXSTD,2,3,0>
        opcode <0ffh,0fah,opn_psubd,OP_MMXSTD,2,3,0>
        opcode <0ffh,0e8h,opn_psubsb,OP_MMXSTD,2,3,0>
        opcode <0ffh,0e9h,opn_psubsw,OP_MMXSTD,2,3,0>
        opcode <0ffh,0d8h,opn_psubusb,OP_MMXSTD,2,3,0>
        opcode <0ffh,0d9h,opn_psubusw,OP_MMXSTD,2,3,0>
        opcode <0ffh,0f9h,opn_psubw,OP_MMXSTD,2,3,0>
        opcode <0ffh,68h,opn_punpckhbw,OP_MMXSTD,2,3,0>
        opcode <0ffh,69h,opn_punpckhwd,OP_MMXSTD,2,3,0>
        opcode <0ffh,6ah,opn_punpckhdq,OP_MMXSTD,2,3,0>
        opcode <0ffh,60h,opn_punpcklbw,OP_MMXSTD,2,3,0>
        opcode <0ffh,61h,opn_punpcklwd,OP_MMXSTD,2,3,0>
        opcode <0ffh,62h,opn_punpckldq,OP_MMXSTD,2,3,0>
        opcode <0ffh,0efh,opn_pxor,OP_MMXSTD,2,3,0>

	opcode	<0,0,0,0,0,0,0>

;/* single byte commands */

floats	label	byte
	opcode	<0ffffh,0d0d9h,opn_fnop,OP_CODEONLY,2,0,0>	;FNOP
	opcode	<0ffffh,0e0d9h,opn_fchs,OP_CODEONLY,2,0,0>	;FCHS
	opcode	<0ffffh,0e1d9h,opn_fabs,OP_CODEONLY,2,0,0>	;FABS
	opcode	<0ffffh,0e4d9h,opn_ftst,OP_CODEONLY,2,0,0>	;FTST
	opcode	<0ffffh,0e5d9h,opn_fxam,OP_CODEONLY,2,0,0>	;FXAM
	opcode	<0ffffh,0e8d9h,opn_fld1,OP_CODEONLY,2,0,0>	;FLD1
	opcode	<0ffffh,0e9d9h,opn_fldl2t,OP_CODEONLY,2,0,0>	;FLDL2T
	opcode	<0ffffh,0ead9h,opn_fldl2e,OP_CODEONLY,2,0,0>	;FLDL2E
	opcode	<0ffffh,0ebd9h,opn_fldpi,OP_CODEONLY,2,0,0>	;FLDPI
	opcode	<0ffffh,0ecd9h,opn_fldlg2,OP_CODEONLY,2,0,0>	;FLDLG2
	opcode	<0ffffh,0edd9h,opn_fldln2,OP_CODEONLY,2,0,0>	;FLDLN2
	opcode	<0ffffh,0eed9h,opn_fldz,OP_CODEONLY,2,0,0>	;FLDZ
	opcode	<0ffffh,0f0d9h,opn_f2xm1,OP_CODEONLY,2,0,0>	;F2XM1
	opcode	<0ffffh,0f1d9h,opn_fyl2x,OP_CODEONLY,2,0,0>	;FYL2X
	opcode	<0ffffh,0f2d9h,opn_fptan,OP_CODEONLY,2,0,0>	;FPTAN
	opcode	<0ffffh,0f3d9h,opn_fpatan,OP_CODEONLY,2,0,0>	;FPATAN
	opcode	<0ffffh,0f5d9h,opn_fprem1,OP_CODEONLY,2,1,0>	;FPREM1
	opcode	<0ffffh,0f4d9h,opn_fxtract,OP_CODEONLY,2,0,0>	;FXTRACT
	opcode	<0ffffh,0f6d9h,opn_fdecstp,OP_CODEONLY,2,0,0>	;FDECSTP
	opcode	<0ffffh,0f7d9h,opn_fincstp,OP_CODEONLY,2,0,0>	;FINCSTP
	opcode	<0ffffh,0f8d9h,opn_fprem,OP_CODEONLY,2,0,0>	;FPREM
	opcode	<0ffffh,0f9d9h,opn_fyl2xp1,OP_CODEONLY,2,0,0>	;FYL2XP1
	opcode	<0ffffh,0fad9h,opn_fsqrt,OP_CODEONLY,2,0,0>	;FSQRT
	opcode	<0ffffh,0fbd9h,opn_fsincos,OP_CODEONLY,2,1,0>	;FSINCOS
	opcode	<0ffffh,0fcd9h,opn_frndint,OP_CODEONLY,2,0,0>	;FRNDINT
	opcode	<0ffffh,0fdd9h,opn_fscale,OP_CODEONLY,2,0,0>	;FSCALE
	opcode	<0ffffh,0fed9h,opn_fsin,OP_CODEONLY,2,1,0>	;FSIN
	opcode	<0ffffh,0ffd9h,opn_fcos,OP_CODEONLY,2,1,0>	;FCOS
	opcode	<0ffffh,0e9dah,opn_fucompp,OP_CODEONLY,2,1,0>	;FUCOMPP
	opcode	<0ffffh,0e0dbh,opn_feni,OP_CODEONLY,2,0,0>	;FENI
	opcode	<0ffffh,0e1dbh,opn_fdisi,OP_CODEONLY,2,0,0>	;FDISI
	opcode	<0ffffh,0e2dbh,opn_fclex,OP_CODEONLY,2,0,0>	;FCLEX
	opcode	<0ffffh,0e3dbh,opn_finit,OP_CODEONLY,2,0,0>	;FINIT
	opcode	<0ffffh,0e4dbh,opn_fsetpm,OP_CODEONLY,2,0,0>	;FSETPM
	opcode	<0ffffh,0d9deh,opn_fcompp,OP_CODEONLY,2,0,0>	;FCOMPP
	opcode	<0ffffh,0e0dfh,opn_fnstsw,OP_AX,2,0,0>		;FNSTSW


;  /* Group 1, RM 3 */

	opcode	<0f8ffh,0c0d9h,opn_fld,OP_FLD,2,0,0>		;FLD
	opcode	<0f8ffh,0c8d9h,opn_fxch,OP_FREGMAYBE,2,0,0>	;FXCH
	opcode	<0f8fbh,0d8d9h,opn_fstp,OP_FLD,2,0,0>		;FSTP
	opcode	<0c0ffh,0c0d9h,opn_esc,OP_ESC,2,0,0>		;ESC


;  /* Group 1, RM0-2 */

	opcode	<038ffh,020d9h,opn_fldenv,OP_FLOATNOPTR,2,0,0>	;FLDENV
	opcode	<038ffh,028d9h,opn_fldcw,OP_FLOATNOPTR,2,0,0>	;FLDCW
	opcode	<038ffh,030d9h,opn_fnstenv,OP_FLOATNOPTR,2,0,0>	;FNSTENV
	opcode	<038ffh,038d9h,opn_fnstcw,OP_FLOATNOPTR,2,0,0>	;FNSTCW
	

;  /* Group 5, RM3 */

	opcode	<0f8ffh,0c0ddh,opn_ffree,OP_FREG,2,0,0>		;FFREE
        opcode  <0f8ffh,0c8ddh,opn_fxch,OP_FREGMAYBE,2,0,0>     ;FXCH
	opcode	<0f8ffh,0d0ddh,opn_fst,OP_FST,2,0,0>		;FST
	opcode	<0f8ffh,0e0ddh,opn_fucom,OP_FREGMAYBE,2,1,0>	;FUCOM
	opcode	<0f8ffh,0e8ddh,opn_fucomp,OP_FREGMAYBE,2,1,0>	;FUCOMP

        opcode  <0f8ffh,0f0dbh,opn_fcomi,OP_FREG,2,1,0>         ;FCOM
        opcode  <0f8ffh,0c0dfh,opn_ffreep,OP_FREG,2,0,0>         ;FFREE
        opcode  <0f8ffh,0c8dfh,opn_fxch,OP_FREGMAYBE,2,0,0>     ;FXCH
        opcode  <0f8ffh,0d0dfh,opn_fst,OP_FLD,2,0,0>            ;FST
        opcode  <0f8ffh,0d8dfh,opn_fstp,OP_FLD,2,0,0>           ;FSTP
        opcode  <0f8ffh,0f0dfh,opn_fcomip,OP_FREG,2,1,0>        ;FCOM
        opcode  <0f8ffh,0e8dbh,opn_fucomi,OP_FREG,2,1,0>        ;FCOM
        opcode  <0f8ffh,0e8dfh,opn_fucomip,OP_FREG,2,1,0>       ;FCOM
        opcode  <0f8ffh,0c0dah,opn_fcmovb,OP_FREG,2,1,0>        ;FCOM
        opcode  <0f8ffh,0d0dah,opn_fcmovbe,OP_FREG,2,1,0>       ;FCOM
        opcode  <0f8ffh,0c8dah,opn_fcmove,OP_FREG,2,1,0>        ;FCOM
        opcode  <0f8ffh,0c0dbh,opn_fcmovnb,OP_FREG,2,1,0>       ;FCOM
        opcode  <0f8ffh,0d0dbh,opn_fcmovnbe,OP_FREG,2,1,0>      ;FCOM
        opcode  <0f8ffh,0c8dbh,opn_fcmovne,OP_FREG,2,1,0>       ;FCOM
        opcode  <0f8ffh,0d8dbh,opn_fcmovnu,OP_FREG,2,1,0>       ;FCOM
        opcode  <0f8ffh,0d8dah,opn_fcmovu,OP_FREG,2,1,0>        ;FCOM

        opcode  <0c0ffh,0c0ddh,opn_esc,OP_ESC,2,0,0>            ;ESC


;  /* Group 5, RM0-2 */

	opcode	<038ffh,020ddh,opn_frstor,OP_FLOATNOPTR,2,0,0>	;FRSTOR
	opcode	<038ffh,030ddh,opn_fnsave,OP_FLOATNOPTR,2,0,0>	;FNSAVE
	opcode	<038ffh,038ddh,opn_fnstsw,OP_FLOATNOPTR,2,0,0>	;FNSTSW


;  /* Group 3 & 7*/

	opcode	<0c0fbh,0c0dbh,opn_esc,OP_ESC,2,0,0>		;ESC
	opcode	<038ffh,028dbh,opn_fld,OP_FLD,2,0,0>		;FLD
	opcode	<038ffh,038dbh,opn_fstp,OP_FLD,2,0,0>		;FSTP


;  /* Group 7 */

	opcode	<038ffh,020dfh,opn_fbld,OP_FBLD,2,0,0>		;FBLD
	opcode	<038ffh,028dfh,opn_fild,OP_FILD,2,0,0>		;FILD
	opcode	<038ffh,030dfh,opn_fbstp,OP_FBLD,2,0,0>		;FBSTP
	opcode	<038ffh,038dfh,opn_fistp,OP_FIST,2,0,0>		;FISTP


;  /* Math, group 0,2,4,6 special RM 3*/

	opcode	<0c0ffh,0c0dah,opn_esc,OP_ESC,2,0,0>		;ESC
	opcode	<0f8ffh,0c0deh,opn_faddp,OP_FLOATMATHP,2,0,0>	;FADDP
	opcode	<0f8ffh,0c8deh,opn_fmulp,OP_FLOATMATHP,2,0,0>	;FMULP
	opcode	<0f8ffh,0d0deh,opn_fcomp,OP_FREG,2,0,0>		;RCOMP
	opcode	<0f8ffh,0d8deh,opn_esc,OP_ESC,2,0,0>		;ESC
	opcode	<0f8ffh,0e8deh,opn_fsubp,OP_FLOATMATHP,2,0,0>	;FSUBP
	opcode	<0f8ffh,0f8deh,opn_fdivp,OP_FLOATMATHP,2,0,0>	;FDIVP
	opcode	<0f8ffh,0e0deh,opn_fsubrp,OP_FLOATMATHP,2,0,0>	;FSUBRP
	opcode	<0f8ffh,0f0deh,opn_fdivrp,OP_FLOATMATHP,2,0,0>	;FDIVRP


;  /* Math, other */

	opcode	<038fbh,0d8h,opn_fadd,OP_FLOATMATH,2,0,0>	;FADD
	opcode	<038fbh,08d8h,opn_fmul,OP_FLOATMATH,2,0,0>	;FMUL
	opcode	<038fbh,010d8h,opn_fcom,OP_FLOATRM,2,0,0>	;FCOM
	opcode	<038fbh,018d8h,opn_fcomp,OP_FLOATRM,2,0,0>	;FCOMP
	opcode	<038ffh,020d8h,opn_fsub,OP_FLOATMATH,2,0,0>	;FSUB
	opcode	<0f8ffh,0e8dch,opn_fsub,OP_FLOATMATH,2,0,0>	;FSUB
	opcode	<038ffh,028dch,opn_fsubr,OP_FLOATMATH,2,0,0>	;FSUBR
	opcode	<038ffh,028d8h,opn_fsubr,OP_FLOATMATH,2,0,0>	;FSUBR
	opcode	<0f8ffh,0e0dch,opn_fsubr,OP_FLOATMATH,2,0,0>	;FSUBR
	opcode	<038ffh,020dch,opn_fsub,OP_FLOATMATH,2,0,0>	;FSUB
	opcode	<038ffh,030d8h,opn_fdiv,OP_FLOATMATH,2,0,0>	;FDIV
	opcode	<0f8ffh,0f8dch,opn_fdiv,OP_FLOATMATH,2,0,0>	;FDIV
	opcode	<038ffh,038dch,opn_fdivr,OP_FLOATMATH,2,0,0>	;FDIVR
	opcode	<038ffh,038d8h,opn_fdivr,OP_FLOATMATH,2,0,0>	;FDIVR
	opcode	<0f8ffh,0f0dch,opn_fdivr,OP_FLOATMATH,2,0,0>	;FDIVR
	opcode	<038ffh,030dch,opn_fdiv,OP_FLOATMATH,2,0,0>	;FDIV
	opcode	<038fbh,0dah,opn_fiadd,OP_FLOATIMATH,2,0,0>	;FIADD
	opcode	<038fbh,08dah,opn_fimul,OP_FLOATIMATH,2,0,0>	;FIMUL
	opcode	<038fbh,010dah,opn_ficom,OP_FLOATIMATH,2,0,0>	;FICOM
	opcode	<038fbh,018dah,opn_ficomp,OP_FLOATIMATH,2,0,0>	;FICOMP
	opcode	<038fbh,020dah,opn_fisub,OP_FLOATIMATH,2,0,0>	;FISUB
	opcode	<038fbh,028dah,opn_fisubr,OP_FLOATIMATH,2,0,0>	;FISUBR
	opcode	<038fbh,030dah,opn_fidiv,OP_FLOATIMATH,2,0,0>	;FIDIV
	opcode	<038fbh,038dah,opn_fidivr,OP_FLOATIMATH,2,0,0>	;FIDIVR


;  /* groups 1, 3, 5, 7 */
;  /* keep the follwing from going into error, RM3 */

	opcode	<0e0f9h,0c0d9h,opn_esc,OP_ESC,2,0,0>		;ESC
	opcode	<038fbh,0d9h,opn_fld,OP_FLD,2,0,0>		;FLD
	opcode	<038fbh,010d9h,opn_fst,OP_FST,2,0,0>		;FST
	opcode	<038fbh,018d9h,opn_fstp,OP_FLD,2,0,0>		;FSTP
	opcode	<038fbh,0dbh,opn_fild,OP_FILD,2,0,0>		;FILD
	opcode	<038fbh,010dbh,opn_fist,OP_FIST,2,0,0>		;FIST
	opcode	<038fbh,018dbh,opn_fistp,OP_FILD,2,0,0>		;FISTP


;  /* Catch- all */

	opcode	<0f8h,0d8h,opn_esc,OP_ESC,2,0,0>		;ESC
	opcode	<0,0,0,0,0,0,0>
;
; now comes a table used only by the assembler for various aliased
; names
;
synonymTable	label	word

        opcode  <0ffh,07,opn_loadall,OP_CODEONLY,1,3,0>         ;LOADALL
        opcode  <0ffh,0d6h,opn_setalc,OP_CODEONLY,1,0,0>        ;SALC
	opcode	<0ffh,0d7h,opn_xlatb,OP_CODEONLY,1,0,0>		;XLATB
        opcode  <0ffh,0e0h,opn_loopne,OP_LOOP,2,0,0>            ;LOOPNE
        opcode  <0ffh,0e1h,opn_loope,OP_LOOP,2,0,0>             ;LOOPE
        opcode  <0ffh,0e0h,opn_loopnew,OP_LOOP,2,0,0>           ;LOOPNE
        opcode  <0ffh,0e1h,opn_loopew,OP_LOOP,2,0,0>            ;LOOPE
        opcode  <0ffh,0e0h,opn_loopned,OP_LOOP,2,0,0>           ;LOOPNE
        opcode  <0ffh,0e1h,opn_looped,OP_LOOP,2,0,0>            ;LOOPE
        opcode  <0ffh,0e0h,opn_loopnzw,OP_LOOP,2,0,0>           ;LOOPNE
        opcode  <0ffh,0e1h,opn_loopzw,OP_LOOP,2,0,0>            ;LOOPE
        opcode  <0ffh,0e0h,opn_loopnzd,OP_LOOP,2,0,0>           ;LOOPNE
        opcode  <0ffh,0e1h,opn_loopzd,OP_LOOP,2,0,0>            ;LOOPE
        opcode  <0ffh,0e2h,opn_loopw,OP_LOOP,2,0,0>             ;LOOPE
        opcode  <0ffh,0e2h,opn_loopd,OP_LOOP,2,0,0>             ;LOOPE
        opcode  <0ffh,0e3h,opn_jcxzw,OP_LOOP,2,0,0>             ;JCXZ
        opcode  <0ffh,0e3h,opn_jcxzd,OP_LOOP,2,0,0>             ;JCXZ
        opcode  <0ffh,0e3h,opn_jecxz,OP_LOOP,2,0,0>             ;JECXZ
        opcode  <0ffh,060h,opn_pushad,OP_INSWORDSIZE,1,1,0>     ;PUSHAD
        opcode  <0ffh,061h,opn_popad,OP_INSWORDSIZE,1,1,0>      ;POPAD
        opcode  <0ffh,09ch,opn_pushfd,OP_INSWORDSIZE,1,0,0>     ;PUSHFD
        opcode  <0ffh,09dh,opn_popfd,OP_INSWORDSIZE,1,0,0>      ;POPFD
        opcode  <0ffh,060h,opn_pushaw,OP_INSWORDSIZE,1,1,0>        ;PUSHAW
        opcode  <0ffh,061h,opn_popaw,OP_INSWORDSIZE,1,1,0>         ;POPAW
        opcode  <0ffh,09ch,opn_pushfw,OP_INSWORDSIZE,1,0,0>        ;PUSHFW
        opcode  <0ffh,09dh,opn_popfw,OP_INSWORDSIZE,1,0,0>         ;POPFW
        opcode  <0ffh,0a5h,opn_movsw,OP_INSWORDSIZE,1,0,0>         ;MOVSW
        opcode  <0ffh,0a7h,opn_cmpsw,OP_INSWORDSIZE,1,0,0>         ;CMPSW
        opcode  <0ffh,0abh,opn_stosw,OP_INSWORDSIZE,1,0,0>         ;STOSW
        opcode  <0ffh,0adh,opn_lodsw,OP_INSWORDSIZE,1,0,0>         ;LODSW
        opcode  <0ffh,0afh,opn_scasw,OP_INSWORDSIZE,1,0,0>         ;SCASW
        opcode  <0ffh,0a5h,opn_movsd,OP_INSWORDSIZE,1,0,0>      ;MOVSD
        opcode  <0ffh,0a7h,opn_cmpsd,OP_INSWORDSIZE,1,0,0>      ;CMPSD
        opcode  <0ffh,0abh,opn_stosd,OP_INSWORDSIZE,1,0,0>      ;STOSD
        opcode  <0ffh,0adh,opn_lodsd,OP_INSWORDSIZE,1,0,0>      ;LODSD
        opcode  <0ffh,0afh,opn_scasd,OP_INSWORDSIZE,1,0,0>      ;SCASD
        opcode  <0ffh,06dh,opn_insw,OP_INSWORDSIZE,1,1,0>          ;INSW
        opcode  <0ffh,06dh,opn_insd,OP_INSWORDSIZE,1,1,0>       ;INSD
        opcode  <0ffh,06fh,opn_outsw,OP_INSWORDSIZE,1,1,0>         ;OUTSW
        opcode  <0ffh,06fh,opn_outsd,OP_INSWORDSIZE,1,1,0>      ;OUTSD
	opcode	<0ffh,072h,opn_jc,OP_SHORTBRANCH,2,0,0>		;JC
	opcode	<0ffh,082h,opn_jc,OP_BRANCH,2,3,0>		;JC
	opcode	<0ffh,072h,opn_jnae,OP_SHORTBRANCH,2,0,0>	;JNAE
	opcode	<0ffh,082h,opn_jnae,OP_BRANCH,2,3,0>		;JNAE
	opcode	<0ffh,073h,opn_jnc,OP_SHORTBRANCH,2,0,0>	;JNC
	opcode	<0ffh,083h,opn_jnc,OP_BRANCH,2,3,0>		;JNC
	opcode	<0ffh,073h,opn_jae,OP_SHORTBRANCH,2,0,0>	;JAE
	opcode	<0ffh,083h,opn_jae,OP_BRANCH,2,3,0>		;JAE
	opcode	<0ffh,074h,opn_je,OP_SHORTBRANCH,2,0,0>		;JE
	opcode	<0ffh,084h,opn_je,OP_BRANCH,2,3,0>		;JE
	opcode	<0ffh,075h,opn_jne,OP_SHORTBRANCH,2,0,0>	;JNE
	opcode	<0ffh,085h,opn_jne,OP_BRANCH,2,3,0>		;JNE
	opcode	<0ffh,076h,opn_jna,OP_SHORTBRANCH,2,0,0>	;JNA
	opcode	<0ffh,086h,opn_jna,OP_BRANCH,2,3,0>		;JNA
	opcode	<0ffh,077h,opn_jnbe,OP_SHORTBRANCH,2,0,0>	;JNBE
	opcode	<0ffh,087h,opn_jnbe,OP_BRANCH,2,3,0>		;JNBE
	opcode	<0ffh,07ah,opn_jpe,OP_SHORTBRANCH,2,0,0>	;JPE
	opcode	<0ffh,08ah,opn_jpe,OP_BRANCH,2,3,0>		;JPE
	opcode	<0ffh,07bh,opn_jpo,OP_SHORTBRANCH,2,0,0>	;JPO
	opcode	<0ffh,08bh,opn_jpo,OP_BRANCH,2,3,0>		;JPO
	opcode	<0ffh,07ch,opn_jnge,OP_SHORTBRANCH,2,0,0>	;JNGE
	opcode	<0ffh,08ch,opn_jnge,OP_BRANCH,2,3,0>		;JNGE
	opcode	<0ffh,07dh,opn_jnl,OP_SHORTBRANCH,2,0,0>	;JNL
	opcode	<0ffh,08dh,opn_jnl,OP_BRANCH,2,3,0>		;JNL
	opcode	<0ffh,07eh,opn_jng,OP_SHORTBRANCH,2,0,0>	;JNG
	opcode	<0ffh,08eh,opn_jng,OP_BRANCH,2,3,0>		;JNG
	opcode	<0ffh,07fh,opn_jnle,OP_SHORTBRANCH,2,0,0>	;JNLE
	opcode	<0ffh,08fh,opn_jnle,OP_BRANCH,2,3,0>		;JNLE
        opcode  <038ffh,092h,opn_setnae,OP_SETS ,2,3,0>   ;SETNAE
        opcode  <038ffh,092h,opn_setc,OP_SETS ,2,3,0>     ;SETC
        opcode  <038ffh,093h,opn_setnc,OP_SETS ,2,3,0>    ;SETNC
        opcode  <038ffh,093h,opn_setae,OP_SETS ,2,3,0>    ;SETAE
        opcode  <038ffh,094h,opn_sete,OP_SETS ,2,3,0>     ;SETE
        opcode  <038ffh,095h,opn_setne,OP_SETS ,2,3,0>    ;SETNE
        opcode  <038ffh,096h,opn_setna,OP_SETS ,2,3,0>    ;SETNA
        opcode  <038ffh,097h,opn_setnbe,OP_SETS ,2,3,0>   ;SETNBE
        opcode  <038ffh,09ah,opn_setpe,OP_SETS ,2,3,0>    ;SETPE
        opcode  <038ffh,09bh,opn_setpo,OP_SETS ,2,3,0>    ;SETPO
        opcode  <038ffh,09ch,opn_setnge,OP_SETS ,2,3,0>   ;SETNGE
        opcode  <038ffh,09dh,opn_setnl,OP_SETS ,2,3,0>    ;SETNL
        opcode  <038ffh,09eh,opn_setng,OP_SETS ,2,3,0>    ;SETNG
        opcode  <038ffh,09fh,opn_setnle,OP_SETS ,2,3,0>   ;SETNLE
	opcode	<0ffh,098h,opn_cwde,OP_OPSIZE1BYTE,1,0,0>	;CWDE
	opcode	<0ffh,099h,opn_cdq,OP_OPSIZE1BYTE,1,0,0>	;CDQ
	opcode	<0ffh,09bh,opn_fwait,OP_CODEONLY,1,0,0>		;FWAIT
	opcode	<0ffffh,00d1d8h,opn_fcom,OP_CODEONLY,2,0,0>	;FCOM
	opcode	<0ffffh,00d9d8h,opn_fcomp,OP_CODEONLY,2,0,0>	;FCOMP
	opcode	<0ffffh,00e1ddh,opn_fucom,OP_CODEONLY,2,0,0>	;FUCOM
	opcode	<0ffffh,00e9ddh,opn_fucomp,OP_CODEONLY,2,0,0>	;FUCOMP
	opcode	<0ffffh,00c9d9h,opn_fxch,OP_CODEONLY,2,0,0>	;FXCH
        opcode  <0ffh,0f1h,opn_int,OP_INTR,1,0,0>               ;INT1
	opcode	<0,0,0,0,0,0,0>


indexes dw group000xxxxx, group001xxxxx, group010xxxxx, group011xxxxx
	dw group100xxxxx, group101xxxxx, group110xxxxx, group111xxxxx

mnemonicMatchCount	dw	0
mnemonicMatchAddrTable	dw	16 DUP (0)
;
	.CODE
;
; find an opcode. FS:SI points to the current byte of code, which is assumed 
; to be the first byte of this opcode.
;  Oops, actually SI points to the first byte of the opcode PAST any 
;  override bytes
;OUTPUT: AX contains the opcode, BX points to the opcode structure for it
;	Apparently there is an option, which can be disabled, to permit
;	disassembling instructions found on the 386 and above. So if we find
;	an instruction and THEN find that this option is disabled, we
;	decide that we didn't find the instruction after all.
;	CY if not found
;
FindOpcode	PROC	
	mov	[x86pfx],0
	mov	bx,offset groupx386	; Assume it is an 0F opcode
	inc	esi			; Point to next byte
	cmp	BYTE PTR fs:[esi-1],0fh	; Is it 0F?
	jnz	short not0ftable  	; No, try another table
	or	[x86pfx],1		; yes, flag as a prefix byte
	jmp	gotable
not0ftable:
	mov	[x86pfx],0		; not the 0f prefix table
	dec	esi			; Else point back to first byte
	mov	bx,offset floats	; Assume floating
	movzx	eax,byte ptr fs:[esi]	; Get the opcode
	and	al,0f8h			; Apply the FLOAT mask
	cmp	al,0d8h			; Apply FLOAT compare
	jz	short gotable		; Yes, go look for opcode
	shr	al,5			; get top 3 bits of opcode
	mov	bx,indexes[EAX*2]	; use as WORD table index
gotable:
	test	WORD PTR [bx],-1	; See if at end of table
	jz	short noentry		; Yes, not found
	mov	ax,fs:[esi]		; Get the opcode
	and	ax,[bx + OPCODE.MSK]	; Mask it
	cmp	ax,[bx + OPCODE.COMPARE]; Compare with the compare value
	jz	short gotentry		; Quit if found
	add	bx,OPCODESIZE		; Else go to next entry
	jmp	gotable			;
gotentry:
	test	[Disassemble32Bit],1	;are 386+ instructions supported?
	jnz	okentry			;if so, we got it
	test	[bx + OPCODE.FLAGS],1	;else report not found
	jnz	noentry
okentry:
	clc				; Found, exit
	ret
noentry:
	stc				; Not found, exit
	ret
FindOpcode	ENDP	

;
; scan a table for matches with this opcode
; INPUT:Well, let's see...
;	SI appears to point to a mnemonic for an opcode, somewere in memory
;	DI appears to point to the beginning of a table of opcode structures
;	AX appears to contain the length of the mnemonic string at [si]
;	BX appears to contain some index, but the syntax confuses me.
;		for mnemonicMatchAddrTable, it is some even value which 
;			cannot exceed 1Eh or else mnemonicMatchAddrTable will 
;			overflow
;		for opcode.flags, it is apparently an offset from the top
;			of the data segment to the start of this opcode 
;			structure. It appears to hold BOTH OF THESE AT ONCE! 
;			HOW?
;		My best guess is that BX comes in as 0
;PROCESSING:
;	Compare the string pointed to by DS:SI with the mnemonic pointed
;	to by the current opcode structure pointed to in ES:DI. Each time
;	we get a string match, we store the address of the structure
;	containing the pointer to the matching string in a table.  No table
;	of opcode structures better have more than 10h matches, since there
;	is no check for this.
;
;OUTPUT: The mnemonicMatchAddrTable table contains some number of addresses 
;	of opcode structures, possibly 0.  My best guess is that the number 
;	of validentries in this table is found in (BX-2) SHR 1
;
;	
findMnemonicMatches	PROC
	test	word ptr [di],-1	; end of table?
	jz	nomorent
	mov	cx,ax			; get len passed in AX
	push	di			;save pointer to structure
	mov	di,[di+opcode.mnemonic]	; get mnemonic from structure
	push	si			;save pointer to found mnemonic
	repe	cmpsb			; scan for match
	pop	si			;restore pointers
	pop	di
	jnz	nomatch			; no match?
	test	[Disassemble32Bit],1	; yes match, check for 386 match
	jnz	okentrymatch
	test	[di + OPCODE.FLAGS],1	;see if 386+ instruction
	jnz	nomatch			; not allowing 386 opcodes
okentrymatch:
	mov	[bx+mnemonicMatchAddrTable],di	; match, put it in match tab
	add	bx,2
nomatch:
	add	di,OPCODESIZE		; next entry
	jmp	findMnemonicMatches
nomorent:
	ret
findMnemonicMatches	ENDP
;
; main opcode lookup outine
; INPUT: By implication at findMnemonicMatches, AX must contain the length of
;	the string being parsed, and SI points to a mnemonic string.
;	These registers must be preserved until at least after the last
;	call to findMnemonicMatches.
; OUTPUT: mnemonicMatCount contains the number of valid matches
;	mnemonicMatchAddrTable contains near pointers to the opcode
;	structures where we actually found the matches to the names
;
LookupOpName	PROC
	sub	bx,bx			;initial match count = 0
	mov	cx,8			;look through 8 tables
	mov	di,offset indexes	; match the main tabs
lp:
	push	di			;save pointer to indexes
	push	cx			;save table count
	mov	di,[di]			;find next table
	call	findMnemonicMatches 	;get match list
	pop	cx			;restore loop count
	pop	di			;and index pointer
	add	di,2			;goto next table pointer
	loop	lp			;for all tables

	mov	di,offset floats	; match the float tab
	call	findMnemonicMatches   	;and seach floats too
	mov	di,offset groupx386	; match the x386 tab (0F prefix)
	call	findMnemonicMatches   	;search that for matches
	mov	di,offset synonymTable	; match the assembly extras tab
	call	findMnemonicMatches   	;search synonyms

	shr	bx,1			;restore count of finds
	mov	[mnemonicMatchCount],bx	; and save count
	jnz	lox			;we found at least one match
	stc				; no match, error
lox:
	ret				; back to caller
LookupOpName	ENDP
END
