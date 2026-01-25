#include <stdio.h>
#include "compress.h" /* contains the rest of the include file declarations */
#ifdef NO_STRCHR
char *strchr(s, c)
char *s;
int c;
{
    while ( *s) {
        if (*s == (char)c)
            return(s);
        else
            s++;
    }
    return(NULL);
}
#endif
#ifdef NO_REVSEARCH
char *strrpbrk(str1,str2)
char *str1;   /*string to be searched */
char *str2;   /*chars to search for */
{
    register char *p;
    register int count = 0;
    while (*str1) {
        str1++;
        count++;
    }
    str1--;
    while (count--) {
        p = str2;
        do {
            if (*str1 == *p)
                return(str1);
        } while (*p++);
        str1--;
    }
    return (NULL);
}
#endif
char *get_program_name(ptr)
char *ptr;
{
    char *cp,*temp;
    if ((cp = strchr(ptr,' '))!= NULL)    /* to allow for os/2 argv[0] */
        *cp = '\0';
    cp = name_index(ptr);
    if ((temp = strchr(cp,'.')) != NULL)
        *temp = '\0';
    setbinary(stdin);        /* MSDOS & compiler dependent, mode defaults*/
    setbinary(stdout);       /* to text stdin/out--see compress.h*/
    for (temp = cp; *temp; temp++)
        *temp = tolower(*temp);
    if(strncmp(cp,"uncomp",6) == 0) {
        do_decomp = 1;
    } else if(strncmp(cp, "zcat",4) == 0) {
        keep = TRUE;
        zcat_flg = do_decomp = 1;
    }
    return (cp);
}
char *name_index(ptr)
char *ptr;
{
    char *p;
    p = strrpbrk(ptr,"\\/:");
    return ((p)?++p:ptr);
}
int is_z_name(ptr)       /* checks if it is already a z name */
char *ptr;
{
    int len = (int)strlen(ptr) -1;
    return ((ptr[len] == 'z' || ptr[len] == 'Z'));
}
int make_z_name(ptr)
char *ptr;
{
    char *ep,*temp;
    temp = name_index(ptr);           /* get right most delimiter */
    if ( (ep = strchr(temp,'.'))!=NULL ) {   /* has an extension */
        if (strlen(ep) > 3) {
            endchar[0] = ep[3];
            ep[3] = 'Z';
        } else
            strcat(ep,"Z");
    } else
        strcat(ptr,".Z");
    return TRUE;
}
void unmake_z_name(ptr)
char *ptr;
{
    register int len = (int)strlen(ptr)-1;
    if ((ptr[len] == 'Z' || ptr[len] == 'z') && *endchar)
        ptr[len] = endchar[0];
    else
        ptr[len] = '\0';
}
#ifndef NOSIGNAL
#ifdef ISOS2
SIGTYPE onintr ( ) {
    signal(SIGINT,SIG_IGN);  /* lets make sure no other interupts happen */
    if (!zcat_flg && !keep_error) {
        fclose(stdout);
        unlink ( ofname );
    }
    exit ( ERROR );
}
SIGTYPE oops ( ) {  /* wild pointer -- assume bad input */
    signal(SIGINT,SIG_IGN);
    if ( do_decomp == 1 )
        fprintf ( stderr, "%s: corrupt input: %s\n",prog_name,ifname);
    if (!zcat_flg && !keep_error) {
        fclose(stdout);
        unlink ( ofname );
    }
    exit ( ERROR );
}
#else        /* for non bound applications */
SIGTYPE onintr ( ) {
    if (!zcat_flg && !keep_error) {
        fclose(stdout);
        unlink ( ofname );
    }
    exit ( ERROR );
}
SIGTYPE oops ( ) {  /* wild pointer -- assume bad input */
    if ( do_decomp == 1 )
        fprintf ( stderr, "%s: corrupt input: %s\n",prog_name,ifname);
    if (!zcat_flg && !keep_error) {
        fclose(stdout);
        unlink ( ofname );
    }
    exit ( ERROR );
}
#endif
#endif
#ifdef MWC
struct utimbuf {
    time_t a,b;
};
#endif
#ifdef __TURBOC__
struct ftime utimbuf;
#endif
#ifdef SOZOBON
#ifndef S_IFREG
#define S_IFREG         (S_IREAD | S_IWRITE)
#endif
#endif
int test_file(ifname)  /* test for a good file name and no links */
char *ifname;          /* returns 0 for good file ERROR for bad  */
{
    struct stat statbuf;
    if (stat(ifname, &statbuf)) {       /* Get stat on input file */
        perror(ifname);
        return(ERROR);
    } else if ((statbuf.st_mode & S_IFMT/*0170000*/) != S_IFREG/*0100000*/) {
        fprintf(stderr, "%s -- not a regular file: unchanged",ifname);
        return(ERROR);
    }
#ifndef USE_LINKS
    else if (statbuf.st_nlink > 1) {
        fprintf(stderr, "%s -- has %d other links: unchanged",ifname,
                statbuf.st_nlink - 1);
        return(ERROR);
    }
#endif
    return (0);
}
void copystat(ifname, ofname)
char *ifname, *ofname;
{
    struct stat statbuf;
    int mode;
#ifndef __TURBOC__
    time_t timep[2];
#endif
    fclose(stdout);
    if (stat(ifname, &statbuf)) {       /* Get stat on input file */
        perror(ifname);
        return;
    }
    if (exit_stat == NOSAVING && (!force)) { /* No compression: remove file.Z */
        if(!quiet)
            fprintf(stderr, " -- no savings -- file unchanged");
    } else if (exit_stat == NOMEM) {
        if (!quiet)
            fprintf(stderr, " -- file unchanged");
        if (!do_decomp)
            exit(ERROR);
        else
            return;   /* otherwise will unlink outfile */
    } else if (exit_stat == OK) {  /* ***** Successful Compression ***** */
        mode = statbuf.st_mode & 07777;
        if (chmod(ofname, mode))        /* Copy modes */
            perror(ofname);
#ifdef __TURBOC__      /* does not have utime */
        getftime(fileno(stdin),&utimbuf);
        freopen(ofname,READ_FILE_TYPE,stdout);
        setftime(fileno(stdout),&utimbuf);
        fclose(stdout);
#else
#ifdef SOZOBON
        utime(ofname, &(statbuf.st_mtime));
#endif
        timep[0] = statbuf.st_atime;
        timep[1] = statbuf.st_mtime;
        utime(ofname, (struct utimbuf *)timep);   /* Update last accessed and modified times */
#endif
        if (!keep) {
            fclose(stdin);
            if (unlink(ifname)) /* Remove input file */
                perror(ifname);
            if(!quiet)
                fprintf(stderr, " -- replaced with %s", ofname);
        } else {
            if(!quiet)
                fprintf(stderr, " -- compressed to %s", ofname);
        }
        return;     /* Successful return */
    }
    fclose(stdout);
    if (unlink(ofname))
        perror(ofname);
}
#ifndef COMPVER
#ifdef MSDOS
#define COMPVER "DOS"
#else
#define COMPVER "Generic"
#endif
#endif
#ifdef COMP40
#define RESET "Adaptive Reset"
#else
#define RESET "No Adaptive Reset"
#endif
void version() {
#ifdef DEBUG
    fprintf(stderr, "%s\nOptions: %s %s DEBUG MAXBITS = %d\n",rcs_ident,COMPVER,
            RESET,MAXBITS);
#else
    fprintf(stderr, "%s\nOptions: %s %s MAXBITS = %d\n",rcs_ident,COMPVER,
            RESET,MAXBITS);
#endif
}
ALLOCTYPE FAR *emalloc(x,y)
unsigned int x;
int y;
{
    ALLOCTYPE FAR *p;
    p = (ALLOCTYPE FAR *)ALLOCATE(x,y);
    return(p);
}
void efree(ptr)
ALLOCTYPE FAR *ptr;
{
    FREEIT(ptr);
}
