#include <stdio.h>
#include "compress.h" /* contains the rest of the include file declarations */
static int offset;
static long int in_count ;         /* length of input */
static long int bytes_out;         /* length of compressed output */
static INTCODE prefxcode, nextfree;
static INTCODE highcode;
static INTCODE maxcode;
static HASH hashsize;
static int  bits;
CONST HASH hs[] = {
  0x13FF,       /* 12-bit codes, 75% occupancy */
  0x26C3,       /* 13-bit codes, 80% occupancy */
  0x4A1D,       /* 14-bit codes, 85% occupancy */
  0x8D0D,       /* 15-bit codes, 90% occupancy */
  0xFFD9        /* 16-bit codes, 94% occupancy, 6% of code values unused */
};
#define Hashsize(maxb) (hs[(maxb) -MINBITS])
CONST INTCODE mc[] = {
  0x0FFF,       /* 12-bit codes */
  0x1FFF,       /* 13-bit codes */
  0x3FFF,       /* 14-bit codes */
  0x7FFF,       /* 15-bit codes */
  0xEFFF        /* 16-bit codes, 6% of code values unused */
};
#define Maxcode(maxb) (mc[(maxb) -MINBITS])
#ifdef __STDC__
#ifdef DEBUG
#define allocx(type, ptr, size) \
    (((ptr) = (type FAR *) emalloc((unsigned int)(size),sizeof(type))) == NULLPTR(type) \
    ?   (fprintf(stderr,"%s: "#ptr" -- ", prog_name), NOMEM) : OK \
    )
#else
#define allocx(type,ptr,size) \
    (((ptr) = (type FAR *) emalloc((unsigned int)(size),sizeof(type))) == NULLPTR(type) \
    ? NOMEM : OK \
    )
#endif
#else
#define allocx(type,ptr,size) \
    (((ptr) = (type FAR *) emalloc((unsigned int)(size),sizeof(type))) == NULLPTR(type) \
    ? NOMEM : OK \
    )
#endif
#define free_array(type,ptr,offset) \
    if (ptr != NULLPTR(type)) { \
        efree((ALLOCTYPE FAR *)((ptr) + (offset))); \
        (ptr) = NULLPTR(type); \
    }
#define alloc_array(type, ptr, size, offset) \
    ( allocx(type, ptr, (size) - (offset)) != OK \
      ? NOMEM \
      : (((ptr) -= (offset)), OK) \
    )
static char FAR *sfx = NULLPTR(char) ;
#define suffix(code)     sfx[code]
#if (SPLIT_PFX)
  static CODE FAR *pfx[2] = {NULLPTR(CODE), NULLPTR(CODE)};
#else
  static CODE FAR *pfx = NULLPTR(CODE);
#endif
#if (SPLIT_HT)
  static CODE FAR *ht[2] = {NULLPTR(CODE),NULLPTR(CODE)};
#else
  static CODE FAR *ht = NULLPTR(CODE);
#endif
int alloc_tables(maxcode, hashsize)
  INTCODE maxcode;
  HASH hashsize;
{
  static INTCODE oldmaxcode = 0;
  static HASH oldhashsize = 0;
  if (hashsize > oldhashsize) {
#if (SPLIT_HT)
      free_array(CODE,ht[1], 0);
      free_array(CODE,ht[0], 0);
#else
      free_array(CODE,ht, 0);
#endif
    oldhashsize = 0;
  }
    if (maxcode > oldmaxcode) {
#if (SPLIT_PFX)
        free_array(CODE,pfx[1], 128);
        free_array(CODE,pfx[0], 128);
#else
        free_array(CODE,pfx, 256);
#endif
        free_array(char,sfx, 256);
        if (   alloc_array(char, sfx, maxcode + 1, 256)
#if (SPLIT_PFX)
            || alloc_array(CODE, pfx[0], (maxcode + 1) / 2, 128)
            || alloc_array(CODE, pfx[1], (maxcode + 1) / 2, 128)
#else
            || alloc_array(CODE, pfx, (maxcode + 1), 256)
#endif
        ) {
            oldmaxcode = 0;
            exit_stat = NOMEM;
            return(NOMEM);
        }
        oldmaxcode = maxcode;
    }
    if (hashsize > oldhashsize) {
        if (
#if (SPLIT_HT)
            alloc_array(CODE, ht[0], (hashsize / 2) + 1, 0)
            || alloc_array(CODE, ht[1], hashsize / 2, 0)
#else
            alloc_array(CODE, ht, hashsize, 0)
#endif
        ) {
            oldhashsize = 0;
            exit_stat = NOMEM;
            return(NOMEM);
        }
        oldhashsize = hashsize;
    }
    return (OK);
}
# if (SPLIT_PFX)
#   define prefix(code)   (pfx[(code) & 1][(code) >> 1])
# else
#   define prefix(code) (pfx[code])
# endif
# if (SPLIT_HT)
#   define probe(hash)    (ht[(hash) & 1][(hash) >> 1])
#   define init_tables() \
    { \
      hash = hashsize >> 1; \
      ht[0][hash] = 0; \
      while (hash--) ht[0][hash] = ht[1][hash] = 0; \
      highcode = ~(~(INTCODE)0 << (bits = INITBITS)); \
      nextfree = (block_compress ? FIRSTFREE : 256); \
    }
# else
#   define probe(hash) (ht[hash])
#   define init_tables() \
    { \
      hash = hashsize; \
      while (hash--) ht[hash] = 0; \
      highcode = ~(~(INTCODE)0 << (bits = INITBITS)); \
      nextfree = (block_compress ? FIRSTFREE : 256); \
    }
# endif
#ifdef COMP40
int cl_block ()
{
    register long int rat;
    checkpoint = in_count + CHECK_GAP;
#ifdef DEBUG
	if ( debug ) {
        fprintf ( stderr, "count: %ld, ratio: ", in_count );
        prratio ( stderr, in_count, bytes_out );
		fprintf ( stderr, "\n");
	}
#endif
    if(in_count > 0x007fffff) {	/* shift will overflow */
        rat = bytes_out >> 8;
        if(rat == 0)       /* Don't divide by zero */
            rat = 0x7fffffff;
        else
            rat = in_count / rat;
    }
    else
        rat = (in_count << 8) / bytes_out;  /* 8 fractional bits */
    if ( rat > ratio ){
        ratio = rat;
        return FALSE;
    }
    else {
        ratio = 0;
#ifdef DEBUG
        if(debug)
    		fprintf ( stderr, "clear\n" );
#endif
        return TRUE;    /* clear the table */
    }
    return FALSE; /* don't clear the table */
}
#endif
void compress()
{
    int c,adjbits;
    register HASH hash;
    register INTCODE code;
    HASH hashf[256];
    maxcode = Maxcode(maxbits);
    hashsize = Hashsize(maxbits);
#ifdef COMP40
    checkpoint = CHECK_GAP;
    ratio = 0;
#endif
    adjbits = maxbits -10;
    for (c = 256; --c >= 0; ){
        hashf[c] = ((( c &0x7) << 7) ^ c) << adjbits;
    }
    exit_stat = OK;
    if (alloc_tables(maxcode, hashsize))  /* exit_stat already set */
        return;
    init_tables();
    if(is_list && !zcat_flg) {  /* Open output file */
        if (freopen(ofname, WRITE_FILE_TYPE, stdout) == NULL) {
            exit_stat = NOTOPENED;
            return;
        }
        if (!quiet)
            fprintf(stderr, "%s: ",ifname);
        setvbuf(stdout,zbuf,_IOFBF,ZBUFSIZE);
    }
    if (!nomagic) {
        putchar(magic_header[0]); putchar(magic_header[1]);
        putchar((char)(maxbits | block_compress));
        if(ferror(stdout)){  /* check it on entry */
            exit_stat = WRITEERR;
            return;
        }
        bytes_out = 3L;     /* includes 3-byte header mojo */
    }
    else
        bytes_out = 0L;      /* no 3-byte header mojo */
    in_count = 1L;
    offset = 0;
    if ((c = getchar()) == EOF) {
        exit_stat = ferror(stdin) ? READERR : OK;
        return;
    }
    prefxcode = (INTCODE)c;
    while ((c = getchar()) != EOF) {
        in_count++;
        hash = prefxcode ^ hashf[c];
        if (hash >= hashsize)
            hash -= hashsize;
        if ((code = (INTCODE)probe(hash)) != UNUSED) {
            if (suffix(code) != (char)c || (INTCODE)prefix(code) != prefxcode) {
                HASH hashdelta = (0x120 - c) << (adjbits);
                do  {
                    assert(code >= FIRSTFREE && code <= maxcode);
                    if (hash >= hashdelta) hash -= hashdelta;
                        else hash += (hashsize - hashdelta);
                    assert(hash < hashsize);
                    if ((code = (INTCODE)probe(hash)) == UNUSED)
                        goto newcode;
                } while (suffix(code) != (char)c || (INTCODE)prefix(code) != prefxcode);
            }
            prefxcode = code;
        }
        else {
            newcode: {
                putcode(prefxcode, bits);
                code = nextfree;
                assert(hash < hashsize);
                assert(code >= FIRSTFREE);
                assert(code <= maxcode + 1);
                if (code <= maxcode) {
                    probe(hash) = (CODE)code;
                    prefix(code) = (CODE)prefxcode;
                    suffix(code) = (char)c;
                    if (code > highcode) {
                        highcode += code;
                        ++bits;
                    }
                    nextfree = code + 1;
                }
#ifdef COMP40
                else if (in_count >= checkpoint && block_compress ) {
                    if (cl_block()){
#else
                else if (block_compress){
#endif
                        putcode((INTCODE)c, bits);
                        putcode(CLEAR, bits);
                        init_tables();
                        if ((c = getchar()) == EOF)
                            break;
                        in_count++;
#ifdef COMP40
                    }
#endif
                }
                prefxcode = (INTCODE)c;
            }
        }
    }
    putcode(prefxcode, bits);
    putcode(CLEAR, 0);
    if (ferror(stdout)){ /* check it on exit */
        exit_stat = WRITEERR;
        return;
    }
    if(zcat_flg == 0 && !quiet) {
#ifdef DEBUG
        fprintf( stderr,
            "%ld chars in, (%ld bytes) out, compression factor: ",
            in_count, bytes_out );
        prratio( stderr, in_count, bytes_out );
        fprintf( stderr, "\n");
        fprintf( stderr, "\tCompression as in compact: " );
        prratio( stderr, in_count-bytes_out, in_count );
        fprintf( stderr, "\n");
        fprintf( stderr, "\tLargest code (of last block) was %d (%d bits)\n",
            prefxcode - 1, bits );
#else
        fprintf( stderr, "Compression: " );
        prratio( stderr, in_count-bytes_out, in_count );
#endif /* DEBUG */
    }
    if(bytes_out > in_count)      /*  if no savings */
        exit_stat = NOSAVING;
    return ;
}
CONST UCHAR rmask[9] = {0x00, 0x01, 0x03, 0x07, 0x0f, 0x1f, 0x3f, 0x7f, 0xff};
void putcode(code,bits)
  INTCODE code;
  register int bits;
{
  static int oldbits = 0;
  static UCHAR outbuf[MAXBITS];
  register UCHAR *buf;
  register int shift;
  if (bits != oldbits) {
    if (bits == 0) {
      if (offset > 0) {
          fwrite(outbuf,1,(offset +7) >> 3, stdout);
          bytes_out += ((offset +7) >> 3);
      }
      offset = 0;
      oldbits = 0;
      fflush(stdout);
      return;
    }
    else {
      if (offset > 0) {
        fwrite(outbuf, 1, oldbits, stdout);
        bytes_out += oldbits;
        offset = 0;
      }
      oldbits = bits;
#ifdef DEBUG
      if ( debug )
        fprintf( stderr, "\nChange to %d bits\n", bits );
#endif /* DEBUG */
    }
  }
  buf = outbuf + ((shift = offset) >> 3);
  if ((shift &= 7) != 0) {
    *(buf) |= (*buf & rmask[shift]) | (UCHAR)(code << shift);
    *(++buf) = (UCHAR)(code >> (8 - shift));
    if (bits + shift > 16)
        *(++buf) = (UCHAR)(code >> (16 - shift));
  }
  else {
    *(buf) = (UCHAR)code;
    *(++buf) = (UCHAR)(code >> 8);
  }
  if ((offset += bits) == (bits << 3)) {
    bytes_out += bits;
    fwrite(outbuf,1,bits,stdout);
    offset = 0;
  }
  return;
}
int nextcode(codeptr)
  INTCODE *codeptr;
{
  static int prevbits = 0;
  register INTCODE code;
  static int size;
  static UCHAR inbuf[MAXBITS];
  register int shift;
  UCHAR *bp;
  if (prevbits != bits) {
    prevbits = bits;
    size = 0;
  }
  if (size - (shift = offset) < bits) {
    if ((size = fread(inbuf, 1, bits, stdin) << 3) <= 0 || ferror(stdin))
      return(NO);
    offset = shift = 0;
  }
  bp = inbuf + (shift >> 3);
  code = (*bp++ >> (shift &= 7));
  code |= *bp++ << (shift = 8 - shift);
  if ((shift += 8) < bits) code |= *bp << shift;
  *codeptr = code & highcode;
  offset += bits;
  return (TRUE);
}
void decompress()
{
  register int i;
  register INTCODE code;
  char sufxchar;
  INTCODE savecode;
  FLAG fulltable, cleartable;
  static char *token= NULL;         /* String buffer to build token */
  static int maxtoklen = MAXTOKLEN;
  exit_stat = OK;
    if (token == NULL && (token = (char*)malloc(maxtoklen)) == NULL) {
    	    exit_stat = NOMEM;
    	    return;
	}
  if (alloc_tables(maxcode = ~(~(INTCODE)0 << maxbits),0)) /* exit_stat already set */
     return;
    if(is_list && !zcat_flg) {  /* Open output file */
        if (freopen(ofname, WRITE_FILE_TYPE, stdout) == NULL) {
            exit_stat = NOTOPENED;
            return;
        }
        if (!quiet)
            fprintf(stderr, "%s: ",ifname);
        setvbuf(stdout,xbuf,_IOFBF,XBUFSIZE);
    }
  cleartable = TRUE;
  savecode = CLEAR;
  offset = 0;
  do {
    if ((code = savecode) == CLEAR && cleartable) {
      highcode = ~(~(INTCODE)0 << (bits = INITBITS));
      fulltable = FALSE;
      nextfree = (cleartable = block_compress) == FALSE ? 256 : FIRSTFREE;
      if (!nextcode(&prefxcode))
        break;
      putc((sufxchar = (char)prefxcode), stdout);
      continue;
    }
    i = 0;
    if (code >= nextfree && !fulltable) {
      if (code != nextfree){
        exit_stat = CODEBAD;
        return ;     /* Non-existant code */
    }
      code = prefxcode;
      token[i++] = sufxchar;
    }
    while (code >= 256) {
#     ifdef DEBUG
        if (code <= (INTCODE)prefix(code)){
            exit_stat= TABLEBAD;
            return;
        }
#     endif
      if (i >= maxtoklen) {
        maxtoklen *= 2;   /* double the size of the token buffer */
        if ((token = realloc(token, maxtoklen)) == NULL) {
          exit_stat = TOKTOOBIG;
          return;
        }
      }
      token[i++] = suffix(code);
      code = (INTCODE)prefix(code);
    }
    putc(sufxchar = (char)code, stdout);
    while (--i >= 0)
        putc(token[i], stdout);
    if (ferror(stdout)) {
        exit_stat = WRITEERR;
        return;
    }
    if (!fulltable) {
      code = nextfree;
      assert(256 <= code && code <= maxcode);
      prefix(code) = (CODE)prefxcode;
      suffix(code) = sufxchar;
      prefxcode = savecode;
      if (code++ == highcode) {
        if (highcode >= maxcode) {
          fulltable = TRUE;
          --code;
        }
        else {
          ++bits;
          highcode += code;           /* nextfree == highcode + 1 */
        }
      }
      nextfree = code;
    }
  } while (nextcode(&savecode));
  exit_stat = (ferror(stdin))? READERR : OK;
  return ;
}
