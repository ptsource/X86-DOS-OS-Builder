;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************
	title WHEREIS
	page  55,131

whereis segment public
        assume cs:whereis,ds:whereis

;equates

COMMAND_LINE    EQU     80H + 2
NULL            EQU     00H
CR              EQU     0DH
LF              EQU     0AH
MAX_SCAN_LEN    EQU     64
TERMINATE       EQU     20H
DIRECTORY       EQU     10H
DOT             EQU     '.'
STAR		EQU	'*'
PRINT_CHAR      EQU     02H
SET_DTA         EQU     1AH
SEARCH_FIRST    EQU     4EH
SEARCH_NEXT     EQU     4FH
DOS_CALL        EQU     21H
PATH_SEPARATOR  EQU     '\'

;macros

CLEAR   macro   reg
        xor     reg,reg
        endm

;this is the format for the dos data transfer area used when dos 2.0
;searches for file match in directories

dta     struc
        reserved        db      21 dup (?)
        attribute       db	?
        time            dw	?
        date            dw	?
        size            dd	?
        name_found      db      13 dup (?)
dta     ends

        org     100h
main    proc    far

;  this is the main program that sets up the initial conditions for
;  search_directory which in turn, does a recursive search.
;       reads:  path_name
;       writes: file_name
;       calls:  search_directory
;

mainline proc   near

start:
	mov	bp, 0				;Clear DOT_FLAG.
        mov     si, COMMAND_LINE                ;start of command line
        mov     di, offset file_name

get_search_name:
        lodsb                           ;get first char
	cmp	al, DOT			;Is it a dot?
	jne	check_CR		;No, then check for carriage return.
	mov	bp, 1			;Yes, then set DOT_FLAG.
	stosb
	jmp	get_search_name		;Loop --
check_CR:
        cmp     al, CR
        je      done_reading_name       ;if carriage return
        stosb
        jmp     get_search_name         ;Loop --
done_reading_name:
	cmp	bp, 1			;Was a dot seen?
	je	terminate_name		;Yes, go finish name processing.
	mov	al, DOT			;No, then append ".*" to file spec.
	stosb
	mov	al, STAR
	stosb
terminate_name:
        CLEAR   al                      ;store zero at end
        stosb
        mov     di, offset path_name
        CLEAR   al
        cld
        mov     cx, MAX_SCAN_LEN
        repnz   scasb
        mov     bx,di
        dec     bx                      ;ds:bx points to end of path_name
        mov     dx,NULL
        call search_directory
        int     TERMINATE
mainline endp

; this procedure searches all the files in the current directory
; looking for a match.  It also prints the full name for each match
;
;       ds:bx   pointer to end of current path name
;       ds:dx   old disk transfer area (dta)
;
; reads:        disk transfer area (dta)
; writes:       disk transfer area (dta)
; calls         build_name, get_first_Match
;               write_matched_name, get_next_match
;               build_star_name, search_sub_directory
;
search_directory proc   near

        push    si
        push    dx
        call    build_name
        call    get_first_match
        jc      no_match                                ;If no match --
        call    write_matched_name
find_next_file:
        call    get_next_match
        jc      no_match
        call    write_matched_name
        jmp     find_next_file                          ;Loop --

no_match:
        pop     dx
        push    dx
        call    build_star_name
        call    get_first_match
        jc      no_more_matches                 ;If no match --
        mov     si,dx
        test    [si].attribute,DIRECTORY
        jnz     is_directory                    ;If directory entry --
find_next_directory:
        call    get_next_match
        jc      no_more_matches                 ;If no more entries --
        test    [si].attribute,DIRECTORY
        jz      find_next_directory             ;If not a directory --
is_directory:
        cmp     [si].name_found,DOT
        je      find_next_directory             ;If it's . or ..
        call    search_sub_directory            ;search sub directory
        push    ax
        mov     ah,SET_DTA
        int     DOS_CALL
        pop     ax
        jmp     find_next_directory
no_more_matches:
        pop     dx
        pop     si
        ret

search_directory  endp
page
; This procedure searches the sub directory who's name is in dta
;
;       ds:bx   end of the current pathname
;       ds:[dx].name_found      name of subdirectory for search
;
; reads:        path_name
; writes:       path_name
; calls:        search_directory
;

search_sub_directory  proc  near

        push    di
        push    si
        push    ax
        push    bx
        cld
        mov     si, dx
        add     si, offset name_found
        mov     di,bx
copy_loop:
        lodsb
        stosb
        or      al,al
        jnz     copy_loop
        mov     bx,di
        std
        stosb
        mov     al,PATH_SEPARATOR
        stosb
        call    search_directory
        pop     bx
        mov     byte ptr [bx],NULL
        pop     ax
        pop     si
        pop     di
        ret

search_sub_directory  endp
page

; This procedure prints the matched name after the path name
;
;  ds:dx        pointer to current disk transfer area
;
; reads:        path_name, name_found (in dta)
; writes:       write_string, send_crlf
;

write_matched_name      proc    near

        push    ax
        push    dx
        mov     dx,offset path_name
        mov     al,[bx]
        mov     byte ptr [bx],NULL
        call    write_string
        mov     [bx],al
        pop     dx
        push    dx
        add     dx, offset name_found
        call    write_string
        call    send_crlf
        pop     dx
        pop     ax
        ret
write_matched_name endp


;  This procedure builds an absolute search name from path_name
;  followed by file_name
;
;  reads:       file_name
;  calls:       build   (to build the name)
;

build_name      proc    near

        push    si
        mov     si, offset file_name
        call    build
        pop     si
        ret
build_name      endp

build_star_name proc    near
        push    si
        mov     si, offset star_name
        call    build
        pop     si
        ret
build_star_name endp

page
; This procedure appends the string at ds:si to path_name in
; path_name.  It knows where the path name ends from knowing
; how long path_name is.
;
;       ds:si   name of file
;       ds:bx   end of path_name
;
; reads:        ds:si
; writes:       path_name
;

build   proc    near
        push    ax
        push    di
        mov     di,bx
        cld
copy_name:
        lodsb
        stosb
        or      al,al
        jnz     copy_name                       ;If not end of string yet --
        pop     di
        pop     ax
        ret
build   endp

; This procedure find the first match between the name given by
; ds:dx and the directory entries found in the directory path_name
;
;       ds:dx   pointer to current disk transfer area
;
;  returns:
;       cf      0       a match was found
;               1       no match found
;       ax              error code returned
;               2       file not found
;               18      no more files
;       ds:dx           pointer to new disk transfer area
;
; reads:        path_name
; writes:       disk_transfer_areas
;

get_first_match proc    near

        push    cx
        cmp     dx,NULL
        ja      allocate                ;go allocate space --
        mov     dx, offset disk_transfer_areas-type dta
allocate:
        add     dx,type dta
        mov     cx,DIRECTORY
        mov     ah,SET_DTA
        int     DOS_CALL
        push    dx
        mov     dx, offset path_name
        mov     ah,SEARCH_FIRST                 ;call for find first match
        int     DOS_CALL
        pop     dx
        pop     cx
        ret
get_first_match endp


; This procedure is much like get_first_match
;
; returns:
;       cf      0       a match was found
;               1       no match found
;       ax              error code returned
;               2       file not found
;               18      no more files
;
; reads:        path_name
; writes:       disk_transfer_areas
;

get_next_match  proc    near
        push    cx
        push    dx
        mov     dx, offset path_name
        mov     cx,DIRECTORY
        mov     ah,SEARCH_NEXT
        int     DOS_CALL
        pop     dx
        pop     cx
        ret
get_next_match  endp

; This procedure sends a crlf pair of characters to the screen
;

send_crlf       proc    near

        push    ax
        push    dx
        mov     ah,PRINT_CHAR
        mov     dl,CR
        int     DOS_CALL
        mov     dl,LF
        int     DOS_CALL
        pop     dx
        pop     ax
        ret
send_crlf       endp

; This procedure writes the asciiz string at
;  ds:dx        address of asciiz string
;

write_string    proc    near

        push    ax
        push    dx
        push    si
        cld
        mov     si,dx
        mov     ah,PRINT_CHAR
        lodsb
write_string_loop:
        mov     dl,al
        int     DOS_CALL
        lodsb
        or      al,al
        jnz     write_string_loop
        pop     si
        pop     dx
        pop     ax
        ret
write_string    endp

; This is the data storage area and must be the last thing
; in the program.
;

star_name       db      '*.*',NULL
path_name       db      PATH_SEPARATOR,NULL
                db      80 dup (0)      ;space for 64 char pathname and
                                        ;13 char filename
file_name       db      13 dup (0)      ;save room for full dos filename

disk_transfer_areas label byte          ;this must start at the end of whereis

main    endp

whereis ends

        end     start
