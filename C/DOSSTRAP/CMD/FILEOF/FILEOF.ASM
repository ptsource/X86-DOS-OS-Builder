;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************
Title   FileOf  Tests for File Existence

RetNear Macro
        DB      0C3H
        Endm

Null    Equ     00H
CR      Equ     0DH
LF      Equ     0AH
Parms   Equ     80H

Cseg    Segment
        Assume  DS:Cseg, SS:Cseg, CS:Cseg, ES:Cseg

        Org     100H

FileOf:
        Mov     BX,Parms                ; point to trailer
        Cmp     Byte Ptr [BX],Null      ; anything there?
        Jnz     GetDefault              ; yes, continue
        Jmp     DisplayHelp             ; no, display help screen

GetDefault:
        Mov     AH,19H                  ; function code to
        Int     21H                     ;  obtain default drive
        Add     AL,'A'                  ; adjust to ascii
        Mov     DriveName,AL            ;  and save for later

        Mov     SI,Offset 2[Parms]      ; point to trailer
        Mov     DI,Offset DriveName     ; point to buffer
        Cmp     Byte Ptr 1[SI],':'      ; drive included?
        Jz      MoveTrailer             ; yes, use it
        Mov     DI,Offset 2[DriveName]  ; no, use default drive

MoveTrailer:
        Lodsb                           ; pick up a byte
        Cmp     AL,CR                   ; end of trailer?
        Jz      TerminateTrailer        ; yes, go make ASCIIZ
        Stosb                           ; no, store this byte
        Jmp     Short   MoveTrailer     ;  and look for more

TerminateTrailer:
        Xor     al,al                   ; terminate the string
        Stosb

LookForFile:
        Call    Ready                   ; disk in drive?
        Jc      NoDiskExit              ; no, file not found
        Xor     AL,AL                   ; open file for reading
        Mov     DX,Offset DriveName     ; point to path name
        Mov     AH,3DH                  ; open a file function
        Int     21H                     ; try to open it
        Jnc     FoundExit               ; found?

NotFoundExit:
        Mov     AL,3                    ; not found return code
        Jmp     Short   FileOfExit      ; exit stage left
DisplayHelp:
        Mov     DX,Offset FileName      ; point to message
        Mov     AH,09H                  ; display string function
        Int     21H                     ; StdOut
NoDiskExit:
        Mov     AL,0                    ; not found return code
        Jmp     Short   FileOfExit      ; exit stage left
FoundExit:
        Push    AX                      ; save file handle
        Pop     BX                      ; retrieve file handle
        Mov     AH,3EH                  ; close file function
        Int     21H                     ; close the file
        Mov     AL,4                    ; found return code
FileOfExit:
        Mov     AH,4CH                  ; terminate a process
        Int     21H                     ; exit stage left

Ready:
        Mov     AL,DriveName            ; drive letter
        And     AL,5FH                  ; upper case
        Sub     AL,'A'                  ; adjust to binary
        Mov     BX,Offset DiskBuffer    ; disk buffer address
        Mov     CX,1                    ; number of sectors
        Mov     DX,0                    ; beginning sector number
        Int     25H                     ; absolute disk read
        Pop     BX                      ; remove flags from stack
        RetNear                         ; exit stage right

DriveName       DB      '?:'
FileName        Equ     $
                DB      'Usage:  FILEOF [pathname]  ',CR,LF
DiskBuffer      Equ     $
                DB      '    Return Code = 0, no disk in the drive.',CR,LF
                DB      '    Return Code = 3, [pathname] does not exist.',CR,LF
                DB      '    Return Code = 4, [pathname] was found.',CR,LF
                DB      '$'

FileOfLen       Equ     (This Byte) - (Offset FileOf)
Filler          Equ     432 - FileOfLen
                DB      Filler DUP(0)

Cseg    Ends

        End     FileOf
