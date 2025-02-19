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
; LOGGING.ASM
;
; Function: log the session to a file
;
	;MASM MODE
	.MODEL SMALL
	.386


include  eprints.inc 
include  einput.inc 
include  emtrap.inc 
include  ebreaks.inc 

        PUBLIC logging,logtofile,CloseLogFile,LoggingStat, logon,logoff

	.data
LogFileName	db	80 DUP (?)
LogfileHandle	dw	0
LogfileBufferPosition	dw	0
LogfileBuffer	db	128 DUP (0)
loggingoff db 0

	.CODE
;
; show status of logger
;
LoggingStat	PROC
	test	[LogfileHandle],-1
	jz	nolog
	PRINT_MESSAGE	<13,10,"Log file: ">
	mov	bx,offset LogFileName
	call	DgroupMessage
	ret
nolog:
	PRINT_MESSAGE	<13,10,"Logging disabled">
	ret
Loggingstat	ENDP
;
; log command
;
logging	PROC	
	call	CloseLogFile		; close old file
	cmp	byte ptr [si],'a'	; check for append
	pushf
	jnz	noappend
	inc	si
noappend:
	Call	WadeSpace	; Wade till name
	jz	nofile
	mov	[LogfileBufferPosition],0
	mov	di,offset LogFileName	; get name
lnlp:
	lodsb
	cmp	al,13
	jz	lnlpend
	stosb
	jmp	lnlp
lnlpend:
	sub	al,al    		; open log file
	stosb
	popf
	mov	al,2
	jnz	noexist
	mov	al,82h 			; try to open for append (non-inheritable)
	mov	ah,3dh
	mov	dx,offset LogFileName
	int	21h
	jc	noexist			; doesn't exist, creeate it
	mov	[LogfileHandle],ax		; LogfileBufferPositionition to end
	mov	bx,ax
	mov	ax,4202h		; seek to eof for append
	sub	cx,cx
	sub	dx,dx
	int	21h
	jnc	xit
	call	closeit
	jmp	noopen
noexist:
	cmp	al,2			; try to create file
	jnz	noopen
	mov	ah,3ch
	mov	dx,offset LogFileName
	sub	cx,cx
	int	21h
	jc	noopen			; failed, get out
	
	mov	bx,ax			; succeeded, close and reopen
	call	closeit
	mov	ax,3d82h		; open, mark as non-inheritable
	mov	dx,offset LogFileName
	int	21h
	jc	noopen
	mov	[LogfileHandle],ax	; finally open, save it and exit
xit:
	sub	sp,2
nofile:
	add	sp,2
	clc
	ret
noopen:
	PRINT_MESSAGE	<13,10,"Can't open log file for write">
	clc
	ret
logging	ENDP
;
; close log file
;
closeLogfile PROC
	call	WriteBuffer
	mov	bx,[LogfileHandle]
	or	bx,bx
	jz	noclose
	call	closeit
noclose:
	ret
closeLogfile	ENDP

closeit	PROC
	mov	[LogfileHandle],0
	mov	ah,3eh
	int	21h
	ret
closeit	ENDP
;
; write a buffer out to log file
;
WriteBuffer PROC
	mov	bx,[LogfileHandle]
	or	bx,bx
	jz	nowrite
	mov	cx,[LogfileBufferPosition]
	mov	[LogfileBufferPosition],0
	mov	dx,offset LogfileBuffer
	mov	ah,40h
	int	21h
	jnc	writeok
	call	closeit
	PRINT_MESSAGE	<13,10,"Error writing log file">
writeok:
nowrite:
	ret
WriteBuffer ENDP
;
; log a char to the file
;
LogToFile PROC
        test    [loggingoff],255
        jnz     nologtofile
	test	[LogfileHandle],-1
	jz	nologtofile
	pusha
	cmp	al,1ah
	jz	logfix
	cmp	al,0ch
	jnz	logok
logfix:
	mov	al,'.'
logok:
	inc	[LogfileBufferPosition]
	mov	di,[LogfileBufferPosition]
	mov	[di + LogfileBuffer -1],al
	cmp	di,128
	jc	noflush
	call	WriteBuffer
noflush:
	popa
nologtofile:
	ret
LogToFile ENDP
logon proc
        mov [loggingoff],0
        ret
logon endp
logoff proc
        mov [loggingoff],1
        ret
logoff endp
	end
