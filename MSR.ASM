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
; msr.asm
;
; Function: view msrs
;
;
	;MASM MODE
	.model small
	.586p

include  iwindow.inc
include  iversion.inc
include  eprints.inc 
include  emtrap.inc 
include  eenv.inc
include  eloader.inc
include  einput.inc
include edos.inc
include eoptions.inc
include eints.inc
include edpmi.inc

	.code
	extrn cpufeatures: dword
	public domsr
domsr PROC
	bt		[cpufeatures],5
	jc		checkmode
    PRINT_MESSAGE   <13,10,"Command not supported by this processor">
	clc
	ret
checkmode:
	test	cs:[indpmi],255
	jnz		testseg
	mov		eax,CR0		;not in DPMI, if in protected mode is a V86 shell
	test	al,1
	jnz		protected
	jmp		ok
testseg:
;	mov		ax,cs
;	and		ax,3
;	jz		ok
protected:
    PRINT_MESSAGE   <13,10,"Command not available in this processor mode">
	clc
	ret
ok:
	mov		al,[optdwordcommand]
	push	ax
	mov		[optdwordcommand],1
	inc		si
	call	wadespace
	jz		err
	call	ReadAddress		; read source address
	jc		err
	call	defDS			; get DS
	call	wadespace
	jnz		readend
	mov		ecx,0
	jmp		join
readend:
    cmp     al,'l'
    jnz     nl
    inc     si
    call    ReadNumber
    jc      err
    mov     ecx,eax
	dec		ecx
	jl		err
    jmp    	join
nl:
	call	ReadNumber		; read end of source
	jc	err
	mov	ecx,eax
	sub	ecx,ebx
	jb	err
join:	
	xchg	ebx,ecx
	call	crlf
lp:
	call	doint
	rdmsr
	call	undoint
	call putvalue
	inc		ecx
	dec		ebx
	jge		lp
x:	
	pop		ax
	mov		[optdwordcommand],al
	clc
	ret
err:
	pop		ax
	mov		[optdwordcommand],al
	stc
	ret
domsr ENDP
theInt PROC
	; we so don't care about the flags for this....
	; we just want to return carry set because there was an error.
	add	word ptr [esp],2
	stc
	retf 2
theInt ENDP
doint PROC
	pop	di
	push	fs
	push	0
	pop		fs
	push	word ptr fs:[13*4 + 2]
	push	word ptr fs:[13*4]
	cli
	mov		word ptr fs:[13*4+2],cs
	mov		word ptr fs:[13*4], offset theInt
	push	di
	clc
	ret
doint ENDP
undoint PROC
	pop		di
	pop	word ptr fs:[13*4]
	pop	word ptr fs:[13*4 + 2]
	sti
	pop	fs	
	push	di
	ret
undoint ENDP
putvalue PROC
	push	ebx
	push	ecx
	push	eax
	push	edx
	pushf
	mov		eax,ecx
	call	printdword
	mov		dl,':'
	call	putchar
	mov		dl,' '
	call	putchar
	popf
	jc		unknown
	pop		eax
	call	printdword
	mov		dl,' '
	call	putchar
	pop		eax
	call	printdword
	call	crlf
	pop		ecx
	pop		ebx
	ret	
unknown:
    PRINT_MESSAGE   <"UNKNOWN">
	call	crlf
	add		sp,8
	pop		ecx
	pop		ebx
	ret
putvalue ENDP
END