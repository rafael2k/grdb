	.model	small
        .386    

	.stack 1024
	.data

	.code
	assume ds:_text
hi	dw	56 dup (0);
dpmientry dd	0
txt	db	"hello$"
txt2 db "err$"
errp:
	mov	dx,offset cs:txt2
	mov	ah,9
	int	21h
	mov	ah,4ch
	int 21h
start:
	mov	eax,offset endfs
	shr	eax,4
	add	ax,1
	mov	bx,cs
	mov cx,es
	sub	bx,cx
	add bx,ax
	mov	ax,offset endfl
	shr	ax,4
	add	ax,1
	add	bx,ax
	mov	ah,4ah
	int 21h
	push	cs
	pop		ds
	mov	ax,1687h
	int	2fh
	mov	word ptr [dpmientry],di
	mov	word ptr [dpmientry+2],es
	or	si,si
	jz	runup
	
	mov	bx,si
	mov	ah,48h
	int	21h
	jc	errp
	mov	es,ax
runup:
	mov	ax,1	
	call [dpmientry]	
	jc	errp
	mov		ax,501h
	mov		bx,3
	mov		cx,4
	int		31h
	jc		errp
	
	shl		ebx,16
	mov		bx,cx
	push	ebx
	
	mov		bx,cs
	mov		ax, 0ah
	int		31h
	pop		ecx
	push	ax
	mov		dx,cx
	shr		ecx,16
	mov		bx,ax
	mov		ax,7
	int		31h

	pop		ax
	push	ax
	mov		bx,ax
	mov		cx,0c092h
	and		ax,3
	shl		ax,5
	or		cx,ax
	mov		ax,9
	int		31h

	pop		bx
	push	bx
	mov		cx,-1
	mov		dx,-1
	mov		ax,8
	int		31h
	
	pop		ax
	mov		ss,ax
	mov		esp,30004h

	mov	bx,cs
	mov	ax,0ah
	int	31h
	push	ax
	mov	bx,ax
	mov	ax,cs
	and	ax,3
	shl	ax,5
	mov	cx,0c09ah
	or	cx,ax
	mov	ax,9
	int	31h
	mov	dx,_text32
	sub	cx,cx
	shld	cx,dx,4
	shl	dx,4
	pop bx
	push bx
	mov	ax,7
	int	31h

        mov     cx,-1
        mov     dx,-1
        pop     bx
        push    bx
        mov     ax,8
        int     31h

	push	0

	retf
endfl:
_text32 SEGMENT "CODE" USE32
	db	65600 Dup(0)
	assume cs:_text32
;        db      0eah,0,0,0,0,0,0
	call	go
        int 3
	mov	ax,44
	call go
	mov	ah,4ch
	int	21h
go:
	mov	edx,offset txt
	mov	ah,9
	int	21h
	ret
endfs:
_text32 ENDS

	end start