;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************
	.xlist
	if1
	%out	REBOOT.ASM
	endif
	if2
	%out	*** PASS 2
	endif
	name	REBOOT
	title	DOS REBOOT PROGRAM
	subttl	REBOOT
	page	66,132
	.list

; ************************************************************************
; **									**
; ** Creates the file specified on the command line, defined by the	**
; ** environment variable REBOOT, C:\CLEAN by default, or no file if	**
; ** command line switch /F is given and performs a cold reboot if	**
; ** command line switch /C is given, or a warm boot by default.  The	**
; ** switch character "-" may be used instead of "/".			**
; **									**
; ************************************************************************

; define bios and dos interrupts, functions, and services
dos_term	equ	20H	; DOS PROGRAM TERMINATION INTERRUPT
dos_func	equ	21H	; DOS FUNCTION INTERRUPT
disp_string	equ	09H	; DOS1 - DISPLAY STRING
create		equ	3CH	; DOS2 - CREATE FILE
close		equ	3EH	; DOS2 - CLOSE FILE

; define constants
lf		equ	0AH	; ^J
cr		equ	0DH	; ^M

dos_flag_seg	equ	00000H		; dos flags memory segment address
dos_boot_flag	equ	00472H		; dos reboot type flag offset

warm		equ	01234H		; warm boot indicator
cold		equ	0FFFFH		; coldboot indicator

reset_seg	equ	0FFFFH		; reset vector segment address
reset_offset	equ	00000H		; reset vector offset
	page
code	segment public
	assume	cs:code,ds:code

	org	0			; PSP

term_inst	dw	(?)		; terminate (int 20H) instruction
mem_size	dw	(?)		; size of available memory
reserved_0	db	(?)		; reserved (normally 0)
call_dispatch	db	5 dup (?)	; call to DOS function dispatcher
term_vec	dd	(?)		; terminate vector
brk_vec		dd	(?)		; break vector
err_vec		dd	(?)		; error vector
dos_use		db	22 dup (?)	; used by DOS
env_ptr		dw	(?)		; environment string pointer
dos_work	db	34 dup (?)	; DOS work area
int21_retf	db	3 dup (?)	; int 21 and retf instructions
reserved_1	db	2 dup (?)	; reserved
fcb_1_ext	db	7 dup (?)	; FCB 1 extension
fcb_1		db	9 dup (?)	; FCB 1
fcb_2_ext	db	7 dup (?)	; FCB 2 extension
fcb_2		db	20 dup (?)	; FCB 2
dta		equ	$		; default dta
attrib		equ	$ + 21		; found file attribute
ftime		equ	$ + 22		; found file time stamp
fdate		equ	$ + 24		; found file date stamp
fsize		equ	$ + 26		; found file size
fname		equ	$ + 30		; found file asciiz filename
parm_size	db	(?)		; parameter size
parm		db	127 dup (?)	; parameter
	page
	org	100H			;

reboot		proc	far

	mov	si,[2CH]		; point to environment strings pointer
	mov	si,[si]			; load pointer to environment strings
	push	si			;
	pop	es			; es = base address of environment strings

	assume	es:nothing

	mov	si,0			; initialize environment string offset

reboot_05:
	mov	al,es:[si]		; load environment character
	cmp	al,0			; end of environment strings?
	jne	reboot_10		; no - test for reboot string

	jmp	reboot_45		; yes - parse command line

reboot_10:
	lea	di,reboot$		; point to reboot string
	mov	cx,len_reboot$		; load counter

reboot_15:
	mov	al,es:[si]		; load environment character
	cmp	al,0			; end of environment string?
	jne	reboot_20		; no - test for match with reboot$

	jmp	reboot_05		; yes - test for end of environment

reboot_20:
	cmp	al,[di]			; match reboot$ character?
	jne	reboot_25		; no - search for end of string

	inc	si			; yes -
	inc	di			;     - advance pointers
	loop	reboot_15		; done? - no - continue

	jmp	reboot_30		; yes - decode environment string

reboot_25:
	inc	si			; advance environment pointer
	mov	al,es:[si]		; load environment character
	cmp	al,0			; end of environment string?
	jne	reboot_25		; no - continue

	inc	si			; yes - point to next string
	jmp	reboot_05		; test for end of environment

reboot_30:
	lea	di,filespec		; point to filespec

reboot_35:
	mov	al,es:[si]		; load environment character
	cmp	al," "			; space?
	jne	reboot_40		; no - store character

	mov	al,0			; yes - load terminator

reboot_40:
	mov	[di],al			; store
	inc	si			;
	inc	di			; advance pointers
	cmp	byte ptr es:[si - 1],0	; done?
	jne	reboot_35		; no - load next character

reboot_45:
	mov	byte ptr[di],0		; yes - terminate filespec
	mov	ax,ds			; load data segment pointer
	mov	es,ax			; set extra segment pointer

	assume	es:code

	cmp	parm_size,0		; any parameter characters?
	jne	reboot_50		; yes - parse command line

	jmp	reboot_100		; no - test for no file flag

reboot_50:
	lea	di,filespec		; yes - point to filespec
	lea	si,parm + 1		; point to command line parameters
	mov	cx,0			; clear filespec character counter

reboot_55:
	lodsb				; load parameter char
	cmp	al," "			; space?
	jne	reboot_60		; no - test for switch character

	mov	byte ptr[di],0		; yes - store terminator
	inc	di			; advance pointer
	jmp	reboot_55		; load next character

reboot_60:
	cmp	al,"/"			; no - switch char?
	je	reboot_65		; yes - parse switch

	cmp	al,"-"			; no - switch char?
	je	reboot_65		; yes - parse switch

	jmp	reboot_85		; no - test for cr

reboot_65:
	lodsb				; load switch character
	cmp	al," "			; space?
	je	reboot_55		; yes - load next character

	cmp	al,cr			; no - cr?
	jne	reboot_70		; no - force lower case

	jmp	reboot_90		; yes - terminate filespec

reboot_70:
	or	al,("A" xor "a")	; force lower case
	cmp	al,"f"			; f?
	je	reboot_75		; yes - set no file flag

	cmp	al,"c"			; no - c?
	je	reboot_80		; yes - set cold flag

	mov	ah,disp_string		; no - indicate display string function
	lea	dx,err_msg_1		; point to message
	int	dos_func		; display message
	int	dos_term		; terminate program

reboot_75:
	mov	nofile_flag,0FFH	; set no file flag
	jmp	reboot_65		; load next char

reboot_80:
	mov	cold_flag,0FFH		; set cold flag
	jmp	reboot_65		; load next char

reboot_85:
	cmp	al,cr			; cr?
	jne	reboot_95		; no - store char

reboot_90:
	jcxz	reboot_100		; any filespec chars?
					; no - test no file flag

	mov	byte ptr[di],0		; yes -
	mov	byte ptr[di + 1],0	;     - store terminator

	jmp	reboot_100		; test no file flag

reboot_95:
	stosb				; store char
	inc	cx			; advance filespec character counter
	jmp	reboot_55		; load next char

reboot_100:
	cmp	nofile_flag,0		; is no file flag set?
	jne	reboot_115		; yes - perform reboot

	lea	dx,def_name		; no - point to default filename
	lea	si,filespec		; point to filespec
	cmp	byte ptr[si],0		; was filespec specified?
	je	reboot_105		; no - create default file

	lea	dx,filespec		; yes - point to filespec

reboot_105:
 	mov	ah,create		; indicate create file function
	mov	cx,0			; indicate normal attributes
	int	dos_func		; create file
	mov	bx,ax			; load handle
	mov	ah,close		; indicate close file function
	int	dos_func		; close file
	mov	si,dx			; load filespec pointer

reboot_110:
	mov	al,byte ptr[si]		; load current filename character
	inc	si			; advance pointer
	cmp	al,0			; found end of current filename?
	jne	reboot_110		; no - continue

	cmp	byte ptr[si],0		; yes - end of filespec?
	je	reboot_115		; yes - perform reboot

	mov	dx,si			; no - point to next filename
	jmp	reboot_105		; create next file

reboot_115:
	mov	cx,warm			; indicate warm boot
	cmp	cold_flag,0		; is cold flag set?
	je	reboot_120		; no - point to dos flags

	mov	cx,cold			; yes - indicate cold boot

reboot_120:
	mov	ax,dos_flag_seg		; load dos flags memory segment address
	mov	ds,ax			; point to low memory

	assume	ds:nothing

	mov	ds:dos_boot_flag,cx	; store boot indicator
	mov	ax,reset_seg		; load reset vector segment address
	push	ax			; store
	mov	ax,reset_offset		; load reset vector offset
	push	ax			;
	ret				;

reboot		endp
	page
; data storage

nofile_flag	db	0		; no file flag
cold_flag	db	0		; cold boot flag

reboot$		db	"REBOOT="	; reboot string
len_reboot$	equ	$ - reboot$	; length of reboot string

def_name	db	"c:\clean",0,0	; default asciiz filename
filespec	db	80 dup (0)	; asciiz filespec

err_msg_1	db	"REBOOT: Usage: REBOOT [/fc] [file ...]",cr,lf,"$"
	page
code	ends

	end	reboot
