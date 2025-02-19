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
; FP.ASM
;
; Function: Handle FP status commands
;
	;MASM MODE
	.MODEL SMALL
	.386

	public	floatcheck, fpcommand

include iwindow.inc
include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include  ebreaks.inc 
include  eloader.inc
include  edos.inc
include eexec.inc

;
; hack to help MASM versions that die on pop-fmath
;
	.data
floatstat 	dw	47 dup (0)	;;fnsave/FNSTOR buffer
ten		dw	10
pointone	dt	0.1
nan		dd	7fffffffh	; quiet nan
inf		dd	7f800000h	; plus infinity
curdig		dd	?		;current digit for input
work		dw	?		;used in detecting FP hardware
fpflag		db	?		;flag if we can use FP commands
enames		db	"IDZOUP"	;exception names


	.code
precmsg	dw	offset _text:prsing,offset _text:reserved
	dw	offset _text:prdbl,offset _text:prxt
roundmsg dw	offset _text:rdnear,offset _text:rdminus
	dw	offset _text:rdplus,offset _text:rdzer
prsing	db	"Single",0
prdbl	db	"Double",0
prxt	db	"Extended",0
reserved db	"Reserved",0
rdnear	db	"Nearest",0
rdzer	db	"Zero",0
rdplus	db	"Plus Infinity",0
rdminus db	"Minus Infinity",0

;
; check for floating point unit
;
floatcheck	proc
		mov	[fpflag],1
		mov	[work],4567h
		fninit
		fstsw 	[work]
		cmp	[work],0
		jz	hasfp
		mov	[fpflag],0
hasfp:
		ret
floatcheck	endp
stackpos PROC
        mov     bx,cx
        imul    bx,[ten]
        add     bx,offset floatstat+14
        ret
stackpos        endp
;
; fp commands
;
fpcommand	proc
	test	[fpflag],1
	jnz	hasfloat
	PRINT_MESSAGE	<13,10,"No FP unit">
	clc
	ret
hasfloat:
	fnsave	[floatstat]
;        fninit
	fwait
	call	WadeSpace
	jz	dumpstack
	cmp	al,'s'
	jnz	flread
;
; status command
;
	inc	si
	call	WadeSpace
	jnz	flerr
        frstor [floatstat]
        PRINT_MESSAGE <13,10,C_OPTTEXT, "Control Word:      ", C_NUMBER>
        mov     ax,[floatstat]
        call    printword
        PRINT_MESSAGE <13,10,C_OPTTEXT, "Status Word:       ", C_NUMBER>
        mov     ax,[floatstat+2]
        call    printword
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "Masked exceptions: ", C_RESERVEDWORD>
	mov	dx,word ptr [floatstat]
	call	except
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "Active exceptions: ", C_RESERVEDWORD>
	mov	dx,word ptr [floatstat+2]
	call	except
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "Precision:         ", C_RESERVEDWORD>
	movzx	bx,byte ptr [floatstat+1]
	and	bl,3
	shl	bl,1
	mov	bx,[bx+precmsg]
	call	olMessage
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "Rounding:          ", C_RESERVEDWORD>
	movzx	bx,byte ptr [floatstat+1]
	and	bl,0ch
	shr	bl,1
	mov	bx,[bx+roundmsg]
	call	olMessage
	PRINT_MESSAGE	<13,10,C_OPTTEXT, "FPU Status flags:  ", C_RESERVEDWORD>
	test	word ptr [floatstat+2],100h
	jz	notc0
	PRINT_MESSAGE	"C0 "
notc0:
	test	word ptr [floatstat+2],200h
	jz	notc1
	PRINT_MESSAGE	"C1 "
notc1:
	test	word ptr [floatstat+2],400h
	jz	notc2
	PRINT_MESSAGE	"C2 "
notc2:
	test	word ptr [floatstat+2],4000h
	jz	notc3
	PRINT_MESSAGE	"C3 "
notc3:
	mov	dl,C_DEFAULT
	call PutChar
	clc
	ret
;
; dump the FP stack
;
dumpstack:
        PRINT_MESSAGE <13,10,C_OPTTEXT, "Control Word:      ", C_NUMBER>
        mov     ax,[floatstat]
        call    printword
        PRINT_MESSAGE <13,10,C_OPTTEXT, "Status Word:       ", C_NUMBER>
        mov     ax,[floatstat+2]
        call    printword
        PRINT_MESSAGE <13,10>
	mov	cx,8
dsl:
	push	cx
        sub     cx,8
        neg     cx
        call    stackpos
	call	dumpval
	pop	cx
	loop	dsl
        frstor [floatstat]
	mov	dl,C_DEFAULT
	call PutChar
	clc
	ret
;
; read an FP number into a reg
;
flread:
	sub	al,'0'
	jc	flerr
	cmp	al,8
	jae	flerr
        sub     al,7
        neg     al
	push	ax
	inc	si
	call	wadespace
	jz	flerr2
	call	ReadFpNumber
	jc	flerr2
	pop	ax
	mov	cl,al
	call	testtag
	jz	flerr3
        movzx   cx,al
        sub     cx,7
        neg     cx
        call    stackpos
        fstp    tbyte ptr [bx]
        frstor [floatstat]
	clc
	ret
	
testtag	PROC
	and	cl,7
	add	cl,cl
	mov	bx,[floatstat+4]
	shr	bx,cl
	and	bl,3
	cmp	bl,3
	ret
testtag	ENDP

flerr3:
        frstor  [floatstat]
	PRINT_MESSAGE	<13,10,"err - empty reg">
	clc
	ret
flerr2:
	add	sp,2
flerr:
        frstor [floatstat]
	stc
	ret
fpcommand	endp
except	PROC
	mov	si,offset enames
	mov	cx,6
exlp:
	shr	dx,1
	lodsb
	jnc	nhr
	push	dx
   	mov	dl,al
	call	putchar
	mov	dl,'e'
	call	putchar
	call	printspace
	pop	dx
nhr:
	loop	exlp
	ret
except	ENDP
;
; dump the value of a stack register
;
dumpval	PROC
	call	crlf
        push    bx
        push    cx
        PRINT_MESSAGE <C_REGISTER, "st">
        pop     cx
        pop     bx
        
	mov	dl,cl
	add	dl,'0'
	call	putchar
	mov	dl,	C_DEFAULT
	call	putchar
        mov     dl,':'
	call	putchar
	call	printspace
	call	printspace
	call	printspace
        mov     ax,word ptr [floatstat+2]
        shr     ax,11
        add     cl,al
        and     cl,7
	mov	ax,word ptr [floatstat+4]
	shr	ax,cl
	shr	ax,cl
	and	al,3
	cmp	al,3
	jnz	notempty
	PRINT_MESSAGE	<C_RESERVEDWORD, "<Empty>">
	clc
	ret

notempty:
	cmp	al,2
	jnz	notnan
	test	byte ptr [bx + 9],80h
	jz	nsinf
      	mov	dl,'-'
	call	putchar
nsinf:
	fld	tbyte ptr [bx]
	fxam
	fnstsw	ax
	fstp	st(0)
	sahf
	jpe	isinf
	PRINT_MESSAGE	<C_NUMBER, "<Nan>">
	clc
	ret
isinf:
	PRINT_MESSAGE	<C_NUMBER, "<Inf>">
	clc
	ret
notnan:
	push	ax
	mov	dl,C_NUMBER
	call	putchar
	pop	ax
	cmp	al,1
	jnz	notzero
	test	byte ptr [bx + 9],80h
	jz	nszer
      	mov	dl,'-'
	call	putchar
nszer:
        PRINT_MESSAGE   "<Zero>"
	clc
	ret
notzero:
	fld	tbyte ptr [bx]
	call	PrintFloating
	fcomp
	clc
	ret
dumpval	ENDP
;
; actual FP print routines
;
PrintFloating	PROC
	call	fextract
	or	ax,ax
	jz	notdenorm
	PRINT_MESSAGE	"<Denorm>"
	ret
notdenorm:
	or	dx,dx
	jns	noneg
	call	putneg
noneg:
	cmp	bx,8		; getter be less than 16!!!!
	jg	highexp
	cmp	bx,-4
	jle	lowexp
	or	bx,bx
	jge	gte0
;
; print for less than one but not exponential
;
	push	bx
	call	putzer
	call	putper
	pop	cx
	not	cx
	jcxz	nozr
	inc	cx
zrl:
	call	putzer
	loop	zrl
nozr:
	mov	cx,16
nl2:
	call	fnd
	call	putdig
	loop	nl2
	ret
;
; print for greater than or equal to one but not exponential
;
gte0:
	push	bx
	mov	cx,bx
	call	fnd
	call	putdig
	jcxz	gte0nl
gtel1:
	call	fnd
	call	putdig
	loop	gtel1
gte0nl:
	call	putper
	pop	cx
	sub	cx,16
	neg	cx
gtel2:
	call	fnd
	call	putdig
	loop	gtel2
	ret
;
; hack to justify negative exponents
;
lowexp:
	dec	bx
	call	fnd
;
; exponential print
;
highexp:
	push	bx
	call	fnd
	call	putdig
	call	putper
	mov	cx,16
hel1:
	call	fnd
	call	putdig
	loop	hel1
	mov	dl,'e'
	call	putchar
	pop	ax
	or	ax,ax
	jns	nonegx
	push	ax
	call	putneg
	pop	ax
	neg	ax
nonegx:
	sub	cx,cx
elp1:
	sub	dx,dx
	div	[ten]
	push	dx
	inc	cx
	or	ax,ax
	jnz	elp1
elp2:
	pop	ax
	call	putdig
	loop	elp2
	ret
putdig:
	mov	dl,al
	add	dl,'0'
	call	putchar
       	ret
putper:
	mov	dl,'.'
	call	putchar
	ret
putneg:
	mov	dl,'-'
	call	putchar
	ret
putzer:
	mov	dl,'0'
	call	putchar
	ret
PrintFloating	ENDP
;
; get exponent and mantissa and sign
;
; enter:
;   st(0) = value
;
; returns:
;   ax = 0	; ok val
;   
;     st(0) = mantissa
;     bx = exp
;     dx = sign   ( +-1)
;
;   ax = -1	; infinity or dnormal
;
fextract 	PROC
	enter	6,0
	fstcw	[bp-2]
	mov	ax,[bp-2]
	or	ah,0ch		; round toward zero
	mov	[bp-4],ax
	fldcw	[bp-4]

	ftst
	fnstsw	ax
	fnclex			; just in case ... 
	sahf
	mov	eax,-1   	; first check for out of range
	jp	fxx
	jnz	dosign		; now check for zero
	sub	bx,bx
	sub	dx,dx
	jmp	fxx

dosign:
	mov	dx,1		; nonzero, finally get sign
	jnc	pos
	fabs       		; we will work with positive nums hereafter
	mov	dx,-1
pos:
	fldlg2       		; log to base 10
	fxch
	fyl2x
	
	fld	st(0)		; get int part
	frndint
	fist	word ptr [bp-6]
	pop	bx

	fsubp	st(1),st(0)			; fraction
	fldl2t			; convert back to base 2
	fmulp	st(1),st(0)

	fld	st(0)		; lovely exponentiation
	frndint
	fxch
	fld	st(1)
	fsubp	st(1),st(0)
	f2xm1			;
	fld1
	faddp	st(1),st(0)
	fscale
	fxch
	fcomp
	sub	eax,eax
fxx:
	fnclex
	fldcw	[bp-2]
	fwait
	leave
	ret
fextract	ENDP
;
; get next digit from mantissa
;
; enter:
;   mantissa from fextract on stack
;
; exit:
;   eax = next digit (base 10)
;   stack = new mantissa
;
fnd	PROC
	ENTER	6,0
	fstcw	[bp-2]
	mov	ax,[bp-2]
	or	ah,0ch		; round toward zero
	mov	[bp-4],ax
	fldcw	[bp-4]

	fld	st(0)		; next digit
	frndint
	fist	word ptr [bp-6]

	fsubp	st(1),st(0)			; new mantissa
	fimul	word ptr [ten]

	fnclex
	fldcw	[bp-2]
	fwait
	pop	ax		; cute trick to get result :)
	leave
	ret
fnd	ENDP
;
; read floating point number
readfpnumber PROC
	sub	dx,dx		; sign = +
	cmp	al,'+'		; get sign bit
	jz	rfn_gotsign
	cmp	al,'-'
	jnz	rfn_nosign
	inc	dx		; minus sign, sign = '-'
rfn_gotsign:
	inc	si		; step past sign
rfn_nosign:
	call	wadespace	; skip space
	jz	rfn_err
	mov	eax,[si]	; check for nan
	and	eax,0ffffffh
	cmp	eax,"nan"
	jnz	rfn_notnan
	fld	[nan]		; nan, load it
	jmp	rfn_ni
rfn_notnan:
	cmp	eax,"fni"	; check for inf
	jnz	rfn_notinf
	fld	[inf]		; inf load it
rfn_ni:
	add	si,3		; skip past inf/nan
	call	wadespace	; err if more
	jnz	rfn_err2
	jmp	rfn_done		; else tag in sign and exit
;
rfn_notinf:
	fldz            	; return val
	call	getdig		; see if leading digits
	jc	rfn_err2		
	jz	rfn_nostart     ; go check for '.' if not digit
rfn_prelp:
	fimul	[ten]   	; else shift digit in
	fild	[curdig]
	faddp	st(1),st(0)
	call	getdig     	; loop till all digits got
	jc	rfn_err2
	jnz	rfn_prelp
	cmp	al,'.'		; now check for '.'
	jz	rfn_dot		; yes, do it
	jmp	rfn_exp
;
rfn_nostart:
	cmp	al,'.'		; no leading digit, must have dot
	jnz	rfn_err
rfn_dot:
	call	getdig		; if no digits get exponent
	jc	rfn_err2
	jz	rfn_exp
	fld	[pointone]	; else we have digits, load up 0.1
rfn_ptlp:
	fild	[curdig]	; load digit
	fmul	st(0),st(1)	; mul by placeholder and add it in
	faddp	st(2),st(0)
	fld	[pointone] 	; adjust placeholder
	fmulp	st(1),st(0)
	call	getdig
	jc	rfn_err3
	jnz	rfn_ptlp
	fstp	st(0)   	; get rid of placeholder
rfn_exp:
	cmp	al,'e'  	; check for exponent
	jnz	rfn_done
	sub	bx,bx
	sub	cx,cx
rfn_exl:
	call	getdig		; first digit of exponent or sign
	jc	rfn_err2
	jnz	rfn_nexs
	inc	cx
	call	getdig
	jz	rfn_err2
	jc	rfn_err2
rfn_nexs:
	xchg	ax,bx
	push	dx
	mul	[ten]
	pop	dx
	xchg	ax,bx
	movzx	ax,al
	add	bx,ax
	call	getdig
	jc	rfn_err2
	jnz	rfn_nexs
	or	cx,cx
	jz	rfn_nexs2
      	neg	bx
rfn_nexs2:
	cmp	bx,1024		; verify range
	jg	rfn_err2
	cmp	bx,-1024
	jl	rfn_err2
	enter	4,0		; need temp space now
	mov	[bp-2],bx	; get exponent to fp stack
	fild	word ptr [bp-2]
	fldl2t                 	; convert exponent to logarithmic base 2
	fmulp	st(1),st(0)
	fnstcw	[bp-4]		; set rounding mode to zero
	mov	ax,[bp-4]
	and	ah,0f3h
	or	ah,0ch
	mov	[bp-2],ax
	fldcw	[bp-2]
	fld	st(0)   	; extract int and fraction of exponent
	frndint
	fxch	st(1)
	fsub	st(0),st(1)
	f2xm1              	; exponentiate the fraction
	fld1
	faddp	st(1),st(0)
	fscale			; scale in the integer part of exponent
	fxch	st(1)  		; get rid of int part
	fcomp	st(1)
	fldcw	[bp-4]		; restore round mode
	leave			; clear stack
	fmulp	st(1),st(0)	; multiply base * exponent (may result in 
				; an infinity)
rfn_done:
	or	dx,dx		; get the sign bit
	jz	rfn_x
	fchs			; to the FPU
rfn_x:
	clc
	ret

rfn_err3:
	fstp	st(0)
rfn_err2:
	fstp	st(0)
rfn_err:
	stc
	ret
;
; routine to get a digit, returns ZR for a '.' or 'e' or CR
; and Carry for an error, else NZ means a digit
;
getdig	PROC
	lodsb			; get val
	cmp	al,'0'		; check low end of digits
	jc	gds		; no, check high end
	cmp	al,'9'
	ja	gds
	sub	al,'0'
	mov	byte ptr [curdig],al ; digit, store it for later
	or	si,si		; set nz
	ret
gds:
	cmp	al,'-'
	jz	gdsk
	cmp	al,'e'		; check for 'e'
	jz	gdsk
	cmp	al,'.'		; '.'
	jz	gdsk
	cmp	al,13		; CR
	jnz	gdsk
	pushf			; if is CR bump char ptr back so
	dec	si		; we don't overrun
	popf
gdsk:
	clc
	ret

getdig	ENDP
readfpnumber ENDP
end
