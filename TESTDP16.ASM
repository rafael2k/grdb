	.model	small

	.stack 256
	.data

	.code
	assume ds:_text
hi	dw	56 dup (0);
dpmientry dd	0
txt	db	"hello$"
txt2 db "err$"
start:
	mov	ax,offset endfl
	shr	ax,4
	add	ax,1
	mov	bx,cs
	mov cx,es
	sub	bx,cx
	add bx,ax
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
	sub ax,ax
	call [dpmientry]	
	jc	errp
	call	go
        int 3
	mov	ax,44
	call go
	mov	ah,4ch
	int	21h
go:
	mov	dx,offset cs:txt
	mov	ah,9
	int	21h
	ret
	
errp:
	mov	dx,offset cs:txt2
	mov	ah,9
	int	21h
	mov	ah,4ch
	int 21h
endfl:
	end start