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
; RM32.ASM
;
; Function: RM32 Switch functions/ A20 line handling
;
	;MASM MODE
	.MODEL SMALL
	.386p

include  iversion.inc
include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include  ebreaks.inc 
include  eints.inc
include  elogging.inc
include  eregs.inc
include  eoptions.inc

        public initflatreal, rundownflatreal
        public incs32
        public cs32init, cs32runup,cs32rundown
        public endofcode

        .data
;
; gdt for flat real mode
;
gdt	db	8 DUP (0)			;null entry  SEL 0
	db	0ffh,0ffh,0,0,0,92h,0cfh,0	;32-bit dseg SEL 8h
	db	0ffh,0ffh,0,0,0,92h,0,0		;16-bit dseg SEL 10h
        db      0ffh,0ffh,0,0,0,9ah,0cfh,0      ;32-bit cseg SEL 18h
        db      0ffh,0ffh,0,0,0,9ah,0,0         ;16-bit cseg SEL 20h
gdtp    dw      27h,0,0                         ;size of gdt and its pointer
oldgdt  db	6 DUP (?)			;their GDT
oldidt  db      6 DUP (?)
rmidt   dw      03ffh,0,0                       ; our IDT
oldflat0 db	0	; echoes flat0 option so we can leave segs alone
			; on successive ?o if they change them
        .code
inCS32  db      0
ifdef RAWA20
;
; Routine to wait till KB controller not busy
;
kb_busy proc
    xor cx,cx           ; Loop 65536 times
kb_bs2:
    in al,64h           ; Get status
    jmp $+2
    jmp $+2
    test al,2           ; See if busy
    jz kb_busy_done     ; Not busy any more
    loop kb_bs2
    stc
    ret
kb_busy_done:
    clc
    ret
kb_busy endp
;
; Routine to wait till KB data buffer empty
;
kb_writewait proc
    xor cx,cx           ; Loop 65536 times
kb_rd2:
    in al,64h           ; Get port status
    test al,2           ;
    jz short kb_writewait_done  ; Quit if buffer empty
    loop kb_rd2         ; Wait a while
    stc                 ; Error
    ret
kb_writewait_done:
    clc
    ret
kb_writewait endp
;
; Routine to wait till KB data buffer fll
;
kb_readwait proc
    xor cx,cx           ; Loop 65536 times
kb_rdrd2:
    in al,64h           ; Get port status
    test al,1           ;
    jnz short kb_readwait_done  ; Quit if buffer empty
    loop kb_rdrd2               ; Wait a while
    stc                 ; Error
    ret
kb_readwait_done:
    mov cx,32           ; Wait for controller to set data
delay:
    jmp $+2
    jmp $+2
    loop delay          ;
    clc
    ret
kb_readwait endp
;
; Routine to turn on A20 line
;
seta20  proc
    cli                 ; Don't want a keypress now!
    call kb_busy        ; Wait while busy
    jc short error              ;
    mov al,0d0h         ; Command to get port status
    out 64h,al          ;
    call kb_busy        ; Wait while busy
    jc short error    
    call kb_readwait    ; Wait for it to put the char there
    jc short error
    in al,60h           ; Get the data
    or al,2             ; Set the A20 bit
    xchg al,ah          ; Data to ah
    call kb_busy        ; Wait while busy
    jc short error
    mov al,0d1h         ; Command to put port status
    out 64h,al          ;
    call kb_busy        ; Wait while busy
    jc short error
    call kb_writewait   ; Wait for buffer to empty
    jc short error
    mov al,ah           ; Write the data
    out 60h,al          ;
    clc                 ; No erros
error:
    sti                 ; Keys allowed now
    ret
seta20  endp
endif ; RAWA20
;
;
; init flat real mode
;
initflatreal PROC
	test	[optdwordcommand],1	;check if can init
	jz	ifrx
	test	[optflatinit],1
	jz	ifrx
        smsw    ax              ; test if in a shell
        test    ax,1
        jnz     ifr_err         ; err if so
ifdef RAWA20
        call    seta20          ; same as XMS global alloc
else
        mov     ax,4300h        ; now see if XMS loaded
        int     2fh
        cmp     al,80h
        jnz     ifr_err         ; err if not
        push    es
        mov     ax,4310h        ; get xms driver address
        int     2fh
        push    es              ; put on stack
        push    bx
        mov     ax,300h         ; now global enable HMA
        call    dword ptr [esp] ;
        pop     eax             ; clear stack
        pop     es
                                ; at this point we don't check XMS
                                ; return stat as it always works :)
endif
	push	ds
	push	es
        push    fs
        push    gs
	sgdt	fword ptr [oldgdt]	;get our gdt
	lgdt	fword ptr [gdtp]	;flat real mode in FS
	mov	eax,CR0
	inc	eax
	mov	CR0,EAX
	mov	bx,8			
	mov	ds,bx
	mov	es,bx
	mov	fs,bx
        mov     gs,bx
	dec	eax		; back to real mode
	mov	CR0,eax
	lgdt	fword ptr [oldgdt]	;reload their GDT
        pop     gs
        pop     fs
	pop	es
	pop	ds
	test	[optflat0],1
	jz	ifrx2
	test	[oldflat0],1
	jnz	ifrx2
	mov	[RegdumpDS],0
	mov	[RegdumpES],0
	mov	[RegdumpFS],0
	mov	[RegdumpGS],0
	; leaves SS and CS alone so we can run programs :).
ifrx2:
	mov	al,[optflat0]
	mov	[oldflat0],al
ifrx:
	ret
ifr_err:
        PRINT_MESSAGE	<13,10,"Error: in DOS shell or XMS not available">
        mov     [optflatinit],0
        ret
initflatreal ENDP
;
; reset descriptors for real mode
;
rundownflatreal PROC
	test	[optdwordcommand],1	;check if can init
	jz	rfrx
	test	[optflatinit],1
	jz	rfrx
;
; we don't have to do lots of checking as the flatinit flag would have
; been cleared if we couldn't make the first transition...
;
	push	ds
	push	es
        push    fs
        push    gs
	sgdt	fword ptr [oldgdt]	;get our gdt
	lgdt	fword ptr [gdtp]	;flat real mode in FS
	mov	eax,CR0
	inc	eax
	mov	CR0,EAX
	mov	bx,16
	mov	ds,bx
	mov	es,bx
	mov	fs,bx
        mov     gs,bx
	dec	eax		; back to real mode
	mov	CR0,eax
	lgdt	fword ptr [oldgdt]	;reload their GDT
        pop     gs
        pop     fs
	pop	es
	pop	ds

rfrx:
	ret
rundownflatreal ENDP

cs32init PROC
        mov     eax,ds
	shl	eax,4
	mov	bx,offset gdt
	movzx	ebx,bx
	add	eax,ebx
	mov	dword ptr [gdtp+2],eax	;save old gdt
        mov     eax,cs
        shl     eax,4
        mov     byte ptr [gdt + 22h],al
        mov     byte ptr [gdt + 23h],ah
        shr     eax,16
        mov     byte ptr [gdt + 24h],al
        mov     ax,SEG32
        shl     eax,4
        mov     byte ptr [gdt + 1ah],al
        mov     byte ptr [gdt + 1bh],ah
        shr     eax,16
        mov     byte ptr [gdt + 1ch],al
        ret
cs32init ENDP
cs32rundown PROC
        cli
        db      0eah                    ; we are actually in 32-bit code here
        dd      offset seg32:cs32rundown2
        dw      seg32
cs32rundown ENDP
cs32runup PROC
        test    [incs32],1
        jnz     okrunup
        ret
okrunup:
        add     sp,2            ; dump return address
        cli
        lidt    fword ptr [oldidt]
        sgdt    fword ptr [oldgdt]
        lgdt    fword ptr [gdtp]
        mov     [incs32],0
        push    eax
        push    0
        push    [RegDumpCS]
        push    [RegDumpEIP]
        push    0
        push    [RegDumpDS]
        mov     eax,cr0
        inc     eax
        mov     cr0,eax
        db      066h,0eah            ; jump to classic pmode code seg
        dd      offset seg32:runupcont1
        dw      18h

cs32runup ENDP
rundowncont1    PROC
        mov     eax,CR0
        dec     eax
        mov     CR0,eax
        db      0eah
        dw      offset _text:rundowncont2
        dw      _text
rundowncont2:
        mov     [incs32],1
        sidt    fword ptr [oldidt]
        lgdt    fword ptr [oldgdt]
        lidt    fword ptr [rmidt]
        pop     eax
        pop     ds
        add     sp,4
        ret
rundowncont1    ENDP
;
;
;
seg32 segment para USE32 "SEG32"
        assume  cs:seg32
cs32rundown2 PROC
        push    ds
        push    eax
        mov     eax,dword ptr [esp+8]   ; convert the ret to word size
        mov     word ptr [esp+10],ax

        mov     eax,dgroup
        mov     ds,eax
        sgdt    fword ptr [oldgdt]
        lgdt    fword ptr [gdtp]
        mov     eax,CR0
        inc     eax
        mov     CR0,eax
        db      0eah
        dd      offset _text:rundowncont1
        dw      20h
cs32rundown2 ENDP

runupcont1 PROC
        mov     eax,cr0
        dec     eax
        mov     cr0,eax
        db      0eah
        dd      offset seg32:runupcont2
        dw      seg32
runupcont2:
	mov	es,[RegdumpES]
	mov	fs,[RegdumpFS]
	mov	gs,[RegdumpGS]
	mov	eax,[RegdumpEAX]	; Load regs
	mov	ebx,[RegdumpEBX]	;
	mov	ecx,[RegdumpECX]	;
	mov	edx,[RegdumpEDX]	;
	mov	esi,[RegdumpESI]	;
	mov	edi,[RegdumpEDI]	;
	mov	ebp,[RegdumpEBP]	;
        lgdt    fword ptr [oldgdt]
	pop	ds		; Load DS
        iret
runupcont1 ENDP
endofcode:
seg32   ENDS
        end
