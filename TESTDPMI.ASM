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
	mov	es,ax
runup:
	sub ax,ax
	call [dpmientry]	
	jc	err
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
	
err:
	mov	dx,offset cs:txt2
	mov	ah,9
	int	21h
	mov	ah,4ch
	int 21h

	end start