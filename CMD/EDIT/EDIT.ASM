;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************
NAME	EDIT
PAGE	58,132
TITLE	DOS Bootstrap Editor

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG, ES:CSEG
		ORG	0100H
START:
		JMP	BEGIN

;-----------------------------------------------------------------------
; Local data area in CSEG.
;-----------------------------------------------------------------------
; ASCII character values used in the program.
TAB		EQU	9
CR		EQU	13
LF		EQU	10
CRLF		EQU	0A0DH

; Character strings and data
COPYRIGHT	DB	"www.wiki.ptsource.eu"
                DB	CR,LF,"$"


HELP_SCREEN     DB      CR,LF,9,'F1 - Help',9,9,9,'Shft-F1 - <NUL> char'
		DB	CR,LF,9,'F2 - Exit and save',9,9,'Shft-F2 - Quit'
		DB	CR,LF,9,'F3 - Print marked',9,9,'Shft-F3 - Form-feed'
		DB	CR,LF,9,'F4 - Mark toggle'
		DB	CR,LF,9,'F5 - Cut marked',9,9,9,'Shft-F5 - Paste'
		DB	CR,LF,9,'F6 - String search',9,9,'Shft-F6 - '
		DB	'Search again'
		DB	CR,LF,9,'F7 - Undo <Del> or Ovr'
		DB	CR,LF,9,'F8 - Delete to EOL'
		DB	CR,LF,9,'F9 - Delete Line'
		DB	CR,LF,9,'F10 - Un-Delete line',LF
		DB	CR,LF,9,'Ctrl-L/R arrow - Move window'
		DB	CR,LF,9,'Ctrl-Home - to top'
		DB	CR,LF,9,'Ctrl-End - to EOF',LF
		DB	CR,LF,9,'Esc - From Exit'
		DB	CR,LF,'$',7,1AH

PROMPT_STRING	DB	"1Help",0		;F1
		DB	"2Exit",0		;F2
		DB	"3Print",0		;F3
		DB	"4Mark",0		;F4
		DB	"5Cut",0		;F5
		DB	"6Search",0		;F6
		DB	"7UnDo",0		;F7
		DB	"8Del EOL",0		;F8
		DB	"9Del L",0		;F9
		DB	"10Udel L",0,0		;F10

PROMPT_LENGTH	=	$ - OFFSET PROMPT_STRING
FILE_TOO_BIG	DB	"File too big$"
READ_ERR_MESS	DB	"Read error$"
MEMORY_ERROR	DB	"Not enough memory$"
CHEK_SUM_MESS	DB	"Altered$"
DOS_2_MESS	DB	"Needs DOS 2.0$"
VERIFY_MESS	DB	"Lose Changes (Y)?",0
SAVE_MESS	DB	"Save as: ",0
DOT_$$$		DB	".$$$",0
DOT_BAK		DB	".BAK",0
SRCH_PROMPT	DB	"SEARCH> ",0
SRCH_FLG	DB	0		;0=normal, 1=search successful (inverse)
SRCH_END	DW	0
SRCH_BASE	DW	0
SRCH_CLR	DB	0F0H		;244
DIRTY_BITS	DB	03H		;1=update screen, 2=cursor 4=cur. line
DIRTY_FILE	DB	0		;0=file not altered, FF=file altered
NORMAL		DB	07H		;video attribute bits
INVERSE		DB	70H		;video (inverse)
LEFT_MARGIN	DB	0		;column number of screen left margin
MARGIN_COUNT	DB	0
INSERT_MODE	DB	01H		;1=INSert, 0=Overstrike, 2or3=Read Only
INSERT_CODE	DB	'OIRR'		;indexed code for display screen
MARK_MODE	DB	0		;toggle, FF=MARK is on.
ROWS		DB	23		;Rows available on display screen
SAVE_COLUMN	DB	0
SAVE_ROW	DB	0
LINE_FLAG	DB	0

EVEN					;"word align" (for 16-bit bus accesses)
NAME_POINTER	DW	81H		;offset of command tail in PSP
NAME_END	DW	81H		;end of tail

VIDEO_STATUS_REG LABEL	DWORD		;(alias for use by LES instruction)
STATUS_REG	DW	0		;video status register offset
VIDEO_SEG	DW	0B000H		;video segment, Mono=0B000, other 0B800

LINE_LENGTH	DW	0		;number of bytes in current line
UNDO_LENGTH	DW	0		;number of DELeted bytes in UnDo buffer
CURS_POSN	DW	0		;Cursor, Hi is row, Low is column

MARK_START	DW	0FFFFH		;MARK text for CUT/PASTE or Print
MARK_END	DW	0
MARK_HOME	DW	0

TOP_OF_SCREEN	DW	0		;address in text file of Top-of-screen
CURSOR		DW	0		;address in text file of cursor
LAST_CHAR	DW	0		;address of last character in file.
COLUMNSB	LABEL	BYTE		;alias BYTE definition
COLUMNS		DW	0

PASTE_SEG	DW	0		;segment address of PASTE buffer
PASTE_SIZE	DW	0		;size of block in PASTE buffer

PAGE_PROC	DW	0		;pointer used by PGUP and PGDN

EXIT_CODE	DW	4C00H		;DOS INT 21H, Func 4CH, exit with code

OLDINT24	DD	0		;pointer to DOS critical error handler

DISPATCH_BASE	EQU	59	  ;initial offset for a PASCAL type CASE list
DISPATCH_TABLE	DW	HELP	  ;59;F1, Help screen (common usage)
		DW	EXIT	  ;60;F2, Save changes and exit (from BSE)
		DW	PRINT	  ;61;F3, Print the marked text
		DW	MARK	  ;62;F4, Toggle mark state on/off
		DW	CUT	  ;63;F5, Move marked text to buffer
		DW	FIND_STR  ;64;F6, Search for text string
		DW	UNDO	  ;65;F7, Replace recently deleted chars
		DW	DEL_EOL	  ;66;F8, Delete from cursor to EOL
		DW	DEL_L	  ;67;F9, Delete the current line
		DW	UDEL_L	  ;68;F10, Insert the last deleted line
		DW	BAD_KEY	  ;69;(NumLock)
		DW	BAD_KEY	  ;70;(ScrollLock)
		DW	HOME_KEY  ;71;Home/7
		DW	UP	  ;72;Up/8
		DW	PGUP	  ;73;PgUp/9
		DW	BAD_KEY	  ;74;(-)
		DW	LEFT	  ;75;Left/4
		DW	BAD_KEY	  ;76;(5)
		DW	RIGHT	  ;77;Right/6
		DW	BAD_KEY	  ;78;(+)
		DW	END_KEY	  ;79;End/1
		DW	DOWN	  ;80;Down/2
		DW	PGDN	  ;81;PgDn/3
		DW	INSERT	  ;82;Ins/3
		DW	DEL_CHAR  ;83;Del/.

		DW	NUL_CHAR  ;84;Shft-F1 -- Add NUL character to file
		DW	ABORT	  ;85;Shft-F2 -- Quit and abandon changes
		DW	PRINT_FF  ;86;Shft-F3 -- Print a form-feed character
		DW	BAD_KEY	  ;87;Shft-F4
		DW	PASTE	  ;88;Shft-F5 -- Insert contents of Paste buffer
		DW	FIND_STR  ;89;Shft-F6 -- Search again for string
		DW	BAD_KEY	  ;90;Shft-F7
		DW	DEL_L	  ;91;Shft-F8 -- Delete line (Multi-Edit)
DISPATCH_END	EQU	92
		;--------------------------------
		; gap in keyboard scan code assignments
		;--------------------------------
DISP_CURS_BASE	EQU	115
		DW	SH_LEFT   ;115;Ctrl-Left arrow
		DW	SH_RIGHT  ;116;Ctrl-Right arrow
		DW	BOTTOM    ;117;Ctrl-End
		DW	CTRL_PGDN ;118;Ctrl-PgDn
		DW	TOP	  ;119;Ctrl-Home
DISP_CURS_END	EQU	120

;**		DW	CTRL_PGUP ;132;Ctrl-PgUp

;---------------------------------
; The following constant is a machine instruction that removes the CGA desnow 
; delay.  It is inserted into the code for EGA, VGA, and mono displays.
; See the article in PC-Magazine for further discussion.

NO_DESNOW = (OFFSET WRITE_IT - OFFSET HWAIT - 2) * 256 + 0EBH ;opcode JMP SHORT

;=======================================================================
; We start by initialize the display, then allocate memory for the file
; and paste segments.  Parse the command line for the filename, if one was 
; input, read in the file.  Finally set the INT 23 and 24 vectors.
;-----------------------------------------------------------------------
BEGIN:
		MOV	AH,30H		;get DOS version (JEG new)
		INT	21H
		CMP	AL,2
		JAE	DOS_2_UP
		MOV	EXIT_CODE,0	;is DOS version 1, exit with function 0.
		MOV	DX,OFFSET DOS_2_MESS ;message "Needs DOS 2.0"
;**short	JMP	EXIT_TO_DOS
		;JMP	SHORT EXIT_22_DOS ;(saves a byte)
		;-----------------------
DOS_2_UP:
		;JEG new -- program code checksum test
		MOV	SI,100H		;start of program file.
		MOV	SP,SI		;set stack pointer to top of PSP.
		MOV	CX,OFFSET CHEK_SUM_BYT - 0100H ;size of program file.
		MOV	AL,CHEK_SUM_BYT	;load checksum correction factor byte.
CHEKSUM_IS_OK:
		XOR	AX,AX
		MOV	DS,AX		;zero DS
		ASSUME	DS:NOTHING
		MOV	BL,10H
		MOV	AH,12H		;get EGA info
		INT	10H
		CMP	BL,10H		;did BL change?
		JE	NOT_EGA		;if not, no EGA in system
		TEST	BYTE PTR DS:[0487H],8 ;is EGA active?
		JNZ	NOT_EGA
		MOV	WORD PTR CS:HWAIT,NO_DESNOW ;get rid of desnow
		MOV	AX,DS:[0484H]	;get number of rows
		DEC	AL		;last row is for prompt line
		MOV	CS:[ROWS],AL	;save the number of rows
NOT_EGA:
		MOV	AX,DS:[044AH]	;get number of columns
		MOV	CS:COLUMNS,AX	;and store it
		MOV	AX,DS:[0463H]	;address of display card
		ADD	AX,6		;add six to get status port
		PUSH	CS
		POP	DS
		ASSUME	DS:CSEG
		MOV	STATUS_REG,AX
		CMP	AX,3BAH		;is this a MONO display?
		JNE	COLOR		;if not, must be a CGA
		MOV	WORD PTR HWAIT,NO_DESNOW ;get rid of desnow
		JMP	SHORT MOVE_STACK

COLOR:
		MOV	VIDEO_SEG,0B800H ;segment for color card
		XOR	BH,BH		;use page zero
		MOV	AH,8		;get current attribute
		INT	10H
		AND	AH,77H		;turn off blink and high intensity
		MOV	NORMAL,AH	;save the normal attribute
		XOR	AH,01110111B	;flip the color bits
		MOV	INVERSE,AH
		OR	AH,80H
		MOV	SRCH_CLR,AH	;search is inverse/blink
MOVE_STACK:
		MOV	BX,OFFSET END_BUFFER
;**rounding	ADD	BX,15		;add offset value for SEG rounding up
		MOV	CL,4		;convert program size to 
		SHR	BX,CL		; paragraphs
		MOV	AH,4AH		;deallocate unused memory
		INT	21H		;DOS call
		MOV	BX,1000H	;request 64K for file segment
		MOV	AH,48H
		INT	21H		;DOS call
		MOV	ES,AX
		ASSUME	ES:FILE_SEG
		MOV	AH,48H		;request 64K for paste buffer
		INT	21H		;DOS call
		JNC	GOT_ENOUGH	;if enough memory, continue
NOT_ENOUGH:
		MOV	DX,OFFSET MEMORY_ERROR

EXIT_2_DOS:	JMP	EXIT_TO_DOS	;jump island to allow SHORT jumps.
		;-----------------------
GOT_ENOUGH:
		MOV	PASTE_SEG,AX	;use this for the paste buffer
GET_FILENAME:
		MOV	SI,80H		;point to command tail in PSP
		MOV	CL,[SI]		;get number of characters in tail
		XOR	CH,CH		;make it a word
		INC	SI		;point to first character
		PUSH	SI
		ADD	SI,CX		;point to last character
		MOV	BYTE PTR [SI],0	;make it an ASCIIZ string (clear the CR)
		MOV	NAME_END,SI	;save pointer to last character
		POP	SI		;get back pointer to filename
		JCXZ	NO_FILENAME	;if no params, just exit
		CLD
DEL_SPACES:
		LODSB			;get character into AL
		CMP	AL," "		;is it a space?
		JNE	FOUND_LETTER
		LOOP	DEL_SPACES
FOUND_LETTER:
		DEC	SI		;backup pointer to first letter
		MOV	NAME_POINTER,SI	;save pointer to filename

		MOV	DX,NAME_POINTER
		MOV	AX,4300H	;get file attribute byte (in CL)
		INT	21H		;DOS call
		JC	ATTRIB_ERROR
		AND	CL,1		;keep bit-0, read-only status
		ADD	CL,CL		;shift RO bit up 
		OR	INSERT_MODE,CL	;save as index modifier value
ATTRIB_ERROR:
		MOV	DX,SI
		MOV	AX,3D00H	;setup to open file
		INT	21H		;DOS call
		; If no carry, Then the opened file handle is in AX
		; If no carry, Then the opened file handle is in AX
		JC	NO_FILENAME	;if we can't open, must be new file
FILE_OPENED:
		PUSH	ES
		POP	DS		;DS has file segment also
		ASSUME	DS:FILE_SEG
		MOV	BX,AX		;get the handle into BX
		XOR	DX,DX		;point to file buffer, DS:DX
		MOV	CX,0FFFEH	;read almost 64K bytes
		MOV	AH,3FH		;read from file or device
		; BX = file handle
		INT	21H		;DOS call
		; If no carry, Then AX contains number of bytes read
		MOV	DI,AX		;number of bytes read in
		JNC	FILE_READ_OK	;if no error, take jump
		MOV	DX,OFFSET READ_ERR_MESS
		;-----------------------
		; the file has been opened, it should now be closed. (JEG)
		;-----------------------
CLOSE_ERR_EXIT:
		MOV	AH,3EH		;close the opened file
		; BX = file handle
		INT	21H
		JMP	SHORT EXIT_2_DOS
		;-----------------------
FILE_READ_OK:
		MOV	LAST_CHAR,DI	;save the file size
		CMP	CX,AX		;did the buffer fill?
		MOV	DX,OFFSET FILE_TOO_BIG
		JE	CLOSE_ERR_EXIT	;if yes, it is too big
		MOV	AH,3EH		;close the file
		; BX = file handle
		INT	21H
;**dirty	MOV	BYTE PTR CS:DIRTY_FILE,0 ;file opened but not altered.
NO_FILENAME:
		PUSH	ES
		PUSH	ES		;save the file segment
		PUSH	CS
		POP	DS
		ASSUME	DS:CSEG
		;-----------------------
		;INT 24 is the critical error handler
		;-----------------------
		MOV	AX,3524H	;get INT 24 vector
		INT	21H		;DOS call
		MOV	WORD PTR OLDINT24,BX   ;store the offset
		MOV	WORD PTR OLDINT24+2,ES ;and the segment
		MOV	DX,OFFSET NEWINT24 ;point to new vector
		MOV	AX,2524H	;now change INT 24 vector
		INT	21H		;DOS call
		;-----------------------
		;INT 23 is the CTRL-Break or CTRL-C handler
		;-----------------------
		MOV	DX,OFFSET NEWINT23
		MOV	AX,2523H	;set the INT 23 vector
		INT	21H		;DOS call

		POP	ES		;get back file segment
		POP	DS
		ASSUME	DS:FILE_SEG
		CALL	REDO_PROMPT	;draw the prompt line

;-----------------------------------------------------------------------
; Here's the main loop.  It updates the screen, then reads a keystroke.
;-----------------------------------------------------------------------
READ_A_KEY:
		CMP	MARK_MODE,0	;is the mark state on?
		JZ	MARK_OFF	;if not, skip this
		OR	DIRTY_BITS,4	;refresh the current row
		MOV	DX,CURS_POSN
		CMP	SAVE_ROW,DH	;are we on the save row?
		JE	SAME_ROW	;if yes, then redo the row only
		OR	DIRTY_BITS,1	;refresh the whole screen
SAME_ROW:
		MOV	AX,CURSOR	;get cursor location
		MOV	BX,MARK_HOME	;get the anchor mark position
		CMP	AX,BX		;moving backward in file?
		JAE	SAME1
		MOV	MARK_START,AX	;switch start and end positions
		MOV	MARK_END,BX
		JMP	SHORT MARK_OFF
SAME1:
		MOV	MARK_END,AX	;store start and end marks
		MOV	MARK_START,BX
MARK_OFF:
		CALL	DISPLAY_SCREEN	;redraw the screen

                XOR     AH,AH           ;read the next key (wait if none ready)
		INT	16H		;BIOS call
		; AL = ASCII code or 0 (for function keys)
		; AH = scan code
                TEST    SRCH_FLG,0FFH
		JZ	CHECK_KEY	;jump if inverse not on
		MOV	SRCH_FLG,0	;turn off highlight
		OR	DIRTY_BITS,1	;redraw screen (next time)
CHECK_KEY:
		OR	AL,AL		;is this an extended code?
		JZ	IS_EXTENDED_CODE ;(jump if not an ASCII character)
 		CALL	INSERT_KEY	;put this ASCII character in the file
;**short	JMP	READ_A_KEY	;get another key
		JMP	SHORT RD_NEXT_KEY ;get another key
;---------------------------------------

IS_EXTENDED_CODE:
		;-----------------------
		; The following code is for "orphan" key codes and alias keys
		;-----------------------
		CMP	AH,132		;is it Ctrl-PgUp? (an orphan code)
		JNE	NOT_CT_PGUP
		CALL	CTRL_PGUP
;**short	JMP	READ_A_KEY
		JMP	SHORT RD_NEXT_KEY ;get another key
		;-----------------------
NOT_CT_PGUP:
		CMP	AH,32		;is it Alt-D (MultiEdit Del-EOL)?
		JNE	NOT_ALT_D
		MOV	AH,66		;substitute scan code for F8
NOT_ALT_D:
		CMP	AH,31		;is it Alt-S (BSE string search)?
		JNE	NOT_ALT_S
		MOV	AH,64		;substitute scan code for F6
NOT_ALT_S:
		CMP	AH,30		;is it Alt-A (BSE search again)?
		JNE	NOT_ALT_A
		MOV	AH,89		;substitute scan code for Shft-F6
NOT_ALT_A:
		;-----------------------
		; The following code sets up a PASCAL style CASE statement.
		;-----------------------
		CMP	AH,DISPATCH_END	;split the dispatch table
		JB	DO_DISPATCH
		;-----------------------
		; offset cursor group of keys to join the regular dispatch table.
		;-----------------------
		CMP	AH,DISP_CURS_BASE
		JB	RD_NEXT_KEY
		CMP	AH,DISP_CURS_END
		JAE	RD_NEXT_KEY
		SUB	AH,LOW (DISP_CURS_BASE - DISPATCH_END) ;close table gap
DO_DISPATCH:
		;-----------------------
		; This is a PASCAL style CASE statement.
		;-----------------------
		MOV	BX,AX		;put AH offset value in BX, AL=0
		XCHG	BL,BH		;make into a proper word
		SUB	BX,DISPATCH_BASE ;zero offset for dispatch table jump
		JC	RD_NEXT_KEY	;too low, not in table
		ADD	BX,BX		;make into word
		CALL	CS:DISPATCH_TABLE[BX] ;call the key procedure
RD_NEXT_KEY:	JMP	READ_A_KEY	;then read another key


;=======================================================================
; KEYBOARD and CURSOR services
;=======================================================================
; These two routines shift the display right or left to allow editing 
; files which contain lines longer than 80 columns.
;-----------------------------------------------------------------------
SH_LEFT		PROC	NEAR
		CMP	LEFT_MARGIN,0	;at start of line already?
		JE	NO_SHIFT	;if yes,then don't shift
		SUB	LEFT_MARGIN,8	;move the window over
		JMP	SHORT SH_RETURN
SH_LEFT		ENDP
;-----------------------------------------------------------------------
SH_RIGHT	PROC	NEAR
		CMP	LEFT_MARGIN,255 - 8 ;past max allowable margin?
		JAE	NO_SHIFT	;then can't move any more
		ADD	LEFT_MARGIN,8	;this moves the margin over
SH_RETURN:
		CALL	CURSOR_COL	;compute column for cursor
		MOV	SAVE_COLUMN,DL	;save the current column
		OR	DIRTY_BITS,1	;redraw the screen
NO_SHIFT:
;**dispatch	JMP	READ_A_KEY
;**bad_key	RET
SH_RIGHT	ENDP

;-----------------------------------------------------------------------
; DISPATCH_TABLE calls to BAD_KEY now go here so that the stack can be 
; kept equallized.  
;-----------------------------------------------------------------------
BAD_KEY		PROC	NEAR
		RET
BAD_KEY		ENDP

;=======================================================================
; This routine moves the cursor to the top of the file.
;-----------------------------------------------------------------------
TOP		PROC	NEAR
		XOR	AX,AX		;get a zero into AX
		MOV	CURSOR,AX	;cursor to start of file
		MOV	TOP_OF_SCREEN,AX
		MOV	LEFT_MARGIN,AL	;move to far left margin
		MOV	CURS_POSN,AX	;home the cursor
		MOV	SAVE_COLUMN,AL	;save the cursor column
		MOV	DIRTY_BITS,3	;redraw the screen and cursor
		RET
TOP		ENDP

;=======================================================================
; This routine moves the cursor to the bottom of the file.
;-----------------------------------------------------------------------
BOTTOM		PROC	NEAR
		MOV	DH,ROWS		;get screen size
		MOV	SI,LAST_CHAR	;point to last character
		DEC	SI
		MOV	LEFT_MARGIN,0	;set window to start of line
		CALL	LOCATE		;adjust the cursor screen position
		CALL	HOME		;move cursor to start of line
		MOV	DIRTY_BITS,1	;this will redraw the screen
		RET
BOTTOM		ENDP

;=======================================================================
; This routine moves the cursor to the start of the current line.
; If <HOME> key and already at start of line, move to start of previous line.
;-----------------------------------------------------------------------
HOME_KEY	PROC	NEAR
		CALL	LEFT		;back up one space, in case at home
HOME_KEY	ENDP

HOME		PROC	NEAR
		CALL	FIND_START	;find start of line
		MOV	CURSOR,SI	;save the new cursor
		MOV	SAVE_COLUMN,0	;save the cursor column

		MOV	BYTE PTR CURS_POSN,0 ;store the column number
		RET
HOME		ENDP

;=======================================================================
; These routines move the cursor right and left
;-----------------------------------------------------------------------
RIGHT		PROC	NEAR
		MOV	SI,CURSOR
		CMP	SI,LAST_CHAR	;at end of file?
		JE	LR_NO_CHANGE	;if yes, then can't move
		INC	SI
		CMP	SI,LAST_CHAR	;at end of file?
		DEC	SI
		JAE	INC_RIGHT	;if yes, then increment
		CMP	WORD PTR [SI],CRLF ;is it CRLF?
		JE	MOVE_DOWN	;if yes, then move down to next line
INC_RIGHT:
		;-----------------------
		INC	CURSOR		;advance the cursor
		JMP	SHORT LR_RETURN
MOVE_DOWN:
		CALL	HOME		;move to start of line
		JMP	SHORT DOWN	;and move down one row
		;(CALL/RETurn)
RIGHT		ENDP
;-----------------------------------------------------------------------
LEFT		PROC	NEAR
		CMP	CURSOR,0	;at start of file?
		JZ	LR_NO_CHANGE	;then can't move left
		MOV	DX,CURS_POSN
		OR	DL,DL		;at first column?
		JZ	MOVE_UP		;if yes, then move up one
		DEC	CURSOR		;shift the cursor offset
LR_RETURN:
		CALL	CURSOR_COL	;compute column for cursor
		MOV	SAVE_COLUMN,DL	;save the cursor column
LR_NO_CHANGE:
		MOV	UNDO_LENGTH,0
		RET
		;-----------------------
MOVE_UP:
		CALL	UP		;move up to next row
		JMP	SHORT ENDD	;and move to end of line
		;(CALL/RETurn)
LEFT		ENDP

;-----------------------------------------------------------------------
; This routine moves the cursor to the end of the current line.
; If END key and already at end of line, move to end of next line.
;-----------------------------------------------------------------------
END_KEY		PROC	NEAR
		CALL	RIGHT		;move one space right, if at EOL
END_KEY		ENDP

ENDD		PROC	NEAR
		MOV	SI,CURSOR
		CALL	FIND_EOL	;find end of this line
		MOV	CURSOR,SI	;store the new cursor
		CALL	CURSOR_COL	;compute the correct column
		MOV	SAVE_COLUMN,DL	;save the cursor column
		RET
ENDD		ENDP

;-----------------------------------------------------------------------
; This routine moves the cursor down one row.  When the last row is reached, 
; the screen is shifted up one row.
;-----------------------------------------------------------------------
DOWN		PROC	NEAR
		MOV	UNDO_LENGTH,0
		MOV	DX,CURS_POSN
		CMP	DH,ROWS		;at bottom row already?
		MOV	SI,CURSOR	;get position in file
		JE	SCREEN_UP	;if at bottom, then scroll up
		CALL	FIND_NEXT	;find the start of next line
		JC	DOWN_RET	;if no more lines, then return
		MOV	CURSOR,SI
		INC	DH		;advance cursor to next row
		CALL	SHIFT_RIGHT	;move cursor to current column
DOWN_RET:
		RET
		;-----------------------
SCREEN_UP:
		CMP	SI,LAST_CHAR	;get cursor offset
		JE	DOWN_RET
		CALL	FIND_START	;find the start of this line
		MOV	CURSOR,SI	;this is the new cursor
		CALL	FIND_NEXT	;find the offset of next line
		JC	SHIFT_RET	;if no more lines, then return
		MOV	CURSOR,SI	;this is the new cursor
		MOV	SI,TOP_OF_SCREEN ;get the start of the top row
		CALL	FIND_NEXT	;and find the next line
		MOV	TOP_OF_SCREEN,SI ;store the new top of screen
		JMP	SHORT SHIFT_RET
		;(CALL/RETurn)
DOWN		ENDP

;-----------------------------------------------------------------------
; This routine moves the cursor up one row.  If the cursor is at the first row, 
; the screen is scrolled down.
;-----------------------------------------------------------------------
UP		PROC	NEAR
		MOV	UNDO_LENGTH,0
		MOV	DX,CURS_POSN
		MOV	SI,CURSOR
		OR	DH,DH		;at top row already?
		JZ	SCREEN_DN	;if yes, then scroll down
		DEC	DH		;move the cursor up one row
		CALL	FIND_CR		;find the beginning of this row
		MOV	CURSOR,SI
		CALL	FIND_START	;find start of this row
		MOV	CURSOR,SI
		CALL	SHIFT_RIGHT	;skip over to current column
AT_TOP:
		RET
		;-----------------------
SCREEN_DN:
		MOV	SI,TOP_OF_SCREEN
		OR	SI,SI		;at start of file?
		JZ	AT_TOP		;if at top, then do nothing
		CALL	FIND_PREVIOUS	;find the preceding line
		MOV	TOP_OF_SCREEN,SI ;save new top of screen
		MOV	SI,CURSOR
		CALL	FIND_PREVIOUS	;find the preceding line
		MOV	CURSOR,SI	;this is the new cursor
SHIFT_RET:
		OR	DIRTY_BITS,1	;need to redraw the screen
		MOV	SI,CURSOR
		MOV	DX,CURS_POSN
		JMP	SHIFT_RIGHT	;move cursor to current column
		;(CALL/RETurn)
UP		ENDP

;=======================================================================
; These four routines move the screen one page at a time by calling the 
; UP and DOWN procedures.
;-----------------------------------------------------------------------
CTRL_PGDN	PROC	NEAR	;do PgDn then PgUp
		CALL	PGDN
		JMP	SHORT PGUP
		;(CALL/RETurn)
CTRL_PGDN	ENDP
;-----------------------------------------------------------------------
PGUP		PROC	NEAR
		MOV	CS:PAGE_PROC,OFFSET UP
		JMP	SHORT PAGE_UP_DN
PGUP		ENDP
;-----------------------------------------------------------------------
CTRL_PGUP	PROC	NEAR	;do PgUp then PgDn
		CALL	PGUP
;**		JMP	SHORT PGDN
		;(CALL/RETurn)
CTRL_PGUP	ENDP
;-----------------------------------------------------------------------
PGDN		PROC	NEAR
		MOV	CS:PAGE_PROC,OFFSET DOWN
PAGE_UP_DN:
		MOV	CL,CS:ROWS	;get vertical length of screen
		SUB	CL,5		;don't page a full screen
		XOR	CH,CH		;make it a word
PAGE_LOOP:
		PUSH	CX
		CALL	PAGE_PROC	;move the cursor down
		POP	CX
		LOOP	PAGE_LOOP	;loop for one page length
		RET
PGDN		ENDP

;=======================================================================
; This routine toggles the Insert/Overstrike mode.
;-----------------------------------------------------------------------
INSERT		PROC	NEAR
	;	ASSUME	DS:NOTHING
;**RO mode	NOT	CS:INSERT_MODE	;toggle the switch
		XOR	CS:INSERT_MODE,1 ;toggle the "I/O" switch
		CALL	REDO_PROMPT ;redraw the insert/overstrike status
		RET
INSERT		ENDP

;=======================================================================
; FILE MANIPULATION services
;=======================================================================
; This routine forces the insertion of the NUL character, 00H, in the file.
;-----------------------------------------------------------------------
NUL_CHAR	PROC	NEAR
		XOR	AX,AX
NUL_CHAR	ENDP

;-----------------------------------------------------------------------
; This routine adds a character into the file.  In insert mode, remaining 
; characters are pushed forward.  If the scan code for <Enter> is detected, 
; a <CR><LF> pair is added as the EOL marker.  If the scan code for 
; <Backspace> is detected, the character to the left of the cursor is 
; deleted (unless the cursor is already at the start of the file).  
;-----------------------------------------------------------------------
INSERT_KEY	PROC	NEAR
		ASSUME	DS:FILE_SEG
		MOV	SI,CS:CURSOR

		CMP	CS:INSERT_MODE,1 ;in insert mode? (0=ovr,1=ins,2 or 3=RO)
		JA	FILE_FULL	;jump if read-only file

		CMP	AH,28		;was this the <Enter> key scan code?
		JE	NEW_LINE	;if yes, make new line: <CR><LF>.

		CMP	AH,14		;was it the <Backspace> key scan code?
		JE	BACK_SPACE	;if yes, delete character left.

		CMP	CS:INSERT_MODE,1 ;in insert mode? (0=ovr,1=ins,2 or 3=RO)
		JE	INSERT_CHAR	;jump if Insert
		;-----------------------
		; test for overstrike character at end of line or file.
		; if EOL or EOF, then insert rather than overstrike.
		;-----------------------
		CMP	SI,CS:LAST_CHAR	;at end of file?
		JAE	INSERT_CHAR
		INC	SI
		CMP	SI,CS:LAST_CHAR	;at end of file?
		DEC	SI
		JAE	INSERT_CHAR
		CMP	WORD PTR [SI],CRLF ;at end of line?
		JE	INSERT_CHAR

OVERSTRIKE_NOT_AT_CRLF:
		MOV	DI,SI
		PUSH	AX		;save new character
		XCHG	DS:[SI],AL	;switch new character for old one
		CALL	SAVE_CHAR	;store the old character
		POP	AX		;get back new character
		JMP	SHORT ADVANCE
;---------------------------------------
INSERT_CHAR:
		PUSH	SI
		PUSH	AX		;save the new character
		MOV	AX,1
		CALL	OPEN_SPACE	;make room for it at SI
		POP	AX		;get back the new character
		POP	DI
		JC	FILE_FULL
		STOSB			;insert character in file buffer, ES:DI
ADVANCE:
		OR	CS:DIRTY_BITS,4	;current line is dirty

		;-----------------------
		; see if we made a CR-LF pair by adding a Ctrl-M with a Ctrl-J
		;-----------------------
		CALL	C_IF_NEW_CRLF	;see if in middle of new CR-LF
		JC	FILE_FULL	;jump if new line was done
		;------------------------
		CMP	AL,CR		;was key <Ctrl-M> - CR?
		JNE	INS_NOT_CR
		MOV	CS:DIRTY_BITS,1	;redraw the screen (just in case EOL)
INS_NOT_CR:
		;-----------------------
		PUSH	UNDO_LENGTH
		CALL	RIGHT		;move cursor to next letter
		POP	UNDO_LENGTH
FILE_FULL:
		RET

CR_AT_EOF:
		INC	CS:CURSOR
		RET

;---------------------------------------
; process the <Enter> key, make new line
;---------------------------------------
NEW_LINE:
		PUSH	SI
		MOV	AX,2
		CALL	OPEN_SPACE	;make space for CR and LF
		POP	DI		;get back old cursor location
		JC	FILE_FULL
		MOV	AX,CRLF 	;LF*256+CR
		STOSW			;store the CR and LF
		JMP	SHORT ADVANCE_NEW_LINE ;repaint the screen
		;(CALL/RETurn)
INSERT_KEY	ENDP

;---------------------------------------
; process the <Backspace> key, delete character left of cursor.
;---------------------------------------
BACK_SPACE	PROC	NEAR
		OR	SI,SI		;is cursor at start of file?
		JZ	FILE_FULL	;if so, no delete right
		CALL	LEFT		;move left one space (flush UnDo buffer)
;**follows	JMP	DEL_CHAR	;and delete the character (into buffer)
		;(CALL/RETurn)
BACK_SPACE	ENDP

;=======================================================================
; This routine deletes the character at the cursor by shifting the remaining 
; characters forward.  <Del> key
;-----------------------------------------------------------------------
DEL_CHAR	PROC	NEAR
		CMP	CS:INSERT_MODE,1 ;in insert mode? (0=ovr,1=ins,2 or 3=RO)
		JA	NO_DEL		;jump if read-only file
		MOV	CX,LAST_CHAR
		MOV	SI,CURSOR
		MOV	DI,SI
		CMP	SI,CX		;are we at end of file?
		JAE	NO_DEL		;if yes, then don't delete
		LODSB			;loads char in AL, DS:SI
		CALL	SAVE_CHAR	;save it for UNDO function
		MOV	AH,[SI]		;look at the next character also
		PUSH	AX		;save character we're deleting
		DEC	LAST_CHAR	;shorten the file by one
		SUB	CX,SI
		REP	MOVSB		;move file down one, DS:SI to ES:DI

		POP	AX		;get back character we deleted
		CMP	AX,CRLF		;did we delete a CR?
		JE	COMBINE
		OR	DIRTY_BITS,4	;current line is dirty
		;-----------------------
		; see if we made a CRLF by deleting a character.
		; if we are in the middle of a CRLF, move the cursor back one.
		;-----------------------
		JMP	SHORT C_IF_NEW_CRLF
		;(CALL/RETurn) - saves a byte
;---------------------------------------
COMBINE:				;deleted an EOL marker, CR-LF
		CALL	DEL_CHAR	;now delete the line feed (recursive)
                MOV     DIRTY_BITS,3
                MOV     DX,CURS_POSN
		MOV	SAVE_COLUMN,DL	;save the cursor column
NO_DEL:
		RET
DEL_CHAR	ENDP

;=======================================================================
; see if we made a CR-LF pair with the cursor located on the LF character 
; by joining the character (Ctrl-M) with a (Ctrl-J).  If so, back up the 
; cursor and open a new line and return with carry set.  if not, return with 
; carry clear.
;-----------------------------------------------------------------------
C_IF_NEW_CRLF	PROC	NEAR
		MOV	SI,CS:CURSOR	;present cursor location
		OR	SI,SI		;is it at start of file
		JZ	DONE_CRLF
		CMP	WORD PTR [SI-1],CRLF ;did we make CR-LF?
		JNE	DONE_CRLF
		DEC	CS:CURSOR	;move cursor back to point at CR code
C_IF_NEW_CRLF	ENDP

;---------------------------------------
; This routine opens a new line.
;---------------------------------------
ADVANCE_NEW_LINE PROC	NEAR		;split line on screen for CR-LF
		CALL	HOME		;cursor to start of line
		CALL	DOWN		;move down to the new line
		MOV	DIRTY_BITS,3	;repaint the screen and cursor
		STC			;C=1 if new line was done
		RET
DONE_CRLF:
		CLC			;C=0 if not new line
		RET
ADVANCE_NEW_LINE ENDP

;=======================================================================
; This routine restores any characters which have recently been deleted.
;-----------------------------------------------------------------------
UNDO		PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		XOR	AX,AX
		XCHG	AX,CS:UNDO_LENGTH ;get buffer length
		MOV	SI,OFFSET UNDO_BUFFER
		JMP	INSERT_STRING
		;(CALL/RETurn)
UNDO		ENDP

;=======================================================================
; This routine inserts spaces into the file buffer.  On entry, AX
; contains the number of spaces to be inserted.  On return, CF=1 if 
; there was not enough space in the file buffer.
;-----------------------------------------------------------------------
OPEN_SPACE	PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		MOV	CX,LAST_CHAR	;last character in the file
		MOV	SI,CX
		MOV	DI,CX
		ADD	DI,AX		;offset for new end of file
		JC	NO_ROOM		;if no more room, return error
		MOV	LAST_CHAR,DI	;save offset of end of file
		SUB	CX,CURSOR	;number of characters to shift
		DEC	DI
		DEC	SI
		STD			;string moves goes forward
		REP	MOVSB		;shift the file upward
		CLD
		MOV	BYTE PTR DIRTY_FILE,0FFH ;file has been altered
		CLC
NO_ROOM:				;carry is set if no room in file
		RET
OPEN_SPACE	ENDP

;=======================================================================
; This routine adds a character to the UNDO buffer.
;-----------------------------------------------------------------------
SAVE_CHAR	PROC	NEAR
		MOV	BX,UNDO_LENGTH
		OR	BH,BH		;is buffer filled?
		JNZ	NO_SAVE		;buffer overflowed, no insert
		INC	UNDO_LENGTH
		MOV	BYTE PTR CS:UNDO_BUFFER[BX],AL
		MOV	BYTE PTR CS:DIRTY_FILE,0FFH ;file altered
NO_SAVE:
		RET
SAVE_CHAR	ENDP

;=======================================================================
; This routine deletes from the cursor position to the end of the line.
;-----------------------------------------------------------------------
DEL_EOL		PROC	NEAR
;**Shft-F8	MOV	CX,CURSOR_POSN
;**Shft-F8	JCXZ	DEL_L
		;-----------------------
		CMP	CS:INSERT_MODE,1 ;in insert mode? (0=ovr,1=ins,2 or 3=RO)
		JA	NO_DEL_L	;jump if read-only file
		MOV	LINE_FLAG,0
		PUSH	CURSOR		;save starting cursor location
		CALL	ENDD		;move to the end of the line
		POP	SI		;get back starting cursor
		MOV	CX,CURSOR	;offset of end of line
		MOV	CURSOR,SI	;restore starting cursor
		JMP	SHORT DEL_END	;delete characters to end of line
		;(CALL/RETurn)
DEL_EOL		ENDP

;-----------------------------------------------------------------------
; This routine deletes a line, placing it in the line buffer. <F9>, <Shft-F8>
;-----------------------------------------------------------------------
DEL_L		PROC	NEAR
		CMP	CS:INSERT_MODE,1 ;in insert mode? (0=ovr,1=ins,2 or 3=RO)
		JA	NO_DEL_L	;jump if read-only file
 		MOV	LINE_FLAG,1
		CALL	FIND_START	;find start of this line
		MOV	CURSOR,SI	;this will be the new cursor
		PUSH	SI		;save the cursor position
		CALL	FIND_NEXT	;find the next line
		MOV	CX,SI		;CX will hold line length
		POP	SI		;get back new cursor location
DEL_END:
		MOV	BYTE PTR DIRTY_FILE,0FFH ;file has been altered

		SUB	CX,SI		;number of bytes on line
		OR	CH,CH		;is line too long to fit?
		JZ	NOT_TOO_LONG
		MOV	CX,100H		;save only 256 characters
NOT_TOO_LONG:
		MOV	LINE_LENGTH,CX	;store length of deleted line
		JCXZ	NO_DEL_L
		MOV	DI,OFFSET LINE_BUFFER ;buffer for deleted line

		PUSH	CX
		PUSH	ES
		PUSH	CS
		POP	ES		;line buffer is in CSEG
		REP	MOVSB		;put deleted line in buffer
		POP	ES		;get back file segment
		POP	AX

		MOV	CX,LAST_CHAR	;get the file size
		SUB	LAST_CHAR,AX	;subtract the deleted line
		MOV	SI,CURSOR	;get new cursor location
		MOV	DI,SI
		ADD	SI,AX		;SI points to end of file
		SUB	CX,SI		;length of remaining file
		JCXZ	NO_DEL_L
		REP	MOVSB		;shift remainder of file up
NO_DEL_L:
		MOV	DIRTY_BITS,3	;redraw the screen and adjust cursor
		RET
DEL_L		ENDP

;=======================================================================
; This routine undeletes a line by copying it from the line buffer into 
; the file.
;-----------------------------------------------------------------------
UDEL_L		PROC	NEAR
		CMP	LINE_FLAG,0	;is this an end of line only?
		JE	UDEL_EOL	;if yes, don't home the cursor
		CALL	HOME		;move cursor to home
UDEL_EOL:
		MOV	AX,LINE_LENGTH	;length of deleted line
		MOV	SI,OFFSET LINE_BUFFER
;**insert_str	JMP	INSERT_STRING	;(follows immediately)
		;(CALL/RETurn)
UDEL_L		ENDP

;-----------------------------------------------------------------------
; This routine inserts AX characters from CS:SI into the file.
; (This routine follows "UDEL_L")
;-----------------------------------------------------------------------
INSERT_STRING	PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		PUSH	SI		;save string buffer
		MOV	SI,CS:CURSOR	;get cursor offset
		PUSH	AX		;save length of string
		PUSH	SI
		CALL	OPEN_SPACE	;make space to insert string
		POP	DI		;get back cursor position
		POP	CX		;get back string length
		POP	SI		;get back string buffer
		JC	NO_SPACE	;if no space available, exit

		PUSH	DS
		PUSH	CS
		POP	DS
		ASSUME	DS:CSEG
		REP	MOVSB		;copy characters DS:SI to ES:DI
		MOV	DIRTY_BITS,3	;redraw the screen and adjust cursor
		POP	DS
		ASSUME	DS:NOTHING
		CALL	C_IF_NEW_CRLF
NO_SPACE:
		RET
INSERT_STRING	ENDP

;=======================================================================
; VIDEO services
;=======================================================================
; This routine displays a character by writing directly to 
; the screen buffer.  To avoid screen noise (snow) on the color
; card (CGA), the horizontal retrace has to be monitored.
;-----------------------------------------------------------------------
WRITE_INVERSE	PROC	NEAR		
		ASSUME	DS:FILE_SEG, ES:FILE_SEG
		MOV	BH,CS:INVERSE	;attribute for inverse video
		JMP	SHORT WRITE_SCREEN
;-----------------------------------------------------------------------
WRITE_FIND:
		MOV	BH,CS:SRCH_CLR	;attribute for find string
;		MOV	BH,CS:INVERSE	;attribute for find string
		JMP	SHORT WRITE_SCREEN
;-----------------------------------------------------------------------
WRITE_NORMAL:
		MOV	BH,CS:NORMAL	;attribute for normal video
WRITE_SCREEN:
		MOV	BL,AL		;save the character
		PUSH	ES
		LES	DX,CS:VIDEO_STATUS_REG ;video status register
		;-------------------------------------------------------
		; HWAIT is used to "desnow" the display for the CGA.
		; If not CGA, the following instruction is modified to a 
		; JMP   SHORT WRITE_IT
		;-------------------------------------------------------
HWAIT:
		IN	AL,DX		;get video status
		ROR	AL,1		;look at horizontal retrace
		JNC	HWAIT		;wait for retrace
WRITE_IT:
		MOV	AX,BX		;get the character/attributes
		STOSW			;write the character
		POP	ES
		RET
WRITE_INVERSE	ENDP

;=======================================================================
; This routine moves the cursor to the row/column in DX.
;-----------------------------------------------------------------------
SET_CURSOR	PROC	NEAR
		XOR	BH,BH		;we're using page zero
		MOV	AH,2		;BIOS set cursor function
		INT	10H
		RET
SET_CURSOR	ENDP

;=======================================================================
; This routine computes the video buffer offset for the row/column in DX.
;-----------------------------------------------------------------------
POSITION	PROC	NEAR
		MOV	AX,CS:COLUMNS	;take columns per row
		MUL	DH		;times row number
		XOR	DH,DH
		ADD	AX,DX		;add the column number
		SHL	AX,1		;times 2 for offset
		MOV	DI,AX		;return result in DI
		RET
POSITION	ENDP

;=======================================================================
; This routine erases from the location in DX to the right edge of the screen.
;-----------------------------------------------------------------------
ERASE_EOL	PROC	NEAR
		ASSUME	DS:NOTHING
		CALL	POSITION	;find screen offset
		MOV	CX,CS:COLUMNS	;get screen size
		SUB	CL,DL		;subtract current position
		JCXZ	NO_CLEAR
ERASE_LOOP:
		MOV	AL," "		;write blanks to erase
		CALL	WRITE_NORMAL	;display it
		LOOP	ERASE_LOOP
NO_CLEAR:
		RET
ERASE_EOL	ENDP

;=======================================================================
; This routine displays the function key prompt and insert/overstrike mode 
; state.  It sets DIRTY_BITS := 3 to force redraw of the entire screen 
; and locate cursor.
;-----------------------------------------------------------------------
REDO_PROMPT	PROC	NEAR
		ASSUME	DS:NOTHING, ES:NOTHING
		PUSH	DS
		PUSH	CS
		POP	DS
		ASSUME	DS:CSEG
		MOV	DH,ROWS		;put prompt at last row
		INC	DH
		XOR	DL,DL		;and column 0
		CALL	POSITION	;convert to screen offset
		MOV	SI,OFFSET PROMPT_STRING
KEY_LOOP:
		MOV	AL,"F"		;display an "F"
		CALL	WRITE_NORMAL
		LODSB
		OR	AL,AL		;last key in prompt?
		JZ	PROMPT_DONE
		CALL	WRITE_NORMAL

		CMP	BYTE PTR CS:[SI],"0" ;is it F10?
		JNE	TEXT_LOOP
		LODSB
		CALL	WRITE_NORMAL
TEXT_LOOP:
		LODSB
		OR	AL,AL		;last letter in word?
		JNZ	WRITE_CHAR

		MOV	AL," "		;display a space
		CALL	WRITE_NORMAL
		JMP	KEY_LOOP
WRITE_CHAR:
		CALL	WRITE_INVERSE	;display the letter
		JMP	TEXT_LOOP	;do the next letter
PROMPT_DONE:
		MOV	DH,ROWS
		INC	DH		;get the last row on the screen
		MOV	DL,PROMPT_LENGTH + 9
		CALL	ERASE_EOL	;erase to the end of this row
		MOV	BL,INSERT_MODE
		XOR	BH,BH
		MOV	AL,CS:[BX + OFFSET INSERT_CODE]
	;	MOV	AL,"O"		;write an "O" (for "Overstrike")
	;	CMP	INSERT_MODE,1	;in insert mode?
	;	JB	OVERSTRIKE
	;	MOV	AL,"I"		;write an "I" (for "Insert")
	;	JE	OVERSTRIKE
	;	MOV	AL,"R"		;write an "R" (for "read-only")
OVERSTRIKE:
		DEC	DI		;backup one character position
		DEC	DI
		CALL	WRITE_NORMAL
		MOV	DIRTY_BITS,3	;now redraw the entire screen
		POP	DS
		ASSUME	DS:NOTHING
		RET
REDO_PROMPT	ENDP

;=======================================================================
; This routine displays the file buffer on the screen.
; DISPLAY_BOTTOM has been deleted to reduce the program code size.
;-----------------------------------------------------------------------
DISPLAY_SCREEN	PROC	NEAR
		ASSUME	DS:FILE_SEG, ES:FILE_SEG

                TEST    DIRTY_BITS,2    ;see if we should adjust the cursor
		JZ	DISP_CURS_OK
		MOV	SI,CURSOR	;get the new cursor offset
		MOV	DX,CURS_POSN	;also get the current row
		CALL	LOCATE		;adjust the cursor screen position
DISP_CURS_OK:

                MOV     DX,CURS_POSN
		MOV	SAVE_ROW,DH
		CALL	SET_CURSOR	;position the cursor

                TEST    DIRTY_BITS,1    ;see if we should update the screen
                JNZ     DO_UPDATE_SCREEN

                TEST    DIRTY_BITS,4    ;is the current line dirty?
                JZ      DISP_DONE       ;if not, take jump
                CALL    DISPLAY_CURRENT ;redraw the current line
                JMP     SHORT DISP_DONE

DO_UPDATE_SCREEN:
                MOV     SI,TOP_OF_SCREEN ;point to first char on screen
		XOR	DH,DH		;start at first row
;		JMP	SHORT NEXT_ROW
;		;-----------------------
;DISPLAY_BOTTOM:				;this redraws the bottom only
;		CALL	FIND_START	;find first character on this row
;		MOV	DX,CURS_POSN	;get current cursor row
NEXT_ROW:
		PUSH	DX
		CALL	DISPLAY_LINE	;display a line
		POP	DX
		;-----------------------
		; the keyboard is tested here to see if a key is waiting
		;-----------------------
		MOV	AH,1
		INT	16H
		MOV	AL,1		;for dirty_bits, update not completed
		JNZ	DISP_NOT_DONE	;jump if there is a key is waiting

		INC	DH		;move to the next row
		CMP	DH,ROWS		;at end of screen yet?
		JBE	NEXT_ROW	;do all the rows
DISP_DONE:
                MOV     AL,0
DISP_NOT_DONE:
                MOV     DIRTY_BITS,AL   ;screen is completely redone
		RET
DISPLAY_SCREEN	ENDP

;=======================================================================
; This routine displays a single line to the screen.  DH holds the 
; row number, SI has the offset into the file buffer.  Tabs are expanded.  
; Adjustment is made for side shift.
;-----------------------------------------------------------------------
DISPLAY_CURRENT	PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		CALL	FIND_START
		MOV	DX,CS:CURS_POSN
DISPLAY_CURRENT ENDP
		;-----------------------
DISPLAY_LINE	PROC	NEAR		;external entry point
		XOR	DL,DL		;start at column zero
		MOV	CS:MARGIN_COUNT,DL
		MOV	CX,DX		;use CL to count the columns
		CALL	POSITION	;compute offset into video
NEXT_CHAR:
		CMP	SI,LAST_CHAR	;at end of file?
		JAE	LINE_DONE
		LODSB			;get next character, DS:SI
		CMP	AL,TAB		;is this a Tab character?
		JE	EXPAND_TAB	;if yes, expand to spaces

		CMP	SI,LAST_CHAR	;at end of file now?
		JAE	DO_PUT		;jump, can't be CR-LF pair

		CMP	WORD PTR [SI-1],CRLF ;EOL marker
		JE	FOUND_CR	;quit when a CR-LF is found
DO_PUT:
		CALL	PUT_CHAR	;put character onto screen
TAB_DONE:
		CMP	CL,CS:COLUMNSB	;at right edge of screen?
		JB	NEXT_CHAR
		INC	SI
		CMP	SI,LAST_CHAR	;at end of file?
		DEC	SI
		JAE	NOT_BEYOND
		CMP	WORD PTR [SI],CRLF ;at end of line?
		;----------------------
		JE	NOT_BEYOND
DO_DIAMOND:
		DEC	DI		;backup one character
		DEC	DI
		MOV	AL,4		;show a diamond
		CALL	WRITE_INVERSE	;in inverse video
NOT_BEYOND:
		JMP	FIND_NEXT	;find start of next line
		;(CALL/RETurn)
;---------------------------------------
EXPAND_TAB:
		MOV	AL," "		;convert tab to spaces
		CALL	PUT_CHAR
		MOV	AL,MARGIN_COUNT
		ADD	AL,CL		;CL is column count
		TEST	AL,00000111B	;at even multiples of eight?
		JNZ	EXPAND_TAB	;if not, keep adding spaces
		JMP	TAB_DONE
;---------------------------------------
FOUND_CR:
		INC	SI		;past the CR-LF
LINE_DONE:
		MOV	DX,CX
		JMP	ERASE_EOL	;erase the end of the line
		;(CALL/RETurn)
		;-----------------------
DISPLAY_LINE	ENDP

;=======================================================================
; This routine displays a single character to the screen.  If the character 
; is marked, it is shown in inverse video.  Characters outside the current 
; margin are not displayed.  Characters left of the margin are skipped.
;-----------------------------------------------------------------------
PUT_CHAR	PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		MOV	BL,MARGIN_COUNT	;get distance to left margin
		CMP	BL,LEFT_MARGIN	;are we inside left margin?
		JAE	IN_WINDOW	;yes, show the character
		INC	BL
		MOV	MARGIN_COUNT,BL
		RET
IN_WINDOW:
		CMP	SRCH_FLG,0
		JE	CKM
		CMP	SI,SRCH_BASE
		JBE	CKM
		CMP	SI,SRCH_END
		JA	CKM
		CALL	WRITE_FIND
;**inverse	CALL	WRITE_INVERSE	;found string highlighted, inverse video
		JMP	SHORT NEXT_COL
CKM:
		;-----------------------
		CMP	SI,MARK_START	;is this character marked?
		JBE	NOT_MARKED
		CMP	SI,MARK_END
		JA	NOT_MARKED
		CALL	WRITE_INVERSE	;marked characters shown inverse
		JMP	SHORT NEXT_COL
		;-----------------------
NOT_MARKED:
		CALL	WRITE_NORMAL
NEXT_COL:
		INC	CL		;increment the column count
		RET
PUT_CHAR	ENDP

;=======================================================================
; This routine adjusts the cursor position ahead to the saved cursor column.  
; On entry DH has the cursor row.
;-----------------------------------------------------------------------
SHIFT_RIGHT	PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		MOV	CL,SAVE_COLUMN	;keep the saved cursor offset
		XOR	CH,CH
		MOV	BP,CX		;keep the saved cursor position
		ADD	CL,LEFT_MARGIN	;shift into visible window
		ADC	CH,0
		XOR	DL,DL
		MOV	CURS_POSN,DX	;get cursor row/column
		JCXZ	NO_CHANGE
RIGHT_AGAIN:
		PUSH	CX
		;-----------------------
		; (JEG)
		INC	SI
		CMP	SI,LAST_CHAR	;at end of file?
		DEC	SI
		JAE	DO_MOVE
		CMP	WORD PTR [SI],CRLF ;at end of line?
		;-----------------------
		JE	DONT_MOVE	;if at end, stop moving
DO_MOVE:
		CALL	RIGHT		;move right one character
DONT_MOVE:
		POP	CX

		MOV	AL,SAVE_COLUMN
		XOR	AH,AH
		CMP	AX,CX		;is cursor still in margin?
		JL	IN_MARGIN	;if yes, keep moving

		MOV	DX,CURS_POSN	;get cursor column again
		XOR	DH,DH
		CMP	DX,BP		;at saved cursor position?
		JE	RIGHT_DONE	;if yes, we're done
		JA	RIGHT_TOO_FAR	;did we go too far?
IN_MARGIN:
		LOOP	RIGHT_AGAIN
RIGHT_DONE:
		MOV	CX,BP
		MOV	SAVE_COLUMN,CL	;get back saved cursor position
NO_CHANGE:
		RET
		;-----------------------
RIGHT_TOO_FAR:
		CALL	LEFT		;move back left one place
		MOV	CX,BP
		MOV	SAVE_COLUMN,CL	;get back saved cursor position
		RET
SHIFT_RIGHT	ENDP

;=======================================================================
; This routine finds the beginning of the previous line.
;-----------------------------------------------------------------------
FIND_PREVIOUS	PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		PUSH	CURSOR		;save the cursor location
		CALL	FIND_CR		;find the start of this line
		MOV	CURSOR,SI	;save the new cursor
		CALL	FIND_START	;find the start of this line
		POP	CURSOR		;get back starting cursor
		RET
FIND_PREVIOUS	ENDP

;=======================================================================
; This routine searches for the previous carriage return.  
; Search starts at DS:SI.
;-----------------------------------------------------------------------
FIND_CR		PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		PUSH	CX
		MOV	AL,LF		;look for a line feed character
		MOV	DI,SI
		MOV	CX,SI
		JCXZ	AT_BEGINNING
		DEC	DI
		STD			;search backwards
LF_PREV:
		REPNE	SCASB		;scan for the character
		JCXZ	LF_END
		CMP	BYTE PTR [DI],CR
		JNE	LF_PREV
		DEC	DI
LF_END:
		;-----------------------
		CLD			;restore the direction flag
		INC	DI
		MOV	SI,DI
AT_BEGINNING:
		POP	CX
		RET
FIND_CR		ENDP

;=======================================================================
; This routine skips past the CR and LF at SI.  SI returns new offset.
;-----------------------------------------------------------------------
SKIP_CR_LF	PROC	NEAR
	;	ASSUME	CS:FILE_SEG
		CMP	SI,LAST_CHAR	;at last char in file?
		JAE	NO_SKIP		;if yes, don't skip anything
		CMP	BYTE PTR [SI],CR ;is first character a CR?
		JNE	NO_SKIP
		INC	SI		;look at next character
		CMP	SI,LAST_CHAR	;is it at the end of file?
		JAE	NO_SKIP		;if yes, don't skip anymore
		CMP	BYTE PTR [SI],LF ;is next character a line feed?
		JNE	NO_SKIP		;skip any line feeds also
		INC	SI
NO_SKIP:
		RET
SKIP_CR_LF	ENDP

;=======================================================================
; This routine computes the location of the start of current line.  
; Returns SI pointing to the first character of the current line.  
;-----------------------------------------------------------------------
FIND_START	PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		MOV	SI,CURSOR	;get the current cursor
		OR	SI,SI		;at start of file?
		JZ	AT_START	;if yse, we're done
		CALL	FIND_CR		;find the CR
		CALL	SKIP_CR_LF
AT_START:
		RET
FIND_START	ENDP

;=======================================================================
; This routine finds the offset of the start of the next line.  The search 
; is started at location of ES:SI.  On return, CF=1 if no CR was found.
;-----------------------------------------------------------------------
FIND_NEXT	PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		PUSH	CX
		CALL	FIND_EOL	;find the end of this line
		JC	AT_NEXT		;if at end of file, return
		CALL	SKIP_CR_LF	;skip past CR and LF
		CLC			;indicate end of line found
AT_NEXT:
		POP	CX
		RET
FIND_NEXT	ENDP

;=======================================================================
; This routine searches for the next carriage return in the file.  
; The search starts at the offset in register SI.  
;-----------------------------------------------------------------------
FIND_EOL	PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		MOV	AL,CR		;look for a carriage return
CR_SCAN:
		MOV	CX,LAST_CHAR	;last letter in the file
		SUB	CX,SI		;count for the search
		MOV	DI,SI
		JCXZ	AT_END		;if nothing to search, return
		REPNE	SCASB		;scan for the character
		MOV	SI,DI		;return the location of the CR
		JCXZ	AT_END		;if not found, return
		CMP	BYTE PTR [SI],LF
		JNE	CR_SCAN
		;-----------------------
		DEC	SI		;back up one, to CR character
		CLC			;indicate the CR was found
		RET
AT_END:
		STC			;indicate CR was not found
		RET
FIND_EOL	ENDP

;=======================================================================
; This routine positions the screen with the cursor at the row 
; selected in register DH.  On entry, SI holds the cursor offset.
;-----------------------------------------------------------------------
LOCATE		PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		MOV	CL,DH
		XOR	CH,CH
		MOV	CURSOR,SI
		XOR	DX,DX		;start at top of screen
		OR	SI,SI		;at start of buffer?
		JZ	LOCATE_FIRST

		CALL	FIND_START	;get start of this row
		XOR	DX,DX		;start at top of screen
		OR	SI,SI		;is cursor at top of file?
		JZ	LOCATE_FIRST
		JCXZ	LOCATE_FIRST	;if location to top row were done
FIND_TOP:
		PUSH	SI
		PUSH	CX
		CALL	FIND_CR		;find previous row
		POP	CX
		POP	AX
		CMP	WORD PTR [SI],CRLF
		JNE	LOCATE_FIRST
		CMP	SI,AX		;did it change?
		JE	LOCATE_DONE	;if not, quit moving
		INC	DH		;cursor moves to next row
		LOOP	FIND_TOP

LOCATE_DONE:
		PUSH	CURSOR
		MOV	CURSOR,SI
		CALL	FIND_START	;find start at top of screen
		POP	CURSOR
LOCATE_FIRST:
		MOV	TOP_OF_SCREEN,SI
		MOV	CURS_POSN,DX
		CALL	CURSOR_COL
		MOV	SAVE_COLUMN,DL
		RET
LOCATE		ENDP

;=======================================================================
; This routine computes the correct column for the cursor.  No inputs.  
; On exit, CURS_POSN is set and DX has row/column.
;-----------------------------------------------------------------------
CURSOR_COL	PROC	NEAR
	;	ASSUME	DS:FILE_SEG
		MOV	SI,CURSOR	;get cursor offset
		CALL	FIND_START	;find start of this line
		MOV	CX,CURSOR	;cursor location in file
		SUB	CX,SI
		MOV	DX,CURS_POSN	;get current row
		XOR	DL,DL		;start at column zero
		MOV	MARGIN_COUNT,DL	;count past the left margin
		JCXZ	COL_DONE
CURSOR_LOOP:
		LODSB			;get the next character
		INC	SI
		CMP	SI,LAST_CHAR
		DEC	SI
		JAE	NOT_EOL		;is <CR> without <LF>, at end of file

		CMP	WORD PTR [SI-1],CRLF ;(JEG)
		JE	COL_DONE	;if at end, we're done
NOT_EOL:
		CMP	AL,TAB		;is it a tab?
		JNE	NOT_A_TAB

		MOV	BL,MARGIN_COUNT
		OR	BL,00000111B
		MOV	MARGIN_COUNT,BL
		CMP	BL,LEFT_MARGIN	;inside visible window yet?
		JB	NOT_A_TAB	;if not, don't advance cursor
		OR	DL,00000111B	;move to multiple of eight
NOT_A_TAB:
		MOV	BL,MARGIN_COUNT
		INC	BL
		MOV	MARGIN_COUNT,BL
		CMP	BL,LEFT_MARGIN
		JBE	OUT_OF_WINDOW
		INC	DL		;we're at next column now
OUT_OF_WINDOW:
		LOOP	CURSOR_LOOP
COL_DONE:
		CMP	DL,COLUMNSB	;past end of display?
		JB	COLUMN_OK	;if not, we're OK
		MOV	DL,COLUMNSB
		DEC	DL		;leave cursor at last column
COLUMN_OK:
		MOV	CURS_POSN,DX	;store at last column
		RET
CURSOR_COL	ENDP

;=======================================================================
; MARK, CUT, PASTE, PRINT services
;=======================================================================
; This routine toggles the mark state and resets the paste buffer pointers.
;-----------------------------------------------------------------------
MARK		PROC	NEAR
		XOR	AX,AX
		NOT	CS:MARK_MODE	;toggle the mode flag
		CMP	CS:MARK_MODE,AL	;turning mode ON?
		JNE	MARK_ON
		OR	CS:DIRTY_BITS,1	;need to redraw the screen
		MOV	CS:MARK_START,0FFFFH
		JMP	SHORT MARK_RET
		;-----------------------
MARK_ON:
		MOV	AX,CS:CURSOR	;get the cursor offset
		MOV	CS:MARK_START,AX	;start of marked range
MARK_RET:
		MOV	CS:MARK_END,AX	;end of marked range
		MOV	CS:MARK_HOME,AX	;center of marked range
		RET
MARK		ENDP

;=======================================================================
; This routine removes the marked text and places it in the paste buffer.
;-----------------------------------------------------------------------
CUT		PROC	NEAR
		CMP	CS:INSERT_MODE,1 ;in insert mode? (0=ovr,1=ins,2 or 3=RO)
		JA	NO_MARK		;jump if read-only file
		CMP	CS:MARK_MODE,0	;is the mark mode on?
		JE	NO_MARK		;if not, then do nothing
		MOV	CX,CS:MARK_END	;get end of mark region
		MOV	SI,CS:MARK_START ;get start of mark region
		SUB	CX,SI		;number of bytes selected
		MOV	PASTE_SIZE,CX
		XOR	DI,DI		;point to paste buffer

		PUSH	CX
		PUSH	ES
		MOV	ES,CS:PASTE_SEG	;set the paste buffer segment to ES
		REP	MOVSB		;deleted text to buffer, DS:SI to ES:DI
		POP	ES
		POP	AX

		MOV	CX,CS:LAST_CHAR
		SUB	CS:LAST_CHAR,AX	;shorten the file this much
		MOV	DI,CS:MARK_START
		MOV	SI,CS:MARK_END
		SUB	CX,SI
		JCXZ	NO_DELETE
		REP	MOVSB		;shorten the file, DS:SI to ES:DI
NO_DELETE:
		MOV	DX,CS:CURS_POSN
		MOV	SI,CS:MARK_START
		CALL	LOCATE		;adjust the screen position
		CALL	MARK		;this turns off select

		;-----------------------
		; see if we made a CR-LF pair by cutting the character(s) from
		; between a Ctrl-M and a Ctrl-J.  If so, open a new line.
		;-----------------------
		CALL	C_IF_NEW_CRLF

NO_MARK:
		RET
CUT		ENDP

;=======================================================================
; This routine copies the paste buffer into the file at the cursor location.
;-----------------------------------------------------------------------
PASTE		PROC	NEAR
		MOV	AX,PASTE_SIZE	;number of characters in buffer
		OR	AX,AX		;any there?
		JZ	NO_PASTE	;if not, nothing to paste

		MOV	SI,CURSOR	;get cursor location
		PUSH	AX
		PUSH	SI
		CALL	OPEN_SPACE	;make room for new characters
		POP	DI
		POP	CX
		JC	NO_PASTE	;if no room, just exit
		XOR	SI,SI		;point to start of paste buffer
		PUSH	DS
		MOV	DS,PASTE_SEG	;segment of paste buffer
		REP	MOVSB		;copy in the new characters
		POP	DS
		OR	DIRTY_BITS,1	;redraw the screen
		CALL	C_IF_NEW_CRLF

NO_PASTE:
		RET
PASTE		ENDP

;=======================================================================
; This routine prints an ASCII Form-Feed character.
;-----------------------------------------------------------------------
PRINT_FF	PROC	NEAR
		CALL	MARK		;toggle MARK "on"
		PUSH	DS
		PUSH	CS
		POP	DS		
		MOV	CX,1		;one character to print
		MOV	SI,OFFSET FF	;offset of last byte in paste buffer
		CALL	DO_FF_CHAR
		POP	DS
		RET

FF		DB	12		;the ASCII Form-Feed character
PRINT_FF	ENDP
;-----------------------------------------------------------------------
; This routine prints the marked text.  If printer fails, it is cancelled.
;-----------------------------------------------------------------------
PRINT		PROC	NEAR
		CMP	MARK_MODE,0	;is mark mode on?
		JE	PRINT_RET	;if not, nothing to print
		MOV	CX,MARK_END	;end of marked region
		MOV	SI,MARK_START	;start of marked region
		SUB	CX,SI		;number of bytes selected
		JCXZ	PRINT_DONE	;if nothing to print, return
DO_FF_CHAR:
		XOR	DX,DX		;select printer 0
		MOV	AH,2
		INT	17H		;get printer status
		TEST	AH,10000000B	;is busy bit set?
		JZ	PRINT_DONE
		TEST	AH,00100000B	;is printer out of paper?
		JNZ	PRINT_DONE
PRINT_LOOP:
		LODSB
		XOR	AH,AH
		INT	17H		;print the character
		ROR	AH,1		;check the time out bit
		JC	PRINT_DONE	;if set, quit printing
		LOOP	PRINT_LOOP
		MOV	AL,CR
;------ [typographical error in article]
;**nop!		XOR	AH,0		;[would be No-Operation]
		XOR	AH,AH
;------
		INT	17H		;finish with a CR
PRINT_DONE:
		CALL	MARK		;turn off the mark status
PRINT_RET:
		RET
PRINT		ENDP

;=======================================================================
; CHARACTER STRING SEARCH and SEARCH AGAIN services; HELP screen
;=======================================================================
FIND_STR	PROC	NEAR
		PUSH	DS
		MOV	BX,CS
		MOV	DS,BX
		ASSUME	DS:CSEG
;---------------------------------------
;** now ShftF6	CMP	AH,66H		;Is it shift F9
		CMP	AH,89		;Is it shift-F6 (JEG)
;---------------------------------------
		JE	RPT_FIND
		MOV	DH,ROWS
		INC	DH		;Last row on the screen
		XOR	DL,DL		;First column
		MOV	SI,OFFSET SRCH_PROMPT
		CALL	TTY_STRING	;Display search prompt
		MOV	DX, OFFSET SRCH_MAX
		MOV	AH,0AH
		INT	21H		;Read input string
RPT_FIND:
		XOR	DX,DX
		MOV	DL,BYTE PTR SRCH_SIZ
		ADD	DX,OFFSET SRCH_STR
		MOV	DI,DX
		DEC	DI
		MOV	SRCH_END,DI
		XOR	DX,DX
		MOV	SI,CURSOR
		INC	SI
		MOV	SRCH_BASE,SI
S_REDO:
		MOV	DI,OFFSET SRCH_STR
		MOV	BX,SRCH_BASE
S_CYCLE:	MOV	AL,[DI]
		MOV	AH,AL		;CONVERT AL TO OPPOSITE AND PUT IN AH
		CMP	AL,'A'
		JB	S_CMP
		CMP	AL,'Z'
		JA	TSTLO
		XOR	AH,20H		;toggle letter case
		JMP	SHORT S_CMP
TSTLO:		CMP	AL,'a'
		JB	S_CMP
		CMP	AL,'z'
		JA	S_CMP
		XOR	AH,20H		;toggle letter case
S_CMP:		CMP	BX,LAST_CHAR
		JA	END_MCH
		CMP	AL,ES:[BX]
		JE	S_MCH
		CMP	AH,ES:[BX]
		JE	S_MCH
		CMP	DI,OFFSET SRCH_STR
		JNE	S_REDO
		INC	BX
		CMP	WORD PTR ES:[BX-1],CRLF ;test for EOL marker
		JNE	S_BX1
		INC	DL
S_BX1:		JMP	SHORT S_CMP
		
S_MCH:		INC	BX
		CMP	DI,OFFSET SRCH_STR
		JNE	NO_BSE
		MOV	SRCH_BASE,BX
NO_BSE:		ADD	DH,DL
		XOR	DL,DL
		CMP	DI,SRCH_END
		JE	YEA_MCH
		INC	DI
		JMP	SHORT S_CYCLE
YEA_MCH:	
		MOV	SRCH_FLG,1
		MOV	SI,SRCH_BASE
		DEC	SI
		MOV	SRCH_BASE,SI
		MOV	CURSOR,SI
		XOR	BX,BX
		MOV	BL,BYTE PTR SRCH_SIZ
		ADD	BX,SI
		MOV	SRCH_END,BX
		XOR	DL,DL
		ADD	DX,CURS_POSN
		CMP	DH,ROWS
		JBE	NEW_S
		XOR	DX,DX
NEW_S:
		POP	DS		;ASSUME is no longer valid
		CALL	LOCATE
                JMP     SHORT END_MCH2
END_MCH:                
		POP	DS
END_MCH2:
                CALL    REDO_PROMPT     ;redraw the prompt and the screen
		RET
FIND_STR	ENDP

;=======================================================================
; This routine displays a user help screen
;-----------------------------------------------------------------------
HELP		PROC	NEAR
		PUSH	DS
		PUSH	CS
		POP	DS
		ASSUME	DS:CSEG		;for func-9, display message
		CALL	CLR_SCREEN

		MOV	DX,OFFSET HELP_SCREEN	;message is at DS:DX in CSEG
		MOV	AH,9		;display message
		INT	21H
HELP_WAIT_KEY:
		MOV	AH,1		;wait for any key pressed
		INT	16H
		JZ	HELP_WAIT_KEY
		MOV	AH,0
		INT	16H

		POP	DS
		ASSUME	DS:NOTHING
		JMP	REDO_PROMPT	;redraw the prompt and the screen
		;(CALL/RETurn)
HELP		ENDP

;=======================================================================
; This routine prompts for a filename then writes the file.  The original 
; file is renamed to filename.BAK.  If an invalid filename is entered, the 
; speaker is beeped.  If the file has not been altered, the edit file is 
; abandoned and control is immediately returned to DOS.  
;-----------------------------------------------------------------------
EXIT		PROC	NEAR
		PUSH	DS		;save in case ESC key
		PUSH	ES
		MOV	AX,CS
		MOV	DS,AX
		MOV	ES,AX
		ASSUME	DS:CSEG, ES:CSEG
		TEST	BYTE PTR DIRTY_FILE,0FFH ;is the file altered?
		JNZ	NEXT_LETTER	;(jump was out of range)
		JMP	FINISHED	;file has not been altered, no save.
		;-----------------------
IS_BACKSPACE:
		CMP	DI,NAME_POINTER	;at first letter?
		JLE	NEXT_LETTER	;if yes, don't erase it
		MOV	BYTE PTR [DI-1],0
		DEC	NAME_END

NEXT_LETTER:
		MOV	DH,ROWS
		INC	DH		;last row on the screen
		XOR	DL,DL		;first column
		MOV	SI,OFFSET SAVE_MESS
		PUSH	DX
		CALL	TTY_STRING	;display a prompt
		POP	DX
		ADD	DL,9		;move right 9 spaces
		MOV	SI,NAME_POINTER
		CALL	TTY_STRING	;display the filename

		XOR	AH,AH		;read the next key
		INT	16H
		MOV	DI,NAME_END	;this points to the last letter
		OR	AL,AL		;is it a real character?
;		JZ	NEXT_LETTER	;ignore special keys
		JZ	IS_ESCAPE	;special keys return to edit mode
		CMP	AL,1BH		;is it ESCape?
		JE	IS_ESCAPE	;continue with exit procedure
		CMP	AL,CR		;is it CR?
		JE	GOT_NAME
		CMP	AL,08H		;is it a backspace?
		JE	IS_BACKSPACE
		CMP	DI,81H + 65	;too many letters?
		JG	NEXT_LETTER	;if yes, ignore them
		XOR	AH,AH		;for new terminal 0 to string
		STOSW			;store the new letter and 0
		INC	NAME_END	;name is one character longer
		JMP	NEXT_LETTER	;read another keystroke
		;-----------------------
IS_ESCAPE:
		POP	ES		;get back file segment
		POP	DS
		JMP	REDO_PROMPT	;redraw the prompt and the screen
		;(CALL/RETurn)		;return to edit mode
		;-----------------------
GOT_NAME:
		MOV	DX,NAME_POINTER	;point to the filename
		MOV	AX,4300H	;get the file attribute
		INT	21H		;DOS call
		JNC	NAME_OK		;if no error, filename is OK
		CMP	AX,3		;was it "path not found" error?
		JE	BAD_NAME	;if yes, filename was bad
NAME_OK:
		MOV	SI,OFFSET DOT_$$$	;point to the ".$$$"
		MOV	DI,OFFSET NAME_DOT_$$$
		CALL	CHG_EXTENSION		;add the new extension

		MOV	DX,OFFSET NAME_DOT_$$$	;point to temp filename
		MOV	CX,0020H		;attribute for new file
		MOV	AH,3CH			;function to create file
		INT	21H			;DOS call
		JNC	NAME_WAS_OK		;continue if name was OK
BAD_NAME:
		MOV	AX,0E07H	;write a bell character
		INT	10H		;BIOS TTY service
		JMP	NEXT_LETTER	;get another letter
		;-----------------------
WRITE_ERROR:
		MOV	AH,3EH		;close the file
		INT	21H		;DOS call
		JMP	BAD_NAME	;filename must be bad
		;-----------------------
NAME_WAS_OK:
		XOR	DX,DX		;this is the file buffer
		MOV	CX,LAST_CHAR	;number of chars in file
		MOV	BX,AX		;this is the handle
		MOV	AH,40H		;write to the file
		POP	DS		;recover the buffer segment
		INT	21H		;write the buffer contents
		POP	DS
		JC	WRITE_ERROR	;exit on a write error
		CMP	AX,CX		;was entire file written?
		JNE	WRITE_ERROR	;if not, exit

		PUSH	CS
		POP	DS			;get the code segment
		MOV	AH,3EH			;close the temp file
		INT	21H			;DOS call
		MOV	SI,OFFSET DOT_BAK	;point to the ".BAK"
		MOV	DI,OFFSET NAME_DOT_BAK
		CALL	CHG_EXTENSION		;make the backup filename

		MOV	DX,OFFSET NAME_DOT_BAK	;point to the backup name
		MOV	AH,41H			;delete existing backup file
		INT	21H			;DOS call
		MOV	DI,OFFSET NAME_DOT_BAK
		MOV	DX,NAME_POINTER
		MOV	AH,56H
		INT	21H			;DOS call

		MOV	DI,NAME_POINTER	;point to new filename
		MOV	DX,OFFSET NAME_DOT_$$$ ;point to temporary file
		MOV	AH,56H		;rename temp to new file
		INT	21H		;DOS call, rename
		POP	AX		;restore the stack
		POP	AX
		JMP	SHORT FINISHED
		;(To return to DOS)
EXIT		ENDP

;-----------------------------------------------------------------------
; This routine prompts for a verify keystroke then exits without saving 
; the file.  If the file has not been altered, the edit file is abandoned 
; and control is immediately returned to DOS.  
;-----------------------------------------------------------------------
ABORT		PROC	NEAR
		PUSH	CS
		POP	DS
		ASSUME	DS:CSEG
		TEST	BYTE PTR DIRTY_FILE,0FFH ;is the file altered?
		JZ	FINISHED	;file has not been altered.

		MOV	DH,ROWS		;last row on display
		INC	DH		;bottom row on screen
		XOR	DL,DL		;first column
		MOV	SI,OFFSET VERIFY_MESS
		CALL	TTY_STRING	;display verify message

		XOR	AH,AH		;read the next key
		INT	16H		;BIOS read key routine
		CMP	AL,CR		;is it CR?
		JE	FINISHED
		OR	AL,20H		;convert to lower case
		CMP	AL,"y"		;was answer Yes?
		JE	FINISHED	;if yes, then we're finished
		CALL	REDO_PROMPT	;redraw the prompt and the screen
		PUSH	ES
		POP	DS		;set DS back to file segment
		RET			;return to edit mode
		;-----------------------
FINISHED:
		MOV	DX,OFFSET COPYRIGHT
		;-----------------------
EXIT_TO_DOS:				;External entry point (DX, message)
		PUSH	CS
		POP	DS		;point to code segment
		ASSUME	DS:CSEG
		CALL	CLR_SCREEN	;clear the screen (passes DX through)
		MOV	AH,9		;display error/exit message DS:DX
		INT	21H		;DOS call
		MOV	AX,EXIT_CODE	;Exit to DOS with exit code
		INT	21H		;DOS call

ABORT		ENDP

;=======================================================================
; This routine copies the input filename to CS:DI and changes the extension.
;-----------------------------------------------------------------------
CHG_EXTENSION	PROC	NEAR
		ASSUME	DS:CSEG, ES:CSEG
		PUSH	SI
		MOV	SI,NAME_POINTER
CHG_LOOP:
		LODSB
		CMP	AL,"."		;look for the extension
		JE	FOUND_DOT
		OR	AL,AL
		JZ	FOUND_DOT
		STOSB			;copy a character
		JMP	CHG_LOOP
		;-----------------------
FOUND_DOT:
		MOV	CX,5		;five characters in extension
		POP	SI
		REP	MOVSB		;move new extension in
		RET
CHG_EXTENSION	ENDP

;=======================================================================
; This routine displays the string at CS:SI at the location in DX.  The 
; remainder of the row is erased.  Cursor is put at the end of the line.
;-----------------------------------------------------------------------
TTY_STRING	PROC	NEAR
		ASSUME	DS:CSEG
		PUSH	DX
		CALL	POSITION	;compute offset into video
		POP	DX
TTY_LOOP:
		LODSB			;load DS:SI to AL
		OR	AL,AL		;at end of string yet?
		JZ	TTY_DONE
		INC	DL
		PUSH	DX
		CALL	WRITE_INVERSE	;write in inverse video
		POP	DX
		JMP	TTY_LOOP
		;-----------------------
TTY_DONE:
		CALL	SET_CURSOR	;move cursor to end of string
		JMP	ERASE_EOL	;erase the rest of the line
		;(CALL/RETurn)
TTY_STRING	ENDP

;=======================================================================
; This routine clears the screen, leaves registers unaltered.
;-----------------------------------------------------------------------
CLR_SCREEN	PROC	NEAR
		ASSUME	DS:NOTHING
		PUSH	AX		;save registers (for INT-24)
		PUSH	BX
		PUSH	CX
		PUSH	DX		;save DX for message address
	 	MOV	DL,79		;DL = right column
		MOV	DH,CS:ROWS	;DH = lower row
		INC	DH		;to clear the last line on the screen
		MOV	CX,0		;CH = upper row, CL = left column
		MOV	BH,CS:NORMAL	;BH is blank line attribute, 07 = normal video
		MOV	AX,0600H	;scroll the cursor up (blank line)
		INT	10H
		XOR	DX,DX		;set cursor to top left of screen
		CALL	SET_CURSOR
		POP	DX
		POP	CX
		POP	BX
		POP	AX
		RET
CLR_SCREEN	ENDP

;=======================================================================
; This is the control break handler for MS-DOS.  It ignores the break.
; Then responds by entering a <Ctrl-C> in the file.
;-----------------------------------------------------------------------
NEWINT23	PROC	FAR
		ASSUME	DS:NOTHING, ES:NOTHING
		MOV	CS:DIRTY_BITS,1	;to redraw the screen
		CLC			;tell DOS to ignore break
		IRET
NEWINT23	ENDP

;=======================================================================
; This is the severe error handler.  It homes the cursor before 
; processing the error.
;-----------------------------------------------------------------------
NEWINT24	PROC	FAR
		ASSUME	DS:NOTHING, ES:NOTHING
		PUSHF
		CALL	CLR_SCREEN	;clear the screen and home the cursor
		POPF
		JMP	CS:OLDINT24
		;(chain to old INT 24 handler)
NEWINT24	ENDP

;=======================================================================
; This is the location of the character string search buffer.  It occupies 
; the last three bytes in the program file.  The following 64-bytes are used 
; for the buffer area.  The third byte is also used as the program code 
; check-sum compensation byte.
;-----------------------------------------------------------------------
		EVEN
SRCH_MAX	DB	66		;42H, maximum size of buffer
SRCH_SIZ	DB	0		;number of char's actually in buffer
SRCH_STR	DB	0		;start of buffer block

		;This is the correction byte for the check-sum test
CHEK_SUM_BYT    DB      0103

;=======================================================================

NAME_DOT_$$$	EQU	$ +64		;128 bytes
NAME_DOT_BAK	EQU	$+80H +64	;128 bytes
UNDO_BUFFER	EQU	$+100H +64	;256 bytes, Del key buffer
LINE_BUFFER	EQU	$+200H +64	;256 bytes, Delete line, EOL

END_BUFFER	EQU	$+300H +64 +15	;end of buffers, file segment follows
					; +15 is for paragraph rounding


CSEG	ENDS

;-----------------------------------------------------------------------

FILE_SEG	SEGMENT
FILE_SEG	ENDS

END		START