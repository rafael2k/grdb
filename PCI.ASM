;    GRDB - debugger for dos with 32-bit extensions
;    Copyright (C) 1997-2006  David Lindauer
;
; original module donated by:
;
; Trung Nguyen <trungn@texmicro.com>
;
; a BIOS developer at texas micro inc.
;
; extensive modifications donated by:
;
; lechee lai <lecheel@yahoo.com>
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
;
; PCI.ASM
;
; Function: PCI commands
;
;
	;MASM MODE
	.MODEL SMALL
	.386

include  eprints.inc
include  einput.inc
include  emtrap.inc
include	 edpmi.inc

IODELAY MACRO
        out     0EDh, al
ENDM

BASEPCIPORT = 0CFCH
BASEPCIIOPORT = 0CF8H

	PUBLIC pci
        extrn   w_cmdset : PROC, optfs : BYTE

	.data

bus_num         db 0
dev_num         db 0
fun_num         db 0
find_count      db 0
Multi_flag      db 0
pci_index       dd 0
pci_data        dd 0
pci_class       dw 0
regIdx          db      0


	.CODE
PID0000    db 'Built before defined',00h
PID0001    db 'VGA-compatible device',00h
PID0100    db 'SCSI bus controller',00h
PID0101    db 'IDE controller',00h
PID0102    db 'Floppy disk controller',00h
PID0103    db 'IPI bus controller',00h
PID0104    db 'RAID controller',00h
PID0180    db 'mass storage controller',00h
PID0200    db 'Ethernet controller',00h
PID0201    db 'Token Ring controller',00h
PID0202    db 'FDDI controller',00h
PID0203    db 'ATM controller',00h
PID0204    db 'ISDN controller',00h
PID0280    db 'Network controller',00h
PID0300    db 'VGA Graphics',00h
PID0301    db 'XGA controller',00h
PID0302    db '3D controller',00h
PID0380    db 'Display controller',00h
PID0400    db 'Video device',00h
PID0401    db 'Audio device',00h
PID0402    db 'Computer telephony device',00h
PID0480    db 'multimedia device',00h
PID0500    db 'RAM',00h
PID0501    db 'Flash',00h
PID0580    db 'Memory controller',00h
PID0600    db 'Host bridge',00h
PID0601    db 'ISA bridge',00h
PID0602    db 'EISA bridge',00h
PID0603    db 'MCA bridge',00h
PID0604    db 'PCI-to-PCI bridge',00h
PID0605    db 'PCMCIA bridge',00h
PID0606    db 'NuBus bridge',00h
PID0607    db 'CardBus bridge',00h
PID0608    db 'RACEway bridge',00h
PID0680    db 'Bridge device (PMU)',00h
PID0700    db 'Generic serial controller',00h
PID0701    db 'Parallel Port',00h
PID0703    db 'Generic modem',00h
PID0780    db 'Communications device',00h
PID8000    db 'Generic 8259 PIC',00h
PID8001    db 'Generic 8237 DMA controller',00h
PID0802    db 'Generic 8254 system timer',00h
PID0803    db 'Generic RTC controller',00h
PID0804    db 'Generic PCI Hot-Plug controller',00h
PID0880    db 'System peripheral',00h
PID0900    db 'Keyboard controller',00h
PID0901    db 'Digitizer',00h
PID0902    db 'Mouse controller',00h
PID0903    db 'Scanner controller',00h
PID0904    db 'Gameport controller',00h
PID0980    db 'Input controller',00h
PID0a00    db 'Generic docking station',00h
PID0a80    db 'Type of docking station',00h
PID0b00    db '386',00h
PID0b01    db '486',00h
PID0b02    db 'Pentium',00h
PID0b10    db 'Alpha',00h
PID0b20    db 'PowerPC',00h
PID0b30    db 'MIPS',00h
PID0b40    db 'Co-processor',00h
PID0c00    db 'FireWire IEEE 1394',00h
PID0c01    db 'ACCESS bus',00h
PID0c02    db 'SSA',00h
PID0c03    db 'Universal Serial Bus (USB)',00h
PID0c04    db 'Fibre Channel',00h
PID0c05    db 'SMBus (System Management Bus)',00h
PID0d00    db 'iRDA compatible controller',00h
PID0d01    db 'Consumer IR controller',00h
PID0d10    db 'RF controller',00h
PID0d80    db 'Type of wireless controller',00h
PID0e00    db 'Intelligent I/O (I2O) Architecture',00h
PID0f01    db 'TV',00h
PID0f02    db 'Audio',00h
PID0f03    db 'Voice',00h
PID0f04    db 'Data',00h
PID1000    db 'Network and computing en/decryption',00h
PID1010    db 'Entertainment en/decryption',00h
PID1080    db 'En/decryption',00h
PID1100    db 'DPIO modules',00h
PID1180    db 'Data acquisition controller',00h
PIDFFFF    DB 'No such device',00

PciClassTbl     Label   WORD
        dw   0000h,  Offset PID0000
        dw   0001h,  Offset PID0001
        dw   0100h,  Offset PID0100
        dw   0101h,  Offset PID0101
        dw   0102h,  Offset PID0102
        dw   0103h,  Offset PID0103
        dw   0104h,  Offset PID0104
        dw   0180h,  Offset PID0180
        dw   0200h,  Offset PID0200
        dw   0201h,  Offset PID0201
        dw   0202h,  Offset PID0202
        dw   0203h,  Offset PID0203
        dw   0204h,  Offset PID0204
        dw   0280h,  Offset PID0280
        dw   0300h,  Offset PID0300
        dw   0301h,  Offset PID0301
        dw   0302h,  Offset PID0302
        dw   0380h,  Offset PID0380
        dw   0400h,  Offset PID0400
        dw   0401h,  Offset PID0401
        dw   0402h,  Offset PID0402
        dw   0480h,  Offset PID0480
        dw   0500h,  Offset PID0500
        dw   0501h,  Offset PID0501
        dw   0580h,  Offset PID0580
        dw   0600h,  Offset PID0600
        dw   0601h,  Offset PID0601
        dw   0602h,  Offset PID0602
        dw   0603h,  Offset PID0603
        dw   0604h,  Offset PID0604
        dw   0605h,  Offset PID0605
        dw   0606h,  Offset PID0606
        dw   0607h,  Offset PID0607
        dw   0608h,  Offset PID0608
        dw   0680h,  Offset PID0680
        dw   0700h,  Offset PID0700
        dw   0701h,  Offset PID0701
        dw   0703h,  Offset PID0703
        dw   0780h,  Offset PID0780
        dw   8000h,  Offset PID8000
        dw   8001h,  Offset PID8001
        dw   0802h,  Offset PID0802
        dw   0803h,  Offset PID0803
        dw   0804h,  Offset PID0804
        dw   0880h,  Offset PID0880
        dw   0900h,  Offset PID0900
        dw   0901h,  Offset PID0901
        dw   0902h,  Offset PID0902
        dw   0903h,  Offset PID0903
        dw   0904h,  Offset PID0904
        dw   0980h,  Offset PID0980
        dw   0a00h,  Offset PID0a00
        dw   0a80h,  Offset PID0a80
        dw   0b00h,  Offset PID0b00
        dw   0b01h,  Offset PID0b01
        dw   0b02h,  Offset PID0b02
        dw   0b10h,  Offset PID0b10
        dw   0b20h,  Offset PID0b20
        dw   0b30h,  Offset PID0b30
        dw   0b40h,  Offset PID0b40
        dw   0c00h,  Offset PID0c00
        dw   0c01h,  Offset PID0c01
        dw   0c02h,  Offset PID0c02
        dw   0c03h,  Offset PID0c03
        dw   0c04h,  Offset PID0c04
        dw   0c05h,  Offset PID0c05
        dw   0d00h,  Offset PID0d00
        dw   0d01h,  Offset PID0d01
        dw   0d10h,  Offset PID0d10
        dw   0d80h,  Offset PID0d80
        dw   0e00h,  Offset PID0e00
        dw   0f01h,  Offset PID0f01
        dw   0f02h,  Offset PID0f02
        dw   0f03h,  Offset PID0f03
        dw   0f04h,  Offset PID0f04
        dw   1000h,  Offset PID1000
        dw   1010h,  Offset PID1010
        dw   1080h,  Offset PID1080
        dw   1100h,  Offset PID1100
        dw   1180h,  Offset PID1180
        dw   -1   ,  Offset PIDFFFF    ; end of table

pci	PROC
;		call	noCommandInDPMI
        mov     crlfcount,0
        call    WadeSpace
        jz      ScanPCI
	cmp	al,'?'		; verify subcommand
        jz      pfaCmd          ; PFA command
	call	ReadNumber	; PFA
	jc	pciErr
        cmp     eax, 0FFFFh     ; Q:Valid PFA
        ja      pciErr          ;   N:
        mov     ebx, eax
	call	WadeSpace	;
;	jz	pciErr
        jz      pciDump
	call	ReadNumber	; Reg
	jc	pciErr
        cmp     eax, 0FFh       ; Q:Valid Reg
        ja      pciErr          ;   N:
        mov     ah, al
        push    ax
	call	WadeSpace	;
        pop     ax
	jnz	pciDoWrite
        call    PciByteRead
        push    ax
        call    crlf
        pop     ax
        call    PrintByte
        jmp     pciNoErr

pciDump:
;        print_message <13,10,"xx| 03020100 07060504 0B0A0908 0F0E0D0C",13,10>
;        print_message <      "--+------------------------------------",13,10>
ifndef NOFS
        test    [optfs],255
        jz      nofsx
        push    ebx
        mov     al,1
        call    w_cmdset
        pop     ebx
nofsx:
endif    
        call    crlfPause
        mov     ah, 0Ah
        call    PciDWordRead
        call    Show_PciClass
        call    crlfPause
        mov     regIdx, 0
        xor     ax, ax
dumpall:
        mov     al, regIdx
;        call    printByte
;        mov     dl, '|'
;        call    putchar
        mov     cx, 4h

dumpline:
        mov     ah, regIdx      ; BX is PFA UID
        push    ax
        mov     al, regIdx
        call    printByte
        call    PrintSpace
        pop     ax
        call    PciDWordRead
        call    PrintDWord
        call    PrintSpace
;        inc     byte ptr regIdx
        add     regIdx, 4       ; Format in DWORD
        loop    dumpline
        call    crlfPause
        cmp     byte ptr regIdx,000h
        jne     dumpall
        jmp     pciNoErr

pciDoWrite:
        push    ax
	call	ReadNumber	; Value
	jc	pciErr
        cmp     eax, 0FFh       ; Q:Valid val
        ja      pciErr          ;   N:
        mov     cl, al
        pop     ax
        mov     al, cl
        push    ax
	call	WadeSpace	;
        pop     ax
	jnz	pciErr
        call    pciByteWrite
        jmp     pciNoErr

pfaCmd:
        inc     si
	call	WadeSpace	; get operator
	jz	pciErr
        xor     ebx, ebx
	call	ReadNumber	; Bus
	jc	pciErr
        cmp     eax, 0FFh       ; Q:Valid Bus
        ja      pciErr          ;   N:
        mov     bl, al          ;   Y: Get bus
        shl     bx, 8
	call	WadeSpace	; get operator
	jz	pciErr
	call	ReadNumber	; Dev
	jc	pciErr
        cmp     eax, 01Fh       ; Q:Valid Dev
        ja      pciErr          ;   N:
        mov     bl, al          ;   Y: Get Dev
        shl     bl, 3
	call	WadeSpace	; get operator
	jz	pciErr
	call	ReadNumber	; Func
	jc	pciErr
        cmp     eax, 07h        ; Q:Valid Func
        ja      pciErr          ;   N:
        or      bl, al
	call	WadeSpace
	jnz	pciErr
        call    crlf
        mov     ax, bx
        call    PrintWord

pciNoErr:
        clc
        jmp     pciDone
ScanPCI:
ifndef NOFS
        test    [optfs],255
        jz      nofsx3
        mov     al,1
        call    w_cmdset
nofsx3:
endif
        call    crlfPause
        call    PciScan
		clc
        ret
pciErr:
        stc

pciDone:
        ret
pci	endp

ChkPci  PROC
        mov     dev_num, 0
devChk:
        call    chkDev
        add     dev_num, 1
        cmp     dev_num, 1fh
        jbe     devChk
        ret
ChkPci  ENDP

chkDev  PROC
        mov     fun_num,0
funChk:
        call    chkFun
        inc     fun_num
        cmp     fun_num, 7
        jbe     funChk
        ret
chkDev  ENDP

chkFun  PROC
        cmp     find_count, 0ffh
        jb      @@2
        ret
@@2:
        xor     eax, eax
        mov     dl, bus_num     ; Get Device Class
        mov     al, dl
        or      ax, 08000h
        shl     eax, 16
        mov     dh,fun_num
        and     dh,007h         ; dh function
        mov     dl,dev_num
        and     dl,01fh         ; dl device
        shl     dl,3
        add     dl,dh
        mov     ah,dl

        mov     al, 08          ; DeviceClass and SubClass
        mov     edx, BASEPCIIOPORT
        out     dx, eax

        mov     edx, BASEPCIPORT
        in      eax, dx
        shr     eax, 16
        mov     pci_class, ax

        xor     eax,eax
        mov     dl,bus_num
        mov     al,dl           ; save bus NO
        or      ax,08000h
        shl     eax,16
        mov     dh,fun_num
        and     dh,007h         ; dh function
        mov     dl,dev_num
        and     dl,01fh         ; dl device
        shl     dl,3
        add     dl,dh
        mov     ah,dl

        mov     edx, BASEPCIIOPORT
        out     dx, eax
        mov     pci_index, eax

        mov     edx, BASEPCIPORT
        in      eax, dx
        mov     pci_data, eax
        cmp     eax, 0FFFFFFFFh
        jnz     @@1
        ret
@@1:
        cmp     fun_num,0
        jne     @@3
        mov     eax,pci_index
        mov     al,0Ch
        mov     edx,BASEPCIIOPORT
        out     dx,eax
        add     dx,4
        in      eax,dx
        shr     eax,23
        and     al,01h
        mov     Multi_flag,al
        jmp     show2
@@3:
        cmp     Multi_flag,1
        je      show2
        ret
show1:
        inc     find_count      ; Kick count of found devices
        Print_Message "PCI Index"
        mov     eax, PCI_index
        call    PrintdWord
        ;
        call    PrintSpace
        ;
        Print_Message "PCI Data:"
        mov     eax, PCI_data
        call    PrintdWord
        call    crlfPause
        ret
show2:                          ; Show Format ' XXXX xx/xx/xx SSSSSSSSSSSS
        inc     find_count      ; kick count of dound devices
        xor     ax, ax
        mov     al, dev_num
        shl     ax, 3
        add     al, fun_num
        add     ah, bus_num
        call    PrintWord
        call    PrintSpace
        mov     al, bus_num
        call    PrintByte
        mov     dl,'/'
        call    PutChar
        mov     al, dev_num
        call    PrintByte
        mov     dl,'/'
        call    PutChar
        mov     al, fun_num
        call    PrintByte
        call    PrintSpace
        mov     ax, pci_class
        call    show_pciclass
        call    crlfPause

        ret
chkFun  ENDP

pciScan PROC
        mov     bus_num,0
		mov		find_count, 0
pciAgain:
        call    ChkPci
        inc     bus_num
busjoin:
        jnz     pciAgain
        ret
pciScan endp

; Input: AH: DeviceClass
;        AL: SubDevice
; Return
;       Print Device Class if Device Founded.
;
show_pciclass   proc    near            ; Show PCI Class Name
        push    bx
        push    ax
        mov     bx, offset cs:PciClassTbl
searchLoop:
        cmp     ax, cs:[bx]
        je      StrFound
        cmp     word ptr cs:[bx], -1
        je      StrDone
        add     bx, 4
        jmp     SearchLoop
StrFound:
        mov     si, word ptr cs:[bx+2]
        mov     bx,si
        call    olMessage
StrDone:
        pop     ax
        pop     bx
        ret
show_pciclass   endp

;----------------------------------------------------------------------------
;       PciByteRead -
;       This proc will read the byte from the register and device
;
;       Entry:  BX = PFA
;                    Bit<15..8>=Bus
;                    Bit<7...3>=Dev
;                    Bit<2..0>=Func
;               AH = Reg
;       Exit:
;               AL = register contents.
;       Affected registers:
;               AL is destroyed, all other registers are preserved.
;
PciByteRead PROC
        push    cx
        push    dx
        push    eax
        mov     ch, ah          ; Save register in CH
        mov     eax,0800000h
        or      ax, bx          ; Get PFA
        shl     eax, 8          ; Make room for register
        mov     al, ch          ; Place register info in location
        and     al,0FCh         ; Strip off alignment data.
        mov     dx,BASEPCIIOPORT        ;
        out     dx,eax
        IODELAY
        call    PointToByte     ; Align the PCI data port to out byte.
        in      al,dx           ; Fetch the data.
        IODELAY
        mov     cl, al          ; Save data first
        pop     eax
        mov     al, cl          ; Place data back
        pop     dx
        pop     cx
        ret
PciByteRead ENDP

;----------------------------------------------------------------------------
;       PciDWordRead -
;       This proc will read the byte from the register and device
;
;       Entry:  BX = PFA
;                    Bit<15..8>=Bus
;                    Bit<7...3>=Dev
;                    Bit<2..0>=Func
;               AH = Reg
;       Exit:
;               EAX = register contents.
;       Affected registers:
;               EAX is destroyed, all other registers are preserved.
;
PciDWordRead PROC
        push    cx
        push    dx
        mov     ch, ah          ; Save register in CH
        mov     eax,0800000h
        or      ax, bx          ; Get PFA
        shl     eax, 8          ; Make room for register
        mov     al, ch          ; Place register info in location
        and     al,0FCh         ; Strip off alignment data.
        mov     dx,BASEPCIIOPORT        ;
        out     dx,eax
        IODELAY
        call    PointToByte     ; Align the PCI data port to out byte.
        in      eax,dx          ; Fetch the data.
        IODELAY
        pop     dx
        pop     cx
        ret
PciDWordRead ENDP


;----------------------------------------------------------------------------
;       PciByteWrite -
;       This proc will write a byte to the register and device
;
;       Entry:  BX = PFA
;                    Bit<15..8>=Bus
;                    Bit<7...3>=Dev
;                    Bit<2..0>=Func
;               AH = Reg
;               AL = Value
;       Exit:
;               None.
;       Affected registers:
;               All registers are preserved.
;
PciByteWrite PROC
        push    cx
        push    dx
        push    eax
        mov     cx, ax          ; Save register and value in CX
        mov     eax,0800000h
        or      ax, bx          ; Get PFA
        shl     eax, 8          ; Make room for register
        mov     al, ch          ; Place register info in location
        and     al,0FCh         ; Strip off alignment data.
        mov     dx,BASEPCIIOPORT        ;
        out     dx,eax
        IODELAY
        call    PointToByte     ; Align the PCI data port to out byte.
        mov     al, cl          ; Get value back
        out     dx, al          ; BlastIT!!!!
        IODELAY
        pop     eax
        pop     dx
        pop     cx
        ret
PciByteWrite ENDP

;----------------------------------------------------------------------------
;       PointToByte
;       This proc provides the appropriate PCI IO port address to properly
;       access data in the PCI CFG space.
;       Entry:
;               CH = Register to use.
;       Exit:
;               DX = PCI data port IO address.
;       Affected registers:
;               DX is modified, all other registers are preserved.
;
PointToByte PROC
        push    cx
        and     cx,0300h        ; Strip all but byte information.
        xchg    ch, cl          ; Swap the LSB and MSB
        mov     dx,BASEPCIPORT  ; Base PCI IO port.
        add     dx,cx           ; Point to our register.
        pop     cx
        ret
PointToByte ENDP

end
