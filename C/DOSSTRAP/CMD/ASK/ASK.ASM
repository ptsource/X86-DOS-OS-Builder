;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************
argl    equ     80h             ; start of command line
special equ     '^'             ; the special escape character
switch  equ     '/'             ; switch character preceeding options
cmdlen  equ     150             ; max length of converted cmd line
maxargc equ     4               ; max # of arguements
squote  equ     39              ; ASCII of '

all     segment 'code'
        assume  cs:all,ds:all
        org     100h
entry:  jmp     start

;********************** data area ***********************
line    db      cmdlen dup(?)   ; store the converted command line
argc    db      ?
argv    dw      maxargc * 2 dup(?)      ; *argv[]
option  db      1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1
              ; a b c d e f g h i j k l m n o p q r s t u v w x y z
                ; 0 = option off, 1=invalid option, 2 = option on
cry     db      'unknown option ',squote
unkopt  db      ?               ; fill in the unknown option here
        db      squote,' ignored',13,10,'$'

;*********************** code area **********************
; getc returns a converted character. bx should point to command line
; cl should contain the length of the command line
; ah=0 if normal character; ah='\' if special character.

three   db      ?               ; for counting down from 3
ten     db      10              ; for multiplying

getc    proc    near
        xor     ax,ax           ; clear character
        sub     cl,1            ; len = len - 1
        jc      eoln            ; reached end of command line

        mov     al,[bx]         ; get a character
        inc     bx              ; point to next one
        cmp     al,special      ; is it the special char '\' ?
        jnz     normal          ; nop; just a normal character

        sub     cl,1            ; len = len - 1
        jc      eoln            ; last character is '\'; ignore it

        mov     ah,al           ; flag special char
        mov     al,[bx]         ; get the next char
        inc     bx              ; point to next char

; translate \nnn characters into ascii
        cmp     al,'0'          ; see if first n is a digit
        jb      notdig          ; not a digit
        cmp     al,'9'
        ja      notdig          ; not a digit

; first n is a digit
        xor     ch,ch           ; init accumulator
        mov     three,3         ; convert 3 digits at most

digit:
        sub     al,'0'          ; convert to binary
; now multiply cl by ten and add al to it
        xchg    al,ch           ; do this so we can use al to multiply
        mul     ten             ; assume result is still 8 bits
        add     ch,al           ; one digit is done.

; more digits?
        dec     three
        jz      gotit           ; converted all three digits
        mov     al,[bx]         ; examine next char
        cmp     al,'0'          ; is it a digit
        jb      gotit           ; not a digit; end translation
        cmp     al,'9'
        ja      gotit           ; not a digit; end translation
        inc     bx              ; point to next char
        jmp     digit           ; process digit

gotit:
        mov     ah,special      ; flag special char even for \nnn
        mov     al,ch           ; return char in al
        ret
normal:
        ret

notdig:                         ; not \nnn (e.g. \a \b \c \d ...)
        cmp     al,special      ; \\ => \
        je      skip
        cmp     al,'"'          ; \" => "
        je      skip
        and     al,31           ; \a => ctrl-a; \b => ctrl-b; ...
skip:
        ret

eoln:
        xor     ax,ax           ; return end-of-line char
        ret

getc    endp

;*********************** prts **********************
count   dw      ?
p       dw      ?

prts    proc    near            ; print string to stdout; si points to string
        mov     ax,[si+2]       ; pointer to string
        mov     p,ax            ; save pointer
        mov     ax,[si]         ; get length of string
        mov     count,ax

ploop:  sub     count,1
        jc      d1              ; end of string
        mov     bx,p
        mov     dl,[bx]         ; current character to be printed
        inc     p               ; point to next character
        mov     ah,2            ; function number for print character
        int     21h             ; print character
        jmp     ploop           ; repeat

d1:     ret
prts    endp

;********************* main *********************

mc      db      ?               ; loop index
char    db      ?               ; key pressed by user

crlf    db      13,10,'$'       ; crlf string

helpms  db      'Usage:',13,10
        db      '  ask [',switch,'c',switch,'q] '
        db      '"prompt message" "expected response"',13,10
        db      '    ',switch
        db      'c makes the response case sensitive',13,10
        db      '    ',switch,'q will accept non-expected response (returns'
        db      ' 0)',13,10
        db      '    "prompt message" and "expected response" are quoted'
        db      ' strings',13,10
        db      '    To embed special characters use ',special
        db      'nnn where nnn is a 3-digit ASCII',13,10
        db      '    or ',special,'a for ctrl-a, ',special,'b for'
        db      ' ctrl-b, ... (except ',special,special,' for ',special
        db      ' itself',13,10,'    and ^" for the quote character)',13,10
        db      '  Response can be tested with if errorlevel',13,10
        db      '  Errorlevel is set to index("expected response",key '
        db      'pressed)',13,10
        db      '$'
nom     db      '*BEEP*  Unexpected response',13,10,'$'

start   proc    near

        mov     bx,argl         ; start of parameters
        mov     cl,[bx]         ; length of parameter
        inc     bx              ; now point to first char
        mov     di,offset line  ; point to convert line buffer
        mov     si,offset argv - 4      ; point to *argv[0] - 4

        mov     argc,0          ; normally start at 1; but for ask.com 0 is ok

; now split command line into arguements in argv[]
loop:
        cmp     argc,maxargc    ; can we handle more arguements?
        jae     done            ; if not; get out

        call    getc            ; convert one character
        or      ax,ax           ; check for done
        jz      done            ; end of command line

        cmp     al,' '          ; a blank space?
        jz      loop            ; skip it

; now we must be seeing the beginning of an arguement
        inc     argc            ; count it
        add     si,4            ; point to next *argv[]
        mov     [si+2],di       ; where string start
        mov     word ptr [si],0 ; set length to 0

        mov     dx,' '          ; assume this is the separator
        cmp     ax,'"'          ; start of quoted string?
        jne     noquote         ;
        mov     dx,'"'          ; make this the separator
        jmp     next            ; don't store the first "

noquote:
        mov     [di],al         ; store the character
        inc     di
        inc     word ptr [si]   ; increment argv's length
next:
        call    getc
        or      ax,ax
        jz      done            ; end of arguement

        cmp     ax,dx           ; is this the separator?
        jz      loop            ; find next arguement

        jmp     noquote         ; keep storing

; now done with splitting argv[]'s
done:
; now let's check for options
        mov     ah,argc
        mov     mc,ah           ; for mc = argc downto 1 do
        mov     si,offset argv - 4
        or      ah,ah           ; do we any argv at all?
        jz      endopt
more:
        add     si,4            ; point to *argv[0,1,2,...]
        mov     bx,[si+2]       ; address of string
        cmp     byte ptr [bx],switch    ; is this string an option?
        jnz     endopt          ; no more options

; process this option (option can be /abc or /a /b /c or /a/b/c)
        mov     cx,[si]         ; length of option string
mopts:
        inc     bx              ; point to char after the switch
        dec     cx              ; decrement length of option string
        jz      nextop          ; done with this option string. Next.

; now scrutinize the option letter
        mov     al,[bx]         ; the option letter
        cmp     al,switch       ; is the switch embedded in here?
        je      mopts           ; ignore it

        cmp     al,'A'          ; check for legal option letters
        jb      badopt
        cmp     al,'Z'
        jbe     goodopt         ; a valid uppercase option letter

        cmp     al,'a'
        jb      badopt
        cmp     al,'z'
        ja      badopt

goodopt:
        mov     dl,al           ; save option letter in case of error
        and     al,31           ; convert to 1-26
        dec     al              ; convert to 0-25
        xor     ah,ah
        mov     di,ax           ; use as an index
        mov     al,dl           ; in case we need this to print error
        cmp     option[di],1    ; check if this is a known option
        je      badopt          ; if not, yell at user
        mov     option[di],2    ; set the option
        jmp     mopts           ; go look at next option char.

badopt:                         ; yell at user for bad option character
        mov     unkopt,al
        mov     dx,offset cry
        mov     ah,9            ; print the error message
        int     21h
        jmp     mopts           ; look at next option char.

nextop:
        dec     mc              ; count down argc
        jnz     more

; now process the parameters
endopt:
        cmp     mc,0            ; see if there's any arguements at all
        ja      nohelp
        mov     dx,offset helpms        ; if not, print a summary
        mov     ah,9            ; print string
        int     21h
        xor     al,al           ; return code 0
        jmp     die

nohelp:                         ; si is pointing to a parameter *argv[]
        mov     di,si
        add     di,4            ; if mc = 2 then di is pointing to the
                                ;  expected response string's argv[]

; now see if we should convert the "expected response" to upper case
        cmp     mc,2            ; is there an "expected response" at all?
        jb      ask             ; if not, then forget about converting
        cmp     option + 'c' - 'a',2    ; should we be case sensitive?
        je      ask             ; if so, then forget about converting

; convert "expected response" to upper case
        mov     cx,[di]         ; length of "expected response"
        mov     bx,[di+2]       ; point to the actual string

convert:
        mov     al,[bx]         ; get a character from "expected response"
        cmp     al,'a'          ; see if it's a lower case letter
        jb      notlow
        cmp     al,'z'
        ja      notlow

; alright, we have a lower case letter here, make it upper and store it back
        sub     al,32
        mov     [bx],al

notlow:
        inc     bx              ; point to next char
        dec     cx              ; decrement length
        jnz     convert         ; until all characters are converted

ask:
        call    prts            ; print first parameter (the prompt)
        mov     ah,1            ; keyboard input function code
        int     21h             ; get a char
        mov     char,al         ; save it

        mov     dx,offset crlf  ; print a carriage return
        mov     ah,9
        int     21h

; now see if the /c option is on or off
        mov     al,char         ; get it back
        cmp     byte ptr [option+'c'-'a'],2
        je      nocase          ; no case translation if on

; translate to upper case
        cmp     al,'a'
        jb      nocase
        cmp     al,'z'
        ja      nocase
        sub     al,32           ; convert lower case to upper case

nocase:
        cmp     mc,2            ; test if expected response is present
        jb      die             ; if not present, just return the ASCII

; now we should try to search the key pressed with expected response
        mov     cx,[di]         ; length of string
        mov     bx,[di+2]       ; start of string
        mov     ah,al           ; mov char into ah
        xor     al,al           ; use this to keep track of the index

search:
        inc     al              ; adjust index
        cmp     [bx],ah         ; match ?
        je      die             ; if so, exit with index as errorlevel
        inc     bx              ; point to next char
        dec     cx              ; more to check?
        jnz     search

; ok, no match, what should we do?
        xor     al,al           ; return this if quiet option is set
        cmp     option + 'q' - 'a',2    ; quiet option set?
        je      die             ; return with errorlevel = 0

        mov     dx,offset nom   ; quiet option not set, so yell at user!
        mov     ah,9
        int     21h
        jmp     ask             ; prompt user again until he gets it right

die:
        mov     ah,4ch          ; terminate; errorlevel in al
        int     21h

start   endp
all     ends
        end     entry
