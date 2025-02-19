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
; SYMBOL.ASM
;
; Function: Handle symbol table functions
;
	;MASM MODE
	.MODEL SMALL
	.386

include einput.inc
include eoptions.inc
include eprints.inc
include emtrap.inc
include edos.inc
include eloader.inc
include elogging.inc
include ememory.inc
include eoptions.inc
include edpmi.inc

        public loadsym,unloadsym,symcmd, symLookupByValue, symname
        public symLookupByName, symReadName
		public nolookup, symseg
		
        .data
symseg  dw      0
symnamebot dw   0
symnametop dw   0
symnameptr dw   0
symcount   dw   0
baseaddr        dw      0
topaddr         dw      0
symfilename db  256 DUP (?)
symsig  db      "SY01"
symsig2 db      4 DUP (0)
stype    db      0
saddr   dd      0
sseg    dw      0
symname db      100 DUP (?)
symname2 db     100 DUP (?)
symModified db     0
nolookup	db	0

        .code
;
; Read a symbol name out of the input stream
;
symReadName2 PROC
        mov     di,offset dgroup:symname2
        jmp     symReadNameExt
symReadName2 ENDP
symReadName PROC
        mov     di,offset dgroup:symname        ; copy symbol name to buffer
symReadName ENDP
symReadNameExt PROC
snl:
        lodsb
        cmp     al,'0'
        jb      eos
        cmp     al,'9'
        ja      chkalpha
snl1:
        stosb
        jmp     snl
chkalpha:
        cmp     al,'_'
        jz      snl1
        and     al,0DFh
        cmp     al,40h
        jc      eos
        cmp     al,'Z'
        jbe     snl1
eos:
        mov     byte ptr [di],0                 ; null term name
        dec     si                              ; point to next character
        ret
symReadNameExt ENDP
;
; get a symbol file name
;
getsymname PROC
        mov     di,offset symfilename
gsn_l:
        lodsb
        cmp     al,0dh
        jz      gsnx
        stosb
        jmp     gsn_l
gsnx:
		sub		al,al
		stosb
        ret
getsymname ENDP
;
; check to make sure we have a symbol file name
;
hasname PROC
        test    [symfilename],255               ; see if there
        jnz     gotname                         ; yes, no message
        PRINT_MESSAGE <13,10,"need file name">
        stc
gotname:
        ret
hasname ENDP
;
; Get the offset and end of the program's primary memory block
;
getloadaddr PROC
		sub		ax,ax
		sub		bx,bx
		test	cs:[inDPMI],1
		jnz		docom
        mov     ax,[userbasepsp]
        dec     ax
        mov     es,ax
        inc     ax
        mov     bx,es:[3]
        test    [exeflag],255
        jz      docom
        add     ax,10h
        sub     bx,10h
docom:
        mov     [baseaddr],ax
        add     ax,bx
        mov     [topaddr],bx
        ret
getloadaddr ENDP
;
; load a symbol vile
;
loadsymfile PROC
        test    [symfilename],255
        jz      lsf_none
        call    getloadaddr
        mov     ax,3d02h
        mov     dx,offset symfilename
        int     21h
        jc      lsf_cantopen
        mov     bx,ax
        mov     ah,3fh
        mov     dx,offset symsig2
        mov     cx,4
        int     21h
        jc      lsf_bad
        mov     eax,dword ptr [symsig]
        cmp     eax,dword ptr [symsig2]
        jnz     lsf_bad
		call	compatibleSymSeg
        mov     es,ax
        sub     di,di
lsflp:
        mov     cx,7
        mov     dx,offset stype
        mov     ah,3fh
        int     21h
        jc      lsf_bad
        or      ax,ax
        jz      lsf_done
        test    [stype],255
        jz      lsf_noadj
        mov     ax,[baseaddr]
        add     [sseg],ax
lsf_noadj:
        mov     cx,1
        mov     dx,offset symname
		movzx	edx,dx
        mov     ah,3fh
        int     21h
        jc      lsf_bad
        movzx   cx,[symname]
        mov     si,cx
        mov     [si+symname],0
        mov     dx,offset symname
        mov     ah,3fh
        int     21h
        jc      lsf_bad
        push    bx
        mov     ebx,[saddr]
        mov     dx,[sseg]
        mov     si,offset symname
        call    symInsert
        pop     bx
        jnc     lsflp
        PRINT_MESSAGE <10,13,"Symbol table too small, truncating symbols">
lsf_done:
        mov     [symModified],0
        mov     ah,3eh
        int     21h
        clc
lsf_none:
        push    ds
        pop     es
        ret
lsf_cantopen:
		push	ds
		pop		es
		PRINT_MESSAGE	<13,10,"Cannot Open: ">
		mov	bx,offset dgroup:symfilename
		call	dgroupMessage
		PRINT_MESSAGE	<" for read access">
		ret
lsf_bad:
        PRINT_MESSAGE <10,13,"Bad symbol file">
        mov     ah,3eh
        int     21h
        stc
        push    ds
        pop     es
        ret
loadsymfile ENDP
;
; save a symbol file
;
savesymfile PROC
        test    [symModified],255
        jz      ssf_none
        test    [symfilename],255
        jz      ssf_none
        call    getloadaddr
        mov     ax,3c00h
		sub		cx,cx
        mov     dx,offset symfilename
		movzx	edx,dx
        int     21h
        jc      ssf_cantopen
        mov     bx,ax
        mov     ah,40h
        mov     dx,offset symsig
        mov     cx,4
        int     21h
		call	compatibleSymSeg
        mov     es,ax
        sub     di,di
ssflp:
        mov     [stype],0
        mov     ax,es:[di+4]
		test	cs:[inDPMI],1
		jnz		ssf_noadj
        cmp     ax,[baseaddr]
        jc      ssf_noadj
        cmp     ax,[topaddr]
        jae     ssf_noadj
        sub     ax,[baseaddr]
        inc     [stype]
ssf_noadj :
        mov     [sseg],ax
        mov     eax,es:[di]
        mov     [saddr],eax
        mov     dx,offset stype 
        mov     cx,7
        mov     ah,40h
        int     21h
        push    ds
        push    es
        pop     ds
        lea     dx,[di+6]
        movzx   cx,byte ptr [di+6]
        inc     cx
        mov     ah,40h
        int     21h
        pop     ds
        call    nextsym
        jc      ssflp
        mov     [symModified],0
        mov     ah,3eh
        int     21h
        clc
ssf_none:
        push    ds
        pop     es
        ret
ssf_cantopen:
		call	printword
		push	ds
		pop		es
		PRINT_MESSAGE	<13,10,"Cannot Open: ">
		mov	bx,offset dgroup:symfilename
		call	dgroupMessage
		PRINT_MESSAGE	<" for write access">
		ret
savesymfile ENDP
;
; unload the symbol section
;
unloadsym PROC
        test    [symseg],-1             ; already unloaded
        jz      notloaded               ; yes exit
        call    savesymfile             ; save it if has a name
        push    es                      ; free the memory
        mov     es,[symseg]
        mov     ah,49h
        int     21h
        pop     es
        mov     [symseg],0              ; reset table pointers
        mov     [symnamebot],0
        mov     [symnametop],0
        mov     [symnameptr],0
notloaded:
        ret
unloadsym ENDP
;
; load the symbol section
;
loadsym PROC
        test    [symseg],-1             ; already loaded
        jnz     noload                  ; yes exit
        movzx   bx,[optsymname]         ; get size
        or      bx,bx                   ; 0 = no table
        jz      noload
        shl     bx,10-4                 ; get len in paragraphs
        mov     ah,48h                  ; allocate a block of memory
        int     21h
        jc      noload                  ; error, exit
        mov     [symseg],ax             ; set up initial pointers
        mov     [symnamebot],0
        mov     [symnameptr],0
        movzx   ax,[optsymname]
        shl     ax,10
        mov     [symnametop],ax
noload:  
        ret
loadsym ENDP
;
; print a symbol value:name pair
;
printval PROC
        mov     ax,es:[di+4]            ; print seg
        call    printword
        mov     dl,':'
        call    putchar
        mov     eax,es:[di]              ; print offs
		call	bit32Address
		jnz		pvdword
        call    printword
		jmp		pvjoin
pvdword:
		call 	printdword
pvjoin:
        mov     dl,' '
        call    putchar
        lea     si,[di+6]               ; point to name and print it
        lods    byte ptr es:[si]
        movzx   cx,al
pvl:
        lods    byte ptr es:[si]
        mov     dl,al
        call    PutChar
        loop    pvl
        ret        
printval ENDP
;
; delete a symbol table entry
;
symClear PROC
        push    bx
        mov     cx,[symnameptr]         ; get length of block to move
        sub     cx,di
        movzx   bx,byte ptr es:[di+6]   ; get length of symbol
        inc     bx
        add     bx,6
        sub     cx,bx                   ; adjust block by symbol size
        mov     si,di                   ; set up pointers
        add     si,bx
        push    ds
		call	compatibleSymSeg
        mov     ds,ax
        cld
        rep     movsb
        pop     ds
        sub     [symnameptr],bx         ; adjust pointer
        dec     [symcount]              ; and symbol count
        mov     [symModified],1
        pop     bx
        ret
symClear ENDP
;
; insert a symbol table entry
;
symInsert PROC
        push    si
        push    bx
        push    edx
        sub     cx,cx                   ; get length of name
        dec     cx
sill:
        lodsb
        inc     cx
        or      al,al
        jnz     sill
        mov     bx,cx                   ; bx = length of symbol
        add     bx,7
        push    cx
        push    di
        mov     si,[symnameptr]         ; get top of table
        mov     cx,si                   ; cx = length to move
        sub     cx,di
        add     si,bx                   ; si = new top of table
        cmp     si,[symnametop]         ; too big?
        jae     six                     ; yes exit
        mov     di,[symnameptr]         ; di = old top of table
        mov     [symnameptr],si         ; set new value
        dec     di                      ; set up pointers
        dec     si
        xchg    si,di
        push    ds
		call	compatibleSymSeg
        mov     ds,ax
        std
        rep     movsb
        cld
        pop     ds
        pop     di
        pop     cx
        pop     edx
        pop     bx
        pop     si
        mov     es:[di],ebx             ; set value of new symbol
        mov     es:[di+4],dx
        lea     di,[di+6]
        mov     al,cl                   ; count byte
        stosb
sill2:
        lodsb                           ; store name
        or      al,al
        jz      six2
        stosb
        jmp     sill2
six2:
        inc     [symcount]              ; increment symbol count
        mov     [symModified],1
        ret
six:      
        stc
        pop     di
        pop     cx
        pop     edx
        pop     bx
        pop     si
        ret
symInsert ENDP
;
; bump to next symbol
;
nextsym PROC
        add     di,6                    ; bump past address info
        movzx   ax,byte ptr es:[di]     ; get name length
        add     di,ax                   ; bump past name
        inc     di                      ; adjust for name length byte
        cmp     di,[symnameptr]         ; see if at end of table
        ret
nextsym ENDP
;
; look up a symbol by name
;
symLookupByName PROC
		test	[nolookup],255
		jnz		slbnx
		call	compatibleSymSeg
        mov     es,ax
        mov     di,[symnamebot]
        cmp     di,[symnameptr]         ; empty?
        jz      slbnx                   ; yes, exit
slbnl:
        push    si
        push    di
        movzx   cx,byte ptr es:[di+6]   ; compare name field
        add     di,7
        cld
        test    [optcisym],255
        jnz     slbn1
        rep     cmpsb
        jmp     slbn2
slbn1:
        lodsb
        xor     al,es:[di]
        inc     di
        and     al,NOT 20h
        loopz   slbn1

slbn2:
        jnz     slbnn
        test    byte ptr [si],0ffh
        jnz     slbnn   
        pop     di                      ; found it
        pop     si
        ret
slbnn:
        pop     di                      ; bump to next sym
        pop     si
        call    nextsym
        jb      slbnl
slbnx:
        stc                             ; not in table
        ret
symLookupByName ENDP
;
; look up a symbol by value.  Symbols are sorted by value
;
symLookupByValue PROC   
		test	[nolookup],255
		jnz		slbvx
		call	compatibleSymSeg
        mov     es,ax
        mov     di,[symnamebot]
        cmp     di,[symnameptr]         ; see if empty
        jz      slbvx                   ; yes exit
slbvl:
        cmp     es:[di+4],dx            ; check segment
        ja      slbvx                   ; table entry > selection, not in table
        jnz     slbvn                   ; not a match, continue
        cmp     es:[di],ebx             ; check offset
        ja      slbvx                   ; table entry > selection, not in table
        jnz     slbvn                   ; not a match, continue
        ret                             ; we found it!
slbvn:
        call    nextsym                 ; next symbol
        jb      slbvl
slbvx:
        stc                             ; we didn't find it
        ret
symLookupByValue ENDP
;
; routine to handle symbol table commands
;
symcmd PROC
        call    WadeSpace                       ; pass spaces
        jz      symshowall                      ; no args, show all symbols
        cmp     al,'$'                          ; check for second $
        jnz     symnamed                        ; no, it is a symbol name command
        inc     si                              ; bump past $
        call    wadespace                       ; more spaces
        jz      symerr                          ; error if no qualifier
        cmp     al,'$'                          ; else third char $
        jz      symsetup                        ; yes go to table setup
        cmp     al,'w'                          ; write command
        jz      symwrite                        ; do it
        cmp     al,'l'                          ; read command
        jz      symread                         ; do it
symerr:
        stc                                     ; invalid command
        ret
;
; symbol table read from file
;
symread:
        inc     si                              ; bump past 'l'
        call    WadeSpace                       ; get name
        call    getsymname
        jc      symerr
        call    hasname                         ; error if no name
        call    loadsymfile                     ; load file
        clc
        ret
;
; symbol table write to file
;
symwrite:
        test    [symseg],-1                     ; get out if no table
        stc
        jz      symerr
        inc     si                              ; bump past 'w'
        call    WadeSpace                       ; get name
        call    getsymname
        jc      symerr
        call    hasname                         ; error if no name
        call    savesymfile                     ; save file
        clc
        ret
;
; symbol table set size or show status
;
symsetup:
        inc     si                              ; bump past '$'
        call    WadeSpace                       ; see if more
        jz      showsetup                       ; no further data, just show stats
		call	noCommandInDPMI
        call    ReadNumber                      ; get size
        jc      symerr
        mov     bx,ax                           ; size to bx
        call    WadeSpace                       ; make sure this is the end
        jnz     symerr
        cmp     bx,64                           ; 64K or less?
        ja      symerr                          ; no error
finish:
        mov     [optsymname],bl                 ; save setting
        mov     [writeopts],1
        call    CloseLogFile            ; close the log file
	call	KillFiles		; else clear mem state to allow
	call	ReleaseMemory		; the change
        call    unloadsym                       ; unload symbol table
        test    [optsymname],255                ; see if any table
        jz      reprogram                       ; no, continue
        call    loadsym
reprogram:
	mov	si,offset grdbname	; reload empty program
	call	MakeEmptyProg
	sub	ax,ax
	test	[loadfile],0ffh
	jz	nochange
	call	LoadProgram		; reload user program
	lahf
nochange:
;
; show symbol table status
;

showsetup:
        PRINT_MESSAGE <13,10,"Table size: ">    
        movzx   ax,[optsymname]                 ; size of table in K
        call    printdecimal
        PRINT_MESSAGE <"K",13,10, "Used: ">
        mov     ax,[symnameptr]                 ; bytes used
        sub     ax,[symnamebot]
        call    printdecimal
        PRINT_MESSAGE <" Bytes",13,10,"Symbols: ">
        mov     ax,[symcount]                   ; symbols present
        call    printdecimal
        clc
        ret
;
; symbol table show all symbols
;
symshowall:
        mov     [crlfcount],0
        push    es
		call	compatibleSymSeg
        mov     es,ax
        mov     di,[symnamebot]
        cmp     di,[symnameptr]                 ; get out if empty
        jae     symsax
symsal:
        call    crlfPause
        call    printval                        ; display symbol
        call    nextsym                         ; bump to next sym
        jb      symsal                          ; loop while not done
symsax:
        pop     es
        clc
        ret
;
; symbol table variable functions
;
symnamed:
        test    [symseg],-1                     ; get out if no symbol table
        stc
        jz      symerr
        call    symReadName2
        call    WadeSpace                       ; next char
        jz      dispsym                         ; no more, display sym
        cmp     al,'='                          ; check for equal
        jnz     symerr                          ; error if not
        inc     si                              ; bump past '='
        call    WadeSpace                       ; next character
        jz      clearsym                        ; no more, delete symbol
;
; adding a new symbol, or overwriting an old one
;
        call    ReadAddress                     ; get its address
        jc      symerr
        push    si
        push    es
        mov     si,offset symname2               ; erase symbols of same name
        call    symLookupByName
        jc      nt1
        call    symClear
nt1:
        mov     si,offset symname2               ; erase symbols with same value
        call    symLookupByValue
        jc      nt2
        call    symClear
nt2:
                                                ; ES:DI points to insertion point
        mov     si,offset symname2               ; insert the symbol
        call    symInsert
        pop     es
        pop     si
        jc      symerr
;
; display a symbol value
;
dispsym:
        push    es
        push    si
        mov     si,offset symname2               ; find it
        call    symLookupByName
        jc      snx
        call    crlf
        call    printval                        ; print the value
snx:
        clc
        pop     si
        pop     es
        ret
;
; delete a symbol from the table
;
clearsym:
        push    es
        push    si
        mov     si,offset symname2              ; find it
        call    symLookupByName
        jc      snx
        call    symClear                        ; delete it
        jmp     snx
symcmd ENDP
        end
