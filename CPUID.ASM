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
; cpuid.asm
;
; Function: Generic CPU identification and display
;
include eprints.inc
include iwindow.inc
include einput.inc
	.model small
	.586
;cpuid	macro
;	db	0fh,0a2h
;endm
	extrn optfs : byte, w_cmdset : PROC
	public	checkcpu, cpumodel, cpufeatures
	PUBLIC  docpuid

	.data
cpufeatures	dd	0	;holds features available
cpumodel	db	0	;model (3,4,5,6 etc.)
cputypes db	"386",0,"486",0,"Pentium",0
	db	"Pentium Pro",0,"786",0,"886",0,"986",0
vibuf   db      13 DUP (0)
opttab  db      "FPU ",0,"VME ",0,"DE  ",0,"PSE ",0,"TSC ",0
        db      "MSR ",0,"PAE ",0,"MCE ",0,"CX8 ",0,"APIC",0,"RES1",0
        db      "SEP ",0,"MTRR",0,"PGE ",0,"MCA ",0,"CMOV",0
        db      "PAT ",0,"PSE ",0,"PSN ",0,"CLFS",0,"RES2",0,"DS  ",0
        db      "ACPI",0,"MMX ",0,"FXSR",0,"SSE ",0,"SSE2",0
        db      "SS  ",0,"HTT ",0,"TM  ",0,"RES3",0,"PBE ",0
tlbtab  db      0,"Null Descriptor",0
        db      1,"Instruction TLB, 4K/4Way/32 entries",0
        db      2,"Instruction TLB, 4M/4Way/2  entries",0
        db      3,"Data TLB, 4K/4Way/64 entries",0
        db      4,"Data TLB, 4M/4Way/8 entries",0
        db      6,"1st Lvl Instruction Cache, 8K/4Way/32 Byte",0
        db      8,"1st Lvl Instruction Cache, 16K/4Way/32 Byte",0
        db      0AH,"1st Lvl Data Cache, 8K/2Way/32 Byte",0
        db      0CH,"1st Lvl Data Cache, 16K/4Way/32 Byte",0
        db      22H,"3rd Lvl Cache, 512K/4Way/64 Byte",0
        db      23H,"3rd Lvl Cache, 1M/4Way/64 Byte",0
        db      40H,"No second, possibly no 3rd Lvl cache",0
        db      41H,"2nd Lvl Cache 128K/4Way/32 Byte",0
        db      42H,"2nd Lvl Cache 256K/4Way/32 Byte",0
        db      43H,"2nd Lvl Cache 512K/4Way/32 Byte",0
        db      44H,"2nd Lvl Cache 1M/4Way/32 Byte",0
        db      45H,"2nd Lvl Cache 2M/4Way/32 Byte",0
        db      50H,"Instruction TLB, 4K/2M or 4M/64 entries",0
        db      51H,"Instruction TLB, 4K/2M or 4M/128 entries",0
        db      52H,"Instruction TLB, 4K/2M or 4M/256 entries",0
        db      5BH,"Data TLB, 4K/4M/64 entries",0
        db      5CH,"Data TLB, 4K/4M/128 entries",0
        db      5DH,"Data TLB, 4K/4M/256 entries",0
        db      66H,"1st Lvl Data Cache, 8K/4Way/64 Byte",0
        db      67H,"1st Lvl Data Cache, 16K/4Way/64 Byte",0
        db      68H,"1st Lvl Data Cache, 32K/4Way/64 Byte",0
        db      70H,"Trace Cache, 12K/8Way",0
        db      71H,"Trace Cache, 16K/8Way",0
        db      72H,"Trace Cache, 32K/8Way",0
        db      79H,"2nd Lvl Cache 128K/8Way/Sectored/64 Byte",0
        db      7AH,"2nd Lvl Cache 256K/8Way/Sectored/64 Byte",0
        db      7CH,"2nd Lvl Cache 1M/8Way/Sectored/64 Byte",0
        db      82H,"2nd Lvl Cache 256K/8Way/32 Byte",0
        db      83H,"2nd Lvl Cache 512K/8Way/32 Byte",0
        db      84H,"2nd Lvl Cache 1M/8Way/32 Byte",0
        db      85H,"2nd Lvl Cache 2M/8Way/32 Byte",0
        db      0ffh
brandtab db     "Brand ID not supported",0
        db      "Celeron",0
        db      "Pentium III",0
        db      "Pentium III Xeon",0
        db      "Reserved",0
        db      "Reserved",0
        db      "Reserved",0
        db      "Reserved",0
        db      "Pentium 4",0
        db      "Reserved",0
        db      "Reserved",0
        db      "Reserved",0
        db      "Reserved",0
        db      "Reserved",0
        db      "Reserved",0
        db      "Reserved",0
        db      "Reserved",0
typetab db      "Original OEM",0
        db      "Intel Overdrive",0
        db      "Dual Processor",0
        db      "Reserved",0
        

	.code
checkcpu	PROC
;
; 8086 has bits 12-15 of flags stuck on
;
	pushf
	pop	bx
	mov	ax,0fffh
	and	ax,bx
	push	ax
	popf
	pushf
	pop	ax
	and	ax,0f000h
	cmp	ax,0f000h
	jz	failed
;
; 80286 has bits 12-15 of flags stuck off
;
	mov	[cpumodel],2
	mov	ax,0f000h
	or	ax,bx
	push	ax
	popf
	pushf
	pop	ax
	and	ax,0f000h
	jz	failed
;
; Now we have a 386 or better.  On a 386 the AC bit (bit 18)
; may not be toggled
;
	mov	[cpumodel],3
	pushfd
	pop	eax
	cli
	mov	dx,sp
	and	sp,NOT 3
	mov	ebx,eax
	btc	eax,18
	push	eax
	popfd
	pushfd
	pop	eax
	push	ebx
	popfd
	mov	sp,dx
	xor	eax,ebx
	bt	eax,18
	jnc	gotid
;
; Now see if a is a pentium or better.  CPUID flag (bit 21) may not
; be toggled on a 486
	mov	[cpumodel],4
	mov	eax,ebx
	btc	eax,21
	push	eax
	popfd
	pushfd
	pop	eax
	xor	eax,ebx
	bt	eax,21
	jnc	gotid
	
;
; It is a pentium or better
;
; so issue a CPUID instruction (level 1) to get the model # and features dword
;
	push	ebx
	mov	eax,1
	cpuid
	mov	[cpufeatures],edx
	and	ah,15
	mov	[cpumodel],ah
	pop	ebx
gotid:
	push	ebx
	popfd
	clc
	ret
failed:
	push	bx
	popf
	stc
	ret
checkcpu	ENDP
;
onetlb PROC
        push    cx
        cmp     al,0ffh
        jz      notlb
        or      al,al
        jz      notlb
        mov     di,offset tlbtab
otl:
        cmp     byte ptr [di],0ffh
        jz      otu
        cmp     al,[di]
        jz      otg
        inc     di
        push    ax
        sub     al,al
        mov     cx,-1
        repne   scasb
        pop     ax
        jmp     otl
otg:
        mov     bx,di
        inc     bx
        call    dgroupMessage
        call    crlf
        jmp     notlb
otu:
        PRINT_MESSAGE   <"Unknown TLB/Cache type",13,10>
notlb:
        pop     cx
        ret
onetlb ENDP
dumptlb PROC
        push    ebx
        push    ecx
        push    edx
        mov     ecx,4
dtl:
        push    eax
        call    onetlb
        pop     eax
        shr     eax,8
        loop    dtl
        pop     edx
        pop     ecx
        pop     ebx
        ret
dumptlb ENDP

docpuid PROC
        inc     si
        call    wadespace
        jnz     herr
        cld
ifndef NOFS
        test    [optfs],255
        jz      nofsx7
        mov     al,1
        call    w_cmdset
nofsx7:
endif
        call    crlf
        movzx   cx,[cpumodel]
        cmp     cx,5
        jae     okcpuid
	mov	di,offset cputypes ; calculate CPU type message pos
	movzx	cx,[cpumodel]		; program needs a 386+ :)
	sub	cx,3
        jcxz    gotcpu2
	sub	al,al
cpulp2:
	push	cx
	mov 	cx,-1
	repne	scasb
	pop	cx
        loop    cpulp2

gotcpu2:
	mov	bx,di 		; put out CPU type
	call	dgroupMessage     

	call	crlf
cidx:
        clc
        ret
okcpuid:
        .586
        sub     eax,eax
        cpuid
        push    ax
        mov     dword ptr [vibuf],ebx
        mov     dword ptr [vibuf+4],edx
        mov     dword ptr [vibuf+8],ecx
        PRINT_MESSAGE <C_OPTTEXT, "Vendor: ", C_SYMBOL>
        mov     bx,offset vibuf
        call    dgroupMessage
        pop     ax
        cmp     ax,1
        jb      cidx
        push    ax
        mov     eax,1
        cpuid
        push    edx
        push    ebx
        push    eax
        PRINT_MESSAGE <9,C_OPTTEXT,"Processor Type: ", C_SYMBOL>
        pop     ecx
        push    ecx
        mov     di,offset typetab
        shr     cx,12
        and     cx,3
        jcxz    ptg
ptl:
        push    cx
        mov     cx,-1
        repne   scasb
        pop     cx
        loop    ptl
ptg:
        mov     bx,di
        call    dgroupMessage
        call    crlf
        PRINT_MESSAGE <C_OPTTEXT,"Family: ", C_NUMBER>
        pop     eax
        push    eax
        shr     ax,8
        and     ax,15
        call    printByte
        PRINT_MESSAGE <9,9,C_OPTTEXT, "Extended Family: ", C_NUMBER>
        pop     eax
        push    eax
        shr     eax,20
        call    printByte
        call    crlf
        PRINT_MESSAGE <C_OPTTEXT, "Model: ", C_NUMBER>
        pop     eax
        push    eax
        shr     ax,4
        and     ax,15
        call    printByte
        PRINT_MESSAGE <9,9,C_OPTTEXT, "Extended Model: ", C_NUMBER>
        pop     eax
        push    eax
        shr     ax,16
        and     ax,15
        call    printByte
        call    crlf
        PRINT_MESSAGE <C_OPTTEXT, "Stepping: ", C_NUMBER>
        pop     eax
        and     ax,15
        call    printByte
        PRINT_MESSAGE <9,9,C_OPTTEXT, "Branding: ", C_SYMBOL>
        pop     ecx
        push    ecx
        mov     di,offset brandtab
        sub     ch,ch
        jcxz    gbrnd
        sub     al,al
brndl:
        push    cx
        mov     cx,-1
        repne   scasb
        pop     cx
        loop    brndl
gbrnd:
        mov     bx,di
        call    dgroupMessage
        call    crlf
        PRINT_MESSAGE <C_OPTTEXT, "CLFLUSH size: ", C_NUMBER>
        pop     eax
        push    eax
        shr     ax,8
        sub     ah,ah
        call    printByte
        PRINT_MESSAGE <9,C_OPTTEXT,"Logical processors: ", C_NUMBER>
        pop     eax
        push    eax
        shr     eax,16
        sub     ah,ah
        call    printByte
        PRINT_MESSAGE <9,C_OPTTEXT, "Local APIC id: ", C_NUMBER>
        pop     eax
        shr     eax,24
        sub     ah,ah
        call    printByte
        call    crlf

        PRINT_MESSAGE <13,10,C_OPTTEXT, "Options:  ">
        pop     eax
        sub     ebx,ebx
olp:
        shr     eax,1
        jnc     notnow
        push    eax
        push    ebx
		mov		dl,C_RESERVEDWORD
		call	PutChar
        lea     ebx,[ebx*4 + ebx + opttab]
        call    dgroupMessage
        mov     dl,','
        call    putchar
        pop     ebx
        pop     eax
notnow:
        inc     ebx
        cmp     ebx,32
        jl      olp
        call    crlf
        call    crlf
        pop     ax
        cmp     ax,2
        jb      cidx
        PRINT_MESSAGE <C_OPTTEXT, "CACHE/TLB:", C_RESERVEDWORD, 13,10>
        mov     eax,2
        cpuid
        push    eax
tlblp:
        or      al,0ffh
        test    eax,eax
        js      tlbnoeax
        call    dumptlb
tlbnoeax:
        mov     eax,ebx
        test    eax,eax
        js      tlbnoebx
        call    dumptlb
tlbnoebx:
        mov     eax,ecx
        test    eax,eax
        js      tlbnoebx
        call    dumptlb
tlbnoecx:
        mov     eax,edx
        test    eax,eax
        js      tlbnoebx
        call    dumptlb
tlbnoedx:

        pop     eax
        dec     al
        jz      tlbx
        push    eax
        mov     eax,2
        cpuid
        jmp     tlblp
tlbx:
		mov		dl,C_DEFAULT
		call	PutChar
        clc
        ret
        .386
herr:
		stc
		ret
docpuid ENDP
	END
