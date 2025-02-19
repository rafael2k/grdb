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
; swift.asm
;
; function: swift (relatively) tracing to find the end of a procedure
;
	.model small
	.386

include eexec.inc
include erm32.inc
include ebreaks.inc
include emtrap.inc
include eints.inc
include edpmi.inc
include eprints.inc

STEPFLAG = 100h
        .code
traceon	db	0	;is swift tracing enabled
int3trace db	0	;are we in the middle of a full-speed run to int3
image	db	0	;image at place int 3 is found
adjusted db 0
oldcs	dw	0	;position of int 3
oldeip  dd      0
stacksave	df	0

	public	swiftrace,traceon,untrace
	assume	ds:nothing, es:nothing, fs:nothing
	.code
FRAMEOFFS = 32 + 2
        extrn incs32:byte
untrace	proc
	push	fs
	push	es
	push	ax		; registers picked because this used in
					; break interrupt too!!!!
	call	CSCompatibleDS
	mov		es,ax
	test	cs:[int3trace],1	;
	jz	nounload2	;
    mov     ebp,cs:[oldeip]

	mov	ax,cs:[oldcs]	
	call	compatibleUtilitySeg
	mov	fs,ax
	mov	al,cs:[image]	;
        mov     fs:[ebp],al     ;
	mov	es:[int3trace],0	;
nounload2:
	mov	es:[traceon],0
	pop		ax
	pop		es
	pop		fs
	ret
untrace	endp

assume ds:_text, es:dgroup
swiftrace PROC
	test	cs:[traceon],0ffh
	jz	notrace
        pushad
	push	fs
	push	es
	push	ds
	push	ax
	call	CSCompatibleDS
	mov		ds,ax
	pop		ax
	call	compatibleES
		call	adjustStack
        mov     bp,sp
		add		bp,6	
        test    cs:[incs32],1
        jz      rmn32

        mov     es:[regdumpEAX],eax
        mov     es:[regdumpEBX],ebx
        mov     es:[regdumpECX],ecx
        mov     es:[regdumpEDX],edx
        mov     es:[regdumpESI],esi
        mov     es:[regdumpEDI],edi
        mov     eax,[bp + 8]
        mov     es:[regdumpEBP],eax
        lea     eax,[bp + FRAMEOFFS + 6]
        mov     es:[regdumpESP],eax
        mov     ax,[bp-4]       
        mov     es:[regdumpES],ax
		mov		ax,[bp-6]
        mov     es:[regdumpDS],ax
        mov     es:[regdumpFS],fs
        mov     es:[regdumpSS],ss
        mov     es:[regdumpGS],gs

        pushfd
        pop     eax
        mov     ax,[bp + FRAMEOFFS + 4]
        mov     es:[regdumpFLAGS],eax
        mov     ax,[bp + FRAMEOFFS + 2]
        mov     es:[regdumpCS],ax
        movzx   eax,word ptr [bp + FRAMEOFFS]
        mov     es:[regdumpEIP],eax
rmn32:
		test	[inDPMI],1
		jz		ld_16
		test	[dpmiType],1
		jz		ld_16
		mov		ebx,dword ptr [bp + FRAMEOFFS]
		mov		si, word ptr [bp + 4 + FRAMEOFFS]
		mov		di,4
		jmp		ld_jn
ld_16:
        movzx   ebx,word ptr [bp + FRAMEOFFS] ;
        mov     si,[bp + 2 + FRAMEOFFS]
		sub		di,di
ld_jn:
		mov		ax,si
		call	compatibleUtilitySeg
		mov		fs,ax
	test	[int3trace],1	;
	jz	nounload	;
        cmp     si,[oldcs]
        jnz     nounload
        cmp     ebx,[oldeip]
        jnz     nounload
        dec     ebx
		test	[inDPMI],1
		jz		st_16
		test	[dpmiType],1
		jz		st_16
        mov     [bp + FRAMEOFFS],ebx
		jmp		st_jn
st_16:
        mov     [bp + FRAMEOFFS],bx
st_jn:

noupdate:
	mov	al,[image]	;
        mov     fs:[ebx],al     ;
	mov	[int3trace],0	;
nounload:
        mov     al,fs:[ebx]
	cmp	al,0cch
	jz	found3
	
	push	di
	call	WadePrefix	; wade through prefixes
	pop		di
	cmp	al,9dh		; ehcek for popf
	jnz	notpopf
    or      word ptr [bp + di + 4 + FRAMEOFFS],STEPFLAG ; make sure popf will trace
	jmp	stx
notpopf:
	cmp	al,0c2h		; now check for rets
	jz	retx
	cmp	al,0c3h
	jz	retx
	cmp	al,0cbh
	jz	retx
	cmp	al,0cah
	jz	retx
	cmp	al,0cfh		; we WILL check iret here
	jnz	tracex		; none of those, check for call/int/string stepping
    or      word ptr [bp + di + 4 + FRAMEOFFS],STEPFLAG ; be sure iret will trace
retx:
       	mov	[traceon],0	; else kill trace flag and trace past ret/iret
tracex:	
        or      word ptr [bp + di + 4+FRAMEOFFS],STEPFLAG       ; set trace flag
	push	di
	call	callcheck	; see if call.int
	pop		di
        jz      short setcall         ; yep, set a break there
	push	di
	call    cmpstring	; see if is string instruction
	pop		di
	mov	ax,1		; else one byte
	jz	short setcall	; yes, set an int 3 instruction in place
stx:
	call	restoreStack
	mov	al,[inDPMI]
	and al,[dpmiType]
	shr	al,1
	mov	[inDPMI],0
	pop ds
	pop	es
	pop	fs
	popad
	jc	dpmi32
    add     esp,2            ; bump past ret
        test    cs:[incs32],1
        jnz     rm32up
real:
	iret
dpmi32:
    add     esp,2            ; bump past ret
	iretd
rm32up:
        mov     ax,dgroup
        mov     es,ax
        mov     ds,ax
        add     sp,4                    ; CS:EIP
        pushfd                          ; get high word of flags
        pop     eax
        pop     ax                      ; word flags to EAX
        call    cs32runup               ; won't return
                                        ; the runup will pop the ret addr
;-------------------------------
setcall:        
		movzx	eax,ax
        add     ebx,eax
        mov     al,fs:[ebx]
		mov	[image],al
        mov     byte ptr fs:[ebx],0cch
		inc	[int3trace]
		mov	[oldcs],si
        mov     [oldeip],ebx
        inc     [oldeip]
        and     word ptr [bp + di + 4 + FRAMEOFFS],NOT STEPFLAG    ; no trace here
	jmp	stx
found3:
	mov	[traceon],0
	call	restoreStack
	pop ds
	pop	es
	pop	fs
	popad
notrace:
	ret
swiftrace ENDP
;
; these next two have to be at the same stack nesting level
;
; the rational is that in 32-bit DPMI, we may have misaligned the stack,
; and windows needs it aligned if we are going to use 32-bit EBP based addressing
; mode.  So we switch back to the 16-bit mode, but have to align SS so that
; bp will be valid.
;
adjustStack PROC
	mov	[adjusted],0
	test	[indpmi],1
	jz		noadj
	test	[dpmiType],1
	jz		noadj
	test	esp,0ffff8000h
	jz		noadj
	inc	[adjusted]
	mov	dword ptr [stacksave],esp
        mov     word ptr [stacksave + 4],ss
	mov	bx,ss
	mov	ax,6		; get base of original stack
	int	31h
	shl	ecx,16		; put in ECX
	mov	cx,dx

	mov	eax,esp			; now add upper bits of ESP
	and	eax,0ffff8000h
	add	ecx,eax
	mov	dx,cx			; shift back to cx:dx
	shr	ecx,16

	mov	ax,7	;set base of new stack seg
	mov	bx,[dpmiSwiftSeg]
	int	31h

	mov	ecx,esp
	and	ecx,7fffh		; 16-bit stack in cx
	mov	ss,[dpmiSwiftSeg]	; load new stack
	mov	esp,ecx

noadj:
	ret
adjustStack ENDP
restoreStack PROC
        test    [adjusted],1
        jz      rsx
        lss     esp, [stacksave]
rsx:
	mov	[adjusted],0
	ret
restoreStack ENDP
	end