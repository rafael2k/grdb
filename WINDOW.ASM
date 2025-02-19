;    GRDB - debugger for dos with 32-bit extensions
;    Copyright (C) 1997-2006  David Lindauer
;
; dual monitor support provided by
;
;	Lawrence E. Boothby
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
; window.asm
;
; Function: full-screen windowing functions
;
	;MASM MODE
	.model small
	.386

include  edispatc.inc 
include  eprints.inc 
include  emtrap.inc 
include  eregs.inc 
include  edump.inc 
include  eentry.inc 
include  eexec.inc 
include  ebreaks.inc 
include  edis.inc 
include  einout.inc
include  eoptions.inc
include  ehistory.inc
include  elogging.inc
include  iwindow.inc
include  edpmi.inc
include eoptions.inc
ifndef NOFS
        public w_putch, w_putcur, w_getcur, w_setcur, w_scrollup, w_clrwnd
        public wnd_asm, wnd_reg, wnd_dump, wnd_cmd, wininit, winrundown
        public wnd_reg2, wnd_full
        public w_putcmdch, w_putpurech
        public w_setwind, w_swapscreen, infs, fullcmd
        public w_cmdset, curwindow, w_framechar, gtb_mono
		
        extrn optfs:byte, getcurpos2: proc, setcurpos2: proc
        extrn getcurshape:proc ;LEB 10-04-2005 needed to init cursor
        extrn DisplayRegisters : PROC, redump : PROC, rediss : PROC
        .data
wnd_asm windstr <1,1,62,9,0,0,7>
wnd_reg windstr <1,64,12,16,0,0,7>
wnd_reg2 windstr <1,77,2,9,0,0,7>
wnd_dump windstr <11,1,60,6,0,0,7>
wnd_cmd windstr <18,1,78,6,0,0,7>
;
wnd_cmdp windstr <18,1,78,6,0,0,7>
wnd_cmdt windstr <1,1,78,17,0,0,7>
wnd_cmdf windstr <1,1,78,23,0,0,7>
;
wnd_full windstr <0,0,80,25,0,0,7>      ;LEB 10-09-2005 used to simplify
;                                        wininit proc for dual monitors
;
curwindow       dw      offset wnd_cmd
screendb        db      80 * 25 * 2 DUP (?)
cursdb  dw      ?
pagedb db ?
infs  db      ?
fullcmd db      0

        .code
wininit PROC
        test    [optfs],255
        jz      winx
        call    w_savescreen    ;a nop if dual monitors
;****************************** this code added for dual monitors ******
        mov     bx,offset wnd_full  ;this centralizes the clear screen
        call    w_clrwnd            ;function to a single procedure LEB
      ;  mov     cx,0               ;10-09-2005
      ;  mov     dx,184fh
      ;  mov     ax,600h
      ;  mov     bh,7
      ;  int     10h
;***********************************************************************
        sub     ax,ax
        call    w_drawborders 
        mov     [infs],1
winx:
        ret
wininit ENDP
winrundown PROC
        test    [optfs],255
        jz      wrdx
        mov     al,0
        call    w_cmdset
        mov     al,0
        call    w_swapscreen
wrdx:
        ret
winrundown ENDP
gettextbase PROC
;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag, LEB 10-09-2005
        jnz      gtb_mono
;***********************************************************************
        push    es
        mov     ax,40h
        mov     es,ax
        mov     ax,es:[63h]
        pop     es
        cmp     ax,3b4h
        mov     ax,0b800h
        jnz     gtb_vga
gettextbase ENDP
gtb_mono PROC
        mov     ax,0b000h
gtb_vga:
		test	cs:[inDPMI],1
		jz		gtb_notdpmi
		pushad
		mov		bx,ax			; in DPMI alias it...
		mov		ax,2
		int		31h
		push	bp
		mov		bp,sp
		mov		[bp + 2 + 7 * 4],ax
		pop		bp
		popad
gtb_notdpmi:
        ret
gtb_mono ENDP
w_setwind PROC
        mov     ax,[curwindow]
        or      bx,bx
        jz      w_swx
        mov     [curwindow],bx
        cmp     bx,offset wnd_cmd
        jz      w_swx
        push    ax
        push    si
        sub     al,al
        call    w_cmdset
        pop     si
        pop     ax
w_swx:
        ret
w_setwind ENDP
w_putcmdch PROC
        pusha
        mov     bx,[curwindow]
        call    w_putch
        call    w_putcur
        popa
        ret
w_putcmdch ENDP
w_putpurech PROC
        pusha
        mov     bx,[curwindow]
        call    w_framechar
        popa
        ret
w_putpurech ENDP
w_putch PROC
        cmp     al,8
        jz      wp_decr
        cmp     al,7fh
        jnz     wp_nldecr
wp_decr:
        test    [bx].curx,-1
        jz      wp_dend
        dec     [bx].curx
wp_dend:
        ret 
wp_nldecr:
        cmp     al,13
        jnz     wp_nlcr
        mov     [bx].curx,0
        ret
wp_nlcr:
        cmp     al,10
        jnz     wp_nllf
dolf:
        inc     [bx].cury
        mov     al,[bx].cury
        cmp     al,[bx].height
        jl      wp_lfend
        dec     [bx].cury
        call    w_scrollup
wp_lfend:
        ret
wp_nllf:
        cmp     al,7
        jnz     wp_nlbell
        push    dx
        mov     dl,al
        mov     ah,2
        int     21h             ;was 21=15h LEB 9-28-2005
        pop     dx
        ret
wp_nlbell:
        cmp     al,9
        jnz     wp_nltab
        add     [bx].curx,8
        and     [bx].curx,0f8h
        mov     al,[bx].curx
        cmp     al,[bx].wid
        jl      wp_bellend
        mov     [bx].curx,0
        jmp     dolf
wp_bellend:
        ret
wp_nltab:
        push    es
        push    ax
        call    gettextbase
        mov     es,ax
        mov     dh,[bx].cury
        mov     dl,[bx].curx
        add     dh,[bx].row
        add     dl,[bx].col
        pop     ax
        mov     ah,[bx].color
        push    bx
        call    w_framechar
        pop     bx
        pop     es
        inc     [bx].curx
        mov     al,[bx].curx
        cmp     al,[bx].wid
        jl      wp_x
        mov     [bx].curx,0
        jmp     dolf
wp_x:
        ret

w_putch ENDP

w_putcur PROC
        mov     dh,[bx].cury
        mov     dl,[bx].curx
        add     dh,[bx].row
        add     dl,[bx].col
        call    setcurpos2
        ret
w_putcur ENDP

w_getcur PROC
        mov     dh,[bx.cury]
        mov     dl,[bx.curx]
        ret
w_getcur ENDP
w_setcur PROC
        mov     [bx.cury],dh
        mov     [bx.curx],dl
        ret
w_setcur ENDP

w_scrollup PROC
        mov     al,1
        jmp     w_scrollcont
w_scrollup ENDP
w_clrwnd PROC
        sub     al,al
w_clrwnd ENDP
w_scrollcont PROC
        push    bx
        push    si
        push    di
        mov     ah,6
        mov     ch,[bx].row
        mov     cl,[bx].col
        mov     dh,[bx].height
        mov     dl,[bx].wid
        mov     bh,[bx].color   ;this destroys BX
;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag, LEB 10-09-2005
        jz      w_scroll
        push    es
		push	ax
		call	gtb_mono
		mov		es,ax
		pop		ax
        xchg    ax,di           ;save AL
        mov     al,ch
        mov     bl,50h
        mul     bl
        xor     ch,ch           ;counting on ch=00 below too
        add     ax,cx 
        xchg    ax,di
        shl     di,1            ;es:di-->beginning of window in frame buffer
        or      al,al           ;al=00 or 01
        xchg    ax,bx           ;get color into ah
        mov     al,20h          ;space fill character
        jz      fill
        ;scroll dh rows and dl columns with es:di==>upper left corner
        dec     dh              ;last row is a fill
next_row:
        mov     cl,dl
        lea     si,[di+0a0h]
        push    si
        rep
        db 26h  ;es:            can override source segment  
        movsw 
        pop     di
        dec     dh
        jnz     next_row
        inc     dh              ;to do fill
fill:   mov     cl,dl           ;last line of window if finishing scroll
        push    di
        rep     stosw
        pop     di
        lea     di,[di+0a0h]
        dec     dh
        jnz     fill
        pop     es
        jmp     short w_scrollx
;***********************************************************************
w_scroll:
        add     dx,cx           ;moved down here so don't have to undo
        sub     dx,0101h        ;for dual monitor case
        int     10h
w_scrollx:
        pop     di
        pop     si
        pop     bx
        ret
w_scrollcont endp

vertline PROC
        push    bx
vllp:
        push    dx
        push    cx
        mov     ax,0fBAH
        call    w_framechar
        pop     cx
        pop     dx
        inc     dh
        loop    vllp
        pop     bx   
        ret
vertline ENDP
horzline PROC
        push    bx
hllp:
        push    dx
        push    cx
        mov     ax,0fcdh
        call    w_framechar
        pop     cx
        pop     dx
        inc     dl
        loop    hllp
        pop     bx   
        ret
horzline ENDP
w_framechar PROC
        push    es
        push    dx
        push    ax
        call    gettextbase
        mov     es,ax
        mov     al,dh
        mov     bl,0a0h
        mul     bl
        sub     dh,dh
        shl     dl,1
        add     ax,dx
        mov     bx,ax
        pop     ax
        mov     es:[bx],ax
        pop     dx
        pop     es
        ret
w_framechar ENDP
w_drawborders PROC
        push    ax
        mov     [infs],1
        mov     dx,0001h
        mov     cx,78
        call    horzline
        mov     dx,1801h
        mov     cx,78
        call    horzline
        mov     dx,0
        mov     cx,25
        call    vertline
        mov     dx,014fh
        mov     cx,0017h
        call    vertline
        mov     dx,0
        mov     ax,0fc9h
        call    w_framechar
        mov     dx,4fh
        mov     ax,0fbBH    
        call    w_framechar
        mov     dx,1800h
        mov     ax,0fc8h
        call    w_framechar
        mov     dx,184fh
        mov     ax,0fBCh
        call    w_framechar
        pop     ax
        test    al,1
        jnz     dp2
        mov     dx,0a01h
        mov     cx,63
        call    horzline
        mov     dx,1101h
        mov     cx,78
        call    horzline
        mov     dx,013fh
        mov     cx,16
        call    vertline
        mov     dx,014ch
        mov     cx,16
        call    vertline
        mov     dx,3fh
        mov     ax,0fcbH
        call    w_framechar
        mov     dx,4ch
        mov     ax,0fcbH
        call    w_framechar
        mov     dx,0a00h
        mov     ax,0fccH
        call    w_framechar
        mov     dx,0a3fh
        mov     ax,0fB9h
        call    w_framechar
        mov     dx,1100h
        mov     ax,0fCCH
        call    w_framechar
        mov     dx,113fh
        mov     ax,0fCAH
        call    w_framechar
        mov     dx,114ch
        mov     ax,0fCAH
        call    w_framechar
        mov     dx,114fh
        mov     ax,0fB9H
        call    w_framechar
dp2:
        ret
w_drawborders ENDP

w_cmdset PROC
        cmp     al,[fullcmd]
        jz      wcs_x
        cld
        push    ds
        pop     es
        mov     [fullcmd],al
        call    w_drawborders
        test    [fullcmd],1
        jnz     tofullscr
        mov     si,offset wnd_cmdp
        mov     di,offset wnd_cmd
        movsd
        sub     [wnd_cmd].cury,17
        cmp     [curwindow],offset wnd_dump
        jz      ndmp
        call    redump
ndmp:
        cmp     [curwindow],offset wnd_reg
        jz      nreg
        call    DisplayRegisters
nreg:
        cmp     [curwindow],offset wnd_reg2
        jz      nreg2
        call    DisplayRegisters
nreg2:
        cmp     [curwindow],offset wnd_asm
        jz      nasm
        call    rediss
nasm:
        jmp     wcs_c
tofullscr:
        mov     si,offset wnd_cmdf
        mov     di,offset wnd_cmd
        movsd
        mov     bx,offset wnd_cmdt
        call    w_clrwnd
        add     [wnd_cmd].cury,17
wcs_c:
        mov     bx,offset wnd_cmd
        call    w_putcur
wcs_x:
        ret
w_cmdset ENDP
w_savescreen PROC

;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag, LEB 10-09-2005
        jnz      w_saveskip
;***********************************************************************
        call    getcurpos2
        mov     [cursdb],dx
        push    es              ; get active page
        mov     ax,40h
        mov     es,ax
        mov     al,es:[62h]
        pop     es
        mov     [pagedb],al
        call    gettextbase
        push    ds
        push    es
        push    ds
        pop     es
        mov     ds,ax
        sub     si,si
        mov     di,offset screendb
        mov     cx,80*25
        cld
        rep     movsw
        pop     es
        pop     ds
        mov     ax,500h ; set active page
        int     10h
w_saveskip:                             ;new label for dual monitors LEB,
        ret                             ;10-09-2005
w_savescreen ENDP
w_restorescreen PROC
;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag, LEB 10-09-2005
        jnz      w_saveskip
;***********************************************************************
        call    gettextbase
        push    es
        mov     es,ax
        mov     si,offset screendb
        sub     di,di
        mov     cx,80*25
        cld
        rep     movsw
        pop     es
w_swapskip:                     ;label added for dual monitors
        ret
w_restorescreen ENDP
w_swapscreen PROC
;****************************** this code added for dual monitors ******
        test    [optdm],0ffh    ;dual monitor flag, LEB 10-09-2005
        jnz      w_swapskip
;***********************************************************************
        cmp     al,[infs]
        jz      w_swex
        mov     [infs],al
        sub     al,al
        call    w_cmdset
        push    es
        call    getcurpos2
        push    dx
        mov     ax,40h
        mov     es,ax
        mov     al,es:[62h]
        push    ax
        mov     al,[pagedb]
        mov     ah,5
        int     10h
        mov     dx,[cursdb]
        call    setcurpos2
        pop     ax
        mov     [pagedb],al
        pop     ax
        mov     [cursdb],ax
        call    gettextbase
        mov     es,ax
        sub     di,di
        mov     si,offset screendb
        mov     cx,80*25
        cld
swlp:
        lodsw
        mov     bx,es:[di]
        mov     ds:[si-2],bx
        stosw
        loop    swlp
        mov     ax,500h ; set active page
        int     10h
        pop     es
w_swex:
        ret
w_swapscreen ENDP        
endif
        end
