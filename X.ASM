hidave  dd      0
        emms
        movd    mm1,eax
        movd    ebx,mm3
        movq    mm1,mm3
        movq    mm3,mm1
        movd    mm1,[hidave]
        movd    [hidave],mm2
        movq    mm1,[hidave]
        movq    [hidave],mm1
        paddb   mm1,mm2
        paddb   mm3,[hidave]
        pslld   mm3,[hidave]
        psllq   mm2,[hidave]
        psllw   mm1,[hidave]
        psrad   mm3,[hidave]
        psraw   mm2,[hidave]
        psrld   mm3,[hidave]
        psrlq   mm2,[hidave]
        psrlw   mm1,[hidave]
        pslld   mm3,4
        psllq   mm2,4
        psllw   mm1,4
        psrad   mm3,4
        psraw   mm2,4
        psrld   mm3,4
        psrlq   mm2,4
        psrlw   mm1,4

        