        .386P

;DATA    SEGMENT AT 0000h
DATA    SEGMENT PARA PUBLIC USE16 'DATA'
;Str1    db      'Done.$'
DATA    ENDS

STACK   SEGMENT PARA STACK 'STACK'
        db      32 dup (?)
STACK   ENDS

CODE    SEGMENT PARA PUBLIC USE16 'CODE'

Main    PROC    NEAR

        mov     ax, DATA
        mov     ds, ax
        ASSUME  DS:DATA

        mov     ax, STACK
        mov     ss, ax
        ASSUME  SS:STACK

        IF      0
        lea     dx, Str1
        mov     ah, 09h
        int     21h
        ENDIF

Main_End:
        mov     ah, 04ch
        int     21h


Main    ENDP

CODE    ENDS

END     Main