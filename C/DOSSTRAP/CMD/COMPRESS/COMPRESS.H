#define TITLE "DOSSTRAP COMPRESS. Visit us at www.wiki.ptsource.eu."
#ifndef FALSE            /* let's get some sense to this */
#define FALSE 0
#define TRUE !FALSE
#endif
#ifndef DEBUG           /* some convoluted defines to make the source */
#ifndef NDEBUG          /* on command line use -DNDEBUG to make a     */
#define DEBUG 		/* program without the debugging routines     */
#endif
#endif
#ifdef TOLZ
#define FILTER FALSE
#define KEEPFLAG TRUE
#endif
#ifdef UNIX
#define NPROTO
#define COMP40           /* take this out for a little more speed */
#ifdef ALLOC
char *alloc();
#define ALLOCATE(x,y)   alloc((unsigned int)x*y)
#else
char *malloc();
#define ALLOCATE(x,y)   malloc((unsigned int)x*y)
#endif
#define FREEIT(ptr)     free(ptr)
#define setbinary(fp)
#define NO_SETVBUF      /* most don't support setvbuf() function */
#endif
#ifdef ISC386           /* my unix version compiler and system DjG */
#define NPROTO          /* the unix release 3.2 dose not support prototypes */
#include <malloc.h>     /* compiler has it, so put it in for future */
#define ALLOCATE(x,y)   malloc((unsigned int)x*y)
#define FREEIT(ptr)     free(ptr)
#define setbinary(fp)
#include <limits.h>
#define _MAX_PATH  PATH_MAX
#define _MAX_NAME  NAME_MAX
#define _MAX_DIR   (PATH_MAX + NAME_MAX)
#define UNIX      /* the rest of the unix stuff is still good */
#define COMPVER "386/ix"
#endif
#ifdef MSC
#define COMPVER "DOS"
#define FAR far
#define MAXSEG_64K
#define NO_REVSEARCH
#define CONST const
#define ALLOCTYPE void
#ifdef M_I86SM
#define SMALLMODEL        /* compiled in small model */
#endif
#define setbinary(fp)    setmode(fileno((fp)), O_BINARY)
#endif
#ifdef MINIX        /* Unix V7 clone for Atari ST */
#define COMPVER "minix"
#define strchr  index
#define strrchr rindex
#define DFLTBITS 13 /* compatible with original MINIX compress, max=16 */
#ifndef KEEPFLAG
#define KEEPFLAG 1  /* compatible with original MINIX compress */
#endif             /* may be redefined from the Makefile if desired */
#ifndef VERBOSE
#define VERBOSE TRUE    /* compatible with original MINIX compress */
#endif            /* may be redefined from the Makefile if desired */
#define NPROTO
#define SIGTYPE int /* MINIX defines this as pointer to int */
#endif      /* end of MINIX changes */
#ifdef MWC
#define COMPVER "TOS(mwc)"
#define MSDOS
#define NOSIGNAL
#define DFLTBITS 14
#define NPROTO
#define NO_SETVBUF
#define NO_REVSEARCH
#define ALLOCATE(x,y)   lcalloc((unsigned long)(x),((unsigned long)(unsigned)(y)))
#define FREEIT(ptr)     free(ptr)
#define setbinary(fp)    ((fp)->_ff &= ~_FASCII)
#endif
#ifdef ALCYON
#define SOZOBON 1
#endif
#ifdef SOZOBON
#define COMPVER "TOS(sozobon)"
#define MSDOS
#define NOSIGNAL
#define DFLTBITS 14
#define NPROTO
#define ALLOCATE(x,y)   lalloc((unsigned long)(x) * ((unsigned long)(y)))
#define FREEIT(ptr)     free(ptr)
#define setbinary(fp)    ((fp)->_flag |= _IOBIN)
#define FILTER  FALSE
#endif
#ifdef __ZTC__                 /* Zortech compiler           */
#define setbinary(fp)    ((fp)->_flag&=~_IOTRAN)
#define NO_REVSEARCH
#define CONST const
#define MAXSEG_64K
#endif
#ifdef XENIX
#define setbinary(fp)
#define FAR far
#define CONST
#define SIGTYPE int           /* xenix defines this as pointer to int */
#ifdef M_I286
#define MAXSEG_64K
#endif
#define NO_SETVBUF            /* evidently xenix chokes on the large buff*/
#endif                        /* really needs to be fine tuned           */
#ifdef MCH_AMIGA
#define COMPVER "Amiga"
#define CONST
#define MAXSEG_64K             /* Manx C compiler limitation */
#define NO_SETVBUF
#endif
#ifdef vms
#define NO_SETVBUF
#endif
#ifdef __TURBOC__
#define MSDOS
#define MAXSEG_64K
#define NO_REVSEARCH
#ifdef __SMALL__
#define SMALLMODEL
#endif
#define CONST const
#define FAR             far
#define setbinary(fp)   setmode(fileno((fp)), O_BINARY)
#endif
#ifndef FILTER
#define FILTER  FALSE
#endif
#ifndef KEEPFLAG
#ifdef DEBUG
#define KEEPFLAG TRUE
#else
#define KEEPFLAG FALSE
#endif
#endif
#include <ctype.h>
#ifdef MINIX
#define assert(x)
extern char *index(), *rindex(), *strcat(), *strcpy(), *strncat(), *strncpy();
#else
#include <assert.h>
#include <string.h>
#endif
#ifndef NOSIGNAL
#include <signal.h>
#endif
#ifdef MWC
#include <stdlib.h>
#include <types.h>
#include <stat.h>
#else
#ifdef SOZOBON
#include <stdio.h>
#include <stat.h>
#include <limits.h>
#include <malloc.h>
#include <errno.h>
#else
#include <sys/types.h>
#include <sys/stat.h>
#endif
#endif
#ifdef M_XENIX
#include <fcntl.h>
#endif
#ifdef MSC
#include <stdlib.h>
#include <io.h>
#include <sys/utime.h>
#include <fcntl.h>
#include <limits.h>
#endif
#ifdef __TURBOC__
#include <stdlib.h>
#include <io.h>
#include <fcntl.h>
#include <limits.h>
#endif
#ifndef NOSIGNAL
#ifndef SIGTYPE
#define SIGTYPE void
#endif
#ifndef SIG_ERR
#define SIG_ERR (SIGTYPE(*)())-1
#endif
#endif
#ifdef INCL_DOSPROCESS
#define ISOS2 TRUE
#endif
#ifdef BIND
#define ISOS2 TRUE
#endif
#ifndef _MAX_PATH
#define _MAX_PATH  144      /* max. length of full pathname       */
#define _MAX_DRIVE   3      /* max. length of drive component     */
#define _MAX_DIR   130      /* max. length of path component      */
#define _MAX_FNAME   9      /* max. length of file name component */
#define _MAX_EXT     5      /* max. length of extension component */
#endif
#ifndef FAR
#define FAR
#endif
#ifndef ALLOCTYPE
#define ALLOCTYPE char
#endif
#ifndef CONST
#define CONST
#endif
typedef unsigned short CODE;
typedef unsigned char UCHAR;
typedef unsigned int  INTCODE;
typedef unsigned int HASH;
typedef int FLAG;
#define INITBITS    9
#define MINBITS     12
#define MAXMAXBITS  16
#ifndef MAXBITS
#define MAXBITS    MAXMAXBITS
#endif
#if (MAXBITS > MAXMAXBITS)
#undef MAXBITS
#define MAXBITS    MAXMAXBITS
#endif
#if (MAXBITS < MINBITS)
#undef MAXBITS
#define MAXBITS  MINBITS
#endif
#ifndef DFLTBITS
#define DFLTBITS MAXBITS
#endif
#if (DFLTBITS < MINBITS)
#undef DFLTBITS
#define DFLTBITS MINBITS
#endif
#if (DFLTBITS > MAXBITS)
#undef DFLTBITS
#define DFLTBITS MAXBITS
#endif
#if (MAXBITS < 14)
#ifdef SMALLMODEL
#define NEARHEAP TRUE
#undef FAR
#define FAR
#endif
#endif
#define NULLPTR(type)   ((type FAR *) NULL)
#ifdef MSC
#include <malloc.h>
#ifdef NEARHEAP
#define ALLOCATE(x,y)   malloc((size_t)((x)*(y)))
#define FREEIT(ptr)     free((ptr))
#else
#define ALLOCATE(x,y)   _fmalloc((size_t)((x)*(y)))
#define FREEIT(ptr)     _ffree((ptr))
#endif
#endif
#ifdef HUGE
#include <malloc.h>
#define ALLOCATE(x,y)   halloc((long)(x),(size_t)(y))
#define FREEIT(ptr)     hfree(ptr)
#endif
#ifdef __TURBOC__
#include <alloc.h>
#ifdef NEARHEAP
#define ALLOCATE(x,y)  malloc((unsigned int)((x)*(y)))
#define FREEIT(x)      free(x)
#else
#define ALLOCATE(x,y)  farmalloc((unsigned long)((x)*(y)))
#define FREEIT(x)    farfree(x)
#endif
#endif
#ifndef ALLOCATE
#include <malloc.h>
#define ALLOCATE(x,y)   malloc((unsigned int)x*y)
#define FREEIT(ptr)     free((ptr))
#endif
# ifdef MAXSEG_64K
#   if  MAXBITS > 14
#       define SPLIT_HT   TRUE
#   else
#       define SPLIT_HT   0
#   endif
# else
#   define SPLIT_HT   0
# endif
# ifdef MAXSEG_64K
#   if  MAXBITS > 15
#       define SPLIT_PFX   TRUE
#   else
#       define SPLIT_PFX   0
#   endif
# else
#   define SPLIT_PFX   0
# endif
#ifndef BUFSIZ
#define BUFSIZ 512
#endif
#ifdef NO_SETBUF
#define NO_SETVBUF
#endif
#ifdef NO_SETVBUF
#   ifndef NO_SETBUF
#       define setvbuf(fp,buf,mode,size) setbuf((fp),(buf))
#       define ZBUFSIZE BUFSIZ
#       define XBUFSIZE BUFSIZ
#   else
#       define setvbuf(fp,buf,mode,size)
#       define ZBUFSIZE (1)
#       define XBUFSIZE (1)
#   endif
#else
#   ifdef NEARHEAP
#       define XBUFSIZE    (0xC00)
#       define ZBUFSIZE    (0x1800)
#   else
#       define XBUFSIZE    (0x3000)      /* 12k bytes */
#       define ZBUFSIZE    (0x6000)      /* 24k bytes */
#   endif
#endif
#define UNUSED      ((CODE)0)   /* Indicates hash table value unused    */
#define CLEAR       ((CODE)256) /* Code requesting table to be cleared  */
#define FIRSTFREE   ((CODE)257) /* First free code for token encoding */
#define MAXTOKLEN   512         /* Max chars in token; size of buffer   */
#define OK          0           /* Result codes from functions:         */
#ifdef vms
#define ERROR       0x10000004  /* General unspecified error            */
#define NORMAL      1           /* No error                             */
#define unlink(x)   remove(x)
#else
#    define NORMAL      0
#    ifdef ERROR
#        if (ERROR == NORMAL)
#            define ERROR   1   /* force redefine if (ERROR == NORMAL)  */
#        endif
#    else
#        define ERROR       1
#    endif
#endif
#define SIGNAL_ERROR -1         /*   signal function error              */
#define NOMEM       2           /*   Ran out of memory                  */
#define TOKTOOBIG   3           /*   Token longer than MAXTOKLEN chars  */
#define READERR     4           /*   I/O error on input                 */
#define WRITEERR    5           /*   I/O error on output                */
#define INFILEBAD   6           /*   Infile not in compressed format    */
#define CODEBAD     7           /*   Infile contained a bad token code  */
#define TABLEBAD    8           /*   The tables got corrupted (!)       */
#define NOSAVING    9           /*   no saving in file size             */
#define NOTOPENED  10           /*   output file couldn't be opened     */
#define YES         1
#define NO          0
#include "compress.fns"
#ifdef MSDOS
#define WRITE_FILE_TYPE "wb"
#define READ_FILE_TYPE "rb"
#define SUFFIX "Z"
#else
#ifdef vms
#define SUFFIX "_Z"
#define WRITE_FILE_TYPE "wb"
#define READ_FILE_TYPE "rb"
#else
#define WRITE_FILE_TYPE "w"
#define READ_FILE_TYPE "r"
#define SUFFIX ".Z"
#endif
#endif
#ifndef VERBOSE
#define VERBOSE FALSE
#endif
#define BIT_MASK    0x1f
#define BLOCK_MASK  0x80
#define CHECK_GAP 10000L     /* ratio check interval */
#ifdef MAIN
UCHAR magic_header[] = { 0x1F,0x9D };  /* 1F 9D */
char rcs_ident[] = TITLE;
#ifdef MWC
long _stksize = 20000L;     /* set MWC's stack to 20,000 */
#ifdef MWC_NAME           /* if defined in makefile set _cmdname for */
char _cmdname[]=MWC_NAME;   /* compress,zcat,uncomp check for desktop and */
#endif                      /* dumb shells */
#endif
#ifdef SOZOBON
long _STKSIZ = 20000L;      /* set runtime stack to 20,000 bytes */
#ifndef CMDNAME
#define CMDNAME "COMPRESS"
#endif
#endif
int overwrite = 0;          /* Do not overwrite unless given -f flag */
int maxbits = DFLTBITS;     /* user settable max # bits/code */
int exit_stat = 0;
int keep = KEEPFLAG;            /* True = don't kill file */
int keep_error = FALSE;     /* True = keep output file even if error exist */
char *prog_name;
char ifname[_MAX_DIR];
char inpath[_MAX_DIR];
char ofname [_MAX_DIR];
char outpath[_MAX_DIR];
int is_list = FALSE;            /* flag for file parameters */
char endchar[1];
char xbuf[XBUFSIZE];
char zbuf[ZBUFSIZE];
#ifdef MSDOS
char separator[] = "\\";
#else
char separator[] = "/";
#endif
int nomagic = FALSE;  /* Use a 3-byte magic number header, unless old file */
int zcat_flg = FALSE; /* Write output on stdout, suppress messages */
int quiet = !VERBOSE; /* don't tell me about compression */
int block_compress = BLOCK_MASK;
#ifdef COMP40
long int ratio = 0L;
long checkpoint = CHECK_GAP;
#endif
int force = 0;
#ifdef DEBUG
int verbose = VERBOSE;
int debug = FALSE;
#endif /* DEBUG */
#ifndef NOSIGNAL
SIGTYPE (*bgnd_flag)();
#endif
int do_decomp = FALSE;
#else               /* not defining instance */
extern UCHAR magic_header[];
extern char rcs_ident[];
#ifdef MWC
extern long _stksize;
#endif
extern int overwrite;
extern int maxbits;
extern int exit_stat;
extern int keep;
extern int keep_error;
extern char *prog_name;
extern char inpath[];
extern char outpath[];
extern int is_list;
extern char endchar[];
extern char xbuf[];
extern char zbuf[];
extern char ifname[];
extern char ofname[];
extern char separator[];
extern int nomagic;
extern int zcat_flg;
extern int quiet;
extern int block_compress;
#ifdef COMP40
extern long int ratio;
extern long checkpoint;
#endif
extern int force;
#ifdef DEBUG
extern int verbose;
extern int debug;
#endif /* DEBUG */
#ifndef NOSIGNAL
extern SIGTYPE (*bgnd_flag)();
#endif
extern int do_decomp;
#endif
