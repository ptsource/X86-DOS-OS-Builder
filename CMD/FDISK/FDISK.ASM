.model small
.stack
.data
    message   db "FDISK is not avaliable. Use PTSource PART for disk and boot management.",13,10
              db "You can find it at www.wiki.ptsource.eu.", "$"
.code
    main    proc
        mov   ax,seg message
        mov   ds,ax
        mov   ah,09
        lea   dx,message
        int   21h

        mov   ax,4c00h
        int   21h
    main    endp
end main