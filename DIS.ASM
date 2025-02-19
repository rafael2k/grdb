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
; dis.asm
;
; Function: patch the dissassembly code together, display the output
;	handle disassembler commands
;
	;MASM MODE
	.model small
	.386

include  eprints.inc 
include  ioperand.inc
include  eoperand.inc 
include  iopcodes.inc
include  eopcodes.inc 
include  emtrap.inc 
include  einput.inc 
include  eoptions.inc
include  iwindow.inc
include  esymbol.inc
include  eints.inc
include edpmi.inc
include iasm.inc
include easm.inc
        PUBLIC  diss,DisOneLine, DisWithAddr, rediss
		public startingDisAddr, disAssemblySeg
        extrn w_setwind : PROC, optfs : BYTE
        extrn wnd_asm : windstr

DEFAULTBYTES = 32		; max number of bytes/line (should be 16)

	.data
  EXTRN source : OPERAND
  EXTRN dest : OPERAND

startingDisAddr	dd	0	;current disassembly address
endningDisAddr	dd	?	;end of disassembly
extraBytes	dw	0	;number of overflow bytes, e.g. if instruction
				;was more than five bytes we need more lines
DisassemblySeg	dw	0	;disassembly segment
DisWithAddr     db      0       ; put an address out to right of disassemble line
ssbase          db      0       ; if SS is default reg
ucr             db      13

	.code

DisplayMemData PROC
		test	[inDPMI],1
		jz		notdpmi
		ret
notdpmi:
		cli
		call	swapintpage
        push    di
        push    si
        mov     [ssbase],0
        lea     bx,[source]
        cmp     [bx+OPERAND.CODE],OM_BASED
        jz      gotbasescale
        cmp     [bx+OPERAND.CODE],OM_ABSOLUTE
        jz      gotabs
        lea     bx,[dest]
        cmp     [bx+OPERAND.CODE],OM_BASED
        jz      gotbasescale
        cmp     [bx+OPERAND.CODE],OM_ABSOLUTE
        jz      gotabs
done:
        pop     si
        pop     di
		call	swapintpage
		sti
        ret
gotabs:
        mov     eax,[bx+OPERAND.ADDRESS]
        jmp     gotaddr
gotbasescale:
        bt      [bx+OPERAND.OEFLAGS],OMF_SCALED
        jnc     baseonly
; must be a 32 bit op - is scaled
        sub     edx,edx
        mov     al,[bx + OPERAND.THEREG]
        cmp     al,255
        jz      nobase
        cmp     [bx + OPERAND.THEREG],4
        jz      ssbased2
        cmp     [bx+operand.THEREG],5
        jnz     notssbased2
ssbased2:
        inc     [ssbase]
notssbased2:
        movzx   di,[bx+OPERAND.THEREG]
        shl     di,2
        mov     edx,[RegDumpEAX+di]
nobase:
        movzx   di,[bx + OPERAND.SCALEREG]
        shl     di,2 
        mov     eax,[RegDumpEAX+di]
        mov     cl,[bx+OPERAND.SCALE]
        shl     eax,cl
        add     eax,edx
        jmp     basescalejoin
baseonly:
        bt      [bx+OPERAND.OEFLAGS],OMF_ADR32
        jc      baseadr32
; 16 bit base reg
        mov     al,[bx + OPERAND.THEREG]
        or      al,al
        jnz     bo161
        mov     eax,[RegDumpEBX]
        add     ax,word ptr [RegDumpESI]
        jmp     basescalejoin2
bo161:
        cmp     al,1
        jnz     bo162
        mov     eax,[RegDumpEBX]
        add     ax,word ptr [RegDumpEDI]
        jmp     basescalejoin2
bo162:
        cmp     al,2
        jnz     bo163
        mov     eax,[RegDumpEBP]
        add     ax,word ptr [RegDumpESI]
        inc     [ssbase]
        jmp     basescalejoin2
bo163:
        cmp     al,3
        jnz     bo164
        mov     eax,[RegDumpEBP]
        add     ax,word ptr [RegDumpEDI]
        inc     [ssbase]
        jmp     basescalejoin2
bo164:
        cmp     al,4
        jnz     bo165
        mov     eax,[RegDumpESI]
        jmp     basescalejoin2
bo165:
        cmp     al,5
        jnz     bo166
        mov     eax,[RegDumpEDI]
        jmp     basescalejoin2
bo166:
        cmp     al,6
        jnz     bo167
        mov     eax,[RegDumpEBP]
        inc     [ssbase]
        jmp     basescalejoin2
bo167:
        mov     eax,[RegDumpEBX]
basescalejoin2:
        movzx   eax,ax ;
        jmp     basescalejoin
baseadr32:
        cmp     [bx + OPERAND.THEREG],4
        jz      ssbased
        cmp     [bx+operand.THEREG],5
        jnz     notssbased
ssbased:
        inc     [ssbase]
notssbased:
        movzx   di,[bx+OPERAND.THEREG]
        shl     di,2
        mov     eax,[RegDumpEAX+di]
basescalejoin:
        add     eax,[bx+OPERAND.ADDRESS]
gotaddr:
        mov     dl,[ssbase]
        or      dl,dl
        mov     dl,SG_DS
        jz      ganotss
        mov     dl,SG_SS
ganotss:
        test    [segs],3fh
        jz      gotseg
        mov     dl,byte ptr [segs]
gotseg:
; at this point EAX has the address and DX has the seg mask
        test    [optflatinit],255
        jz      limit
		call	bit32Address;
        jnz     nolimit
limit:
        cmp     eax,0ffffh
        ja      done
nolimit:
        sub     si,si
fsl:
        shr     dl,1
        jc      gotseg2
        add     si,2
        jmp     fsl
gotseg2:
        
        add     ax,3
        push    es
        mov     es,[si+RegDumpES]
        mov     dl,es:[eax]
        shl     edx,8
        dec     ax
        mov     dl,es:[eax]
        shl     edx,8
        dec     ax
        mov     dl,es:[eax]
        shl     edx,8
        dec     ax
        mov     dl,es:[eax]
        mov     cx,si
        shr     cx,1
        pop     es
        pop     si
;
; this is where we actually draw it
;
        push    edx
        push    eax
        push    cx
        mov     al,TAB_DISPOS
        call    TabTo
        pop     cx
        or      al,1
        call    GetSeg
        mov     byte ptr [si],'['
        inc     si
        pop     eax     
        mov     di,bx
        call    putword
        mov     byte ptr [si],']'
        inc     si
        mov     byte ptr [si],'='
        inc     si
        pop     eax
        bt      [bx+OPERAND.oeflags],OMF_BYTE
        jnc     nbyte
        call    putbyte
        jmp     gse
nbyte:
        call    putwordox
gse:
        mov     byte ptr [si],0
        pop     di
		call	swapintpage
		sti
        ret        
                
        
DisplayMemData ENDP
;
; Get a dissassembled line of code
; INPUT: DI points to 256-byte buffer in caller's stack frame
;	Remember that DS=SS during this process
;	SI appears to point to the code to disassemble
;
;	oldposition EQU bp - 4	;beginning of bytes for line
;	put	EQU bp -6	;unused
;	bytestomove EQU bp - 8	;number of bytes to put in hex dump portion
				;of line
isNewLine	EQU	[bp-2]	;set to true if we are doing an overflow line
oldposition	EQU	[bp-6]	;beginning of bytes for line
put		EQU	[bp-8]	;unused
bytestomove	EQU	[bp-10]	;number of bytes to put in hex dump portion
				;of line
GetCodeLine	PROC
	ENTER	10,0	       		;8 bytes of automatic space
	mov	WORD PTR isNewLine,TRUE ; Assume it has an opcode
	mov	BYTE PTR [di],0		; Clear output buffer
	mov	oldposition,esi		; Current position
	test	extrabytes,0FFh		; See if still printing bytes
	jz	short notextra		; from last instruction

;Only 5 code bytes fit on a line before the mnemonics, so if this instruction
;had >5 bytes, we need to stick them on another line by themselves. In this
;case, we already snagged them, and I guess DI points to them.  So we add
;the number of additional bytes to our pointer to the input, then exchange
;this with the buffer pointer
;  The implication here is that the entire opcode has been disassembled
;and converted to mnemonics, but defninitely not clear yet just exactly
;where the extra opcode bytes get displayed.  Right here, we tab over to
;a new position and zero out the buffer beyond those bytes.

	movzx	eax,extrabytes
	add		esi,eax		; New position to edi
	xchg	esi,edi			;

;Now, SI points into the buffer at a location just past the extra bytes. We
;put a 0 into the buffer for reasons unknown right now, then call TabTo.
;AHA, TabTo calls strlen, which will return a string length of 0 since SI
;points to a 0, and therefore we get a full tab. TabTo stuffed the
;intervening positions with spaces, and terminated them with 0. But we
;overwrite that and the next 15 buffer positions with 0 anyway.

	mov byte ptr [si],C_CODEBYTES
	inc si
	mov	BYTE PTR [si],0		; Clear buffer
	mov	al,10			; Tab to pos 14
	call	TabTo			; by stuffing spaces into the buffer
	xchg	esi,edi			; edi = buffer again now
	push	di			;save buffer position
	mov	cx,4			; next four DWORDS = 0;
	sub	eax,eax			;
	rep	stosd			; Store the dwords
	pop	di			;and point at 16 0's
	mov	WORD PTR isNewLine,False; Doesn't have an opcode
	jmp	btm

;OK, we aren't doing leftover stuff from the prior call.

notextra:
	mov	eax,code_address		; Get code address
	cmp	eax,endningDisAddr			; See if done
	jnc	endcodeline		; Quit if nothing left
	xchg	esi,edi			; esi = buffer now
	push	si			;save buffer address
	mov BYTE PTR [si],C_ADDRESS
	inc	si
	mov	ax,fs			;get segment
	call	putword			;build that into buffer
	mov	BYTE PTR [si],':'	; Print ':' in buffer
	inc	si			;go past the colon
	mov	eax,code_Address		; Get code address
	test	cs:[inDPMI],1
	jz		adrword
	test	cs:[dpmiType],1
	jz		adrword
	call	putdword
	jmp		adrjn
adrword:
	call	putword			; Print it out in buffer
adrjn:
	mov	BYTE PTR [si],' '	; Put a space
	inc	si			;go past the space
	mov BYTE PTR [si],C_CODEBYTES
	inc si
	mov	BYTE PTR [si],0		; Put an end-of-buffer
	pop	ax			;restore the buffer address into EAX
	xchg	si,ax			;now put it into ESI, EAX has new ptr
	push	ax			;save new pointer
        mov     al,25                   ; Tab to pos 29
		test	cs:[indpmi],1
		jz		a25ok
		test	cs:[dpmitype],1
		jz 		a25ok
		add		al,4
a25ok:
	call	TabTo			;stuff with spaces

;XCHG always gives me headaches.  Lets see... TabTo bumped SI up, while EAX
;still holds the buffer position before the spaces TabTo put in there.
;More important, the prior position is on the stack, since we are about to
;blow EAX at ReadOverrides. This old position (just after the offset) will
;eventually be popped into EDI.
;  Now DI points to the post-spaces position, and SI points to whatever DI
;pointed to.  This requires a careful trace, so:
;1) DI entered this routine pointing to the 256-byte buffer on the stack
;2) Then, it was exchanged, so DI pointed to the code to disassemble
;3) Now, di points back into the buffer and SI points to the code to dis

	xchg	esi,edi			; edi = buffer beyond spaces
	call	ReadOverrides		; Read any overrides
	call	FindOpcode		; Find the opcode table

;The prior two calls moved SI past this opcode, which was consumed and
;translated. NOW we point SI back into the buffer and DI at the code
;to disassemble.

	xchg	esi,edi			; esi = buffer, di=code
	jnc	short gotopcode		; Got opcode, go format the text

;If the opcode was unrecognised, we need to just DB this byte and try again
;to find the start of an opcode on the next byte until we are back into
;some kind of sync again.

	push	si			; Else just put a DB
	mov	ax,"db"			;opcode not in table, could be new
	call	put2			; CPU type
	pop	si			;restore position before 'db'
        mov     al,TAB_ARGPOS           ; Tab to the arguments=12+4?
	call	TabTo			;stuff with spaces
	mov	al,fs:[edi]		;Get next code byte into AL
	inc	edi			;bump code pointer
	mov byte ptr [si],C_NUMBER
	inc	si
	call	putbyte			;cvt to ASCII and stick in bufer
	mov	BYTE PTR [si],0		; End the buffer
	xchg	esi,edi			;DI=buffer, SI=code
	pop	di			;address just past offset of address
	jmp	short btm		; Go do the byte dump

;If we got here, the opcode was recognized.  Right here:
;SI=buffer pointer, DI=code pointer

gotopcode:
	push	si			;save buffer pointer
	mov	esi,edi			;point SI at the code
	call	asm32BitMode
	mov		ax,1		; native
	jnz		dodisp
	dec		ax			; real
dodisp:
	call	DispatchOperands	;this probably bumps SI past them
	mov	edi,esi			;so DI is now the code pointer
	pop	si			;restore the buffer pointer
	push	edi			;save the code pointer
	call	FormatDisassembly	;Use the operand parse to format output
	pop	edi			;restore code pointer
        test    [DisWithAddr],1
        jz      noaddr
        dec     [DisWithAddr]
        pop     esi
        push    esi
        call    DisplayMemData
noaddr:
	xchg	esi,edi			;SI now code, DI now bufer

;EAX, pushed far above, contained a pointer into the buffer just past the
;offset part of the address plus 1 space, and points at the 0 following
;that space.

	pop	di			;but so what, since DI now restored
        
btm:

;We already put a 0 in this location way up above, but I guess it won't
;hurt to do it twice, just to make sure...

	mov	BYTE PTR [di],0		; End the buffer

;Ouch. Let's see... SI points to the code we are disassembling whether we
;found a valid opcode or not.  Probably coincidence.

	mov	eax,esi			; Calculate number of bytes to dump
	sub	eax,oldposition		;by subtracting old from new offset
	mov	bytestomove,ax		;and set variable with result
	mov	extrabytes,0		; Bytes for next round = 0
	cmp	WORD PTR bytestomove,5	; See if > 5
	jbe	short notmultiline	; No, not multiline
	mov	ax,bytestomove		; Else calculate bytes left
	sub	al,5			;and save result for next time
	mov	extrabytes,ax	
	mov	WORD PTR bytestomove,5	; Dumping 5 bytes - our max
notmultiline:

;Ouch again. Lets see... SI points to the code, and DI to the buffer, so
;we switch them, DI=code and SI=buffer

	xchg	esi,edi			; esi = buffer
	push	di			; Save code pointer
 	mov	edi,oldposition		; Get original code position
	mov	cx,bytestomove		; Get bytes to move
putlp:
	mov	al,fs:[edi]		; Get a byte
	call	putbyte			; Expand to ASCII
	mov	BYTE PTR [si],' '	; Put in a space
	inc	si			; Next buffer pos
	inc	edi			; Next code pos
	LOOP	putlp			; Loop till done
	xchg	esi,edi			; Restore regs DI=buf, SI=code
	movzx	eax,word ptr bytestomove		; Codeaddress+=bytes dumped
	add	code_address,eax	
endcodeline:
	mov	ax,isNewLine		; Return new line flag
	LEAVE				
	ret
GetCodeLine	ENDP	
;
; Main disassembler
; The user pressed the U command key, followed by ???, then CR.  We are going 
; to disassemble from either where we are, or from the address provided.
;	My guess is that SI points to the input line at the character
; following the U.
;  
;
rediss  PROC
        mov     si,offset ucr
        mov     eax,[RegDumpEIP]
        mov     [StartingDisAddr],eax
        mov     ax,[RegDumpCS]
        mov     [DisassemblySeg],ax
rediss  ENDP
diss	PROC	
	ENTER	256,0			; Buffer = 256 bytes long
ifndef NOFS
        test    [optfs],255
        jz      ndis
        mov     bx,offset wnd_asm
        call    w_setwind
        push    ax
        mov     cx,9
        jmp     cdis
ndis:
        mov     cx,65530
endif
cdis:
	call	WadeSpace		; See if any parms
	jz	short atindex		; No disassemble at index
	call	ReadAddress		; Else read start address into BX
	jc	badargs			; Get out bad args
	mov	eax,DEFAULTBYTES		; Number of bytes to disassemble=32
	add	eax,ebx			; Find end of disassembly
	call bit32Address
	jnz	okadd
	cmp	eax,0fff0h
	jc	okadd			; Seems to be a segment limit
    mov	eax,0FFF0h		; goto end of segment?
okadd:
	mov	endningDisAddr,eax	; Save count? as default
	call	WadeSpace		; See if any more args
	jz	short gotargs		; No, got args
        cmp     al,'l'                  ; length specifier?
        jnz     dissnl
        inc     si
        call    ReadNumber
        jc      short badargs
        add     eax,ebx
        jmp     dissnl2
dissnl:
	call	ReadNumber		; Read the end address
	jc	short badargs           ; Out if bad args
        inc     eax
dissnl2:
	call bit32Address
	jnz	dissnl3
	cmp	eax,0fff0h
	jc	dissnl3			; Seems to be a segment limit
    mov	eax,0FFF0h		; goto end of segment?
dissnl3:
	mov	endningDisAddr,eax			; Save end
	jmp	short gotargs		; We have args
badargs:
ifndef NOFS
        test    [optfs],255
        jz      nrw
        pop     bx
        call    w_setwind
nrw:
endif
	stc				; Error
	LEAVE
	ret
atindex:
	mov	ebx,startingDisAddr	; Get the next address to disassemble
	movzx	edx,DisassemblySeg 	;
	mov	eax,ebx
	or	eax,edx
	jnz	goindex
	mov	ebx,[regDumpEIP]
	mov	dx, [regDumpCS]
goindex:
	mov	eax,DEFAULTBYTES		; Default bytes to disassemble
	add	eax,ebx			;
	mov	endningDisAddr,eax 	; Set up end
	call bit32Address
	jnz	gotargs
	cmp eax,0fff0h
	jbe gotargs
	mov endningDisAddr, 0fff0h
gotargs:
	call	defCS			; get CS segment
	mov	code_address,ebx		; Save code address for printout
ifndef NOFS
        mov     [startingDisAddr],ebx
endif
	mov	esi,ebx			;
	mov	fs,dx			; ES = the seg
	mov	DisassemblySeg,fs		
gcloop:	
	call	scankey
	jnz	dusetadr
        push    cx
        mov     ebx,[code_address]
        mov     dx,fs
        push    es
        call    symLookupByValue
        jc      disnn
        call    crlf
        movzx   cx,byte ptr es:[di+6]
        push    esi
        lea     si,[di+7];
disol:
        lods    byte ptr es:[si]
        mov     dl,al
        call    PutChar
        loop    disol
        pop     esi
        mov     dl,':'
        call    PutChar
ifndef NOFS
        pop     es
        pop     cx
        dec     cx
        jz      dusetadr
        push    cx
        push    es
endif
disnn:
        pop     es
	lea	di,[bp - 256]		; Get the buffer
	call	GetCodeLine		; Get a line of text
	call	crlf
	lea	bx,[bp - 256]		; Print out the text
	call	dgroupMessage
ifndef NOFS
        pop     cx
        dec     cx
        jz      dusetadr
endif
;	cmp	esi,0fff0h
;	jnc	dusetadr2
isdw:
	cmp	esi,endningDisAddr		
        jc      gcloop                  ; Loop if not
	test	extrabytes,0FFFFh	; Loop if not done with dump
	jnz	gcloop			
dusetadr:
ifndef NOFS
        test    [optfs],255
        jnz     nostore
endif
        mov     esi,code_address 
		
	mov	startingDisAddr,esi		
ifndef NOFS
nostore:
        test    [optfs],255
        jz      dxx
        pop     bx
        call    w_setwind
dxx:
endif
	clc
	LEAVE
	ret
dusetadr2:
	sub	esi,esi
	mov	code_address,esi
	jmp	dusetadr
diss	ENDP	
;
; Disassemble one line.  Used by the Reg display command
; INPUT: DX holds segment value (CS)
;	BS holds offset value (IP)
;
DisOneLine	PROC	
	ENTER	256,0			; Space for buffer
	mov		[nolookup],0	; allow name lookups
	push	ebx		 	;save logical IP
	push	dx			;and logical CS
	call	crlf			;so CRLF won't blow them
	pop	dx
	pop	ebx
	mov	ax,1			;move to next position		
	add	eax,ebx			; One byte to disassemble
	mov	endningDisAddr,eax 	;(will disassemble entire instruction)
	mov	code_address,ebx		;save this disassembly address
	mov	fs,dx			;save segment in FS
	mov	esi,ebx			;point to code to disassemble in SI
	mov	startingDisAddr,esi	; Save new starting index
	mov	DisassemblySeg,fs 	;set disassembly segment
dol_loop:
	lea	di,[bp - 256]		;Point DI at buffer to dis into
	call	GetCodeLine		; Get a line of code
	lea	bx,[bp -256]		;point BX at line we created
	call	dgroupMessage		;and put it on the screen
	test	extrabytes,0FFFFh	; See if >5 opcode bytes
	jz dol_x
	call	crlf
	jmp	dol_loop
dol_x:
	clc				; No errors
	mov		[nolookup],0;
	leave
	ret
DisOneLine	ENDP	
END