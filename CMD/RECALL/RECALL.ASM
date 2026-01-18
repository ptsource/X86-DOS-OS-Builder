;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************

%NEWPAGE
;--------------------------------------------------------------------------;
;                          D I R E C T I V E S                             ;
;--------------------------------------------------------------------------;
DOSSEG
MODEL     tiny

IDEAL
LOCALS
JUMPS

FALSE               EQU       0
TRUE                EQU       NOT FALSE
BELL                EQU       7
BS                  EQU       8
TAB                 EQU       9
CR                  EQU       13
LF                  EQU       10
ESCAPE              EQU       27             ; nb: ESC is a TASM keyword
SPACE               EQU       ' '
KEY_F1              EQU       3bh
KEY_F2              EQU       3ch
KEY_F3              EQU       3dh
KEY_F4              EQU       3eh
KEY_F5              EQU       3fh
KEY_F6              EQU       40h
KEY_F7              EQU       41h
KEY_F8              EQU       42h
KEY_F9              EQU       43h
KEY_F10             EQU       44h
KEY_HOME            EQU       47h
KEY_UP              EQU       48h
KEY_PGUP            EQU       49h
KEY_LEFT            EQU       4bh
KEY_RIGHT           EQU       4dh
KEY_END             EQU       4fh
KEY_DOWN            EQU       50h
KEY_PGDN            EQU       51h
KEY_INS             EQU       52h
KEY_DEL             EQU       53h
KEY_C_F1            EQU       5eh
KEY_C_F2            EQU       5fh
KEY_C_F3            EQU       60h
KEY_C_F4            EQU       61h
KEY_C_F5            EQU       62h
KEY_C_F6            EQU       63h
KEY_C_F7            EQU       64h
KEY_C_F8            EQU       65h
KEY_C_F9            EQU       66h
KEY_C_F10           EQU       67h
KEY_C_LEFT          EQU       73h
KEY_C_RIGHT         EQU       74h
KEY_C_END           EQU       75h
KEY_C_PGDN          EQU       76h
KEY_C_HOME          EQU       77h
KEY_C_PGUP          EQU       84h
KEY_F11             EQU       85h
KEY_F12             EQU       86h
KEY_C_F11           EQU       89h
KEY_C_F12           EQU       8ah
@16BIT              EQU       (@Cpu AND 8) EQ 0
@32BIT              EQU       (@Cpu AND 8)
NOWARN RES
MACRO    PUSHA                               ;; Pushs all registers
   IF @Cpu AND 2                             ;;  if for 80186 or better
      pusha                                  ;;   use regular opcode
   ELSE                                      ;;  else
      push ax cx dx bx sp bp si di           ;;   nb: order matters!
                                             ;;   nb: SP is not original!
   ENDIF
ENDM
MACRO    POPA                                ;; Pops all registers
   IF @Cpu AND 2                             ;;  if for 80186 or better
      popa                                   ;;   use regular opcode
   ELSE                                      ;;  else
      pop di si bp bx bx dx cx ax            ;;   nb: order matters!
                                             ;;   nb: don't pop SP!
   ENDIF
ENDM
NOWARN RES
MACRO    ZERO     RegList                    ;; Zeros registers
   IRP      Reg, <RegList>
         xor      Reg, Reg
   ENDM
ENDM

DOS                 EQU       21h            ; main MSDOS interrupt
STDIN               EQU       0              ; standard input
STDOUT              EQU       1              ; standard output
STDERR              EQU       2              ; error output
STDAUX              EQU       3              ; COM port
STDPRN              EQU       4              ; printer
TSRMAGIC            EQU       424bh          ; magic number
STRUC     ISR
          Entry     DW        10EBh          ; short jump ahead 16 bytes
          OldISR    DD        ?              ; next ISR in chain
          Sig       DW        TSRMAGIC       ; magic number
          EOIFlag   DB        ?              ; 0 (80) if soft(hard)ware int
          Reset     DW        ?              ; short jump to hardware reset
          Reserved  DB        7 dup (0)
ENDS
STRUC     ISRHOOK
          Vector    DB        ?              ; vector hooked
          Entry     DW        ?              ; offset of TSR entry point
ENDS
STRUC     TSRSIG
          Company   DB        8 dup (" ")    ; blank-padded company name
          Product   DB        8 dup (" ")    ; blank-padded product name
          Desc      DB        64 dup (0)     ; ASCIIZ product description
ENDS
GLOBAL at : PROC
GLOBAL errmsg : PROC
   GLOBAL ProgName : BYTE                    ; needed for errmsg()
   GLOBAL EOL : BYTE                         ; ditto
GLOBAL fgetc : PROC
GLOBAL fputc : PROC
GLOBAL fputs : PROC
GLOBAL getchar : PROC
GLOBAL getdate : PROC
GLOBAL getswtch : PROC
GLOBAL gettime : PROC
GLOBAL getvdos : PROC
GLOBAL getvect : PROC
GLOBAL isatty : PROC
GLOBAL kbhit : PROC
GLOBAL pause : PROC
GLOBAL putchar : PROC
GLOBAL setvect : PROC
GLOBAL sleep : PROC
GLOBAL find_NextISR : PROC
GLOBAL find_PrevISR : PROC
GLOBAL hook_ISR : PROC
GLOBAL unhook_ISR : PROC
GLOBAL free_Env : PROC
GLOBAL fake_Env : PROC
GLOBAL check_ifInstalled : PROC
GLOBAL install_TSR : PROC
GLOBAL remove_TSR : PROC

GLOBAL atoi : PROC
GLOBAL atou : PROC
GLOBAL utoa : PROC

EOS                 EQU       0              ; terminates strings
GLOBAL isalpha : PROC
GLOBAL isdigit : PROC
GLOBAL islower : PROC
GLOBAL isupper : PROC
GLOBAL iswhite : PROC
GLOBAL memcmp : PROC
GLOBAL strchr : PROC
GLOBAL strcmp : PROC
GLOBAL strlen : PROC
GLOBAL tolower : PROC
GLOBAL toupper : PROC




; BUFSIZE specifies size of the recall buffer for collecting commandlines.
; Values of 255 or below are risky because that's the maximum buffer size
; for subfunction 10 of Int 21h and my code in add_LineToBuffer does not 
; make sure commandlines will fit. I foresee no problems, however, with 
; larger values up to about 60K.
BUFSIZE   equ       1024                     ; >>>CHANGE AT YOUR RISK<<<
ERRH      equ       1                        ; errorlevel if help given
ERRINS    equ       10                       ; errorlevel if install failed
ERRUNI    equ       20                       ; errorlevel if uninstall failed
ERRNYI    equ       25                       ; errorlevel if not yet installed
OFF       equ       0
ON        equ       1


%NEWPAGE
;--------------------------------------------------------------------------;
;                        C O D E    S E G M E N T                          ;
;--------------------------------------------------------------------------;
CODESEG

ORG       0                                  ; address of code segment start
SegStart  DB        ?                        ;    used in when installing

ORG       80h                                ; address of commandline
CmdLen    DB        ?
CmdLine   DB        127 DUP (?)

ORG       100h                               ; start of .COM file
STARTUPCODE
          jmp       main


%NEWPAGE
;--------------------------------------------------------------------------;
;                        R E S I D E N T   D A T A                         ;
;--------------------------------------------------------------------------;
TSR_Sig   TSRSIG    <'DOSSTRAP', 'RECALL  ',\
                    'commandline editor and history TSR'>
TSR_Ver   DW        (2 SHL 8) + 1            ; (minor shl 8) + major
MPlex     DB        ?                        ; multiplex ID
HookTbl   ISRHOOK   <21h, do_Int21>
          ISRHOOK   <2dh, do_Int2D>          ; 2d must be last!!!

OldAX     DW        ?                        ; value of AX register when my
                                             ;    handler is first called
OldStack  DD        ?                        ; address of caller's stack
CurCmd    DW        0                        ; pointer to current command
                                             ;    in recall buffer
InsMode   DB        ON                       ; InsertMode toggle flag

STRUC     CMD                                ; structure for editing cmd
          Key       DB        ?              ;    extended code for key
          Function  DW        ?              ;    address of editing function
ENDS
CmdTbl    CMD       <KEY_LEFT,     OFFSET mov_lchar>
          CMD       <KEY_RIGHT,    OFFSET mov_rchar>
          CMD       <KEY_PGUP,     OFFSET mov_lword>
          CMD       <KEY_PGDN,     OFFSET mov_rword>
          CMD       <KEY_HOME,     OFFSET mov_bol>
          CMD       <KEY_END,      OFFSET mov_eol>
          CMD       <KEY_UP,       OFFSET mov_pcmd>
          CMD       <KEY_DOWN,     OFFSET mov_ncmd>
          CMD       <BS,           OFFSET del_lchar>
          CMD       <KEY_C_LEFT,   OFFSET del_lchar>
          CMD       <KEY_DEL,      OFFSET del_rchar>
          CMD       <KEY_C_RIGHT,  OFFSET del_rchar>
          CMD       <KEY_C_PGUP,   OFFSET del_lword>
          CMD       <KEY_C_PGDN,   OFFSET del_rword>
          CMD       <KEY_C_HOME,   OFFSET del_bol>
          CMD       <KEY_C_END,    OFFSET del_eol>
          CMD       <ESCAPE,       OFFSET del_line>
          CMD       <KEY_C_F9,     OFFSET del_buf>
          CMD       <KEY_INS,      OFFSET toggle_InsMode>
          CMD       <0,            OFFSET ring_Bell>   ; >>>must be last<<<


%NEWPAGE
;--------------------------------------------------------------------------;
;                          L O C A L   S T A C K                           ;
;--------------------------------------------------------------------------;
          DB        16 dup("STACK   ")       ; 128 bytes for local stack
StackTop  =         $


%NEWPAGE
;--------------------------------------------------------------------------;
;                        R E S I D E N T   C O D E                         ;
;--------------------------------------------------------------------------;
;----  is_CharWhite  ------------------------------------------------------;
;  Purpose:    Tests if character is either a blank or a tab.              ;
;  Notes:      none                                                        ;
;  Entry:      AL = character to be tested.                                ;
;  Exit:       Zero flag set if true, cleared otherwise.                   ;
;  Calls:      none                                                        ;
;  Changes:    flags                                                       ;
;--------------------------------------------------------------------------;
PROC is_CharWhite

          cmp       al, SPACE                ; if == SPACE then zf = 1
          jz        SHORT @@Fin
          cmp       al, TAB                  ; if == TAB then zf = 1
@@Fin:
          ret
ENDP is_CharWhite


;----  get_KeyNoEcho  -----------------------------------------------------;
;  Purpose:    Reads key from STDIN, waiting as necessary.                 ;
;  Notes:      Allows DESQview to operate efficiently if task inactive.    ;
;              Ctrl-C and Ctrl-Break generate Int 23h.                     ;
;  Entry:      n/a                                                         ;
;  Exit:       AL = character (0 => extended code available next).         ;
;  Calls:      none                                                        ;
;  Changes:    AX                                                          ;
;--------------------------------------------------------------------------;
PROC get_KeyNoEcho

          mov       ah, 8
          int       DOS
          ret
ENDP get_KeyNoEcho


;----  ring_Bell  ---------------------------------------------------------;
;  Purpose:    Rings the console bell as a warning to user.                ;
;  Notes:      none                                                        ;
;  Entry:      n/a                                                         ;
;  Exit:       n/a                                                         ;
;  Calls:      none                                                        ;
;  Changes:    none                                                        ;
;--------------------------------------------------------------------------;
PROC ring_Bell

          push      ax dx
          mov       ah, 2
          mov       dl, BELL
          int       DOS
          pop       dx ax
          ret
ENDP ring_Bell


;----  display_Char  ------------------------------------------------------;
;  Purpose:    Displays character on STDOUT and advances to next char.     ;
;  Notes:      Do *not* call this procedure to display backspaces; use     ;
;                   backup_Cursor instead. Though they'd be displayed      ;
;                   properly, BX would be *incremented* here.              ;
;              Does *not* adjust CH or CL.                                 ;
;  Entry:      AL = character to display,                                  ;
;              BX = pointer to current position in commandline.            ;
;  Exit:       BX++                                                        ;
;  Calls:      none                                                        ;
;  Changes:    BX                                                          ;
;--------------------------------------------------------------------------;
PROC display_Char

          push      ax dx
          mov       dl, al
          mov       ah, 2
          int       DOS
          inc       bx                       ; move to next char on cmdline
          pop       dx ax
          ret
ENDP display_Char


;----  advance_Cursor  ----------------------------------------------------;
;  Purpose:    Moves the cursor forwards on the screen.                    ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              SI = # of bytes to advance.                                 ;
;  Exit:       BX += SI,                                                   ;
;              CH -= SI.                                                   ;
;  Calls:      display_Char                                                ;
;  Changes:    AX, CH,                                                     ;
;              BX (display_Char)                                           ;
;--------------------------------------------------------------------------;
PROC advance_Cursor

          or        si, si                   ; anything to skip over?
          jz        SHORT @@Fin

; Adjust CH now. (This could be left until later - no big deal.)
          mov       al, ch
          ZERO      ah
          sub       ax, si
          mov       ch, al                   ; CH -= SI

; Display SI characters on commandline.
          push      cx
          mov       cx, si
@@NextChar:
          mov       al, [bx]
          call      display_Char             ; nb: increments BX too
          loop      SHORT @@NextChar
          pop       cx

@@Fin:
          ret
ENDP advance_Cursor


;----  backup_Cursor  -----------------------------------------------------;
;  Purpose:    Moves the cursor backwards on the screen.                   ;
;  Notes:      Does *not* handle properly line-wrapping yet.               ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              SI = # of bytes to back up.                                 ;
;  Exit:       BX -= SI,                                                   ;
;              CH += SI.                                                   ;
;  Calls:      none                                                        ;
;  Changes:    AX, BX, CH                                                  ;
;--------------------------------------------------------------------------;
PROC backup_Cursor

          or        si, si                   ; anything to skip over?
          jz        SHORT @@Fin

; Adjust BX and CH now. (This could be left until later - no big deal.)
          sub       bx, si                   ; BX -= SI
          mov       al, ch
          ZERO      ah
          add       ax, si
          mov       ch, al                   ; CH += SI

; Back up cursor by displaying non-destructive backspaces.
          push      cx dx
          mov       ah, 2
          mov       cx, si
          mov       dl, BS
@@PrevChar:
          int       DOS
          loop      SHORT @@PrevChar
          pop       dx cx

@@Fin:
          ret
ENDP backup_Cursor


;----  delete_Chars  ------------------------------------------------------;
;  Purpose:    Deletes characters from commandline.                        ;
;  Notes:      No checks are done on SI's validity; ie, caller should      ;
;                   ensure there are enough characters on line to delete.  ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              CL = # of bytes left in commandline,                        ;
;              SI = # of characters to delete.                             ;
;  Exit:       CH -= SI,                                                   ;
;              CL += SI.                                                   ;
;  Calls:      display_Char, backup_Cursor                                 ;
;  Changes:    CH, CL, SI,                                                 ;
;              AX (backup_Cursor)                                          ;
;--------------------------------------------------------------------------;
PROC delete_Chars

          or        si, si                   ; anything to delete?
          jz        SHORT @@Fin

; Adjust CH and CL now while I have SI handy. At the same time
; I am also computing the number of characters to shift.
          mov       al, cl
          ZERO      ah
          add       ax, si
          mov       cl, al                   ; CL += SI
          mov       al, ch
          sub       ax, si
          mov       ch, al                   ; CH -= SI
          push      cx                       ; final values of CH and CL
          push      ax                       ; used to back up cursor

; Shift CH - SI characters remaining on line to the left by SI characters.
          mov       cx, ax                   ; CX = CH - SI
          jcxz      SHORT @@CoverUp          ; skip if deleting to eol
@@NextChar:
          mov       al, [bx+si]
          mov       [bx], al
          call      display_Char             ; nb: increments BX too
          loop      SHORT @@NextChar

; Display spaces to overwrite chars remaining on line.
@@CoverUp:
          mov       al, SPACE
          mov       cx, si
@@NextBlank:
          call      display_Char             ; nb: increments BX too
          loop      SHORT @@NextBlank

; Back up cursor to its location on invocation.
          pop       ax                       ; CH - SI
          add       si, ax                   ; SI += (CH - SI)
          call      backup_Cursor            ; nb: decrements BX too
          pop       cx

; NB: BX will be incremented (CH - SI) + SI times by display_Char and
; decremented CH times by backup_Cursor so overall it won't change.
@@Fin:
          ret
ENDP delete_Chars


;----  add_CharToLine  ----------------------------------------------------;
;  Purpose:    Adds a character to commandline buffer.                     ;
;  Notes:      Checks to see if buffer would overflow first.               ;
;  Entry:      AL = character to add,                                      ;
;              BX = pointer to current position in line,                   ;
;              CH = number of characters until end of line,                ;
;              CL = number of bytes left in line.                          ;
;  Exit:       BX and CX changed as appropriate.                           ;
;  Calls:      display_Char, backup_Cursor, ring_Bell                      ;
;  Changes:    AX, BX, CX                                                  ;
;--------------------------------------------------------------------------;
PROC add_CharToLine

; Check for space unless insert mode is OFF *and* not at eol.
          cmp       [cs:InsMode], ON
          je        SHORT @@CheckForSpace
          or        ch, ch
          jz        SHORT @@CheckForSpace

; Overwrite existing character while in not at eol.
          mov       [bx], al
          call      display_Char             ; nb: increments BX too
          dec       ch
          jmp       SHORT @@Fin

@@CheckForSpace:
          or        cl, cl
          jz        SHORT @@Abort
          or        ch, ch
          jnz       SHORT @@AddWithShift

; At end of line.
          mov       [bx], al
          call      display_Char             ; nb: increments BX too
          dec       cl
          jmp       SHORT @@Fin

; Add character and shift everything to right over by 1 position.
@@AddWithShift:
          push      cx dx
          mov       cl, ch                   ; CH = chars to eol
          ZERO      ch
          mov       si, cx                   ; save for backing up
          inc       cl                       ; but add 1 to display new char
@@NextChar:
          mov       dl, [bx]                 ; use DL as temporary storage
          mov       [bx], al
          call      display_Char             ; nb: increments BX too
          mov       al, dl                   ; recover previous char
          loop      SHORT @@NextChar
          call      backup_Cursor            ; nb: decrements BX too
          pop       dx cx
          dec       cl
          jmp       SHORT @@Fin

@@Abort:
          call      ring_Bell                ; if out of space

@@Fin:
          ret
ENDP add_CharToLine


;----  find_StartofPrevWord  ----------------------------------------------;
;  Purpose:    Locates start of previous word in commandline.              ;
;  Notes:      "Words" are delineated by blanks and/or start/finish of     ;
;                   the commandline.                                       ;
;  Entry:      BX = pointer to current position in commandline.            ;
;  Exit:       SI = # of characters from BX to start of previous word.     ;
;  Calls:      is_CharWhite                                                ;
;  Changes:    AX, SI                                                      ;
;--------------------------------------------------------------------------;
PROC find_StartofPrevWord

          push      bx dx
          inc       dx
          inc       dx                       ; DX now points to bol
          mov       si, bx                   ; SI = current position

; Skip over any whitespace. Note: don't bother with 1st character -
; think of how it should behave if positioned at start of a word.
@@SkipWhite:
          dec       bx
          cmp       bx, dx
          jb        SHORT @@Fin              ; done if BX < bol
          mov       al, [bx]
          call      is_CharWhite
          jz        SHORT @@SkipWhite

; Next skip over non-blanks until the start of the word.
@@SkipWord:
          dec       bx
          cmp       bx, dx
          jb        SHORT @@Fin              ; done if BX < bol
          mov       al, [bx]
          call      is_CharWhite
          jnz       SHORT @@SkipWord

; Finally compute how many characters must be skipped.
@@Fin:
          inc       bx                       ; backed up 1 too many
          sub       si, bx
          pop       dx bx
          ret
ENDP find_StartofPrevWord


;----  find_StartofNextWord  ----------------------------------------------;
;  Purpose:    Locates start of next word in commandline.                  ;
;  Notes:      "Words" are delineated by blanks and/or start/finish of     ;
;                   the commandline.                                       ;
;  Entry:      BX = pointer to current position in commandline.            ;
;  Exit:       SI = # of characters from BX to start of next word.         ;
;  Calls:      is_CharWhite                                                ;
;  Changes:    AX, SI                                                      ;
;--------------------------------------------------------------------------;
PROC find_StartofNextWord

          push      bx dx
          mov       dx, bx
          mov       al, ch
          ZERO      ah
          add       dx, ax                   ; DX now points to eol

; Skip over any existing word. Note: unlike find_StartofPrevWord, here
; we do not want to initially skip ahead - imagine if cursor were at
; a blank before the start of a word.
@@SkipWord:
          cmp       bx, dx
          je        SHORT @@Fin              ; done if BX = eol
          mov       al, [bx]
          inc       bx
          call      is_CharWhite
          jnz       SHORT @@SkipWord

; Next skip over whitespace until the start of the word.
@@SkipWhite:
          cmp       bx, dx
          je        SHORT @@Fin              ; done if BX = eol
          mov       al, [bx]
          inc       bx
          call      is_CharWhite
          jz        SHORT @@SkipWhite
          dec       bx                       ; point back to white space

; Finally compute how many characters must be skipped.
@@Fin:
          mov       si, bx                   ; where we are now
          pop       dx bx
          sub       si, bx                   ; less where we started from
          ret
ENDP find_StartofNextWord


;----  recall_CmdFromBuf  -------------------------------------------------;
;  Purpose:    Replaces current with a commandline from buffer.            ;
;  Notes:      Does *not* check SI's validity.                             ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              CL = # of bytes left in commandline,                        ;
;              SI = pointer to command in recall buffer.                   ;
;  Entry:      BX = pointer to end of new commandline,                     ;
;              CH = 0,                                                     ;
;              CL = # of bytes left in new commandline.                    ;
;  Calls:      del_line, display_Char, ring_Bell                           ;
;  Changes:    AL, BX, CH, CL, SI                                          ;
;--------------------------------------------------------------------------;
PROC recall_CmdFromBuf

; Clear current commandline and display new one.
          push      si                       ; since del_line zaps SI
          call      del_line                 ; changes CH and CL such that CX
                                             ;   == max # of chars in buffer
          pop       si
@@NextChar:
          mov       al, [cs:si]
          cmp       al, CR
          je        SHORT @@Fin
          inc       si
          mov       [bx], al
          call      display_Char             ; nb: increments BX too
          loop      SHORT @@NextChar         ; continue as long as CX > 0
          cmp       [BYTE cs:si], CR         ; did loop end prematurely?
          je        SHORT @@Fin              ;   no
          call      ring_Bell                ;   yes, warn user

@@Fin:
          ret
ENDP recall_CmdFromBuf


;----  mov_lchar  ---------------------------------------------------------;
;  Purpose:    Moves cursor left in the commandline.                       ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line.                             ;
;  Exit:       BX--,                                                       ;
;              CH++,                                                       ;
;              SI = 1 (or 0 if already at bol).                            ;
;  Calls:      backup_Cursor                                               ;
;  Changes:    SI,                                                         ;
;              BX, CH (backup_Cursor)                                      ;
;--------------------------------------------------------------------------;
PROC mov_lchar

          mov       si, bx
          sub       si, dx
          cmp       si, 2
          ja        SHORT @@MoveIt           ; at bol if BX - DX <= 2
          ZERO      si
          jmp       SHORT @@Fin

@@MoveIt:
          mov       si, 1                    ; move 1 character
          call      backup_Cursor            ; nb: decrements BX too

@@Fin:
          ret
ENDP mov_lchar


;----  mov_rchar  ---------------------------------------------------------;
;  Purpose:    Moves cursor right in the commandline.                      ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line.                             ;
;  Exit:       BX++,                                                       ;
;              CH--,                                                       ;
;              SI = 1 (or 0 if already at eol).                            ;
;  Calls:      advance_Cursor                                              ;
;  Changes:    SI,                                                         ;
;              AX, BX, CH (advance_Cursor)                                 ;
;--------------------------------------------------------------------------;
PROC mov_rchar

          ZERO      si                       ; set SI = 0 first
          or        ch, ch
          jz        SHORT @@Fin              ; abort if CH = 0
          inc       si                       ; move 1 character
          call      advance_Cursor           ; nb: increments BX

@@Fin:
          ret
ENDP mov_rchar


;----  mov_lword  ---------------------------------------------------------;
;  Purpose:    Moves cursor to start of previous word.                     ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line.                             ;
;  Exit:       BX and CH adjusted as appropriate.                          ;
;  Calls:      find_StartofPrevWord, backup_Cursor                         ;
;  Changes:    SI, (find_StartofPrevWord)                                  ;
;              AX, BX, CH (backup_Cursor)                                  ;
;--------------------------------------------------------------------------;
PROC mov_lword

          call      find_StartofPrevWord
          call      backup_Cursor
          ret
ENDP mov_lword


;----  mov_rword  ---------------------------------------------------------;
;  Purpose:    Moves cursor to start of next word.                         ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line.                             ;
;  Exit:       BX and CH adjusted as appropriate.                          ;
;  Calls:      find_StartofNextWord, advance_Cursor                        ;
;  Changes:    SI, (find_StartofNextWord)                                  ;
;              AX, BX, CH (advance_Cursor)                                 ;
;--------------------------------------------------------------------------;
PROC mov_rword

          call      find_StartofNextWord
          call      advance_Cursor
          ret
ENDP mov_rword


;----  mov_bol  -----------------------------------------------------------;
;  Purpose:    Moves cursor to start of commandline.                       ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line.                             ;
;  Exit:       BX = DX + 2,                                                ;
;              CH = # of characters in commandline,                        ;
;              SI = # of characters backed up.                             ;
;  Calls:      backup_Cursor                                               ;
;  Changes:    SI,                                                         ;
;              AX, BX, CH (backup_Cursor)                                  ;
;--------------------------------------------------------------------------;
PROC mov_bol

          mov       si, bx
          sub       si, dx
          dec       si
          dec       si                       ; SI = BX - (DX + 2)
          call      backup_Cursor
          ret
ENDP mov_bol


;----  mov_eol  -----------------------------------------------------------;
;  Purpose:    Moves cursor to end of commandline.                         ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line.                             ;
;  Exit:       BX += CH,                                                   ;
;              CH = 0,                                                     ;
;              SI = # of characters advanced.                              ;
;  Calls:      advance_Cursor                                              ;
;  Changes:    SI,                                                         ;
;              AX, BX, CH (advance_Cursor)                                 ;
;--------------------------------------------------------------------------;
PROC mov_eol

          mov       al, ch
          ZERO      ah
          mov       si, ax                   ; SI = CH
          call      advance_Cursor
          ret
ENDP mov_eol


;----  mov_pcmd  ----------------------------------------------------------;
;  Purpose:    Replaces current with previous commandline from buffer.     ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              CL = # of bytes left in commandline.                        ;
;  Entry:      BX = pointer to end of new commandline,                     ;
;              CH = 0,                                                     ;
;              CL = # of bytes left in new commandline,                    ;
;              [CurCmd] adjusted.                                          ;
;  Calls:      recall_CmdFromBuf, del_line                                 ;
;  Changes:    CurCmd,                                                     ;
;              AX, BX, CH, CL, SI, (recall_CmdFromBuf)                     ;
;--------------------------------------------------------------------------;
PROC mov_pcmd

          push      di

; Point DI to 2 bytes before CurCmd. Abort if this lies at or before
; start of recall buffer.
          mov       di, [cs:CurCmd]
          dec       di                       ; now at possible CR
          dec       di                       ; now at possible cmd's last char
          cmp       di, OFFSET RecallBuf
          jbe       SHORT @@Abort

; Scan backwards to start of buffer or until finding another CR.
          push      cx                       ; CH/CL for recall_CmdFromBuf
          pushf
          mov       al, CR
          mov       cx, di
          sub       cx, OFFSET RecallBuf - 1
          std                                ; scan backwards
          repne     scasb                    ; uses ES:DI
          popf
          pop       cx
          inc       di                       ; should point to CR
          cmp       [BYTE es:di], CR
          jne       SHORT @@Abort

; Point SI to start of command and recall it.
          inc       di
          mov       si, di
          mov       [cs:CurCmd], si
          call      recall_CmdFromBuf
          jmp       SHORT @@Fin

; Nothing to recall, so point CurCmd to start of buffer
; and delete current line.
@@Abort:
          mov       [cs:CurCmd], OFFSET RecallBuf
          call      del_line

@@Fin:
          pop       di
          ret
ENDP mov_pcmd


;----  mov_ncmd  ----------------------------------------------------------;
;  Purpose:    Replaces current with next commandline from buffer.         ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              CL = # of bytes left in commandline.                        ;
;  Entry:      BX = pointer to end of new commandline,                     ;
;              CH = 0,                                                     ;
;              CL = # of bytes left in new commandline,                    ;
;              [CurCmd] adjusted.                                          ;
;  Calls:      recall_CmdFromBuf, del_line                                 ;
;  Changes:    [CurCmd],                                                   ;
;              AX, BX, CH, CL, SI (recall_CmdFromBuf)                      ;
;--------------------------------------------------------------------------;
PROC mov_ncmd

          push      di

; Point DI to CurCmd. Abort if this lies at or after LastByte.
          mov       di, [cs:CurCmd]
          cmp       di, OFFSET LastByte
          jae       SHORT @@Abort

; Scan forwards to end of buffer or until finding another CR.
; NB: Scan stops before final CR in the recall buffer since
; there can never be a command after that; saves having to
; check DI against OFFSET LastByte.
          push      cx                       ; CH/CL for recall_CmdFromBuf
          mov       al, CR
          mov       cx, OFFSET LastByte      ; *not* OFFSET LastByte + 1
          sub       cx, di
          repne     scasb                    ; uses ES:DI
          pop       cx
          dec       di                       ; should point to CR
          cmp       [BYTE es:di], CR
          jne       SHORT @@Abort

; Point SI to start of command and recall it.
          inc       di                       ; point to 1st char in next cmd
          mov       si, di
          mov       [cs:CurCmd], si
          call      recall_CmdFromBuf
          jmp       SHORT @@Fin

; Nothing to recall, so point CurCmd to just past end
; of recall buffer and delete current line.
@@Abort:
          mov       [cs:CurCmd], OFFSET LastByte + 1
          call      del_line

@@Fin:
          pop       di
          ret
ENDP mov_ncmd


;----  del_lchar  ---------------------------------------------------------;
;  Purpose:    Deletes character to left of cursor.                        ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CL = # of bytes left in commandline.                        ;
;  Exit:       BX--,                                                       ;
;              CL++.                                                       ;
;  Calls:      mov_lchar, delete_Chars                                     ;
;  Changes:    BX, (mov_lchar),                                            ;
;              AX, CH, CL, SI (delete_Chars)                               ;
;--------------------------------------------------------------------------;
PROC del_lchar

          call      mov_lchar                ; sets SI = 0 (at bol) or 1
          call      delete_Chars
          ret
ENDP del_lchar


;----  del_rchar  ---------------------------------------------------------;
;  Purpose:    Deletes character at cursor.                                ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              CL = # of bytes left in commandline.                        ;
;  Exit:       BX--,                                                       ;
;              CH--,                                                       ;
;              CL++.                                                       ;
;  Calls:      delete_Chars                                                ;
;  Changes:    AX, CH, CL, SI (delete_Chars)                               ;
;--------------------------------------------------------------------------;
PROC del_rchar

          or        ch, ch
          jz        SHORT @@Fin              ; abort if already at eol
          mov       si, 1
          call      delete_Chars
@@Fin:
          ret
ENDP del_rchar


;----  del_lword  ---------------------------------------------------------;
;  Purpose:    Deletes word to left of cursor.                             ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              CL = # of bytes left in commandline.                        ;
;  Exit:       BX, CH, and CL adjusted as appropriate.                     ;
;  Calls:      mov_lword, delete_Chars                                     ;
;  Changes:    BX, (mov_lword),                                            ;
;              AX, CH, CL, SI (delete_Chars)                               ;
;--------------------------------------------------------------------------;
PROC del_lword

          call      mov_lword                ; sets SI = 0 (at bol) or > 0
          call      delete_Chars
          ret
ENDP del_lword


;----  del_rword  ---------------------------------------------------------;
;  Purpose:    Deletes word to right of cursor.                            ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              CL = # of bytes left in commandline.                        ;
;  Exit:       CH, and CL adjusted as appropriate.                         ;
;  Calls:      find_StartofNextWord, delete_Chars                          ;
;  Changes:    AX, CH, CL, SI (delete_Chars)                               ;
;--------------------------------------------------------------------------;
PROC del_rword

          call      find_StartofNextWord     ; sets SI = 0 (at eol) or > 0
          call      delete_Chars
          ret
ENDP del_rword


;----  del_bol  -----------------------------------------------------------;
;  Purpose:    Deletes from cursor to start of commandline.                ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              CL = # of bytes left in commandline.                        ;
;  Exit:       BX = DX + 2,                                                ;
;              CH = number of characters in commandline,                   ;
;              CL -= BX - DX - 2.                                          ;
;  Calls:      mov_bol, delete_Chars                                       ;
;  Changes:    BX, (mov_bol)                                               ;
;              AX, CH, CL, SI (delete_Chars)                               ;
;--------------------------------------------------------------------------;
PROC del_bol

          call      mov_bol                  ; sets SI = 0 (at bol) or > 0
          call      delete_Chars
          ret
ENDP del_bol


;----  del_eol  -----------------------------------------------------------;
;  Purpose:    Deletes from cursor to end of commandline.                  ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              CL = # of bytes left in commandline.                        ;
;  Exit:       BX = DX + 2,                                                ;
;              CH = 0,                                                     ;
;              CL -= CH.                                                   ;
;  Calls:      delete_Chars                                                ;
;  Changes:    AX, CH, CL, SI (delete_Chars)                               ;
;--------------------------------------------------------------------------;
PROC del_eol

          mov       al, ch
          ZERO      ah
          mov       si, ax
          call      delete_Chars
          ret
ENDP del_eol


;----  del_line  ----------------------------------------------------------;
;  Purpose:    Deletes entire commandline.                                 ;
;  Notes:      none                                                        ;
;  Entry:      BX = pointer to current position in commandline,            ;
;              CH = # of bytes to end of line,                             ;
;              CL = # of bytes left in commandline.                        ;
;  Exit:       BX = DX + 2,                                                ;
;              CH = 0,                                                     ;
;              CL = [DX].                                                  ;
;  Calls:      mov_bol, del_eol                                            ;
;  Changes:    BX, (mov_bol)                                               ;
;              AX, CH, CL, SI (del_eol)                                    ;
;--------------------------------------------------------------------------;
PROC del_line

          call      mov_bol
          call      del_eol
          ret
ENDP del_line


;----  del_buf  -----------------------------------------------------------;
;  Purpose:    Deletes all commands in recall buffer.                      ;
;  Notes:      Does not affect current commandline.                        ;
;              This function is not documented elsewhere.                  ;
;  Entry:      n/a                                                         ;
;  Exit:       [CurCmd] = OFFSET LastByte + 1.                             ;
;  Calls:      init_Buf                                                    ;
;  Changes:    AX, [CurCmd] (init_Buf)                                     ;
;--------------------------------------------------------------------------;
PROC del_buf

          mov       [WORD cs:CurCmd], 0
          call      init_Buf                 ; nb: changes CurCmd
          ret
ENDP del_buf


;----  toggle_InsMode  ----------------------------------------------------;
;  Purpose:    Toggles flag for insert mode.                               ;
;  Notes:      none                                                        ;
;  Entry:      n/a                                                         ;
;  Exit:       [InsMode] toggled.                                          ;
;  Calls:      none                                                        ;
;  Changes:    [InsMode]                                                   ;
;--------------------------------------------------------------------------;
PROC toggle_InsMode

          xor       [cs:InsMode], 1
          ret
ENDP toggle_InsMode


;----  init_Buf  ----------------------------------------------------------;
;  Purpose:    Initializes recall buffer if necessary.                     ;
;  Notes:      Clears recall buffer if CurCmd is zero. Normally, CurCmd    ;
;                   will take on values OFFSET RecallBuf and LastByte,     ;
;                   or less. Zero should not otherwise occur.              ;
;              This is needed when scanning for previous commands -        ;
;                   spurious CRs should not be encountered.                ;
;  Entry:      [CurCmd] = pointer to current command in recall buffer.     ;
;  Exit:       [CurCmd] = OFFSET LastByte + 1 if buffer is initialized.    ;
;  Calls:      none                                                        ;
;  Changes:    AX, [CurCmd] possibly                                       ;
;--------------------------------------------------------------------------;
PROC init_Buf

; Abort if [CurCmd] is non-zero.
          cmp       [WORD cs:CurCmd], 0
          jne       SHORT @@Fin

; Initialize buffer by zeroing out all but last byte. There put a CR
; so when searching backwards for commands I'll find at least one.
          push      cx di
          ZERO      al                       ; fill with zeros
          mov       cx, BUFSIZE - 1
          mov       di, OFFSET RecallBuf
          rep       stosb                    ; uses ES:DI
          mov       [BYTE es:di], CR         ; buffer ends with CR
          pop       di cx

; Point current command to past end of recall buffer. This is so both
; mov_pcmd and mov_ncmd will not find any commands yet still function
; without error (which would happen if [CurCmd] were left at 0).
          mov       [cs:CurCmd], OFFSET LastByte + 1

@@Fin:
          ret
ENDP init_Buf


;----  get_CmdLine  -------------------------------------------------------;
;  Purpose:    Reads a commandline from user.                              ;
;  Notes:      The caller's buffer is used as a scratch area to keep       ;
;                   memory requirements to a minimum.                      ;
;  Entry:      DS:DX = buffer for storing commandline,                     ;
;              [BYTE DS:DX] = maximum number of bytes to read.             ;
;  Exit:       [BYTE DS:DX+1] = number of bytes actually read,             ;
;              [BYTE DS:DX+2] = 1st byte read from user.                   ;
;  Calls:      get_KeyNoEcho, add_CharToLine, [CmdTbl]                     ;
;  Changes:    AX, BX, CX, BP, [InsMode], [PrevCmd], [NextCmd]             ;
;--------------------------------------------------------------------------;
PROC get_CmdLine

          mov       bx, dx                   ; BX used for indexed addressing
          ZERO      ch                       ; bytes to end of line
          mov       cl, [bx]                 ; space left in buffer
          dec       cl                       ;    less 1 for final CR
          inc       bx                       ; pointer to first spot in buffer
          inc       bx

; Get key and determine if it's an editing key or a regular character.
@@NewKey:
          call      get_KeyNoEcho            ; get key from user
          cmp       al, CR                   ; is user done yet?
          jz        SHORT @@Fin
          cmp       al, LF                   ; skip LF if stdin redirected
          jz        SHORT @@NewKey
          cmp       al, BS                   ; BS is an editing key
          je        SHORT @@EditKey
          cmp       al, ESCAPE               ; ESCAPE is another
          je        SHORT @@EditKey
          or        al, al                   ; was key zero?
          jnz       SHORT @@RegularChar      ;   no, then it's a regular char
          call      get_KeyNoEcho            ;   yes, get extended scan code

; Process extended key as an editing key. Invalid keys are not added
; to the commandline buffer; instead, they merely result in a bell.
@@EditKey:
          mov       bp, OFFSET CmdTbl        ; point to table of editing cmds

@@NewCmd:
          cmp       [(CMD PTR cs:bp).Key], al
          je        SHORT @@ProcessCmd
          add       bp, SIZE CmdTbl
          cmp       [(CMD PTR cs:bp).Key], 0 ; zero marks end of table
          jne       SHORT @@NewCmd           ;   and must point to ring_Bell
                                             ;   so execution drops thru!!!
@@ProcessCmd:
          call      [(CMD PTR cs:bp).Function]
          jmp       SHORT @@NewKey

; It's an ordinary character so add it to the commandline.
@@RegularChar:
          call      add_CharToLine
          jmp       SHORT @@NewKey

; Now determine number of bytes in buffer, put that count in [DX+1], 
; and terminate buffer with a CR. NB: count excludes final CR.
@@Fin:
          mov       bx, dx                   ; point back to start of buffer
          mov       al, [bx]                 ; compute count
          sub       al, cl
          dec       al                       ; exclude final CR
          ZERO      ah
          mov       [bx+1], al               ; [DS:DX+1] = count
          add       bx, ax
          mov       [BYTE bx+2], CR          ; place CR at end of buffer
          ret
ENDP get_CmdLine


;----  store_CmdInBuf  ----------------------------------------------------;
;  Purpose:    Stores the commandline at the end of the recall buffer.     ;
;  Notes:      Commandlines consisting of 1 character (CR) are not saved.  ;
;  Entry:      DS:DX = pointer to start of commandline,                    ;
;              [BYTE DS:DX+1] = maximum number of bytes to read.           ;
;  Exit:       [CurCmd] = LastByte + 1.                                    ;
;  Calls:      none                                                        ;
;  Changes:    AX, BX, CX, DI, SI, [CurCmd]                                ;
;--------------------------------------------------------------------------;
PROC store_CmdInBuf

; Check length of commandline.
          mov       bx, dx
          mov       cl, [bx+1]
          or        cl, cl                   ; CL does not include final CR
          jz        SHORT @@Fin              ; so if = 0, nothing's there
          inc       cl                       ; else set CX = # bytes in cmd
          ZERO      ch                       ;   *including* final CR

; Make room in recall buffer for commandline by shifting everything
; back by [DS:DX+1] characters. 
          push      cx ds                    ; need both to copy to recall buf
          mov       ax, cs
          mov       ds, ax
          mov       di, OFFSET RecallBuf     ; to start of buffer
          mov       si, di
          add       si, cx                   ; from start + CX
          neg       cx
          add       cx, BUFSIZE              ; for BUFSIZE - [BYTE BX+1]
          rep       movsb                    ; move them
          pop       ds cx

; Add commandline in empty space at end of recall buffer. By this
; point DI will point to space for current commandline.
          mov       si, bx
          inc       si
          inc       si
          rep       movsb                    ; from DS:SI to ES:DI
          mov       [cs:CurCmd], OFFSET LastByte + 1

@@Fin:
          ret
ENDP store_CmdInBuf


;----  do_Int21  ----------------------------------------------------------;
;  Purpose:    Passes calls to input strings along to my own handler.      ;
;  Notes:      none                                                        ;
;  Entry:      AH = subfunction to perform                                 ;
;  Exit:       If AH = 10, DS:DX points to buffer read from user.          ;
;  Calls:      init_Buf, get_CmdLine, store_CmdInBuf                       ;
;  Changes:    flags                                                       ;
;--------------------------------------------------------------------------;
PROC do_Int21   FAR

; This structure is used to share intrrupts. The real entry point
; follows immediately after it.
my_Int21  ISR       < , , , 0, ((@@hw_reset - $ - 2) SHL 8 + 0ebh), >

; If the call is for buffered input, then use my handler;
; otherwise, pass it along to the old handler.
          cmp       ah, 10
          jz        SHORT @@SwitchStack
          jmp       [cs:my_Int21.OldISR]     ;   no, pass it along
                                             ;      nb: old vector issues IRET

; Switch over to my own stack and save callers registers.
@@SwitchStack:
          mov       [cs:OldAX], ax           ; can't push it on my stack yet
          cli                                ; critical part - disallow INTs
          mov       [WORD cs:OldStack], sp
          mov       [WORD cs:OldStack+2], ss
          mov       ax, cs
          mov       ss, ax
          mov       sp, OFFSET StackTop
          sti                                ; ok, out of critical section
          push      bx cx dx di si bp ds es

; Meat of my interrupt handler.
          mov       es, ax                   ; set ES = CX
          cld
          call      init_Buf
          call      get_CmdLine
          call      store_CmdInBuf

; Restore caller's registers.
          pop       es ds bp si di dx cx bx
          cli
          mov       ss, [WORD cs:OldStack+2]
          mov       sp, [WORD cs:OldStack]
          sti
          mov       ax, [cs:OldAX]

          iret                               ; return to caller

; Required for IBM Interrupt Sharing Protocol. Normally it is used
; only by hardware interrupt handlers.
@@hw_reset:
          retf
ENDP do_Int21


;----  do_Int2D  ----------------------------------------------------------;
;  Purpose:    Handle INT 2D.                                              ;
;  Notes:      Only the install check is truly supported.                  ;
;  Entry:      AH = Multiplex ID,                                          ;
;              AL = function code                                          ;
;  Exit:       AL = FF in the case of an install check,                    ;
;              CX = TSR version,                                           ;
;              DX:DI points to resident copy of TSR signature.             ;
;  Calls:      n/a                                                         ;
;  Changes:    AL, CX, DX, DI                                              ;
;--------------------------------------------------------------------------;
PROC do_Int2D  FAR

; This structure is used to share intrrupts. The real entry point
; follows immediately after it.
my_Int2D  ISR       < , , , 0, ((@@hw_reset - $ - 2) SHL 8 + 0ebh), >

; Test if request is for me. Pass it along to next ISR in chain if not.
          cmp       ah, [cs:MPlex]           ; my multiplex ID?
          jz        SHORT @@forMe            ;   yes
          jmp       [cs:my_Int2D.OldISR]     ;   no, pass it along
                                             ;      nb: old vector issues IRET

; Check function as specified in AL.
@@forMe:
          cmp       al, 0                    ; installation check
          jz        SHORT @@InstallCheck
          cmp       al, 1                    ; get entry point
          jz        SHORT @@GetEntryPoint
          cmp       al, 2                    ; uninstall
          jz        SHORT @@Uninstall
          ZERO      al                       ; mark as not implemented
          jmp       SHORT @@Fin

@@InstallCheck:
          dec       al                       ; set AL = FF
          mov       cx, [cs:TSR_Ver]         ; CH = major; CL = minor
          mov       dx, cs                   ; DX:DI points to sig string
          mov       di, OFFSET TSR_Sig
          jmp       SHORT @@Fin

@@GetEntryPoint:
          ZERO      al                       ; mark as not supported
          jmp       SHORT @@Fin

@@Uninstall:
          ZERO      al                       ; not implemented in API
          jmp       SHORT @@Fin

@@Fin:
          iret                               ; return to caller

; Required for IBM Interrupt Sharing Protocol. Normally it is used
; only by hardware interrupt handlers.
@@hw_reset:
          retf
ENDP do_Int2D


%NEWPAGE
;--------------------------------------------------------------------------;
;                        R E C A L L   B U F F E R                         ;
;--------------------------------------------------------------------------;
RecallBuf =         $                        ; will overlay transient portion
LastByte  =         RecallBuf + BUFSIZE - 1  ; room for BUFSIZE characters
                                             ; and end of resident portion


%NEWPAGE
;--------------------------------------------------------------------------;
;                       T R A N S I E N T   D A T A                        ;
;--------------------------------------------------------------------------;
ProgName  DB        'RECALL: '
          DB        EOS
EOL       DB        '.', CR, LF
          DB        EOS
HelpMsg   DB        CR, LF
          DB        'DOASTRAP RECALL - commandline editor and history TSR.', CR, LF
          DB        'Usage: RECALL [-options]', CR, LF, LF
          DB        'Options:', CR, LF
          DB        '  -i = install in memory', CR, LF
          DB        '  -l = list commandlines in recall buffer', CR, LF
          DB        '  -r = remove from memory', CR, LF
          DB        '  -? = display this help message', CR, LF, LF
          DB        'Only one option can be specified at a time.'
          DB        CR, LF, EOS
ErrMsgOpt DB        'illegal option -- '
OptCh     DB        ?                        ; room for offending character
          DB        EOS
ErrMsgVer DB        'DOS v1 is not supported'
          DB        EOS
ErrMsgRes DB        'unable to go resident'
          DB        EOS
ErrMsgRem DB        'unable to remove from memory'
          DB        EOS
ErrMsgNYI DB        'not yet installed'
          DB        EOS
InstalMsg DB        'DOSSTRAP RECALL now installed.'
          DB        CR, LF, EOS
RemoveMsg DB        'successfully removed'
          DB        EOS

SwitCh    DB        '-'                      ; char introducing options
HFlag     DB        0                        ; flag for on-line help
IFlag     DB        0                        ; flag for installing TSR
LFlag     DB        0                        ; flag for listing commandlines
RFlag     DB        0                        ; flag for removing TSR


%NEWPAGE
;--------------------------------------------------------------------------;
;                       T R A N S I E N T   C O D E                        ;
;--------------------------------------------------------------------------;
;----  go_Resident  -------------------------------------------------------;
;  Purpose:    Attempts to make TSR resident.                              ;
;  Notes:      Aborts if there's not enough memory to satisfy request.     ;
;              This procedure ONLY EXITS ON ERROR.                         ;
;  Entry:      DS = segment address of program's PSP, which also holds     ;
;                   HookTbl, a structure of type ISRHOOK.                  ;
;  Exit:       none                                                        ;
;  Calls:      check_ifInstalled, fputs, fake_Env, install_TSR, errmsg     ;
;  Changes:    AX, BX, CX, DX, DI, SI, ES                                  ;
;--------------------------------------------------------------------------;
PROC go_Resident

; See if there's already a copy resident. nb: only interested in AX
; on return from the install check.
          mov       si, OFFSET TSR_Sig
          call      check_ifInstalled        ; -> AX, CX, and DX:DI
          cmp       al, 2                    ; out of multiplex ids?
          jz        SHORT @@Abort            ;   yes, abort
          cmp       al, 1                    ; already loaded?
          jz        SHORT @@Abort            ;   yes
          mov       [MPlex], ah              ; save mplex id

; This is the point of no-return -- if we get here we're going resident.
          mov       bx, STDOUT
          mov       dx, OFFSET InstalMsg
          call      fputs

; Create a fake environment and free existing one.
; Make sure that ES points to PSP.
          ZERO      cx                       ; tells fake_Env to fake it
          push      ds
          pop       es
          call      fake_Env

; Ok, all that's left is to go resident.
; ****************************************************************************
; NB: TASM's IDEAL mode treats arguments of the OFFSET operator in a peculiar 
; fashion, as can be seen by browsing the lexical grammer in Appendix A of
; the _Reference Guide_. If MASM mode were used, the expression below would
; be written "(OFFSET LastByte - OFFSET SegStart + 16) SHR 5". However, in
; IDEAL mode not only would "OFFSET SegStart + 16" be parsed as "OFFSET
; (SegStart + 16)" but also the result would be viewed as a relative quantity.
; As it is, TASM replaces labels below with their respective address values 
; thereby computing the "correct" amount of memory to save.
; ****************************************************************************
; NB: While Angermayer and Jaeger in their book say 15 should be used
; below, I've found 16 is necessary to handle cases in which LastByte
; lies at the start of a paragraph. So what if I'm wasting an entire
; paragraph!
; ****************************************************************************
          mov       dx, (LastByte - SegStart + 16) SHR 4
          mov       bx, OFFSET HookTbl       ; pointer to ISRHOOK structure
          call      install_TSR              ; never returns

; Execution gets here only on error because:
;  - all multiplex ids are in use! 
;  - the TSR is already resident.
@@Abort:
          mov       dx, OFFSET ErrMsgRes     ; "unable to go resident"
          call      errmsg
          ret
ENDP go_Resident


;----  clear_Resident  ----------------------------------------------------;
;  Purpose:    Attempts to remove a TSR from memory.                       ;
;  Notes:      none                                                        ;
;  Entry:      DS = segment address of program's PSP.                      ;
;  Exit:       AL = 0 if removal succeeded; ERRNYI if not installed;       ;
;                   ERRUNI otherwise.                                      ;
;  Calls:      check_ifInstalled, remove_TSR, errmsg                       ;
;  Changes:    AX, BX, CX, DX, DI, SI, ES                                  ;
;--------------------------------------------------------------------------;
PROC clear_Resident

; See if there's already a copy resident.
          mov       si, OFFSET TSR_Sig
          call      check_ifInstalled        ; DS:SI -> AX, CX, DX:DI
          cmp       al, 1                    ; already loaded?
          jz        SHORT @@Removal          ;   yes
          mov       al, ERRNYI               ;   no, set return code
          mov       dx, OFFSET ErrMsgNYI     ;     "not yet installed"
          jmp       SHORT @@Fin

; Try to remove it.
@@Removal:
          mov       bx, OFFSET HookTbl       ; HookTbl in resident data area
          mov       es, dx                   ; install check returns DX:DI
          call      remove_TSR               ; ES:BX -> n/a
          jc        SHORT @@Abort
          ZERO      al
          mov       dx, OFFSET RemoveMsg
          jmp       SHORT @@Fin

@@Abort:
          mov       al, ERRUNI
          mov       dx, OFFSET ErrMsgRem     ; "unable to remove"

@@Fin:
          call      errmsg
          ret
ENDP clear_Resident


;----  list_CmdLines  -----------------------------------------------------;
;  Purpose:    Lists commandlines in recall buffer.                        ;
;  Notes:      none                                                        ;
;  Entry:      none                                                        ;
;  Exit:       AL = 0 if successful; ERRNYI otherwise.                     ;
;  Calls:      check_ifInstalled, errmsg                                   ;
;  Changes:    AX, CX, DX, DI, SI, ES                                      ;
;--------------------------------------------------------------------------;
PROC list_CmdLines

          mov       si, OFFSET TSR_Sig
          call      check_ifInstalled        ; DS:SI -> AX, CX, DX:DI
          cmp       al, 1                    ; already loaded?
          jnz       SHORT @@Abort            ;   no
          push      ds
          mov       ds, dx                   ; point DS into resident data
          mov       es, dx                   ; ES too

; Point to start of 1st complete command in recall buffer. NB:
; there will always be at least one command - "recall -l".
          mov       al, CR
          mov       cx, BUFSIZE
          mov       di, OFFSET RecallBuf
          repne     scasb                    ; uses ES:DI

; Display rest of buffer. NB: This is done character one character at
; a time because buffered lines end with CR, not 0.
          mov       ah, 2                    ; DOS subfunction to display char
@@NextChar:
          mov       dl, [di]                 ; get char
          inc       di
          int       DOS                      ; display it
          cmp       dl, CR                   ; need to display CR/LF?
          loopne    SHORT @@NextChar         ; always decrements CX 
          mov       dl, LF                   ; display LF now
          int       DOS
          or        cx, cx                   ; done yet?
          jnz       SHORT @@NextChar

          pop       ds
          ZERO      al                       ; flag no error
          jmp       SHORT @@Fin

@@Abort:
          mov       dx, OFFSET ErrMsgNYI
          call      errmsg
          mov       al, ERRNYI

@@Fin:
          ret
ENDP list_CmdLines


;----  skip_Spaces  -------------------------------------------------------;
;  Purpose:    Skips past spaces in a string.                              ;
;  Notes:      Scanning stops with either a non-space *OR* CX = 0.         ;
;  Entry:      DS:SI = start of string to scan.                            ;
;  Exit:       AL = next non-space character,                              ;
;              CX is adjusted as necessary,                                ;
;              DS:SI = pointer to next non-space.                          ;
;  Calls:      none                                                        ;
;  Changes:    AL, CX, SI                                                  ;
;--------------------------------------------------------------------------;
PROC skip_Spaces

          jcxz      SHORT @@Fin
@@NextCh:
          lodsb
          cmp       al, ' '
          loopz     @@NextCh
          jz        SHORT @@Fin              ; CX = 0; don't adjust

          inc       cx                       ; adjust counters if cx > 0
          dec       si

@@Fin:
          ret
ENDP skip_Spaces


;----  get_Opt  -----------------------------------------------------------;
;  Purpose:    Get a commandline option.                                   ;
;  Notes:      none                                                        ;
;  Entry:      AL = option character,                                      ;
;  Exit:       n/a                                                         ;
;  Calls:      tolower, errmsg                                             ;
;  Changes:    AX, DX, [OptCh], [HFlag], [IFlag], [LFlag], [RFlag]         ;
;--------------------------------------------------------------------------;
PROC get_Opt

          mov       [OptCh], al              ; save for later
          call      tolower                  ; use only lowercase in cmp.
          cmp       al, 'i'
          jz        SHORT @@OptI
          cmp       al, 'l'
          jz        SHORT @@OptL
          cmp       al, 'r'
          jz        SHORT @@OptR
          cmp       al, '?'
          jz        SHORT @@OptH
          mov       dx, OFFSET ErrMsgOpt     ; unrecognized option
          call      errmsg                   ; then *** DROP THRU *** to OptH

; Various possible options.
@@OptH:
          mov       [HFlag], ON              ; set help flag
          jmp       SHORT @@Fin

@@OptI:
          mov       [IFlag], ON              ; install in memory
          jmp       SHORT @@Fin

@@OptL:
          mov       [LFlag], ON              ; list cmds in recall buffer
          jmp       SHORT @@Fin

@@OptR:
          mov       [RFlag], ON              ; remove from memory

@@Fin:
          ret
ENDP get_Opt


;----  process_CmdLine  ---------------------------------------------------;
;  Purpose:    Processes commandline arguments.                            ;
;  Notes:      A switch character by itself is ignored.                    ;
;  Entry:      n/a                                                         ;
;  Exit:       n/a                                                         ;
;  Calls:      skip_Spaces, get_Opt                                        ;
;  Changes:    AX, CX, SI,                                                 ;
;              DX, [OptCh], [HFlag], [IFlag], [LFlag], [RFlag] (get_Opt)   ;
;              Direction flag is cleared.                                  ;
;--------------------------------------------------------------------------;
PROC process_CmdLine

          cld                                ; forward, march!
          ZERO      ch
          mov       cl, [CmdLen]             ; length of commandline
          mov       si, OFFSET CmdLine       ; offset to start of commandline

          call      skip_Spaces              ; check if any args supplied
          or        cl, cl
          jnz       SHORT @@ArgLoop

          mov       [HFlag], ON              ; assume user needs help
          jmp       SHORT @@Fin

; For each blank-delineated argument on the commandline...
@@ArgLoop:
          lodsb                              ; next character
          dec       cl
          cmp       al, [SwitCh]             ; is it the switch character?
          jnz       SHORT @@NonOpt           ;   no

; Isolate each option and process it. Stop when a space is reached.
@@OptLoop:
          jcxz      SHORT @@Fin              ; abort if nothing left
          lodsb
          dec       cl
          cmp       al, ' '
          jz        SHORT @@NextArg          ; abort when space reached
          call      get_Opt
          jmp       @@OptLoop

; Any argument which is *not* an option is invalid. Set help flag and abort.
@@NonOpt:
          mov       [HFlag], ON
          jmp       SHORT @@Fin

; Skip over spaces until next argument is reached.
@@NextArg:
          call      skip_Spaces
          or        cl, cl
          jnz       @@ArgLoop

@@Fin:
          ret
ENDP process_CmdLine


;----  main  --------------------------------------------------------------;
;  Purpose:    Main section of program.                                    ;
;  Notes:      none                                                        ;
;  Entry:      Arguments as desired                                        ;
;  Exit:       Return code as follows:                                     ;
;                   0 => program ran successfully,                         ;
;                   ERRH => on-line help supplied,                         ;
;                   ERRINS => program could not be installed,              ;
;                   ERRNYI => program was not yet installed.               ;
;  Calls:      process_CmdLine, fputs, list_CmdLines, install_TSR,         ;
;                   uninstall_TSR                                          ;
;  Changes:    n/a                                                         ;
;--------------------------------------------------------------------------;
main:

; Must be running at least DOS v2.x.
          call      getvdos
          cmp       al, 2
          jae       SHORT @@ReadCmds
          mov       dx, OFFSET ErrMsgVer     ; gotta have at least DOS v2
          call      errmsg

; Parse commandline.
@@ReadCmds:
          call      process_CmdLine          ; process commandline args
          cmp       [IFlag], ON              ; install it?
          je        SHORT @@Install
          cmp       [LFlag], ON              ; list commands?
          je        SHORT @@List
          cmp       [RFlag], ON              ; remove it?
          je        SHORT @@Remove
          mov       bx, STDERR               ; user must need help
          mov       dx, OFFSET HelpMsg
          call      fputs
          mov       al, ERRH
          jmp       SHORT @@Fin

@@List:
          call      list_CmdLines
          jmp       SHORT @@Fin

@@Install:
          call      go_Resident              ; returns on error only
          mov       al, ERRINS
          jmp       SHORT @@Fin

@@Remove:
          call      clear_Resident

; Terminate the program using as return code what's in AL.
@@Fin:
          mov       ah, 4ch
          int       DOS
EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Writes an ASCIIZ string to specified device.
;  Notes:      A zero-length string doesn't seem to cause problems when
;                 this output function is used.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      BX = device handle,
;              DS:DX = pointer to string.
;  Exit:       Carry flag set if EOS wasn't found or handle is invalid.
;  Calls:      strlen
;  Changes:    none
;-------------------------------------------------------------------------;
PROC fputs

   push     ax cx di es
   mov      ax, ds
   mov      es, ax
   mov      di, dx
   call     strlen                        ; set CX = length of string
   jc       SHORT @@Fin                   ; abort if problem finding end
   mov      ah, 40h                       ; MS-DOS raw output function
   int      DOS
@@Fin:
   pop      es di cx ax
   ret

ENDP fputs


EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Writes an error message to stderr.
;  Notes:      none
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      DS:DX = pointer to error message.
;  Exit:       n/a
;  Calls:      fputs
;  Changes:    none
;-------------------------------------------------------------------------;
PROC errmsg

   push     bx dx
   mov      bx, STDERR
   mov      dx, OFFSET ProgName           ; display program name
   call     fputs
   pop      dx                            ; recover calling parameters
   push     dx                            ; and save again to avoid change
   call     fputs                         ; display error message
   mov      dx, OFFSET EOL
   call     fputs
   pop      dx bx
   ret

ENDP errmsg


EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Gets version of DOS currently running.
;  Notes:      none
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      n/a
;  Exit:       AL = major version number,
;              AH = minor version number (2.1 = 10).
;  Calls:      none
;  Changes:    AX
;-------------------------------------------------------------------------;
PROC getvdos

   push     bx cx                         ; DOS destroys bx and cx!
   mov      ah, 30h
   int      DOS
   pop      cx bx
   ret

ENDP getvdos


EVEN
;--------------------------------------------------------------------------;
;  Purpose:    Gets address of an interrupt handler.
;  Notes:      none
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      AL = interrupt of interest.
;  Exit:       ES:BX = address of current interrupt handler
;  Calls:      none
;  Changes:    ES:BX
;--------------------------------------------------------------------------;
PROC getvect

   push     ax
   mov      ah, 35h                       ; find address of handler
   int      DOS                           ; returned in ES:BX
   pop      ax
   ret
ENDP getvect


;--------------------------------------------------------------------------;
;  Purpose:    Sets an interrupt vector.
;  Notes:      none
;  Requires:   8086-class CPU and DOS v1.0 or better.
;  Entry:      AL = interrupt of interest,
;              DS:DX = address of new interrupt handler
;  Exit:       n/a
;  Calls:      none
;  Changes:    none
;--------------------------------------------------------------------------;
PROC setvect

   push     ax
   mov      ah, 25h                       ; set address of handler
   int      DOS
   pop      ax
   ret
ENDP setvect


EVEN
;--------------------------------------------------------------------------;
;  Purpose:    Finds the next in a chain of ISRs.
;  Notes:      ISRs must be shared according to the IBM Interrupt
;                 Sharing Protocol.
;  Requires:   8086-class CPU.
;  Entry:      ES:BX = entry point for a given ISR.
;  Exit:       ES:BX = entry point for next ISR in the chain,
;              cf = 1 on error
;  Calls:      none
;  Changes:    BX, ES, cf
;--------------------------------------------------------------------------;
PROC find_NextISR

; Save DS, then set it to ES. This will avoid segment overrides below.
   push     ds es
   pop      ds

; Run three tests to see if the ISR obeys the protocol.
;1) Entry should be a short jump (opcode 0EBh).
;2) Sig should equal a special value ("KB").
;3) Reset should be another short jump.
   cmp      [BYTE PTR (ISR PTR bx).Entry], 0ebh
   jnz      SHORT @@Abort
   cmp      [(ISR PTR bx).Sig], TSRMAGIC
   jnz      SHORT @@Abort
   cmp      [BYTE PTR (ISR PTR bx).Reset], 0ebh
   jnz      SHORT @@Abort

; Ok, looks like the ISR is following the Interrupt Sharing Protocol.
; nb: cf will be clear as a result of the last comparison.
   les      bx, [(ISR PTR bx).OldISR]
   jmp      SHORT @@Fin

; Uh, oh, somebody's not being very cooperative or we've hit DOS/BIOS.
@@Abort:
   stc                                    ; flag error

@@Fin:
   pop      ds
   ret

ENDP find_NextISR


;--------------------------------------------------------------------------;
;  Purpose:    Finds the previous in a chain of ISRs.
;  Notes:      ISRs must be shared according to the IBM Interrupt
;                 Sharing Protocol.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      AL = vector hooked,
;              ES:BX = entry point for a given ISR.
;  Exit:       ES:BX = entry point for next ISR in the chain,
;              cf = 1 on error
;  Calls:      getvect, find_NextISR
;  Changes:    BX, ES, cf
;--------------------------------------------------------------------------;
PROC find_PrevISR

   push     ax cx dx

; Stack holds previous ISR. Initialize it to a null pointer.
   ZERO     cx
   push     cx cx

; Point CX:DX to current ISR, then get first ISR in the chain.
   mov      cx, es
   mov      dx, bx
   call     getvect                       ; AL -> ES:BX
   jmp      SHORT @@Cmp

; Cycle through ISRs until either a match is found or we can't go further.
@@Next:
   add      sp, 4                         ; get rid of two words on stack
   push     es bx                         ; now save ES:BX
   call     find_NextISR                  ; ES:BX -> ES:BX
   jc       SHORT @@Fin                   ; abort on error
@@Cmp:
   mov      ax, es                        ; are segs the same?
   cmp      ax, cx
   jnz      SHORT @@Next
   cmp      dx, bx                        ; what about offsets?
   jnz      SHORT @@Next

@@Fin:
   pop      bx es                         ; pointer to previous ISR
   pop      dx cx ax
   ret

ENDP find_PrevISR


;--------------------------------------------------------------------------;
;  Purpose:    Hooks into an ISR and keeps track of previous ISR.
;  Notes:      none
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      AL = vector to hook,
;              ES:BX = pointer to a structure of type ISR.
;  Exit:       n/a
;  Calls:      getvect, setvect
;  Changes:    n/a
;--------------------------------------------------------------------------;
PROC hook_ISR

   push     bx dx bp ds es

; Save old vector to it can be restored later. Then set new hook.
   push     es bx                         ; need them later
   call     getvect                       ; AL -> ES:BX
   pop      dx ds                         ; recover pointer to ISR
   mov      bp, dx                        ; use BP for indexing
   mov      [WORD (ISR PTR bp).OldISR], bx
   mov      [WORD ((ISR PTR bp).OldISR)+2], es
   call     setvect                       ; uses DS:DX

   pop      es ds bp dx bx
   ret

ENDP hook_ISR


;--------------------------------------------------------------------------;
;  Purpose:    Unhooks an ISR if possible.
;  Notes:      Unhooking an ISR is more complicated than hooking one
;                 because of the need to support interrupt sharing.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      AL = vector hooked,
;              ES:BX = entry point of current ISR.
;  Exit:       cf = 1 on error
;  Calls:      find_PrevISR, setvect
;  Changes:    cf
;--------------------------------------------------------------------------;
PROC unhook_ISR

   push     bx cx dx ds es

; Point DS:DX to next ISR, then ES:BX to previous ISR in the chain.
   lds      dx, [(ISR PTR es:bx).OldISR]
   call     find_PrevISR                  ; ES:BX -> ES:BX
   jc       SHORT @@Fin                   ; abort on error

; If find_PrevISR() returned a null pointer, then the current ISR
; is first in the chain; just use DOS to reassign the vector.
; Otherwise, update the OldISR entry in the previous handler.
   mov      cx, es                        ; did find_PrevISR() ...
   or       cx, bx                        ; return null pointer?
   jnz      SHORT @@Update                ;   no. update OldISR
   call     setvect                       ;   yes, hook AL to DS:DX
   jmp      SHORT @@Fin
@@Update:
   mov      [WORD (ISR PTR es:bx).OldISR], dx
   mov      [WORD ((ISR PTR es:bx).OldISR)+2], ds

@@Fin:
   pop      es ds dx cx bx
   ret

ENDP unhook_ISR


EVEN
AMI         equ      2dh                  ; Alternate Multiplex Interrupt
ENVBLK      equ      2ch                  ; ptr in PSP to environment block


;--------------------------------------------------------------------------;
;  Purpose:    Frees up a program's environment block.
;  Notes:      Programs such as PMAP or MEM scan environment blocks to
;                 learn names of TSRs. Freeing it means such programs
;                 will not be able to identify the TSR.
;              It's ASSUMED the ENV BLOCK has NOT ALREADY been FREED.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      ES = segment of program's PSP.
;  Exit:       none
;  Calls:      none
;  Changes:    none
;--------------------------------------------------------------------------;
PROC free_Env

   push     ax ds es

   push     es                            ; point DS to PSP too
   pop      ds
   mov      es, [ENVBLK]                  ; pointer to env block
   mov      ah, 49h                       ; free memory block
   int      DOS
   mov      [WORD PTR ENVBLK], 0          ; make it 0

   pop      es ds ax
   ret

ENDP free_Env


;--------------------------------------------------------------------------;
;  Purpose:    Replaces a program's real environment with a smaller, fake
;                 one to save space. Programs like PMAP and MEM though
;                 will still be able to identify TSRs.
;  Notes:      If run with DOS version lower than v3.10, the environment
;                 block is merely freed.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      CX = size in bytes of pseudo-environment block (if 0 
;                 one is created containing just program name/args),
;              DS:SI = pointer to pseudo-environment block,
;              ES = segment of program's PSP.
;  Exit:       none
;  Calls:      getvdos, free_Env, strlen
;  Changes:    none
;--------------------------------------------------------------------------;
PROC fake_Env

   push     ax bx cx di si ds es
   pushf

; Make sure DOS is v3.10 or better. If not, just free environment.
; nb: I could code this to handle old versions so long as caller
; supplies a real block, but why bother?
   call     getvdos                       ; get DOS version
   xchg     al, ah
   cmp      ax, (3 SHL 8) + 10            ; v3.10 or better?
   jae      SHORT @@FindEnv               ;   yes
   call     free_Env                      ;   no, just free it
   jmp      SHORT @@Fin

; Locate environment block.
@@FindEnv:
   mov      bx, [es:ENVBLK]               ; pointer to env block
   mov      es, bx

; If CX is zero, point DS:SI to just the program name/args in the
; current environment. This format was introducted with DOS v3.10.
;
; nb: Refer to _Undocumented DOS, p 399 for format of environment block.
   cld                                    ; scasb and movsb must go forward
   or       cx, cx                        ; is CX zero?
   jnz      SHORT @@GetMem                ;   no
   mov      ds, bx                        ; point DS to env block too
   ZERO     al                            ; ends of ASCIIz strings
   ZERO     di                            ; start at offset 0
@@NextString:
   call     strlen                        ; find length of string at ES:DI
   add      di, cx                        ; update DI
   inc      di                            ;   and past EOS
   scasb                                  ; are we at another 0?
   jne      SHORT @@NextString            ;   no
   mov      si, di                        ; point SI to
   dec      si                            ;   EOS in ...
   dec      si                            ;   last string
   mov      [WORD PTR es:di], 1           ; only want prog name/args
   inc      di                            ; point to start of string
   inc      di
   call     strlen                        ; find its length
   add      cx, di                        ; get # bytes to move
   sub      cx, si
   inc      cx

; At this point, CX holds number of bytes to allocate and DS:SI point
; to a copy of the pseudo-environment block.
@@GetMem:
   ZERO     di                            ; either way, destination = 0
   mov      bx, cx                        ; from # bytes
   REPT     4
      shr      bx, 1                      ; get # paragraphs
   ENDM
   inc      bx                            ; think what if CX < 0fh
   push     bx                            ; must save BX if DOS fails
   mov      ah, 48h                       ; allocate memory
   int      DOS                           ; returns block in AX
   pop      bx
   jc       SHORT @@JustResize            ; cf => failure

; Memory allocation succeeded so: (1) Copy to new block. (2) Adjust
; pointer in program's PSP. (3) Free old block.
   push     es                            ; points to old env block
   mov      es, ax                        ; new block
   rep      movsb
   mov      ah, 62h                       ; get program's PSP
   int      DOS                           ; returns it in BX
   mov      ds, bx
   mov      [ENVBLK], es                  ; pointer to new env block
   pop      es                            ; recover pointer to old env
   mov      ah, 49h                       ; free it
   int      DOS
   jmp      SHORT @@Fin

; Memory allocation failed so we'll use existing block and resize it.
@@JustResize:
   rep      movsb
   mov      ah, 4ah                       ; modify allocation
   int      DOS

@@Fin:
   popf
   pop      es ds si di cx bx ax
   ret

ENDP fake_Env


;--------------------------------------------------------------------------;
;  Purpose:    Checks if a TSR has been installed in memory.
;  Notes:      For a description of the steps followed here, see Ralf
;                 Brown's alternate multiplex proposal.
;              This procedure MUST BE RUN before going resident and
;                 the multiplex id returned SHOULD BE SAVED in the
;                 resident data area.
;  Requires:   8086-class CPU
;  Entry:      DS:SI = pointer to TSR's signature string.
;  Exit:       AL = 0 if not installed, = 1 if installed, = 2 if all
;                 multiplex ids are in use,
;              AH = multiplex id to use based on AL,
;              CX = TSR version number if installed,
;              DX:DI = pointer to resident copy of TSR's sig if AL = 1.
;  Calls:      getvect, memcmp
;  Changes:    AX, CX, DX, DI
;--------------------------------------------------------------------------;
PROC check_ifInstalled

   push     bx es

; Do a quick check to see if 2d is hooked. 
   mov      al, AMI                       ; alternate multiplex interrupt
   call     getvect                       ; handler address in ES:BX
   ZERO     ax
   cmp      [BYTE PTR es:bx], 0cfh        ; is it IRET opcode?
   jz       SHORT @@Fin                   ;   yes, return with AX = 0

; Do an install check on each possible multiplex id. 
   ZERO     bx                            ; marks 1st unused mplex id
@@CheckIt:
   ZERO     al                            ; be sure to do install check
   int      AMI                           ; might trash CX and DX:DI
   or       al, al                        ; is AL zero still?
   jnz      SHORT @@CmpSigs               ;   no, multiplex's in use

; It's not in use. Save if it's the first.
   or       bl, bl                        ; 1st available id found already?
   jnz      SHORT @@NextMPlex             ;   yes
   inc      bl                            ;   no, but flag it now
   mov      bh, ah                        ;     and hold onto mplex
   jmp      SHORT @@NextMPlex

; Compare first 16 bytes of sigs. DS:SI points to a known sig;
; DX:DI to one somewhere in resident code.
@@CmpSigs:
   push     cx                            ; save TSR version number
   mov      cx, 16                        ; # bytes in sigs to compare
   mov      es, dx                        ; memcmp() needs ES:DI and DS:SI
   call     memcmp
   pop      cx                            ; recover TSR version number
   jnz      SHORT @@NextMPlex
   mov      al, 1
   jmp      SHORT @@Fin

; Move on to next multiplex number.
@@NextMPlex:
   add      ah, 1                         ; sets zf if AH was 255. Done?
   jnz      SHORT @@CheckIt               ;   no, back for more
   mov      ah, bh                        ;   yes, AH = 1st available id
   or       bl, bl                        ;   did we run out?
   jnz      SHORT @@Fin                   ;     no
   mov      al, 2                         ;     yes

@@Fin:
   pop      es bx
   ret

ENDP check_ifInstalled


;--------------------------------------------------------------------------;
;  Purpose:    Installs a TSR in memory.
;  Notes:      This procedure never returns.
;              No changes are made here to the environment block.
;              Entry points are assumed relative to ES.
;              Call check_ifInstalled() to determine which multiplex
;                 id will be used.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      DX = number of paragraphs to reserve,
;              ES:BX = pointer to a structure of ISRHOOK.
;  Exit:       n/a
;  Calls:      hook_ISR
;  Changes:    n/a
;--------------------------------------------------------------------------;
PROC install_TSR

; Set hooks as specified by ISRHOOK structure. 
   mov      bp, bx                        ; BX needed when hooking ISRs
@@NextHook:
   mov      al, [(ISRHOOK PTR bp).Vector]
   mov      bx, [(ISRHOOK PTR bp).Entry]
   call     hook_ISR                      ; AL, ES:BX -> n/a
   add      bp, SIZE ISRHOOK
   cmp      al, AMI                       ; at end of table?
   jnz      SHORT @@NextHook              ;   no

; And now go resident. Note that DX already holds # paragraphs to keep.
   mov      ax, 3100h                     ; terminate/stay resident, rc = 0
   int      DOS                           ; via DOS
   ret                                    ; ***never reached***

ENDP install_TSR


;--------------------------------------------------------------------------;
;  Purpose:    Removes a TSR if possible.
;  Notes:      Caller should use check_ifInstalled() to make sure the
;                 TSR has first been installed.
;              Entry points are assumed to be relative to ES.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      ES:BX = pointer to a structure of ISRHOOK.
;  Exit:       cf set if operation failed
;  Calls:      find_PrevISR, unhook_ISR
;  Changes:    AX, cf
;--------------------------------------------------------------------------;
PROC remove_TSR

   push     bx dx bp ds es                ; save registers

; Set DS to ES to avoid segment overrides. Also, use BP for indexing into 
; the hook table, and save it in DX as it's needed later.
   push     es
   pop      ds
   mov      bp, bx
   mov      dx, bx

; For each vector in the hook table, make sure the ISR can be unhooked.
@@NextVect:
   mov      al, [(ISRHOOK PTR bp).Vector]
   mov      bx, [(ISRHOOK PTR bp).Entry]
   push     es                            ; hang onto this
   call     find_PrevISR                  ; able to find it?
   pop      es
   jc       SHORT @@Fin                   ;   no, abort
   add      bp, SIZE ISRHOOK
   cmp      al, AMI                       ; at end of table?
   jnz      SHORT @@NextVect              ;   no

; It's possible to unhook all vectors, so go to it. 
   mov      bp, dx
@@NextHook:
   mov      al, [(ISRHOOK PTR bp).Vector]
   mov      bx, [(ISRHOOK PTR bp).Entry]
   call     unhook_ISR                    ; AL, ES:BX -> n/a
   jc       SHORT @@Fin                   ; it had better succeed!
   add      bp, SIZE ISRHOOK
   cmp      al, AMI                       ; at end of table?
   jnz      SHORT @@NextHook              ;   no

; Now free TSR's memory.
   mov      bx, [ENVBLK]
   or       bx, bx                        ; any environment block?
   jz       SHORT @@MainMem               ;   no
   mov      es, bx                        ;   yes, free it
   mov      ah, 49h
   int      DOS                           ; trashes AH
   jc       SHORT @@Fin                   ; shouldn't be necessary
@@MainMem:
   mov      ah, 49h
   mov      bx, ds                        ; free TSR's memory
   mov      es, bx
   int      DOS

@@Fin:
   pop      es ds bp dx bx                ; pop registers
   ret

ENDP remove_TSR


EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Converts character to lowercase.
;  Notes:      none
;  Requires:   8086-class CPU.
;  Entry:      AL = character to be converted.
;  Exit:       AL = converted character.
;  Calls:      none
;  Changes:    AL
;              flags
;-------------------------------------------------------------------------;
PROC tolower

   cmp      al, 'A'                       ; if < 'A' then done
   jb       SHORT @@Fin
   cmp      al, 'Z'                       ; if > 'Z' then done
   ja       SHORT @@Fin
   or       al, 20h                       ; make it lowercase
@@Fin:
   ret

ENDP tolower


;-------------------------------------------------------------------------;
;  Purpose:    Converts character to uppercase.
;  Notes:      none
;  Requires:   8086-class CPU.
;  Entry:      AL = character to be converted.
;  Exit:       AL = converted character.
;  Calls:      none
;  Changes:    AL
;              flags
;-------------------------------------------------------------------------;
PROC toupper

   cmp      al, 'a'                       ; if < 'a' then done
   jb       SHORT @@Fin
   cmp      al, 'z'                       ; if > 'z' then done
   ja       SHORT @@Fin
   and      al, not 20h                   ; make it uppercase
@@Fin:
   ret

ENDP toupper


EVEN
;--------------------------------------------------------------------------;
;  Purpose:    Compares two regions of memory.
;  Notes:      none
;  Requires:   8086-class CPU.
;  Entry:      CX = number of bytes to compare,
;              DS:SI = start of 1st region of memory,
;              ES:DI = start of 2nd region.
;  Exit:       zf = 1 if equal.
;  Calls:      none
;  Changes:    zf
;--------------------------------------------------------------------------;
PROC memcmp

   push     cx di si
   pushf                                  ; save direction flag
   cld
   repe     cmpsb                         ; compare both areas
   popf                                   ; recover direction flag
   dec      di
   dec      si
   cmpsb                                  ; set flags based on final byte
   pop      si di cx
   ret

ENDP memcmp


EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Calculates length of an ASCIIZ string.
;  Notes:      Terminal char is _not_ included in the count.
;  Requires:   8086-class CPU.
;  Entry:      ES:DI = pointer to string.
;  Exit:       CX = length of string,
;              cf = 0 and zf = 1 if EOS found,
;              cf = 1 and zf = 0 if EOS not found within segment.
;  Calls:      none
;  Changes:    CX,
;              flags
;-------------------------------------------------------------------------;
PROC strlen

   push     ax di
   pushf
   cld                                    ; scan forward only
   mov      al, EOS                       ; character to search for
   mov      cx, di                        ; where are we now
   not      cx                            ; what's left in segment - 1
   push     cx                            ; save char count
   repne    scasb
   je       SHORT @@Done
   scasb                                  ; test final char
   dec      cx                            ; avoids trouble with "not" below

@@Done:
   pop      ax                            ; get original count
   sub      cx, ax                        ; subtract current count
   not      cx                            ; and invert it
   popf                                   ; restore df
   dec      di
   cmp      [BYTE PTR es:di], EOS
   je       SHORT @@Fin                   ; cf = 0 if equal
   stc                                    ; set cf => error

@@Fin:
   pop      di ax
   ret

ENDP strlen


END
