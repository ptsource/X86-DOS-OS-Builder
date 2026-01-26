;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************
;  Usage:   XDIR [d:][directory]
 
CODE SEGMENT
ASSUME CS:CODE,DS:CODE
ORG 100H

START:         JMP    BEGINNING

 
;              DATA AREA
;              ---------

FIELD_SIZE     EQU    44
BAR_START      EQU    323
COPY_MARK      EQU    26
FCB            EQU    5CH
 
CURRENT_DISK   DB  ?
STATUS_REG     DW  ?
VIDEO_SEG      DW  0B000H
NORMAL         DB  07H
INVERSE        DB  70H
BAR_ATTRIBUTE  DB  70H
CURSOR_TYPE    DW  ?
CUR_VERIFY     DB  0
 
SORT_OFFSET    DW  0
SORT_TABLE     DW  0,12,9,3,13,8,29
SORT_FLAG      DB  0
SEARCH_ATTRIB  DW  17H
CUR_OFFSET     DW  BUFFER
CUR_FILE       DW  ?
END_OFFSET     DW  ?
PAGE_END       DW  21 * 160 + BAR_START
COUNT          DW  0
FILE_CNT       DW  0
LINE           DW  BAR_START
SEARCH_COUNT   DW  ?
 
MARK_CNT       DW     0
FILENAME_END   DW     ?
PURGE_DISK     DB     ?
READ_HANDLE    DW     ?
WRITE_HANDLE   DW     ?
SOURCE_ATTRIB  DW     ?
TARGET_ATTRIB  DW     ?
SIZE_LOW       DW     ?
SIZE_HIGH      DW     ?
SOURCE_TIME    DW     ?
SOURCE_DATE    DW     ?
FILE_NAME      DW     ?
COPY_FLAG      DB     0
DELETE_FLAG    DB     0
RENAME_FLAG    DB     0
VERIFY_FLAG    DB     0
 
DISPATCH_KEY   DB  1,3BH,3CH,3DH,3EH,3FH,40H,4AH,4EH,12H,14H,1FH,20H,2EH,2FH
               DB  31H,32H,41H,42H,43H,44H,47H,48H,49H,4FH,50H,51H,76H,84H
DISPATCH_CNT   EQU $ - DISPATCH_KEY
 
DISPATCH_TABLE DW  EXIT, COPY, DELETE, MOVE, CLEAR_MARK, MARK_BLANK, VERIFY
               DW  UNMARK, MARK, SORT_EXT, SORT_DATE, SORT_SIZE, DELETE
               DW  COPY, VERIFY, SORT_NAME, MOVE, SORT_NAME, SORT_EXT
               DW  SORT_SIZE, SORT_DATE, HOME_BAR, UP_ARROW, PG_UP
               DW  END_BAR, DN_ARROW, PG_DN, BOTTOM_BAR, TOP_BAR
DISPATCH_END   EQU $ - 2
 
NOT_ENOUGH     DB  "Requires 128K free RAM$"
INVALID        DB  "Invalid directory$"
TOO_MANY       DB  "Too many files$"
LOADING        DB  "Loading and Sorting directory.",0
LOAD_ONLY      DB  "Loading directory.",0
DIRECTORY      DB  "Directory of ",0
FILES          DB  4 DUP(32),"File(s)",11 DUP(32),"bytes free",0
DELETE_MSG     DB  " will be deleted.",0,"Do you wish to delete?  Y/N",0
BS             DB  8,32,8,0
DISK_MSG       DB  "Error reading drive ",0
               DB  "(R)etry or (Q)uit",0
MARKED_MSG     DB  " marked files",0
COPY_MSG       DB  "Copy ",0
MOVE_MSG       DB  "Move ",0
TO_MSG         DB  " to...",0
STAR_DOT_STAR  DB  "*.*",0
ON             DB  " ON",0
OFF            DB  "OFF",0
DIRECTORIES    DB  "<DIR>"
 
MENU  LABEL  BYTE
DB  201,20 DUP (205),187,186,"      DOSSTRAP      ",186
DB  186,"www.wiki.ptsource.eu",186,186,"       [2026]       ",186
DB  199,20 DUP (196),182,          186," F1   Copy          ",186
DB  186," F2   Delete        ",186,186," F3   Move          ",186
DB  186," F4   Clear marks   ",186,186," F5   Mark blank    ",186
DB  186," F6   Verify   OFF  ",186,186," F7   Sort by Name  ",186
DB  186," F8   Sort by Ext.  ",186,186," F9   Sort by Size  ",186
DB  186," F10  Sort by DaTe  ",186,186," +/-  Mark/Unmark   ",186
DB  186," Esc  to Exit       ",186,200,20 DUP (205),188
DB  "  Use: ",24,32,25," PgUp PgDn"
DB  "   ^PgUp ^PgDn Home End "
 
;----------------------------------------------------------------------------;
; Some housekeeping first. Since we will be changing the default drive       ;
; and directory to the requested drive and directory, we need to save the    ;
; current defaults, so they can be restored.  Install critical error trap.   ;
;----------------------------------------------------------------------------;
 
;              CODE AREA
;              ---------
BEGINNING:     MOV    AX,3301H               ;Turn Control Break off.
               MOV    DL,0
               INT    21H
 
               MOV    AH,54H                 ;Get current verify flag.
               INT    21H
               MOV    CUR_VERIFY,AL          ; and save.
               XOR    AL,AL
               CALL   SET_VERIFY             ;Turn verify off.
 
               MOV    DX,OFFSET DISK_ERROR   ;Install critical error trap.
               MOV    AX,2524H
               INT    21H
 
               CLD                           ;String moves forward.
               CALL   GET_DRIVE              ;Get current drive.
               MOV    CURRENT_DISK,AL        ;Save.
               MOV    SI,OFFSET CURRENT_DIR  ;Get current directory.
               CALL   GET_DIR
 
;---------------------------------------------------------------------;
; More housekeeping. We will be writing directly to the screen buffer ;
; so we need the display card address and the status register.        ;
;---------------------------------------------------------------------;
 
DISPLAY:       MOV    AX,40H           ;Point to the ROM BIOS data area
               MOV    DS,AX            ; and get base address of active
               MOV    AX,DS:[63H]      ; display card.
               ADD    AX,6             ;Add six to get status register
               PUSH   CS               ;Done there, so restore data segment.
               POP    DS
               MOV    STATUS_REG,AX    ;Store status register.
               CMP    AX,3BAH          ;Status port of MONO card is 3BAh.
               JZ     MONO             ;If that's what we got, it's MONO
               MOV    VIDEO_SEG,0B800H       ; else COLOR so add 800h.
               XOR    BH,BH                  ;Get current attribute
               MOV    AH,8                   ; of display page zero.
               INT    10H
               MOV    NORMAL,AH              ;Store it.
               XOR    AH,1110111B            ;Flip color bits.
               MOV    INVERSE,AH             ;Save it.
               MOV    BAR_ATTRIBUTE,AH
MONO:          XOR    BH,BH
               MOV    AH,3                   ;Retrieve cursor type.
               INT    10H
               MOV    CURSOR_TYPE,CX
 
               MOV    AH,49H                 ;Return our memory segment.
               INT    21H
               MOV    BX,2000H               ;Request 128K.
               MOV    AH,4AH
               INT    21H
               MOV    DX,OFFSET NOT_ENOUGH
               JNC    PARSE
               JMP    ERROR_EXIT             ;If not available, exit.
 
;----------------------------------------;
; Parse the command line for parameters. ;
;----------------------------------------;
 
PARSE:         MOV    SI,81H                 ;Point to first character.
               CMP    BYTE PTR DS:[80H],0    ;Any parameters?
               JNZ    NEXT_SWITCH
               JMP    GET_WORKING            ;If no, skip.
 
NEXT_SWITCH:   LODSB                         ;Get a byte.
               CMP    AL,13                  ;Carriage return?
               JZ     GET_PARA               ;If yes, done here.
               CMP    AL,"/"                 ;Is it switch character?
               JNZ    NEXT_SWITCH            ;If no, get next character.
               LODSB                         ;Get switch character.
               AND    AL,5FH                 ;Capitalize.
               CMP    AL,"R"                 ;If "R", remove directories.
               JNZ    CK_EXT
               MOV    SEARCH_ATTRIB,7
CK_EXT:        CMP    AL,"E"                 ;If "E", sort by extension.
               JNZ    CK_SIZE
               MOV    SORT_OFFSET,4
CK_SIZE:       CMP    AL,"S"                 ;If "S", sort by size.
               JNZ    CK_DATE
               MOV    SORT_OFFSET,8
CK_DATE:       CMP    AL,"D"                 ;If "D", sort by date.
               JZ     GOT_DATE
               CMP    AL,"T"                 ;If "T", sort by date.
               JNZ    CK_ORIGINAL
GOT_DATE:      MOV    SORT_OFFSET,12
 
CK_ORIGINAL:   CMP    AL,"O"                 ;If "O", don't sort at all.
               JNZ    NEXT_SWITCH
               MOV    SORT_FLAG,1
               JMP    SHORT NEXT_SWITCH
 
GET_PARA:      XOR    BL,BL                  ;Assume no drive request.
               MOV    SI,81H                 ;Point to first character.
NEXT_PARSE:    LODSB
               CMP    AL,13                  ;Carriage return or slash?
               JZ     GET_WORKING            ;If yes, done here.
               CMP    AL,"/"
               JZ     GET_WORKING
               CMP    AL,32                  ;Leading space?
               JBE    NEXT_PARSE             ;If yes, get next byte.
 
               MOV    BP,SI                  ;Save start.
NEXT_PARA:     LODSB
               CMP    AL,32                  ;End of parameter?
               JBE    END_PARA               ;If yes, done here.
               CMP    AL,"/"
               JZ     END_PARA
               CMP    AL,":"                 ;Drive request?
               JNZ    NEXT_PARA              ;If no, get next byte.
               MOV    DL,BYTE PTR [SI-2]     ;Else, retrieve request.
               AND    DL,5FH                 ;Capitalize.
               SUB    DL,"A"                 ;Convert to DOS format.
               CALL   CHANGE_DRIVE           ;And change drive.
               JMP    SHORT NEXT_PARA        ;Find end of parameter.
 
END_PARA:      MOV    BYTE PTR DS:[SI-1],0   ;Convert parameter to ASCIIZ.
               MOV    BL,BYTE PTR DS:[SI-2]
GET_WORKING:   MOV    SI,OFFSET WORKING_DIR  ;Store working drive directory.
               CALL   GET_DIR
               CMP    BL,":"                 ;Is there a drive request?
               JZ     MESSAGE                ;If yes, skip directory change.
               CMP    BL,32                  ;Is it a delimiter?
               JBE    MESSAGE                ;If yes, skip.
               MOV    DX,BP                  ;Retrieve start.
               DEC    DX                     ;Adjust.
               CALL   CHANGE_DIR             ;Change directory.
               MOV    DX,OFFSET INVALID
               JC     ERROR_EXIT             ;If error, exit.
 
MESSAGE:       CALL   CLS                    ;Clear screen.
               CALL   CURSOR_OFF             ;Cursor off.
               MOV    SI,OFFSET LOADING      ;Display sorting message.
               MOV    DX,0C19H
               CMP    SORT_FLAG,1            ;Unless not sorted.
               JNZ    DISP_MSG
               MOV    SI,OFFSET LOAD_ONLY    ;Then display loading message.
               MOV    DX,0C1FH
DISP_MSG:      CALL   DISPLAY_TEXT
 
               MOV    DI,OFFSET BUFFER       ;Put space character
               MOV    CX,16000               ; in directory listing
               MOV    AX,2020H               ; buffer.
               REP    STOSW
 
;------------------------------------------------------------------;
; Read all the directory filenames and store as records in buffer. ;
;------------------------------------------------------------------;
 
READ_DIR:      MOV    DX,OFFSET STAR_DOT_STAR
               MOV    CX,SEARCH_ATTRIB
               CALL   FIND_FIRST             ;Find first matching file.
               JC     EXIT                   ;If empty directory, exit.
 
STORE_NAME:    MOV    DI,OFFSET BUFFER + 1   ;Point to buffer.
               MOV    BP,SP                  ;Reserve space for stack.
               SUB    BP,500
               CALL   BUFFER_NAME            ;Convert to directory format.
 
FIND_NEXT:     MOV    AH,4FH                 ;Find next matching.
               INT    21H
               JC     STORE_COUNT            ;If carry, no more names.
               CALL   BUFFER_NAME
               CMP    DI,BP                  ;Are we encroaching the stack?
               JBE    FIND_NEXT              ;If no, find next.
               MOV    DX,OFFSET TOO_MANY     ;Else, exit with message.
 
;-----------------------------------------------------------------------;
; This is the exit routine. Restore the defaults the way we found them. ;
;-----------------------------------------------------------------------;
 
ERROR_EXIT:    MOV    AH,9                   ;Display error message.
               INT    21H
               MOV    AL,1                   ;Error code of one.
               JMP    SHORT TERMINATE
 
EXIT:          CALL   CLS                    ;Clear screen.
               XOR    DX,DX                  ;Set cursor top left.
               CALL   SET_CURSOR
               CALL   CURSOR_ON              ;Turn cursor back on.
               XOR    AL,AL                  ;Error code of zero.
TERMINATE:     PUSH   AX
               MOV    AL,CUR_VERIFY          ;Restore verify state.
               CALL   SET_VERIFY
               MOV    DL,CURRENT_DISK        ;Restore drive.
               CALL   CHANGE_DRIVE
               POP    AX
               MOV    AH,4CH
               INT    21H
 
;-----------------------------------;
; Store buffer end address and page ;
; end then sort the filenames.      ;
;-----------------------------------;
 
STORE_COUNT:   DEC    DI
               MOV    END_OFFSET,DI          ;Store ending offset.
               MOV    BX,COUNT               ;Retrieve file count.
               CMP    BX,21                  ;Enough to fill one page?
               JAE    DO_SORT                ;If yes, use default setting.
               MOV    AX,160                 ;Calculate last record.
               MUL    BL
               ADD    AX,BAR_START           ;Add bar offset.
               MOV    PAGE_END,AX
DO_SORT:       CMP    SORT_FLAG,1            ;Should we sort or leave original?
               JZ     READY                  ;If it was "/O", don't sort.
               CALL   SORT
 
;------------------------------------------------------------------------;
; Now, we are ready to get target directory and display it and the menu. ;
;------------------------------------------------------------------------;
 
READY:         MOV    DI,OFFSET PURGE_DIR    ;Point to storage.
               CALL   GET_DRIVE              ;Get drive.
               MOV    PURGE_DISK,AL
               ADD    AL,"A"                 ;Convert to ASCII.
               STOSB
               MOV    AL,":"                 ;Add colon.
               STOSB
               MOV    SI,DI                  ;Get directory.
               CALL   GET_DIR
               MOV    SI,OFFSET PURGE_DIR    ;Make a carbon copy of
               MOV    DI,OFFSET SOURCE       ; directory.
CARBON_COPY:   MOVSB
               CMP    BYTE PTR [SI],0
               JNZ    CARBON_COPY
               MOV    AL,"\"                 ;Add "\" to end of path
               CMP    [DI-1],AL              ; if not root directory.
               JZ     STORE_END
               STOSB
STORE_END:     MOV    FILE_NAME,DI           ;Store end of path to tack
               CALL   UPDATE_FREE            ; on filename later on.
               MOV    DX,OFFSET WORKING_DIR  ;Restore the working directory.
               CALL   CHANGE_DIR
               MOV    DL,CURRENT_DISK        ;Restore to default drive
               CALL   CHANGE_DRIVE
               MOV    DX,OFFSET CURRENT_DIR  ; and default directory.
               CALL   CHANGE_DIR
               CALL   REFRESH_DIR            ;Display drive, directory, menu.
 
;-----------------------------------------;
; We are ready for business now. We will  ;
; loop here, waiting for user keystrokes. ;
;-----------------------------------------;
 
GET_KEY:       CALL   UPDATE_SCREEN
               CALL   READ_KEY               ;Get a keystroke.
               MOV    BX,AX                  ;Save returned key.
               CMP    AH,1                   ;Is it Esc or below?
               JBE    FUNCTION               ;If yes, function.
               CMP    AH,36H                 ;Is it right shift or above?
               JAE    FUNCTION               ;If yes, function.
               CMP    AH,1CH                 ;Is it CR?
               JZ     FUNCTION               ;If yes, function.
               MOV    AH,2                   ;Get shift state.
               INT    16H
               TEST   AL,4                   ;Is Ctrl depressed?
               JNZ    FUNCTION               ;If no, check function request.
               CALL   SEARCH                 ;Else, search for first letter.
               JMP    SHORT GET_KEY
FUNCTION:      MOV    DI,OFFSET DISPATCH_KEY
               MOV    AL,BH
               MOV    CX,DISPATCH_CNT        ;Valid commands.
               REPNZ  SCASB
               JNZ    GET_KEY                ;If no match, get another.
               MOV    DI,OFFSET DISPATCH_END
               SHL    CX,1
               SUB    DI,CX
               CALL   DS:[DI]                ;Else do subroutine.
               JMP    SHORT GET_KEY          ;Update screen; get next command.
 
               ;*************;
               ; SUBROUTINES ;
               ;*************;
 
;---------------------------------------------------------------;
; This subroutine copies either the highlighted or marked file. ;
;---------------------------------------------------------------;
 
COPY:          CALL   COUNT_MARKS            ;Count marks.
               CMP    CX,0                   ;Any marked files?
               JNZ    COPY_DEST              ;If yes, display "Copy" message.
               CALL   GET_NAME               ;Is the highlighted a directory?
               JC     COPY_ERROR             ;If yes, exit.
COPY_DEST:     MOV    DX,172FH
               MOV    SI,OFFSET COPY_MSG
               CALL   DISPLAY_TEXT
               CALL   DESTINATION            ;Ask user for destination.
               JC     END_COPY               ;If Esc pressed, exit.
               MOV    COPY_FLAG,1            ;Else, indicate copy.
               CALL   EXEC_MARKED            ;Execute the command.
               MOV    COPY_FLAG,0            ;Restore copy flag.
END_COPY:      RET
 
COPY_ERROR:    CALL   BEEP
               RET
 
;----------------------------------------------------------------;
; This subroutine deletes either the highlighted or marked file. ;
;----------------------------------------------------------------;
 
DELETE:        MOV    DX,172FH               ;Postion cursor for display.
               CALL   SET_CURSOR
               CALL   COUNT_MARKS            ;Get count of marked files.
               CMP    CX,0                   ;Any marked?
               JNZ    DELETE_MARKED          ;If marked, display number marked.
               CALL   GET_NAME               ;Else get highlighted.
               JC     DELETE_ERROR           ;If it's a directory exit.
               CMP    BYTE PTR [SI+39],"H"   ;If it's a hidden file exit.
               JZ     DELETE_ERROR
               MOV    SI,FILE_NAME           ;Else display filename.
               JMP    SHORT DISP_DELETE
 
DELETE_MARKED: MOV    AX,CX                  ;Display count of marked files.
               CALL   GET_COUNT
               MOV    SI,OFFSET MARKED_MSG   ;Display "marked files".
DISP_DELETE:   CALL   GET_TEXT
               MOV    SI,OFFSET DELETE_MSG   ;Display "will be deleted".
               CALL   GET_TEXT
               MOV    DX,182FH               ;Display warning message.
               CALL   DISPLAY_TEXT
 
QUERY:         CALL   READ_KEY               ;Get a keystroke.
               CMP    AH,31H                 ;Is it "N"?
               JZ     DELETE_END             ;If yes, exit delete.
               CMP    AH,1                   ;Is it Esc?
               JZ     DELETE_END             ;If yes, exit delete.
               CMP    AH,15H                 ;Is it "Y"?
               JZ     DELETE_FILE            ;If yes, delete
               CALL   BEEP                   ;Else, beep.
               JMP    SHORT QUERY            ;And get another keystroke.
 
DELETE_FILE:   MOV    DELETE_FLAG,1          ;Indicate deletion.
               CALL   EXEC_MARKED            ;Execute the command.
               MOV    DELETE_FLAG,0          ;Restore deletion flag.
DELETE_END:    CALL   CLEAR_MSG
               RET
 
DELETE_ERROR:  CALL   BEEP                   ;Beep if error.
               RET
 
;--------------------------------------------------------------;
; This subroutine moves either the highlighted or marked file. ;
;--------------------------------------------------------------;
 
MOVE:          CALL   COUNT_MARKS            ;Get count of marked files.
               CMP    CX,0                   ;Any files marked?
               JNZ    MOVE_DEST              ;If yes, display message.
               CALL   GET_NAME               ;Else, see if highlighted is a
               JC     MOVE_ERROR             ; directory; If yes, exit.
MOVE_DEST:     MOV    DX,172FH
               MOV    SI,OFFSET MOVE_MSG     ;Display move message.
               CALL   DISPLAY_TEXT
               CALL   DESTINATION            ;Get user response.
               JC     END_MOVE               ;If Esc pressed, exit.
               MOV    AL,CURRENT_DISK        ;Else, check if move across drives.
               ADD    AL,"A"                   ;Get default drive.
               CMP    BYTE PTR ENTRY + 1,":"   ;Is there a drive specified?
               JNZ    CK_DRIVE                 ;If not, use default.
               MOV    AL,ENTRY               ;Else, use user drive.
               AND    AL,5FH                 ;Capitalize.
CK_DRIVE:      CMP    AL,SOURCE              ;Is it the same as source?
               JZ     JUST_RENAME            ;If yes, rename.
COPY_DELETE:   MOV    COPY_FLAG,1            ;Else, indicate both copy/delete.
               MOV    DELETE_FLAG,1
JUST_RENAME:   MOV    RENAME_FLAG,1
EXEC_MOVE:     CALL   EXEC_MARKED            ;Execute the command.
               MOV    DELETE_FLAG,0          ;Restore all flags.
               MOV    COPY_FLAG,0
               MOV    RENAME_FLAG,0
END_MOVE:      RET
 
MOVE_ERROR:    CALL   BEEP
               RET
 
;-----------------------------------;
; This subroutine clears all marks. ;
;-----------------------------------;
 
CLEAR_MARK:    MOV    SI,OFFSET BUFFER       ;Point to start of listing.
NEXT_CLEAR:    MOV    BYTE PTR [SI],32       ;Write space over mark.
               ADD    SI,FIELD_SIZE          ;Next record.
               CMP    SI,END_OFFSET          ;End of listing?
               JB     NEXT_CLEAR             ;If no, continue until done.
               RET
 
;----------------------------------------------------------------------;
; This subroutine marks all files that aren't marked with an asterisk. ;
;----------------------------------------------------------------------;
 
MARK_BLANK:    MOV    SI,OFFSET BUFFER       ;Point to start of listing.
NEXT_BLANK:    CMP    BYTE PTR [SI+14],"<"   ;Is it a directory?
               JZ     LOOP_MARK              ;If yes, skip.
               CMP    BYTE PTR [SI+40],"H"   ;Is it a hidden file?
               JZ     LOOP_MARK              ;If yes, skip.
               CMP    BYTE PTR [SI],32       ;Is it blank (a space)?
               JNZ    LOOP_MARK                 ;If no, skip.
               MOV    BYTE PTR [SI],COPY_MARK   ;Else mark.
LOOP_MARK:     ADD    SI,FIELD_SIZE             ;Next record.
               CMP    SI,END_OFFSET          ;Continue until done.
               JB     NEXT_BLANK
               RET
 
;--------------------------------------------------------;
; This subroutine marks or unmarks the highlighted file. ;
;--------------------------------------------------------;
 
MARK:          MOV    DL,COPY_MARK           ;Right arrow character.
               JMP    SHORT STORE_MARK
 
UNMARK:        MOV    DL,32                  ;Space character.
 
STORE_MARK:    CALL   GET_NAME               ;Get filename.
               JC     MARK_END               ;If directory, skip.
               CMP    BYTE PTR [SI+39],"H"   ;Is it a hidden file?
               JZ     MARK_END               ;If yes, skip.
               MOV    [SI-1],DL              ;Else store the character.
MARK_END:      CALL   DN_ARROW               ;And move down a row.
               RET
 
;------------------------------------------------; 
; This subroutine toggles the copy verify state. ;
;------------------------------------------------;
 
VERIFY:        XOR    VERIFY_FLAG,1               ;Toggle flag.
               MOV    DI,OFFSET MENU+(10*22)+16   ;Point to menu.
               MOV    SI,OFFSET ON                ;Assume "ON".
               MOV    AL,1
               CMP    VERIFY_FLAG,1               ;Is it on?
               JZ     TOGGLE                      ;If yes, store.
               MOV    SI,OFFSET OFF               ;Else, store "OFF".
               XOR    AL,AL
 
TOGGLE:        MOV    CX,3
               REP    MOVSB
               CALL   SET_VERIFY
               CALL   REFRESH_MENU                ;Display.
               RET
 
;----------------------------------------------------;
; This subroutine counts the number of marked files. ;
;----------------------------------------------------;
 
COUNT_MARKS:   XOR    CX,CX                  ;Zero out counter.
               MOV    SI,OFFSET BUFFER          ;Point to start of listing.
NEXT_COPY:     CMP    BYTE PTR [SI],COPY_MARK   ;Is it marked?
               JNZ    LOOP_COPY                 ;In no, skip.
               INC    CX                     ;Else, increment counter.
LOOP_COPY:     ADD    SI,FIELD_SIZE          ;Next record.
               CMP    SI,END_OFFSET          ;Continue until done.
               JB     NEXT_COPY
               MOV    MARK_CNT,CX            ;Store the count of marked files.
               RET
 
;---------------------------------------------;
; This subroutine prompts the user for the    ;
; destination of highlighted or marked files. ;
;---------------------------------------------;
 
DESTINATION:   CALL   GET_NAME               ;Get filename.
               MOV    SI,FILE_NAME
               MOV    AX,MARK_CNT            ;Retrieve count of marked files.
               CMP    AX,0                   ;Were there any?
               JZ     DISP_SOURCE            ;If no, display source filename.
               CALL   GET_COUNT              ;Else, display count of marked.
               MOV    SI,OFFSET MARKED_MSG   ;Display "marked files".
DISP_SOURCE:   CALL   GET_TEXT
               MOV    SI,OFFSET TO_MSG       ;Display "to..."
               CALL   GET_TEXT
               MOV    DX,182FH
               CALL   CLEAR_OLD              ;Remove last user entry.
 
GET_DEST:      CALL   READ_KEY               ;Get a keystroke.
               CMP    AL,27                  ;Is it Esc?
               JZ     ABORT_DEST             ;If yes, abort.
               CMP    AL,13                  ;Is it carriage return?
               JZ     DO_DEST                ;If yes, execute.
               CMP    AL,8                   ;Is it backspace?
               JNZ    NOT_BS3                ;If yes, backspace.
               CALL   MOVE_BS
               JMP    SHORT GET_DEST
NOT_BS3:       CMP    AL,32                  ;Is it above space?
               JBE    GET_DEST               ;If no, ignore.
               CMP    DI,OFFSET ENTRY + 32   ;Else, is 32 line entry field full?
               JZ     GET_DEST               ;If yes, ignore.
               STOSB                         ;Else, store the character.
               CALL   WRITE_TEXT             ;And display it.
               JMP    SHORT GET_DEST
 
ABORT_DEST:    CALL   CURSOR_OFF
               CALL   CLEAR_MSG
               STC
               RET
 
DO_DEST:       CLC
               RET
 
;------------------------------------------------------------------------------;
; This subroutine either copies moves or deletes a highlighted or marked file. ;
;------------------------------------------------------------------------------;
 
EXEC_MARKED:   CALL   CURSOR_OFF             ;Turn cursor off.
               CMP    MARK_CNT,0             ;Are there any files marked?
               JNZ    MANY_MARKS             ;If yes, go find them.
               MOV    MARK_CNT,1             ;Else, change loop counter to one.
               CALL   GET_NAME
               JMP    SHORT EXEC_BAR         ;And execute it one time.
 
MANY_MARKS:    CALL   HOME_BAR               ;Home the highlight bar.
CK_MARK:       CALL   UPDATE_SCREEN          ;Update the screen.
               CALL   GET_NAME                   ;Get the highlighted filename.
               CMP    BYTE PTR [SI-1],COPY_MARK  ;Is it marked?
               JZ     EXEC_BAR                   ;If yes, execute command.
               CALL   DN_ARROW               ;Else, move down a row.
               JMP    SHORT CK_MARK          ;And check it for a mark.
 
EXEC_BAR:      CMP    BYTE PTR [SI+39],"H"   ;Is it a hidden file?
               JZ     EXEC_ERROR             ;If yes, skip.
               CMP    RENAME_FLAG,1          ;Is it a same drive move?
               JNZ    CK_COPY                ;If no, skip renaming.
               CALL   PARSE_ENTRY            ;Else, parse user entry.
               MOV    DX,OFFSET TARGET       ;Point to target.
               MOV    CX,7                   ;Does the file exist?
               CALL   FIND_FIRST
               JNC    EXEC_ERROR             ;If yes, skip
               CMP    COPY_FLAG,1            ;Is it across drives?
               JZ     GO_READ_WRITE          ;Is yes copy/delete.
               MOV    DX,OFFSET SOURCE
               MOV    DI,OFFSET TARGET
               MOV    AH,56H                 ;Else, rename it.
               INT    21H
               JC     EXEC_ERROR             ;Next one if failed.
               JMP    SHORT REMOVE           ;Else, remove it from list.
 
CK_COPY:       CMP    COPY_FLAG,1            ;Is it a copy request?
               JNZ    CK_DELETE              ;If no, check delete.
               CALL   PARSE_ENTRY            ;Else parse user entry.
GO_READ_WRITE: CALL   READ_WRITE             ;Copy the file.
               JC     EXEC_ERROR             ;If failed, skip rest.
MARK_IT:       MOV    SI,CUR_FILE            ;Else, mark with asterisk
               MOV    BYTE PTR [SI-1],"*"
CK_DELETE:     CMP    DELETE_FLAG,1          ;Is it a delete request?
               JNZ    CK_KEYSTROKE           ;If no, skip.
               MOV    DX,OFFSET SOURCE       ;Else, delete the file.
               MOV    AH,41H
               INT    21H
               JC     EXEC_ERROR
REMOVE:        CALL   REMOVE_FILE            ;If successful, remove from list.
               JMP    SHORT CK_KEYSTROKE
 
EXEC_ERROR:    CALL   BEEP
               CALL   DN_ARROW               ;Go to next line.
 
CK_KEYSTROKE:  CALL   CK_KEY                 ;Was a key struck while busy
               JNZ    CLEAR_KEY              ; at our copy, move or delete task?
               DEC    MARK_CNT               ;If yes, abort, else all done?
               JZ     END_EXEC               ;If no, continue until done.
               JMP    CK_MARK
 
CLEAR_KEY:     CALL   READ_KEY               ;Clear the keyboard buffer,
               CALL   CK_KEY                 ; user entry and prompt.
               JNZ    CLEAR_KEY
END_EXEC:      CALL   UPDATE_FREE
               CALL   FILE_COUNT
               CALL   CLEAR_MSG
               RET
 
;----------------------------------------;
; This subroutine parses the user entry. ;
;----------------------------------------;
 
PARSE_ENTRY:   MOV    BP,OFFSET TARGET       ;Point to target storage.
               MOV    DI,BP
               MOV    SI,OFFSET ENTRY        ;Point to user entry.
               CMP    BYTE PTR [SI],0        ;Anything entered?
               JNZ    GET_END                ;If yes, continue.
               JMP    TACK_FILENAME          ;Else, store source name.
 
GET_END:       LODSB                         ;Move user entry into target
               STOSB                         ; workspace.
               CMP    AL,0
               JNZ    GET_END
 
               STD                           ;Reverse string operation.
               DEC    DI                     ;Adjust pointer back one.
               MOV    SI,DI                  ;Make it the source pointer.
               MOV    FILENAME_END,DI        ;And store.
FIND_PATH:     CMP    SI,OFFSET TARGET - 1   ;Are we at start of name?
               JZ     SEARCH_WILD            ;If yes, done here.
               LODSB
               CMP    AL,"\"                 ;Else, is it a path delimiter?
               JZ     FOUND_PATH             ;If yes, mark start of filename.
               CMP    AL,":"                 ;Colon is also a path delimiter.
               JNZ    FIND_PATH
 
FOUND_PATH:    INC    SI                     ;Adjust pointer to end of path.
SEARCH_WILD:   INC    SI
               MOV    BP,SI                  ;And store.
               CLD                           ;String back to forward.
               MOV    DI,FCB                 ;Use file control block for
               MOV    AX,2900H               ; workspace.
               INT    21H                    ;Parse the entry for globals.
               CMP    AL,1                   ;Any wild cards?
               JNZ    CK_PATH                ;If no, check if it's a directory.
 
               MOV    SI,FCB + 1             ;Else, point to first character.
               MOV    DI,BP                  ;Point to target storage.
               MOV    BX,FILE_NAME           ;Point to source.
               MOV    CX,8                   ;Eight characters.
GLOBAL_NAME:   LODSB
               CMP    AL,32                  ;End of name?
               JZ     EXTENSION              ;If yes, do extension.
               CMP    AL,"?"                 ;Wild card?
               JNZ    LOOP_NAME              ;If no, store target character.
               MOV    AL,[BX]                ;Else, replace with source char.
               CMP    AL,"."                 ;Unless end of name.
               JZ     EXTENSION
               CMP    AL,0
               JZ     EXTENSION
LOOP_NAME:     STOSB                         ;Store the character.
               CMP    BYTE PTR [BX],"."      ;Are we at end of source name?
               JZ     NEXT_GLOBAL            ;If yes, don't move pointer.
               INC    BX                     ;Else, point to next source char.
NEXT_GLOBAL:   LOOP   GLOBAL_NAME
 
EXTENSION:     MOV    AL,"."                 ;Filename delimiter.
               STOSB                         ;Store it.
FIND_EXT:      CMP    [BX],AL                ;Was there a dot in source?
               JZ     DO_DOT                 ;If yes do extension.
               CMP    BYTE PTR [BX],0        ;End of source name?
               JZ     DO_EXT                 ;If yes, do extension.
               INC    BX                     ;Else, go to end of name.
               JMP    SHORT FIND_EXT
 
DO_DOT:        INC    BX                     ;Bump pointer past dot.
DO_EXT:        MOV    SI,FCB + 9             ;Point to extension of parsed.
               MOV    CX,3                   ;Three characters.
DO_EXTENSION:  LODSB
               CMP    AL,32                  ;End of parsed?
               JZ     END_GLOBAL             ;If yes, done here.
               CMP    AL,"?"                 ;Wild card?
               JNZ    LOOP_EXT               ;If no, store user character.
               MOV    AL,[BX]                ;Else, store source character.
 
LOOP_EXT:      STOSB
               INC    BX
               LOOP   DO_EXTENSION           ;Do all three extension chars.
 
END_GLOBAL:    XOR    AL,AL                  ;Make it an ASCIIZ.
               STOSB
               JMP    SHORT PARSE_END        ;Done here.
 
CK_PATH:       MOV    DI,BP                  ;Any characters after path
               CMP    BP,FILENAME_END        ; delimiter?
               JZ     TACK_FILENAME          ;If no, tack on source name.
               MOV    DX,OFFSET ENTRY        ;Else, see if it's a directory.
               MOV    CX,10H
               CALL   FIND_FIRST
               JC     PARSE_END              ;If not found, done here.
               CMP    DS:[149],CL            ;If not directory, done here.
               JNZ    PARSE_END
               MOV    DI,FILENAME_END        ;Else, tack on source filename.
               MOV    AL,"\"
               STOSB
 
TACK_FILENAME: MOV    SI,FILE_NAME           ;Source filename.
               MOV    CX,7
               REP    MOVSW
PARSE_END:     RET
 
;----------------------------------------------------;
; This section does the reading and writing to disk. ;
;----------------------------------------------------;
 
READ_WRITE:    MOV    DX,OFFSET SOURCE       ;Point to source filespec.
               XOR    AL,AL                  ;Open file for reading.
               CALL   OPEN_FILE
               JNC    SAVE_HANDLE
               JMP    END_RW                 ;Exit if failed.
SAVE_HANDLE:   MOV    READ_HANDLE,AX         ;Save the handle.
               MOV    CX,7
               CALL   FIND_FIRST             ;Get source
               MOV    SI,149
               LODSB
               XOR    AH,AH
               MOV    SOURCE_ATTRIB,AX       ; attribute
               LODSW
               MOV    SOURCE_TIME,AX         ; time
               LODSW
               MOV    SOURCE_DATE,AX         ; date
               LODSW
               MOV    SIZE_LOW,AX            ; and size
               LODSW
               MOV    SIZE_HIGH,AX           ; and save.
 
               MOV    DX,OFFSET TARGET       ;Point to target filename.
               CALL   FIND_FIRST             ;Does it exist?
               JNC    CK_IF_SAME             ;If yes, see if same as source.
 
               CALL   GET_DISK               ;Else, get disk free space.
               JMP    SHORT CK_FREE          ;Go see if enough room.
 
CK_IF_SAME:    MOV    CL,DS:[149]            ;Get attribute of target
               XOR    CH,CH
               MOV    BP,CX                  ; and save.
               XOR    CX,1                   ;Flip read-only attribute.
               CALL   CHMOD
               MOV    DX,OFFSET SOURCE       ;Now get source attribute.
               CALL   GETMOD
               CMP    CX,SOURCE_ATTRIB       ;See if it has changed.
               PUSHF                         ;Save compare results.
               MOV    DX,OFFSET TARGET       ;Restore target attribute.
               MOV    CX,BP
               CALL   CHMOD
               POPF                          ;Retrieve compare results.
               STC                           ;Assume files are the same.
               JNZ    CLOSE_READ             ;If they are, exit.
               CALL   GET_DISK               ;Else, get free disk space.
               ADD    AX,DS:[154]
               ADC    DX,DS:[156]            ;Target size + disk free.
CK_FREE:       SUB    AX,SIZE_LOW            ;Total - source size.
               SBB    DX,SIZE_HIGH
               JB     CLOSE_READ             ;If negative, not enough room.
 
CREATE:        MOV    DX,OFFSET TARGET       ;Create and truncate target file
               XOR    CX,CX                  ; to zero.
               MOV    AH,3CH
               INT    21H
               JC     CLOSE_READ
               MOV    WRITE_HANDLE,AX        ;Save handle.
               MOV    AX,DS                  ;Point to second 64K segment
               ADD    AX,1000H               ; for read/write buffer.
               MOV    DS,AX
               XOR    DX,DX
 
COPY_READ:     MOV    BX,CS:READ_HANDLE      ;Retrieve read handle.
               MOV    CX,0FFFFH              ;Read up to 64K at a time.
               MOV    AH,3FH
               INT    21H
               JC     COPY_DONE              ;If done, exit.
               CMP    AX,0                   ;If zero, also done.
               JZ     CHANGE_DATE
 
               MOV    BP,AX                  ;Save bytes read.
               MOV    CX,AX                  ;Bytes read into counter.
               MOV    BX,CS:WRITE_HANDLE     ;Retrieve write handle.
               MOV    AH,40H
               INT    21H                    ;Write the buffer to disk.
               JC     COPY_DONE
               CMP    CX,BP                  ;Did we write same number as read?
               STC                           ;Assume we had a problem.
               JNZ    COPY_DONE              ;If no, exit.
               CMP    CX,0FFFFH              ;Was it a full 64K read?
               JZ     COPY_READ              ;If yes, there must be more.
CHANGE_DATE:   MOV    BX,CS:WRITE_HANDLE
               MOV    CX,CS:SOURCE_TIME      ;Else, make time/date same
               MOV    DX,CS:SOURCE_DATE      ; as source.
               MOV    AX,5701H
               INT    21H
 
COPY_DONE:     PUSH   CS                     ;Restore data segment.
               POP    DS
 
CLOSE_WRITE:   PUSHF                         ;Save error if any.
               MOV    BX,WRITE_HANDLE        ;Close write file.
               CALL   CLOSE_FILE
               POP    AX                     ;Retrieve flags.
               JC     CLOSE_READ             ;Close successful?
               XCHG   AH,AL                  ;If no, exit with error, else
               SAHF                          ; retrieve write state.
 
CLOSE_READ:    PUSHF                         ;Save flags.
               MOV    BX,READ_HANDLE         ;Close read file.
               CALL   CLOSE_FILE             ;Return with status of
               POPF                          ; write file.
END_RW:        RET
 
;------------------------------------------------------------------------;
; These four subroutines control in which column the sorting will start. ;
;------------------------------------------------------------------------;
 
SORT_NAME:     MOV    SORT_OFFSET,0
               JMP    SHORT SORT_MSG
 
SORT_EXT:      MOV    SORT_OFFSET,4
               JMP    SHORT SORT_MSG
 
SORT_SIZE:     MOV    SORT_OFFSET,8
               JMP    SHORT SORT_MSG
 
SORT_DATE:     MOV    SORT_OFFSET,12
SORT_MSG:      MOV    DX,1733H
               MOV    SI,OFFSET LOADING+12
               CALL   DISPLAY_TEXT
 
;------------------------------------------;
; This subroutine does the actual sorting. ;
;------------------------------------------;
 
SORT:          CMP    COUNT,1                ;Can't sort one file.
               JZ     SORT_RETURN
               MOV    DX,END_OFFSET          ;End of filenames in DX.
               SUB    DX,44
               MOV    BP,SORT_OFFSET
NEXT_PASS:     MOV    SORT_FLAG,0
               MOV    BX,OFFSET BUFFER + 1   ;Point to start of buffer.
 
NEXT_SORT:     MOV    SI,BX                  ;Source and destination.
               ADD    SI,SORT_TABLE[BP]
               MOV    DI,SI
               ADD    DI,FIELD_SIZE
               CMP    BP,12                  ;Is it special case of date?
               JZ     DO_DATE                ;If yes, go do it.
               MOV    CX,SORT_TABLE[BP+2]
COMPARE:       REPZ   CMPSB                  ;Compare filenames.
               JBE    END_SORT               ;If already in order, skip.
 
SWAP:          MOV    SI,BX                  ;Else, recover pointers.
               DEC    SI
               MOV    DI,SI
               ADD    DI,FIELD_SIZE
               MOV    CX,FIELD_SIZE / 2      ;Exchange the records.
NEXT_SWAP:     MOV    AX,[DI]
               MOVSW
               MOV    [SI-2],AX
               LOOP   NEXT_SWAP
               MOV    SORT_FLAG,1            ;Flag that exchange was made.
 
END_SORT:      ADD    BX,FIELD_SIZE          ;Point to next record.
               CMP    BX,DX                  ;End of top?
               JB     NEXT_SORT              ;If no, bubble sort next.
               SUB    DX,FIELD_SIZE          ;Else, move top down one record.
               CMP    SORT_FLAG,0            ;Was there exchange made?
               JNZ    NEXT_PASS              ;If yes, another pass.
SORT_RETURN:   CALL   CLEAR_MSG
               RET
 
DO_DATE:       MOV    CX,2                   ;Compare year first.
               REPZ   CMPSB
               JA     SWAP                   ;If above, swap.
               JNZ    END_SORT
               SUB    SI,8                   ;Else, adjust and do month/day.
               SUB    DI,8
               MOV    CX,5
               REPZ   CMPSB
               JA     SWAP                   ;If above, swap.
               JNZ    END_SORT
               ADD    SI,10                  ;Else, adjust and do meridian.
               ADD    DI,10
               CMPSB
               JA     SWAP                   ;If above, swap.
               JNZ    END_SORT
               SUB    SI,6                   ;Else, adjust and do time.
               SUB    DI,6
               MOV    CX,5
               CMP    WORD PTR [SI],3231H    ;Is it special case "12:"?
               JZ     CK_MERIDIAN            ;If yes, see if same.
               CMP    WORD PTR [DI],3231H    ;Is destination "12:"?
               JNZ    COMPARE                ;If no, normal compare.
               JMP    SWAP                   ;Else, swap.
CK_MERIDIAN:   CMPSW                         ;Are both "12:"?
               JNZ    END_SORT               ;If no, next record.
               MOV    CX,3                   ;Else compare minutes.
               JMP    SHORT COMPARE
 
;--------------------------------------------------------------------------;
; These six subroutines control the bar and page of the directory listing. ;
;--------------------------------------------------------------------------;
 
UP_ARROW:      MOV    BP,-160                ;Move bar up one line.
               JMP    SHORT BAR_MOVE
 
DN_ARROW:      MOV    BP,160                 ;Move bar down one line.
BAR_MOVE:      CALL   SCROLL_BAR
               RET
 
PG_UP:         MOV    BP,- FIELD_SIZE * 21   ;Move up 21 lines.
               CALL   SCROLL
               JMP    SHORT BOTTOM_BAR
 
PG_DN:         MOV    BP,FIELD_SIZE * 21     ;Move down 21 lines.
MOVE_PAGE:     CALL   SCROLL
               JMP    SHORT TOP_BAR          ;Move bar to top.
 
HOME_BAR:      MOV    CUR_OFFSET,OFFSET BUFFER   ;Move listing to beginning.
TOP_BAR:       MOV    SI,BAR_START               ;And move bar to top.
               CALL   MOVE_BAR
               RET
 
END_BAR:       MOV    BX,END_OFFSET          ;Move listing to last page.
               SUB    BX,21 * FIELD_SIZE
               CMP    BX,OFFSET BUFFER
               JBE    BOTTOM_BAR
               MOV    CUR_OFFSET,BX
BOTTOM_BAR:    MOV    SI,PAGE_END            ;And move bar to bottom.
               SUB    SI,160
               CALL   MOVE_BAR
               RET
 
;-----------------------------------------------------------------------;
; This subroutine searches for a filename with a specific first letter. ;
;-----------------------------------------------------------------------;
 
SEARCH:        CMP    BL,"a"                 ;Capitalize if lower case.
               JB     SEARCH_IT
               CMP    BL,"z"
               JA     SEARCH_IT
               AND    BL,5FH
SEARCH_IT:     CALL   GET_NAME               ;Get current position.
               XOR    DX,DX                  ;Zero out file counter.
               MOV    DI,SI                  ;Store current position in DI.
               MOV    SI,OFFSET BUFFER + 1   ;Point to top of listing.
               CMP    BYTE PTR [DI],BL       ;Are we currently at a match?
               JNZ    NEXT_SEARCH            ;If no, start from top.
FIND_START:    INC    DX                     ;Increment count.
               ADD    SI,FIELD_SIZE          ;Increment record.
               CMP    SI,DI                  ;New record?
               JBE    FIND_START             ;If no, find it.
 
NEXT_SEARCH:   CMP    BYTE PTR [SI],BL       ;Got a match?
               JZ     FOUND_IT               ;If yes, process.
INC_SEARCH:    ADD    SI,FIELD_SIZE          ;Else, point to next record.
               INC    DX
               CMP    BYTE PTR [SI],32       ;End of listing?
               JNZ    NEXT_SEARCH            ;If no, keep searching.
               CALL   BEEP                   ;No matches, so beep.
               RET
 
FOUND_IT:      MOV    CX,COUNT               ;Retrieve file count.
               SUB    CX,DX                  ;Subtract search count.
               MOV    SEARCH_COUNT,CX        ;And store.
               MOV    CL,NORMAL              ;Turn off bar for now.
               MOV    BAR_ATTRIBUTE,CL
               CALL   END_BAR                ;First move to end.
               JMP    SHORT FIND_IT
NEXT_FIND:     CALL   UP_ARROW               ;Move up to matching filename.
FIND_IT:       DEC    SEARCH_COUNT
               JNZ    NEXT_FIND
               MOV    CL,INVERSE             ;Turn bar back on and display.
               MOV    BAR_ATTRIBUTE,CL
               XOR    BP,BP
               CALL   SCROLL_BAR
               RET
 
;--------------------------------------------------------------------------;
; This subroutine gets the highlighted file and converts it to DOS format. ;
;--------------------------------------------------------------------------;
 
GET_NAME:      MOV    SI,CUR_OFFSET          ;Get top of page.
               INC    SI                     ;Bump past mark field.
               MOV    AX,LINE                ;Get location of bar.
               SUB    AX,BAR_START           ;Adjust.
               MOV    CL,160                 ;Convert to byte pointer.
               DIV    CL
               MOV    CL,FIELD_SIZE
               MUL    CL
               ADD    SI,AX                  ;Add to current offset.
               MOV    CUR_FILE,SI            ;And save pointer.
               PUSH   SI
               MOV    DI,FILE_NAME           ;Store the first eight characters.
               MOV    CX,8
               CALL   STORE_BYTES
               INC    SI
               CMP    BYTE PTR DS:[SI],32    ;End of name?
               JZ     END_NAME               ;If yes, done here.
               MOV    AL,"."                 ;Else, add dot.
               STOSB
               MOV    CX,3                   ;Three possible characters
               CALL   STORE_BYTES            ; as extension.
END_NAME:      MOV    BYTE PTR [DI],0        ;Convert to ASCIIZ.
               POP    SI
               CMP    BYTE PTR [SI+13],"<"   ;Is it a directory?
               STC
               JZ     NAME_ERROR             ;If yes, indicate so.
               CLC
NAME_ERROR:    RET
 
STORE_BYTES:   LODSB                         ;Get a character.
               CMP    AL,32                  ;If it's space, skip.
               JZ     SKIP_STORE
               STOSB
SKIP_STORE:    LOOP   STORE_BYTES
               RET
 
;-----------------------------------------------------------;
; This subroutine moves and turns the cursor on and removes ;
; the last user entry in preparation for new input.         ;
;-----------------------------------------------------------;
 
CLEAR_OLD:     CALL   SET_CURSOR             ;Move cursor.
               CALL   CURSOR_ON              ;Turn it on.
               MOV    DI,OFFSET ENTRY        ;Write nulls over old entry.
               XOR    AX,AX
               MOV    CX,18
               REP    STOSW
               MOV    DI,OFFSET ENTRY        ;Initiate pointer for entry.
               RET
 
;-----------------------------;
; This subroutine backspaces. ;
;-----------------------------;
 
MOVE_BS:       CMP    DI,OFFSET ENTRY        ;At beginning of field?
               JZ     MOVE_BS_END            ;If yes, skip.
               DEC    DI                     ;Else, decrement pointer.
               MOV    BYTE PTR [DI],0
               MOV    SI,OFFSET BS           ;Erase last character.
               CALL   GET_TEXT
MOVE_BS_END:   RET
 
;------------------------------------------------------------------;
; This subroutine removes the filename from the directory listing. ;
;------------------------------------------------------------------;
 
REMOVE_FILE:   MOV    DI,CUR_FILE            ;Point to filename.
               DEC    DI                     ;Include mark field.
               MOV    SI,DI                  ;Move all the records
               ADD    SI,FIELD_SIZE          ; that follow up one.
NEXT_RECORD:   MOV    CX,FIELD_SIZE / 2
               REP    MOVSW
               CMP    DI,END_OFFSET
               JB     NEXT_RECORD
               SUB    DI,FIELD_SIZE
               MOV    END_OFFSET,DI          ;Store new end.
               XOR    BP,BP
               CALL   SCROLL                 ;Update the screen.
               DEC    COUNT
               DEC    FILE_CNT               ;Decrement file count.
               JNZ    MORE_FILES             ;If empty, exit.
               JMP    EXIT
MORE_FILES:    CMP    COUNT,21               ;Full page?
               JAE    REMOVE_END             ;If yes, skip.
               SUB    PAGE_END,160           ;Else, adjust page end.
               MOV    SI,PAGE_END
               SUB    SI,160
               CMP    SI,LINE                ;Is bar below directory listing?
               JA     REMOVE_END             ;If no, skip.
               CALL   MOVE_BAR               ;Else, move bar up one line.
REMOVE_END:    RET
 
;----------------------------------------------;
; This subroutine displays the count of files. ;
;----------------------------------------------;
 
FILE_COUNT:    MOV    DI,OFFSET FILES        ;Blank out previous count.
               MOV    AX,2020H
               STOSW
               MOV    AX,FILE_CNT
               XOR    DX,DX
               CALL   TRANSLATE
 
DISPLAY_BYTES: MOV    DX,1806H               ;Row 24; column 6.
               MOV    SI,OFFSET FILES        ;Display file count.
               CALL   DISPLAY_TEXT
               RET
 
;---------------------------------------------------;
; This subroutine converts a hex number to decimal. ;
;---------------------------------------------------;
 
TRANSLATE:     XCHG   AX,DX
               MOV    BX,10                  ;Convert to decimal.
               STD                           ;Reverse direction.
NEXT_COUNT:    MOV    CX,DX
               XOR    DX,DX
               DIV    BX
               XCHG   AX,CX
               DIV    BX
               XCHG   AX,DX
               ADD    AL,"0"                 ;Convert to ASCII.
               STOSB                         ;Store the remainder.
               MOV    AX,CX
               OR     CX,DX
               JNZ    NEXT_COUNT
               CLD                           ;Back to forward direction.
               RET
 
;----------------------------------------------------------------------------;
; This subroutine displays the current directory, menu, and number of files. ;
;----------------------------------------------------------------------------;
 
REFRESH_DIR:   CALL   CLS                    ;Clear the screen.
REFRESH_MENU:  MOV    SI,OFFSET MENU         ;Point to menu position.
               MOV    DI,(2*160)+98          ;And to screen position.
               MOV    BH,20                  ;Display 20 lines of menu.
NEXT_REFRESH:  MOV    CX,22                  ;22 characters per line.
NEXT_MENU:     LODSB
               MOV    BL,AL
               CALL   WRITE_SCREEN
               LOOP   NEXT_MENU
               ADD    DI,116                 ;Next line.
               DEC    BH
               JNZ    NEXT_REFRESH
 
               MOV    DX,4
               MOV    SI,OFFSET DIRECTORY    ;Display "Directory ".
               CALL   DISPLAY_TEXT
               MOV    SI,OFFSET PURGE_DIR    ;Display working directory.
               CALL   GET_TEXT
               CALL   FILE_COUNT             ;Display file count.
               MOV    BL,INVERSE             ;Put up cursor bar.
               CALL   BAR
               RET
 
;-------------------------------------;
; This subroutine scrolls the screen. ;
;-------------------------------------;
 
SCROLL:        MOV    SI,CUR_OFFSET          ;Get current offset.
               ADD    SI,BP                  ;Add requested direction.
CK_LOWER:      CMP    SI,OFFSET BUFFER       ;If above start check upper limit.
               JAE    UPPER_LIMIT
LOWER_LIMIT:   MOV    CUR_OFFSET,OFFSET BUFFER    ;Else, make it start.
               JMP    SHORT SCROLL_RETURN         ;And update screen.
 
UPPER_LIMIT:   MOV    BX,END_OFFSET                      ;See if beyond end of
               CMP    BX,OFFSET BUFFER + 21 * FIELD_SIZE ; directory listing.
               JA     CK_UPPER
               MOV    CUR_OFFSET,OFFSET BUFFER
               JMP    SHORT SCROLL_RETURN
 
CK_UPPER:      SUB    BX,21 * FIELD_SIZE
               CMP    SI,BX
               JBE    END_SCROLL
               MOV    SI,BX
 
END_SCROLL:    MOV    CUR_OFFSET,SI          ;Update current offset.
SCROLL_RETURN: RET
 
;--------------------------------------------------;
; This subroutine scrolls the bar if between start ;
; and end of page. Otherwise the page is scrolled. ;
;--------------------------------------------------;
 
SCROLL_BAR:    MOV    SI,LINE                ;Get current line.
               ADD    SI,BP                  ;Add requested line.
               MOV    BP,- FIELD_SIZE        ;Assume below beginning.
               CMP    SI,BAR_START           ;Is it?
               JB     SCROLL_PAGE            ;If yes, scroll page instead.
               MOV    BP,FIELD_SIZE          ;Do the same for end of page.
               CMP    SI,PAGE_END
               JAE    SCROLL_PAGE
               CALL   MOVE_BAR
               RET
 
SCROLL_PAGE:   CALL   SCROLL
               RET
 
;----------------------------------------------------;
; This subroutine does the actual moving of the bar. ;
;----------------------------------------------------;
 
MOVE_BAR:      MOV    BL,NORMAL              ;Remove old bar.
               CALL   BAR
               MOV    LINE,SI                ;And move bar to new line.
               MOV    BL,BAR_ATTRIBUTE
               CALL   BAR
               RET
 
BAR:           MOV    DI,LINE                ;Retrieve line.
               MOV    CX,39                  ;Bar length 39.
NEXT_BAR:      CALL   WRITE_SCREEN           ;Write the attribute.
               LOOP   NEXT_BAR
               RET
 
;-------------------------------------------------;
; This subroutine displays the directory listing. ;
;-------------------------------------------------;
 
UPDATE_SCREEN: XOR    BP,BP
               MOV    SI,CUR_OFFSET          ;Retrieve starting offset.
               MOV    DI,2*160               ;Point to row two of screen.
               MOV    BH,21                  ;21 lines to write.
NEXT_WRITE:    MOV    CX,FIELD_SIZE          ;44 characters per line.
NEXT_CHAR:     LODSB                         ;Get a byte.
               MOV    BL,AL                  ;Save it in BL.
               CALL   WRITE_SCREEN           ;Write them.
               LOOP   NEXT_CHAR
               ADD    DI,160 - FIELD_SIZE * 2   ;Bump pointer to next line.
               DEC    BH                        ;Do all 21 lines.
               JNZ    NEXT_WRITE
               RET
 
;------------------------------------------------------------;
; This subroutine displays the directory by writing directly ;
; to the screen buffer. To avoid screen noise (snow) on the  ;
; color card, the horizontal retrace has to be monitored.    ;
;------------------------------------------------------------;
 
WRITE_SCREEN:  MOV    DX,STATUS_REG          ;Retrieve status register.
               MOV    AX,VIDEO_SEG           ;Point to screen segment.
               MOV    ES,AX
 
HORZ_RET:      IN     AL,DX                  ;Get status.
               TEST   AL,1                   ;Is it low?
               JNZ    HORZ_RET               ;If not, wait until it is.
               CLI                           ;No more interrupts.
 
HWAIT:         IN     AL,DX                  ;Get status.
               TEST   AL,1                   ;Is it high?
               JZ     HWAIT                  ;If no, wait until it is.
               MOV    AL,BL                  ;Retrieve character; now it's OK
               STOSB                         ; to write to screen buffer.
               STI                           ;Interrupts back on.
               INC    DI                     ;Bump pointer past attribute.
               PUSH   CS
               POP    ES
               RET                           ;Return
 
;-----------------------------------------------------------------------;
; These two subroutines clear either the messages or the entire screen. ;
;-----------------------------------------------------------------------;
 
CLEAR_MSG:     MOV    CX,172CH               ;Row 24; column 43.
               MOV    DX,184FH               ;Row 25; column 79.
               JMP    SHORT CLEAR_WINDOW
 
CLS:           XOR    CX,CX
               MOV    DX,184FH               ;Entire screen.
 
CLEAR_WINDOW:  PUSH   BP
               PUSH   BX
               MOV    BH,NORMAL              ;Clear with original attribute.
               MOV    AX,600H
               INT    10H
               POP    BX
               POP    BP
               RET
 
;-----------------------------------------;
; These subroutines display the messages. ;
;-----------------------------------------;
 
DISPLAY_TEXT:  CALL   SET_CURSOR             ;Move cursor.
GET_TEXT:      LODSB
               CMP    AL,0                   ;Zero marks end of string.
               JZ     END_TEXT
               CALL   WRITE_TEXT
               JMP    SHORT GET_TEXT
END_TEXT:      RET
 
WRITE_TEXT:    PUSH   SI                     ;BIOS does not save SI.
               MOV    AH,0EH                 ;Write teletype.
               INT    10H
               POP    SI
               RET
 
;--------------------------------------------------------------;
; These two subroutines change the default drive or directory. ;
;--------------------------------------------------------------;
 
GET_DRIVE:     MOV    AH,19H
               INT    21H
               RET
 
CHANGE_DRIVE:  MOV    AH,0EH
               INT    21H
               RET
 
;---------------------------------------------;
; These two subroutines open or close a file. ;
;---------------------------------------------;
 
OPEN_FILE:     MOV    AH,3DH
               INT    21H
               RET
 
CLOSE_FILE:    MOV    AH,3EH
               INT    21H
               RET
 
;------------------------------------------------; 
; This subroutine finds the first matching file. ;
;------------------------------------------------;
 
FIND_FIRST:    MOV    AH,4EH
               INT    21H
               RET
 
;--------------------------------------------------------------;
; These two subroutines retrieve or change a file's attribute. ;
;--------------------------------------------------------------;
 
CHMOD:         MOV    AX,4301H
               INT    21H
               RET
 
GETMOD:        MOV    AX,4300H
               INT    21H
               RET
 
;---------------------------------------------------------; 
; This subroutine gets the free disk space of the target. ;
;---------------------------------------------------------;
 
GET_DISK:      MOV    SI,DX                  ;Retrieve pointer to target file.
               MOV    DL,-1                  ;Assume default drive.
               CMP    BYTE PTR [SI+1],":"    ;Is there a drive request?
               JNZ    GET_FREE               ;If no, get default drive.
               MOV    DL,[SI]                ;Else, retrieve drive request.
               AND    DL,5FH                 ;Capitalize.
               SUB    DL,"A"                 ;Convert to DOS format.
GET_FREE:      CALL   DISK_FREE              ;Get free bytes.
               RET
 
;--------------------------------------------------------------;
; This subroutine gets the free disk space of the source drive ;
;--------------------------------------------------------------;
 
UPDATE_FREE:   MOV    DL,PURGE_DIR           ;Get source drive.
               SUB    DL,"A"                 ;Convert to DOS format.
               CALL   DISK_FREE              ;Get disk free space.
               MOV    DI,OFFSET FILES + 20   ;Point to storage.
               CALL   TRANSLATE              ;Convert hex to decimal and store.
               RET
 
;----------------------------------------------; 
; This subroutine retrieves available clusters ;
; and converts it to hexidecimal bytes free.   ;
;----------------------------------------------;
 
DISK_FREE:     INC    DL                     ;Adjust drive.
               MOV    AH,36H                 ;Disk free space.
               INT    21H
               XOR    DX,DX
               MUL    BX                     ;Sectors per cluster times clusters
               MUL    CX                     ;Result times bytes per cluster.
               RET
 
;------------------------------------------;
; This subroutine converts hex to decimal. ;
;------------------------------------------;
 
GET_COUNT:     MOV    BX,10                  ;Convert to decimal.
               XOR    CX,CX                  ;Zero in counter.
GET_NUMBER:    XOR    DX,DX                  ;Zero in high half.
               DIV    BX
               ADD    DL,"0"                 ;Convert to ASCII.
               PUSH   DX                     ;Save results.
               INC    CX                     ;Also increment count.
               CMP    AX,0                   ;Are we done?
               JNZ    GET_NUMBER
 
NEXT_NUMBER:   POP    AX                     ;Retrieve numbers.
               CALL   WRITE_TEXT             ;And write them.
               LOOP   NEXT_NUMBER
               RET
 
;---------------------------------------------------------;
; These five subroutines move the cursor, get the current ;
; directory, beep the speaker, check or get a keystroke.  ;
;---------------------------------------------------------;
 
SET_CURSOR:    PUSH   SI
               XOR    BH,BH                  ;Page zero.
               MOV    AH,2                   ;Set cursor.
               INT    10H
               POP    SI
               RET
 
GET_DIR:       MOV    BYTE PTR [SI],"\"      ;DOS doesn't preface directory
               INC    SI                     ; with slash so we must.
               XOR    DL,DL
               MOV    AH,47H                 ;Retrieve default directory.
               INT    21H
               RET
 
BEEP:          MOV    DL,7                   ;Beep via DOS.
               MOV    AH,2
               INT    21H
               RET
 
READ_KEY:      MOV    AH,0                   ;Retrieve keystroke via BIOS.
               INT    16H
               RET
 
CK_KEY:        MOV    AH,1                   ;Check for keystroke via BIOS.
               INT    16H
               RET
 
;-------------------------------------------------------------;
; This subroutine waits until a keystroke is pressed and then ;
; clears the message.  Keystroke remains in keyboard buffer.  ;
;-------------------------------------------------------------;
 
DELAY:         CALL   CK_KEY
               JZ     DELAY
               CALL   CLEAR_MSG
               RET
 
;-----------------------------------------------;
; These subroutines turn the cursor off and on. ;
;-----------------------------------------------;
 
CURSOR_OFF:    MOV    CX,2000H
               JMP    SHORT SET_TYPE
 
CURSOR_ON:     MOV    CX,CURSOR_TYPE
 
SET_TYPE:      MOV    AH,1
               INT    10H
               RET
 
;------------------------------------------------;
; This subroutine changes the default directory. ;
;------------------------------------------------;
 
CHANGE_DIR:    MOV    AH,3BH
               INT    21H
               RET
 
;------------------------------------------------;
; This subroutine changes the copy verify state. ;
;------------------------------------------------;
 
SET_VERIFY:    MOV    AH,2EH
               INT    21H
               RET
 
;--------------------------------------------------;
; This long subroutine stores the filename in DIR  ;
; format. That is, filename, bytes, date and time. ;
;--------------------------------------------------;
 
BUFFER_NAME:   MOV    SI,158                 ;Point to filename.
               MOV    CX,12                  ;Store 12 bytes of filename.
               CMP    BYTE PTR [SI],"."      ;Is it a dot directory?
               JNZ    INC_COUNT              ;If no, it's a file.
               CMP    BYTE PTR [SI+1],"."    ;Is it a double dot directory?
               JNZ    DONT_STORE             ;If no, single dot so skip.
               INC    COUNT                  ;Else, increment total count.
               LODSB                         ;Store dots and go to file size.
               STOSB
               STOSB
               ADD    DI,10
               JMP    SHORT FILE_SIZE
DONT_STORE:    RET
 
INC_COUNT:     INC    COUNT                  ;Increment total count.
NEXT_STORE:    LODSB                         ;Get a byte.
               CMP    AL,0                   ;End of filename?
               JZ     END_STORE              ;If yes, finish with blanks.
               CMP    AL,"."                 ;Is it the period?
               JNZ    STORE_BYTE             ;If no, store.
               SUB    CX,3                   ;Else store 3 spaces.
               MOV    AL,32
               REP    STOSB
               ADD    CX,3
               JMP    SHORT NEXT_STORE       ;Get next byte.
 
STORE_BYTE:    STOSB                         ;Store byte.
               LOOP   NEXT_STORE             ;Get next byte.
END_STORE:     MOV    AL,32                  ;Pad balance with spaces.
               REP    STOSB
 
FILE_SIZE:     PUSH   DI                     ;Save pointer.
               TEST   BYTE PTR DS:[149],10H  ;Is it a directory?
               JZ     STORE_SIZE             ;If no, store size.
               MOV    SI,OFFSET DIRECTORIES  ;Else, store "<DIR>".
               INC    DI
               MOV    CX,5
               REP    MOVSB
               JMP    SHORT END_DATE
 
STORE_SIZE:    INC    FILE_CNT               ;Increment file count.
               ADD    DI,8                   ;Move to end of bytes field.
               MOV    DX,DS:[156]            ;Retrieve high and low words
               MOV    AX,DS:[154]            ; of bytes.
               CALL   TRANSLATE              ;Convert to decimal.
 
END_DATE:      POP    DI                     ;Retrieve pointer.
               ADD    DI,11                  ;Move to date field.
DATE:          MOV    DX,DS:[152]            ;Retrieve date.
               MOV    AX,DX
               MOV    CL,5                   ;Shift to lowest bits.
               ROR    AX,CL
               AND    AX,0FH                 ;Mask off all but month.
               MOV    CL,0FFH                ;Flag as no leading zeros.
               MOV    CH,"-"                 ;Delimiting character.
               CALL   STORE_WORD             ;Store it.
 
               MOV    AX,DX                  ;Retrieve date.
               AND    AX,1FH                 ;Mask off all but day.
               MOV    CL,0                   ;Flag include leading zeros.
               MOV    CH,"-"
               CALL   STORE_WORD             ;Store it.
 
               MOV    AX,DX                  ;Retrieve date for last time.
               MOV    CL,9
               ROR    AX,CL
               AND    AX,7FH                 ;Mask off all but year.
               ADD    AX,80                  ;Adjust to ASCII.
               CMP    AX,100                 ;Past year 2000?
               JB     DISPLAY_DATE           ;If no, display. Else, adjust for
               SUB    AX,100                 ; next century. (Planning ahead!)
DISPLAY_DATE:  MOV    CL,0                   ;Display leading zeros.
               MOV    CH,32
               CALL   STORE_WORD             ;Store it.
 
TIME:          INC    DI                     ;Move to time field.
               MOV    DX,DS:[150]            ;Retrieve time.
               MOV    AX,DX
               MOV    CL,11                  ;Shift to hours bits.
               ROR    AX,CL
               AND    AX,1FH                 ;Mask off all but hours.
               PUSH   AX
               CMP    AX,12                  ;Past noon?
               JBE    MERIDIAN
               SUB    AX,12                  ;If yes, adjust.
MERIDIAN:      CMP    AX,0                   ;Midnight?
               JNZ    NOT_MIDNIGHT
               MOV    AX,12                  ;If yes, adjust.
NOT_MIDNIGHT:  MOV    CL,0FFH                ;Suppress leading zeros.
               MOV    CH,":"
               CALL   STORE_WORD             ;Store it.
 
               MOV    AX,DX                  ;Retrieve time.
               MOV    CL,5                   ;Shift to minutes bits.
               ROR    AX,CL
               AND    AX,3FH                 ;Mask off all but minutes.
               MOV    CL,0
               POP    DX                     ;Retrieve hours.
               MOV    CH,"p"                 ;Assume PM.
               CMP    DX,12                  ;Is it PM?
               JAE    PM
               MOV    CH,"a"                 ;If no, AM.
 
PM:            CALL   STORE_WORD             ;Store it.
               MOV    AH,BYTE PTR DS:[149]   ;Get attribute byte.
               MOV    AL,"H"                 ;Assume it's hidden.
               TEST   AH,2                   ;Is it?
               JNZ    HIDDEN                 ;If yes, store "H".
               MOV    AL,32                  ;Else, store a space.
HIDDEN:        STOSB
               MOV    AL,"S"                 ;Assume it's system.
               TEST   AH,4                   ;Is it?
               JNZ    SYSTEM                 ;If yes, store "S".
               MOV    AL,32                  ;Else, store a space.
SYSTEM:        STOSB
               MOV    AL,"R"                 ;Assume it's read-only.
               TEST   AH,1                   ;Is it?
               JNZ    READ_ONLY              ;If yes, store "R".
               MOV    AL,32                  ;Else, store a space.
READ_ONLY:     STOSB
               MOV    AL,"A"                 ;Assume it's archive.
               TEST   AH,20H                 ;is it?
               JNZ    ARCHIVE                ;If yes, store "A".
               MOV    AL,32                  ;Else store a space.
ARCHIVE:       STOSB
               INC    DI                     ;Bump pointer past mark field.
               RET
 
;-------------------------------;
 
STORE_WORD:    MOV    BL,10
               DIV    BL                     ;Divide by ten.
               ADD    AX,"00"                ;Convert to ASCII.
               CMP    CL,0                   ;Are we to display leading zero?
               JZ     STORE_IT               ;If yes, store as is.
               CMP    AL,"0"                 ;Is it a leading zero?
               JNZ    STORE_IT               ;If no, store it.
               MOV    AL,32                  ;Else, store a space.
STORE_IT:      STOSW
               MOV    AL,CH                  ;Store delimiter character also.
               STOSB
               RET
 
;-------------------------------------------;
; This is the new Critical Error interrupt. ;
;-------------------------------------------;
 
DISK_ERROR:    STI                           ;Interrupts back on.
               PUSHF                         ;Save all registers.
               PUSH   AX
               PUSH   BX
               PUSH   CX
               PUSH   DX
               PUSH   SI
               PUSH   DI
               PUSH   BP
               PUSH   DS
               PUSH   ES
 
               PUSH   AX                     ;Save failed drive number.
               MOV    AX,CS
               MOV    DS,AX                  ;Point to our data segment.
               MOV    ES,AX
 
               CALL   CLEAR_MSG              ;Clear current message.
               MOV    SI,OFFSET DISK_MSG     ;Display disk error message.
               MOV    DX,172FH
               CALL   DISPLAY_TEXT
               POP    AX                     ;Retrieve fail drive and display.
               ADD    AL,"A"
               CALL   WRITE_TEXT
               MOV    DX,182FH               ;Display rest of error message.
               CALL   DISPLAY_TEXT
 
WAIT_KEY:      CALL   READ_KEY               ;Get a response to message.
               CMP    AH,13H                 ;Was it scan code for "R"?
               JZ     END_DISK               ;If yes retry.
               CMP    AH,10H                 ;Was it "Q"?
               JNZ    WAIT_KEY               ;If no, wait until correct response
               JMP    EXIT                   ;Else, exit to DOS.
 
END_DISK:      CALL   CLEAR_MSG              ;Clear disk error message.
               POP    ES                     ;Restore registers.
               POP    DS
               POP    BP
               POP    DI
               POP    SI
               POP    DX
               POP    CX
               POP    BX
               POP    AX
               POPF
               MOV    AL,1                   ;Return with retry request.
               IRET
 
CURRENT_DIR    DB     0
WORKING_DIR    EQU    CURRENT_DIR+68
PURGE_DIR      EQU    WORKING_DIR+68
SOURCE         EQU    PURGE_DIR+66
TARGET         EQU    SOURCE+65+13
ENTRY          EQU    TARGET+65+13
BUFFER         EQU    ENTRY+36
 
CODE ENDS
END  START
