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
; LOADER.ASM
;
; Function : COM/EXE file loader
;


	.model small
	.386
	public	MakeEmptyProg, userbasepsp, filelen,loadfile,loadcommand,exeflag
	public  ParseProgName,exestats,LoadProgram
        public  lastcs,lastip

include eenv.inc
include emtrap.inc
include edump.inc
include edos.inc
include ememory.inc
include eprints.inc
include einput.inc

headstruct struc
sig	dw	?  	; EXE signature- we exit if not 'MZ'
mlength	dw	?	; length modulo 512
pages	dw	?	; length in pages, rounded UP
relocs	dw	?	; Number of relocation items
headsize dw	?	; Size of header in paragraphs
			; We will later assume this is less than 1000h
			; paragraphs but you probably should fix that
minalloc dw	?	; Minimum memory needed
maxalloc dw	?	; Maximum memory desired
dispss	dw	?	; starting stack
basesp	dw	?	;
checksum dw	?   	; We'll ignore the checksum.  Dos ignores it too
			; if it is zero
baseip dw	?       ; Starting CS:IP
dispcs	dw	?
relocofs dw	?	; Offset to relocation table
overlay dw	?	; I never saw a program with the overlay field set
			; so I don't know what happens here...
headstruct ends
	.data
loadfile	db	80 DUP (?)	;file name
loadcommand	db	128 DUP (?)	;associated command
filelen	dd	0			;length of file
handle	dw	0			;IO handle
exeflag	db	0			;is it EXE loaded as EXE
header	headstruct <>			;EXE file header
userbasepsp dw	0			;their PSP
relox	dd	?			;current relocation value
lastip	dd	0			;last CS:IP from header
lastcs	dw	0

	.code
;
; clear FCBs in PSP
;
InitFCB	PROC
	push	es
	mov	es,[userbasepsp]
	sub	al,al
	stosb
	mov	cx,11
	mov	al,20h
	rep	stosb
	pop	es
	ret
InitFCB	ENDP
;
; create an empty program area
;
MakeEmptyProg PROC
	mov	[filelen],0
	mov	[exeflag],0
	push	si		; refresh env
	call	CopyEnv
	pop	si
	jc	nomem
	mov	bx,-1		; minimum emem needed
	mov	ah,48h
	int	21h
	cmp	al,8
	jnz	nomem
	cmp	bx,200h
	jc	nomem	
	push	bx      	; space for their PSP
	mov	ah,48h
	int	21h
	mov	[userbasepsp],ax
	mov	[userpsp],ax
	mov [userdta],80h
    mov [userdta + 2],ax
	mov	dx,ax		; create it
	mov	ah,26h
	int	21h
	mov	fs,[psp]
	mov	ax,fs:[2]
	mov	fs,[userbasepsp]
	mov	fs:[2],ax
	push	es		; now create a dummy file table
	mov	es,[userbasepsp]
	mov	di,18h
	mov	al,1
	stosb
	stosb
	stosb
	dec	al
	stosb
	inc	al
	inc	al
	stosb
	mov	al,0ffh
	mov	cx,10h
	rep	stosb
	pop	es
	push ds
	lds dx,dword ptr [userdta]	; set their DTA
	mov ah,1ah
	int 21h
	pop ds
	call	SetDebugPSP	; put us back at our PSP/DTA now
	pop	ax
	cmp	ax,1000h        ;initial SP
	mov	bx,0ffeeh
	jnc	meok
	movzx	ebx,ax
	shl	bx,4
	sub	bx,18
meok:
	mov	[RegdumpEIP],0	; init all regs to defaults
	mov	[RegdumpEAX],0
	mov	[RegdumpEBX],0
	mov	[RegdumpECX],0
	mov	[RegdumpEDX],0
	mov	[RegdumpESP],ebx
	mov	[RegdumpEBP],0
	mov	[RegdumpESI],0
	mov	[RegdumpEDI],0
	mov	ax,[userbasepsp]
	mov	[RegdumpCS],ax
	mov	[RegdumpDS],ax
	mov	[RegdumpES],ax
	mov	[RegdumpFS],ax
	mov	[RegdumpGS],ax
	mov	[RegdumpSS],ax
	mov	[indexseg],ax
	mov	[RegdumpEIP],100h
	mov	[index],100h
	mov	word ptr [RegdumpFLAGS],202h ; flags
	mov	word ptr fs:[bx],0
	mov	fs,[userbasepsp]	; set up env seg
	mov	bx,[TgtPgmEnvSeg]
	mov	fs:[2ch],bx
	mov	ax,[userbasepsp]	; tag the arena entries
	mov	bx,ax
	dec	bx
	call	tagarena
	mov	ax,[userbasepsp]
	mov	bx,[TgtPgmEnvSeg]
	dec	bx
	call	tagarena
	mov	di,5ch			; set up FCBs
	call	InitFCB
	mov	di,6ch
	call	InitFCB
	clc
nomem:
	ret
MakeEmptyProg ENDP
;
; throw a file name into an FCB, just for the old days :)
;
tofcb	PROC
	call	WadeSpace
	sub	al,al
	cmp	byte ptr [si+1],':'
	jnz	nodrive
	lodsw
        cmp     al,'a'
        jl      nouc
        xor     al,20h
nouc:
        sub     al,'A'-1
nodrive:
	stosb
	push	si
fxlp:
	lodsb
	cmp	al,':'
	jz	tfcberr
	cmp	al,'\'
	jz	tfcberr
	cmp	al,'/'
	jz	tfcberr
	cmp	al,','
	jz	fxdn
	cmp	al,' '
	jz	fxdn
	or	al,al
	jz	fxdn
	jnz	fxlp
fxdn:
	xchg	[esp],si
	mov	cx,8
mvlp:
	lodsb
	cmp	al,'.'
	jz	dodot
	cmp	si,[esp]
	jnc	tfcbx
	and	al,0dfh
	stosb
	loop	mvlp
wade1:
	lodsb
	cmp	al,'.'
	jz	dodot
	cmp	si,[esp]
	jnc	tfcbx
	jmp	wade1
dodot:
	mov	cl,3
	sub	di,5
	and	di,NOT 7
	add	di,13
ddl:
	lodsb
	cmp	si,[esp]
	jnc	tfcbx
	and	al,0dfh
	stosb
	loop	ddl
tfcbx:
	test	byte ptr [si],0ffh
	jz	tfcberr
	pop	si
	clc
	ret
tfcberr:
        pop     si
        stc
	ret
	
tofcb	ENDP
;
; put a command line in user psp
;
SetUserCommand	PROC
	push	es
	mov	es,[userbasepsp]
	mov	al,1
	mov	cx,80h
	mov	di,80h
	rep	stosb
	mov	di,81h
	mov	si,offset loadcommand
	mov	byte ptr es:[80h],0
	mov	cx,126
cml_lp:
	lodsb
	or	al,al
	jz	cml_dn
	stosb
	
	inc	byte ptr es:[80h]
	loop	cml_lp
cml_dn:
	mov	al,0dh
	stosb
        mov     si,offset loadcommand
	mov	di,05ch
	call	tofcb
	jc	comdone
	mov	di,06ch
	call	tofcb
comdone:
	pop	es
	ret
	
SetUserCommand	ENDP
;
; parse the program name/command line as set in a W/L command
;
ParseProgName	PROC
	lodsb
	cmp	al,' '
	jz	ParseProgName
	dec	si
	mov	es:[loadfile],0
	mov	es:[loadcommand],0
	mov	di,offset loadfile
ppnlp:
	lodsb
	cmp	al,' '
	jz	ppngot
        cmp     al,'/'
        jz      ppngot
	cmp	al,13
	jz	ppcgot
	or	al,al
	jz	ppngot
	stosb
	jmp	ppnlp
ppngot:
	mov	al,0
	stosb
	dec	si
	mov	di,offset loadcommand
ppclp:
	lodsb
	cmp	al,13
	jz	ppcgot
	or	al,al
	jz	ppcgot
	stosb
	jmp	ppclp
ppcgot:
	dec	si
	mov	al,0
	stosb
	push	ds
	push	es
	pop	ds
	push	si
	mov	si,offset loadfile
	call	QualifyName
	pop	si
	pop	ds
	ret	
ParseProgName	ENDP
;
; main program loader
;
LoadProgram	PROC
        mov     [exeflag],0             ; assume com
	push	ax			; unload prog
	call	UnLoadProgram
	pop	ax
	or	ax,ax
	jnz	lcm
	call	LoadExe			; EXE load
	jmp	lpfin
lcm:
	call	LoadCom			; COM load
lpfin:
	jc	lpnomod
	mov	word ptr [RegdumpECX],ax	; set stats
	mov	word ptr [RegdumpECX+2],0
	shr	eax,16
	mov	[RegdumpEBX],eax
	call	SetUserCommand
	mov	si,offset loadfile	; tag arean with prog name
	mov	ax,[userbasepsp]
	mov	bx,ax
	dec	bx
	call	tagarena
	mov	ax,[userbasepsp]
	mov	bx,[TgtPgmEnvSeg]
	dec	bx
	call	tagarena
	call	SetEnvName
	clc
lpnomod:
	ret
LoadProgram	ENDP
;
; Verify size of loaded file
;
VerifySize PROC
        push    es
        push    ecx
        mov     cx,[userbasepsp]
        dec     cx
        mov     es,cx
        movzx   ecx,word ptr es:[3]
        shl     ecx,4
        sub     ecx,100h
        cmp     eax,ecx
        pop     ecx
        pop     es
        jg      vsbad
        clc
        ret
vsbad:
        stc
        ret
VerifySize ENDP

openProgram PROC
	mov ax,3d00h			; Open the file
	mov dx,offset loadfile
	int 21h
	jnc	op_x
	mov si,offset loadfile
	mov ah,'.'
op_l1:
	lodsb
	or	al,al
	jz	op_x1
	cmp al,ah
	jnz	op_l1
	cmp [si],ah
	stc
	jnz	op_x
	inc	si
	jmp	op_l1
op_x1:	; no extension
	dec	si
	mov dword ptr [si],04d4f432eh ; .com
	mov byte ptr [si + 4], 0
	mov ax,3d00h			; Open the file
	mov dx,offset loadfile
	int 21h
	mov byte ptr [si] , 0
	jnc op_x

	mov dword ptr [si],04558452eh ; .exe
	mov byte ptr [si + 4], 0
	mov ax,3d00h			; Open the file
	mov dx,offset loadfile
	int 21h
	mov byte ptr [si] , 0
op_x:
	ret
openProgram ENDP
;
; com file load, just grab the data
;
LoadCom	PROC
	call	openProgram
	mov bx,ax
	jc failure
LoadCom2	PROC
        mov     ax,4202h
	sub	cx,cx
	sub	dx,dx
	int	21h
	jc	failure
        shl     eax,16
        mov     ax,dx
        ror     eax,16
        call    VerifySize
        jc      failure
        mov     ax,4200h
	sub	cx,cx
	sub	dx,dx
	int	21h
	jc	failure
	mov	si,[userbasepsp]
	
	push	ds
	add	si,10h
rdlp:
	mov	ds,si
	mov ax,3f00h			; Read the file
	mov cx,8000h
	sub	dx,dx
	int 21h
	jc failure2
	add	si,800H
	movzx	eax,ax
	add	es:[filelen],eax
	cmp	ax,8000H
	jz	rdlp
	clc

failure2 PROC
	pop	ds
failure PROC
	pushf
	mov ax,3e00h			; close the file
	int 21h
	popf
	jnc	loadok
	mov	[filelen],0
	mov	[exeflag],0
loadok:
	mov	eax,[filelen]
	ret
failure ENDP
failure2 ENDP
LoadCom2 ENDP
LoadCom	ENDP
;
; exe file load
;
LoadEXE	PROC
;
; Open the file
;
	call openProgram
	mov bx,ax
	mov [handle],ax
	jc failure
;
; Read the basic part of the header
;
	mov ax,3f00h			; Read the file
	mov dx,offset header
	mov cx,1ch
	int 21h
	jc failure

        mov     ax,[header.sig]             ; Fail if not an EXE
        cmp     ax,"ZM"
        jnz     LoadCom2
	mov	[exeflag],1
;
; Load exe file
	movzx ecx,[header.pages]		; calculate size of prog
	dec     cx
	shl	ecx,9
	movzx  	eax,[header.mlength]
	add	ecx,eax
	movzx	eax,[header.headsize]
	shl	eax,4
        sub     ecx,eax
        jc      failure
        mov     eax,ecx
        call    VerifySize
	jc	failure
	mov	[filelen],ecx
	mov	ax,[userbasepsp]
	mov	fs,ax
	add	ax,[header.minalloc]
	add	ax,10h
	cmp	fs:[2],ax
	jc	failure

	mov	ax,fs
	dec	ax
	mov	fs,ax
	mov	ax,fs:[3]
	cmp	ax,[header.maxalloc]
	jbe	nomemresize
	mov	bx,[header.maxalloc]
	push	es
	mov	es,[userbasepsp]
	mov	ah,4ah
	int	21h
	pop	es
nomemresize:
	mov	si,[userbasepsp]
	add	si,10h
	
	mov	dx,[header.headsize]
	shl	dx,4
	push ecx				; point at program data
	sub cx,cx
	mov ax,4200h
	mov bx,cs:[handle]
	int 21h
	pop ecx
	jc failure

	push	ds
redlp:
	push	ecx
	mov	ds,si
	mov ax,3f00h			; Read the file
	mov cx,8000h
	sub	dx,dx
	int 21h
	jc failure2
	pop	ecx
	add	si,800h
	sub	ecx,8000h
	jnc	redlp
	pop	ds



	test cs:[header.relocs],-1   	; get out if no relocs
	jz lfexit
	mov	si,[userbasepsp]
	add	si,10h
	sub cx,cx
	mov dx,cs:[header.relocofs]	; position to start of reloc table
	mov ax,4200h
	int 21h
	jc failure

	mov cx,[header.relocs]		; Get number of relocs
	mov bx,[handle]
relolp:
	push cx				; Load a reloc
	mov cx,4
	mov dx, offset relox
	mov ah,3fh
	int 21h
	pop cx
	jc failure

	add word ptr [relox+2],si	; Adjust to phys address
	lfs di,[relox]			; Readjust the reloc
	add fs:[di],si
	loop relolp			; continue till done
lfexit:
	mov	ax,[userbasepsp]
	add	ax,10h
	add	[header.dispcs],ax
	add	[header.dispss],ax
	movzx	eax,[header.baseip]
	mov	[RegdumpEIP],eax
	movzx	eax,[header.basesp]
	mov	[RegdumpESP],eax
	mov	ax,[header.dispcs]
	mov	[RegdumpCS],ax
	mov	ax,[header.dispss]
	mov	[RegdumpSS],ax
	mov	ah,3eh
	int	21h

	mov	eax,[RegdumpEIP]
	mov	[lastip],eax
	mov	ax,[RegdumpCS]
	mov	[lastcs],ax
	mov	eax,[filelen]
	movzx	ebx,[header.headsize]
	shl	ebx,4
	add	eax,ebx
	sub	eax,512
	clc
	ret
LoadEXE	ENDP
;
; used by status screen to display EXE status
;
ExeStats PROC
	test	[filelen],-1
	jz	noexe
	PRINT_MESSAGE	<13,10,"File length: ">
	mov	eax,[filelen]
	call	PrintDWord
	test    [exeflag],0ffh
	jz	noexe
	mov	cx,[userbasepsp]
	add	cx,10h
	PRINT_MESSAGE	<13,10,"CS:IP = ">
	mov	ax,[header.dispcs]
	call	printword
	mov	dl,':'
	call	PutChar
	mov	ax,[header.baseip]
	call	printword
	PRINT_MESSAGE	<13,10,"SS:SP = ">
	mov	ax,[header.dispss]
	call	printword
	mov	dl,':'
	call	PutChar
	mov	ax,[header.basesp]
	call	printword
	PRINT_MESSAGE	<13,10,"minalloc: ">
	mov	ax,[header.minalloc]
	call	printword
	PRINT_MESSAGE	<" maxalloc: ">
	mov	ax,[header.maxalloc]
	call	printword
	PRINT_MESSAGE	<13,10,"relocs: ">
	mov	ax,[header.relocs]
	call	printword

noexe:
	ret
ExeStats ENDP
	end