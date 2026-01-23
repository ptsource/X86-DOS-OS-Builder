;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************

cpu 8086                               ; "-O3" does the inverse jump trick
                                       ;  if you use "cpu 8086"   ;-)
? equ 0

%idefine offset
%idefine ptr

section .text
org 100h

Start:

  cld

  push ds
  mov ax, 3524h                 ; back up old int 24h
  int 21h
  mov word ptr [old24h], bx
  mov word ptr [old24h+2], es
  pop es
  
  mov ah, 25h                   ; set up new int 24h (al=24h still)
  mov dx, offset int24h
  int 21h

  mov di, offset wildcard       ; wipe all buffers
  mov cx, offset frarray-offset wildcard + 20000
  mov al, 0
  rep stosb

  call fillcmdbuffer            ; create capitalized version of command line
  call check_switches
  call set_wildcard

  call checkCyclic
  call checkPath

  copy_directory:
    call copy_files
  test byte ptr [config], 00010000b
  jz nonrecursive
    call find_dir
    jc copy_directory
  nonrecursive:

  cmp word ptr [directories], 0000h
  jne dirsfound
  cmp byte ptr [filesfound], 00h
  je filenotfound
  dirsfound:
  call print_total

;---------------------------------------------------------
quit:
  call return

  mov ax, 2524h                 ; restore original int 24h
  lds dx,[old24h]               ; CM -- oops, put this before int 21h
  int 21h

  mov ax, 4c00h
  int 21h
;---------------------------------------------------------
find_dir:
  mov bx, offset csource
  call trimdir
  mov dx, offset defaultwildcard
  call appendstring
  mov dx, offset csource

  or byte ptr [fattr],  00010000b       ; directories added to "allowable"
  mov byte ptr [rattr], 00010000b       ; directories set as "required"
    call findfirst
    jc nodirsfound

  contfd:

  test byte ptr [config], 00100000b     ; lfn?
  jnz dolfnfinddir
    mov si, word ptr [dta]
    mov al, byte ptr [es:si+15h]        ; get attribute byte
    mov dx, word ptr [es:si+1Eh]        ; get 4 bytes of the filename
    mov bp, word ptr [es:si+1Eh+2]
    jmp checkisdir
  dolfnfinddir:
    mov al, byte ptr [frecord]          ; get attribute byte (lfn)
    mov dx, word ptr [frecord+2Ch]      ; get 4 bytes of the filename
    mov bp, word ptr [frecord+2Ch+2]
  checkisdir:

  test byte ptr al, 00010000b           ; directory attribute set?
  jz not_dir                            ; no?  not a directory then.

  and bp,0FFh
  test bp,bp
  jnz recheck

  cmp dx, 2E2Eh                         ; directory entry is '..'?
  jne recheck
  jmp not_dir                            ; yes.  ignore it.
 
recheck:
  cmp dx, 002Eh                         ; directory entry is '.'?
  je not_dir                            ; yes.  ignore it.

  mov bx, offset destination
  call findend
  push bx
  mov bx, offset source
  call findend
  push bx
  mov bx, offset rfile
  call findend

  test byte ptr [config], 00100000b
  jnz lfnappend
    mov dx, word ptr [dta]
    add dx, 1Eh
    push es
    pop ds
    call appendstring
    pop bx
    call appendstring
    pop bx
    call appendstring
    push cs
    pop ds
  jmp commonfinddir
  lfnappend:
    mov dx, offset frecord+2Ch
    call appendstring
    pop bx
    call appendstring
    pop bx
    call appendstring

  commonfinddir:
    mov dx, offset source
    mov al, '\';
  call setLastByte
    mov dx, offset rfile
  call setLastByte

  mov dx, offset destination
  call getattributes
  jc makedir
    test cl, 00010000b
    jnz direxists
  makedir:

  mov ah, 39h                           ; dos make directory
  test byte ptr [config], 00100000b
  jz shortmakedir
    mov ax, 7139h                       ; lfn make directory
  shortmakedir:

  int 21h
  mov word ptr [error], offset destination
  call errorHandle

  mov al, '$'                           ; display directory created
  mov dx, offset rfile
  call setLastByte
  call printstring
  call return
  mov bx, offset rfile
  call trimdir
  inc word ptr [directories]
  mov dx, offset destination

  direxists:

  test byte ptr [config], 00000001b     ; retain attributes?
  jz skipsetdirattributes
  test byte ptr [config], 00100000b     ; lfn?
  jnz lfngetdirattrib
    mov si, word ptr [dta]
    mov cl, byte ptr [es:si+15h]        ; get attribute byte
    jmp donegotdirattrib
  lfngetdirattrib:
    mov cl, byte ptr [frecord]          ; get attribute byte (lfn)
  donegotdirattrib:
  call setattributes                    ; copy source attributes to dest dir
  skipsetdirattributes:

  mov al, '\';
  call setLastByte

  call backupfr
  stc
  ret

  not_dir:
    call findnext
    jnc contfd
    call findclose

  nodirsfound:
    cmp word ptr [frindex], 0
    je finisheddirs
    call restorefr
    mov bx, offset rfile
    call trimdir
    mov bx, offset source
    call trimdir
    mov bx, offset destination
    call trimdir
  jmp not_dir

  finisheddirs:
    clc
  ret
;---------------------------------------------------------
print_total:
  mov dl, 9
  call printchar

  mov ax, word ptr [files]
  mov bx, 10
  mov si, offset vbuffer+5

  mov byte ptr [si], '$'
  kdd:
    dec si
    xor dx, dx
    div bx
    add dl, '0'
    mov byte ptr [si], dl
    test ax, ax
    jz wdh
  cmp si, offset vbuffer
  jne kdd

  wdh:
  mov dx, si
  call printstring
  mov dx, offset fcmsg
  jmp printstring
;---------------------------------------------------------
copy_files:
  and byte ptr [fattr], 11101111b       ; directories not in "allowable"
  mov byte ptr [rattr], 00h             ; required attributes for search (none)

  mov dx, offset source                 ; adds the wildcard to the source
  mov bx, offset csource                ; path to use findfirst with it
  call appendstring
  mov dx, offset wildcard
  call appendstring

  mov dx, offset csource                ; find the first file of what was
  call findfirst                        ; specified by the source statement
  jnc fpf
    cmp al, 12h                         ; no more files
    je donecopying
    cmp al, 02h
    je donecopying
    mov word ptr [error], offset csource
    jmp definiteErrorHandle
  fpf:
  call backfiledta                      ; backup the search specification

  keepcopying:
  call setFiles                         ; set current source & destination
                                        ; filename buffers sfile/dfile
  call checkDestination

  mov byte ptr [filesfound], 1

  call openfiles
  test byte ptr [config], 00000100b
  jz skipcfile

  call copyFile
  call closefiles

  skipcfile:
    call findnext
    jnc keepcopying
    cmp al, 12h                         ; last file?
    jne keepcopying                     ; no, keep copying
    jmp findclose

  donecopying:
  ret
;---------------------------------------------------------
getattributes:
  xor al, al
  xor bl, bl
jmp attributecore
;---------------------------------------------------------
setattributes:
  and cx, 0000000000100111b             ; can't set volume label, dir, etc
  mov al, 01h
  mov bl, 01h
;---------------------------------------------------------
attributecore:
  test byte ptr [config], 00100000b
  jnz dolfnsetattributes
  mov ah, 43h
  jmp docheck2

  dolfnsetattributes:
  mov ax, 7143h
  stc

  docheck2:
  int 21h
ret
;---------------------------------------------------------
; Ask if the destination file should be replaced
;
; Sets [config] flags appropriately
;
replaceQuery:

  test byte ptr [config], 01000000b
  jz dontSkipExisting
    and byte ptr [config], 11111011b
  dontSkipExisting:
  test byte ptr [config], 00001000b
  jz abortreplacequery

  mov dx, offset owmsg
  call printstring
  call displayfile
  mov dx, offset ynamsg
  call printstring

  regetkey:

    mov ah, 00h
    int 16h

    cmp al, 3                           ; CTRL+C
    je quit

    cmp al, 97
    jb nocaseadjust
    sub al, 32
    nocaseadjust:

    cmp al, 'Y'
    je displaykey
    cmp al, 'A'
    je replaceallfiles
    cmp al, 'N'
    jne regetkey

  noreplacefile:
    and byte ptr [config], 11111011b
    jmp displaykey
  replaceallfiles:
    and byte ptr [config], 11110111b
  displaykey:
    mov dl, al
    call printchar
    jmp return

  abortreplacequery:
  ret
;---------------------------------------------------------
restdirdta:
  mov si, offset dirdta
  jmp restdtacommon

restfiledta:
  mov si, offset filedta

restdtacommon:
  test byte ptr [config], 00100000b
  jnz norestneeded
  mov cx, 13
  mov di, word ptr [dta]

  rep movsb
norestneeded:
ret
;---------------------------------------------------------
backdirdta:
  mov di, offset dirdta
  jmp backdtacommon

backfiledta:
  mov di, offset filedta

backdtacommon:
  test byte ptr [config], 00100000b
  jnz nobackneeded
  mov cx, 13
  mov si, word ptr [dta]

  mnbop:                             ; backup dta data
    mov al, byte ptr [es:si]
    mov byte ptr [di], al
    inc si
    inc di
  loop mnbop
nobackneeded:
ret
;---------------------------------------------------------
displayfile:
  mov al, '$'
  mov dx, offset rfile
  call setLastByte
  jmp printstring                       ; jmp instead of call/ret
;---------------------------------------------------------
; frindex = 0FFFFh needs to be checked

backupfr:                               ; back up file record
  mov bx, word ptr [frindex]
  mov dx, bx
  shl bx, 1
  inc word ptr [frindex]
  test byte ptr [config], 00100000b
  jnz dolfnbkfr
    shl dx, 1
    shl dx, 1
    add bx, dx
    mov si, word ptr [dta]
    mov dx, word ptr [es:si+0Fh]
    mov word ptr [frarray+2+bx], dx
    mov dx, word ptr [es:si+11h]
    mov word ptr [frarray+4+bx], dx
    mov dx, word ptr [es:si+0Dh]
    jmp donebackupfr
  dolfnbkfr:
    mov dx, word ptr [findhandle]
  donebackupfr:
    mov word ptr [frarray+bx], dx
  ret
;---------------------------------------------------------
; frindex = 0 needs to be checked

restorefr:
  dec word ptr [frindex]
  mov bx, word ptr [frindex]
  shl bx, 1
  test byte ptr [config], 00100000b
  jnz dolfnrsfr
    mov dx, word ptr [frindex]
    shl dx, 1
    shl dx, 1
    add bx, dx
    mov si, word ptr [dta]
    mov dx, word ptr [frarray+bx]
    mov word ptr [es:si+0Dh], dx
    mov dx, word ptr [frarray+bx+2]
    mov word ptr [es:si+0Fh], dx
    mov dx, word ptr [frarray+bx+4]
    mov word ptr [es:si+11h], dx
  jmp drfr
  dolfnrsfr:
    mov dx, word ptr [frarray+bx]
    mov word ptr [findhandle], dx
  drfr:
  ret
;---------------------------------------------------------
openfiles:
  or byte ptr [config], 00000100b       ; default to replacing file
  mov dx, offset dfile
  call getattributes            ; \\\attributes to find need to be changed?
  jc nonexistantfile
    call replaceQuery
  nonexistantfile:
  test byte ptr [config], 00000100b     ; copy this file?
  jz skipthisfile

;  mov dx, offset dfile                  ; check for read-only attribute
;  call getattributes
;  jc abortsetattrib
;    test cl, 00000001b
;    jz abortsetattrib
;    and cl, 11111110b                   ; unset it, if set
;    call setattributes
;  abortsetattrib:

  test byte ptr [config], 00000010b     ; display the file that
  jz dontdispfile                       ; is currently being copied
    call displayfile
    call return
  dontdispfile:

  call openFile
  mov word ptr [error], offset sfile
  call errorHandle
  mov word ptr [shandle], ax

  call createFile
  mov word ptr [error], offset dfile
  call errorHandle
  mov word ptr [dhandle], ax

  skipthisfile:
  mov bx, offset rfile
  jmp trimdir                           ; jmp instead of call/ret
;---------------------------------------------------------
closefiles:
  mov ah, 3Eh
  mov bx, word ptr [dhandle]    ; close source & destination files
  int 21h

  mov ah, 3Eh
  mov bx, word ptr [shandle]
  int 21h
  ret
;---------------------------------------------------------
copyFile:
  mov word ptr [error], offset sfile
  mov bx, word ptr [shandle]            ; read from file
  mov cx, 32768
  mov dx, offset buffer
  mov ah, 3Fh
  int 21h
  call errorHandle

  test ax, ax
  jz donecopy

  mov word ptr [error], offset dfile
  mov cx, ax
  mov ah, 40h
  mov bx, word ptr [dhandle]
  int 21h
  call errorHandle                      ; ///\\\disk full check needed (ax<cx)

  cmp cx, 32768
  je copyFile

  donecopy:
  inc word ptr [files]
  ret
;---------------------------------------------------------
errorHandle:
  jnc noErrorHandling
  definiteErrorHandle:
    cmp al, 03h
    je pathnotfound
    cmp al, 05h
    je accessdenied

    mov dx, offset uemsg
    cmp al, 02h
    jne unknownerror

    filenotfound:
    mov dx, offset fnfmsg       ; if the file wasn't found, then
    call printstring            ; print "file not found - [filename]"
    mov dx, offset wildcard
    jmp appendError

    pathnotfound:
    mov dx, offset pnfmsg       ; if the path wasn't found, then
    call printstring            ; print "path not found - [path]"
    mov dx, word ptr [error]
    jmp appendError

    accessdenied:
    mov dx, offset admsg
    call printstring
    mov dx, word ptr [error]
    appendError:
      mov al, '$'
      call setLastByte

      unknownerror:
      call printstring
      jmp quit

  noErrorHandling:
  ret
;---------------------------------------------------------
setFiles:
  mov dx, offset destination            ; copy the destination path
  mov bx, offset dfile                  ; to 'dfile'
  call appendstring
  mov ax, bx
  mov dx, offset source                 ; copy the source path
  mov bx, offset sfile                  ; to 'sfile'
  call appendstring

  test byte ptr [config], 00100000b
  jnz uselfnsu

  push es
  pop ds
  mov dx, word ptr [dta]                ; copy the name of the first
  add dx, 1Eh                           ; file found to the end
  call appendstring                     ; of 'sfile' and 'dfile'
  mov bx, ax
  call appendstring

  mov bx, offset rfile                  ; copy it to "rfile" too
  call findend
  call appendstring
  push cs
  pop ds

ret

uselfnsu:
  mov dx, offset frecord+2Ch            ; do the same as above only for LFN
  call appendstring
  mov bx, ax
  call appendstring
  mov bx, offset rfile                  ; copy it to "rfile" too
  call findend
  jmp appendstring                      ; jmp instead of call/ret
;---------------------------------------------------------
checkCyclic:
  test byte ptr [config], 00010000b
  jz abortcyclic

  mov si, offset source
  mov di, offset struename
  call truename
  mov si, offset destination
  mov di, offset dtruename
  call truename

  mov si, offset struename
  mov di, offset dtruename

  continuecomparison:
    lodsb
    cmp al, 0
    je samepath
    cmp al, byte ptr [di]
    jne abortcyclic
    inc di
  jmp continuecomparison

  samepath:
    mov dx, offset cyclic
  call printstring
  abortcyclic:
  ret
;---------------------------------------------------------
checkPath:

  mov bx, offset destination
  call findend
  cmp bx, offset destination            ; path is 0 bytes long?
  je dontappendslash
  cmp byte ptr [bx-1], ':'              ; drive letter?
  je dontappendslash
    mov dx, offset destination
    mov al, '\'
    call setLastByte
  dontappendslash:

  mov si, offset destination
  mov di, offset dtruename
  call truename

  mov dx, offset dtruename
  mov al, '.'
  call setLastByte
  mov dx, offset dtruename
  call getattributes
  jnc destexists
    mov dx, offset fakedest
    call printstring
    jmp quit
  destexists:
ret
;---------------------------------------------------------
; Check if the source file is the same as the destination file
;
checkDestination:
  mov si, offset sfile
  mov di, offset struename
  call truename
  mov si, offset dfile
  mov di, offset dtruename
  call truename

  mov si, offset struename
  mov di, offset dtruename

  comparenextbyte:
    lodsb
    cmp al, byte ptr [di]
    jne different
    cmp al, 0
    je same
    inc di
  jmp comparenextbyte

  same:
    mov dx, offset srcdest
    call printstring
    jmp quit

  different:
  ret
;---------------------------------------------------------
truename:
  mov dx, si
  mov bx, offset tempbuffer
  call appendstring
  mov dx, offset tempbuffer
  cmp bx, dx
  je adddot
  cmp byte ptr [bx-1], ':'
  jne skipadddot
    adddot:
    mov al, '.'
    call setLastByte
  skipadddot:
  mov si, offset tempbuffer

  mov ah, 60h

  test byte ptr [config], 00100000b
  jz sfntruename
    mov ax, 7160h
    xor cx, cx
  sfntruename:
  int 21h

  ; ////\\\Error checking needed
  ret
;---------------------------------------------------------
createFile:
  mov al, 1
  jmp dofileop
openFile:
  mov al, 0
  dofileop:
  mov cx, 0020h                         ; archive attribute
  test byte ptr [config], 00100000b
  jnz dolfndx
    test byte ptr [config], 00000001b   ; retain attributes?
    jz nonlfnat
      mov bx, word ptr [dta]
      mov cl, byte ptr [bx+15h]         ; attributes
    nonlfnat:
    mov ah, 3Ch
    mov dx, offset dfile
    cmp al, 1
    je wcfnlfn
      mov ah, 3Dh
      mov dx, offset sfile
    wcfnlfn:
    int 21h
  ret

  dolfndx:
    test byte ptr [config], 00000001b
    jz nolfnat
      mov cl, byte ptr [frecord]        ; retain attributes
    nolfnat:
    mov dx, 10010b                      ; create file
    mov bx, 0001h
    mov si, offset dfile
    cmp al, 1
    je dcflfn
      mov si, offset sfile
      mov dx, 1b                        ; file reading stuff
      xor bx, bx
    dcflfn:
    mov ax, 716Ch
    int 21h
  ret
;---------------------------------------------------------
appendstring:                   ; overwrites string 'bx' with
  push si                       ; string 'dx' until a 00h is hit
  push ax                       ; in string 'dx'
  mov si, dx
  cappends:                     ; the function is called 'append...'
  lodsb                         ; because strings may then be appended
  mov byte ptr [cs:bx], al      ; to string 'bx' if the register is
  cmp al, 00h                   ; preserved until the next call
  je doneas
  inc bx
  jmp cappends
  doneas:
  pop ax
  pop si
  ret
;---------------------------------------------------------
findfirst:
  mov ch, byte ptr [rattr]
  mov cl, byte ptr [fattr]

  test byte ptr [config], 00100000b
  jz nolfnfindfirst
  mov di, offset frecord
  mov ax, 714Eh
  xor si, si
  int 21h
  mov word ptr [findhandle], ax
  ret

nolfnfindfirst:
  mov ah, 4Eh           ; should al=00h?  what's this about append?
  int 21h
  ret
;---------------------------------------------------------
findnext:
  test byte ptr [config], 00100000b
  jz nolfnfindnext
  mov bx, word ptr [findhandle]
  mov di, offset frecord
  mov ax, 714Fh
  xor si, si
  int 21h
  ret

nolfnfindnext:
  mov ah, 4Fh
  int 21h
  ret
;---------------------------------------------------------
findclose:
  test byte ptr [config], 00100000b
  jz nofindclose

  mov ax, 71A1h
  mov bx, word ptr [findhandle]
  int 21h

  nofindclose:
ret
;---------------------------------------------------------
setLastByte:                    ; locates 00h in string 'dx' and replaces
  mov bx, dx                    ; it with 'al', but only if 'al' doesn't
                                ; already match the last byte
  cas:
  cmp byte ptr [bx], 0
  je enf
  inc bx
  jmp cas

  enf:
  cmp byte ptr [bx-1], al
  je abortas
  mov byte ptr [bx], al
  mov byte ptr [bx+1], 00h
  abortas:
  ret
;---------------------------------------------------------
findend:                    ; find the end of 'bx' (because it's=00h)
  cmp byte ptr [bx], 00h
  je foundend
    inc bx
    jmp findend
  foundend:
  ret
;---------------------------------------------------------
trimdir:                     ; cuts the file/wildcard from a directory (bx)
  xor cx, cx

  nextdirbyte:
  cmp byte ptr [bx], 00h
  je foundenddec
  inc bx
  inc cx
  jmp nextdirbyte
  foundenddec:
  dec bx

  decdir:
  jcxz donetrim
  mov byte ptr [bx], 00h
  dec bx
  dec cx
  cmp byte ptr [bx], ':'
  je donetrim
  cmp byte ptr [bx], '\'
  jne decdir

  donetrim:
  inc bx
  ret
;---------------------------------------------------------
set_wildcard:

  ; This section doubles as an LFN-support check
  ; I don't like it at all.  The 'jmp' could cause an endless loop,
  ; and I'm not certain that 7100h will be returned for 7143h.
  mov dx, offset source
  call getattributes
  jnc no_carry
    cmp ax, byte 0001h                  ; CM -- LFN functions not available?
    je nolfn                            ; CM -- yes; record and use SFN
                                        ;   function instead
    cmp ax, 7100h                       ; some sort of win95 error?
    jne donecp                          ; no; success or SFN called
    nolfn:
      and byte ptr [config], 11011111b  ; use sfn
      jmp set_wildcard
  no_carry:
    test cl, 00010000b                  ; is the source a directory?
    jz donecp
      mov al, '\'
      call setLastByte                  ; then append a slash
  donecp:

  test byte ptr [config], 00100000b
  jnz dontgetdta
    mov ah, 2Fh                         ; get DTA
    int 21h                             ; ES is now DTA segment
    mov word ptr [dta], bx
  dontgetdta:

  mov dx, offset destination
  call getattributes
  jc pmwd

  test cl, 00010000b
  jz pmwd
    mov al, '\'
    call setLastByte
  pmwd:

  mov bx, offset source
  call findend
  cmp bx, offset source
  je adddefaultwildcard
  cmp byte ptr [bx-1], '\'
  je stardotstar
  cmp byte ptr [bx-1], ':'      ; drive letter
  jne notstardotstar
  stardotstar:
    adddefaultwildcard:
    mov dx, offset defaultwildcard
    call appendstring
  notstardotstar:

  cmp byte ptr [wildcard], 00h
  jne wcret

  mov bx, offset source
  call findend

  movebackmore:
  cmp bx, offset source         ; next find the last slash by moving
  je sready                     ; backwards.  assume the entire source
  dec bx                        ; is the wildcard if there's no slash or
  cmp byte ptr [bx], ':'        ; colon (in case of C:*.* or similar)
  je dontmoveback
  cmp byte ptr [bx], '\'
  jne movebackmore
  dontmoveback:
  inc bx

  sready:

  mov si, offset wildcard
  kctsw:
  mov al, byte ptr [bx]
  cmp al, 00h
  je wcret
  mov byte ptr [bx], 00h
  mov byte ptr [si], al
  inc si
  inc bx
  jmp kctsw

  wcret:

  ret
;---------------------------------------------------------
check_switches:
  mov si, offset cmdbuffer

  nextswitch:
    mov dl, ' '
    lodsb
    cmp al, 0
    je noswitches
    cmp al, '/'
    je switchfound              ; if the byte is a slash, its a switch
    cmp al, ' '
    je nextswitch               ; if it's a space, skip to the next byte
    cmp al, '"'
    jne notquoted
    mov dl, '"'
    cmp byte ptr [si], '/'
    je skipthisone
  notquoted:
    mov bx, offset source       ; if the length of "source" is 0, then
    cmp byte ptr [bx], 0        ; we don't have one yet, so fill it
    je dofill
    mov bx, offset destination  ; if length of source is not zero,
    cmp byte ptr [bx], 0        ; & "destination" is not zero, then
    jne help                    ; number of parameters is invalid
    dofill:
    cmp al, '"'                 ; was the byte we loaded a double quote?
    je skipthisone
    mov byte ptr [bx], al       ; start filling in the source/destination
    inc bx
    skipthisone:
    lodsb
    keepgoing:
    cmp al, 0
    je noswitches
    cmp al, '/'
    je switchfound
    cmp al, '"'
    je nextswitch
    cmp dl, '"'
    je dofill
    cmp al, ' '
    je nextswitch
  jmp dofill

  switchfound:
    lodsw
    cmp al, 0
    je cmderror
    cmp dl, '"'    ; if a double quote was already used, then
    je sdno        ; it is not a one letter switch (made by a space)
    cmp ah, ' '
    je switchok1   ; space indicates a single-letter switch
    sdno:
    cmp ah, 0      ; must be a single letter switch if its the buffer end
    je switchok1        
    cmp ah, '/'    ; another slash means its another switch (single-letter)
    je switchok1
    cmp ah, '"'    ; double-quotes?  then its the start of another parameter
    je switchok1   ; or the end of this one
    cmp al, '"'
    je switchok0   ; if its the current byte that's a double quote, then
    switchnotok:
    sub si, 3
    jmp cmderror

    switchok0:
      dec si           ; then move the slash back by one and pretend we've
                       ; just found a slash by placing one at the previous pos
      mov byte ptr [si-1], '/'
      mov dl, '"'      ; setting the double-quote and jumping back to
    jmp switchfound    ; switchfound to check to see if its valid

    switchok1:
      cmp al, '?'
      je help
      call fixAL
      cmp al, 'Y'
      je yswitch
      cmp al, 'Q'
      je qswitch
      cmp al, 'K'
      je kswitch
      cmp al, 'R'
      je rswitch
      cmp al, 'L'
      je lswitch
      cmp al, 'N'
      je nswitch
      jmp switchnotok

    rswitch:
      or byte ptr [config],  00010000b
      jmp doneswitch

    kswitch:
      or byte ptr [config],  00000001b
      jmp doneswitch

    yswitch:
      and byte ptr [config], 11110111b
      jmp doneswitch

    nswitch:
      and byte ptr [config], 11110111b
      or byte ptr [config],  01000000b
      jmp doneswitch

    lswitch:
      and byte ptr [config], 11011111b
      jmp doneswitch

    qswitch:
      and byte ptr [config], 11111101b

    doneswitch:
      dec si
      cmp byte ptr [si], '"'
      je skipthisone
      cmp ah, 0
      jne nextswitch

  noswitches:
    cmp byte ptr [source], 0
    je help
  ret
;---------------------------------------------------------
help:
  mov dx, offset helpmsg
  call printstring
  jmp quit
;---------------------------------------------------------
fixAL:          ; capitalizes AL
  cmp al, 'a'
  jb donefixing
  cmp al, 'z'
  ja donefixing
  sub al, 32
  donefixing:
  ret
;---------------------------------------------------------
fillcmdbuffer:
  mov si, 0080h                         ; grab command line length
  lodsb
  xor ah, ah
  mov cx, ax
  mov di, offset cmdbuffer
  mov dl, ' '
  jcxz nobuffer
  copbuf:
  lodsb
  cmp al, '"'
  je switchdl
  doneswitchdl:
  cmp dl, '"'
  je iasc
  cmp al, ';'                           ; check for any characters that
  je cts                                ; are typically treated like
  cmp al, ','                           ; spaces and convert them to space
  je cts
  cmp al, '='
  je cts
  iasc:
  cmp al, 9
  jne dtc
  cts:
    mov al, ' '
  dtc:
  stosb
  loop copbuf
  nobuffer:
  ret

  switchdl:
    cmp dl, '"'
    je unswitchdl
    mov dl, '"'
  jmp doneswitchdl
  unswitchdl:
    mov dl, ' '
  jmp doneswitchdl
;---------------------------------------------------------
cmderror:
  push si
  inc si

  keepgoin:
    lodsb
    cmp dl, '"'
    je nendo
      cmp al, 32
      je endothis
    nendo:
    cmp al, 0
    je endothis
    cmp al, '"'
    je endothis
    cmp al, '/'
    jne keepgoin

  endothis:
    mov dx, offset invparm
    call printstring
    mov byte ptr [si-1], '$'
    pop dx
    call printstring
  jmp quit
;---------------------------------------------------------
printchar:
  push ax
  mov ah, 02h
  int 21h
  pop ax
  ret
;---------------------------------------------------------
return:
  mov dl, 13
  call printchar
  mov dl, 10
  jmp printchar                 ; jmp instead of call/ret
;---------------------------------------------------------
printstring:
  push ax
  mov ah, 09h
  int 21h
  pop ax
  ret
;---------------------------------------------------------
int24h:
  iret
;---------------------------------------------------------




;---------------------------------------------------------
section .data align=1

helpmsg     db 'Usage: XCOPY {source} [destination] [switch(es)]',13,10
            db 9,'/Y - Overwrite existing files.',13,10
            db 9,'/N - Do not overwrite existing files.',13,10
            db 9,'/Q - Do not display filenames while copying.',13,10
            db 9,'/L - Do not use LFN functions if available.',13,10
            db 9,'/K - Retain attributes.',13,10
            db 9,'/R - Recursive copy.$'

fcmsg           db ' File(s) copied$'
owmsg           db 'Overwrite $'
ynamsg          db ' (Yes/No/All)?$'
fakedest        db 'Destination does not exist!$'
srcdest         db 'Source matches destination!$'
cyclic          db 'Cannot perform a cyclic copy!$'
invparm         db 'Invalid parameter - $'
fnfmsg          db 'File not found - $'
pnfmsg          db 'Path not found - $'
admsg           db 'Access denied - $'
uemsg           db 'Unknown Error - $'

defaultwildcard db '*.*',00h

config      db 00101110b        ; bit configuration:
                                ;       00000001: retain attributes
                                ;       00000010: display copied files
                                ;       00000100: copy current file
                                ;       00001000: ask about existing files
                                ;       00010000: recurse
                                ;       00100000: use LFN
                                ;       01000000: don't overwrite

fattr       db 00100111b        ; file attributes to find
rattr       db ?                ; required attributes to find
error       dw ?                ; used to pass a string to print
                                ; when an error message is printed

dta         dw ?                ; disk transfer address
findhandle  dw ?                ; filefind handle
shandle     dw ?                ; source file handle
dhandle     dw ?                ; destination file handle

old24h      dd ?

section .bss

wildcard    resb 300              ; wildcard to be copied
source      resb 300              ; source path
destination resb 300              ; destination path
csource     resb 300              ; source path & wildcard
sfile       resb 300              ; source file to be copied
dfile       resb 300              ; destination file to be copied to
struename   resb 300              ; truename for source file to be copied
dtruename   resb 300              ; truename destination file to be copied to
rfile       resb 300              ; ? name to display ?
tempbuffer  resb 300              ; temporary buffer for truename

frecord     resb 318              ; find record
cmdbuffer   resb 130              ; buffer containing command line arguments
buffer      resb 32768            ; buffer for file data
vbuffer     resb 6                ; buffer to store # of files as ascii
filedta     resb 13               ; backup of the find parameters from dta
dirdta      resb 13               ; backup of the find parameters from dta
filesfound  resb 1                ; flag stating that files have been found
files       resw 1                ; total number of files copied
directories resw 1                ; total number of directories created
frindex     resw 1                ; find record backup index
frarray     resb 20000            ; find record backups

