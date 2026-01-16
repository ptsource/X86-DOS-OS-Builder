;------------------------------------------------------------------------;
;  ANSI.COM - Replacement for the ANSI.SYS console device driver.        ;
;  Unlike ANSI.SYS which must be installed at boot time, ANSI.COM        ;
;  can be installed and uninstalled at anytime.  Enhancements include    ;
;  a fast screen write and variable sized keyboard reassignment buffer.  ;
;------------------------------------------------------------------------;
_TEXT          SEGMENT PUBLIC 'CODE'
               ASSUME  CS:_TEXT,DS:_TEXT,ES:_TEXT,SS:_TEXT
               ORG     100H
START:         JMP     INITIALIZE

SIGNATURE      DB      CR,LF,"$",26

CR             EQU     13
LF             EQU     10
SPACE          EQU     32
ESC_CHAR       EQU     27
SINGLE_QUOTE   EQU     39
DOUBLE_QUOTE   EQU     34
BELL           EQU     7
BS             EQU     8

OFF            EQU     1
ON             EQU     2
SLOW           EQU     4
FAST           EQU     8
STATUS_MASK    EQU     11111100B

ANSI_STATE     DW      ESC_STATE
STATUS         DB      ON OR FAST
PARAMETERS     DB      "OFF ON  SLOWFAST"
LAST_PARAMETER EQU     $ - PARAMETERS

OLD_INT_29     DW      ?,?
OLD_INT_16     DW      ?,?
OLD_INT_21     DW      ?,?

ATTRIBUTE      DB      7
SAVE_POSITION  DW      0
LINE_WRAP      DB      ON
QUOTE_TYPE     DB      ?
ESC_COUNT      DW      0
NUMBER_COUNT   DW      0

FORMAT_CHARS   DB      CR,LF,BS,BELL
FORMAT_LENGTH  EQU     $ - FORMAT_CHARS

COMMAND_TABLE  LABEL   BYTE
DB   "H", "A", "B", "C", "D", "f", "n", "s", "u", "K", "m", "h", "l", "p", "J"
COMMAND_LENGTH EQU     $ - COMMAND_TABLE

DW   CURS_POSITION, CURSOR_UP,     CURSOR_DOWN, CURS_FORWARD, CURS_BACKWARD
DW   HORZ_VERT_POS, DEVICE_STATUS, SAVE_CURSOR, RESTORE_CURS, ERASE_IN_LINE
DW   SGR,           SET_MODE,      RESET_MODE,  REASSIGNMENT, CLS
COMMAND_END    EQU     $ - 2

ATTRIBUTE_TABLE        LABEL    BYTE
DB   00,01,04,05,07,08,30,31,32,33,34,35,36,37,40,41,42,43,44,45,46,47
ATTRIBUTE_LENGTH       EQU      $ - ATTRIBUTE_TABLE

;Format: AND mask,OR mask
DB      000H,07H, 0FFH,08H, 0F8H,01H, 0FFH,80H, 0F8H,70H, 088H,00H
DB      0F8H,00H, 0F8H,04H, 0F8H,02H, 0F8H,06H, 0F8H,01H, 0F8H,05H
DB      0F8H,03H, 0F8H,07H, 08FH,00H, 08FH,40H, 08FH,20H, 08FH,60H
DB      08FH,10H, 08FH,50H, 08FH,30H, 08FH,70H
ATTRIBUTE_END          EQU      $ - 2

BIOS_ACTIVE_PAGE       EQU     62H
ACTIVE_PAGE    DB      ?
ADDR_6845      DW      ?
BIOS_CRT_MODE          EQU     49H
CRT_MODE       DB      ?
CRT_COLS       DW      ?
CRT_LEN        DW      ?
CRT_START      DW      ?
CRT_DATA_LENGTH        EQU     $ - CRT_MODE
CURSOR_POSN    LABEL   WORD
CURSOR_COL     DB      ?
CURSOR_ROW     DB      ?
CRT_ROWS       DB      ?

DOS_INPUT      DB      OFF
BUSY_FLAG      DB      OFF
REASSIGN_FLAG  DB      OFF
REMOVE_FLAG    DB      ON
REASSIGN_COUNT DW      0
REASSIGN_POS   DW      ?
FUNCTION_16    DB      ?
ZR             EQU     1000000B

ESC_BUFFER_SIZE      EQU     126
REASSIGNMENT_DEFAULT EQU     200
REASSIGNMENT_SIZE    DW      REASSIGNMENT_DEFAULT
REASSIGNMENT_MAX     EQU     60 * 1024
REASSIGN_END         DW      REASSIGNMENT_BUFFER
BUFFER_END           DW      REASSIGNMENT_BUFFER + REASSIGNMENT_DEFAULT

;------------------------------------------------------------------------------;
; INT 29 is an undocumented interrupt called by DOS for output to the console. ;
;------------------------------------------------------------------------------;
ANSI_INT_29    PROC    FAR

               PUSH    AX                      ;Save all registers.
               PUSH    BX
               PUSH    CX
               PUSH    DX
               PUSH    SI
               PUSH    DI
               PUSH    DS
               PUSH    ES
               PUSH    BP

               CLD                             ;All string operations forward.
               MOV     BX,CS                   ;Point to our data segment.
               MOV     DS,BX
               MOV     ES,BX
               CALL    ANSI_STATE              ;Call the current state of
                                               ; the ANSI Esc sequence.
               POP     BP
               POP     ES
               POP     DS
               POP     DI
               POP     SI
               POP     DX
               POP     CX
               POP     BX
               POP     AX                      ;Restore all registers and
               IRET                            ; return.
ANSI_INT_29    ENDP

;------------------------------------------------;
ANSI_INT_21    PROC    FAR
               PUSHF
               CMP     AH,0AH                  ;If DOS Int 21 functions Ah,
               JZ      INPUT                   ; 7h, 1h or console input (6h)
               CMP     AH,7                    ; then tell INT 16, DOS input
               JZ      INPUT                   ; is active.
               CMP     AH,1
               JZ      INPUT
               CMP     AH,6
               JNZ     QUICK21_EXIT
               CMP     DL,0FFH
               JZ      INPUT
QUICK21_EXIT:  POPF                              ;If not, let the original
               JMP     DWORD PTR CS:OLD_INT_21   ; interrupt process the call.

INPUT:         POPF
               MOV     CS:DOS_INPUT,ON           ;INT 16 handler flag.
               PUSHF
               CALL    DWORD PTR CS:OLD_INT_21   ;Emulate an interrupt.
               MOV     CS:DOS_INPUT,OFF          ;Turn flag back off.
               RET     2                         ;Return with current flags.
ANSI_INT_21    ENDP

;-----------------------------------------------------------------;
; If we get here via a DOS console input call, any awaiting key   ;
; in keyboard buffer is checked to see if it is to be reassigned. :
;-----------------------------------------------------------------;
ANSI_INT_16    PROC    FAR
               STI                             ;Interrupts back on.
               PUSHF                           ;Preserve flags on stack.
               PUSH    BP
               PUSH    DS
               PUSH    AX
               PUSH    CS                      ;Point to our data.
               POP     DS

               CMP     DOS_INPUT,OFF           ;If not called via a DOS
               JZ      QUICK16_EXIT            ; console input call, exit.
               CMP     BUSY_FLAG,ON            ;If already processing a call,
               JZ      QUICK16_EXIT            ; exit.
               CLD                             ;All string operations forward.
               MOV     BP,SP                   ;Base reference to flags on stack
               MOV     FUNCTION_16,AH          ;Save function request.
               AND     AH,NOT 10H              ;Strip possible extended request.
               JZ      GET_KEY                 ;If zero, it's wait for a key.
               DEC     AH                      ;Else, decrement.  If zero it's
               JZ      KEY_STATUS              ; key status, else exit.

QUICK16_EXIT:  POP     AX                      ;Restore registers and let
               POP     DS                      ; original interrupt handler
               POP     BP                      ; process the call.
               POPF
               JMP     DWORD PTR CS:OLD_INT_16

KEY_STATUS:    OR      BYTE PTR [BP+6],ZR      ;Assume none ready; ZR = 1.
GET_KEY:       MOV     BUSY_FLAG,ON            ;Non-reentrant; flag busy.
               POP     AX
               PUSH    BX                      ;Save some more registers.
               PUSH    CX
               PUSH    DX
               PUSH    SI
               PUSH    DI
               CMP     REASSIGN_FLAG,ON        ;Already in process of reassign?
               JZ      CK_BUFFER               ;If yes, check kbd buffer.

               PUSHF                           ;Else, emulate an interrupt.
               CALL    DWORD PTR OLD_INT_16
               PUSHF                           ;Status call results in flags.
               TEST    FUNCTION_16,1           ;Was it a status call?
               JZ      CK_DUP                  ;If no, check key returned.
               POPF                            ;Else, retrieve status results.
               JZ      INT16_EXIT              ;If zero, no key waiting.
               AND     BYTE PTR [BP+6],NOT ZR  ;Else, ZR = 0.
               PUSHF                           ;PUSHF just to keep stack right.

CK_DUP:        POPF                            ;Fix stack.
               MOV     BX,AX                   ;Match procedure wants key in BX.
               CALL    CK_MATCH                ;Check reassignment buffer.
               JC      INT16_EXIT              ;If no match, exit.
               MOV     AX,[DI]                 ;Else, retrieve string length.
               SUB     AX,3                    ;Adjust for length word and match
               ADD     DI,3                    ; byte; same for string pointer.
               OR      BL,BL                   ;Extended key? ie. key = 0.
               JNZ     STORE_COUNT             ;If no, save length and pointer.
               DEC     AX                      ;Else, adjust for extended code.
               INC     DI
STORE_COUNT:   MOV     REASSIGN_COUNT,AX       ;Save string length.
               MOV     REASSIGN_POS,DI         ;Save pointer to string.
               MOV     REASSIGN_FLAG,ON        ;Flag that replacement in effect.
CK_BUFFER:     TEST    FUNCTION_16,1           ;Was it a key wait function call?
               JNZ     RETRIEVE                ;If no, key status; get it.
               CMP     REMOVE_FLAG,OFF         ;Removed it from kbd buffer?
               JZ      RETRIEVE                ;If yes, get reassignment.
               MOV     AH,FUNCTION_16          ;Else, eat the replaced character
               INT     16H                     ; via INT 16.
               MOV     REMOVE_FLAG,OFF         ;Flag character eaten.

RETRIEVE:      MOV     DI,REASSIGN_POS         ;Retrieve pointer to string.
               MOV     AX,[DI]                 ;Retrieve replacement character.
               TEST    FUNCTION_16,1           ;Is it a key wait function call?
               JZ      REMOVE                  ;If yes, bump pointer up one.
               AND     BYTE PTR [BP+6],NOT ZR  ;If no, status call; ZR = 0
               JMP     SHORT INT16_EXIT        ;All done.

REMOVE:        INC     REASSIGN_POS            ;Move pointer to next character.
               DEC     REASSIGN_COUNT          ;One less character to replace.
               JZ      REASSIGN_DONE           ;If end of string, reset flags.
               OR      AL,AL                   ;Else, extended replacement?
               JNZ     INT16_EXIT              ;If no, done here.
               INC     REASSIGN_POS            ;Else adjust pointers.
               DEC     REASSIGN_COUNT
               JNZ     INT16_EXIT              ;End of string?
REASSIGN_DONE: MOV     REASSIGN_FLAG,OFF       ;If yes, reset flags.
               MOV     REMOVE_FLAG,ON

INT16_EXIT:    MOV     BUSY_FLAG,OFF           ;Reset the busy flag.
               POP     DI                      ;Restore registers.
               POP     SI
               POP     DX
               POP     CX
               POP     BX
               POP     DS
               POP     BP
               POPF                            ;Flags on stack have status
               RET     2                       ; results; kill old flags.
ANSI_INT_16    ENDP

;************* ANSI ESCAPE STATE ROUTINES ************* ;

ESC_STATE:     MOV     BX,OFFSET BRACKET_STATE ;Assume Esc character.
               CMP     AL,ESC_CHAR             ;Is it Esc?  If yes, store
               JZ      SHORT_JUMP              ; char. and next state.
               JMP     WRITE_CHAR              ;Else, normal char; write it.

;------------------------------------------------;
BRACKET_STATE: MOV     BX,OFFSET SPECIAL_STATE ;Assume left bracket.
               CMP     AL,"["                  ;Is it left bracket?  If yes,
SHORT_JUMP:    JZ      STORE_STATE             ;store char. and next state.
               JMP     FLUSH_BUFFER            ;Else, flush Esc out of buffer.

;---------------------------------------------------------------;
; Must process <ESC>[2J (CLS) regardless if ANSI.COM ON or OFF. ;
;---------------------------------------------------------------;
SPECIAL_STATE: MOV     BX,OFFSET CLS_STATE     ;Assume Erase in Display code.
               CMP     AL,"2"                  ;Is it the "2" ?
               JZ      STORE_STATE             ;If yes, progress to next state.
               TEST    STATUS,OFF              ;Else, is ANSI OFF ?
               JNZ     FLUSH_BUFFER            ;If yes, flush Esc, bracket.
               MOV     BX,OFFSET PARAM_STATE   ;Else, check for first Set,
               CMP     AL,"="                  ; Reset Mode characters of
               JZ      STORE_STATE             ; "=" and "?".
               CMP     AL,"?"
               JZ      STORE_STATE             ;If found, store.
               JMP     SHORT DO_PARAMETER      ;Else, check other codes.

;------------------------------------------------;
CLS_STATE:     CMP     AL,"J"                  ;Is it second character of CLS?
               MOV     DI,OFFSET COMMAND_END   ;If yes, execute
               JZ      EXECUTE                 ; Erase in Display procedure.
               TEST    STATUS,OFF              ;ANSI OFF?  If yes, flush buffer.
               JNZ     FLUSH_BUFFER            ; If not fall through to process.
               MOV     BYTE PTR NUMBER_BUFFER,2   ;Store the previous 2.
DO_PARAMETER:  MOV     ANSI_STATE,OFFSET PARAM_STATE  ;Parameter state.

;------------------------------------------------;
PARAM_STATE:   CALL    CK_QUOTE                ;Is it single or double quotes?
               JZ      STORE_STATE             ;If yes, store string state.
               CMP     AL,";"                  ;Is it semi-colon delimiter?
               JNZ     CK_NUMBER               ;If no, check if number.
               INC     NUMBER_COUNT            ;Else, increment number count.
               JMP     SHORT BUFFER_CHAR       ;Buffer the semi-colon.

CK_NUMBER:     CMP     AL,"0"                  ;Is it below 0 ?
               JB      FLUSH_BUFFER            ;If yes, illegal; flush buffer.
               CMP     AL,"9"                  ;Else, is it above 9 ?
               JA      DO_COMMAND              ;If yes, check for command char.
               CALL    ACCUMULATE              ;Else it's a number; accumulate.
               JMP     SHORT BUFFER_CHAR       ;Buffer the character.

DO_COMMAND:    MOV     DI,OFFSET COMMAND_TABLE ;Point to legal ANSI commands.
               MOV     CX,COMMAND_LENGTH       ;Number of commands.
               REPNZ   SCASB                   ;Check for a match.
               JNZ     FLUSH_BUFFER            ;If no match, flush sequence.
               INC     NUMBER_COUNT            ;Else, increment for last number.
               MOV     DI,OFFSET COMMAND_END   ;Point to appropriate command
               SHL     CX,1                    ; processing procedure.
               SUB     DI,CX
EXECUTE:       CALL    GET_BIOS_DATA           ;Get cursor position data.
               CALL    DS:[DI]                 ;Do command subroutine.
               JMP     SHORT FLUSH_END         ;Clear buffer.

;------------------------------------------------;
QUOTE_STATE:   CMP     AL,QUOTE_TYPE           ;Is it an ending string quote?
               JNZ     BUFFER_CHAR             ;If no, buffer literal.
               MOV     BX,OFFSET PARAM_STATE   ;Else, back to parameter parsing.

;------------------------------------------------;
STORE_STATE:   MOV     ANSI_STATE,BX           ;Store the ANSI state.

;------------------------------------------------;
BUFFER_CHAR:   MOV     DI,ESC_COUNT            ;Buffer the character in case
               CMP     DI,ESC_BUFFER_SIZE      ; ending ANSI command is illegal.
               JZ      FLUSH_BUFFER            ;If buffer full, flush.
               ADD     DI,OFFSET ESC_BUFFER    ;Point to next buffer position.
               STOSB                           ;Store the character.
               INC     ESC_COUNT               ;Increment the sequence count.
               RET

;------------------------------------------------;
FLUSH_BUFFER:  PUSH    AX                      ;Save the current character.
               MOV     SI,OFFSET ESC_BUFFER    ;Point to the sequence buffer.
               MOV     CX,ESC_COUNT            ;Count of buffered characters.
NEXT_FLUSH:    LODSB                           ;Retrieve one.
               PUSH    CX                      ;Save counter and pointer.
               PUSH    SI
               CALL    WRITE_CHAR              ;Write character to screen.
               POP     SI                      ;Restore counter and pointer.
               POP     CX
               LOOP    NEXT_FLUSH              ;Flush entire buffer.
               POP     AX                      ;Retrieve last character.
               CALL    WRITE_CHAR              ;Write it also.
FLUSH_END:     MOV     ESC_COUNT,0                   ;Reset counter.
               MOV     ANSI_STATE,OFFSET ESC_STATE   ;Back to Esc state.
               MOV     NUMBER_COUNT,0                ;Reset parameter counter.
               PUSH    CS                            ;Point to our data.
               POP     ES
               MOV     DI,OFFSET NUMBER_BUFFER       ;Clear number buffer
               MOV     CX,ESC_BUFFER_SIZE / 2        ; to zeros.
               XOR     AX,AX
               REP     STOSW
               RET

;------------------------------------------------;
; Slow video writes are via BIOS Write TTY.      ;
;------------------------------------------------;
WRITE_CHAR:    MOV     DI,OFFSET FORMAT_CHARS  ;Let BIOS process carriage
               MOV     CX,FORMAT_LENGTH        ; return, linefeed, backspace
               REPNZ   SCASB                   ; and bell via
               JZ      WRITE_TTY               ; TTY.

               CALL    GET_BIOS_DATA           ;Get BIOS video data.
               CMP     AL,9                    ;Is character a TAB?
               JNZ     CK_ACTIVE               ;If no, process normally.
               MOV     CX,CURSOR_POSN          ;Else, expand TAB to
               AND     CX,7                    ; appropriate space characters.
               NEG     CX
               ADD     CX,8
NEXT_TAB:      PUSH    CX
               MOV     AL,SPACE
               CALL    CK_ACTIVE
               POP     CX
               LOOP    NEXT_TAB
               RET

CK_ACTIVE:     TEST    STATUS,OFF              ;Is ANSI OFF?
               JNZ     WRITE_TTY               ;If yes, write via BIOS TTY.
CK_FAST:       CALL    CK_SLOW_TEXT            ;Is ANSI SLOW or in graphics
               JNC     WRITE_FAST              ; mode? If no, write fast.

WRITE_SLOW:    PUSH    AX                      ;Else, write character/attribute
               MOV     CX,1                    ; at current cursor position
               MOV     BH,ACTIVE_PAGE          ; via BIOS.
               MOV     BL,ATTRIBUTE
               MOV     AH,9
               INT     10H
               POP     AX

               CMP     LINE_WRAP,ON            ;Is line wrap on?
               JZ      TTY                     ;If yes, continue.
               MOV     CX,CRT_COLS             ;Else, cursor at rightmost
               DEC     CL                      ; column?
               CMP     CL,CURSOR_COL           ;If yes, continue, else
               JNZ     TTY                     ; return without writing.
               RET

;------------------------------------------------;
WRITE_TTY:     MOV     BL,7                    ;Attribute in graphics mode.
TTY:           MOV     AH,0EH
               INT     10H
               RET

;----------------------------------------------------------------------------;
; Fast screen writes are directly to the video buffer without retrace check. ;
;----------------------------------------------------------------------------;
WRITE_FAST:    PUSH    ES                      ;Preserve extra segment.
               MOV     DX,CURSOR_POSN          ;Retrieve cursor position.
               CALL    VIDEO_SETUP             ;Calculate video address.
               MOV     AH,ATTRIBUTE            ;Retrieve attribute.
               STOSW                           ;Put char/attrib in video buffer.
               INC     DL                      ;Increment cursor column.
               CMP     DL,BYTE PTR CRT_COLS    ;End of row?
               JB      UPDATE_CURSOR           ;If no, update cursor.

               CMP     LINE_WRAP,OFF           ;Else, line wrap off?
               JZ      FAST_END                ;If yes, don't move cursor.
               XOR     DL,DL                   ;Else, column zero.
               INC     DH                      ;Next row.
               CALL    INFORMATION             ;Get displayable row info.
               CMP     DH,AL                   ;Beyond the bottom of screen?
               JBE     UPDATE_CURSOR           ;If no, update cursor.

               DEC     DH                      ;Else, cursor to original row.
               MOV     DI,CRT_START            ;Point destination to top.
               MOV     SI,DI                   ;Point source to second row
               MOV     AX,CRT_COLS             ; by adding width in columns
               PUSH    AX                      ; twice for char/attribute.
               ADD     SI,AX
               ADD     SI,AX
               MUL     DH                      ;Times displayable rows - 1.
               MOV     CX,AX                   ; equals char/attrib to scroll.
               PUSH    DS                      ;Save data segment and
               PUSH    ES                      ; point to video segment.
               POP     DS
               REP     MOVSW                   ;Scroll the screen.
               POP     DS                      ;Restore data segment.
               POP     CX                      ;Retrieve CRT columns.
               MOV     AL,SPACE                ;Write space/attrib to
               MOV     AH,ATTRIBUTE            ; bottom row.
               REP     STOSW

UPDATE_CURSOR: CALL    SET_CURSOR              ;Update the cursor position.
FAST_END:      POP     ES                      ;Restore extra segment.
               RET

;************* SUPPORT ROUTINES *************;

CK_QUOTE:      MOV     BX,OFFSET QUOTE_STATE   ;Assume quote state.
               MOV     AH,DOUBLE_QUOTE
               CMP     AL,AH                   ;Is it double quote?
               JZ      GOT_QUOTE               ;If yes, string delimiter.
               MOV     AH,SINGLE_QUOTE         ;Is it single quote?
               CMP     AL,AH                   ;Is yes, string delimiter.
               JNZ     QUOTE_END               ;Else, return ZR = 0.
GOT_QUOTE:     MOV     QUOTE_TYPE,AH           ;Store as matching string end.
QUOTE_END:     RET

;------------------------------------------------;
ACCUMULATE:    PUSH    AX                      ;Preserve number character.
               SUB     AL,"0"                  ;Convert ASCII to binary.
               MOV     CL,AL                   ;Save the number.
               MOV     AX,10                   ;Multiply previous count by 10.
               MOV     BX,NUMBER_COUNT
               MUL     BYTE PTR NUMBER_BUFFER[BX]
               ADD     AL,CL                            ;Add in new number
               MOV     BYTE PTR NUMBER_BUFFER[BX],AL    ; and store.
               POP     AX
               RET

;---------------------------------------------------------------------------;
; OUTPUT:  CY = 1 if write SLOW mode or in graphics mode; CY = 0 otherwise. ;
;---------------------------------------------------------------------------;
CK_SLOW_TEXT:  TEST    STATUS,SLOW
               JNZ     SLOW_MODE
               CMP     CRT_MODE,7
               JZ      TEXT_MODE
               CMP     CRT_MODE,3
               JA      SLOW_MODE
TEXT_MODE:     CLC
               RET

SLOW_MODE:     STC
               RET

;-------------------------------------;
; OUTPUT:  AL = Screen rows minus one ;
;-------------------------------------;
INFORMATION:   PUSH    DS                      ;Save data segment.
               MOV     AX,40                   ;Point to BIOS data.
               MOV     DS,AX
               MOV     AL,DS:[84H]             ;Retrieve rows - 1.
               OR      AL,AL                   ;BIOS supported?
               JNZ     INFO_END                ;If yes, done here.
               MOV     AL,24                   ;Else, assume 25 lines.
INFO_END:      POP     DS
               RET

;------------------------------------------------------------------------------;
; INPUT:  DX = Cursor position.                                                ;
; OUTPUT: ES = Video buffer segment; DI = Video buffer offset; AX,DX preserved ;
;------------------------------------------------------------------------------;
VIDEO_SETUP:   PUSH    AX
               MOV     AX,CRT_COLS             ;Retrieve CRT columns.
               MUL     DH                      ;Times cursor row.
               MOV     BL,DL
               XOR     BH,BH
               ADD     AX,BX                   ;Plus cursor column.
               SHL     AX,1                    ;Times two for attribute.
               MOV     DI,CRT_START            ;Plus starting video offset.
               ADD     DI,AX                   ;Equals destination.

               MOV     BX,0B000H               ;Assume mono card.
               CMP     ADDR_6845,3B4H          ;Is it mono port?
               JZ      VIDEO_SEGMENT           ;If yes, guessed right.
               ADD     BX,800H                 ;Else, point to color segment.
VIDEO_SEGMENT: MOV     ES,BX
               POP     AX
               RET

;------------------------------------------------;
; Move BIOS video data into our data segment.    ;
;------------------------------------------------;
GET_BIOS_DATA: PUSH    DS
               PUSH    DI                      ;Point to BIOS data segment.
               MOV     BX,40H
               MOV     DS,BX
               MOV     SI,BIOS_ACTIVE_PAGE     ;Start with active page.
               MOV     DI,OFFSET ACTIVE_PAGE
               MOVSB                           ;Retrieve active page
               MOVSW                           ; and address of 6845 port.
               MOV     SI,BIOS_CRT_MODE        ;Retrieve CRT mode, CRT columns,
               MOV     CX,CRT_DATA_LENGTH      ; CRT length, CRT start.
               REP     MOVSB
               MOV     BL,ES:ACTIVE_PAGE       ;Use active page as index
               XOR     BH,BH                   ; of active cursor position.
               SHL     BX,1
               ADD     SI,BX
               MOVSW
               POP     DI
               POP     DS
               RET

;----------------------------------------------------------------------------;
; OUTPUT: BL = First parameter; BH = Second parameter; DX = cursor position. ;
;----------------------------------------------------------------------------;
ADJUST_NUMBER: MOV     BX,WORD PTR NUMBER_BUFFER
               OR      BH,BH
               JNZ     ADJUST_AL               ;If either parameter zero,
               INC     BH                      ; increment to convert
ADJUST_AL:     OR      BL,BL                   ; to base one.
               JNZ     ADJUST_END
               INC     BL
ADJUST_END:    MOV     DX,CURSOR_POSN          ;Return cursor position.
               RET

;--------------------------------------------------------------------------;
; INPUT:  AX = number; BP = 0 if console output; BP = 1 if storage output. ;
;--------------------------------------------------------------------------;
DECIMAL_OUT:   MOV     BX,10                   ;Divisor of ten.
               XOR     CX,CX                   ;Zero in counter.
NEXT_COUNT:    XOR     DX,DX                   ;Zero in high half.
               DIV     BX                      ;Divide by ten.
               ADD     DL,"0"                  ;Convert to ASCII.
               PUSH    DX                      ;Save results.
               INC     CX                      ;Also increment count.
               CMP     AX,0                    ;Are we done?
               JNZ     NEXT_COUNT              ;Continue until zero.
               OR      BP,BP                   ;If BP zero, output to screen.
               JNZ     DEVICE_OUTPUT           ;Else, store in buffer.

REPORT_OUTPUT: POP     AX                      ;Retrieve number.
               CALL    PRINT_CHAR              ;Display it.
               LOOP    REPORT_OUTPUT
               RET

DEVICE_OUTPUT: POP     AX                      ;Retrieve number.
               STOSB                           ;Store it
               LOOP    DEVICE_OUTPUT
               RET

;************* ANSI COMMAND SUBSET *************;

CLS:           CALL    INFORMATION             ;Get displayable rows.
               MOV     DH,AL                   ;Store in DH.
               MOV     BH,7                    ;Assume normal attribute.
               TEST    STATUS,OFF              ;Is ANSI OFF?
               JNZ     CLS_SLOW                ;If yes, CLS via BIOS.
               MOV     BH,ATTRIBUTE            ;Else, requested attribute.
               CALL    CK_SLOW_TEXT
               JC      CLS_SLOW                ;If ANSI SLOW, via BIOS.

CLS_FAST:      MOV     AH,BH                   ;Else, attribute in high half.
               MOV     AL,SPACE                ;Space character in low half.
               XOR     DX,DX                   ;Cursor position home.
               CALL    VIDEO_SETUP             ;Calculate video address.
               MOV     CX,CRT_LEN              ;Retrieve CRT length.
               SHR     CX,1                    ;Times two for attribute.
               REP     STOSW                   ;Write directly to video buffer.
               JMP     SHORT SET_CURSOR        ;Set the cursor top left corner.

CLS_SLOW:      MOV     DL,BYTE PTR CRT_COLS    ;Retrieve CRT columns.
               DEC     DL                      ;Adjust to zero base.
               XOR     CX,CX                   ;Scroll active page.
               MOV     AX,600H
               INT     10H
               XOR     DX,DX                   ;Home the cursor.
               JMP     SHORT SET_CURSOR

;------------------------------------------------;
CURS_POSITION:                                 ;These two commands are the same.
HORZ_VERT_POS: CALL    INFORMATION             ;Returns AL = screen rows.
               CALL    ADJUST_NUMBER           ;Returns BL,BH = parameters.
               SUB     BX,101H                 ;Zero based.
               CMP     BL,AL                   ;If cursor request within
               JA      CURSOR_END              ; boundaries of screen, set it.
               CMP     BH,BYTE PTR CRT_COLS
               JAE     CURSOR_END
               XCHG    BH,BL
               MOV     DX,BX

SET_CURSOR:    MOV     BH,ACTIVE_PAGE          ;Set cursor via BIOS.
               MOV     AH,2
               INT     10H
CURSOR_END:    RET

;------------------------------------------------;
CURSOR_UP:     CALL    ADJUST_NUMBER           ;Move cursor up one or more rows
               OR      DH,DH                   ; without changing column.
               JZ      CURSOR_END              ;If already at top, ignore.
               SUB     DH,BL
               JNC     SET_CURSOR              ;Stay in bounds.
               XOR     DH,DH
               JMP     SHORT SET_CURSOR

;------------------------------------------------;
CURSOR_DOWN:   CALL    INFORMATION             ;Returns AL = screen rows.
               CALL    ADJUST_NUMBER           ;Returns BL,BH =nos.; DX = cursor
               CMP     DH,AL                   ;Move cursor down requested
               JZ      CURSOR_END              ; rows without changing column.
               ADD     DH,BL
               CMP     DH,AL
               JNA     SET_CURSOR
               MOV     DH,AL                   ;Stay in bounds.
               JMP     SHORT SET_CURSOR

;------------------------------------------------;
CURS_FORWARD:  CALL    ADJUST_NUMBER           ;Returns BL,BH =nos.; DX = cursor
               MOV     BH,BYTE PTR CRT_COLS    ;Retrieve displayable columns.
               DEC     BH                      ;Adjust to zero base.
               CMP     DL,BH                   ;Move cursor forward one or more
               JZ      CURSOR_END              ; columns without changing row.
               ADD     DL,BL
               CMP     DL,BH
               JNA     SET_CURSOR
               MOV     DL,BH                   ;Stay in bounds.
               JMP     SHORT SET_CURSOR

;------------------------------------------------;
CURS_BACKWARD: CALL    ADJUST_NUMBER           ;Returns BL,BH =nos.; DX = cursor
               OR      DL,DL                   ;Move cursor backward one or
               JZ      CURSOR_END              ; more columns without changing
               SUB     DL,BL                   ; row.  Ignore if already left.
               JNC     SET_CURSOR
               XOR     DL,DL                   ;Stay in bounds.
               JMP     SHORT SET_CURSOR

;--------------------------------------------------------;
; Report cursor position via console; Format: ESC[#;#R   ;
;--------------------------------------------------------;
DEVICE_STATUS: MOV     DI,OFFSET DEVICE_STATUS_BUFFER
               MOV     AL,ESC_CHAR
               STOSB                           ;Store leading Esc, bracket
               MOV     AL,"["                  ;in special Device Status Buffer.
               STOSB

               MOV     AL,CURSOR_ROW           ;Retrieve cursor row.
               XOR     AH,AH                   ;Zero in high half.
               INC     AX                      ;Convert to base one.
               MOV     BP,1                    ;Flag as storage.
               CALL    DECIMAL_OUT             ;Convert to ASCII.
               MOV     AL,";"                  ;Store delimiting semi-colon.
               STOSB
               MOV     AL,CURSOR_COL           ;Do same with cursor column.
               XOR     AH,AH
               INC     AX
               CALL    DECIMAL_OUT
               MOV     AL,"R"                  ;Add command character
               STOSB
               MOV     AL,CR                   ; and carriage return.
               STOSB
               SUB     DI,OFFSET DEVICE_STATUS_BUFFER   ;Setup for console out.
               MOV     REASSIGN_COUNT,DI
               MOV     REASSIGN_POS,OFFSET DEVICE_STATUS_BUFFER
               MOV     REASSIGN_FLAG,ON
               MOV     REMOVE_FLAG,OFF
               RET

;------------------------------------------------;
SAVE_CURSOR:   MOV     DX,CURSOR_POSN
               MOV     SAVE_POSITION,DX
               RET

;------------------------------------------------;
RESTORE_CURS:  MOV     DX,SAVE_POSITION
               JMP     SET_CURSOR

;------------------------------------------------;
ERASE_IN_LINE: MOV     DX,CURSOR_POSN          ;Erase from the cursor to
               MOV     CX,CRT_COLS             ; the end of the line, including
               SUB     CL,DL                   ; the current cursor position.
               CALL    CK_SLOW_TEXT
               JC      ERASE_SLOW              ;If ANSI ON and not graphics,
               CALL    VIDEO_SETUP             ; write directly to video buffer
               MOV     AL,SPACE                ; with space/attribute.
               MOV     AH,ATTRIBUTE
               REP     STOSW
               RET

ERASE_SLOW:    MOV     CX,DX                   ;Else, erase SLOW via
               MOV     DL,BYTE PTR CRT_COLS    ; BIOS scroll active page.
               DEC     DL
               MOV     BH,ATTRIBUTE
               MOV     AX,601H
               INT     10H
               RET

;------------------------------------------------;
;            Set Graphics Rendition              ;
;------------------------------------------------;
SGR:           MOV     SI,OFFSET NUMBER_BUFFER     ;Point to number parameters.
NEXT_SGR:      LODSB                               ;Retrieve parameter.
               MOV     DI,OFFSET ATTRIBUTE_TABLE   ;Look up attribute in
               MOV     CX,ATTRIBUTE_LENGTH         ; translation table.
               REPNZ   SCASB
               JNZ     SGR_LOOP

               MOV     DI,OFFSET ATTRIBUTE_END
               SHL     CX,1
               SUB     DI,CX
               MOV     AX,[DI]
               AND     ATTRIBUTE,AL            ;If match, AND with strip mask.
               OR      ATTRIBUTE,AH            ;OR with add mask.
SGR_LOOP:      DEC     NUMBER_COUNT            ;Do all parameters.
               JNZ     NEXT_SGR
               RET

;------------------------------------------------;
SET_MODE:      MOV     AH,ON                   ;Assume command 7,
               JMP     SHORT CK_WRAP           ; turn line wrap on.

;------------------------------------------------;
RESET_MODE:    MOV     AH,OFF                     ;Assume turn line wrap off.
CK_WRAP:       MOV     AL,BYTE PTR NUMBER_BUFFER  ;Retrieve number parameter.
               CMP     AL,7                       ;Is it 7?
               JZ      SET_WRAP                ;If yes, set wrap mode.
               JB      DO_MODE                 ;1 - 6 valid modes.
               CMP     AL,14                   ;14 - 16 valid modes.
               JB      MODE_END
               CMP     AL,19
               JA      MODE_END                ;If above 16, illegal.
DO_MODE:       XOR     AH,AH                   ;Else, set video mode
               INT     10H                     ; to parameter.
               RET

SET_WRAP:      MOV     LINE_WRAP,AH
MODE_END:      RET

;--------------------------------------------------------------------;
; Keyboard Key Reassignment:  First convert ASCII numbers to binary, ;
; parse out delimiting semi-colons, and quote string delimiters.     ;
;--------------------------------------------------------------------;
REASSIGNMENT:  MOV     CX,ESC_COUNT            ;Retrieve length of Esc sequence.
               DEC     CX                          ;Adjust.
               MOV     SI,OFFSET ESC_BUFFER + 2    ;Point past Esc, bracket.
               MOV     DI,OFFSET PARSE_BUFFER      ;Point to parse storage.
NEXT_STRING:   MOV     QUOTE_TYPE,0                ;Reset quote type.
NEXT_NUM:      XOR     DL,DL                   ;Use DL to carry number; init = 0
               XOR     BP,BP                   ;Use BP as number flag.
NEXT_PARAM:    LODSB                           ;Retrieve a byte.
               DEC     CX                      ;Decrement string length counter.
               JZ      PARSE_END               ;If zero, done.
               MOV     AH,QUOTE_TYPE           ;Else, retrieve quote type.
               OR      AH,AH                   ;If zero, not in string.
               JNZ     QUOTE_MODE              ;Else, go to string mode.
               CALL    CK_QUOTE                ;Is character a quote?
               JZ      NEXT_PARAM              ;If yes, ignore.
               CMP     AL,";"                  ;Else, is it semi-colon?
               JZ      STORE_NUMBER            ;If yes, number delimiter.

               SUB     AL,"0"                  ;Else, must be number; convert
               MOV     DH,AL                   ; to binary; save in DH.
               MOV     AX,10                   ;Multiply current total by ten.
               MUL     DL
               ADD     AL,DH                   ;Add new number.
               MOV     DL,AL                   ;Save in DL.
               MOV     BP,1                    ;Flag that number mode active.
               JMP     SHORT NEXT_PARAM        ;Next parameter.

STORE_NUMBER:  OR      BP,BP                   ;If number mode flag not set then
               JZ      NEXT_PARAM              ;semi-colon not prefaced with no.
               MOV     AL,DL                   ;Else, store number.
               STOSB
               JMP     SHORT NEXT_NUM          ;Reset number carrying registers.

QUOTE_MODE:    CMP     AL,AH                   ;Is current char a string ending
               JZ      NEXT_STRING             ; quote?  If yes, exit quote mode
               STOSB                           ;Else, store char as literal.
               JMP     SHORT NEXT_PARAM

;----------------------------------------------------------------------------;
; Remove duplicate assignments if removal leaves room for new assignment.    ;
; If no duplicate and room, add new assignment, else flush buffer to screen. ;
;----------------------------------------------------------------------------;
PARSE_END:     OR      BP,BP                   ;Was last parameter a number?
               JZ      CK_LENGTH               ;If no, skip.
               MOV     AL,DL                   ;Else, store the last number.
               STOSB
CK_LENGTH:     SUB     DI,OFFSET PARSE_BUFFER - 2   ;Calculate string length
               MOV     AX,DI                        ; including word for length.
               MOV     BX,WORD PTR PARSE_BUFFER     ;BL=new first ASCII; BH=2nd.
               MOV     CX,5                         ;String length has to be at
               OR      BL,BL                   ;least word + 2 for old + new = 5
               JZ      CK_LEGAL                ; for extended key reassignment.
               DEC     CX                      ;And word + 1 for old + new = 4
CK_LEGAL:      CMP     AX,CX                   ; for regular ASCII reassignment.
               JB      ASSIGN_FLUSH            ;If not, illegal; flush buffer.
               MOV     BP,BUFFER_END           ;BP to carry buffer end pointer.
               CALL    CK_MATCH                ;Is char already reassigned?
               JC      CK_ROOM                 ;If no, check room for new.

CK_REMOVE:     MOV     CX,DX                   ;REASSIGN_END - string end
               SUB     CX,SI                   ; = bytes to move.
               JZ      CK_ROOM                 ;If zero, last string.
               SUB     DX,[DI]                 ;Is REASSIGN_END - old string
               ADD     DX,AX                   ; + new string >
               CMP     DX,BP                   ; BUFFER_END?
               JA      ASSIGN_FLUSH            ;If yes, flush buffer to screen.
               REP     MOVSB                   ;Else, move them down in buffer.
               JMP     SHORT STORE_NEW

CK_ROOM:       ADD     DX,AX                   ;New string + current strings.
               CMP     DX,BP                   ;Greater than buffer size?
               JA      ASSIGN_FLUSH            ;If yes, flush new string.
STORE_NEW:     MOV     SI,OFFSET PARSE_BUFFER  ;Else, room for new string.
               STOSW                           ;Store string length first.
               MOV     CX,AX                   ;Adjust counter.
               DEC     CX
               DEC     CX
               REP     MOVSB                   ;Store the actual string.
               MOV     REASSIGN_END,DI         ;Store new string end.
               RET

ASSIGN_FLUSH:  MOV     AL,"p"                  ;If buffer full, flush string
               JMP     FLUSH_BUFFER            ; including ending "p" command.

;------------------------------------------------------------------------------;
; INPUT:  BL = first ASCII code to match; BH = extended if BL = 0              ;
; OUTPUT: CY = 1 if no match found; CY = 0 if match found.                     ;
;         DI points to string length of match; DI+2 points to start of string. ;
;         SI = end of string; DX = REASSIGN_END; BP = BUFFER_END               ;
;------------------------------------------------------------------------------;
CK_MATCH:      MOV     DX,REASSIGN_END                ;Current strings end.
               MOV     SI,OFFSET REASSIGNMENT_BUFFER  ;Point to buffer.
NEXT_MATCH:    MOV     DI,SI                          ;Current record.
               CMP     DI,DX                   ;End of strings?
               JAE     NO_MATCH                ;If yes, no match.
               MOV     CX,[DI+2]               ;CL=current first ASCII; CH=2nd
               ADD     SI,[DI]                 ;Point to next record.
               CMP     BL,CL                   ;First characters match?
               JNZ     NEXT_MATCH              ;If no, check next record.
               OR      BL,BL                   ;Extended code? ie zero.
               JNZ     MATCH                   ;If no, then match.
               CMP     BH,CH                   ;Else, check second code.
               JNZ     NEXT_MATCH              ;If not same, no match.
MATCH:         CLC                             ;Else return with CY = 0
               RET

NO_MATCH:      STC                             ;No match; CY = 1.
               RET

;----------------------------------------------------------------------;
; Buffer area will write over disposable data and initialization code. ;
;----------------------------------------------------------------------;
ESC_BUFFER            =       $
NUMBER_BUFFER         =       ESC_BUFFER + ESC_BUFFER_SIZE
PARSE_BUFFER          =       NUMBER_BUFFER
DEVICE_STATUS_BUFFER  =       PARSE_BUFFER + ESC_BUFFER_SIZE
DEVICE_STATUS_SIZE    =       11
REASSIGNMENT_BUFFER   =       DEVICE_STATUS_BUFFER + DEVICE_STATUS_SIZE

;              DISPOSABLE DATA
;              ---------------

SYNTAX         LABEL   BYTE
DB      "Usage:  ANSI [FAST | SLOW][ON | OFF][/B nnn][/C][/U]",CR,LF
DB      "FAST = direct screen writes; default",CR,LF
DB      "SLOW = screen writes via BIOS",CR,LF
DB      "ON/OFF = active/inactive; default is ON",CR,LF
DB      "nnn = buffer size bytes (0-60K) reserved for reassignment; "
DB      "default 200",CR,LF
DB      "/U = Uninstall"
CR_LF   DB     CR,LF,"$"

STATUS_MSG     DB      "Status: $"
BUFFER_MSG     DB      CR,LF,"Buffer size: $"
BYTES_FREE     DB      CR,LF,"Bytes free:  $"
ANSI_SYS_MSG   DB      "ANSI.SYS is installed so "
NOT_INSTALLED  DB      "ANSI.COM not installed",CR,LF,"$"
CON            DB      "CON"
CON_OFFSET     EQU     10

SIZE_MSG       DB      "Uninstall to change buffer size",CR,LF,"$"
UNLOAD_MSG     DB      "ANSI can't be uninstalled",CR,LF
               DB      "Uninstall resident programs in reverse order",CR,LF,"$"
NOT_ENOUGH     DB      "Not enough memory",CR,LF,"$"
ALLOCATE_MSG   DB      "Memory allocation error",CR,LF,BELL,"$"
INSTALL_MSG    DB      "ANSI.COM Installed",CR,LF,"$"
UNINSTALL_MSG  DB      "ANSI.COM Uninstalled",CR,LF,"$"

;--------------------------------------------------------------------;
; Search memory for a copy of our code, to see if already installed. ;
;--------------------------------------------------------------------;
INITIALIZE     PROC    NEAR
               CLD                             ;All string operations forward.
               MOV     BX,OFFSET START         ;Point to start of code.
               NOT     BYTE PTR [BX]           ;Change a byte so no false match.
               XOR     DX,DX                   ;Start at segment zero.
               MOV     AX,CS                   ;Store our segment in AX.
NEXT_PARAG:    INC     DX                      ;Next paragraph.
               MOV     ES,DX
               CMP     DX,AX                   ;Is it our segment?
               JZ      ANNOUNCE                ;If yes, search is done.
               MOV     SI,BX                   ;Else, point to our signature.
               MOV     DI,BX                   ; and offset of possible match.
               MOV     CX,16                   ;Check 16 bytes for match.
               REP     CMPSB
               JNZ     NEXT_PARAG              ;If no match, keep looking.

;------------------------------------------------;
ANNOUNCE:      MOV     DX,OFFSET SIGNATURE     ;Display our signature.
               CALL    PRINT_STRING
               MOV     DX,OFFSET SYNTAX        ;And syntax.
               CALL    PRINT_STRING
               MOV     SI,81H                  ;Point to command line.
NEXT_CAP:      LODSB                           ;Capitalize parameters.
               CMP     AL,CR
               JZ      PARSE
               CMP     AL,"a"
               JB      NEXT_CAP
               CMP     AL,"z"
               JA      NEXT_CAP
               AND     BYTE PTR [SI - 1],5FH
               JMP     SHORT NEXT_CAP

;------------------------------------------------;
PARSE:         MOV     SI,81H                  ;Point to command line again.
NEXT_PARA:     XOR     AX,AX                   ;Position in status parameters.
               MOV     BX,4                    ;Status parameters each 4 bytes.
NEXT_STATUS:   MOV     DI,OFFSET PARAMETERS    ;Point to "OFF ON  SLOWFAST"
               ADD     DI,AX                   ;Point to next parameter.
               ADD     AX,BX
               CMP     AX,LAST_PARAMETER       ;Check all four possible statuses
               JA      CK_SWITCHES
               PUSH    SI                      ;Save command line pointer.
               MOV     CX,2                    ;Check first two bytes for match.
               REP     CMPSB
               POP     SI                      ;Recover command line pointer.
               JNZ     NEXT_STATUS

               DIV     BL                      ;If match, divide offset by four.
               MOV     CL,1                    ;Set a bit to match offset.
NEXT_SHIFT:    SHL     CL,1
               DEC     AL
               JNZ     NEXT_SHIFT
               SHR     CL,1                    ;Adjust.
               MOV     AH,STATUS_MASK          ;Retrieve appropriate ON/OFF
               CMP     CL,ON                   ; or FAST/SLOW mask.
               JBE     ADD_STATUS
               ROL     AH,1
               ROL     AH,1

ADD_STATUS:    AND     ES:STATUS,AH            ;Mask off old status.
               OR      ES:STATUS,CL            ;Add new status.
               INC     SI                      ;Bump command line pointer.
               INC     SI

CK_SWITCHES:   LODSB                           ;Get a byte.
               CMP     AL,CR                   ;Is it carriage return?
               JZ      INSTALL                 ;If yes, done here.
               CMP     AL,"/"                  ;Is there a switch character?
               JNZ     NEXT_PARA               ;If no, keep looking.
               LODSB                           ;Else, get the switch character.
               CMP     AL,"B"                  ;Is it "B" ?
               JNZ     CK_C                    ;If no, check "C".
               CALL    CK_INSTALLED            ;Else, see if already installed.
               JZ      GET_SIZE                ;If no, get buffer request size.
               MOV     DX,OFFSET SIZE_MSG      ;Else, display error message.
               CALL    PRINT_STRING
               JMP     SHORT NEXT_PARA
GET_SIZE:      CALL    DECIMAL_INPUT           ;Get number parameter.
               CMP     BX,REASSIGNMENT_MAX     ;If greater than maximum, use
               JBE     STORE_BUFFER            ; maximum, else use requested
               MOV     BX,REASSIGNMENT_MAX     ; size.
STORE_BUFFER:  MOV     REASSIGNMENT_SIZE,BX
               ADD     BX,OFFSET REASSIGNMENT_BUFFER  ;Calculate end of buffer.
               MOV     BUFFER_END,BX
               JMP     SHORT NEXT_PARA

CK_C:          CMP     AL,"C"                  ;Is it "C" ?
               JNZ     CK_U                    ;If not, check "U".
               MOV     ES:REASSIGN_END,OFFSET REASSIGNMENT_BUFFER  ;Clear buffer
CK_U:          CMP     AL,"U"                  ;Is it "U" ?
               JZ      DO_U                    ;If yes, try to uninstall.
               JMP     NEXT_PARA               ;Else, next parmater.
DO_U:          CALL    CK_INSTALLED            ;Else, see if installed.
               MOV     DX,OFFSET NOT_INSTALLED ;If no, exit with error message.
               JZ      LILLY_PAD               ;Too far for short jump.
               JMP     UNINSTALL               ;Else, uninstall.

;------------------------------------------------;
INSTALL:       CALL    STATUS_REPORT           ;Display status.
               CALL    CK_INSTALLED            ;Check if already installed.
               JZ      CK_AVAILABLE            ;If no, see if enough memory.
               OR      AL,AL                   ;Else, done.
               JMP     EXIT                    ;Exit with ERRORLEVEL = 0.

;--------------------------------;
; This is the install procedure. ;
;--------------------------------;
CK_AVAILABLE:  MOV     BP,OFFSET REASSIGNMENT_BUFFER   ;TSR ends at end
               ADD     BP,REASSIGNMENT_SIZE            ; of reassignment buffer.
               ADD     BP,15                           ;Round up.
               CMP     BP,DS:[6]               ;Buffer > PSP bytes in segment?
               MOV     DX,OFFSET NOT_ENOUGH    ;If yes, exit without installing
               JA      MSG_EXIT                ; with message.

               MOV     AX,3529H                ;Get undocumented INT 29 vector.
               INT     21H
               MOV     SI,OFFSET CON           ;Does it point to ANSI.SYS?
               MOV     DI,CON_OFFSET           ;Check by looking for "CON"
               MOV     CX,3                    ; as device name.
               REP     CMPSB
               MOV     DX,OFFSET ANSI_SYS_MSG  ;Exit with error message if
LILLY_PAD:     JZ      MSG_EXIT                ;ANSI.SYS loaded.

               MOV     OLD_INT_29[0],BX        ;Else save old interrupt.
               MOV     OLD_INT_29[2],ES
               MOV     DX,OFFSET ANSI_INT_29   ;Install new interrupt.
               MOV     AX,2529H
               INT     21H
               MOV     AX,3516H                ;Get INT 16 vector.
               INT     21H
               MOV     OLD_INT_16[0],BX        ;Save old interrupt.
               MOV     OLD_INT_16[2],ES
               MOV     DX,OFFSET ANSI_INT_16   ;Install new interrupt.
               MOV     AX,2516H
               INT     21H
               MOV     AX,3521H                ;Get DOS 21h interrupt.
               INT     21H
               MOV     OLD_INT_21[0],BX        ;Save old interrupt.
               MOV     OLD_INT_21[2],ES
               MOV     DX,OFFSET ANSI_INT_21   ;Install new interrupt.
               MOV     AX,2521H
               INT     21H

               MOV     AX,DS:[2CH]             ;Get environment segment.
               MOV     ES,AX
               MOV     AH,49H                  ;Free up environment.
               INT     21H

               MOV     DX,OFFSET INSTALL_MSG   ;Display install message.
               CALL    PRINT_STRING
               CALL    FLUSH_END               ;Setup the number buffer.
               MOV     DX,BP                   ;Retrieve resident byte request.
               MOV     CL,4
               SHR     DX,CL                   ;Convert to paragraphs.
               MOV     AX,3100H                ;Return error code of zero.
               INT     21H                     ;Terminate but stay resident.

;-------------------------------------------------------------------;
; Exit.  Return ERRORLEVEL code 0 if successful, 1 if unsuccessful. ;
;-------------------------------------------------------------------;
MSG_EXIT:      CALL    PRINT_STRING
ERROR_EXIT:    MOV     AL,1                    ;ERRORLEVEL = 1.
EXIT:          MOV     AH,4CH                  ;Terminate.
               INT     21H

;---------------------------------------------------;
; This subroutine uninstalls the resident ANSI.COM. ;
;---------------------------------------------------;
UNINSTALL:     AND     ES:STATUS,NOT ON        ;Turn OFF ANSI, just in case
               OR      ES:STATUS,OFF           ; can't uninstall.
               MOV     CX,ES                   ;Save segment in CX.
               MOV     AX,3529H                ;Get interrupt 29h.
               INT     21H
               CMP     BX,OFFSET ANSI_INT_29   ;Has it been hooked by another?
               JNZ     UNINSTALL_ERR           ;If yes, exit with error message.
               MOV     BX,ES
               CMP     BX,CX                   ;Is the segment vector same?
               JNZ     UNINSTALL_ERR           ;If no, exit with error message.

               MOV     AX,3516H                ;Get interrupt 16h.
               INT     21H
               CMP     BX,OFFSET ANSI_INT_16   ;Has it been hooked by another?
               JNZ     UNINSTALL_ERR           ;If yes, exit with error message.
               MOV     BX,ES
               CMP     BX,CX                   ;Is the segment vector same?
               JNZ     UNINSTALL_ERR           ;If no, exit with error message.

               MOV     AX,3521H                ;Get interrupt 21h.
               INT     21H
               CMP     BX,OFFSET ANSI_INT_21   ;Has it been hooked by another?
               JNZ     UNINSTALL_ERR           ;If yes, exit with error message.
               MOV     BX,ES
               CMP     BX,CX                   ;Is the segment vector same?
               JNZ     UNINSTALL_ERR           ;If no, exit with error message.

               MOV     AH,49H                  ;Return memory to system pool.
               INT     21H
               MOV     DX,OFFSET ALLOCATE_MSG
               JC      MSG_EXIT                ;Display message if problem.

               MOV     DX,ES:OLD_INT_29[0]     ;Restore old INT 29.
               MOV     DS,ES:OLD_INT_29[2]
               MOV     AX,2529H
               INT     21H
               MOV     DX,ES:OLD_INT_16[0]     ;Restore old INT 16.
               MOV     DS,ES:OLD_INT_16[2]
               MOV     AX,2516H
               INT     21H
               MOV     DX,ES:OLD_INT_21[0]     ;Restore old INT 21.
               MOV     DS,ES:OLD_INT_21[2]
               MOV     AX,2521H
               INT     21H

               PUSH    CS
               POP     DS                      ;Point to our data.
               MOV     DX,OFFSET UNINSTALL_MSG ;Display uninstall message.
               CALL    PRINT_STRING
               OR      AL,AL                   ;Exit with ERRORLEVEL = 0.
               JMP     EXIT

UNINSTALL_ERR: MOV     ES,CX                   ;If error, display OFF status.
               CALL    STATUS_REPORT
               MOV     DX,OFFSET UNLOAD_MSG    ;And exit with error message.
               JMP     MSG_EXIT
INITIALIZE     ENDP

;--------------------------------------------------;
; INPUT:  SI points to parameter start.            ;
; OUTPUT: SI points to parameter end; BX = number. ;
;--------------------------------------------------;
DECIMAL_INPUT  PROC    NEAR
               XOR     BX,BX                   ;Start with zero as number.
NEXT_DECIMAL:  LODSB                           ;Get a character.
               CMP     AL,CR                   ;Carriage return?
               JZ      ADJUST_DEC              ;If yes, done here.
               CMP     AL,"/"                  ;Forward slash?
               JZ      ADJUST_DEC              ;If yes, done here.
               SUB     AL,"0"                  ;ASCII to binary.
               JC      NEXT_DECIMAL            ;If not between 0 and 9, skip.
               CMP     AL,9
               JA      NEXT_DECIMAL
               CBW                             ;Convert byte to word.
               XCHG    AX,BX                   ;Swap old and new number.
               MOV     CX,10                   ;Shift to left by multiplying
               MUL     CX                      ; last entry by ten.
               JC      DECIMAL_ERROR           ;If carry, too big.
               ADD     BX,AX                   ;Add new number and store in BX.
               JNC     NEXT_DECIMAL            ;If not carry, next number.
DECIMAL_ERROR: MOV     BX,-1                   ;Else, too big; return -1.

ADJUST_DEC:    DEC     SI                      ;Adjust pointer.
               RET
DECIMAL_INPUT  ENDP

;-------------------------------------------------------;
; OUTPUT: ZR = 1 if not installed; ZR = 0 if installed. ;
;-------------------------------------------------------;
CK_INSTALLED:  MOV     AX,ES
               MOV     BX,CS
               CMP     AX,BX                   ;Compare segments.
               RET

;------------------------------------------------;
STATUS_REPORT: MOV     DX,OFFSET STATUS_MSG
               CALL    PRINT_STRING            ;Display "Status: ".
               MOV     BL,ES:STATUS
               MOV     BH,1
NEXT_REPORT:   TEST    BL,BH
               JZ      LOOP_STATUS

               MOV     DL,BH
               MOV     AX,-1
NEXT_BIT:      INC     AX
               SHR     DL,1
               JNC     NEXT_BIT
               SHL     AX,1
               SHL     AX,1
               MOV     SI,OFFSET PARAMETERS    ;Display appropriate ON or OFF,
               ADD     SI,AX                   ; SLOW or FAST.
               MOV     CX,4
REPORT:        LODSB
               CALL    PRINT_CHAR
               LOOP    REPORT

LOOP_STATUS:   SHL     BH,1
               CMP     BH,FAST
               JBE     NEXT_REPORT
               MOV     DX,OFFSET BUFFER_MSG    ;Display "Buffer size: ".
               CALL    PRINT_STRING
               MOV     AX,ES:REASSIGNMENT_SIZE
               PUSH    AX
               XOR     BP,BP
               CALL    DECIMAL_OUT             ;Display the size.
               MOV     DX,OFFSET BYTES_FREE    ;Display "Bytes free: ".
               CALL    PRINT_STRING
               POP     AX
               ADD     AX,OFFSET REASSIGNMENT_BUFFER
               SUB     AX,ES:REASSIGN_END
               CALL    DECIMAL_OUT             ;Display the bytes free.
               MOV     DX,OFFSET CR_LF
               CALL    PRINT_STRING
               RET

;------------------------------------------------;
PRINT_CHAR:    MOV     DL,AL
               MOV     AH,2                    ;Print character via DOS.
               JMP     SHORT DOS_INT

PRINT_STRING:  MOV     AH,9                    ;Print string via DOS.
DOS_INT:       INT     21H
               RET

_TEXT          ENDS
               END     START
