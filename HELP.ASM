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
; help.asm
;
; Function: Handle help menus
;
;   Handles numbers
;   Handles segments
;   Handles trapping page faults
;   Handles command input
;
	;MASM MODE
	.model small
	.386

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
include emsr.inc

        extrn w_cmdset : proc, optfs: BYTE
		extrn docpuid : proc, doprogram : proc, doarena:proc, dochain: Proc
        public PrintVersion
	PUBLIC  help

	.data
memx	dw	0	; used to filter non-program stuff in arena dump (?m)

	.code
;
PrintVersion PROC
	call	PrintFollowingMessage
        db      13,10,"Get Real Debugger Version "
        db      30h + verid/10,'.',30h + verid MOD 10,9
        db      "Copyright (c) 1997-2009 David Lindauer (LADSoft)",13,10
        db      0
        ret
PrintVersion ENDP
;
; help command entry point
;
Help	PROC
	call	WadeSpace
	jnz	help2
ifndef NOFS
        test    [optfs],255
        jz      nofsx
        mov     al,1
        call    w_cmdset
nofsx:
endif
        call    PrintVersion
        call    PrintFollowingMessage            
        db      C_COMMAND,"a       ",C_OPERAND,"[address]               ",C_DESCRIPTION,"- assemble",13,10
        db      C_COMMAND,"b[d]    ",C_OPERAND,"[#]                     ",C_DESCRIPTION,"- show breakpoint(s)",13,10
        db      C_COMMAND,"b[d]    ",C_OPERAND,"[-]#,addr[,r/w/x[,len]] ",C_DESCRIPTION,"- set or clear a breakpoint",13,10
        db      C_COMMAND,"d[bwd]  ",C_OPERAND,"[start [,end]]          ",C_DESCRIPTION,"- dump memory",13,10
        db      C_COMMAND,"e[bwd]  ",C_OPERAND,"start [,list]           ",C_DESCRIPTION,"- examine memory",13,10
        db      C_COMMAND,"g       ",C_OPERAND,"[=start] [,break]       ",C_DESCRIPTION,"- run from start (or pos) to break",13,10
        db      C_COMMAND,"h       ",C_OPERAND,"val1 [+-*/] val2        ",C_DESCRIPTION,"- hex arithmetic",13,10
        db      C_COMMAND,"i[bwd]  ",C_OPERAND,"port                    ",C_DESCRIPTION,"- read from port",13,10
        db      C_COMMAND,"o[bwd]  ",C_OPERAND,"port,val                ",C_DESCRIPTION,"- write to port",13,10
        db      C_COMMAND,"p[r]    ",C_OPERAND,"[count]                 ",C_DESCRIPTION,"- step over [out]",13,10
        db      C_COMMAND,"q[s]    ",C_OPERAND,"                        ",C_DESCRIPTION,"- quit [save options]",13,10
        db      C_COMMAND,"r       ",C_OPERAND,"[reg[:val]]             ",C_DESCRIPTION,"- show/modify regs",13,10
        db      C_COMMAND,"rf      ",C_OPERAND,"[list of flag values]   ",C_DESCRIPTION,"- show/modify flags",13,10
        db      C_COMMAND,"rm      ",C_OPERAND,"[#,val]                 ",C_DESCRIPTION,"- show/modify mmx regs, high byte first",13,10
        db      C_COMMAND,"rn[s]   ",C_OPERAND,"[#, val]                ",C_DESCRIPTION,"- show fp regs or status, or set reg value",13,10
        db      C_COMMAND,"t       ",C_OPERAND,"[count]                 ",C_DESCRIPTION,"- step into",13,10
        db      C_COMMAND,"u       ",C_OPERAND,"[start [,end]]          ",C_DESCRIPTION,"- unassemble",13,10
        db      C_COMMAND,"y       ",C_OPERAND,"[pfa [,reg[,val]]]      ",C_DESCRIPTION,"- read/[write] PCI reg or show devices",13,10
        db      C_COMMAND,"y?      ",C_OPERAND,"bus, dev, func          ",C_DESCRIPTION,"- get PCI PFA from bus:dev:func",13,10
        db      C_COMMAND,"?       ",C_OPERAND,"                        ",C_DESCRIPTION,"- this help",13,10
        db      C_COMMAND,"??      ",C_OPERAND,"                        ",C_DESCRIPTION,"- show extended commands",13,10
		db		C_DEFAULT,13,10,"prefix an 'end' value with the character 'l' to denote a length"
	db	0
	clc
	ret	
help2:
	cmp	al,'?'
        jnz     gnu
	inc	si
	call	wadespace
	jnz	herr
ifndef NOFS
        test    [optfs],255
        jz      nofsx1
        mov     al,1
        call    w_cmdset
nofsx1:
endif
        call    PrintVersion
	call	PrintFollowingMessage
	db	13,10
        db      C_COMMAND,"c       ",C_OPERAND,"start,end,start2        ",C_DESCRIPTION,"- compare memory",13,10
		db		C_COMMAND,"cls     ",C_OPERAND,"                        ",C_DESCRIPTION,"- clear screen", 13, 10
        db      C_COMMAND,"f       ",C_OPERAND,"start,end [,val]        ",C_DESCRIPTION,"- fill memory",13,10
        db      C_COMMAND,"l[@][-] ",C_OPERAND,"[name[ command]]        ",C_DESCRIPTION,"- read from file",13,10
        db      C_COMMAND,"m       ",C_OPERAND,"source,end,dest         ",C_DESCRIPTION,"- move memory",13,10
        db      C_COMMAND,"s       ",C_OPERAND,"start,end [,list]       ",C_DESCRIPTION,"- search for a byte pattern",13,10
        db      C_COMMAND,"w       ",C_OPERAND,"[@addr] [name] [,len]   ",C_DESCRIPTION,"- write to file",13,10
        db      C_COMMAND,"xr      ",C_OPERAND,"drive: addr,start [,len]",C_DESCRIPTION,"- read logical disk sector",13,10
        db      C_COMMAND,"xw      ",C_OPERAND,"drive: addr,start [,len]",C_DESCRIPTION,"- write logical disk sector",13,10
        db      C_COMMAND,"@[a]    ",C_OPERAND,"[logfile]               ",C_DESCRIPTION,"- start/stop logging to a file [append]",13,10
        db      C_COMMAND,"?c      ",C_OPERAND,"                        ",C_DESCRIPTION,"- returns info about the CPU",13,10
        db      C_COMMAND,"?g[r]   ",C_OPERAND,"                        ",C_DESCRIPTION,"- gnu information",13,10    
        db      C_COMMAND,"?i      ",C_OPERAND,"                        ",C_DESCRIPTION,"- view interrupt info",13,10
        db      C_COMMAND,"?m[x]   ",C_OPERAND,"                        ",C_DESCRIPTION,"- view arena tags[all]",13,10
        db      C_COMMAND,"?o      ",C_OPERAND,"[+-option list]         ",C_DESCRIPTION,"- view/set options",13,10
        db      C_COMMAND,"?p      ",C_OPERAND,"                        ",C_DESCRIPTION,"- view program status",13,10
        db      C_COMMAND,"?s      ",C_OPERAND,"reg [,end]              ",C_DESCRIPTION,"- view MSR",13,10
        db      C_COMMAND,"$       ",C_OPERAND,"[name[=[value]]]        ",C_DESCRIPTION,"- show,clear, or set a symbol value",13,10
        db      C_COMMAND,"$$l     ",C_OPERAND,"[name]                  ",C_DESCRIPTION,"- load symbols",13,10
        db      C_COMMAND,"$$w     ",C_OPERAND,"[name]                  ",C_DESCRIPTION,"- save symbols",13,10
        db      C_COMMAND,"$$$     ",C_OPERAND,"[tablesize]             ",C_DESCRIPTION,"- show or set symbol table characteristics",13,10
        db      C_COMMAND,"/       ",C_OPERAND,"instruction             ",C_DESCRIPTION,"- assemble and execute instruction",13,10
		db		C_DEFAULT
	db	0
	clc
	ret	
;
; program & processor info
;
gnu:
        cmp     al,'g'
        jnz     status
        inc     si
        call    wadespace
        jnz     gnuredistribute
ifndef NOFS
        test    [optfs],255
        jz      nofsx2
        mov     al,1
        call    w_cmdset
nofsx2:
endif
        call    PrintVersion
        call    PrintFollowingMessage ; warranty info
        db      13,10, C_GNUTEXT
        db      "    This program is distributed in the hope that it will be useful,",13,10
        db      "    but WITHOUT ANY WARRANTY; without even the implied warranty of",13,10
        db      "    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the",13,10
        db      "    GNU General Public License for more details.",13,10, C_DEFAULT
        db      0
        jmp     gnujoin
        
gnuredistribute:
ifndef NOFS
        test    [optfs],255
        jz      nofsx3
        mov     al,1
        call    w_cmdset
nofsx3:
endif
        call    PrintVersion
        call    PrintFollowingMessage ; copying info
        db      13,10, C_GNUTEXT
        db      "    This program is free software; you can redistribute it and/or modify",13,10
        db      "    it under the terms of the GNU General Public License as published by",13,10
        db      "    the Free Software Foundation; either version 2 of the License, or",13,10
        db      "    (at your option) any later version.",13,10 , C_DEFAULT
        db      0
gnujoin:
        call    PrintFollowingMessage ; copying info
        db      13,10, C_GNUTEXT
        db      "    You should have received a copy of the GNU General Public License",13,10
        db      "    along with this program; if not, write to the Free Software",13,10
        db      "    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02111-1307  USA",13,10
        db      13,10
        db      "    (See the file 'COPYING' for details)",13,10, C_DEFAULT
        db      0
        clc
        ret
status:
        cmp     al,'c'
		jz		docpuid
hmem2:
	cmp	al,'p'
	jz	doprogram
;
; arena stats
;
hmem:	cmp	al,'m'
	jz	doarena
hmsr:
	cmp	al,'s'
	jz	domsr
	; fall through
;
; option status, jump to option routine
;
hopt:
	cmp	al,'o'
	jz doopt
;
; chain status
;
hchain:
	cmp	al,'i'
	jz dochain
herr:
	stc
	ret
Help	ENDP
END