/********************************************************/
/*                                                      */
/*               www.wiki.ptsource.eu                   */
/*                                                      */
/********************************************************/
#include <stdio.h>
#define MAIN        /* header has defining instances of globals */
#include "compress.h" /* contains the rest of the include file declarations */
#define ARGVAL() (*++(*argv) || (--argc && *++argv))
char suffix[] = SUFFIX ;          /* only used in this file */
void main( argc, argv ) register int argc;
char **argv;
{
    char **filelist, **fileptr,*temp;
    char response;
    struct stat statbuf;
    prog_name = "COMPRESS";
#ifndef NOSIGNAL
    if ( (bgnd_flag = signal ( SIGINT, SIG_IGN )) != SIG_IGN ) {
        if (bgnd_flag == SIG_ERR) {
            exit_stat = SIGNAL_ERROR;
            check_error();
        }
        if( (signal(SIGINT,onintr) == SIG_ERR)
                || (signal(SIGSEGV,oops) == SIG_ERR)) {/* check your compiler docs. */
            exit_stat = SIGNAL_ERROR;
            check_error();
        }
    }
#endif
#ifdef ALLOC
    filelist = fileptr = (char **)(alloc(argc * sizeof(char *)));
#else
    filelist = fileptr = (char **)(malloc(argc * sizeof(char *)));
#endif
    *filelist = NULL;
    for (argc--, argv++; argc > 0; argc--, argv++) {
        if (**argv == '-') {        /* A flag argument */
            while (*++(*argv)) {    /* Process all flags in this arg */
                switch (**argv) {
#ifdef DEBUG
                    case 'D':
                        debug = TRUE;
                        keep_error = TRUE;
                        break;
                    case 'V':
                        verbose = TRUE;
                        version();
                        break;
#else
                    case 'V':
                        version();
                        break;
#endif /*DEBUG */
                    case 'v':
                        quiet = FALSE;
                        break;
                    case 'd':
                        do_decomp = TRUE;
                        break;
                    case 'f':
                        force = overwrite = TRUE;
                        break;
                    case 'n':
                        nomagic = TRUE;
                        break;
                    case 'C':
                        block_compress = FALSE;
                        break;
                    case 'b':
                    case 'B':
                        if (!ARGVAL()) {
                            fprintf(stderr, "Missing maxbits\n");
                            Usage(1);
                            exit(ERROR);
                        }
                        maxbits = atoi(*argv);
                        goto nextarg;
                    case 'I':
                        if (!ARGVAL()) {
                            fprintf(stderr, "Missing in_path name\n");
                            Usage(1);
                            exit(ERROR);
                        }
                        strcpy(inpath,*argv);
                        temp = &inpath[strlen(inpath)-1];
#ifdef MSDOS
                        if (*temp != '\\' && *temp != '/')
#else
                        if (*temp != separator[0])
#endif
                            strcat(inpath,separator);
                        goto nextarg;
                    case 'O':
                        if (!ARGVAL()) {
                            fprintf(stderr, "Missing out_path name\n");
                            Usage(1);
                            exit(ERROR);
                        }
                        strcpy(outpath,*argv);
                        temp = &outpath[strlen(outpath)-1];
#ifdef MSDOS
                        if (*temp != '\\' && *temp != '/')
#else
                        if (*temp != separator[0])
#endif
                            strcat(outpath,separator);
                        goto nextarg;
                    case 'c':
                        keep = zcat_flg = TRUE;
                        break;
                    case 'K':
                        keep_error = TRUE;
                        break;
                    case 'k':
                        keep = !keep;
                        break;
                    case '?':
                    case 'h':
                    case 'H':
                        Usage(0);
                        exit(NORMAL);
                        break;
                    case 'q':
                        quiet = TRUE;
                        break;
                    default:
                        fprintf(stderr, "%s : Unknown flag: '%c'\n",prog_name, **argv);
                        Usage(1);
                        exit(ERROR);
                } /* end switch */
            } /* end while processing this argument */
        }  /* end if option parameter */
        else {                                  /* must be input file name */
            *fileptr++ = *argv;                 /* Build input file list */
            *fileptr = NULL;
        } /* end else */
nextarg:
        continue;                          /* process nextarg */
    } /* end command line processing */
    if(maxbits < MINBITS || maxbits > MAXBITS) {
        fprintf(stderr,"\n%s: illegal bit value, range = %d to %d\n",prog_name,MINBITS,MAXBITS);
        exit(NORMAL);
    }
    if (zcat_flg && *outpath)         /* can't have an out path and zcat */
        *outpath = '\0';
    strcpy(ifname,"stdin");
    strcpy(ofname,"stdout");
    if (*filelist) {         /* Check if there are files specified */
        is_list = TRUE;
        for (fileptr = filelist; *fileptr; fileptr++) {
            exit_stat = 0;
            endchar[0] = '\0';
            if (do_decomp) {                /* DECOMPRESSION          */
                if (*inpath) {              /* adjust for inpath name */
                    strcpy(ifname,inpath);  /* and copy into ifname   */
                    strcat(ifname,name_index(*fileptr));
                } else
                    strcpy(ifname,*fileptr);
                if(!is_z_name(ifname))         /* Check for .Z suffix    */
                    if(!(make_z_name(ifname))) /* No .Z: tack one on     */
                        continue;
                if ((freopen(ifname, READ_FILE_TYPE, stdin)) == NULL) {
                    perror(ifname);
                    continue;
                } else
                    setvbuf(stdin,zbuf,_IOFBF,ZBUFSIZE);
                if (!nomagic) {             /* Check the magic number */
                    if ((getchar() != (magic_header[0] & 0xFF))
                            || (getchar() != (magic_header[1] & 0xFF))) {
                        fprintf(stderr, "%s: not in compressed format\n",
                                ifname);
                        continue;
                    }
                    maxbits = getchar();    /* set -b from file */
                    block_compress = maxbits & BLOCK_MASK;
                    maxbits &= BIT_MASK;
                    if(maxbits > MAXBITS) {
                        fprintf(stderr,
                                "%s: compressed with %d bits, can only handle %d bits\n",
                                ifname, maxbits, MAXBITS);
                        continue;
                    }
                }  /* end if nomagic */
                if (*outpath) {              /* adjust for outpath name */
                    strcpy(ofname,outpath);  /* and copy into ofname   */
                    strcat(ofname,name_index(ifname));
                } else
                    strcpy(ofname,ifname); /* DjG may screw up the placement */
                unmake_z_name(ofname);     /* strip off Z or .Z */
            } else {          /* COMPRESSION */
                if (*inpath) {              /* adjust for inpath name */
                    strcpy(ifname,inpath);  /* and copy into ifname   */
                    strcat(ifname,name_index(*fileptr));
                } else
                    strcpy(ifname,*fileptr);
                if (is_z_name(ifname)) {
                    fprintf(stderr, "%s: already has %s suffix -- no change\n",
                            ifname,suffix);
                    continue;
                }
                if ((freopen(ifname,READ_FILE_TYPE, stdin)) == NULL) {
                    perror(ifname);
                    continue;
                } else
                    setvbuf(stdin,xbuf,_IOFBF,XBUFSIZE);
                if (*outpath) {              /* adjust for outpath name */
                    strcpy(ofname,outpath);  /* and copy into ofname   */
                    strcat(ofname,name_index(ifname));
                } else /* place it in directory of input file */
                    strcpy(ofname,ifname); /* DjG may screw up the placement */
                if (!(make_z_name(ofname)))
                    continue;
            } /* end else compression  we now have the files set up */
            if (!overwrite && !zcat_flg) {
                if (!stat(ofname, &statbuf)) {
                    response = 'n';
                    fprintf(stderr, "%s already exists;", ofname);
#ifndef NOSIGNAL
                    if (foreground()) {
#else
                    if (TRUE) {
#endif
                        fprintf(stderr, "\ndo you wish to overwrite %s (y or n)? ",
                                ofname);
                        fflush(stderr);
                        response = get_one();
                    }
                    if ((response != 'y') && (response != 'Y')) {
                        fprintf(stderr, "\tnot overwritten\n");
                        continue;
                    }
                } /* end if stat */
            } /* end if overwrite */
            if (!zcat_flg)
                if(test_file(ifname)) {
                    putc('\n',stderr);
                    continue;  /* either linked or not a regular file */
                }
            if (!do_decomp) {
                compress();
                check_error();
            } else {
                decompress();
                check_error();
            }
            if(!zcat_flg) {
                copystat(ifname, ofname); /* Copy stats */
                if((exit_stat ) || (!quiet))
                    putc('\n', stderr);
            }       /* end if zcat */
        }           /*end for  loop */
    }               /* end if filelist */
    else {          /* it is standard input to standard output*/
#if (FILTER == FALSE)     /* filter is defined as true or false */
        if ( isatty(fileno(stdin)) ) {
            Usage(1);
            exit(NORMAL);
        }
#endif
        if (do_decomp) {
            setvbuf(stdin,zbuf,_IOFBF,ZBUFSIZE);  /* make the buffers larger */
            setvbuf(stdout,xbuf,_IOFBF,XBUFSIZE);
        } else {
            setvbuf(stdin,xbuf,_IOFBF,XBUFSIZE);  /* make the buffers larger */
            setvbuf(stdout,zbuf,_IOFBF,ZBUFSIZE);
        }
        if (!do_decomp) {   /* compress stdin to stdout */
            compress();
            check_error();
            if(!quiet)
                putc('\n', stderr);
        } /* end compress stdio */
        else {   /* decompress stdin to stdout */
            if (!nomagic) {
                if ((getchar()!=(magic_header[0] & 0xFF))
                        || (getchar()!=(magic_header[1] & 0xFF))) {
                    fprintf(stderr, "stdin: not in compressed format\n");
                    exit(ERROR);
                }
                maxbits = getchar();    /* set -b from file */
                block_compress = maxbits & BLOCK_MASK;
                maxbits &= BIT_MASK;
                if(maxbits > MAXBITS) {
                    fprintf(stderr,
                            "stdin: compressed with %d bits, can only handle %d bits\n",
                            maxbits, MAXBITS);
                    exit(ERROR);
                }
            }
            decompress();
            check_error();
        } /* end else decomp stdio */
    } /* end else standard input */
    exit(exit_stat);
}
void Usage(flag)
int flag;
{
    static char *keep2 =  "keep";
    static char *keep3 =  "kill (erase)";
    static char *on = "on";
    static char *off = "off";
#ifdef DEBUG
    fprintf(stderr,"Usage: %s [-cCdDf?hkKvV][-b maxbits][-Iinpath][-Ooutpath][filenames...]\n",
            prog_name);
#else
    fprintf(stderr,"Usage: %s [-cCdf?hkKvV][-b maxbits][-Iinpath][-Ooutpath][filenames...]\n",
            prog_name);
#endif
    if (flag)
        return;
    fprintf(stderr,"Argument Processing..case is significant:\n");
    fprintf(stderr,"     MUST use '-' for switch character\nAll flags are optional.\n");
#ifdef DEBUG
    fprintf(stderr,"     -D => debug; Keep file on error.\n");
    fprintf(stderr,"     -V => print Version; debug verbose\n");
#else
    fprintf(stderr,"     -V => print Version\n");
#endif
    fprintf(stderr,"     -d => do decompress, default = %s\n",(do_decomp)?on:off);
    fprintf(stderr,"     -v => verbose\n");
    fprintf(stderr,"     -f => force overwrite of output file, default = %s\n",
            (force)?on:off);
    fprintf(stderr,"     -n => no header: useful to uncompress old files\n");
    fprintf(stderr,"     -c => cat all output to stdout default = %s\n",
            (zcat_flg)?on:off);
    fprintf(stderr,"     -C => disable block compress.\n");
    fprintf(stderr,"     -k => %s input file, default == %s\n",(keep)?keep3:keep2,
            (keep)?keep2:keep3);
    fprintf(stderr,"     -K => %s output file on error, default == %s\n",
            (keep_error)?keep3:keep2,(keep_error)?keep2:keep3);
    fprintf(stderr,"     -b maxbits  => default == %d bits, max == %d bits\n",maxbits,MAXBITS);
    fprintf(stderr,"     -I pathname => infile path  == %s\n",inpath);
    fprintf(stderr,"     -O pathname => outfile path == %s\n",outpath);
    fprintf(stderr,"     -? -h => help usage.\n");
}
char get_one() {
    char tmp[2];
    int fd;
#ifdef SOZOBON
    return(0x7F & getche());
}
#else
#   ifdef MINIX
    fd = open("/dev/tty", 0);   /* open the tty directly */
#   else
    fd = fileno(stderr);             /* read from stderr */
#   endif
    read(fd, tmp, 2);
    while (tmp[1] != '\n') {
        if (read(fd, tmp+1, 1) < 0) {   /* Ack! */
            perror("stderr");
            break;
        }
    }
    return(tmp[0]);
}
#endif
void writeerr() {
    perror ( ofname );
    if (!zcat_flg && !keep_error) {
        fclose(stdout);
        unlink ( ofname );
    }
    exit ( 1 );
}
#ifndef NOSIGNAL
int foreground() {
    if(bgnd_flag) { /* background? */
        return(0);
    } else {          /* foreground */
        if(isatty(2)) {     /* and stderr is a tty */
            return(1);
        } else {
            return(0);
        }
    }
}
#endif
void prratio(stream, num, den)
FILE *stream;
long int num, den;
{
    register int q;         /* Doesn't need to be long */
    if(num > 214748L) {     /* 2147483647/10000 */
        q = (int) (num / (den / 10000L));
    } else {
        q = (int) (10000L * num / den);     /* Long calculations, though */
    }
    if (q < 0) {
        putc('-', stream);
        q = -q;
    }
    fprintf(stream, "%d.%02d%%", q / 100, q % 100);
}
int check_error() {   /* returning OK continues with processing next file */
    switch(exit_stat) {
        case OK:
            return (OK);
        case NOMEM:
            if (do_decomp)
                fprintf(stderr,"%s: not enough memory to decompress '%s'.\n", prog_name, ifname);
            else
                fprintf(stderr,"%s: not enough memory to compress '%s'.\n", prog_name, ifname);
            break;
        case SIGNAL_ERROR:
            fprintf(stderr,"%s: error setting signal interupt.\n",prog_name);
            exit(ERROR);
            break;
        case READERR:
            fprintf(stderr,"%s: read error on input '%s'.\n", prog_name, ifname);
            break;
        case WRITEERR:
            fprintf(stderr,"%s: write error on output '%s'.\n", prog_name, ofname);
            break;
        case TOKTOOBIG:
            fprintf(stderr,"%s: token too long in '%s'. Failed on realloc().\n", prog_name, ifname);
            break;
        case INFILEBAD:
            fprintf(stderr, "%s: '%s' in unknown compressed format.\n", prog_name, ifname);
            break;
        case CODEBAD:
            fprintf(stderr,"%s: file token bad in '%s'.\n", prog_name,ifname);
            break;
        case TABLEBAD:
            fprintf(stderr,"%s: internal error -- tables corrupted.\n", prog_name);
            break;
        case NOTOPENED:
            fprintf(stderr,"%s: could not open output file %s\n",prog_name,ofname);
            exit(ERROR);
            break;
        case NOSAVING:
            if (force)
                exit_stat = OK;
            return (OK);
        default:
            fprintf(stderr,"%s: internal error -- illegal return value = %d.\n", prog_name,exit_stat);
    }
    if (!zcat_flg && !keep_error) {
        fclose(stdout);         /* won't get here without an error */
        unlink ( ofname );
    }
    exit(exit_stat);
    return(ERROR);
}
