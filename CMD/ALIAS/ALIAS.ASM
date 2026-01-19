;********************************************************
;*                                                      *
;*               www.wiki.ptsource.eu                   *
;*                                                      *
;********************************************************

        IDEAL
        MODEL   TINY
        SEGMENT CODE

        ORG     0100h
        ASSUME  cs:CODE, ds:CODE, es:CODE

NAVN    EQU     "ALIAS"         ; Navn på programmet
NAVNLEN EQU     5               ; Navnets lengde
VER     EQU     "v1.0"          ; Versjon
DATO    EQU     "2026"          ; Dato for versjon
DSIZE   EQU     1024            ; Antall bytes som settes av til data
INTNR   EQU     21h             ; Interrupt nummer
IDFUNK  EQU     0FFh            ; Funksjonsnummer for å sjekke om installert
                                ;   tidligere


start:  jmp     NEAR settopp    ; Hopp til programstart


;
; Variabler som brukes av interruptrutinen(e)
;
id      DB      NAVN            ; For å sjekke om allerede installert
gmladr  DD      ?               ; Gammel interrupt-adresse
tmplin  DB      257 DUP (0)     ; Midlertidig linje
endret  DB      ?


;
; UPCASE oversetter al til stor bokstav
;
PROC    upcase
        cmp     al, 'a'
        jb      @@ret
        cmp     al, 'z'
        ja      @@ret
        sub     al, 'a' - 'A'
@@ret:  ret
ENDP    upcase


;
; FORBIBLANKE kopierer fra DS:SI til ES:DI helt til første ikke-blanke
; tegn påtreffes. Dette kopieres også, og DI og SI peker til dette i
; hver sin streng når prosedyren returnerer.
; OBS: Virker bare ved kopiering til tmplin, siden DI testes mot denne.
;
PROC    forbi_blanke
        push    ax
        cld
@@l1:   lodsb
        stosb
        cmp     di, OFFSET tmplin + 256
        jae     @@ret
        cmp     al, ' '
        je      @@l1
@@ret:  dec     si
        dec     di
        pop     ax
        ret
ENDP    forbi_blanke


;
; FINN_ALIAS leter gjennom listen av aliaser etter ordet DS:SI peker til
; (avsluttet av en blank). ES:DI settes til å peke til strengen etter ordet
; (eksklusiv den blanke foran). Hvis ikke funnet, peker ES:DI til 0.
; ES må peke til segmentet hvor aliasene ligger
;
PROC    finn_alias
        push    ax
        push    bx
        push    cx

        mov     di, OFFSET data

@@ny_runde:
        cmp     [BYTE es: di], 0
        je      @@ret
        mov     bx, si
@@like_tegn:
        mov     al, [bx]
        inc     bx
        call    upcase
        mov     ah, [es: di]
        inc     di
        cmp     ax, 2020h    ; Begge blanke
        je      @@ret
        cmp     ax, 200Dh    ; Blank og linjeslutt
        je      @@ret
        cmp     ah, al
        je      @@like_tegn
        xor     al, al
        mov     cx, DSIZE
        cld
        repne   scasb
        jmp     @@ny_runde

@@ret:  pop     cx
        pop     bx
        pop     ax
        ret
ENDP    finn_alias


;
; FINN_OG_KOPIER leter gjennom listen av aliaser etter ordet DS:SI peker
; til (avsluttet av en blank). Hvis dette er funnet, kopieres riktig
; alias til tmplin. Hvis ikke, kopieres ordet til tmplin.
; ES:DI må peke til neste posisjon i tmplin.
;
PROC    finn_og_kopier
        push    ax
        push    bx
        push    es
        push    di
        call    finn_alias
        cmp     [BYTE es: di], 0
        je      @@ikke_funnet
        mov     [cs: endret], 1
        pop     ax     ; Gammel DI i AX
        pop     bx     ; Gammel ES i BX
        push    ds
        push    si

        push    es       ; DS:SI til alias
        pop     ds
        mov     si, di

        mov     es, bx   ; ES:DI til tmplin
        mov     di, ax

        cld              ; Kopier alias
@@l1:   lodsb
        stosb
        cmp     di, OFFSET tmplin + 256
        jae     @@ut_av_loekke1
        cmp     al, 0
        jne     @@l1
        dec     di

@@ut_av_loekke1:
        pop     si
        pop     ds

@@l3:   cmp     [BYTE si], ' '   ; Hopp over ordet i orginallinjen
        je      @@ret
        cmp     [BYTE si], 0Dh
        je      @@ret
        inc     si
        jmp     @@l3

@@ikke_funnet:
        pop     di
        pop     es
        cld
@@l2:   lodsb
        stosb
        cmp     di, OFFSET tmplin + 256
        jae     @@ut_av_loekke2
        cmp     al, ' '
        je      @@har_kopiert_fra_linje
        cmp     al, 0Dh
        jne     @@l2
@@har_kopiert_fra_linje:
        dec     di
@@ut_av_loekke2:
        dec     si

@@ret:  pop     bx
        pop     ax
        ret
ENDP    finn_og_kopier


;
; KOPIER_RESTEN kopierer fra DS:SI til ES:DI helt til første 0Dh
; åtreffes. Dette kopieres også, og DI og SI peker til dette i
; hver sin streng når prosedyren returnerer.
;
PROC    kopier_resten
        push    ax
        cld
@@l1:   lodsb
        stosb
        cmp     di, OFFSET tmplin + 256
        jae     @@ut_av_loekke
        cmp     al, 0Dh
        jne     @@l1
        dec     di
@@ut_av_loekke:
        dec     si
        pop     ax
        ret
ENDP    kopier_resten


;
; NYINT er den nye interruptrutinen.
; Det er viktig at alle registere spares!
;
PROC    nyint   FAR
        sti
        cmp     ah, IDFUNK      ; Kan dette være spørsmål om Identifikajsjon?
        jne     @@ikke_id       ; Hopp over rutine som sjekker dette.

        push    cx      ; Sjekker om det er spørsmål om rutinen er installert
        push    si      ;    tidligere
        push    di
        push    es
        mov     cx, cs
        mov     es, cx
        mov     di, OFFSET id
        mov     cx, NAVNLEN
        cld
        repe    cmpsb
        je      @@like
        pop     es              ; Ikke like, pop av alle,
        pop     di              ;
        pop     si              ;
        pop     cx              ;
        jmp     SHORT @@ikke_id ; og returner til vanlig gjennomføring.
@@like: pop     cx              ; es skal ikke poppes, cx brukes som dummy
        pop     di
        pop     si
        pop     cx
        mov     di, OFFSET id   ; es:di skal peke til NAVN
        iret

@@ikke_id:
        cmp     ah, 0Ah         ; Skriv inn linje?
        je      @@les_linje
@@jmp_gml:
        jmp     [DWORD FAR cs: gmladr]   ; Hopp til gammel rutine

@@les_linje:
        pushf
        call    [DWORD FAR cs: gmladr]

        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    es
        push    ds

@@sjekk_en_gang_til:
        push    cs
        pop     es
        mov     di, OFFSET tmplin   ; ES:DI peker til midlertidig Lstring
        mov     si, dx              ; DS:SI peker til orginal Lstring

        cld
        movsw                       ; ES:DI og DS:SI peker nå til første tegn.

        call    forbi_blanke
        cmp     [BYTE si], 0Dh      ; Er strengen tom?
        je      @@ret

        mov     [BYTE cs: endret], 0
        call    finn_og_kopier

        call    kopier_resten

        mov     di, OFFSET tmplin + 2  ; Skal sette Max og Ant i tmplin
        mov     cl, [es: tmplin]       ; til riktige verdier, og må derfor
        xor     ch, ch                 ; søke etter 0Dh.
        mov     al, 0Dh                ; CX=Max
        cld
        repne   scasb
        je      @@funnet
        mov     al, [es: tmplin]
        dec     al
        xor     ah, ah
        mov     di, ax   ; Max
        mov     [es: tmplin + 1], al
        add     di, OFFSET tmplin + 2
        mov     [BYTE es: di], 0Dh
        jmp     SHORT @@kopier_tilbake
@@funnet:
        sub     di, OFFSET tmplin + 3
        mov     ax, di
        mov     [es: tmplin + 1], al
@@kopier_tilbake:
        push    ds
        mov     ax, ds
        push    es
        pop     ds
        mov     es, ax
        mov     si, OFFSET tmplin
        mov     di, dx
        mov     cl, [si]
        xor     ch, ch
        add     cx, 2
        cld
        rep     movsb
        pop     ds

        cmp     [BYTE cs: endret], 0
        jne     @@sjekk_en_gang_til

@@ret:  pop     ds
        pop     es
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        iret
ENDP    nyint





;
; Her følger selve installasjonsrutinen. Den blir ikke resident.
;

LABEL   data    BYTE
LABEL   ikkeres BYTE
        DB      256 DUP(0)   ; Plass til første linje
;
; Variabler som brukes av installasjonsprogrammet
;
avslax  DW      4C00h ; Funksjonskall for avslutning.
avsldx  DW      0     ; dx' verdi ved avslutning
intseg  DW      ?

idtxt   DB      13, NAVN, " ", VER, ".", 13, 10, "$"
bruktxt DB      "Usage: ", NAVN, " { ? | ALIAS [command]] }", 13, 10
        DB      "       ALIAS   A new alias name.", 13, 10
        DB      "       command The command to make an alias of. If no command", 13, 10
        DB      "       is given, an existing alias is removed.", 13, 10, 10
        DB      "       No parameters will list all available aliases.", 13, 10, 10
        DB      "Notes: * Only the first word of a command line is checked for aliases.", 13, 10
        DB      "       * Works only when the input lines are read using INT 21h, func 0Ah.", 13, 10, "$"
altxt   DB      13, "List of aliases currently available:", 13, 10, "$"
tomtxt  DB      13, "No aliases found.", 13, 10, "$"
ikkepls DB      13, "Not enough room for aliases.", 13, 10, "$"
ulovtxt DB      13, "Illegal alias name. Use letters only.", 13, 10, "$"


;
; PRINT viser $-strengen som DS:DX peker til
;
PROC    print
        push    ax
        mov     ah, 9
        int     21h
        pop     ax
        ret
ENDP    print


;
; TOLKPARAMETRE går igjennom kommandolinjen og setter opp etter
; angitte parametre.
; ES må peke til segmentet med aliaser!
;
PROC    tolkparametre
        push    ax
        push    bx
        push    cx
        push    dx
        push    es
        push    ds
        push    si
        push    di
        mov     bx, 80h
@@j1:   inc     bx
        cmp     [BYTE bx], ' '
        je      @@j1
        cmp     [BYTE bx], '?'
        je      @@vis_bruk_og_id
        cmp     [BYTE bx], 13
        jne     @@ny_alias
        cmp     [BYTE avslax + 1], 4Ch   ; Er programmet installert før?
        jne     @@vis_bruk
        jmp     SHORT @@vis_aliaser
@@vis_bruk_og_id:
        mov     dx, OFFSET idtxt        ; Vis identifikasjonslinje
        call    print
@@vis_bruk:
        mov     dx, OFFSET bruktxt
        call    print
        jmp     SHORT @@ret
@@vis_aliaser:
        mov     di, OFFSET data
        cmp     [BYTE es: di], 0
        je      @@ingen_aliaser
        mov     dx, OFFSET altxt
        jmp     SHORT @@vm1
@@ingen_aliaser:
        mov     dx, OFFSET tomtxt
@@vm1:  call    print
@@vm2:  cmp     [BYTE es: di], 0
        je      @@ret
        mov     dl, ' '
        mov     ah, 2       ; Skriv en blank
        int     21h
@@vm3:  mov     dl, [es: di]
        inc     di
        cmp     dl, 0
        je      @@neste
        mov     ah, 2
        int     21h
        jmp     @@vm3
@@neste:mov     dl, 13      ; Linjeskift
        mov     ah, 2
        int     21h
        mov     dl, 10
        mov     ah, 2
        int     21h
        jmp     @@vm2
@@ret:  pop     di
        pop     si
        pop     ds
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
@@ny_alias:
        mov     si, bx      ; DS:SI peker til første bokstav.
        ; Først, gjør om aliasnavnet til store bokstaver, og sjekk om
        ; lovlige tegn (bare bokstaver).
        cld
@@na1:  lodsb
        cmp     al, ' '
        je      @@navn_ok
        cmp     al, 0Dh
        je      @@navn_ok
        call    upcase
        mov     [si - 1], al
        cmp     al, 'A'
        jb      @@ulovlig_navn
        cmp     al, 'Z'
        jbe     @@na1
@@ulovlig_navn:
        mov     dx, OFFSET ulovtxt
        call    print
        jmp     @@ret
@@navn_ok:
        mov     dx, si
        dec     dx
        sub     dx, bx  ; DX inneholder nå aliasnavnets lengde.
        ; Så sjekkes det om aliasen finnes. Isåfall fjernes den.
        mov     si, bx
        call    finn_alias
        cmp     [BYTE es: di], 0
        je      @@finnes_ikke
        push    ds
        push    es
        push    si
        push    di
        mov     si, di
        dec     si
        sub     si, dx     ; SI - midlertidig peker til aliasstart
        mov     cx, DSIZE
        xor     al, al
        cld
        repne   scasb
        xchg    si, di
        push    es
        pop     ds
        mov     cx, OFFSET data + DSIZE
        sub     cx, si
        cld
        rep     movsb
        pop     di
        pop     si
        pop     es
        pop     ds
@@finnes_ikke:
        ; Deretter sjekkes det om det er ledig plass.
        mov     di, OFFSET data
        xor     al, al
        cmp     [es: di], al
        je      @@helt_tomt
        mov     cx, DSIZE
        cld
@@na2:  repne   scasb
        cmp     [BYTE es: di], 0
        jne     @@na2
@@helt_tomt:
        ; Nå peker ES:DI til stedet den nye skal legges inn.
        mov     cx, OFFSET data + DSIZE - 2
        sub     cx, di                         ; CX - ledig plass
        mov     al, [cs: 80h]     ; Parameterlengde i PSP
        xor     ah, ah
        cmp     ax, cx
        jae     @@ikke_plass
        ; Aliasen legges til hvis det står noe etter navnet.
        mov     si, bx
        mov     cx, dx   ; Navnlengde
        mov     dx, di   ; For å spare di
        cld
        rep     movsb
        mov     al, ' '
        stosb
@@na3:  lodsb                    
        cmp     al, ' '
        je      @@na3
        cmp     al, 0Dh  ; Er ingen kommando angitt etter aliasen?
        jne     @@na4
        mov     di, dx
        xor     al, al
        cld
        stosb            ; Merk som siste igjen.
        jmp     @@ret
@@na4:  stosb
        lodsb
        cmp     al, 0Dh
        jne     @@na4
@@legg_til_null:
        xor     al, al
        stosb
        stosb
        jmp     @@ret
@@ikke_plass:
        mov     dx, OFFSET ikkepls
        call    print
        jmp     @@ret
ENDP    tolkparametre


settopp:
        mov     ah, 35h                 ; Les gammel interrupt-adresse
        mov     al, INTNR               ;
        int     21h                     ;
        mov     [WORD gmladr], bx       ; Lagre denne
        mov     [WORD gmladr + 2], es   ;

        mov     si, OFFSET id           ; Sjekk om installert før
        xor     ax, ax                  ;
        mov     es, ax                  ; Null ut es
        mov     ah, IDFUNK              ;   funksjon for sjekk
        int     INTNR                   ;
        mov     si, OFFSET id           ; Sammenlikne strengene
        mov     cx, NAVNLEN             ;
        cld                             ;
        repe    cmpsb                   ;

        jne     @@j1                    ; Hvis ikke lik, installér
        mov     [intseg], es
        jmp     SHORT @@j2

@@j1:   mov     ah, 25h                 ; Sett ny interruptadresse
        mov     al, INTNR
        mov     dx, OFFSET nyint
        int     21h
        mov     dx, OFFSET ikkeres      ; Finn antall paragrafer
        add     dx, DSIZE               ;
        mov     cl, 4                   ;
        shr     dx, cl                  ;
        inc     dx                      ;
        mov     [avsldx], dx
        mov     [avslax], 3100h
        mov     [intseg], cs
        push    cs
        pop     es
        ;mov     dx, OFFSET idtxt        ; Vis identifikasjonslinje
        ;call    print

@@j2:   call    tolkparametre
        mov     dx, [avsldx]         ; Utfør avslutning
        mov     ax, [avslax]
        int     21h


        ENDS
        END     start
