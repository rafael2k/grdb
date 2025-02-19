        .model tiny
        .code
        org     100h
        public start, prog

start:
        mov     dx,offset prog
        mov     ah,9
        int     21h
        mov     ah,4ch
        int     21h
prog    db      "hi dave$"

        end start