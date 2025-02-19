;
; simple test program to illustrate RM32 code segment support
;
        .model small
        .386p
        .stack 1024

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
rmidt   db      0ffh,3,0,0,0,0                  ; our IDT
inCS32  db      0
        dw      seg32
oldflat0 db	0	; echoes flat0 option so we can leave segs alone
			; on successive ?o if they change them

route   dd      offset _text:cs32rundown

seg32 segment para USE32 "SEG32"
        assume  cs:seg32
cs32rundown2 PROC
        mov     byte ptr es:[0ah],44h
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
        mov     byte ptr es:[2],44h
        db      0eah
        dd      offset seg32:runupcont2
        dw      seg32
runupcont2:
        mov     byte ptr es:[4],44h
        lgdt    fword ptr [oldgdt]
	pop	ds		; Load DS
        iret
runupcont1 ENDP
temp1 PROC
        mov     eax,22
        mov     ebx,44
        mov     ecx,66
        ret
temp1 ENDP
temp PROC
        mov     edi,22113388h
        call    temp1
        mov     ecx,44
        ret
temp ENDP

r32main PROC
        int 3
        mov     byte ptr es:[6],44h
        mov     eax,4422h
        call    temp
        mov     dword ptr es:[0],offset temp
        call    dword ptr [es:0]
        mov     eax,44444444h
        mov     ebx,2222h
        mov     cx,2132h
        db      0eah
        dw      offset _text:r32x,0
        dw      _text
r32main ENDP

seg32   ENDS
        .code
;
;
; init flat real mode
;
initflatreal PROC
        smsw    ax              ; test if in a shell
        test    ax,1
        jnz     ifr_err         ; err if so
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
ifrx:
	ret
ifr_err:
        ret
initflatreal ENDP
;
; reset descriptors for real mode
;
rundownflatreal PROC
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
        sub     eax,eax
	mov	ax,ds
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
        db      0eah
        dd      offset seg32:cs32rundown2
        dw      seg32
cs32rundown ENDP
cs32runup PROC
        cli
        sgdt    fword ptr [oldgdt]
        lgdt    fword ptr [gdtp]
        mov     [incs32],0
        pushfd
        push    0
        push    seg32
        mov     eax,offset seg32:r32main
        push    eax
        push    0
        push    ds
        mov     eax,cr0
        inc     eax
        mov     cr0,eax
        mov     byte ptr es:[0],44h
        db      066h,0eah            ; jump to classic pmode code seg
        dd      offset seg32:runupcont1
        dw      18h

cs32runup ENDP
rundowncont1    PROC
        mov     eax,CR0
        dec     eax
        mov     CR0,eax
        mov     byte ptr es:[0ch],44h
        db      0eah
        dw      offset _text:rundowncont2
        dw     _text
rundowncont2:
        mov     [incs32],1
        lgdt    fword ptr [oldgdt]
        lidt    fword ptr [rmidt]
        mov     byte ptr es:[0eh],44h
        pop     eax
        pop     ds
        add     sp,4
        ret
rundowncont1    ENDP

start:
        mov     ax,dgroup
        mov     ds,ax
        mov     ax,0b800h
        mov     es,ax
        call    cs32init
        call    cs32runup
r32x:
;        mov     byte ptr es:[8],44h
        db      0ffh,15h
        dw      offset route
        dw      0
        mov     ah,4ch
        int     21h
        end start