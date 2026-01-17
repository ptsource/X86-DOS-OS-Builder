;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************
PAGE ,132
TITLE Memory Query Program

CODE      SEGMENT BYTE PUBLIC 'CODE'

          ASSUME  CS:CODE,DS:CODE

          ORG     100H

START:    JMP     MEM


AVAILPAG  DW      ?
AVAILPAR  DW      ?
TOTALPAG  DW      ?
TOTALPAR  DW      ?

EMM_NAME  DB      "EMMXXXX0"
EMM_NLEN  EQU     $-OFFSET EMM_NAME
ERRIMS    DB      "Expanded Memory Manager Error!",7,13,10,"$"
PC100     DB      "100.0"

MEM:     INT     12H                           ; Get Total Standard Memory
          MOV     DX,64                         ; Convert to Paragraphs
          MUL     DX
          MOV     TOTALPAR,AX                   ;   and Save
          MOV     DX,16                         ; Convert to Bytes
          MUL     DX
          MOV     DI,OFFSET TOTAL[8]            ; Convert to Decimal-ASCII
          CALL    DEC8OUT
          CALL    STRIP0
          MOV     AH,9                          ; Output to Screen
          MOV     DX,OFFSET TOTAL
          INT     21H
          MOV     AX,CS                         ; Determine Available Memory
          DEC     AX                            ;   from Mem Alloc Cntl Block
          MOV     ES,AX
          MOV     AX,ES:[3]
          MOV     AVAILPAR,AX
          MOV     BX,16
          MUL     BX
          MOV     CX,DX
          MOV     BX,AX
          MOV     DI,OFFSET AVAIL[8]            ; Convert to Decimal-ASCII
          CALL    DEC8OUT
          CALL    STRIP0
          MOV     AX,AVAILPAR                   ; Calculate Percent Available
          MOV     BX,100
          MUL     BX
          MOV     BX,TOTALPAR
          DIV     BX
          MOV     DI,OFFSET AVAIL[35]           ; Convert Percent to ASCII
          CALL    DEC2OUT
          CALL    STRIP0
          MOV     AX,DX
          MOV     BX,100
          MUL     BX
          MOV     BX,TOTALPAR
          DIV     BX
          MOV     DI,OFFSET AVAIL[38]
          CALL    DEC2OUT
          MOV     AH,9                          ; Output to Screen
          MOV     DX,OFFSET AVAIL
          INT     21H
          MOV     AH,88H                        ; Check for Extended Memory
          INT     15H
          JC      CHK_IMS                       ; If None, Skip to IMS Memory
          OR      AX,AX
          JZ      CHK_IMS
          MOV     BX,1024                       ; Convert Size (K) to Bytes
          MUL     BX
          MOV     DI,OFFSET ETOTAL[8]           ; Convert to Decimal-ASCII
          CALL    DEC8OUT
          CALL    STRIP0
          MOV     AH,9                          ; Output to Screen
          MOV     DX,OFFSET ETOTAL
          INT     21H
CHK_IMS:  PUSH    ES                            ; Check for IMS Expanded Memory
          MOV     AX,3567H
          INT     21H
          MOV     DI,10
          MOV     SI,OFFSET EMM_NAME
          MOV     CX,EMM_NLEN
          CLD
          REPE    CMPSB
          POP     ES
          JNE     DONE                          ; If None, Skip
          MOV     AH,42H                        ; Get IMS Memory Size (Pages)
          INT     67H
          OR      AH,AH                         ; If Error, Flag It
          JNZ     IMSERR
          MOV     TOTALPAG,DX                   ; Save Memory Size Parameters
          MOV     AVAILPAG,BX
          MOV     AX,16384                      ; Convert Pages to Bytes
          MUL     DX
          MOV     DI,OFFSET IMSTOTAL[8]         ; Convert to Decimal-ASCII
          CALL    DEC8OUT
          CALL    STRIP0
          MOV     AH,9                          ; Output to Screen
          MOV     DX,OFFSET IMSTOTAL
          INT     21H
          MOV     AX,16384                      ; Convert Available to Bytes
          MUL     BX
          MOV     DI,OFFSET IMSAVAIL[8]         ; Convert to Decimal-ASCII
          CALL    DEC8OUT
          CALL    STRIP0
          MOV     AX,AVAILPAG                   ; Calculate Percent Available
          CMP     AX,TOTALPAG
          JNE     NOT_ALL
          MOV     DI,OFFSET IMSAVAIL[49]
          MOV     SI,OFFSET PC100
          MOV     CX,5
          REP     MOVSB
          JMP     SHORT AVAILOUT
NOT_ALL:  MOV     BX,100
          MUL     BX
          MOV     BX,TOTALPAG
          DIV     BX
          MOV     DI,OFFSET IMSAVAIL[51]        ; Convert Percent to ASCII
          CALL    DEC2OUT
          CALL    STRIP0
          MOV     AX,DX
          MOV     BX,100
          MUL     BX
          MOV     BX,TOTALPAG
          DIV     BX
          MOV     DI,OFFSET IMSAVAIL[54]
          CALL    DEC2OUT
AVAILOUT: MOV     AH,9                          ; Output to Screen
          MOV     DX,OFFSET IMSAVAIL
          INT     21H
DONE:     MOV     AX,4C00H                      ; Exit to DOS
          INT     21H
IMSERR:   MOV     AH,9                          ; Output IMS Error Message
          MOV     DX,OFFSET ERRIMS
          INT     21H
          MOV     AX,4C01H                      ; Exit to DOS (RetCode = 1)
          INT     21H

STRIP0:   CMP     BYTE PTR [DI],'0'             ; If this char is not '0', Done
          JNE     STRIP1
          CMP     BYTE PTR [DI+1],'0'           ; If next byte in non-numeric,
          JL      STRIP1                        ;   Done
          CMP     BYTE PTR [DI+1],'9'
          JG      STRIP1
          MOV     BYTE PTR [DI],' '             ; Replace '0' with ' '
          INC     DI                            ; Point to next character
          JMP     SHORT STRIP0                  ; Repeat
STRIP1:   RET                                   ; Done


DEC2OUT:  PUSH    AX                            ; Save Registers
          PUSH    BX
          XOR     AH,AH                         ; Clear AH
          MOV     BL,10                         ; AH=AX%10,AL=AX/10
          DIV     BL
          ADD     AX,'00'                       ; Convert to ASCII
          SUB     DI,2
          MOV     [DI],AX                       ; Store in String
          POP     BX                            ; Restore Registers
          POP     AX
          RET                                   ; Done

DEC4OUT:  PUSH    AX                            ; Save Registers
          PUSH    BX
          MOV     BL,100                        ; AH=AX%100,AL=AX/100
          DIV     BL
          XCHG    AH,AL                         ; Convert 2 LSD's
          CALL    DEC2OUT
          XCHG    AH,AL                         ; Convert 2 MSD's
          CALL    DEC2OUT
          POP     BX                            ; Restore Registers
          POP     AX
          RET                                   ; Done

DEC8OUT:  PUSH    AX                            ; Save Registers
          PUSH    BX
          PUSH    DX
          MOV     BX,10000                      ; DX=DX:AX%10000,AX=DX:AX/10000
          DIV     BX
          XCHG    DX,AX                         ; Convert 4 LSD's
          CALL    DEC4OUT
          XCHG    DX,AX                         ; Convert 4 MSD's
          CALL    DEC4OUT
          POP     DX                            ; Restore Registers
          POP     BX
          POP     AX
          RET                                   ; Done

TOTAL     DB      "       0 Bytes Total Memory",13,10,"$"
AVAIL     DB      "       0 Bytes Available Memory ( 0.00%)",13,10,"$"
ETOTAL    DB      "       0 Bytes of Extended Memory Total",13,10,"$"
IMSTOTAL  DB      "       0 Bytes of LIM Expanded Memory Total",13,10,"$"
IMSAVAIL  DB      "       0 Bytes of LIM Expanded Memory Available ( 0.00%)",13,10,"$"

CODE      ENDS

          END     START
