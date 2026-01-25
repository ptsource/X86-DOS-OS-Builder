/********************************************************/
/*                                                      */
/*               www.wiki.ptsource.eu                   */
/*                                                      */
/********************************************************/
#include <stdio.h>
#include <stdlib.h>

main()
{
    unsigned envseg, envsize, envinuse;
    int count;
    char far *ptr;

    getsysenv(&envseg, &envsize, &envinuse);
    ptr = (char far *) ((long) envseg << 16);
    for (count=0; count<envinuse; count++)
        {
        if(*(ptr + count) == '\0')
            putchar('\n');
        else
            putchar(*(ptr + count));
        }
    printf("\n");
    return(0);
}

getsysenv(envseg, envsize, envinuse)
unsigned *envseg, *envsize, *envinuse;
{
    unsigned getdospsp(), computeenvinuse(), dospsp, temp;
    unsigned far *ptr;

    dospsp = getdospsp();
    ptr = (unsigned far *) (((long) dospsp << 16) | 0x2c);
    temp = *ptr;
    if((temp != 0) && (_osmajor != 3 || _osminor <= 19 || _osminor >= 30))
        {
        *envseg = temp;
        }
    else
        {
        ptr = (unsigned far *) (((long) (dospsp-1) << 16) | 3);
        *envseg = dospsp + (*ptr) + 1;
        }
    ptr = (unsigned far *) (((long) ((*envseg)-1) << 16) | 3);
    *envsize = 16*(*ptr);
    *envinuse = computeenvinuse(*envsize, *envseg);
    return(0);
}

unsigned getdospsp()
{
    unsigned temp, temp1;
    unsigned far *ptr;

    ptr = (unsigned far *) (((long) _psp << 16) | 0x16);
    temp = *ptr;	
    while(1)
        {
        ptr = (unsigned far *) (((long) temp << 16) | 0x16);
        temp1 = *ptr;
        if((!temp1) || (temp1 == temp))
            return(temp);
        else
            temp = temp1;
        }
}

unsigned computeenvinuse(envsize, envseg)
unsigned envsize, envseg;
{
    unsigned j;
    unsigned far *ptr;

    for(j=0; j<=(envsize-3); j++)
        {
        ptr = (unsigned far *) (((long) envseg << 16) | j);
        if(*ptr == 0)
            {
            return(j+2);
            }
        }
    return(envsize);
}
