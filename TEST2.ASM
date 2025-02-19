        .model small

        .stack
        .code
jma:
        push    cs
        pop     ds
        mov     ax,900h
        mov     dx,offset tt
        int 21h
        mov     ax,4c00h
        int 21h

tt      db      "hi dave$"
        end jma