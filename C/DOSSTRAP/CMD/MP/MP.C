/********************************************************/
/*                                                      */
/*               www.wiki.ptsource.eu                   */
/*                                                      */
/********************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dos.h>
#define MAXSTRS 100		/* increase this if you have more env strings */
#define MAXPATH 500		/* max size of path string */
#define PATHSEP ";"		/* separates node names in path */
void main(int argc, char *argv[]) {
    int i, num, envsize, len, nstrs=0, nextra, pathindex;
    char dowhat, varstg[MAXPATH], tmpstr[MAXPATH],
         *strptr[MAXSTRS], far *envp, far *envptr, *subloc;
    unsigned far *p_psp, far *p_env;
    struct {
        char link;
        unsigned int owner_psp;
        unsigned int blk_len;
    } far *envmcb;
    if (argc < 2) {
        fprintf(stderr, "Usage: MP [ -{p|a} newnodename | -r oldnodename newnodename]*\n");
        exit(1);
    }
    p_psp = MK_FP(_psp,0x16);    /*pointer to parent's PSP*/
    p_env = MK_FP(*p_psp,0x2c);  /*pointer to parent's environment ptr*/
    envptr = MK_FP(*p_env,0x00); /*pointer to parent's environment */
    envmcb = MK_FP(*p_env-1,0x00); /* pointer to parent env MCB */
    envsize = (*envmcb).blk_len<<4;
    envp = envptr;
    while (*envp) {      /* env strings terminated by second null */
        int len;
        char far *fp;
        char *lp;
        for (len=0, fp=envp; *fp; fp++) len++;
        lp = strptr[nstrs++] = malloc(len+1);
        for ( ; (*lp++=*envp++); );
    }
    for (pathindex=0; pathindex<nstrs; pathindex++) if (strnicmp(strptr[pathindex],"PATH=",5) ==0 ) break;
    if (pathindex>=nstrs) {
        fprintf(stderr, "MP: Can't find path var!\n");
        exit(1);
    }
    strcpy(varstg,strptr[pathindex]);
    while (--argc > 0 ) {
        if ( ( (dowhat=(*++argv)[0])) != '-') {
            fprintf(stderr, "MP: begin switches with '-', as in '-%c'\n", dowhat);
            exit(1);
        }
        dowhat = tolower(*++argv[0]);
        if (dowhat!='p' && dowhat!='a' && dowhat!='r') {
            fprintf(stderr, "MP: invalid switch -%c\n", dowhat);
            exit(1);
        };
        if (--argc <=0) {
            fprintf(stderr, "MP: switch -%c missing node name\n", dowhat);
            exit(1);
        }
        switch (dowhat) {
            case 'a':
                strcat(varstg,PATHSEP);
                strcat(varstg,*++argv);
                break;
            case 'p':
                strcpy(tmpstr,"PATH=");
                strcat(tmpstr,*++argv);
                strcat(tmpstr,PATHSEP);
                strcat(tmpstr,strpbrk(varstg,"=")+1);
                strcpy(varstg,tmpstr);
                break;
            case 'r':
                if ( (subloc=strstr(varstg,*++argv)) == NULL) {
                    fprintf(stderr,"MP: pathnode %s not found in current path", *argv);
                    fprintf(stderr," (case-sensitive!)\n");
                    fprintf(stderr,"    replacement ignored");
                    while ( *(argv+1)[0] != '-') {
                        ++argv;
                        argc--;
                    }
                    break;
                };
                strcpy(tmpstr,subloc+strlen(*argv));
                if (*(argv+1)[0] != '-') {
                    strcpy(subloc,*++argv);
                    --argc;
                } else subloc = '\0';
                strcat(varstg,tmpstr);
                break;
        };
    }
    strptr[pathindex] = &varstg;
    for (i=0, len=0; i<nstrs; i++) len += strlen(strptr[i]) + 1;
    if (len+1>envsize)  {
        fprintf(stderr,"MP: Env block too small to store updated PATH string\n");
        exit(1);
    } else {
        for (i=0; i<nstrs; i++) {
            for ( ; (*envptr++ = *strptr[i]++) ; ) ;
            *envptr = '\0';
        }
    }
}
