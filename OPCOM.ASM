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
; opcom.asm
;
; text for assembly/disassembly
;
include iwindow.inc
	;MASM MODE
	.model small
	.386p

	.data
; This is a table of mnemonics for the dissassembler
;
	public	opn_cwde
	public	opn_cdq
	public	opn_add
	public	opn_push
	public	opn_pop
	public	opn_or
	public	opn_adc
	public	opn_sbb
	public	opn_and
	public	opn_daa
	public	opn_sub
	public	opn_das
	public	opn_xor
	public	opn_aaa
	public	opn_cmp
	public	opn_aas
	public	opn_inc
	public	opn_dec
	public	opn_pusha
	public	opn_popa
	public	opn_pushad
	public	opn_popad
        public  opn_pushaw
        public  opn_popaw
	public	opn_bound
	public	opn_arpl
	public	opn_imul
	public	opn_insb
	public	opn_ins
	public	opn_outsb
	public	opn_outs
	public	opn_insd
	public	opn_outsd
	public	opn_insw
	public	opn_outsw
	public	opn_jo
	public	opn_jno
	public	opn_jc
	public	opn_jnae
	public	opn_jnc
	public	opn_jna
	public	opn_jnbe
	public	opn_jae
	public	opn_je
	public	opn_jne
	public	opn_jpe
	public	opn_jpo
	public	opn_jnle
	public	opn_jnl
	public	opn_jnge
	public	opn_jng
	public	opn_jb
	public	opn_jnb
	public	opn_jz
	public	opn_jnz
	public	opn_jbe
	public	opn_ja
	public	opn_js
	public	opn_jns
	public	opn_jp
	public	opn_jnp
	public	opn_jl
	public	opn_jge
	public	opn_jle
	public	opn_jg
	public	opn_test
	public	opn_xchg
	public	opn_mov
	public	opn_lea
        public  opn_loadall
        public  opn_loadall386
        public  opn_loadall286
	public	opn_nop
	public	opn_cbw
	public	opn_cwd
	public	opn_call
	public	opn_wait
	public	opn_fwait
	public	opn_pushf
	public	opn_popf
	public	opn_pushfd
	public	opn_popfd
        public  opn_pushfw
        public  opn_popfw
	public	opn_sahf
	public	opn_lahf
	public	opn_movs
	public	opn_cmps
	public	opn_stos
	public	opn_lods
	public	opn_scas
	public	opn_movsb
	public	opn_cmpsb
	public	opn_stosb
	public	opn_lodsb
	public	opn_scasb
	public	opn_movsw
	public	opn_cmpsw
	public	opn_stosw
	public	opn_lodsw
	public	opn_scasw
	public	opn_movsd
	public	opn_cmpsd
	public	opn_stosd
	public	opn_lodsd
	public	opn_scasd
	public	opn_rol
	public	opn_ror
	public	opn_rcl
	public	opn_rcr
	public	opn_shl
	public	opn_shr
	public	opn_sar
	public	opn_ret
	public	opn_les
	public	opn_lds
	public	opn_enter
	public	opn_retf
	public	opn_int
        public  opn_icebp
	public	opn_into
	public	opn_iret
	public	opn_leave
	public	opn_aam
	public	opn_aad
	public	opn_xlat
	public	opn_xlatb
	public	opn_loopnz
	public	opn_loopz
	public	opn_loopne
	public	opn_loope
	public	opn_loop
        public  opn_loopnzw
        public  opn_loopzw
        public  opn_loopnew
        public  opn_loopew
        public  opn_loopw
        public  opn_loopnzd
        public  opn_loopzd
        public  opn_loopned
        public  opn_looped
        public  opn_loopd
	public	opn_jcxz
        public  opn_jcxzw
        public  opn_jcxzd
        public  opn_jecxz
	public	opn_in
	public	opn_out
	public	opn_jmp
	public	opn_lock
	public	opn_repnz
	public	opn_repz
	public	opn_hlt
	public	opn_cmc
	public	opn_not
	public	opn_neg
	public	opn_mul
	public	opn_div
	public	opn_idiv
	public	opn_clc
	public	opn_stc
	public	opn_cli
	public	opn_sti
	public	opn_cld
	public	opn_std
	public	opn_movsx
	public	opn_movzx
	public	opn_lfs
	public	opn_lgs
	public	opn_lss
	public	opn_clts
	public	opn_shld
	public	opn_shrd
	public	opn_bsf
	public	opn_bsr
	public	opn_bt
	public	opn_bts
	public	opn_btr
	public	opn_btc
	public	opn_ibts
	public	opn_xbts
        public  opn_salc
        public  opn_setalc
	public	opn_setc
	public	opn_setnae
	public	opn_setnc
	public	opn_setna
	public	opn_setnbe
	public	opn_setae
	public	opn_sete
	public	opn_setne
	public	opn_setpe
	public	opn_setpo
	public	opn_setnle
	public	opn_setnl
	public	opn_setnge
	public	opn_setng
	public	opn_seto
	public	opn_setno
	public	opn_setb
	public	opn_setnb
	public	opn_setz
	public	opn_setnz
	public	opn_setbe
	public	opn_seta
	public	opn_sets
	public	opn_setns
	public	opn_setp
	public	opn_setnp
	public	opn_setl
	public	opn_setge
	public	opn_setle
	public	opn_setg
	public	opn_lar
	public	opn_lsl
	public	opn_lgdt
	public	opn_lidt
	public	opn_lldt
	public	opn_lmsw
	public	opn_ltr
	public	opn_sgdt
	public	opn_sidt
	public	opn_sldt
	public	opn_smsw
	public	opn_str
	public	opn_verr
	public	opn_verw
	public	opn_fnop
	public	opn_fchs
	public	opn_fabs
	public	opn_ftst
	public	opn_fxam
	public	opn_fld1
	public	opn_fldl2t
	public	opn_fldl2e
	public	opn_fldpi
	public	opn_fldlg2
	public	opn_fldln2
	public	opn_fldz
	public	opn_f2xm1
	public	opn_fyl2x
	public	opn_fptan
	public	opn_fpatan
	public	opn_fprem1
	public	opn_fxtract
	public	opn_fdecstp
	public	opn_fincstp
	public	opn_fprem
	public	opn_fyl2xp1
	public	opn_fsqrt
	public	opn_fsincos
	public	opn_frndint
	public	opn_fscale
	public	opn_fsin
	public	opn_fcos
	public	opn_fucompp
	public	opn_feni
	public	opn_fdisi
	public	opn_fclex
	public	opn_finit
	public	opn_fsetpm
	public	opn_fcompp
	public	opn_fld
	public	opn_fxch
	public	opn_fstp
	public	opn_esc
	public	opn_fldenv
	public	opn_fldcw
	public	opn_fnstenv
	public	opn_fnstcw
	public	opn_ffree
        public  opn_ffreep
	public	opn_fst
	public	opn_fucom
	public	opn_fucomp
	public	opn_frstor
	public	opn_fnsave
	public	opn_fnstsw
	public	opn_fbld
	public	opn_fild
	public	opn_fbstp
	public	opn_fistp
	public	opn_fmul
	public	opn_fcom
	public	opn_fsub
	public	opn_fsubr
	public	opn_fdiv
	public	opn_fdivr
	public	opn_fadd
	public	opn_fcomp
	public	opn_fiadd
	public	opn_fimul
	public	opn_ficom
	public	opn_ficomp
	public	opn_fisub
	public	opn_fisubr
	public	opn_fidiv
	public	opn_fidivr
	public	opn_fist
	public	opn_faddp
	public	opn_fmulp
	public	opn_fdivp
	public	opn_fdivrp
	public	opn_fsubp
	public	opn_fsubrp
	public	opn_wbinvd
	public	opn_invd
	public	opn_bswap
	public	regs
	public	psegs
	public	crreg
	public	drreg
	public	trreg
	public	sudreg
	public	scales
	public	stalone
	public	st_repz
	public	st_repnz
        public  st_lock
	public	base0
	public	base1
	public	base2
	public	base3
	public	base4
	public	base5
	public	base6
	public	base7
	public	st0
	public	st1
	public	st2
	public	st3
	public	st4
	public	st5
	public	byptr
	public	dwptr
	public	woptr
	public	theptr
        public  pbptr
        public  fwptr
	public	stsreg
        public  mmxreg
	public	based
	public	sts
	public	opn_cmovo
	public	opn_cmovno
	public	opn_cmovb
	public	opn_cmovnb
	public	opn_cmovz
	public	opn_cmovnz
	public	opn_cmovbe
	public	opn_cmova
	public	opn_cmovs
	public	opn_cmovns
	public	opn_cmovp
	public	opn_cmovnp
	public	opn_cmovl
	public	opn_cmovge
	public	opn_cmovle
	public	opn_cmovg
	PUBLIC  opn_cmpxchg
	PUBLIC  opn_cmpxchg8b
	PUBLIC	opn_cpuid
	PUBLIC	opn_rdmsr
	PUBLIC	opn_rdtsc
	PUBLIC	opn_rdpmc
	PUBLIC	opn_rsm
	PUBLIC	opn_ud2
	PUBLIC	opn_wrmsr
	PUBLIC	opn_xadd
        public opn_emms
        public opn_movd
        public opn_movq
        public opn_packssdw
        public opn_packsswb
        public opn_packuswb
        public opn_paddb
        public opn_paddd
        public opn_paddsb
        public opn_paddsw
        public opn_paddusb
        public opn_paddusw
        public opn_paddw
        public opn_pand
        public opn_pandn
        public opn_pcmpeqb
        public opn_pcmpeqd
        public opn_pcmpeqw
        public opn_pcmpgtb
        public opn_pcmpgtd
        public opn_pcmpgtw
        public opn_pmaddwd
        public opn_pmulhw
        public opn_pmullw
        public opn_por
        public opn_pslld
        public opn_psllq
        public opn_psllw
        public opn_psrad
        public opn_psraw
        public opn_psrld
        public opn_psrlq
        public opn_psrlw
        public opn_psubb
        public opn_psubd
        public opn_psubsb
        public opn_psubsw
        public opn_psubusb
        public opn_psubusw
        public opn_psubw
        public opn_punpckhbw
        public opn_punpckhwd
        public opn_punpckhdq
        public opn_punpcklbw
        public opn_punpcklwd
        public opn_punpckldq
        public opn_pxor
        public opn_fcomi
        public opn_fcomip
        public opn_fucomi
        public opn_fucomip
        public opn_fxsave
        public opn_fxrstor
        public opn_fcmovb
        public opn_fcmovbe
        public opn_fcmove
        public opn_fcmovnb
        public opn_fcmovnbe
        public opn_fcmovne
        public opn_fcmovnu
        public opn_fcmovu
        public opn_farptr
opn_cwde db	"cwde",0
opn_cdq	db	"cdq",0
opn_add	db	"add",0
opn_push	db	"push",0
opn_pop	db	"pop",0
opn_or	db	"or",0
opn_adc	db	"adc",0
opn_sbb	db	"sbb",0
opn_and	db	"and",0
opn_daa	db	"daa",0
opn_sub	db	"sub",0
opn_das	db	"das",0
opn_xor	db	"xor",0
opn_aaa	db	"aaa",0
opn_cmp	db	"cmp",0
opn_aas	db	"aas",0
opn_inc	db	"inc",0
opn_dec	db	"dec",0
opn_pusha	db	"pusha",0
opn_popa	db	"popa",0
opn_pushad	db	"pushad",0
opn_popad	db	"popad",0
opn_pushaw      db      "pushaw",0
opn_popaw       db      "popaw",0
opn_bound	db	"bound",0
opn_arpl	db	"arpl",0
opn_imul	db	"imul",0
opn_insb	db	"insb",0
opn_insw	db	"insw",0
opn_insd	db	"insd",0
opn_ins	db	"ins",0
opn_outsb	db	"outsb",0
opn_outsw	db	"outsw",0
opn_outsd	db	"outsd",0
opn_outs	db	"outs",0
opn_jc	db	"jc",0
opn_jnae	db	"jnae",0
opn_jnc	db	"jnc",0
opn_jna	db	"jna",0
opn_jnbe	db	"jnbe",0
opn_jae	db	"jae",0
opn_je	db	"je",0
opn_jne	db	"jne",0
opn_jpo	db	"jpo",0
opn_jpe	db	"jpe",0
opn_jnle	db	"jnle",0
opn_jnl	db	"jnl",0
opn_jnge	db	"jnge",0
opn_jng	db	"jng",0
opn_jo	db	"jo",0
opn_jno	db	"jno",0
opn_jb	db	"jb",0
opn_jnb	db	"jnb",0
opn_jz	db	"jz",0
opn_jnz	db	"jnz",0
opn_jbe	db	"jbe",0
opn_ja	db	"ja",0
opn_js	db	"js",0
opn_jns	db	"jns",0
opn_jp	db	"jp",0
opn_jnp	db	"jnp",0
opn_jl	db	"jl",0
opn_jge	db	"jge",0
opn_jle	db	"jle",0
opn_jg	db	"jg",0
opn_test	db	"test",0
opn_xchg	db	"xchg",0
opn_mov	db	"mov",0
opn_lea	db	"lea",0
opn_loadall     db "loadall",0
opn_loadall386     db "loadall386",0
opn_loadall286     db "loadall286",0
opn_nop	db	"nop",0
opn_cbw	db	"cbw",0
opn_cwd	db	"cwd",0
opn_call	db	"call",0
opn_wait	db	"wait",0
opn_fwait	db	"fwait",0
opn_pushf	db	"pushf",0
opn_popf	db	"popf",0
opn_pushfd	db	"pushfd",0
opn_popfd	db	"popfd",0
opn_pushfw      db      "pushfw",0
opn_popfw       db      "popfw",0
opn_sahf	db	"sahf",0
opn_lahf	db	"lahf",0
opn_movs	db	"movs",0
opn_cmps	db	"cmps",0
opn_stos	db	"stos",0
opn_lods	db	"lods",0
opn_scas	db	"scas",0
opn_movsb	db	"movsb",0
opn_cmpsb	db	"cmpsb",0
opn_stosb	db	"stosb",0
opn_lodsb	db	"lodsb",0
opn_scasb	db	"scasb",0
opn_movsw	db	"movsw",0
opn_cmpsw	db	"cmpsw",0
opn_stosw	db	"stosw",0
opn_lodsw	db	"lodsw",0
opn_scasw	db	"scasw",0
opn_movsd	db	"movsd",0
opn_cmpsd	db	"cmpsd",0
opn_stosd	db	"stosd",0
opn_lodsd	db	"lodsd",0
opn_scasd	db	"scasd",0
opn_rol	db	"rol",0
opn_ror	db	"ror",0
opn_rcl	db	"rcl",0
opn_rcr	db	"rcr",0
opn_shl	db	"shl",0
opn_shr	db	"shr",0
opn_sar	db	"sar",0
opn_ret	db	"ret",0
opn_les	db	"les",0
opn_lds	db	"lds",0
opn_enter	db	"enter",0
opn_retf	db	"retf",0
opn_int	db	"int",0
opn_icebp db    "icebp",0
opn_into	db	"into",0
opn_iret	db	"iret",0
opn_leave	db	"leave",0
opn_aam	db	"aam",0
opn_aad	db	"aad",0
opn_xlat	db	"xlat",0
opn_xlatb	db	"xlatb",0
opn_loopnz	db	"loopnz",0
opn_loopz	db	"loopz",0
opn_loopne	db	"loopne",0
opn_loope	db	"loope",0
opn_loop	db	"loop",0
opn_loopnzw     db      "loopnzw",0
opn_loopzw      db      "loopzw",0
opn_loopnew     db      "loopnew",0
opn_loopew      db      "loopew",0
opn_loopw       db      "loopw",0
opn_loopnzd     db      "loopnzd",0
opn_loopzd      db      "loopzd",0
opn_loopned     db      "loopned",0
opn_looped      db      "looped",0
opn_loopd       db      "loopd",0
opn_jcxz	db	"jcxz",0
opn_jcxzw       db      "jcxzw",0
opn_jcxzd       db      "jcxzd",0
opn_jecxz       db      "jecxz",0
opn_in	db	"in",0
opn_out	db	"out",0
opn_jmp	db	"jmp",0
opn_lock	db	"lock",0
opn_repnz	db	"repnz",0
opn_repz	db	"repz",0
opn_hlt	db	"hlt",0
opn_cmc	db	"cmc",0
opn_not	db	"not",0
opn_neg	db	"neg",0
opn_mul	db	"mul",0
opn_div	db	"div",0
opn_idiv	db	"idiv",0
opn_clc	db	"clc",0
opn_stc	db	"stc",0
opn_cli	db	"cli",0
opn_sti	db	"sti",0
opn_cld	db	"cld",0
opn_std	db	"std",0
opn_movsx	db	"movsx",0
opn_movzx	db	"movzx",0
opn_lfs	db	"lfs",0
opn_lgs	db	"lgs",0
opn_lss	db	"lss",0
opn_clts	db	"clts",0
opn_shld	db	"shld",0
opn_shrd	db	"shrd",0
opn_bsf	db	"bsf",0
opn_bsr	db	"bsr",0
opn_bt	db	"bt",0
opn_bts	db	"bts",0
opn_btr	db	"btr",0
opn_btc	db	"btc",0
opn_ibts	db	"ibts",0
opn_xbts	db	"xbts",0
opn_salc        db      "salc",0
opn_setalc      db      "setalc",0
opn_setc	db	"setc",0
opn_setnae	db	"setnae",0
opn_setnc	db	"setnc",0
opn_setna	db	"setna",0
opn_setnbe	db	"setnbe",0
opn_setae	db	"setae",0
opn_sete	db	"sete",0
opn_setne	db	"setne",0
opn_setpo	db	"setpo",0
opn_setpe	db	"setpe",0
opn_setnle	db	"setnle",0
opn_setnl	db	"setnl",0
opn_setnge	db	"setnge",0
opn_setng	db	"setng",0
opn_seto	db	"seto",0
opn_setno	db	"setno",0
opn_setb	db	"setb",0
opn_setnb	db	"setnb",0
opn_setz	db	"setz",0
opn_setnz	db	"setnz",0
opn_setbe	db	"setbe",0
opn_seta	db	"seta",0
opn_sets	db	"sets",0
opn_setns	db	"setns",0
opn_setp	db	"setp",0
opn_setnp	db	"setnp",0
opn_setl	db	"setl",0
opn_setge	db	"setge",0
opn_setle	db	"setle",0
opn_setg	db	"setg",0
opn_lar	db	"lar",0
opn_lsl	db	"lsl",0
opn_lgdt	db	"lgdt",0
opn_lidt	db	"lidt",0
opn_lldt	db	"lldt",0
opn_lmsw	db	"lmsw",0
opn_ltr	db	"ltr",0
opn_sgdt	db	"sgdt",0
opn_sidt	db	"sidt",0
opn_sldt	db	"sldt",0
opn_smsw	db	"smsw",0
opn_str	db	"str",0
opn_verr	db	"verr",0
opn_verw	db	"verw",0
opn_fnop	db	"fnop",0
opn_fchs	db	"fchs",0
opn_fabs	db	"fabs",0
opn_ftst	db	"ftst",0
opn_fxam	db	"fxam",0
opn_fld1	db	"fld1",0
opn_fldl2t	db	"fldl2t",0
opn_fldl2e	db	"fldl2e",0
opn_fldpi	db	"fldpi",0
opn_fldlg2	db	"fldlg2",0
opn_fldln2	db	"fldln2",0
opn_fldz	db	"fldz",0
opn_f2xm1	db	"f2xm1",0
opn_fyl2x	db	"fyl2x",0
opn_fptan	db	"fptan",0
opn_fpatan	db	"fpatan",0
opn_fprem1	db	"fprem1",0
opn_fxtract	db	"fxtract",0
opn_fdecstp	db	"fdecstp",0
opn_fincstp	db	"fincstp",0
opn_fprem	db	"fprem",0
opn_fyl2xp1	db	"fyl2xp1",0
opn_fsqrt	db	"fsqrt",0
opn_fsincos	db	"fsincos",0
opn_frndint	db	"frndint",0
opn_fscale	db	"fscale",0
opn_fsin	db	"fsin",0
opn_fcos	db	"fcos",0
opn_fucompp	db	"fucompp",0
opn_feni	db	"feni",0
opn_fdisi	db	"fdisi",0
opn_fclex	db	"fnclex",0
opn_finit	db	"fninit",0
opn_fsetpm	db	"fsetpm",0
opn_fcompp	db	"fcompp",0
opn_fld	db	"fld",0
opn_fxch	db	"fxch",0
opn_fstp	db	"fstp",0
opn_esc	db	"esc",0
opn_fldenv	db	"fldenv",0
opn_fldcw	db	"fldcw",0
opn_fnstenv	db	"fnstenv",0
opn_fnstcw	db	"fnstcw",0
opn_ffree	db	"ffree",0
opn_ffreep       db     "ffreep",0
opn_fst	db	"fst",0
opn_fucom	db	"fucom",0
opn_fucomp	db	"fucomp",0
opn_frstor	db	"frstor",0
opn_fnsave	db	"fnsave",0
opn_fnstsw	db	"fnstsw",0
opn_fbld	db	"fbld",0
opn_fild	db	"fild",0
opn_fbstp	db	"fbstp",0
opn_fistp	db	"fistp",0
opn_fmul	db	"fmul",0
opn_fcom	db	"fcom",0
opn_fsub	db	"fsub",0
opn_fsubr	db	"fsubr",0
opn_fdiv	db	"fdiv",0
opn_fdivr	db	"fdivr",0
opn_fadd	db	"fadd",0
opn_fcomp	db	"fcomp",0
opn_fiadd	db	"fiadd",0
opn_fimul	db	"fimul",0
opn_ficom	db	"ficom",0
opn_ficomp	db	"ficomp",0
opn_fisub	db	"fisub",0
opn_fisubr	db	"fisubr",0
opn_fidiv	db	"fidiv",0
opn_fidivr	db	"fidivr",0
opn_fist	db	"fist",0
opn_faddp	db	"faddp",0
opn_fmulp	db	"fmulp",0
opn_fsubp	db	"fsubp",0
opn_fdivp	db	"fdivp",0
opn_fsubrp	db	"fsubrp",0
opn_fdivrp	db	"fdivrp",0
opn_wbinvd	db	"wb"
opn_invd	db	"invd",0
opn_bswap	db	"bswap",0
opn_cmovo	db	"cmovo",0
opn_cmovno	db	"cmovno",0
opn_cmovb	db	"cmovb",0
opn_cmovnb	db	"cmovnb",0
opn_cmovz	db	"cmovz",0
opn_cmovnz	db	"cmovnz",0
opn_cmovbe	db	"cmovbe",0
opn_cmova	db	"cmova",0
opn_cmovs	db	"cmovs",0
opn_cmovns	db	"cmovns",0
opn_cmovp	db	"cmovp",0
opn_cmovnp	db	"cmovnp",0
opn_cmovl	db	"cmovl",0
opn_cmovge	db	"cmovge",0
opn_cmovle	db	"cmovle",0
opn_cmovg	db	"cmovg",0
opn_cmpxchg	db	"cmpxchg",0
opn_cmpxchg8b	db	"cmpxchg8b",0
opn_cpuid	db	"cpuid",0
opn_rdmsr	db	"rdmsr",0
opn_rdpmc	db	"rdpmc",0
opn_rdtsc	db	"rdtsc",0
opn_rsm		db	"rsm",0
opn_ud2		db	"ud2",0
opn_wrmsr	db	"wrmsr",0
opn_xadd	db	"xadd",0
opn_emms	db	"emms",0
opn_movd        db      "movd",0
opn_movq        db      "movq",0
opn_packssdw	db	"packssdw",0
opn_packsswb	db	"packsswb",0
opn_packuswb	db	"packuswb",0
opn_paddb	db	"paddb",0
opn_paddd	db	"paddd",0
opn_paddsb	db	"paddsb",0
opn_paddsw	db	"paddsw",0
opn_paddusb	db	"paddusb",0
opn_paddusw	db	"paddusw",0
opn_paddw	db	"paddw",0
opn_pand	db	"pand",0
opn_pandn	db	"pandn",0
opn_pcmpeqb	db	"pcmpeqb",0
opn_pcmpeqd	db	"pcmpeqd",0
opn_pcmpeqw	db	"pcmpeqw",0
opn_pcmpgtb	db	"pcmpgtb",0
opn_pcmpgtd	db	"pcmpgtd",0
opn_pcmpgtw	db	"pcmpgtw",0
opn_pmaddwd	db	"pmaddwd",0
opn_pmulhw	db	"pmulhw",0
opn_pmullw	db	"pmullw",0
opn_por         db      "por",0
opn_pslld	db	"pslld",0
opn_psllq	db	"psllq",0
opn_psllw	db	"psllw",0
opn_psrad	db	"psrad",0
opn_psraw	db	"psraw",0
opn_psrld	db	"psrld",0
opn_psrlq	db	"psrlq",0
opn_psrlw	db	"psrlw",0
opn_psubb	db	"psubb",0
opn_psubd	db	"psubd",0
opn_psubsb	db	"psubsb",0
opn_psubsw	db	"psubsw",0
opn_psubusb	db	"psubusb",0
opn_psubusw	db	"psubusw",0
opn_psubw	db	"psubw",0
opn_punpckhbw	db	"punpckhbw",0
opn_punpckhwd	db	"punpckhwd",0
opn_punpckhdq	db	"punpckhdq",0
opn_punpcklbw	db	"punpcklbw",0
opn_punpcklwd	db	"punpcklwd",0
opn_punpckldq	db	"punpckldq",0
opn_pxor	db	"pxor",0
opn_fcomi       db      "fcomi",0
opn_fcomip      db      "fcomip",0
opn_fucomi      db      "fucomi",0
opn_fucomip     db      "fucomip",0
opn_fxsave      db      "fxsave",0
opn_fxrstor     db      "fxrstor",0
opn_fcmovb      db      "fcmovb",0
opn_fcmovbe     db      "fcmovbe",0
opn_fcmove      db      "fcmove",0
opn_fcmovnb     db      "fcmovnb",0
opn_fcmovnbe    db      "fcmovnbe",0
opn_fcmovne     db      "fcmovne",0
opn_fcmovnu     db      "fcmovnu",0
opn_fcmovu      db      "fcmovu",0

regs	db	"alcldlblahchdhbhaxcxdxbxspbpsidi"
psegs	db	"escsssdsfsgs"
crreg	db	"CR01234567"
drreg	db	"DR01234567"
trreg	db	"TR01234567"
sudreg	db	"?R????????"
scales  db      "1*2*4*8*"
stalone	db	"st",0
st_repz	db	C_INSTRUCTION, "repz ",0
st_repnz db	C_INSTRUCTION, "repnz ",0
st_lock db      C_INSTRUCTION, "lock ",0

base0	db	"bx+si",0
base1	db	"bx+di",0
base2	db	"bp+si",0
base3	db	"bp+di",0
base4	db	"si",0
base5	db	"di",0
base6	db	"bp",0
base7	db	"bx",0
st0	db	"dword",0	; Should be DWORD for MATH, FWORD for jmp/call
st1	db	"dword",0
st2	db	"qword",0
st3	db	"word",0
st4	db	"tbyte"
st5	db	0
byptr   db      "byte ",0,"ptr ",0
dwptr	db	"d"
woptr	db	"word"
theptr  db      " ",0," ptr ",0
pbptr   db      "pbyte ",0,"ptr ",0
fwptr   db      "fword ",0,"ptr ",0
stsreg	db	"st(",0
mmxreg  db      "mm",0
based	dw	base0,base1,base2,base3,base4,base5,base6,base7
sts	dw	st0,st1,st2,st3,st4,st5,st5,st5
opn_farptr db   "far ",0
;	mov	eax,"wde"
	END
