/********************************************************/
/*                                                      */
/*               www.wiki.ptsource.eu                   */
/*                                                      */
/********************************************************/
#include <dir.h>
#include <dos.h>
#include <io.h>
#include <string.h>
unsigned long int sum_subdir(struct ffblk, unsigned long int *);
void main(int argc, char *argv[])
{
	struct ffblk ffblk;
	unsigned long int sum, number_space;
	unsigned long int *dir_num;
	int done, test;
	char buffer[128], buffer2[128];
	test=666;
	dir_num=&number_space;
	if(argc>=2) {
        	getcwd(buffer2, 128);
		test=chdir(argv[1]);
		if(test!=0) {
			printf("Not a valid directory argument.\n");
			printf("Usage: dirspace [path]\n");
			exit(1);
		}
	}
	*dir_num=1;  /* this counts the starting directory */
	getcwd(buffer,128);
	printf("\n%s\n",buffer);
	sum=sum_subdir(ffblk, dir_num);
	printf("\n%lu bytes in %lu directories.\n", sum, *dir_num);
	/* if a command line arg was used */
	/* we go back to the original dir */
	if(test==0)
		chdir(buffer2);
}
unsigned long int sum_subdir(struct ffblk ffblk, unsigned long int *dir_num)
{
	unsigned long int sum=0;
	int done, attrib, failed;
	char buffer[128], dotdir[] = {'.','\0'};
	/* I think the 255 will "see" any DOS attribute because   */
	/* of the hexadecimal definitions of the attribs in dir.h */
	done=findfirst("*.*",&ffblk,255);
	/* This checks for the . and .. entries in the dir listing. */
	/* If found, they are skipped.  This is necessary because   */
	/* the root dir doesn't have these, and always skipping     */
	/* the first two entries misses the first two dirs in the   */
        /* root directory.  Thus the necessity of this check.       */
	if(strcmp(ffblk.ff_name,dotdir)==0) {
		done=findnext(&ffblk);
		done=findnext(&ffblk);
	}
	if(!done)
		do {
			failed=chdir(ffblk.ff_name);
			/* If successful chdir returns 0 */
			/* so !failed means we went into */
			/* a subdirectory.               */
			if(!failed) {
                        	getcwd(buffer, 128);
				printf("%s\n", buffer);
				(*dir_num)++;
				sum+=sum_subdir(ffblk, dir_num);
				chdir("..");
                        }
			sum+=ffblk.ff_fsize; /* on directories this == 0 */
			done=findnext(&ffblk);
		} while(!done);
	return(sum);
}
