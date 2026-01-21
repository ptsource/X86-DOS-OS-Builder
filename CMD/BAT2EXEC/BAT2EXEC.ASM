;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************
		page	66,132
                code	segment
		assume	cs:code

		org	2ch
local_environment	dw	?		;Word containing the segment
						;  of the program's env. block.
		org	80h
command_tail	db	?			;Offset of the command tail.

		org	100h

main:		jmp	initialize
program 	db	"BAT2EXEC","$",1Ah
;----------------------------------------------------------------------------
;Equates used to find data offsets in the compiled program.
;----------------------------------------------------------------------------
BUFF_SIZE    	equ	255			;Size of runtime buffers

std_data_size	equ	offset data_end - data_start
code_start_ptr	equ	[bp + offset code_start - offset data_start]
com_stack_ptr	equ	[bp + offset stack_ptr - offset data_start]
com_prog_size	equ	[bp + offset prog_segsize - offset data_start]
com_label_start equ	[bp + offset label_list_strt - offset data_start]
parse_buff	equ	[bp + offset prse_buff_ptr - offset data_start]
parse2_buff	equ	[bp + offset prs2_buff_ptr - offset data_start]
exec_buff	equ	[bp + offset exec_buff_ptr - offset data_start]
forloop_buff	equ	[bp + offset for_buff_ptr - offset data_start]
forloop_ptr	equ	[bp + offset floop_ptr - offset data_start]
stdout_hdl	equ	[bp + offset file_handle1 - offset data_start]
outfile_hdl	equ	[bp + offset file_handle2 - offset data_start]
stdin_hdl	equ	[bp + offset file_handle3 - offset data_start]
infile_hdl	equ	[bp + offset file_handle4 - offset data_start]
environment_seg equ	[bp + offset master_env - offset data_start]
dos_version	equ	[bp + offset version_num - offset data_start]
process_rc	equ	[bp + offset proc_rc - offset data_start]
shift_count	equ	[bp + offset shift_cnt - offset data_start]

code_call_size	equ	offset code_call_end - offset code_call
code_jmp_size	equ	offset code_jmp_end - offset code_jmp
code_jc_size	equ	offset code_jc_end - offset code_jc
code_jnc_size	equ	offset code_jnc_end - offset code_jnc
code_jmpdis_size   equ	   offset code_jmpdis_end - offset code_jmpdis
code_leasi_size equ	offset code_leasi_end - offset code_leasi
code_movsi_size equ	offset code_movsi_end - offset code_movsi
code_movsiim_size equ	offset code_movsiim_end - offset code_movsiim
code_leadi_size equ	offset code_leadi_end - offset code_leadi
code_movdi_size equ	offset code_movdi_end - offset code_movdi
code_movdiim_size equ	offset code_movdiim_end - offset code_movdiim
;============================================================================
;Compiler data
;============================================================================
command_table	db	"IF",0                  ;Commands processed by
		db	"REM",0                 ;  compiler
		db	"FOR",0
		db	"ECHO",0
		db	"GOTO",0
		db	"EXIT",0
		db	"PAUSE",0
		db	"SHIFT",0
		db	"SET",0
		db	"CALL",0
		db	"PATH",0
		db	"PROMPT",0
		db	"CD",0                  ;DOS commands internal to
		db	"LH",0                  ;DOS commands internal to
		db	"MD",0                  ;  command.com.
		db	"RD",0
		db	"CLS",0
		db	"DIR",0
		db	"DEL",0
		db	"REN",0
		db	"VER",0
		db	"VOL",0
		db	"CTTY",0
		db	"CHCP",0
		db	"TYPE",0
		db	"COPY",0
		db	"DATE",0
		db	"TIME",0
		db	"ERASE",0
		db	"CHDIR",0
		db	"MKDIR",0
		db	"RMDIR",0
		db	"BREAK",0
		db	"RENAME",0
		db	"DELETE",0
		db	"VERIFY",0
		db	"COMMAND",0,0

batcmd_jmptbl	dw	if_cmd			;if command
		dw	rem_cmd 		;rem command
		dw	for_cmd 		;for command
		dw	echo_cmd		;echo command
		dw	goto_cmd		;goto command
		dw	rem_cmd 		;exit command
		dw	pause_cmd		;pause command
		dw	shift_cmd		;shift command
		dw	set_cmd 		;set command

		dw	internal_cmd		;call command
		dw	path_cmd 		;Path command
		dw	prompt_cmd 		;Prompt command
		dw	internal_cmd		;DOS internal command
		dw	external_cmd		;DOS program
		dw	label_cmd		;Process BAT label
batcmd_jmptbl1	=	$

ifstr1		db	"ERRORLEVEL"
ifstr2		db	"EXIST"

internal_cmdsw	db	"/C "                   ;Switch for transient commands

for_active_flag db	0			;Set if parsing a FOR loop
goto_active	db	0			;Set if goto parsed
goto_data_ptr	dw	0			;Data offset of last goto	

temp1		dw	0			;Temp data storage.

cmd_switches	db	?			;Used if command line switches
cmd_switch_end	=	$			;  needed.

last_routine	dw	offset init_code_next	;Last canned routine used.

codebuff_start	dw	0			;Buffer to construct the code
codebuff_ptr	dd	0			;  image of the COM file.

databuff_start	dw	?			;Buffer to hold the data
databuff_end	dw	?			;  image of the COM file.

firstlabel	dw	-1			;Ptr to 1st label in COM file

outbuff_ptr	dd	0			;Buffer to hold the final
outbuff_end	dw	0			;  image of the COM file.

quote_flag	db	0			;Disable translate flag
redirect_in	db	0			;Input redirection flag
redirect_out	db	0			;Output redirection flag

pipe_toggle	db	0			;Piping file flag
pipein_file	dw	0
pipein_flag	db	0
pipeout_file	dw	0
pipeout_flag	db	0
pipe1_file	dw	0
		db	"T^M^P_$1.!!!",0	;Name of piping file 1
pipe2_file	dw	0
		db	"T^M^P_$2.!!!",0	;Name of piping file 2

inbuff_ptr	dw	offset end_of_code+512	;Buffer for BAT file
inbuff_size	dw	1024 			;Size of input buffer

file_handle	dw	-1			;Handle of BAT file
file_linecount	dw	0			;Line number being processed.

com_string	db	".COM",0		;Extension for output file
outfile_name	db	13 dup (" ")		;Name of output file.

filemsg1	db	13,10,"Error in line $" ;File identification message.

errmsg0 	db	"Need DOS 2.0 or greater$"
errmsg1 	db	13,10,"Usage: BAT2EXEC filename.ext",13,10,"$"
errmsg2 	db	"Can",39,"t find input file$"
errmsg3 	db	"Not enough memory$"
errmsg4 	db	"No input file specified$"
errmsg5 	db	"COM file size too big$"
errmsg6 	db	"Syntax error$"
errmsg7 	db	"Compiler data buffer full$"
errmsg8 	db	"Label defined more than once$"
errmsg9 	db	"Label "
errmsg9labl	db	8 dup (" ")
		db	"not found$"
errmsg10	db	"Illegal disk specified$"
errmsg11	db	"FOR loops cannot be nested$"

endmsg		db	13,10,"$"

;----------------------------------------------------------------------------
; Start of compiler code.
;----------------------------------------------------------------------------
initialize	proc	near
		assume	cs:code,ds:code,es:code
		mov	dx,offset program	;Display message.
		mov	ah,9
		int	21h
		cld				;Set string operations 'up.'
		mov	ah,30h			;Get DOS version, run only
		int	21h			;  if 2.0 or greater.
		xchg	al,ah			;Swap major, minor numbers
		mov	dx,offset errmsg0	;Bad DOS version
		cmp	ah,2
		jb	jmp_disp_error

		mov	sp,offset end_of_code + 512	;Move stack
		mov	ah,4ah				;Reduce memory
		mov	bx,1000h			; allocation to 64K
		int	21h

		mov	ax,inbuff_ptr		;Compute start of buffer for
		add	ax,inbuff_size		;  COM file data.
		mov	databuff_start,ax

		mov	ah,48h			;Allocate memory block for
		mov	bx,1000h		;  intermediate buffer.
		int	21h
		mov	dx,offset errmsg3	;Not enough memory msg
		jc	jmp_disp_error
		mov	word ptr codebuff_ptr[2],ax	;Save segment.

		mov	ah,48h			;Allocate memory block for
		mov	bx,1000h		;  output file buffer.
		int	21h
		jc	jmp_disp_error
		mov	word ptr outbuff_ptr[2],ax	;Save segment.
;
;Parse the command line for switches.
;
		mov	si,offset command_tail
		xor	cx,cx
		or	cl,[si] 		;Get command line length
		je 	init_0		      	;If zero, report no filename
		inc	si
parse_cmdline_l1:
		xor	bl,bl			;Search for the next
		call	scan4char		;  non-space character.
		jnc	init_1		      	;If zero, report no filename
init_0:
		mov	dx,offset errmsg1
		jmp	short jmp_disp_error	;If none, report no filename
init_1:
		mov	al,[si]
		cmp	al,"/"                  ;See if command switch
		je	parse_error
		call	loadbatfile		;Load input BAT file
		jc	jmp_disp_error
		jmp	short parse_cmdline_end
parse_error:
		mov	dx,offset errmsg2
jmp_disp_error:
		jmp	disp_error
parse_cmdline_end:
;
;Compile BAT file line by line.
;
		mov	si,inbuff_ptr		;SI points to input BAT file
		mov	di,databuff_start	;DI points to COM file data.
		add	di,std_data_size	;Make room for std data set.
new_line:
		inc	file_linecount		;Inc line number
new_line1:
		xor	bl,bl			;Look for 1st character
		call	scan4char		;If nothing on line, check
		jc	comp_endcheck		;  for EOF
		call	redirect_check
		cmp	byte ptr [si],'@'	;See if non echo prefix
		jne	comp_1
		inc	si			;Move past @
comp_1:
		call	parse			;Parse 1st word in the line.
		jc 	jmp_disp_error		
		jmp	short new_line
comp_endcheck:
		cmp	al,13			;See if carrage return, if so
		je	new_line		;  continue.
		cmp	file_handle,-1		;If at end of buffer, check
		je	comp_end		;  to see if any more of the
		call	loadbatfile		;  file to read.
		jc	jmp_disp_error
		mov	si,inbuff_ptr		;Reset SI to start of buffer.
		jmp	short new_line1		
comp_end:
;
;Inline code complete, append terminate code.
;
		call	redirect_close
		mov	databuff_end,di 	;Save ptr to end of data.
		les	di,codebuff_ptr
		assume	es:nothing
		mov	si,offset end_code	;Append terminate code
		mov	cx,offset end_code_end-offset end_code
		rep	movsb
		mov	word ptr codebuff_ptr,di ;Save ptr to end of COM code.
;
;File processed. Assemble data and code into one routine.  Start by
;stringing the canned routines together using the links set by the
;INCLUDE routine.
;
		les	di,outbuff_ptr		 ;Get ptr to output buffer
		mov	si,offset init_code_next ;  for COM file.
file_1: 	mov	cx,[si-2]		;Get size of routine
		push	[si]			;Save pointer to next routine
		add	si,4			;Skip past number of links
		rep	movsb			;Copy routine to COM file.
		pop	si
		or	si,si			;See if last routine
		jne	file_1			;No, loop back.
;
;Save starting offset of data to be used by the COM program.
;
		mov	bp,offset data_start_ptr-offset init_code
		mov	ax,100h 		;AX = end pointer
		add	ax,di			;Add length of canned routines.
		mov	es:[bp],ax		;Save data start pointer
		mov	bp,di			;Use BP as starting data offset

		mov	si,databuff_start	;Compute length of COM data
		mov	cx,databuff_end 	;  plus the canned routines.
		sub	cx,si
		add	ax,cx			;Add data length to end ptr
;
;Now that we have the length of the canned routines and the data, we can
;compute the starting offset of the inline code.  Use this number to adjust
;the jump table entries in the label list.  While fixing offsets check to
;see that all labels have code offsets, if not, print no label error msg.
;When complete, append data to file.
;
		mov	bx,offset firstlabel	;Get pointer to the first label
		mov	dx,[bx] 		;Get offset to 1st label entry
		add	dx,bx			;Add in BX to get absolute off
file_11:
		cmp	word ptr [bx],-1	;See if at end of label list.
		je	file_13
		add	bx,[bx] 		;Get next in list
		cmp	word ptr [bx+2],-1	;See if label ptr to code
		je	file_12 		;  initialized. No, error.
		add	[bx+2],ax		;Add starting offset of code
		jmp	short file_11
file_12:
		mov	si,bx			;Label not defined as a
		add	si,5			;  destination.  Print error
		xor	cx,cx			;  message inc lost label.
		mov	cl,[bx+4]		;Get size of label
		push	cs
		pop	es
		mov	di,offset errmsg9labl
		rep	movsb
		mov	dx,offset errmsg9	;Label not found msg
		jmp	disp_error
file_13:
		rep	movsb			;Append data to COM file.
		sub	dx,databuff_start	;Set pointer to 1st label list
		mov	es:com_label_start,dx	;Initialize pointer.
;
;Append the inline code to the program.
;
		mov	ax,100h
		add	ax,di
		mov	es:code_start_ptr,ax	;Save offset of main code.

		mov	cx,word ptr codebuff_ptr
		mov	si,codebuff_start	;Get pointer to code
		mov	ds,word ptr codebuff_ptr[2]
		assume	ds:nothing
		sub	cx,si			;Get size of code
		add	ax,cx			;Make sure canned routines
		jnc	file_2			;  and data < 64 K bytes.
file_too_big:	mov	dx,offset errmsg5	;COM file too big msg
		jmp	disp_error
file_2:
		rep	movsb			;Append inline code.
;
;Compute the size of the data buffers and the stack used by the COM program.
;Write these numbers to the COM file data area.
;
		push	cs
		pop	ds
		assume	ds:code
		add	ax,512			;Add room for stack
		jc	file_too_big
		and	ax,0fffeh		;Set stack on even word.
		mov	es:com_stack_ptr,ax	;Save run time stack pointer
		add	ax,2			;Make room for buff length word
		mov	es:parse_buff,ax	;Save ptr to parsing buffer.
		add	ax,BUFF_SIZE+2		;Add room for buffer 2
		jc	file_too_big
		mov	es:parse2_buff,ax	;Save ptr to parsing buffer 2
		add	ax,BUFF_SIZE+2		;Add room for buffer
		jc	file_too_big
		mov	es:exec_buff,ax		;Save ptr to exec buffer 
		add	ax,BUFF_SIZE+2		;Add room for buffer
		jc	file_too_big
		mov	es:forloop_buff,ax	;Save ptr to For loop buffer
		add	ax,BUFF_SIZE		;Add room for buffer
		jc	file_too_big

		mov	outbuff_end,di		;Save end pointer to file
		add	ax,15
		jc	file_3			;Compute size of COM file
		mov	cl,4			;  in paragraphs.
		shr	ax,cl
		mov	es:com_prog_size,ax	;Save file size
		mov	byte ptr es:shift_count,0	;Clear shift count
		mov	byte ptr es:process_rc,0	;Clear return code
file_3:
;
;Write file to disk.
;
		mov	ah,3ch			;Create file
		xor	cx,cx			;Normal attributes
		mov	dx,offset outfile_name	;Name of file
		int	21h

		mov	bx,ax			;Copy handle
		mov	ah,40h			;Write file
		push	ds
		lds	dx,outbuff_ptr		;Get start of buffer
		mov	cx,cs:[outbuff_end]	;Get number of bytes to write
		sub	cx,dx
		int	21h			;Write file to disk
		pop	ds

		mov	ah,3eh			;Close file
		int	21h
;
;Compile complete. Clean up and end.
;
good_exit:
		xor	al,al			;Return code = 0
exit:
		push	ax			;Save return code
		mov	ah,49h			;Release memory block used
		mov	es,word ptr cs:[codebuff_ptr+2] ;  for file buffer.
		int	21h

		mov	bx,file_handle
		cmp	bx,-1			;See if input file closed.
		jne	exit_1    		;  If not, do so.
		mov	ah,3eh			;Close file.
		int	21h
exit_1:
		pop	ax			;Get back return code
		mov	ah,4Ch			;Terminate
		int	21h
;
;Display error message.
;
disp_error:
		push	cs
		pop	ds
		assume	ds:code
		cmp	file_linecount,0
		je	disp_error1		;If processing a file, print
		push	dx			;  a message informing the
		mov	dx,offset filemsg1	;  user the line that
		call	printmsg		;  contained the error.
		mov	ax,file_linecount
		call	hex2asc
		mov	dx,offset endmsg
		call	printmsg
		pop	dx
disp_error1:
		call	printmsgcr		;print string
		mov	al,01			;Terminate with RC = 1
		jmp	short exit

;-----------------------------------------------------------------------------
; PARSE  Parse a statment.
; Entry:  SI - Pointer to string to parse.
;	  DI - Pointer to end of COM file data.
; Exit:   CF - Set if error.
;	  SI - Updated.
;-----------------------------------------------------------------------------
parse		proc	near
		mov	bx,14
		mov	al,[si] 		;See if label, if so, skip 
		cmp	al,":"			;  cmd search.
		je	parse_2

		mov	bx,12
		cmp	al,"%"                  ;See if cmd line param or env
		je	parse_2 		;  var. If so, internal cmd

		mov	ax,[si+1]		;See if change to default disk
		cmp	al,":"
		jne	parse_1

		mov	bx, 12			;Set internal command.
		cmp	ah," "
		jbe	parse_2
parse_1:
		call	capsalpha		;Capitalize batch command
		push	di			;Search list of BAT cmds.
		mov	di,offset command_table
		call	findstr
		pop	di
parse_2:
		push	bx			;Scan past command except for
		cmp	bx,8			;  external progs, inter cmds,
		ja	parse_3 		;  and labels.
		mov	bl,1
		call	scan4char
		jnc	parse_3 		;If end of line, back up to
		dec	si			;  show CR.
parse_3:
		pop	bx
		shl	bx,1			;Compute offset of routine to
		add	bx,offset batcmd_jmptbl ;  call.
		call	[bx]			;Call routine to compile line.
		ret
parse		endp

;-----------------------------------------------------------------------------
; FINDSTR  determines if a string is in a list.
; Entry:  SI - Pointer to ASCII string to find.
;	  DI - Pointer to list of ASCIIZ strings.
;	  CX - Size of string
; Exit:   CF - Clear if string found
;	  BX - If CF clear, index into list
;-----------------------------------------------------------------------------
findstr 	proc	near
		push	cx
		push	es
		push	cs			;Point ES:DI to table of
		pop	es			;  batch commands.
		xor	dx,dx
		or 	dx,cx			;Save length of string
		je	finds_3
		xor	bx,bx			;Zero index counter
finds_1:
		push	si
		mov	cx,dx			;Restore command size
		repe	cmpsb			;Compare command
		pop	si
		jne	finds_11
		cmp	byte ptr [di],0		;See if at end of compare str
		je	string_found
finds_11:		
		inc	bx
		xor	al,al
		cmp	[di-1],al
		jne	finds_2
		dec	di
finds_2:
		mov	cx,10			;Scan to next zero
		repne	scasb
		cmp	byte ptr [di],0 	;See if second zero. If so
		jne	finds_1 		;  end of list.
finds_3:
		mov	bx,13
		stc				;Indicate string not found
findstr_exit:
		pop	es
		pop	cx
		ret
string_found:
		cmp	bx,12			;If past the BAT commands,
		jb	findstr_3		;  then it is an internal cmd.
		mov	bx,12
findstr_3:
		clc				;Set string found flag
		jmp	short findstr_exit
findstr 	endp

;-----------------------------------------------------------------------------
; CAPSALPHA capitalizes word pointed to by SI
; Entry:  SI - Pointer to ASCII word to capitalize
; Exit:   CX - Size of word
;-----------------------------------------------------------------------------
capsalpha	proc near
		assume	ds:nothing,es:nothing
		push	ax
		xor	ax,ax			;Exit on non-alpha chars
		jmp	short capsword_entry2
capsalpha	endp

;-----------------------------------------------------------------------------
; CAPSWORD capitalizes word pointed to by SI
; Entry:  SI - Pointer to ASCII word to capitalize
; Exit:   CX - Size of word
;-----------------------------------------------------------------------------
capsword	proc near
		assume	ds:nothing,es:nothing
		push	ax
		mov	ah,1			;Ignore extra characters
capsword_entry2:
		push	di
		push	si
		push	es
		push	ds			;Set ES:DI = DS:SI
		pop	es
		mov	di,si
		xor	cx,cx			;Clear byte counter.
caps_1:
		lodsb				;Get character
		cmp	al," "                  ;Allow any non-space character
		jbe	caps_exit
		call	capschar
		jnc	caps_2
		or	ah,ah
		je	caps_exit
caps_2:
		stosb				;Save character
		inc	cx			;Inc byte counter
		jmp	short caps_1
caps_exit:
		pop	es
		pop	si
		pop	di
		pop	ax
		ret
capsword	endp

;-----------------------------------------------------------------------------
; CAPSCHAR capitalizes character in AL
; Entry:  AL - ASCII char to capitalize
; Exit:   CX - Size of word
;-----------------------------------------------------------------------------
capschar	proc near
		assume	ds:nothing,es:nothing

		cmp	al,"a"                  ;If between a and z,
		jb	caps_char_2   		;  capitalize it.
		cmp	al,"z"
		ja	caps_char_exit
		and	al,0DFh
caps_char_1:
		clc
		jmp	short caps_char_exit
caps_char_2:
		cmp	al,'Z'
		ja	caps_char_3
		cmp	al,'A'
		jae	caps_char_1
caps_char_3:
		stc
caps_char_exit:
		ret
capschar	endp

;-----------------------------------------------------------------------------
; REDIRECT CLOSE post process redirection commands
; Entry:  DI - Pointer to end of COM file data.
; Exit:   CF - Set if error.
;	  Batch file line updated to remove any redirection symbols
;-----------------------------------------------------------------------------
redirect_close	proc	near
		assume	cs:code,ds:code
		cmp	redirect_in,0		;See if redirecton active
		je	redirclose_1
		mov	redirect_in,0
		mov	bx,offset redirci_next	;Append close redirect file
		call	include_code		;  routine to code.
		xor	cx,cx
		call	inline_code
redirclose_1:
		cmp	redirect_out,0		;See if redirecton active
		je	redirclose_2
		mov	redirect_out,0
		mov	bx,offset redirco_next	;Append close redirect file
		call	include_code		;  routine to code.
		xor	cx,cx
		call	inline_code
redirclose_2:
		cmp	pipein_flag,0		;See if in pipe curr active
		je 	redirclose_3
		mov	dx,pipein_file		;Get offset of input pipe file
		mov	cx,1			;Indicate parameter type
		mov	bx,offset redirdel_next	;Delete the piping file
		call	include_code
		call	inline_code		
		mov	pipein_flag,0		;Clear flag
redirclose_3:
		cmp	pipeout_flag,0		;See if out pipe curr active
		je 	redirclose_exit
		mov	dx,pipeout_file		;Get offset of input pipe file
		xor	bx,bx			;Add output redirection code
		xor	ax,ax			;  to file.
		call	redirect_openi
		mov	pipein_flag,1		;Set pipe input flag
		mov	pipeout_flag,0		;Clear pipe output flag
		mov	pipein_file,dx		;Copy pointer to filename
redirclose_exit:
		ret
redirect_close	endp

;-----------------------------------------------------------------------------
; REDIRECT CHECK process redirection commands
; Entry:  SI - Pointer to current BAT file line
;	  DI - Pointer to end of COM file data.
; Exit:   CF - Set if error.
;	  Source file line updated to remove any redirection symbols
;-----------------------------------------------------------------------------
redirect_check	proc	near
		assume	cs:code,ds:code
		push	si
		call	redirect_close
		mov	quote_flag,0
redirect_1:
		mov	bp,si			;Save current position
		lodsb
		cmp	al,'"'                  ;See if quote
		jne	redirect_2
		not	quote_flag
redirect_2:
		cmp	quote_flag,0		;Ignore characters in quotes
		jne	redirect_1
;
; Check for piping
;
		cmp	al,'|'                  ;Check for piping symbol
		jne	redirect_5 
		mov	byte ptr [si-1],13	;Replace | with CR
 
		mov	bx,offset pipe1_file	;Get offset of pipe file to
		cmp	pipe_toggle,0		;  use.  Alternate files so
		jne	redirect_3 		;  that input and output files
		mov	bx,offset pipe2_file	;  don't get mixed up.
redirect_3:
		not	pipe_toggle
		xor	dx,dx			;If file not already used, 
		or 	dx,[bx]			;  load the filename into 
		jne	redirect_4 		;  the COM data buffer.
		mov	dx,di
		sub	dx,databuff_start	;Compute offset of filename
		mov	[bx],dx			;Save pointer to filename
		lea	si,[bx+2]		;Get address of filename
		mov	ah,1	
		call	copy_string		;Copy name to COM data buffer
		xor	al,al			;Terminate filename with zero
		stosb
redirect_4:
		mov	pipeout_file,dx
		mov	pipeout_flag,1
		xor	bx,bx			;Add output redirection code
		xor	ax,ax			;  to file.
		call	redirect_openo
		jmp	short redirect_exit	;Terminate line scan.
;
; Check for output redirection
;
redirect_5:
		cmp	al,'>'                  ;Check for redirect out
		jne	redirect_7
		xor	bx,bx
		cmp	byte ptr [si],'>'       ;Check for append redirect
		jne	redirect_6
		lodsb				;Remove 2nd >
		inc	bx			;Set append flag
redirect_6:
		push	bx			;Save append flag
		xor	bl,bl
		call	scan4char		;Get filename
		mov	dx,di
		mov	ah,1			;Copy only one word
		call	copy_string
		xor	al,al			;Terminate name with zero
		stosb
		sub	dx,databuff_start	;Compute offset of filename
		pop	ax			;Get append flag
		call	redirect_openo
		call	erase_redirect		;Erase redirect from line.
		jmp	short redirect_1
redirect_7:
		cmp	al,'<'                  ;Check for redirect in
		jne	redirect_10
		xor	bl,bl
		call	scan4char		;Get filename
		mov	dx,di
		mov	ah,1			;Copy only one word
		call	copy_string
		xor	al,al			;Terminate name with zero
		stosb

		sub	dx,databuff_start	;Compute offset of filename
		call	redirect_openi
		call	erase_redirect		;Erase redirect from line.
		jmp	redirect_1
redirect_10:
		cmp	al,13
		je	redirect_exit
		jmp	redirect_1
redirect_exit:
		clc
		pop	si
		ret
redirect_check	endp

;-----------------------------------------------------------------------------
; REDIRECT OPENO process redirection commands
; Entry:  AX - 1 = append file.
; Entry:  DX - Offset from data buffer start of file name
;	  BX - 0 no translation of filename.
;-----------------------------------------------------------------------------
redirect_openo	proc	near
		assume	cs:code,ds:code
		push	si
		push	ax			;Save append flag
		mov	cx,0031h		;Indicate parameter type
		or	bx,bx			;See if env var or cmd line
		je	redirect_oo1		;  parms.

		mov	bx,offset procstr_next	;Get offset of translate
		call	include_code		;  routine. Include if needed.

		push	bx
		mov	bx,offset prse_buff_ptr - offset data_start
		mov	cx,0021h		;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	dx,bx
		pop	bx
		mov	cx,32h
redirect_oo1:
		mov	bx,offset rediroo_next	;Append open redirect file
		call	include_code
		pop	bx			;Restore append flag
		call	inline_code
		mov	redirect_out,1		;Set redirect active flag
		pop	si
		ret
redirect_openo	endp

;-----------------------------------------------------------------------------
; REDIRECT OPENI loads code to open a file for input redirection
; Entry:  DX - Offset from data buffer start of file name
;	  BX - 0 no translation of filename.
;-----------------------------------------------------------------------------
redirect_openi	proc	near
		assume	cs:code,ds:code
		push	si
		mov	cx,1			;Indicate parameter type
		or	bx,bx			;See if env var or cmd line
		je	redirect_oi1		;  parms.

		mov	bx,offset procstr_next	;Get offset of translate
		call	include_code		;  routine. Include if needed.

		mov	bx,offset prse_buff_ptr - offset data_start
		mov	cx,21h			;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	dx,bx
		mov	cx,2
redirect_oi1:
		mov	bx,offset rediroi_next	;Append open redirect file
		call	include_code
		call	inline_code
		mov	redirect_in,1		;Set redirect active flag
		pop	si
		ret
redirect_openi	endp

;-----------------------------------------------------------------------------
; ERASE REDIRECT
; Entry:  BP - Pointer to redirect character
;	  SI - Pointer to end of redirect phrase.
;-----------------------------------------------------------------------------
erase_redirect	proc	near
		assume	cs:code,ds:code
		push	di			;Save ptr to data buffer
		mov	al,' '
		mov	di,bp			;Get start of redirect string
		dec	si
erase_1:
		stosb
		cmp	di,si
		jb	erase_1
		pop	di
		ret
erase_redirect	endp

;-----------------------------------------------------------------------------
; IF CMD compiles an IF command.
; Entry:  SI - Pointer to character after the IF command
;	  DI - Pointer to end of compiled data.
; Exit:   AL - Error code if CF set
;	  CF - Set if error
;	  SI,DI updated.
;-----------------------------------------------------------------------------
if_cmd		proc	near
		assume	cs:code,ds:code
		xor	bl,bl			;Find 1st char of next word
		call	scan4char
		mov	cx,si			;Save pointer to test
		mov	dx,di
		mov	bp,0			;Clear 'NOT' flag
;
;See if NOT prefix is used in test
;
		lodsw				;Get 1st two chars of test
		or	ax,2020h
		cmp	ax,'on'                 ;See if 'no'
		jne	if_cmd_chk_cmp
		lodsw				;Get 2nd and 3rd characters
		or	al,20h			;Convert 3rd char to lower
		cmp	al,'t'                  ;  case.   See if last char is
		jne	if_cmd_chk_cmp 		;  't' followed by s space
		cmp	ah,' '
		ja	if_cmd_chk_cmp 
		inc	bp
		xor	bl,bl			;Find next word
		call	scan4char
		mov	cx,si
;
;Test for string compare by looking for == signs.
;
if_cmd_chk_cmp:
		mov	si,cx			;Restore pointer to condition
		mov	bl,3			;Find next space or equal sign
		call	scan4char
		jc	if_syntax_jmp
		xor	bl,bl
		call	scan4char		;Find next word
		cmp	word ptr [si],"=="	;See if string compare		
		je 	if_cmd_cmp1		;No, check other tests
		jmp	if_cmd_chk_errlev
if_cmd_cmp1:
		inc	si			;Move SI past equals signs
		inc	si
		xor	bl,bl			;Find second string
		call	scan4char
		jnc	if_cmd_cmp2
if_syntax_jmp:
		jmp	short if_syntax
if_cmd_cmp2:
		push	si			;Save pointer to 2nd string
		mov	si,cx			;Restore ptr to 1st string
		push	di			;Save ptr to size byte
		inc	di
		mov	dx,di			;Save ptr to start of string
		sub	dx,databuff_start
		mov	ah,2			;Copy only one word
		call	copy_string		;Load string into data space
		xor	al,al
		stosb
		or	bx,bx			;See if translation is needed
		pop	bx			;Restore pointer to size byte
		mov	[bx],cl 		;Save length of string
		mov	cl,1			;Assume LEA parameter call
		je	if_cmd_03

		mov	bx,offset procstr_next	;Append translate string
		call	include_code		;  routine to code.
		mov	bx,offset prs2_buff_ptr - offset data_start
		mov	cx,0021h		;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	dx,bx			;Copy ptr to buffer.
		mov	cx,2			;Use MOV parameter type
if_cmd_03:
		pop	si			;Restore ptr to 2nd string
		push	dx			;Save pointer to 1st string
		push	cx			;Save parameter type
if_cmd_04:
		push	di			;Save ptr to size byte
		inc	di
		mov	dx,di			;Save ptr to start of string
		sub	dx,databuff_start
		mov	ah,2
		call	copy_string		;Load string into data space
		xor	al,al
		stosb
		or	bx,bx			;See if translation is needed
		pop	bx
		mov	[bx],cl 		;Save length of string
		mov	cx,10h			;Set parameter type
		je	if_cmd_06

		mov	bx,offset procstr_next	;Append translate string
		call	include_code		;  routine to code.
		mov	bx,offset prse_buff_ptr - offset data_start
		mov	cx,0021h		;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	dx,bx			;Copy ptr to buffer.
		mov	cx,20h			;Use proper parameter type
if_cmd_06:
		mov	bx,offset ifequal_next	;Append comparison code
		call	include_code
		pop	bx			;Restore param 1 type
		and	bl,0fh
		or	cl,bl			;Combine parameter types
		mov	bx,dx			;Move parameter 2
		pop	dx			;Restore parameter 1
		call	inline_code		;Add call to string compare
		jmp	if_cmd_10
if_syntax:
		mov	dx,offset errmsg6	;Syntax error.
		stc
		jmp	if_exit
;
;See if ERRORLEVEL test.
;
if_cmd_chk_errlev:
		mov	si,cx			;Restore pointer to 1st string
		mov 	bx,cx			;Save pointer to 1st string
		mov	di,offset ifstr1	;See if ERRORLEVEL test
		call	capsalpha
		cmp	cx,10
		jne	if_cmd_2
		repe	cmpsb			;Compare strings
		jne	if_cmd_2
		mov	bx,offset iferrlev_next ;Save offset of errlev code
		push	bx			;  on stack.  Use exist code
 		xor	bl,bl
		call	scan4char		;Scan to next word.
		cmp	byte ptr [si],'='
		jne	if_cmd_21
		inc	si
 		xor	bl,bl
		call	scan4char		;Scan to next word.
		jmp	short if_cmd_21 	;  to append error code.
;
;See if EXIST test.
;
if_cmd_2:
		mov	si,bx			;Restore pointer to 1st string
		mov	di,offset ifstr2	;See if EXIST test
		cmp	cx,5			;Check length of string
		jne	if_syntax
		repe	cmpsb			;Compare strings
		jne	if_syntax
		mov	bx,offset ifexist_next	;Save test existance code off
		push	bx
 		xor	bl,bl
		call	scan4char		;Scan to next word.
if_cmd_21:
		mov	di,dx			;Restore data pointer
		sub	dx,databuff_start
		mov	ah,2
		call	copy_string
		xor	al,al			;Terminate string with zero.
		stosb
		mov	cl,21h			;Set parameter type
		or	bx,bx			;See if translation is needed
		je	if_cmd_3

		mov	bx,offset procstr_next	;Append translate string
		call	include_code		;  routine to code.
		mov	bx,offset prse_buff_ptr - offset data_start
		mov	cx,0021h		;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	dx,bx			;Copy ptr to buffer.
		mov	cl,22h			;Use proper parameter type
if_cmd_3:
		pop	bx			;Restore test code offset
		call	include_code
		mov	bx,offset prs2_buff_ptr - offset data_start
		call	inline_code		;Insert exist test call
if_cmd_10:
		mov	cx,200h 		;Include Jump if carry opcode
		or	bp,bp
		je	if_cmd_12
		mov	cx,300h 		;Change to Jump if not carry
if_cmd_12:
		call	inline_code
		push	ax			;Save address of jmp to modify
		push	word ptr codebuff_ptr	;Save current code buff ptr
;
;Compile the remainder of the line as if it were a normal statment.
;
		xor	bl,bl			;Scan for next word
		call	scan4char
		call	parse			;Compile remainder of line.

		pop	cx			;Compute the difference for the
		pop	bx			;  jmp opcode.
		jc	if_exit 		;If error during parse, exit.
		push	es
		mov	ax,word ptr codebuff_ptr
		mov	es,word ptr codebuff_ptr[2]
		sub	ax,cx
		mov	es:[bx],ax		;Save jmp offset
		pop	es
		clc
if_exit:
		ret
if_cmd		endp

;-----------------------------------------------------------------------------
; FOR CMD compiles an FOR command.
; Entry:  SI - Pointer to character after the FOR command
;	  DI - Pointer to end of compiled data.
; Exit:   AL - Error code if CF set
;	  CF - Set if error
;	  SI,DI updated.
;-----------------------------------------------------------------------------
for_cmd 	proc	near
		assume	cs:code,ds:code	
		cmp	for_active_flag,0		
		je	for_cmd_0
		mov	dx,offset errmsg11	;No nested FOR loops
		stc
		jmp	for_exit
for_cmd_0:
		mov	goto_active,0		;Clear goto detect flag
		inc	for_active_flag
		xor	bl,bl			;Find 1st char of next word
		call	scan4char
		jc	jmp_for_syntax
		mov	bp,si			;Save pointer to loop variable
		mov	dx,di
		sub	dx,word ptr databuff_start
;
;Copy the set data to the com file data area.  As always, if environment
;variables or command line parameters are in the data, insert a call to
;the translate routine before calling the for loop routine.
;
for_cmd_1:
		lodsb				;Scan until '(' is found
		cmp	al,13			;  indicating the start of the
		jne	for_cmd_2		;  data set.
jmp_for_syntax:
		jmp	for_syntax
for_cmd_2:
		cmp	al,'('
		jne	for_cmd_1
		mov	ah,3			;Copy until ')' found.
		call	copy_string
		xor	al,al			;Terminate string with zero.
		stosb
		mov	cx,11h
		or	bx,bx
		je	for_cmd_3

		mov	bx,offset procstr_next	;Append translate string
		call	include_code		;  routine to code.
		mov	bx,offset for_buff_ptr - offset data_start
		mov	cx,0021h		;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	dx,bx			;Copy ptr to buffer.
		mov	cl,12h			;Use proper parameter type
for_cmd_3:
		push	word ptr codebuff_ptr	;Save current code buff ptr
		mov	bx,offset forloop_next
		call	include_code
		mov	bx,di			;Initialize for loop data
		sub	bx,databuff_start	;  structure.
		mov	word ptr [di],0
		inc	di
		inc	di
		call	inline_code		;Insert call to loop code.
		mov	cx,200h 		;Include Jump if carry opcode
		call	inline_code
		push	ax			;Save address of jmp to modify
		push	word ptr codebuff_ptr	;Save current code buff ptr

;
;Scan the remainder of the line. Replace all instances of the loop variable
;with a special code that the run time translate routine understands.
;
		xor	bl,bl			;Find DO
		call	scan4char
		jc	for_syntax_1
		push	si
		lodsw				;Confirm DO exists
		and	ax,0dfdfh		;Convert to upper case
		cmp	ax,"OD"
		pop	si
		jne	for_syntax_1
		mov	bl,1			;Find end of 'DO'
		call	scan4char
		jc	for_syntax_1
		xor	bl,bl			;Find start of loop command.
		call	scan4char
		jc	for_syntax_1
		push	si			;Save pointer to command.
		push	di			;Save data buffer pointer.
		mov	di,si
		mov	bl,2			;Find the end of the line.
		call	scan4char
		mov	dx,si			;Save pointer to end of line
for_cmd_4:
		mov	si,bp			;Get ptr to loop variable.
		mov	cx,3			;Scan the remainder of the
		repe	cmpsb			;  line for the loop variable.
		jne	for_cmd_5		;  When found, replace with
		dec	di			;  % followed by 7f7fh. This
		dec	di			;  flag tells the runtime
		mov	ax,7f7fh		;  xlate routine to sub in
		stosw				;  the loop string.
for_cmd_5:
		cmp	di,dx			;See if at the end of the line.
		jb	for_cmd_4
		pop	di			;Restore data buffer ptr
		pop	si			;Restore ptr to command.
;
;Compile the remainder of the line as if it were a normal statment.
;
		call	parse			;Compile remainder of line.

		pop	cx			;Get code ptr after loop code
		pop	bx			;Get addr of JC
		pop	ax			;Get code ptr to loop code
		jc	for_exit1
		mov	dx,cx			;DX may have had an error msg

		sub	ax,word ptr codebuff_ptr ;Compute displacment from END
		sub	ax,3			 ;  of JMP opcode.
		mov	cx,400h 		;Insert JMP opcode after code
		call	inline_code		;  for statments inside FOR
		mov	ax,word ptr codebuff_ptr;  loop.
		sub	ax,dx
		push	es
		mov	es,word ptr codebuff_ptr[2]
		mov	es:[bx],ax
		pop	es
;
; If goto parsed during FOR, place jump for goto after FOR loop
;
		cmp	goto_active,0
		je 	for_exit
		mov	dx,goto_data_ptr
		mov	bx,offset gotodly_next	;Append goto delay 
		call	include_code		;  routine to code.
		mov	cx,1
		call	inline_code		;Add code to COM file.
for_exit:
		clc
for_exit1:
		mov	for_active_flag,0	;Clear flag
		ret
for_syntax_1:
		add	sp,6			;Clean off stack
for_syntax:
		mov	dx,offset errmsg6	;Syntax error
		stc
		jmp	short for_exit1
for_cmd 	endp

;-----------------------------------------------------------------------------
; GOTO CMD compiles a goto command.
; Entry:  SI - Pointer to first character after the command.
;	  DI - Pointer to end of compiled data.
; Exit:   AL - Error code if CF set
;	  CF - Set if error
;	  SI,DI updated.
;-----------------------------------------------------------------------------
goto_cmd	proc	near
		assume	cs:code,ds:code
		mov	goto_active,1		;Needed for FOR loop
		mov	bp,di			;Save ptr to start of string.
		xor	bl,bl			;Find the first nonspace char.
		call	scan4char
		mov	dx,offset errmsg6	;Check for Syntax error
		jc	goto_cmd_error
		cmp	byte ptr [si],':'	;See if leading :.  If so,
		jne	goto_c0			;  don't include in label.
		inc	si
goto_c0:
		push	si
		xor	ax,ax
		stosw				;Save word in case FOR loop
		xor	ah,ah			;  delay goto.
		call	copy_string		;Copy label to COM data.
		xor	al,al			;Terminate label with zero
		stosb
		pop	si
		mov	dx,offset errmsg8	;Check to see if label found.
		or	cx,cx			;If not, error.
		je	goto_cmd_error
		cmp	for_active_flag,0	;If in for loop, force eval
		jne	goto_c1			;  Jmp must occur after FOR

		or	bx,bx			;See if env var or cmd line
		je	goto_c2 		;  parms.  If not hard code jmp
goto_c1:
		mov	bx,offset procstr_next	;Get offset of translate
		call	include_code		;  routine. Include if needed.

		mov	dx,bp			;Get pointer to label.
		sub	dx,databuff_start	;Compute offset.
		mov	goto_data_ptr,dx	;Save offset in case FOR loop
		add	dx,2			;Move past word ptr
		mov	bx,offset prse_buff_ptr - offset data_start
		mov	cx,0021h		;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	dx,bx
		mov	cx,32h			;Use proper parameter type
		mov	bx,offset goto_next	;Append goto string
		call	include_code		;  routine to code.
		xor	bx,bx
		cmp	for_active_flag,0	;If in FOR loop delay goto.
		je	goto_c11		;  Pass ptr to word to save
		mov	bx,goto_data_ptr	;  destination address.
goto_c11:
		call	inline_code		;Add code to COM file.
		jmp	goto_cmd_exit
;
;Since label doesn't use env vars or cmd line params, hard code JMP.
;
goto_c2:
		mov	di,bp			;Reset data ptr to ignore label
		call	getlabel		;See if label in list.
		mov	ax,bx			;Copy pointer to label pointer
		add	ax,2			;  to code.
		sub	ax,databuff_start	;Compute offset of pointer
		mov	cx,100h 		;Insert JMP opcode.
		call	inline_code
goto_cmd_exit:
		mov	bl,2
		call	scan4char		;Scan to the end of the line.
		clc
goto_cmd_exit1: ret
goto_cmd_error:
		stc
		jmp	short goto_cmd_exit1
goto_cmd       endp

;-----------------------------------------------------------------------------
; LABEL CMD processes a label found in the bat file.
; Entry:  SI - Pointer to first character of the label
;	  DI - Pointer to end of compiled data.
; Exit:   AL - Error code if CF set
;	  CF - Set if error
;	  SI,DI updated.
;-----------------------------------------------------------------------------
label_cmd	proc	near
		assume	cs:code,ds:code
		inc	si			;Move past ':'
		call	getlabel
		cmp	word ptr [bx+2],-1	;See if list entry initialized
		jne	label_error		;  if so error.
		mov	ax,word ptr codebuff_ptr
		mov	[bx+2],ax		;Save code ptr in COM data
		mov	bl,2
		call	scan4char		;Scan to the end of the line.
		clc
label_exit:
		ret
label_error:
		mov	dx,offset errmsg8	;Two identical labels
		stc
		jmp	short label_exit
label_cmd	endp

;-----------------------------------------------------------------------------
; GETLABEL searches the label list in the data area.  If a matching label entry
;   is found it is returned, if not a label entry is created.
; Entry:  SI - Pointer to first character of the label
;	  DI - Pointer to end of compiled data.
; Exit:   BX - Points to label entry.
;	  SI,DI updated.
;-----------------------------------------------------------------------------
getlabel	proc	near
		assume	cs:code,ds:code
		call	capsword		;Convert to caps & get length.
		cmp	cx,8			;Max length of a label 8
		jbe	getlabel_1		;  characters to be consistant
		mov	cx,8			;  with DOS.
getlabel_1:
		mov	bp,di			;Save data ptr
		mov	di,offset firstlabel	;Get ptr to the 1st label
		mov	bx,di
		cmp	word ptr [di],-1	;See if any labels defined.
		je	getlabel_2		;No, skip label list search.

		push	cx			;Save label size
		add	bx,[bx] 		;Point to first label
		call	lblsrch_code		;Search label list.
		pop	cx
		mov	di,bp			;Create label entry.
		jnc	getlabel_exit
getlabel_2:
		mov	di,bp			;Create label entry.
		mov	ax,-1
		stosw				;Clear end of list tag
		stosw				;Indicate unitialized label
		mov	al,cl
		stosb				;Save length of label
		rep	movsb			;Copy label into data buffer
		mov	ax,bp
		sub	ax,bx			;Compute offset to new label
		mov	[bx],ax 		;Load offset in prev. label
		mov	bx,bp			;Get start of label entry
getlabel_exit:
		clc
		ret
getlabel	endp

;-----------------------------------------------------------------------------
; EXTERNAL CMD compiles a routine to exexute a program.
; Entry:  SI - Pointer to character after the command
;	  DI - Pointer to end of compiled data.
; Exit:   AL - Error code if CF set
;	  CF - Set if error
;	  SI,DI updated.
;-----------------------------------------------------------------------------
external_cmd	proc	near
		assume	cs:code,ds:code
		mov	dx,di			;Save ptr to filename
		sub	dx,databuff_start	;Compute offset.
		mov	ah,1
		call	copy_string		;Copy filename to COM data.
		mov	temp1,bx		;Save translate flag
		dec	si			;Back up one char
		xor	al,al			;Terminate filename with zero
		stosb
		inc	di
		push	di			;Save ptr to command line tail
		xor	ah,ah
		call	copy_string		;Copy command line tail.
		mov	ax,000dh		;Append CR and zero
		stosw
		pop	bp			;Save length of cmd line tail.
		inc	cl			;  Adjust for the CR since 
		mov	[bp-1],cl		;  ProcStr will add CR to the
		sub	bp,databuff_start	;  count.  Exec prog fixes 
		mov	cx,11h			;  this at run time.
		or	bx,bx			;See if translation code needed
		je	externalcmd_1
;
;See if we need translation for command line tail.
;
		push	dx
		mov	dx,bp			;Get pointer to cmd line tail
		mov	bx,offset procstr_next	;Get offset of translate
		call	include_code		;  routine.
		mov	bx,offset prse_buff_ptr - offset data_start
		mov	cx,21h			;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	cx,21h			;Use proper parameter type
		mov	bp,bx
		pop	dx
externalcmd_1:
;
;See if we need translation for param.
;
		mov	ax,temp1		;Get translate flag for cmd
		or	ax,ax			;See if extern cmd needs
		je	externalcmd_2		;  translation.
		mov	bx,offset procstr_next	;Get offset of translate
		call	include_code		;  routine.
		mov	bx,offset prs2_buff_ptr - offset data_start
		push	cx
		mov	cx,21h			;Indicate parameter type
		call	inline_code		;Insert translate code.		
		pop	cx
		and	cl,0f0h			;Use proper parameter type
		or	cl,02h			;  retain the prev param type
		mov	dx,bx			;  for cmd line tail.
externalcmd_2:
		mov	bx,offset external_next ;Append prog launch code
		call	include_code
		mov	bx,bp			;Get ptr to filename
		call	inline_code		;Add code to COM file.
		clc
		ret
external_cmd	endp

;-----------------------------------------------------------------------------
; INTERNAL CMD compiles a command internal to command.com
; Entry:  SI - Pointer to character after the command
;	  DI - Pointer to end of compiled data.
; Exit:   AL - Error code if CF set
;	  CF - Set if error
;	  SI,DI updated.
;-----------------------------------------------------------------------------
internal_cmd	proc	near
		assume	cs:code,ds:code
		inc	di			;Make room for string size.
		push	di			;Save ptr to internal command.
		push	si
		mov	si,offset internal_cmdsw
		movsw				;Copy /C switch to tell
		movsb				;  COMMAND.COM to execute and
		pop	si			;  terminate.
		xor	ah,ah
		call	copy_string		;Copy internal command
		mov	ax,000dh		;Append CR and zero
		stosw
		pop	bp
		add	cl,3			;Add length of /c switch
		mov	[bp-1],cl		;Save length of command line

		mov	dx,bp			;Get pointer to internal cmd
		sub	dx,databuff_start	;Compute offset.
		mov	cx,1
		or	bx,bx			;See if translation code needed
		je	internalcmd_1

		mov	bx,offset procstr_next	;Get offset of translate
		call	include_code		;  routine.
		mov	bx,offset prse_buff_ptr - offset data_start
		mov	cx,0021h		;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	cx,2			;Use proper parameter type
		mov	dx,bx			;Get input from str1 buffer
internalcmd_1:
		mov	bx,offset intcmd_next	;Append internal cmd routine
		call	include_code		;  to code.
		call	inline_code		;Add code to COM file.
		clc
		ret
internal_cmd	endp

;-----------------------------------------------------------------------------
; PATH CMD compiles a path command
; Entry:  Same as SET command
;-----------------------------------------------------------------------------
path_cmd 	proc	near
		assume	cs:code,ds:code
		mov	bp,2
		push	si
		add	si,4			;Move past path cmd		
		xor	bx,bx			;Find the first nonspace char.
		call	scan4char		;If no characters, set flag
		pop	si
		jnc	set_entry1		;  to print path string.
		mov	bp,3
		jmp	short set_entry1
path_cmd 	endp

;-----------------------------------------------------------------------------
; PROMPT CMD compiles a path command
; Entry:  Same as SET command
;-----------------------------------------------------------------------------
prompt_cmd 	proc	near
		assume	cs:code,ds:code
		mov	bp,1
		jmp	short set_entry1
prompt_cmd 	endp

;-----------------------------------------------------------------------------
; SET CMD compiles a command to change variables in the environment
; Entry:  SI - Pointer to character after the command
;	  DI - Pointer to end of compiled data.
; Exit:   CF - Set if error
;	  DX - Offset to error message if CF set.
;	  SI,DI updated.
;-----------------------------------------------------------------------------
set_cmd 	proc	near
		assume	cs:code,ds:code
		mov	bp,0			;Assume not PATH or PROMPT	
set_entry1:
		push	bp
		xor	bx,bx			;Find the first nonspace char.
		call	scan4char
		mov	dx,di			;Save ptr to set command.
		jc	setcmd_0
		xor	ah,ah
		call	copy_string		;Copy string to COM data
setcmd_0:
		xor	al,al			;Append zero
		stosb
		sub	dx,databuff_start	;Compute offset of data.
		mov	cx,31h
		or	bx,bx			;See if translation code needed
		je	setcmd_1

		mov	bx,offset procstr_next	;Get offset of translate
		call	include_code		;  routine.
		mov	bx,offset prse_buff_ptr - offset data_start
		mov	cx,21h			;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	cx,32h			;Use proper parameter type
		mov	dx,bx			;Get input from str1 buffer
setcmd_1:
		mov	bx,offset setenv_next	;Append set routine to code.
		call	include_code
		pop	bx			;Get PATH/PROMPT flag
		call	inline_code		;Add code to COM file.
		clc
		ret
set_cmd 	endp

;-----------------------------------------------------------------------------
; ECHO CMD compiles an ECHO command.
; Entry:  SI - Pointer to character after the ECHO command
;	  DI - Pointer to end of compiled data.
; Exit:   AL - Error code if CF set
;	  CF - Set if error
;	  SI,DI updated.
;-----------------------------------------------------------------------------
echo_cmd	proc	near
		assume	cs:code,ds:code
		mov	dx,si			;Save pointer to string start
		inc	dx			;Move pointer past 1st space
		xor	bl,bl			;Echo can either echo a
		call	scan4char		;  string to the keyboard or
		jc	echo_c01		;  toggle the echo flag.
		or	al,20h			;Check for on or off keyword
		cmp	al,"o"                  ;  to indicate what type of
		jne	echo_c0 		;  Echo this is.
		mov	ax,[si+1]		;Get next two characters
		or	al,20h			;Make lower case
		mov	bl,1
		cmp	al,"n"                  ;Check for echo on
		je	echo_c00
		or	ah,20h			;Make lower case
		cmp	ax,"ff"                 ;Check for echo off
		jne	echo_c0
		dec	bl
		mov	ah,[si+3]		;Get character past word
echo_c00:
		cmp	ah," "                  ;Make sure not just the start
		ja	echo_c0 		;  of another word.
		mov	bl,2
		call	scan4char		;Find end of line.
		jmp	short echo_exit
;
;Echo ASCII line, Include code in COM file to echo string.
;
echo_c01:
		mov	si,dx			;Restore data pointer
		cmp	byte ptr [si-2],'.'	;See if Echo.
		jne	echo_exit
		mov	dx,di
		jmp	short echo_c1
echo_c0:
		mov	si,dx			;Restore data pointer
		mov	dx,di
		xor	ah,ah
		call	copy_string		;Copy string to COM data.
echo_c1:
		mov	ax,0a0dh		;Terminate line with CRLF
		stosw
		xor	al,al			;Append zero byte
		stosb
		mov	cx,1			;Append runtime routines.
		sub	dx,databuff_start
		or	bx,bx			;Check translate flag, if set
		je	echo_c21		;  append translate code 1st.
		mov	bx,offset procstr_next	;Append translate string
		call	include_code		;  routine to code.
		mov	bx,offset prse_buff_ptr - offset data_start
		mov	cx,0021h		;Indicate parameter type
		call	inline_code		;Insert translate code.
		mov	dx,bx
		mov	cx,2			;Use proper parameter type
echo_c21:
		mov	bx,offset echo_msg_next ;Append echo string
		call	include_code		;  routine to code.
echo_c3:
		call	inline_code		;Add code to COM file.
echo_cstatus:
echo_exit:
		clc
echo_cmd_exit:
		ret
echo_cmd	endp

;-----------------------------------------------------------------------------
; PAUSE CMD compiles a PAUSE command.
; Entry:  SI - Pointer to character after the PAUSE command
;	  DI - Pointer to end of compiled data.
; Exit:   AL - Error code if CF set
;	  CF - Set if error
;	  SI,DI updated.
;-----------------------------------------------------------------------------
pause_cmd	proc	near
		assume	cs:code,ds:code
;Append routine if necessary
		mov	bx,offset pause_next	 ;Append PAUSE routine if
		call	include_code		 ;  necessary.

		mov	cx,0			;Add inline code with 0 params
		call	inline_code		;  to call pause routine.

		mov	bl,2			;Scan to end of line
		call	scan4char
		clc
pause_cmd_exit:
		ret
pause_cmd	endp

;-----------------------------------------------------------------------------
; SHIFT CMD compiles a SHIFT command.
; Entry:  SI - Pointer to character after the SHIFT command
;	  DI - Pointer to end of compiled data.
; Exit:   AL - Error code if CF set
;	  CF - Set if error
;	  SI,DI updated.
;-----------------------------------------------------------------------------
shift_cmd	proc	near
		assume	cs:code,ds:code
		mov	bx,offset shift_next	 ;Append shift routine if
		call	include_code		 ;  necessary.
		mov	cx,0			;Add inline code with 0 params
		call	inline_code		;  to call pause routine.
		mov	bl,2			;Scan to end of line
		call	scan4char
		clc
		ret
shift_cmd	endp

;-----------------------------------------------------------------------------
; REM CMD  Processes remark lines in batch file.
; Entry:  SI - pointer to line in BAT file
;-----------------------------------------------------------------------------
rem_cmd 	proc near
		assume	cs:code,ds:code
		dec	si			;Back up to make sure we don't
rem_c1: 	lodsb				;  miss a carrage return.
		cmp	al,1ah			;Loop until end of line or end
		je	rem_exit		;  of file.
		cmp	al,13
		jne	rem_c1
rem_exit:
		clc
		ret
rem_cmd 	endp

;-----------------------------------------------------------------------------
; COPY STRING copies a string to the com file data buffer.
; Entry:  SI - Pointer to 1st character of the string.
;	  DI - Pointer to end of compiled data.
;	  AH - 0 = copy until end of line
;	       1 = copy only one word
;	       2 = copy only one word, break on /
;	       3 = copy until ')'
; Exit:   BX - 0 if no environment variables or command line parameters.
;	  CX - Size of string.
;	  SI,DI updated.
;-----------------------------------------------------------------------------
copy_string	proc	near
		assume	cs:code,ds:code
		push	dx
		mov	dx,di			;Copy pointer to string
		xor	bx,bx			;Clear param/env flag
		xor	cx,cx			;Clear count
copystr_1:
		lodsb				;Get byte
		cmp	al,13			;See if carrage return
		je	copystr_exit		;Yes, quit.
		cmp	al,1ah			;See if EOF
		je	copystr_exit
copystr_2:
		cmp	ah,3			;See if set copy
		jne	copystr_3		;No, skip next test.
		cmp	al,')'                  ;See if end of set
		je	copystr_exit		;Yes, quit.
		jmp	short copystr_4
copystr_3:
		or 	ah,ah			;See if phrase or word copy
		je 	copystr_4		;Phase, skip next test.
		cmp	al,' '                  ;See if end of word.
		jbe	copystr_exit		;Yes, quit.
		cmp	al,'='                  ;Equal sign indicates end of
		je	copystr_exit		;  word.
		cmp	ah,2
		je 	copystr_4
		cmp	al,'/'                  ;/ indicates end of word.
		je	copystr_exit		
copystr_4:
		inc	cx
		cmp	al,'%'                  ;See if translation needed.
		jne	copystr_6 
		inc	bh			;Set env/cmd line param flag
		or	bl,bl			;See if already set.
		mov	bl,0			;Clear caps flag
		jne	copystr_6 		;If caps set, trailing %

		cmp	byte ptr [si],7fh	;Check for For loop var. If
		jne	copystr_5		;  found, copy it removing
		stosb				;  the extra 7f.
		lodsb
		inc	si
		jmp	short copystr_6
copystr_5:
		cmp	byte ptr [si],'9'       ;If char after % is number,
		ja 	copystr_51		;  this is a command line 
		cmp	byte ptr [si],'0'       ;  parameter, else an env
		jae	copystr_6		;  var.
copystr_51:
		inc	bl			;Set caps flag
copystr_6:
		or	bl,bl
		je	copystr_7
		call	capschar
copystr_7:
		stosb				;Save byte
		jmp	short copystr_1 	;Loop back.
copystr_exit:
		pop	dx
		ret
copy_string	endp

;-----------------------------------------------------------------------------
; INLINE CODE  Adds the necessary inline code to call a canned
;		routine.
; Entry:  AX - Offset of canned routine.
;	  CL - (low nibble) Method to pass parameter one
;	  CL - (high nibble) Method to pass parameter two
;	  CH - (low nibble) Call/Jump method
;	  DX - Parameter one
;	  BX - Parameter two
;-----------------------------------------------------------------------------
inline_code	proc	near
		push	bp
		push	si			;Save pointer to input buffer.
		push	di
		push	es
		les	di,codebuff_ptr 	;Point ES:DI to buffer
		mov	bp,cx
		and	cl,0fh			;Look only at SI code nibble
		cmp	cl,1			;Check for LEA SI
		jne	inline_1
		mov	si,offset code_leasi
		mov	[si+2],dx		;Load paramter one
		mov	cx,code_leasi_size
		rep	movsb			;Copy routine into COM file.
		jmp	short inline_10
inline_1:
		cmp	cl,2			;Check for MOV SI
		jne	inline_2
		mov	si,offset code_movsi
		mov	[si+2],dx		;Load parameter one
		mov	cx,code_movsi_size
		rep	movsb			;Copy routine into COM file.
		jmp	short inline_10
inline_2:
		cmp	cl,3			;Check for MOV SI Immediate
		jne	inline_10
		mov	si,offset code_movsiim
		mov	[si+1],dx		;Load parameter one
		mov	cx,code_movsiim_size
		rep	movsb			;Copy routine into COM file.
inline_10:
		mov	cx,bp			;Get back code
		and	cl,0f0h
		cmp	cl,10h			;Check for LEA DI
		jne	inline_11
		mov	si,offset code_leadi
		mov	[si+2],bx		;Load paramter two
		mov	cx,code_leadi_size
		rep	movsb			;Copy routine into COM file.
		jmp	short inline_13
inline_11:
		cmp	cl,20h			;Check for MOV DI
		jne	inline_12
		mov	si,offset code_movdi
		mov	[si+2],bx		;Load parameter two
		mov	cx,code_movdi_size
		rep	movsb			;Copy routine into COM file.
		jmp	short inline_13
inline_12:
		cmp	cl,30h			;Check for MOV immed DI
		jne	inline_13
		mov	si,offset code_movdiim
		mov	[si+1],bx		;Load parameter two
		mov	cx,code_movdiim_size
		rep	movsb			;Copy routine into COM file.
inline_13:
		mov	cx,bp
		and	ch,0fh
		jne	inline_20
		mov	si,offset code_call	;Code to call the canned
		mov	cx,code_call_size	;  routine.
		mov	[si+1],ax		;Insert the destination offset.
		rep	movsb			;Copy routine into COM file.
		jmp	short inline_30
inline_20:
		cmp	ch,01			;Check for jmp
		jne	inline_21
		mov	si,offset code_jmp	;Code to jmp to destination.
		mov	cx,code_jmp_size
		mov	[si+2],ax		;Insert the destination offset.
		rep	movsb			;Copy routine into COM file.
		jmp	short inline_30
inline_21:
		cmp	ch,02			;Check for jc
		jne	inline_22
		mov	si,offset code_jc	;Code to jc to destination.
		mov	cx,code_jc_size
		lea	ax,[di+3]		;Save offset of JMP to mod
		rep	movsb			;Copy routine into COM file.
		jmp	short inline_30
inline_22:
		cmp	ch,03			;Check for jnc
		jne	inline_23
		mov	si,offset code_jnc	;Code to jnc to destination.
		mov	cx,code_jnc_size
		lea	ax,[di+3]		;Save offset of JMP to mod
		rep	movsb			;Copy routine into COM file.
		jmp	short inline_30
inline_23:
		cmp	ch,04			;Check for jmp displacment
		jne	inline_30
		mov	si,offset code_jmpdis	;Code to jmp IP relative.
		mov	[si+1],ax
		mov	cx,code_jmpdis_size
		rep	movsb			;Copy routine into COM file.
inline_30:
		mov	word ptr cs:codebuff_ptr,di
		pop	es
		pop	di
		pop	si
		pop	bp
		ret
inline_code	endp

;-----------------------------------------------------------------------------
; INCLUDE CODE - Appends the routine to the append list if necessary and
;		 returns the offset of the routine in the compiled program.
; Entry:  BX - Pointer to header of canned routine to append.
; Exit:   AX - Offset of canned routine in COM file.
;-----------------------------------------------------------------------------
include_code	proc	near
		assume	ds:code,es:nothing
		push	cx
		push	dx
		mov	ax,[bx-4]		;Get COM file offset
		or	ax,ax			;If zero, routine has not
		jne	include_exit		;  been appended.
		mov	cx,bx			;Save pointer to new routine
;
;Address the prevous 'last' routine header.  Update that header, then use
;information in that header to compute the offset of the new routine.
;
		xchg	bx,last_routine
		mov	[bx],cx 		;Add code to chain.
		mov	ax,[bx-2]		;Compute offset of new routine
		add	ax,[bx-4]		;  by adding the offset of the
		sub	ax,[bx+2]		;  prevous routine to its size.
		mov	bx,cx

		mov	cx,[bx+2]		;Get number of called routines.
		add	ax,cx
		mov	[bx-4],ax		;Set offset of code.
		jcxz	include_exit
		shr	cx,1			;If this routine needs other
		add	bx,4			;  routines, include them in
		push	ax			;  the COM file.
include_1:
		push	cx
		push	bx
		mov	bx,[bx]
		call	include_code
		pop	bx
		mov	[bx],ax
		add	bx,2
		pop	cx
		loop	include_1
		pop	ax
include_exit:
		pop	dx
		pop	cx
		ret
include_code	endp
;-----------------------------------------------------------------------------
; PRINTMSG prints the message pointed to by DX to the screen.
; Entry:  DX - pointer to ASCII message terminated by $
;-----------------------------------------------------------------------------
printmsg	proc	near
		assume	ds:nothing,es:nothing
		push	ds
		push	cs
		pop	ds
		assume	ds:code
		mov	ah,9			;Print message
		int	21h
		pop	ds
		ret
printmsg	endp

;-----------------------------------------------------------------------------
; PRINTMSGCR calls PRINTMSG, then appends a carriage return to the message.
; Entry:  DX - pointer to ASCII message terminated by $
;-----------------------------------------------------------------------------
printmsgcr	proc	near
		assume	ds:nothing,es:nothing
		push	dx
		call	printmsg
		mov	dx,offset endmsg
		call	printmsg
		pop	dx
		ret
printmsgcr	endp

;-----------------------------------------------------------------------------
; HEX2ASC converts a binary number to ASCII and prints it to the screen.
; Entry:  AX - binary number
;-----------------------------------------------------------------------------
hex2asc 	proc near
		assume	ds:nothing,es:nothing
		push	bx
		mov	cx,5			;Allow max of five digits
hex_loop1:
		xor	dx,dx			;Clear high word
		mov	bx,10			;Load number base
		div	bx			;Divide by base (10)
		add	dl,30h			;Convert to ascii
		push	dx			;Save digit on stack
		loop	hex_loop1
		mov	cx,5			;Allow max of five digits
		mov	bl,"0"                  ;Set leading zero indicator
hex_loop2:
		pop	dx			;Get digit off stack
		or	bl,dl			;Don't print leading zeros.
		cmp	bl,"0"                  ;The first non zero will
		je	hex_1			;  change bl to non-zero.
		mov	ah,2			;DOS character output
		int	21h
hex_1:
		loop	hex_loop2
hex_exit:
		pop	bx
		ret
hex2asc 	endp

;-----------------------------------------------------------------------------
; LOADBATFILE loads the input BAT file.
; Entry:  DS:SI - pointer to the name of the file to open
; Exit:      CF - clear if successful
;
;  Support for BAT files larger than 16 K is not currently implimented.
;-----------------------------------------------------------------------------
loadbatfile	proc	near
		assume	cs:code,ds:code
		push	di
		push	si
		mov	bx,file_handle
		cmp	bx,-1
		jne	loadfile_3
		mov	dx,si			;Save filename pointer
		mov	di,offset outfile_name	;Point DI to buffer to hold
		mov	cx,8			;  the output file name.
loadfile_1:
		lodsb				;Copy the name until the 
		cmp	al,' '			;  extension is reached.
		je	loadfile_2		
		cmp	al,'.'
		je 	loadfile_2
		stosb
		loop	loadfile_1
loadfile_2:	
		mov	si,offset com_string	;Append COM extension to 
		movsb				;  output file name.
		movsw
		movsw
		mov	si,dx			;Get back filename pointer
		mov	bl,1			;Find end of filename
		call	scan4char
		dec	si
		mov	byte ptr [si],0 	;Make filename ASCIIZ.
		mov	ax,3d00h		;Open file (Read only)
		int	21h
		jc	loadfile_error
		mov	bx,ax			;Copy file handle
;
;Read contents into file buffer.
;
loadfile_3:
		mov	file_handle,-1		;Assume file completely read.
		mov	ah,3fh			;Read input BAT file into
		mov	dx,inbuff_ptr		;  memory above stack space
		mov	cx,inbuff_size 		;Get size of buffer
		sub	cx,4
		int	21h			
		mov	di,dx			;Point DI to end of the file
		add	di,ax	
		cmp	ax,cx			;Check if complete file read.
		jb 	loadfile_4

		std				;If there is more of the file
		push	dx			;  to read, scan backwards to
		mov 	dx,ax			;  the end of the last line.
		mov	cx,ax			;Get file length

		mov	al,13			;Scan for last CR
		cmp	[di-1],al 		;If last byte in buffer a CR
		jne	loadfile_30		;  back up 2 CRs.  Fixes bug	
		dec	di			;  in Ver 1.4.
		dec	di
		dec	cx
		dec	cx
loadfile_30:

		repne	scasb
		cld				;Reset string flag
		add  	di,3
		add	cx,3
		xchg	cx,dx			;Compute the number of bytes
		sub	dx,cx			;  to back up the file pointer
		mov	cx,0			;  The filepointer is a 32
		jz	loadfile_31		;  bit number in CX,DX.
		dec	cx
loadfile_31:
		mov	ax,4201h		;Move file pointer backwards
		int	21h
		mov	file_handle,bx
		pop	dx
loadfile_4:
		mov	ax,1a1ah
		stosw				;Append EOF bytes.
		stosw

		cmp	file_handle,-1
		jne	loadfile_exit
		mov	ah,3eh			;Close file.
		int	21h
loadfile_exit:
		clc
loadfile_exit1:
		pop	si
		pop	di
		ret
loadfile_error:
		stc
		mov	dx,offset errmsg2	;Bad filename specified.
		jmp	short loadfile_exit1
loadbatfile	endp

;-----------------------------------------------------------------------------
; SCAN4CHAR scans a string to find the first character.
; Entry:  SI - pointer to ASCII string
;	  BL - 0 = find next char, 
;              1 = find next space, 
;              2 = find end of line,
;              3 = find next space or =.
; Exit:   AL - matching character
;	  SI - pointer to matching character
;	  CF - set if carriage return or EOF found
;-----------------------------------------------------------------------------
scan4char	proc near
		assume	ds:nothing,es:nothing
scan4loop:
		lodsb
		cmp	al,13			;Check for carriage return.
		je	scan4_eol
		cmp	al,1ah			;Check for end of file char.
		jne	scan4_1
scan4_eol:
		stc
		jmp	short scan4_exit1
scan4_1:
		cmp	bl,3
		je	scan4_equal
		cmp	bl,1			;Check if searching for space,
		je	scan4_space 		;  character, or end of line.
		ja	scan4loop
		cmp	al," "                  ;Check for space or other
		jbe	scan4loop		;  'white' characters.
		jmp	short scan4_exit
scan4_equal:
		cmp	al,"="			;Check for exit
		je	scan4_exit
scan4_space:
		cmp	al," "                  ;Check for characters.
		ja	scan4loop
scan4_exit:
		dec	si			;Back up before character
		clc
scan4_exit1:
		ret
scan4char	endp

;============================================================================
;Routines used by compiled program.
;============================================================================
;!!--------------------------------------------------------------------------
;Code fragments used to call canned routines.
;----------------------------------------------------------------------------
code_call	proc	near
		mov	ax,1234h		;Set address to call routine.
		call	ax			;Call canned routine.
code_call_end	=	$
code_call	endp

code_jmp	proc	near
		mov	ax,[bp+1234h]		;Set address to call routine.
		jmp	ax			;Jump to new offset.
code_jmp_end	=	$
code_jmp	endp

code_jc 	proc	near
		jnc	code_jc_end		;Jump over long jmp
		jmp	initialize		;This jmp will be modified
code_jc_end	=	$
code_jc 	endp

code_jnc	proc	near
		jc	code_jnc_end		;Skip over long jmp
		jmp	initialize		;This jmp will be modified
code_jnc_end	=	$
code_jnc	endp

code_jmpdis	proc	near
		jmp	initialize		;This jmp will be modified
code_jmpdis_end =	$
code_jmpdis	endp

code_leasi	proc	near
		lea	si,[bp+1234h]		;Load address of data
code_leasi_end	=	$
code_leasi	endp

code_movsi	proc	near
		mov	si,[bp+1234h]		;Load data
code_movsi_end	=	$
code_movsi	endp

code_movsiim	proc	near
		mov	si,1234h		;Load immediate data
code_movsiim_end  =	$
code_movsiim	endp

code_leadi	proc	near
		lea	di,[bp+1234h]		;Load address of data
code_leadi_end	=	$
code_leadi	endp

code_movdi	proc	near
		mov	di,[bp+1234h]		;Load data
code_movdi_end	=	$
code_movdi	endp

code_movdiim	proc	near
		mov	di,1234h		;Load immediate data
code_movdiim_end  =	$
code_movdiim	endp

;----------------------------------------------------------------------------
;Predefined data needed for all compiled programs.
;----------------------------------------------------------------------------
data_start	=	$
code_start	dw	?			;Offset of main code routine
stack_ptr	dw	?			;Offset of end of code + stack
prog_segsize	dw	?			;Size of COM prog in paragraphs
prse_buff_ptr	dw	?			;Buffer for parsing strings
prs2_buff_ptr	dw	?			;Buffer for parsing strings
exec_buff_ptr	dw	?			;Buffer for exec function
for_buff_ptr	dw	?			;Buffer for For loop variables
floop_ptr	dw	?			;Pointer to for loop string
file_handle1	dw	?			;Saved handle of std output
file_handle2	dw	?			;Handle of output file
file_handle3	dw	?			;Saved handle of std input
file_handle4	dw	?			;Handle of input file
label_list_strt dw	?			;Offset into data of 1st label.
master_env	dw	?			;Segment of environment blk
version_num	dw	?			;DOS version number
proc_rc 	db	?			;Return code of last program.
shift_cnt	db	?			;Count of shift parameter
data_end	=	$

;----------------------------------------------------------------------------
;INIT CODE Routine at the start of all compiled programs.
;----------------------------------------------------------------------------
init_code_off	dw	100h			;Pointer to offset in COM file
init_code_size	dw	offset init_code_end-offset init_code_start
init_code_next	dw	0			;Ptr to next routine to append
init_code_lnks	dw	0			;Bytes in the dependancy header ;Number of routines called
init_code_start =	$

init_code	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		jmp	init_code_1
		db	"Compiled by BAT2EXEC 1.5",13,10
  		db	"PC Magazine ",254," Douglas Boling",13,10,1ah
init_code_1:
		cld
		mov	bp,ds:[offset data_start_ptr - offset init_code + 100h]
		mov	bp,[bp]
		mov	sp,com_stack_ptr	;Move stack pointer
		mov	bx,com_prog_size	;Reduce memory allocation
		mov	ah,4ah			;Resize memory block
		int	21h
		mov	ax,ds:[2ch]		;Get program environment seg
		mov	environment_seg,ax	;  use unless SET cmd used.
		mov	bx,code_start_ptr	;Get starting code offset
		jmp	bx			;Jump to start of code.
data_start_ptr	dw	?			;Offset of data area.
init_code	endp
init_code_end	=	$

;----------------------------------------------------------------------------
;END CODE Routine appended at the end of all compiled programs.
;----------------------------------------------------------------------------
end_code_off	dw	0			;Pointer to offset in COM file
end_code_size	dw	offset end_code_end-offset end_code_start
end_code_next	dw	0			;Ptr to next routine to append
end_code_lnks	dw	0			;Bytes in the dependancy header ;Number of routines called
end_code_start	=	$

end_code	proc	near
		assume	cs:code,ds:code
		mov	ax,4c00h		;Terminate program
		int	21h
end_code	endp
end_code_end	=	$

;----------------------------------------------------------------------------
;ECHO MSG CODE Routine used print a string to the standard output device
; Entry:  DS:SI - offset of string to print.
;----------------------------------------------------------------------------
echo_msg_off	dw	0			;Pointer to offset in COM file
echo_msg_size	dw	offset echo_msg_end-offset echo_msg_start
echo_msg_next	dw	0			;Ptr to next routine to append
echo_msg_lnks	dw	0			;Bytes in the dependancy header ;Number of routines called
echo_msg_start	=	$

echo_msg_code	proc	near
		assume	cs:code,ds:code
		mov	dl,[si] 		;Get character
		inc	si
		or	dl,dl
		je	echo_msg_1
		mov	ah,2			;Print character
		int	21h
		jmp	short echo_msg_code
echo_msg_1:
		ret
echo_msg_code	endp
echo_msg_end	=	$

;----------------------------------------------------------------------------
;ECHO STATUS CODE Routine used to report the status of the echo flag.
; Entry:  AL - Echo flag.
;----------------------------------------------------------------------------
echo_stat_ptr	dw	0			;Pointer to offset in COM file
echo_stat_size	dw	offset echo_stat_end-offset echo_stat_start
echo_stat_next	dw	0			;Ptr to next routine to append
echo_stat_lnks	dw	0			;Bytes in the dependancy header ;Number of routines called
echo_stat_start =	$

echo_stat_code	proc	near
		assume	cs:code,ds:code
		call	echo_stat_1		;Push IP on stack
echo_msg	db	"ECHO is $"
echo_on 	db	"on",10,13,"$"
echo_off	db	"off",10,13,"$"
echo_stat_1:
		pop	dx			;Pop offset of echo message
		push	ax			;Save status of echo flag
		mov	ah,9
		int	21h
		add	dx,offset echo_on-offset echo_msg ;Point to 'on' msg
		pop	ax
		or	al,al			;Check status of echo flag
		je	echo_report_1
		add	dx,offset echo_off-offset echo_on ;Point to 'off' msg
		add	dx,5			;Point to off message.
echo_report_1:
		mov	ah,9			;Print last part of echo stat
		int	21h
		ret
echo_stat_code	endp
echo_stat_end	=	$

;----------------------------------------------------------------------------
;PAUSE CODE Routine used pause execution of the COM file.
;----------------------------------------------------------------------------
pause_ptr	dw	0			;Pointer to offset in COM file
pause_size	dw	offset pause_end-offset pause_start
pause_next	dw	0			;Ptr to next routine to append
pause_lnks	dw	0			;Bytes in the dependancy header ;Number of routines called
pause_start	=	$

pause_code	proc	near
		assume	cs:code,ds:code
		call	pause_1 	;Push IP on stack
pause_msg	db	"Strike any key when ready...",13,10,"$"
pause_1:
		pop	dx			;Pop offset of message
		mov	ah,9			;Print message.
		int	21h

		mov	ah,7			;Keyboard unfiltered input
		int	21h			;  without echo.
		ret
pause_code	endp
pause_end	=	$

;----------------------------------------------------------------------------
;SHIFT CODE Routine used shift the input parameters by one.
;----------------------------------------------------------------------------
shift_ptr	dw	0			;Pointer to offset in COM file
shift_size	dw	offset shift_end-offset shift_start
shift_next	dw	0			;Ptr to next routine to append
shift_lnks	dw	0			;Bytes in the dependancy header ;Number of routines called
shift_start	=	$

shift_code	proc	near
		assume	cs:code,ds:code
		inc	byte ptr shift_count	 ;Inc shift count.
		ret
shift_code	endp
shift_end	=	$

;-----------------------------------------------------------------------------
; SCAN_CHAR scans a string to find the first character.
; Entry:  SI - pointer to ASCII string
;	  DL - 0 = find next char, 1 = find next space
;	  CX - file length
; Exit:   AL - first nonspace character
;	  CF - set if carriage return found
;-----------------------------------------------------------------------------
scan4_off	dw	0			;Pointer to offset in COM file
scan4_size	dw	offset scan4_end - offset scan4_start
scan4_next	dw	0			;Ptr to next routine to append
scan4_lnks	dw	0
scan4_start	=	$

scan_char	proc near
		assume	ds:nothing,es:nothing
scan_loop:
		lodsb
		cmp	al,9			;See if char is tab
		je	scan_space		;If before, end of line

		cmp	al,";"
		je	scan_space
		cmp	al,","
		je	scan_space

		cmp	al," "                  ;See if char is space.
		jb	scan_eol		;If before, end of line
		je	scan_space
		or	dl,dl			;Not space, if looking
		jne	scan_loop		;  for space continue.
		jmp	short scan_exit
scan_space:
		or	dl,dl			;Space found, see if looking
		je	scan_loop		;  for one.
scan_exit:
		clc
		ret
scan_eol:
		stc
		ret
scan_char	endp
scan4_end	=	$

;-----------------------------------------------------------------------------
; GETMEMBER  returns a pointer to the Nth word in a line.
; Entry:     SI - pointer to line of words
;	     DH - number of the word to return
; Exit:      SI - pointer to word
;	     CF - Set if word not in line.
;-----------------------------------------------------------------------------
getmember_scan4 equ	[bx-6]
getmember_off	dw	0			;Pointer to offset in COM file
getmember_size	dw	offset getmember_end - offset getmember_start
getmember_next	dw	0			;Ptr to next routine to append
getmember_lnks	dw	2			;Bytes in the dependancy header
getmember_start =	$
		dw	offset scan4_next	;Offset of called routine.

getmember	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		push	bx
		call	getmember_0
getmember_0:
		pop	bx
getmember_1:
		xor	dl,dl
		call	getmember_scan4 	;Find next word
		jc	getmember_notfound
		dec	dh			;Dec parameter count
		jle	getmember_2
		inc	dl
		call	getmember_scan4 	;Find next space
		jc	getmember_exit
		jmp	short getmember_1	;If not done, loop back.
getmember_2:
		dec	si			;Backup to 1st char in word.
		clc
getmember_exit:
		pop	bx
		ret
getmember_notfound:
		stc
		jmp	short getmember_exit
getmember	endp
getmember_end	=	$

;-----------------------------------------------------------------------------
; PROCSTRING processes a string to convert any environment variables or
;	     command line variables.
; Entry:  DS:SI - ASCIIZ string to process
;	  ES:DI - pointer to output buffer.
; Exit:   DS:SI - pointer to beginning of new ASCIIZ string.
;	 [SI-1] - Length of new string.
;-----------------------------------------------------------------------------
procstr_cmdl	equ	[bx-8]
procstr_env	equ	[bx-6]
procstr_off	dw	0			;Pointer to offset in COM file
procstr_size	dw	offset procstr_end - offset procstr_start
procstr_next	dw	0			;Ptr to next routine to append
procstr_lnks	dw	4			;Bytes in the dependancy header

procstr_start	=	$
		dw	offset subparm_next	;Offset of called routines.
		dw	offset subenv_next

procstr_code	proc	near
		assume	cs:code,ds:code,es:code
		push	bx
		call	procstr_0
procstr_0:
		pop	bx
		push	di
		push	si
		mov	ah,BUFF_SIZE		;Set size of buffer
procstr_1:
		lodsb				;Get byte from string
		or	al,al			;Check for end of string
		je	procstr_exit
		cmp	al,"%"                  ;See if special character
procstr_jmp:
		je	procstr_3		;Yes, process special char.
procstr_2:
		stosb				;Store byte from string
		dec	ah
		jne	procstr_1
procstr_exit:
		xor	al,al			;Force zero byte end.
		stosb
		pop	si
		pop	di
		mov	bl,BUFF_SIZE
		sub	bl,ah
		mov	ds:[di-1],bl		;Store length of string
		pop	bx
		ret
;
;A percent sign has been found indicating a 'soft' parameter.  Three types of
;soft parameters are allowed; command line parameter, environment variable,
;and for loop parameter.
;
procstr_3:
		lodsb				;Get next character
		dec	cx
		cmp	al,"%"                  ;If double %, include one
		je	procstr_2		;  in string.
		cmp	al,7fh			;See if for loop var
		jne	procstr_32
		push	si
		mov	si,forloop_ptr		;Get ptr to for loop string
procstr_30:
		lodsb
		cmp	al,0			;If zero, end of string
		je	procstr_31
		stosb
		dec	ah			;Dec buffer size counter
		jne	procstr_30		;If buffer not full, continue
procstr_31:
		pop	si			;Get back source string pointer
		jmp	short procstr_4
procstr_32:
		mov	dh,al			;Copy and check to see if
		sub	dh,"0"                  ;  the next char is a number.
		jb	procstr_5		;  If so, assume a line
		cmp	dh,9			;  parameter.
		ja	procstr_5
		call	procstr_cmdl		;Call cmd line param routine
procstr_4:
		or	ah,ah
		jne	procstr_1
		jmp	short procstr_exit	;If at end of string, done
procstr_5:
		dec	si			;Backup to 1st character
		inc	cx
		call	procstr_env
		jmp	short procstr_4
procstr_code	endp
procstr_end	=	$

;-----------------------------------------------------------------------------
; SUBLINEPARAM substitutes a parameter from the command line.
; Entry:  ES:DI - pointer to buffer to copy the line parameter
;	     DH - binary number of the line parameter
;	     AH - size of buffer
; Exit:   ES:DI - pointer to byte after the parameter in the buffer
;	     CX - remaining length of the buffer
;-----------------------------------------------------------------------------
subparm_getmem	equ	[bx-6]
subparm_off	dw	0			;Pointer to offset in COM file
subparm_size	dw	offset subparm_end - offset subparm_start
subparm_next	dw	0			;Ptr to next routine to append
subparm_lnks	dw	2			;Bytes in the dependancy header
subparm_start	=	$
		dw	offset getmember_next	;Offset of called routine.

sublineparam	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		push	bx
		call	sublineparam_1
		db	"DOS2X",0		;Dummy %0 parameter for DOS 2x
sublineparam_1:
		pop	bx
		push	cx
		push	si
		push	ds
		mov	si,80h			;Get ptr to cmd line
		xor	cx,cx
		mov	cl,[si] 		;Get number of chars in buffer.
		inc	si			;Point to data
		add	dh,ds:shift_count	;Add in shift count.
		or	dh,dh			;Check count of param to find.
		jnz	sublineparam_12
;
;For parameter 0, attempt to look in the env block for the name of the prog.
;
		push	ax			;Save buffer size in AH
		mov	ah,30h			;Get DOS version 
		int	21h			;If DOS 2.x, program nane not
		cmp	al,2			;  in the env segment.  Use
		pop	ax
		ja	sublineparam_10		;  dunny name instead.
		lea	si,[bx]			;Point to dummy parameter
		jmp	short sublineparam_2
sublineparam_10:
		push	es
		push	di
		mov	es,ds:[2ch]		;Get segment of local env	
		xor	al,al
		xor	di,di
		mov	cx,8000h
sublineparam_11:
		repne	scasb			;Find double zero
		scasb
		jne	sublineparam_11
		scasw				;Scan to name
		mov	si,di			;Copy pointer to name
		pop	di
		pop	es
		mov	ds,ds:[2ch]
		jmp	short sublineparam_2
sublineparam_12:
		call	subparm_getmem		;Get pointer to proper word.
		jc	sublineparam_exit
sublineparam_2:
		lodsb				;Get character from parameter
		cmp	al," "                  ;If space, parameter done
		jbe	sublineparam_exit

		cmp	al,";"			;Comma and semicolon also
		je	sublineparam_exit	;  delimit a command line
		cmp	al,","			;  parameter.
		je	sublineparam_exit

		stosb
		dec	ah			;Dec buffer size counter
		jnz	sublineparam_2
sublineparam_exit:
		pop	ds
		pop	si
		pop	cx
		pop	bx
		ret
sublineparam	endp
subparm_end	=	$
;-----------------------------------------------------------------------------
; SUBENVVAR substitutes a parameter from the program environment block.
; Entry:  DS:SI - pointer to enviroment variable.
;	  ES:DI - pointer to buffer.
;	     AH - size of buffer.
; Exit:   ES:DI - pointer to byte after the parameter in the buffer
;	  DS:SI - pointer to the character after the line parameter number
;	     CX - remaining free bytes in the buffer.
;-----------------------------------------------------------------------------
subenv_srchenv	equ	[bx-6]
subenv_off	dw	0			;Pointer to offset in COM file
subenv_size	dw	offset subenv_end-offset subenv_start
subenv_next	dw	0			;Ptr to next routine to append
subenv_lnks	dw	2			;Bytes in the dependancy header
subenv_start	=	$
		dw	offset searchenv_next	;Call to search environment blk

subenvvar	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		push	bx
		call	subenvvar_0
subenvvar_0:
		pop	bx
		push	ds
;
;Compute the length of the variable name.
;
		mov	cx,255
		push	di			;Save pointer to internal buff
		mov	di,si			;Compute the length of the
		mov	dx,cx			;  environment variable by
		mov	al,"%"                  ;  searching for the trailing
		repne	scasb			;  % sign.
		sub	dx,cx			;Compute length of variable.
		dec	dx			;Subtract % byte from length.
		mov	cx,di
		pop	di
		push	cx			;Save ptr to end of var
		call	subenv_srchenv		;Search environment block.
		jc	short subenvvar_exit	;CF set, variable not found.
;
;Environment variable found. Substitute into string.
;
subenvvar_1:
		lodsb				;Get env var character
		or	al,al			;Check for end of string
		je	subenvvar_exit
		stosb				;Save character in string
		dec	ah			;Dec buffer size count.
		jne	subenvvar_1		;If buffer not full, continue
subenvvar_exit:
		pop	si			;Restore string pointer
		pop	ds			;Restore segment register
		pop	bx
		ret
subenvvar	endp
subenv_end	=	$

;-----------------------------------------------------------------------------
; SEARCH_ENV scans the environment block for a string.
; Entry:  DS:SI - pointer to ASCII string
;	     DX - length of string
; Exit:   DS:SI - points to first character of environment string
;	     CF - clear if string found
;-----------------------------------------------------------------------------
searchenv_off	dw	0		       ;Pointer to offset in COM file
searchenv_size	dw	offset searchenv_end - offset searchenv_start
searchenv_next	dw	0		       ;Ptr to next routine to append
searchenv_lnks	dw	0
searchenv_start =	$

search_env	proc near
		assume	ds:nothing,es:nothing
		push	bx
		push	cx
		push	di
		push	es
		mov	es,environment_seg	;Get seg of environment blk
		xor	di,di			;Point ES:DI to environment.
		mov	bx,si			;Save pointer to var name
search_env_1:
		mov	si,bx			;Get back ptr to var name.
		mov	cx,dx			;Compare env var to var in
		repe	cmpsb			;  string.
		je	search_env_2		;Variable found, exit loop
		xor	al,al			;Find next environment var.
		mov	cx,-1			;Scan the entire segment.
		repne	scasb
		cmp	byte ptr es:[di],0	;If double zero, end of env
		jne	search_env_1		;  block. else, loop back.
search_env_not_found:
		mov	si,di			;Point SI to end of env data
		push	es
		pop	ds
		stc
		jmp	short search_env_exit
search_env_2:
;
;Environment variable found. Point DS:SI to the string.
;
		mov	si,di
		push	es			;DS:SI points to env string
		pop	ds
search_env_3:
		lodsb				;Move environment pointer past
		cmp	al,"="                  ;  the equals sign.
		jne	search_env_3
		cmp	byte ptr [si],0
		je	search_env_not_found
search_env_4:
		lodsb				;Move pointer to first
		or	al,al			;  non-space character.
		jb	search_env_5
		cmp	al," "
		jb	search_env_4
search_env_5:
		dec	si
		clc
search_env_exit:
		pop	es
		pop	di
		pop	cx
		pop	bx
		ret
search_env	endp
searchenv_end	=	$

;----------------------------------------------------------------------------
;EXTERNAL CMD  Routine used to launch programs from the COM file.
; Entry   DS:SI - Pointer to the ASCIIZ program name
;	  ES:DI - Pointer to the ASCIIZ command line tail
;----------------------------------------------------------------------------
extern_intcmd	equ	[bx-14]
extern_echomsg	equ	[bx-12]
extern_parspath equ	[bx-10]
extern_launch	equ	[bx-8]
extern_ifexits	equ	[bx-6]
extern_pathcnt	equ	[bx]
extern_path_var equ	[bx+1]
extern_file_ext equ	[bx+6]
extern_filename equ	[bx+15]
extern_filetail equ	[bx+17]
extern_lostmsg	equ	[bx+19]
extern_cmdparm	equ	[bx+46]
extern_pathflag	equ	[bx+49]
external_ptr	dw	0			;Pointer to offset in COM file
external_size	dw	offset external_end - offset external_start
external_next	dw	0			;Ptr to next routine to append
external_lnks	dw	10			;Bytes in the dependancy header ;Number of routines called
external_start	=	$
		dw	intcmd_next		;Call to launch COMMAND.COM
		dw	echo_msg_next		;Call to display string
		dw	parsepath_next		;Call to get part of path
		dw	launch_next		;Call execute file
		dw	ifexist_next		;Call to find file

external_code	proc	near
		assume	cs:code,ds:code
		push	bx
		call	external_0
		db	0			;Cnt to track path search.
		db	"PATH="
		db	"COMEXEBAT"
		dw	0			;Pointer to filename
		dw	0			;Pointer to command line tail
		db	"Bad command or file name",13,10,0
		db	"/C "
		db	0			;Flag for path search
external_0:
		pop	bx			;Get pointer to local vars.
		mov	extern_filename,si	;Save ptr to file name
		mov	extern_filetail,di	;Save ptr to command line tail
		mov	dx,exec_buff 		;Get pointer to free buffer.
		add	dx,4			;Make room for /C if needed.
		mov	byte ptr extern_pathflag,0
		mov	byte ptr extern_pathcnt,0
;Parse path to generate filename.
external_1:
		mov	di,dx			;Get ptr to start of buffer
		xor	cx,cx			;Check to see if we need to
		or	cl,extern_pathcnt	;  check the directorys in
		jne	external_19		;  the path.
;The first time through, parse the name without using the path.
		push	dx
		push	si
		xor	dx,dx			;Assume default drive
		cmp	byte ptr [si+1],':'	;See if drive specified	
		jne	external_11
		mov	dl,[si]
		and	dl,0dfh			;Set to upper case
		sub	dl,'@'			;Convert ASCII to number
		movsw				;Copy drive letter
		add	word ptr extern_filename,2  ;Don't use drive in path
external_11:
		cmp	byte ptr [si],'\'	;See if starting at root.
		je	external_110
		mov	al,'\'			;Start at root dir
		stosb
		push	si
		mov	si,di			;Get pointer to buffer.
		mov	ah,47h			;Get current directory
		int	21h
		pop	si
		xor	al,al
		mov	cx,64
		repne	scasb			;Find end of directory string
		dec	di
		cmp	byte ptr [di-1],'\'	;Unless at root dir, add
		je 	external_110
		mov	al,'\'
		stosb
external_110:
		xor	ax,ax
external_12:
		lodsb				;Get a byte
		cmp	ax,2e2eh		;See if we need to back up
		jne	external_13		;  one directory.
		std
		mov	al,'\'			;Scan backwards to erase	
		mov	cx,18			;  last directory.
		repne	scasb
		repne	scasb
		cld
		inc	di
		jmp	short external_12
external_13:
		stosb	
		mov	ah,al			;Copy last character.
		cmp	al,'\'			;See if name specifies a path
		jne	external_14
		inc	byte ptr extern_pathflag
external_14:
		cmp	al,0
		jne	external_12
external_15:
		dec	di			;Since DOS does not let the
		mov	dx,di			;  user specify the file ext.
		std				;  scan back to make sure one
		mov	cx,5			;  is not attached.
		mov	al,'.'
		repne   scasb	
		cld
		jne	external_16
		inc	di
		mov	dx,di
external_16:
		mov	di,dx
		pop	si
		pop	dx
		jmp	short external_4
;Parse the path string to search remaining directorys.
external_19:
		cmp	byte ptr extern_pathflag,0  ;If a complete path was
		jne	external_badcmd		    ;  specified, don't search
		mov	si,extern_filename	    ;  the path.
		call	extern_parspath
		jnc	external_2		;If we have checked all
external_badcmd:
		lea	si,extern_lostmsg	;  directories in the path,
		call	extern_echomsg		;  display file not found msg.
		jmp	short external_exit

;Append filename to the end of the path.
external_2:
		mov	cx,73			;Max length of filename
external_3:
		lodsb
		cmp	al,' '                  ;See if end of word
		jbe	external_4
		cmp	al,'.'                  ;See if end of filename
		je	external_4
		stosb
		loop	external_3
external_4:
		mov	al,'.'                  ;Append '.' to filename
		stosb
		lea	si,extern_file_ext	;Get pointer to extensions
		mov	cx,3			;3 extension types COM EXE BAT
external_5:
		movsw				;Append extension to filename
		movsb
		xor	al,al			;Termainate with zero
		stosb
		push	dx
		push	si
		push	cx
		mov	si,dx			;Get ptr to start of name
		call	extern_ifexits		;Search for file
		pop	cx
		pop	si
		pop	dx
		jnc	external_6
		sub	di,4			;Backup to file extension
		loop	external_5
		inc	byte ptr extern_pathcnt ;Look in the next path str
		jmp	external_1
external_6:
		cmp	cx,1			;See if BAT extension
		jne	external_8
		lea	si,extern_cmdparm	;Get pointer to /C
		sub	dx,3
		mov	di,dx			;Get ptr to string buffer
		movsw				;Copy /C param
		movsb
		xor	al,al
		mov	cx,252
		repne	scasb			;Find end of filename
		mov	byte ptr [di-1],' '     ;Fill in zero with space
		mov	si,extern_filetail	;Get ptr to command line tail
		cmp	[si-1],cl
		ja	external_7
		mov	cl,[si-1]		;Get length of cmd line tail
external_7:
		rep	movsb
		mov	byte ptr [di],13	;Append CR to cmd line.
		mov	si,dx			;Get pointer to BAT filename
		mov	ax,di			;Compute length of cmd line.
		sub	ax,dx
		mov	[si-1],al
		call	extern_intcmd		;Launch COMMAND.COM
		jmp	short external_exit
external_8:
		mov	di,extern_filetail	;Get ptr to command line tail
		dec	di			;Back up to buffer length
		dec	byte ptr [di]		;Sub CR from length
		push	di
		mov	si,dx			;Get ptr to start of name
		call	extern_launch		;Execute program
		pop	di
		inc	byte ptr [di]		;Restore cmd line length
external_exit:
		pop	bx
		ret
external_code	endp
external_end	=	$

;-----------------------------------------------------------------------------
; PARSEPATH  Parses the PATH and returns a qualified directory from the path.
; Entry:  ES:DI - pointer to destination buffer.
;	     CX - index into the path variable. (zero based.)
; Exit:   ES:DI - pointer to ASCIIZ destination filename.
;	     CF - Set if past end of the path
;-----------------------------------------------------------------------------
parsepath_srenv equ	[bx-6]
parsepath_off	dw	0			 ;Pointer to offset in COM file
parsepath_size	dw	offset parsepath_end - offset parsepath_start
parsepath_next	dw	0			 ;Ptr to next routine to append
parsepath_lnks	dw	2
parsepath_start =	$
		dw	offset searchenv_next	 ;Call to search env block

parsepath	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		push	bx
		call	parsepath_1
		db	"PATH"
parsepath_1:
		pop	bx		
		push	dx
		push	si
		push	ds
		mov	dx,4			;Length of PATH string
		mov	si,bx			;Point SI to PATH string
		call	getcom_srchenv		;PATH var ptr return in DS:SI
parsepath_2:
		dec	cx			;Dec path segment count
		jcxz	parsepath_4
parsepath_3:
		lodsb				;Get character
		or	al,al			;See if end of path string
		je	parsepath_notfound
		cmp	al,';'                  ;See if end of path segment
		jne	parsepath_3
		jmp	short parsepath_2
parsepath_4:
		lodsb
		cmp	al,';'                  ;See if end of path segment
		je	parsepath_5
		or	al,al			;See if end of path
		je	parsepath_5
		stosb
		jmp	short parsepath_4
parsepath_5:
		push	cs
		pop	ds
		cmp	byte ptr es:[di-1],'\'  ;Append \ if necessary.
		je	parsepath_6
		mov	al,'\'
		stosb
parsepath_6:
		clc
parsepath_exit:
		pop	ds
		pop	si
		pop	dx
		pop	bx
		ret
parsepath_notfound:
		stc
		jmp	short parsepath_exit
parsepath	endp
parsepath_end	  =	  $

;-----------------------------------------------------------------------------
; INTCMD  Launches the shell ,usually COMMAND.COM, to run an internal command.
; Entry   DS:SI - pointer to the ASCIIZ internal command to run.
;-----------------------------------------------------------------------------
intcmd_launch	equ    [bx-8]
intcmd_getcom	equ    [bx-6]
intcmd_off	dw     0			;Pointer to offset in COM file
intcmd_size	dw     offset intcmd_end - offset intcmd_start
intcmd_next	dw     0			;Ptr to next routine to append
intcmd_lnks	dw     4
intcmd_start	=      $
		dw     offset launch_next	;Call to load and run program.
		dw     offset getcom_next	;Call to find shell name.

intcommand	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		push	bx
		call	intcmd_1
intcmd_1:
		pop	bx			;Get pointer to sub calls.
		mov	di,si			;Copy ptr to command
		dec	di			;Back up to cmd line size.
		mov	al,process_rc		;Get and save return code
		push	ds
		push	ax
		call	intcmd_getcom		;Get comspec string.
		call	cs:intcmd_launch	;Run program.
		pop	ax
		pop	ds
		mov	process_rc,al		;Restore return code	
		pop	bx
		ret
intcommand	endp
intcmd_end	=	$

;-----------------------------------------------------------------------------
; GETCOMSPEC  Gets the name of the shell program running
; Exit:   DS:SI - pointer to the ASCIIZ name of the shell porgram.
;-----------------------------------------------------------------------------
getcom_srchenv	equ	[bx-6]
getcom_off	dw	0			 ;Pointer to offset in COM file
getcom_size	dw	offset getcom_end - offset getcom_start
getcom_next	dw	0			 ;Ptr to next routine to append
getcom_lnks	dw	2
getcom_start	=	$
		dw	offset searchenv_next	 ;Call to search environment blk

getcomspec	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		push	bx
		call	getcom_1
getcom_str	db	"COMSPEC"
getcom_1:
		pop	bx
		mov	dx,offset getcom_1 - offset getcom_str
		mov	si,bx
		call	getcom_srchenv		;Get pointer to comspec string
		pop	bx
		ret
getcomspec	endp
getcom_end	=	$

;----------------------------------------------------------------------------
;LAUNCH PROG  Routine used to load and run programs.
; Entry   DS:SI - pointer to the program name to run.
;	  ES:DI - pointer to the command line tail.
; Exit	  return code variable set.
;----------------------------------------------------------------------------
launch_fcb1	equ	[bx]
launch_fcb2	equ	[bx+16]
launch_ptr	dw	0			;Pointer to offset in COM file
launch_size	dw	offset launch_end - offset launch_start
launch_next	dw	0			;Ptr to next routine to append
launch_lnks	dw	0			;Bytes in the dependancy header ;Number of routines called
launch_start	=	$

launch_code	proc	near
		assume	cs:code,ss:code
		push	bx
		call	launch_1		;Push IP on stack
		db	0			;Dummy FCB for program
		db	"DUMMY   FCB"
		db	0,0,0,0
		db	0			;Dummy FCB for program
		db	"DUMMY   FCB"
		db	0,0,0,0
launch_1:
		pop	bx			;Get pointer to local vars.

		push	ds
		push	es			;Save stack ptr since it is not
		mov	com_stack_ptr,sp	;  saved under DOS 2.x.
;Parse first two parameters into FCBs.
		push	di			;Save ptr to tail
		push	si			;Save ptr to name
		mov	si,di			;Copy ptr to cmd line
		inc	si			;Skip size byte
		lea	di,launch_fcb1
		mov	ax,2903h		;Parse FCB
		int	21h
		lea	di,launch_fcb2
		mov	ax,2903h
		int	21h
		pop	si
		pop	di

		push	cs			;Create Parameter block on
		lea	dx,launch_fcb2		;  the stack. Start with 2nd
		push	dx			;  FCB.
		push	cs
		lea	dx,launch_fcb1
		push	dx
		push	cs			;Push ptr to command line tail.
		push	di
		mov	ax,cs:[environment_seg]	;Use env block set by prog.
		push	ax
		mov	bx,sp			;Copy pointer to parameter blk

		mov	ax,4b00h		;DOS EXEC program.
		mov	dx,si			;Get pointer to filename
		int	21h
		mov	bp,offset data_start_ptr - offset init_code + 100h
		mov	bp,cs:[bp]
		mov	bx,cs			;Reload BP to access local data
		cli
		mov	ss,bx			;Restore stack
		mov	sp,com_stack_ptr
		sti
		cld				;Restore default direction
		pop	es
		pop	ds
;Get return code
		mov	ah,4dh			;Get return code
		int	21h
		mov	process_rc,al		;Save
		pop	bx
		ret
launch_code	endp
launch_end    =       $

;----------------------------------------------------------------------------
;GOTO  Routine to jump to a label pointed to by a cmd line parameter or
;      environment variable.
; Entry   DS:SI - pointer to label to find.
;            DI - Wait flag/ptr. If <> 0, put goto address at pointer.
; Exit	  This routine does not return unless the label is not found.
;----------------------------------------------------------------------------
goto_echomsg	equ	[bx-7]
goto_lblsrch	equ	[bx-5]
goto_ptr	dw	0			;Pointer to offset in COM file
goto_size	dw	offset goto_end - offset goto_start
goto_next	dw	0			;Ptr to next routine to append
goto_lnks	dw	4			;Bytes in the dependancy header ;Number of routines called
goto_start	=	$
		dw	echo_msg_next		;Used to print error msg
		dw	lblsrch_next		;Used to find label

goto_code	proc	near
		assume	cs:code,ds:code
		call	goto_1
		db	8 dup (" ")
		db	" Label not found",13,10,0
goto_1:
		pop	bx
		push	di			;Save wait flag/pointer
		mov	di,bx			;Load label into error msg
		xor	dx,dx			;Get size of label as it is
		mov	cx,8			;  copied into error msg.
goto_2:
		lodsb
		cmp	al," "
		jbe	goto_4
		cmp	al,'a'
		jb	goto_3
		and	al,0dfh 		;Capitalize label
		cmp	al,'Z'
		ja	goto_4
goto_3:
		stosb
		inc	dx
		loop	goto_2
goto_4:
		mov	cx,dx			;Get size of label
		mov	si,bx			;Get pointer to label
		mov	di,com_label_start	;Get ptr to start of label list
		add	di,bp			;Add offset of data
		push	bx			;Save ptr to msg
		call	goto_lblsrch		;Call search routine
		pop	dx			;Restore ptr to message
		pop	si			;Restore Wait flag/pointer
		jc	goto_5			;CF set, label not found.
		mov	ax,[bx+2]		;Get destination ptr
		or	si,si			;See if delay flag <> 0
		je	goto_41			;If 0, no delay
		mov	[bp+si],ax		;Save ret addr at pointer
		ret
goto_41:
		pop	ax			;Remove return address
		push	[bx+2]			;Push new return address
goto_exit:
		ret
goto_5:
		mov	bx,dx			;Set addressability to call
		call	goto_echomsg		;Print error message.
		ret
goto_code	endp
goto_end     	=	$

;----------------------------------------------------------------------------
;GOTO DLY  Routine used if goto statment is inside a FOR loop.  Since a for
;      loop cannot be exited before it ends, this routine checks to see if
;      the GOTO statment was ever executed. If so, we now can jump.
; Entry   DS:SI - pointer to destination pointer. 0 = no jump.
; Exit	  This routine does not return unless the ptr = 0
;----------------------------------------------------------------------------
gotodly_ptr	dw	0			;Pointer to offset in COM file
gotodly_size	dw	offset gotodly_end - offset gotodly_start
gotodly_next	dw	0			;Ptr to next routine to append
gotodly_lnks	dw	0			;Bytes in the dependancy header ;Number of routines called
gotodly_start	=	$

gotodly_code	proc	near
		assume	cs:code,ds:code
		xor	ax,ax			;Get pointer, test if zero.
		or	ax,[si]			;If zero, return.  If not
		je	gotodly_exit		;  push the new destination
		pop	bx			;  on the stack and return.
		push	ax
gotodly_exit:
		ret
gotodly_code    endp
gotodly_end     =	     $

;----------------------------------------------------------------------------
;LABEL SEARCH Routine to search list of labels to determine goto destination.
; Entry   ES:DI - pointer to the first entry in the list. (Assume ES = DS)
;	  DS:SI - pointer to label to find.
;	     CX - Length of label
; Exit	     BX - pointer to matching list entry, or last entry if not found.
;	     CF - Set if label not found.
;----------------------------------------------------------------------------
lblsrch_ptr	dw	0			;Pointer to offset in COM file
lblsrch_size	dw	offset lblsrch_end - offset lblsrch_start
lblsrch_next	dw	0			;Ptr to next routine to append
lblsrch_lnks	dw	0			;Bytes in the dependancy header ;Number of routines called
lblsrch_start	=	$

lblsrch_code	proc	near
		assume	cs:code,ds:code
		push	si
		mov	dx,si			;Save ptr to label
		mov	ax,cx			;Save label length
		mov	bx,di			;Get ptr to list
lblsrch_1:
		mov	di,bx
		add	di,4			;Move to label string
		mov	si,dx			;Get ptr to new label
		mov	cx,ax			;Get length of label
		cmp	[di],cl 		;Compare lengths of the labels
		jne	lblsrch_2
		inc	di			;Skip past length byte
		repe	cmpsb			;Compare labels.
		je	lblsrch_4
lblsrch_2:
		cmp	word ptr [bx],-1	;See if at end of list
		je	lblsrch_3
		add	bx,[bx] 		;Point to next label
		jmp	short lblsrch_1
lblsrch_3:
		stc				;No label found.
		jmp	short lblsrch_exit
lblsrch_4:
		clc				;Label found
lblsrch_exit:
		pop	si
		ret
lblsrch_code	endp
lblsrch_end	=	$

;-----------------------------------------------------------------------------
; IFEQUAL  Compares two strings.
; Entry:  DS:SI - Pointer to first ASCIIZ String
;	  ES:DI - Pointer to second ASCIIZ String
;	     CX - Length of strings.
; Exit:      CF - Clear if equal
;-----------------------------------------------------------------------------
ifequal_off	dw     0			;Pointer to offset in COM file
ifequal_size	dw     offset ifequal_end - offset ifequal_start
ifequal_next	dw     0			;Ptr to next routine to append
ifequal_lnks	dw     0
ifequal_start	=      $

ifequal 	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		xor	cx,cx
		mov	cl,[si-1]		;Get size of string
		cmp	cl,[di-1]		;Compare sizes of strings
		jne	ifequal_notequal
		rep	cmpsb			;Compare strings
		jne	ifequal_notequal
		clc
		ret
ifequal_notequal:
		stc
		ret
ifequal 	endp
ifequal_end	=	$

;-----------------------------------------------------------------------------
; IFEXIST  Determines if a file exists.
; Entry:  DS:SI - Pointer to ASCIIZ filename.
;	     DI - Pointer to buffer for disk transfer area.
; Exit:      CF - Clear if file exists
;	     DI - IF file exists, points to filename.
;-----------------------------------------------------------------------------
ifexist_off	dw     0			;Pointer to offset in COM file
ifexist_size	dw     offset ifexist_end - offset ifexist_start
ifexist_next	dw     0			;Ptr to next routine to append
ifexist_lnks	dw     0
ifexist_start	=      $

ifexist 	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		mov	dx,di
		mov	ah,1ah			;Set DTA
		int	21h

		mov	dx,si			;Copy pointer to filename
		xor	cx,cx			;Normal attributes
		mov	ah,4eh			;DOS Find First
		int	21h
		jc	ifexist_exit
		add	di,1eh			;Point DI to filename in DTA
		clc
ifexist_exit:
		ret
ifexist 	endp
ifexist_end	=	$

;-----------------------------------------------------------------------------
; IFERRLEV  Compares the value passed with the return code of the last
;	    program executed.
; Entry:     SI - Pointer to ASCIIZ Error level.
; Exit:      CF - Clear if process error level above or equal to SI
;-----------------------------------------------------------------------------
iferrlev_off	dw     0			;Pointer to offset in COM file
iferrlev_size	dw     offset iferrlev_end - offset iferrlev_start
iferrlev_next	dw     0			;Ptr to next routine to append
iferrlev_lnks	dw     0
iferrlev_start	=      $

iferrlev	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		xor	ax,ax			;Convert ASCIIZ number into
		mov	bx,ax			;  decimal
iferrlev_1:
		mov	bl,[si] 		;Convert error level number
		sub	bl,'0'                  ;  from ASCII to decimal.
		jb	iferrlev_2
		cmp	bl,9
		ja	iferrlev_2
		mov	dx,10
		mul	dx
		jc	iferrlev_2
		add	ax,bx			;Add in digit
		inc	si
		jmp	short iferrlev_1
iferrlev_2:
		cmp	process_rc,al		;Compare to last program
		ret
iferrlev	endp
iferrlev_end	=	$

;-----------------------------------------------------------------------------
; FORLOOP  Processes commands in a FOR loop.
; Entry:     SI - Pointer to ASCIIZ set of parameters.
;	     DI - Pointer loop structure in data area
;		  LoopCnt	db	 0	Member of the set to use
;		  FirstFlag	db	 0	Indicates Find first/next
; Exit:      CF - Set if FOR loop complete.
;-----------------------------------------------------------------------------
forloop_getmem	equ	[bx-6]
forloop_savchr	equ	[bx]
forloop_eptr	equ	[bx+1]
forloop_dta   	equ	[bx+3]
forloop_off	dw	0			;Pointer to offset in COM file
forloop_size	dw	offset forloop_end - offset forloop_start
forloop_next	dw	0			;Ptr to next routine to append
forloop_lnks	dw	2
forloop_start	=	$
		dw	getmember_next

forloop 	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		push	bx
		call	forloop_0
		db	0			;Saved termaination character
		dw	0			;Ptr to term character address
		db	43 dup (0)		;Used for DTA
forloop_0:
		pop	bx
		push	si
		mov	si,forloop_eptr
		or	si,si
		je	forloop_01
		mov	al,forloop_savchr
		mov	byte ptr [si-1],al 	;Remove zero terminator
forloop_01:
		pop	si
;
;Set DTA. If 2nd time or later time looping on a member, use find next to
;determine the string for this time through the loop.
;
		lea	dx,forloop_dta		
		mov	ah,1ah			;Set DTA
		int	21h

		cmp	byte ptr [di+1],0	;See if first time for member
		je	forloop_1
		mov	ah,4fh			;Find next file
		int	21h
		jc	forloop_1		;Not found, go to next member
		lea	dx,[bx+21h]		;Point to filename in DTA
		jmp	short forloop_notdone	;Execute loop body
;
;First time with this member of the set, if wildcards are in the member,
;use DOS find first to get the loop string.
;
forloop_1:
		mov	byte ptr [di+1],0	;Clear first/next flag
		inc	byte ptr [di]		;Look at next member of the set
		mov	dh,[di] 		;Get loop count
		call	forloop_getmem		;Get member of set.  If no
		jc	forloop_done		;  more members, loop done.
		mov	dx,si			;Save pointer to member
		xor	ah,ah			;Clear wildcard flag
forloop_2:
		lodsb				;Scan set member to check for
		cmp	al,' '                  ;  any wildcard chars.
		jbe	forloop_4
		cmp	al,'?'
		jne	forloop_3
		inc	ah			;Set wildcard found flag
forloop_3:
		cmp	al,'*'
		jne	forloop_2
		inc	ah			;Set wildcard found flag
		jmp	short forloop_2
forloop_4:
		xor	al,al
		xchg	byte ptr [si-1],al	;Set zero terminator.
		mov	forloop_savchr,al	;Save char over written
		or	ah,ah			;If no wildcards, execute
		je	forloop_notdone 	;Execute loop body
		mov	byte ptr [di+1],1	;Set first/next flag
		xor	cx,cx			;Normal attributes
		mov	ah,4eh			;DOS find first
		int	21h
		jc	forloop_1		;If not found, get next member
		lea	dx,[bx+1eh]		;Set ptr to filename in DTA
forloop_notdone:
		mov	forloop_ptr,dx		;Set loop data ptr
		mov	forloop_eptr,si
		clc
forloop_exit:
		pop	bx
		ret
forloop_done:
		mov	word ptr [di],0 	;Clear loop variables
		mov	word ptr forloop_eptr,0
		stc
		jmp	short forloop_exit
forloop 	endp
forloop_end	=	$

;-----------------------------------------------------------------------------
; FINDENV  Finds the environment block of the local command processor.
; Exit:    Variable environment_seg set with segment of the environment.
;-----------------------------------------------------------------------------
findenv_off	dw	0			 ;Pointer to offset in COM file
findenv_size	dw	offset findenv_end - offset findenv_start
findenv_next	dw	0			 ;Ptr to next routine to append
findenv_lnks	dw	0
findenv_start	=	$

findenv 	proc	near
		assume	cs:code,ds:code,es:code,ss:code
		push	bx
		push	es

		mov	ax,ds:[2ch]		;Get default env
		cmp	environment_seg,ax	;Check to see if already
		jne	findenv_exit		;  found.
		push	cs
		pop	es
findenv_1:
	        mov     ax,es:[16h]             ;Get parent's PSP
		mov	dx,ax			;Save PSP segment
		push	ax
		dec	ax			;Point to mcb
		mov	es,ax
	        cmp     byte ptr es:[0],"M"     ;check for mcb signature
		pop	es
	        jne     findenv_exit
		
		cmp	dx,es:[16h]		;See if PSP is own parent
		jne	findenv_1		;No, keep looking

		mov	cx,30		
		mov	es,ax
findenv_2:		
	        add     ax,es:[3]               ;Add size of memory block
		inc	ax
	        mov     es,ax

	        cmp     byte ptr es:[0],"M"     ;check for mcb signature
	        jne     findenv_exit
	        cmp     dx,es:[1]               ;See if this owned by cmd proc
	        je      findenv_3
	        loop    findenv_2
	        jmp     short findenv_exit
findenv_3:
		inc	ax
findenv_found:
		mov	environment_seg,ax	;Save pointer to master env 
findenv_exit:
		pop	es
		pop	bx
		ret
findenv 	endp
findenv_end	=	$

;-----------------------------------------------------------------------------
; SET_ENV  Sets/resets environment variables.
; Entry:  DS:SI - pointer to ASCII string containing the environment variable
;		  and, optionally, the string to assign.
;                 If no string specified, the environment is dumped to the
;                 screen.
;            DI - Flag to indicate setting of PATH and PROMPT vars
;                 0 = Normal Env var, 1 = PROMPT var, 2 = PATH var.
;-----------------------------------------------------------------------------
setenv_findenv	equ	[bx-10]
setenv_echo	equ	[bx-8]
setenv_serchenv equ	[bx-6]
setenv_pathflag	equ	[bx]
setenv_varlen 	equ	[bx+1]
setenv_fullmsg	equ	[bx+2]
setenv_crmsg  	equ	[bx+29]
setenv_nopath	equ	[bx+32]
setenv_off	dw	0			;Pointer to offset in COM file
setenv_size	dw	offset setenv_end - offset setenv_start
setenv_next	dw	0			;Ptr to next routine to append
setenv_lnks	dw	6
setenv_start	=	$
		dw	offset findenv_next	;Call to find the master env
		dw	offset echo_msg_next	;Call to print line.
		dw	offset searchenv_next	;Call to search environment blk

set_env 	proc near
		assume	ds:nothing,es:nothing
		push	bx
		call	setenv_1
		db	0			;PATH/PROMPT flag storage
		db	0			;Var length.
		db	"Out of environment space",13,10,0
		db	13,10,0
		db	"No Path",0
setenv_1:
		pop	bx			;Set up local addressing
		mov	ax,di
		xchg	al,ah
		mov	setenv_pathflag,ah
		push	ax
		call	setenv_findenv		;Find master env block
		pop	ax
		push	bp
		push	es
;See if we need to simply print the PATH statment.
		cmp	ah,3
		jne	setenv_19
		mov	dx,4
		call	setenv_serchenv 	;Get pointer to variable
		jnc	setenv_11
		lea	si,setenv_nopath	;If path string not found, 
		push	cs			;  print no path msg.
		pop	ds
		jmp	short setenv_12
setenv_11:
		sub	si,5			;Back up to start of PATH
setenv_12:
		call	cs:setenv_echo		;Print string
		push	cs
		pop	ds
		lea	si,setenv_crmsg		;Append CR.
		call	setenv_echo
		jmp	setenv_8
setenv_19:	
		mov	cx,BUFF_SIZE
		xor	dx,dx
		push	si			;Save ptr to new env var
		mov	di,si
setenv_2:
		lodsb
		or 	ah,ah			;See if PATH or PROMPT
		je	setenv_23
		cmp	al," "			;If PATH or PROMPT statments,
		jne	setenv_23		;  remove any spaces between	
		mov	al,"="			;  variable and assignment.
		push	di
		stosb
setenv_20:
		lodsb				;Scan past equal sign 
		cmp	al," "			
		je	setenv_20
		cmp	al,"="
		je	setenv_20
setenv_21:
		stosb	
		or	al,al
		je	setenv_22
		lodsb				;Remove spaces in set string.
		jmp	short setenv_21
setenv_22:
		pop	di
		jmp	short setenv_4
setenv_23:
		or 	al,al
		je	setenv_4
		cmp	al,"="                  ;Scan until end of variable
		je	setenv_4		;  found.
		cmp	al,'a'
		jb	setenv_3
		cmp	al,'z'
		ja	setenv_3
		and	al,0dfh 		;Capitalize variable
setenv_3:
		cmp	al," "			;Keep a count of non-space
		jbe	setenv_31		;  characters.
		inc	dh
setenv_31:
		stosb
		inc	dl			;Var length count.
		loop	setenv_2
setenv_4:
		pop	si
;
;If no characters after SET, dump env vars to screen.
;
		mov	setenv_varlen,dl	;Save length of env var.
		mov	al,dh
		xor	dh,dh
		or	dh,dh			;See if path or prompt
		jne	setenv_40
setenv_40:
		or	al,al			;If second Zero, end of vars.
		jne	setenv_48
		push	ds
		mov	ds,cs:[environment_seg]	;Get segment of environment
		xor	si,si
		lea	di,setenv_crmsg		;Get address of CR string
		mov	cx,cs
setenv_41:
		call	cs:setenv_echo		;Print var
		push	ds
		push	si
		mov 	ds,cx
		mov 	si,di
		call	cs:setenv_echo		;Print CR
		pop	si
		pop	ds
		cmp	byte ptr ds:[si],0	;If next char 0, end of block
		jne	setenv_41
		pop	ds
		jmp	setenv_8
;
;Set or Clear env var.
;
setenv_48:
		mov	ax,si
		inc	di
		cmp	byte ptr cs:[di]," "    ;If nothing past '=' then
		jae	setenv_49		;  simply erase var from env.
		xor	ax,ax
setenv_49:
		push	ax			;Save set/erase flag
		call	setenv_serchenv 	;Get pointer to variable
		pop	dx			
		push	ds			;ES = env segment
		pop	es
		mov	di,si			;Copy pointer to variable
		jc	setenv_61

		xor	al,al			;Scan backwards to find start
		std				;  of var name
		mov	cx,256
		repne	scasb
		inc	di
		inc	di
		push	di
		cld				;Scan forward to find end of
		mov	cx,256			;  variable.
		repne	scasb
		mov	si,di
		pop	di
		xor	ah,ah
setenv_5:
		lodsb				;Move byte from past var to
		stosb				;  cover up current assignment
		or	ah,al			;If two zeros in a row then
		je	setenv_6		;  end of env vars.
		mov	ah,al
		jmp	short setenv_5
setenv_6:
		dec	di			;Back up before last zero
setenv_61:
		push	cs
		pop	ds
		mov	si,dx			;Get back ptr to env var
		or	si,si			;See if var assignment
		je	setenv_8

		push	es			;Get size of the environment
		mov	ax,es			;  block by reading the size
		dec	ax			;  in the memory control block.
		mov	es,ax
		mov	bp,es:[3]
		mov	cl,4
		shl	bp,cl			;Convert to bytes.
		dec	bp
		dec	bp
		pop	es
		xor	ax,ax			;See if there is room in the
		mov	al,setenv_varlen	;  env block for the var name.
		inc	al			;  If not, don't even start.
		add	ax,di			;  If room for name, copy as 
		cmp	ax,bp			;  much of the var as possible
		jae	setenv_72
		mov	ah,setenv_pathflag	;Get pathflag byte
setenv_7:
		cmp	di,bp			;Check for end of env block.
		jae	setenv_72
		lodsb				;Copy new env var
		cmp	ah,2	
		jne	setenv_71		;If PATH var, make upper case.
		cmp	al,'a'
		jb 	setenv_71
		cmp	al,'z'
		ja	setenv_71
		and	al,0dfh			
setenv_71:	
		stosb
		or	al,al			;Check for end of variable.
		jne	setenv_7
		stosb
		jmp	short setenv_8
setenv_72:
		xor	al,al
		stosb
		push	cs
		pop	es
		lea	si,setenv_fullmsg	;If environment block full,
		call	setenv_echo		;  print message.
setenv_8:
		pop	es
		pop	bp
		pop	bx
		ret
set_env 	endp
setenv_end	=	$

;-----------------------------------------------------------------------------
; REDIROO  Opens a file for output redirection.
; Entry:  DS:SI - pointer to ASCII filename to open.
;	     DI - 0  open new file, 1 append to existing file.
;-----------------------------------------------------------------------------
rediroo_off	dw	0			;Pointer to offset in COM file
rediroo_size	dw	offset rediroo_end - offset rediroo_start
rediroo_next	dw	0			;Ptr to next routine to append
rediroo_lnks	dw	0
rediroo_start	=	$

rediroo 	proc near
		assume	ds:nothing,es:nothing

		mov	word ptr stdout_hdl,-1	;Clear handle
		mov	dx,si			;Get ptr to outfile file
		xor	cx,cx			;Normal attributes
		mov	ax,3c02h		;Create file
		or	di,di			;See if append or new file
		je	rediroo_2
		inc	ah			;Open file
rediroo_2:
		int	21h
		jc	rediroo_exit
		mov	bx,ax			;Copy file handle
		or	di,di
		je	rediroo_3
		mov	ax,4202h		;Move file ptr to end of file
		xor	dx,dx
		mov	cx,dx
		int	21h
		jc	rediroo_exit
rediroo_3:
		mov	outfile_hdl,bx		;Save output file handle
		push	bx
		mov	ah,45h			;Duplicate output handle
		mov	bx,1			;Std output handle
		int	21h
		mov	stdout_hdl,ax		;Save dup std output handle

		mov	cx,1
		pop	bx
		mov	ah,46h			;Force dup file handle
		int	21h
rediroo_exit:
		ret
rediroo 	endp
rediroo_end	=	$

;-----------------------------------------------------------------------------
; REDIRCO  Closes a file used for output redirection.
;-----------------------------------------------------------------------------
redirco_off	dw	0			;Pointer to offset in COM file
redirco_size	dw	offset redirco_end - offset redirco_start
redirco_next	dw	0			;Ptr to next routine to append
redirco_lnks	dw	0
redirco_start	=	$

redirco 	proc near
		assume	ds:nothing,es:nothing
		cmp	word ptr stdout_hdl,-1	;If error on redirect, skip
		je	redirco_exit		;  restore.

		mov	ah,46h			;Force restore of std out
		mov	bx,stdout_hdl
		mov	cx,1
		int	21h

		mov	ah,3eh			;Close file
		mov	bx,outfile_hdl		;Get output file handle
		int	21h
redirco_exit:
		ret
redirco 	endp
redirco_end	=	$

;-----------------------------------------------------------------------------
; REDIROI  Opens a file for input redirection.
; Entry:  DS:SI - pointer to ASCII filename to open.
;	     DI - 0  open new file, 1 append to existing file.
;-----------------------------------------------------------------------------
rediroi_off	dw	0			;Pointer to offset in COM file
rediroi_size	dw	offset rediroi_end - offset rediroi_start
rediroi_next	dw	0			;Ptr to next routine to append
rediroi_lnks	dw	0
rediroi_start	=	$

rediroi 	proc near
		assume	ds:nothing,es:nothing

		mov	word ptr stdin_hdl,-1	;Clear handle
		mov	dx,si			;Get ptr to outfile file
		mov	ax,3d00h		;Open file, Read only
		int	21h
		jc	rediroi_exit
		mov	infile_hdl,ax		;Save input file handle
		push	ax

		mov	ah,45h			;Duplicate input handle
		xor	bx,bx
		int	21h
		mov	stdin_hdl,ax		;Save dup std input handle

		xor	cx,cx
		pop	bx
		mov	ah,46h			;Force dup file handle
		int	21h
rediroi_exit:
		ret
rediroi 	endp
rediroi_end	=	$

;-----------------------------------------------------------------------------
; REDIRCI  Closes a file used for input redirection.
;-----------------------------------------------------------------------------
redirci_off	dw	0			;Pointer to offset in COM file
redirci_size	dw	offset redirci_end - offset redirci_start
redirci_next	dw	0			;Ptr to next routine to append
redirci_lnks	dw	0
redirci_start	=	$

redirci 	proc near
		assume	ds:nothing,es:nothing
		cmp	word ptr stdin_hdl,-1	;If error on redirect, skip
		je	redirci_exit		;  restore.

		mov	ah,46h			;Force restore of std in hdl
		xor	cx,cx
		mov	bx,stdin_hdl
		int	21h

		mov	ah,3eh			;Close file
		mov	bx,infile_hdl		;Get input file handle
		int	21h
redirci_exit:
		ret
redirci 	endp
redirci_end	=	$

;-----------------------------------------------------------------------------
; REDIRDEL Deletes piping file.
; Entry:  DS:SI - pointer to ASCII filename to delete.
;-----------------------------------------------------------------------------
redirdel_off	dw	0			;Pointer to offset in COM file
redirdel_size	dw	offset redirdel_end - offset redirdel_start
redirdel_next	dw	0			;Ptr to next routine to append
redirdel_lnks	dw	0
redirdel_start	=	$

redirdel 	proc near
		assume	ds:nothing,es:nothing

		mov	dx,si			;Copy pointer to filename
		mov	ah,41h			;Delete file
		int	21h
		ret
redirdel 	endp
redirdel_end	=	$

initialize	endp
		even				;compiler stack on word boundry
end_of_code	=	$
code		ends

end		main
