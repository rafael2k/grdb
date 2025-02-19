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
; dpmi.ASM
;
; Function: dpmi handlers
;
; not very efficient, but, fast enough!
;
	;MMODE
	.MODEL SMALL
	.386
        public  initDPMI, rundownDPMI, dpmiHandler
		public compatibleDS, compatibleES, CSCompatibleDS
		public compatibleZeroPage
  		public compatibleIntPage,compatibleStackSeg,compatibleHistSeg
		public compatibleSymSeg, compatibleUtilitySeg
		public codeAlias, inDPMI, dpmiType, dpmixcept
		public noCommandInDPMI, dpmiSwiftSeg
		
include eints.inc
include ehistory.inc
include eloader.inc
include emtrap.inc
include ebreaks.inc
include eprints.inc
include eints.inc
include esymbol.inc
include edump.inc
include iasm.inc
include easm.inc
include edis.inc
include einput.inc
        .code
startDPMI       dd      0
utilitySelector	dw		?
codeAlias       dw      ?
codesel32		dw		?
codeSelector    dw      ?,0
dataSelector    dw      ?
allSelector     dw      ?
dpmiIntPage		dw		?
dpmiStackSeg	dw		?
dpmiHistSeg		dw		?
dpmiSymSeg		dw		?
dpmiSwiftSeg	dw		?
xceptflags		dd		?
xceptcs			dd		?
xceptip			dd		?
xceptxcept		dd		?
xceptretval		dw		?
gb4desc db      0ffh,0ffh,0,0,0,0F2h,0cfh,0
dpmiType        db      0       ; 1 = 32 bit
dpmiHooked      db      0
inDPMI			db		0		; 1 = in DPMI
replaceStart    db      0
oldint21h		db		6 dup (0)
dpmixcept		db		?

;
; macro called in 32 bit mode
; to thunk down to our 16-bit handlers
; a convenience to keep from messing with 32-bit segments
;
thunk3216 macro	address
	db	02eh,0ffh,035h		;push[codeSelector]
	dw	offset codeSelector
	dw	0
	db	68h					; push address
	dw	offset address
	dw	0
	retf
endm

compatibleUtilitySeg proc
	test	[inDPMI],1
	jz		cus_real
	push	dx
	push	cx
	push	bx
	mov		bx,ax
	mov		ax,6 ; get base
	int		31h
	mov		ax,7 ; set base
	mov		bx,[utilitySelector]
	int		31h
	mov		ax,[utilitySelector]
	pop		bx
	pop		cx
	pop		dx
cus_real:
	ret
compatibleUtilitySeg endp
compatibleSymSeg proc
	test	[inDPMI],1
	jz		csys_real
	mov		ax, [dpmiSymSeg]
	ret
csys_real:
	mov		ax, [symseg]
	ret
compatibleSymSeg endp

compatibleZeroPage proc
	test	[inDPMI],1
	jz		czs_real
	mov		ax, [allSelector]
	ret
czs_real:
	sub		ax,ax
	ret
compatibleZeroPage endp

compatibleIntPage proc
	test	[inDPMI],1
	jz		cis_real
	mov		ax, [dpmiIntPage]
	ret
cis_real:
	mov		ax,cs:[IntPage]
	ret
compatibleIntPage endp
compatibleStackSeg proc
	test	[inDPMI],1
	jz		css_real
	mov		ax, dpmiStackSeg
	ret
css_real:
	mov		ax,[StackSeg]
	ret
compatibleStackSeg endp
compatibleHistSeg proc
	test	[inDPMI],1
	jz		chs_real
	mov		ax, dpmiHistSeg
	ret
chs_real:
	mov		ax,[HistSeg]
	ret
compatibleHistSeg endp
CScompatibleDS PROC
	test	[inDPMI],1
	jz		csds_real
	mov		ax,[codeAlias]
	ret
csds_real:
	mov		ax,cs
	ret
CScompatibleDS ENDP
compatibleDS PROC
	test	[inDPMI],1
	jz		cds_real
	mov		ds,[dataSelector]
	ret
cds_real:
	push	DGROUP
	pop		ds
	ret
compatibleDS ENDP
compatibleES PROC
	test	[inDPMI],1
	jz		ces_real
	mov		es,[dataSelector]
	ret
ces_real:
	push	DGROUP
	pop		es
	ret
compatibleES ENDP

noCommandInDPMI PROC
	test	[inDPMI],1
	jz	ncid
	PRINT_MESSAGE	<13,10,"Command not available in DPMI mode">
	pop	cx
ncid:
	ret
noCommandInDPMI	ENDP
;
; we have to hook the DPMI transition code directly because
; Win9x does this by intercepting the int 2fH in pmode and we
; can't rely on the DOS chain for this
;
initDPMI        PROC
        push    es
        mov     ax,1687h
        int     2fh
        and     ax,ax
        jnz     idx
        mov     al,es:[di]
        mov     [replacestart],al
        mov     byte ptr es:[di],0cch	; int 3
		cmp		byte ptr es:[di],0cch	; win/9x doesn't allow us to hook DPMI
		jnz		idx						; at all, so just get out
        mov     word ptr [startDPMI],di
        mov     word ptr [startDPMI+2],es
		pop		es
        inc     dpmiHooked
		Call	PrintFollowingMessage
		db		13,10, "DPMI Start code hooked",0
		ret
idx:
        pop     es
        ret
initDPMI        ENDP
rundownDPMI     PROC
        test    [dpmiHooked],0ffh
        jz      rdx
        push    es
        les     di,[startDPMI]
        mov     al,[replaceStart]
        mov     byte ptr es:[di],al
        pop     es
rdx:
        ret
rundownDPMI     ENDP
;
; our replacement for the DPMI stack's startup routine
;
dpmiHandler PROC
;
; at this point the top of the stack has a near return to our int3 hook.
; that is followed by an iret frame for the int3 instruction that got us to this
; point.  If this is a legit DPMI client request to enter pmode, that will be
; followed by a far return to the beginning of the client's pmode code.
;
        pusha
		test	cs:[dpmihooked],1
		jz		notdpmitest
		test	[inDPMI],1
		jnz		notdpmitest
		mov		bx,[esp + 8 * 2 + 2]		; IRET IP
		dec		bx							; -1 to point at the int 3
		cmp		bx,word ptr cs:[startdpmi]
		jnz		notdpmitest
		mov		bx,[esp + 8 * 2 + 4]		; IRET CS
		cmp		bx,word ptr cs:[startdpmi + 2]
		jz		godpmi
notdpmitest:
		popa
		ret

godpmi:
		and		al,1
		mov		cs:[dpmiType],al
        push    es
        les     di,[startDPMI]
		mov		cs:[dpmihooked], 0
        mov     al,cs:[replaceStart]
        mov     byte ptr es:[di],al
        push    ds
		mov		ax,dgroup
		mov		ds,ax
		mov		es,ax
		call 	PrintFollowingMessage
		db		13,10,"Entering DPMI Mode", 13, 10, 0
		mov		al,20h
        pop     ds
        pop     es
        popa
        add     sp,8    ; remove the return to GRDB's int 3 handler, and the
						; iret frame that got us here

        call    cs:[startDPMI]	; enter pmode
        jc      startErr
;	at this point we are in 16-bit pmode.
; CS = our (GRDB) 16-bit CS
; DS = client's 16-bit DS
; SS = client's 16-bit SS
; ES = client's 16-bit PSP

        pushad
        mov     bp,sp
;
; now we replace the client's return address with an pmode/16 version
;
        mov     bx,[bp + 8 * 4 + 2]	; replace the client's far return CS
		call	getsel16
        mov     [bp + 8 * 4 + 2],ax	; with a pmode version
        mov     bx,ax
        mov     cx,0009ah
        mov     ax,cs
        and     ax,3
        shl     ax,5
        or      cx,ax
        mov     ax,9            ; set access rights
        int     31h        
		
; now start in on the GRDB - specific initialization

        push    ds
        push    es
; first up we make an alias for our CS
;
        mov     bx,cs
        mov     ax,0ah
        int     31h
        mov     es,ax
		mov		es:[codeAlias],ax
		
		mov		es:[codeSelector],cs
		
        ; make an alias for our DGROUP

        mov     bx,dgroup
		call	getsel16
		mov		ds,ax
		mov		es:[dataSelector],ax

        
; create a selector to access all 4 GB

        mov     cx,1
        mov     ax,0            ; allocate a selector
        int     31h
        
        mov     es:[allSelector],ax
        mov     bx,ax
        lea     di,[gb4desc]
        mov     ax,0ch
        int     31h
		
;
; make a utility selector, 4GB limit, that can be used
; arbitrarily.  E.g it will be used in the assembler as
; an alias for the code segment we are modifying
;
		mov		bx,es:[allSelector]
		mov		ax,0ah
		int		31h
		mov		es:[utilitySelector],ax

; create a selector for the stack
        mov     bx,[stackseg]
		call	getsel16
        mov     es:[dpmistackseg],ax

; create a selector for the history
        mov     bx,[histseg]
		call	getsel16
        mov     es:[dpmihistseg],ax

; create a selector for the intpage
        mov     bx,cs:[intpage]
		call	getsel16
        mov     es:[dpmiintpage],ax

; create a selector for the symbol seg
        mov     bx,[symseg]
		call	getsel16
        mov     es:[dpmiSymSeg],ax
		

; create a selector for the swiftrace seg
        mov     bx,0
		call	getsel16
        mov     es:[dpmiSwiftSeg],ax

; create a selector for the symbol seg
        mov     bx,[userbasepsp]
		call	getsel16
        mov     [bp-8],ax              ; return correct PSP to caller in ES

;
; create selectors for all active breakpoints
;

		mov		cx,15
brlp:
		bt		[breakenum],cx
		jnc		nobr
		mov		bx,cx
		shl		bx,3
		push	bx
		push	cx
		mov		bx,word ptr [bx + breaklist + 4]
		call	getsel16
		pop		cx
		pop		bx
		mov		word ptr [bx + breaklist +4], ax
nobr:
		dec		cx
		jns		brlp
;
; make a 32-bit code selector
; windows needs this since the switch back to 16-bit in interrupts
; isn't well handled
;
		mov		bx,[realcs]
		call	getsel16
		mov		es:[codesel32],ax
		mov		bx,ax
		mov		ax,cs
		and		ax,3
		shl		ax,5
		mov		cx,0c09ah
		or		cx,ax
		mov		ax,9
		int		31h
;
; hook int 21h function 4ch so we can delete all the selectors we created

;
		mov		ax,204h
		mov		bl,21h
		int		31h
		mov		dword ptr es:[oldint21h], edx
		mov		word ptr es:[oldint21h + 4],cx

		test	cs:[dpmiType],1
		jnz		int2132
		mov		cx,cs
		mov		dx, offset int21Handler
		jmp		int21jn
int2132:
		mov		cx, cs:[codesel32]
		mov		dx, offset int21thunk
int21jn:
		movzx	edx,dx
		mov		ax,205h
		mov		bl,21h
		int		31h

;
; hook int 1 and int 3
; some dos extenders will only do int handlers
; but others will only do exception handlers
; so we hook both...
;		
		test	cs:[dpmiType],1
		jnz		int332
		mov		cx,cs
		mov		dx, offset int3Handler
		jmp		int3jn
int332:
		mov		cx, cs:[codesel32]
		mov		dx, offset int3thunk
int3jn:
		movzx	edx,dx
		mov		ax,205h
		mov		bl,3
		int		31h

		test	cs:[dpmiType],1
		jnz		exc332
		mov		cx,cs
		mov		dx, offset exc3Handler
		jmp		exc3jn
exc332:
		mov		cx, cs:[codesel32]
		mov		dx, offset exc3thunk
exc3jn:
		movzx	edx,dx
		mov		ax,203h
		mov		bl,3
                int             31h

		test	cs:[dpmiType],1
		jnz		int132
		mov		cx,cs
		mov		dx, offset int1Handler
		jmp		int1jn
int132:
		mov		cx, cs:[codesel32]
		mov		dx, offset int1thunk
int1jn:
		movzx	edx,dx
		mov		ax,205h
		mov		bl,1
                int             31h

		test	cs:[dpmiType],1
		jnz		exc132
		mov		cx,cs
		mov		dx, offset exc1Handler
		jmp		exc1jn
exc132:
		mov		cx, cs:[codesel32]
		mov		dx, offset exc1thunk
exc1jn:
		movzx	edx,dx
		mov		ax,203h
		mov		bl,1
                int             31h
;
; hook various exceptions in an attempt to keep the debugger running...
; these will return to the input handler when processing commands
; or to the trap handler if the program was running
;
		test	cs:[dpmiType],1
		jnz		exc632
		mov		cx,cs
		mov		dx, offset exc6Handler
		jmp		exc6jn
exc632:
		mov		cx, cs:[codesel32]
		mov		dx, offset exc6thunk
exc6jn:
		movzx	edx,dx
		mov		ax,203h
		mov		bl,6
                int             31h

		test	cs:[dpmiType],1
		jnz		exc1332
		mov		cx,cs
		mov		dx, offset exc13Handler
		jmp		exc13jn
exc1332:
		mov		cx, cs:[codesel32]
		mov		dx, offset exc13thunk
exc13jn:
		movzx	edx,dx
		mov		ax,203h
		mov		bl,13
                int             31h

		test	cs:[dpmiType],1
		jnz		exc1432
		mov		cx,cs
		mov		dx, offset exc14Handler
		jmp		exc14jn
exc1432:
		mov		cx, cs:[codesel32]
		mov		dx, offset exc14thunk
exc14jn:
		movzx	edx,dx
		mov		ax,203h
		mov		bl,14
                int             31h
;
; do some final initialization for pmode
; make various commands default to the pmode data areas
;
		mov		[startingDisAddr], 0
		mov		[disassemblySeg], 0
		mov		ax,[allSelector]
		mov		[indexseg],ax
		mov		dword ptr [index], 00h
		mov	[lastseg],0
		mov	[lastofs], 0
        pop     es
        pop     ds
        popad
        clc
		retf
;
; at this point we are still in real mode
;
startErr:
        retf
dpmiHandler ENDP
int21thunk:
	thunk3216	int21handler
int21Handler PROC
		pushfd
		cmp	ah,4ch
		jnz	chain
		pushad
		;
		; unhook this int
		;
		mov		cx,word ptr cs:[oldint21h + 4]
		mov		edx, dword ptr cs:[oldint21h]
		mov		ax,205h
		mov		bl,21h
		int		31h		
		;
		; reset some params
		;
		push	ds
		mov		ds,cs:[dataSelector]
		mov		[startingDisAddr], 0
		mov		[disassemblySeg], 0
		mov		ax,[userbasepsp]
		mov		[indexseg],ax
		mov		dword ptr [index], 100h
		mov	[lastseg],0
		mov	[lastofs], 0
		pop		ds

		;
		; free resources
		;
		call dpmiCleanup
		popad
chain:
		push	eax
		movzx	eax,word ptr cs:[oldint21h + 4]
		xchg	eax,[esp]
		push	dword ptr cs:[oldint21h]
		iretd
int21Handler ENDP
exc1thunk:
	thunk3216	exc1handler
exc1handler PROC
		call	stackswitch
		test	cs:[dpmiType],1
		jnz		exc1rmdw
		add		esp,2
		jmp		exc1jn2
exc1rmdw:
		add		esp,4
exc1jn2:
		push	es
		mov		es,cs:[codeAlias]
		mov		es:[inDPMI],1
		mov		es:[dpmixcept],0
		pop		es
		jmp		entry1
exc1handler ENDP
int1thunk:
	thunk3216	int1handler
int1handler PROC
		push	es
		mov		es,cs:[codeAlias]
		mov		es:[inDPMI],1
		mov		es:[dpmixcept],0
		pop		es
		jmp		entry1
int1handler ENDP
exc3thunk:
	thunk3216	exc3handler
exc3handler PROC
		call stackswitch
		test	cs:[dpmiType],1
		jnz		exc3rmdw
		add		esp,2
		jmp		exc3jn2
exc3rmdw:
		add		esp,4
exc3jn2:
		push	es
		mov		es,cs:[codeAlias]
		mov		es:[inDPMI],1
		mov		es:[dpmixcept],0
		pop		es
		jmp		entry3
exc3handler ENDP
int3thunk:
	thunk3216	int3handler
int3Handler PROC
		push	es
		mov		es,cs:[codeAlias]
		mov		es:[inDPMI],1
		mov		es:[dpmixcept],0
		pop		es
		jmp		entry3
int3Handler ENDP
exc6thunk:
	thunk3216	exc6handler
exc6handler PROC
		call stackswitch
		test	cs:[dpmiType],1
		jnz		exc6rmdw
		add		esp,2
		jmp		exc6jn2
exc6rmdw:
		add		esp,4
exc6jn2:
		test	cs:[inDPMI],1
		jnz		requalInput
		push	es
		mov		es,cs:[codeAlias]
		mov		es:[inDPMI],1
		mov		es:[dpmixcept],0
		pop		es
		jmp		entry6
exc6handler ENDP
exc13thunk:
	thunk3216	exc13handler
exc13handler PROC
		call stackswitch
		test	cs:[inDPMI],1
                jnz             requalInput
		push	es
		mov		es,cs:[codeAlias]
		mov		es:[inDPMI],1
		mov		es:[dpmixcept],0
		pop		es
		jmp		entry13
exc13handler ENDP
exc14thunk:
	thunk3216	exc14handler
exc14handler PROC
		call stackswitch
		test	cs:[inDPMI],1
		jnz		requalInput
		push	es
		mov		es,cs:[codeAlias]
		mov		es:[inDPMI],1
		mov		es:[dpmixcept],0
		pop		es
		jmp		entry14
exc14handler ENDP
requalInput PROC
		call	CompatibleDS
		call	CompatibleES
		call	compatibleStackSeg
		mov	ss,ax	; load our stack
                PRINT_MESSAGE   <13,10,"Invalid memory access">
                movzx   esp,[stackofs]  ; clear top of ESP just in case...              
		jmp		InputHandler
requalInput ENDP
stackswitch PROC
        push ds
		push	eax
		push	ebp
        push ebx
        lea ebp,[esp + 16]
		test	cs:[dpmiType],1
		jz		sswitch16
		; 
		; ebp better be aligned at this point...
		;
        mov ds,[ebp + 8 + 16 + 4]
        ; we have to handle PMODE/W differently
        ; because its exception mechanism is non-conformant
        ; basically for pmode/w there will be an interrupt frame 
        ; just below the SS:ESP stored in the exception frame;
        ; if that frame's return address is the same as the return
        ; address in the exception frame we have pmodew.  pmodew
        ; will ignore changes to the exception frame so we have to
        ; go to the interrupt frame to make changes...
        mov ax,ss
        mov bx,ds
        cmp ax,bx
        mov ebx,[ebp + 8 + 16]
        jnz notpmw
        mov eax,[ebx - 8]
        cmp eax,[ebp + 8 + 8]
        jnz notpmw
        mov eax,[ebx - 12]
        cmp eax,[ebp + 8 + 4]
        jnz notpmw
        ; if we get here it is pmode/w
        and word ptr [ebx - 4], 0feffh
        mov word ptr [ebx - 12], offset resync
		mov word ptr [ebx-10],0
        mov [ebx - 8],cs
notpmw:
		assume ds:_text
		mov	ds,cs:[codeAlias]
        mov eax,[ebp - 4]
		shr	eax,16
        mov [xceptretval],ax 
        add ebp, 8
        mov eax,[ebp]
        mov [xceptxcept],eax 
        mov eax,[ebp+4]
        mov [xceptip],eax 
        mov eax,[ebp+8]
        mov [xceptcs],eax 
        mov eax,[ebp+12]
        mov [xceptflags],eax
        
        and word ptr [ebp + 12], 0feffh
        mov word ptr [ebp +4], offset resync
		mov word ptr [ebp + 6] , 0
        mov [ebp + 8],cs
        pop ebx
        pop ebp
		pop eax
		pop ds
		add esp,2
		db	066h
		retf
		assume ds:nothing
resync:
        push cs:[xceptflags]
        push cs:[xceptcs]
        push cs:[xceptip]
        push cs:[xceptxcept]
        push cs:[xceptretval]		
        ret
sswitch16:
        mov ds,[bp + 4 + 8 + 2]
        ; we have to handle PMODE/W differently
        ; because its exception mechanism is non-conformant
        ; basically for pmode/w there will be an interrupt frame 
        ; just below the SS:ESP stored in the exception frame;
        ; if that frame's return address is the same as the return
        ; address in the exception frame we have pmodew.  pmodew
        ; will ignore changes to the exception frame so we have to
        ; go to the interrupt frame to make changes...
        mov ax,ss
        mov bx,ds
        cmp ax,bx
        mov bx,word ptr [bp + 4 + 8]
        jnz notpmw16
        mov ax,word ptr [bx - 4]
        cmp ax,[bp + 4 + 4]
        jnz notpmw16
        mov ax,[bx - 6]
        cmp ax,[bp + 4 + 2]
        jnz notpmw16
        ; if we get here it is pmode/w
        and word ptr [bx - 2], 0feffh
        mov word ptr [bx - 6], offset resync16
        mov [bx - 4],cs
notpmw16:
		mov	ds,cs:[codeAlias]
		assume ds:_text
        movzx eax,word ptr [bp - 2]
        mov [xceptretval],ax 
        add bp, 4
        movzx eax,word ptr [bp]
        mov [xceptxcept],eax 
        movzx eax,word ptr [bp+2]
        mov [xceptip],eax 
        movzx eax,word ptr [bp+4]
        mov [xceptcs],eax 
        movzx eax,word ptr [bp+6]
        mov [xceptflags],eax
        
        and word ptr [bp + 6], 0feffh
        mov word ptr [bp + 2], offset resync16
        mov [bp + 4],cs
        pop ebx
        pop ebp
		pop eax
		pop ds
		add esp,2
		retf
		assume ds:dgroup
resync16:
        push word ptr cs:[xceptflags]
        push word ptr cs:[xceptcs]
        push word ptr cs:[xceptip]
        push word ptr cs:[xceptxcept]
        push word ptr cs:[xceptretval]
		ret
stackswitch ENDP
getsel16 PROC
		push	bx
		mov	ax,0ah
		mov	bx, cs
		int 31h
		mov		bx,ax
		pop		dx
		push	bx
		sub		cx,cx
		shld cx,dx,4
		shl dx,4
		
		mov	ax,07h
		int	31h
		
		pop ax
		ret
getsel16 ENDP
dpmiCleanup PROC
		
		mov bx,cs:[codeAlias]
		mov	ax,1
		int 31h
		mov	bx,cs:[dataSelector]
		mov	ax,	1
		int	31h
		mov	bx,cs:[allSelector]
		mov	ax,	1
		int	31h
		mov	bx,cs:[dpmiIntPage]
		mov	ax,	1
		int	31h
		mov	bx,cs:[dpmiStackSeg]
		mov	ax,	1
		int	31h
		mov	bx,cs:[dpmiHistSeg]
		mov	ax,	1
		int	31h
		mov	bx,cs:[dpmiSymSeg]
		mov	ax,	1
		int	31h
		mov	bx,cs:[utilitySelector]
		mov	ax,	1
		int	31h
		mov	bx,cs:[codesel32]
		mov	ax,1
		int 31h
		mov	bx,cs:[dpmiSwiftSeg]
		mov	ax,1
		int 31h
		ret
dpmiCleanup ENDP
        end