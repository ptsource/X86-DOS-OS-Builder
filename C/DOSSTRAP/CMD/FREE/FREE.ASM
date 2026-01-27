;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************
        name    free
        page    60,132
        title   'FREE --- Report free space on disk'


cr      equ     0dh             ;ASCII carriage return
lf      equ     0ah             ;ASCII line feed
blank	equ	20h		;ASCII space code
eom	equ	'$'		;end of string marker


; Here we define a dummy segment containing labels
; for the default file control block and the command tail buffer,
; so that the main program can access those locations.
;
psp	segment para public 'PSP'  

	org	05ch
fcb	label	byte		;default file control block

	org	080h
command	label	byte		;default command buffer

psp	ends


cseg	segment	para public 'CODE'

	assume	cs:cseg,ds:psp,es:data,ss:stack


get_drive proc	near		;get drive selection, if any,
				;otherwise obtain the identity
				;of the current disk drive.
				;Return drive (1=A, 2=B, etc) in AL.
				;
	mov 	al,fcb        	;Pick up the drive code, parsed 
				;by DOS into the default file
				;control block.
	or	al,al		;Is it the default?
	jnz	get_drive1	;no, use it
	mov	ah,19h		;Yes, get the actual current
	int	21h		;drive from PC-DOS.
	inc 	al		;Increment to match FCB code.
get_drive1:			;Return drive code in AL.
	ret
get_drive endp


free 	proc    far             ;entry point from PC-DOS

        push    ds              ;save DS:0000 for final
        xor     ax,ax           ;return to PC-DOS
        push    ax
        mov     ax,data         ;make our data segment
        mov     es,ax           ;addressable via ES register.
        mov     ah,30h		;check version of PC-DOS.	
        int     21h
        cmp     al,2
        jae     free1		;proceed, DOS 2.0 or greater.
        mov     dx,offset msg2  ;DOS 1.x --- print error message
	mov	ax,es		;and exit. First fix up DS register 
	mov	ds,ax		;so error message is addressable.
	jmp	free4

free1:  call    get_drive 	;get drive selection into DL.
	push	es		;copy ES to DS for remainder
	pop	ds		;of the program...
	assume	ds:data		;and tell assembler about it.
	mov	dl,al		
	add	al,'A'-1	;form drive letter from drive code,
	mov	outputb,al	;and put it into the output string. 
	mov	ah,36h		;now call DOS to get free disk space.
	int	21h
	cmp	ax,-1		;was drive invalid?
	je	free3		;yes,go print error message
				;drive was ok, so now registers are...
				;AX=number of sectors per cluster
				;BX=available clusters,
				;CX=number of bytes per sector,
				;DX=total clusters per drive.
				;calculate free space:
	mul	cx		;sectors per cluster * bytes per sector
				;(we assume this won't overflow into DX)
	mul	bx		;then * available clusters 

				;DX:AX now contains free space in bytes.
				;SI = last byte address for converted string.
	mov	si,offset (outputa+9)
	mov	cx,10		;CX = 10, radix for conversion
	call	bin_to_asc	;convert free space value to ASCII,
	mov	dx,offset output
	jmp	free4		;and print it out.

free3:  mov     dx,offset msg1  ;illegal drive, print error

free4:	mov	ah,9		;print the string whose address
	int	21h		;is in DX.
	ret			;then return to DOS.

free   endp


; Convert 32 bit binary value to ASCII string.
;
; Call with  DX:AX = signed 32 bit value
;	     CX    = radix
;            SI    = last byte of area to store resulting string
;	             (make sure enough room is available to store
;		      the string in the radix you have selected.)
;
; Destroys AX, BX, CX, DX, and SI.
;
bin_to_asc proc	near		;convert DX:AX to ASCII.
				;force storage of at least 1 digit.
	mov	byte ptr [si],'0' 
	or	dx,dx		;test sign of 32 bit value,
	pushf			;and save sign on stack.
	jns	bin1		;jump if it was positive.
	not	dx		;it was negative, take 2's complement
	not	ax		;of the value. 
	add	ax,1
	adc	dx,0
bin1:				;divide the 32 bit value by the radix 
				;to extract the next digit for the
				;forming string.
	mov	bx,ax		;is the value zero yet?
	or	bx,dx
	jz	bin3		;yes, we are done converting.
	call	divide		;no, divide by radix.
	add	bl,'0'		;convert the remainder to an ASCII digit.
	cmp	bl,'9'		;we might be converting to hex ASCII,
	jle	bin2		;jump if in range 0-9,
	add	bl,'A'-'9'-1	;correct it if in range A-F.
bin2:	mov	[si],bl		;store this character into string.
	dec	si		;back up through string,
	jmp	bin1		;and do it again.
bin3:				;restore sign flag,
	popf			;was original value negative?
	jns	bin4		;no, jump
				;yes,store sign into output string.
	mov	byte ptr [si],'-'
bin4:	ret			;back to caller.
bin_to_asc endp


; General purpose 32 bit by 16 bit unsigned divide.
; This must be used instead of the plain machine unsigned divide
; for cases where the quotient may overflow 16 bits (for example,
; dividing 100,000 by 2).  If called with a zero divisor, this
; routine returns the dividend unchanged and gives no warning.
;
; Call with DX:AX = 32 bit dividend
;           CX    = divisor
;
; Returns   DX:AX = quotient
;           BX    = remainder
;	    CX    = divisor (unchanged)
;
divide	proc	near		; Divide DX:AX by CX
	jcxz	div1		; exit if divide by zero
	push	ax		; 0:dividend_upper/divisor
	mov	ax,dx
	xor	dx,dx
	div	cx
	mov	bx,ax		; BX = quotient1
	pop	ax		; remainder1:dividend_lower/divisor
	div	cx
	xchg	bx,dx		; DX:AX = quotient1:quotient2
div1:	ret			; BX = remainder2
divide	endp

cseg    ends


data    segment para public 'DATA'

output		db	cr,lf
outputa		db	10 dup (blank)
		db	' bytes free on drive '
outputb		db	'x:',cr,lf,eom

msg1            db      cr,lf
                db      'That disk drive does not exist.'
                db      cr,lf,eom

msg2            db      cr,lf
                db      'Requires DOS version 2 or greater.'
                db      cr,lf,eom

data    ends    


stack   segment para stack 'STACK'
        db      64 dup (?)
stack   ends

        end     free
