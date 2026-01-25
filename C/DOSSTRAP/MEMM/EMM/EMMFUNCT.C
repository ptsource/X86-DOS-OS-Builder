

/******************************************************************************
	INCLUDE FILES
 ******************************************************************************/ 
#include "emm.h"


/******************************************************************************
	EXTERNAL DATA STRUCTURES
 ******************************************************************************/ 
/*
 * I/O Map
 * map_size
 *	this is an array of port addresses, 4 ports per
 *	emulated board. Each emulated board has up to
 *	128 16Kb EMM pages assigned. The size of the table,
 *	the number of ports used, is map_size
 *		map_size = (<number of 386 pages>/(128*4))*4
 */
/*extern unsigned short	iomap[]; */
/*extern char		map_size;*/

/*
 *  map_known
 *	This flags is set whenever the user is given the I/O map
 */
/*extern char		map_known; */

/*
 * page frame base
 *	this is a map of the linear addresses of the
 *	4 16Kb EMM `physical' windows that the user
 *	accesses the EMM pages through. The entries
 *	of this array are far pointers into the page table.
 *	Thus, the address defined by page_frame_base[0]
 *	is the address of the long word that is the page
 *	table entry for the first EMM window. The reason for 
 *	this obscurity is in speed of mapping -- it is used
 *	to directly obtain access to the entry to be programmed
 */
extern unsigned	long page_frame_base[];

/*
 * save_map
 *	This is an array of structures that save the 
 *	current mapping state. Size is dynamically determined.
 */
extern struct save_map save_map[];

/*
 * handle_table
 *	This is an array of handle pointers.
 *	page_index of zero means free
 */
extern struct handle_ptr handle_table[];
extern Handle_Name Handle_Name_Table[];
extern unsigned short	handle_table_size;	/* number of entries */
extern unsigned short	handle_count;		/* active handle count */

/*
 * EMM Page table
 *	this array contains lists of indexes into the 386
 *	Page Frame Addresses (pft386).  Each list is pointed to
 *	by a handle table entry and is sequential/contiguous.
 *	This is so that maphandlepage doesn't have to scan
 *	a list for the specified entry.
 */
extern unsigned	short	*emm_page;		/* ptr to _emm_page array */
extern unsigned	short	free_count;		/* current free count */
extern unsigned	short	total_pages;		/* number being managed */
extern unsigned	short	emmpt_start;		/* next free entry in table */

/*
 * EMM free table
 *	this array is a stack of available page table entries. 
 *	each entry is an index into pft386[].
 */
extern	unsigned short	*emm_free;		/* ptr to _emm_free array */
extern	unsigned short	free_top;

/*
 * Page frame table
 *	This array contains addresses of physical page frames
 *	for 386 pages. A page is refered to by an index into
 *	this array
 */
extern union pft386 *pft386;		/* ptr to page frame table array */


/*
 * Current status of `HW'. The way this is handled is that
 * when returning status to caller, normal status is reported 
 * via EMMstatus being moved into AX. Persistant errors
 * (such as internal datastructure inconsistancies, etc) are
 * placed in `EMMstatus' as HW failures. All other errors are 
 * transient in nature (out of memory, handles, ...) and are 
 * thus reported by directly setting AX. The EMMstatus variable
 * is provided for expansion and is not currently being
 * set to any other value.
 */
extern unsigned short EMMstatus;

/*
 * debug & such
 */
/*unsigned null_count = 0;	/* number of attempts to map null pages */


/******************************************************************************
	EXTERNAL FUNCTIONS
 ******************************************************************************/ 
extern	struct handle_ptr	*valid_handle();	/* validate handle */
extern  unsigned far		*source_addr();		/* get DS:SI far ptr */
extern  unsigned far		*dest_addr();		/* get ES:DI far ptr */
/*extern	unsigned		AutoUpdate();		/* update auto mode */
extern	unsigned		wcopy();
extern	unsigned		copyout();
extern	void			reallocate();


/******************************************************************************
	ROUTINES
 ******************************************************************************/ 

/*
 * Avail_Pages()
 * returns: number of available emm pages
 *
 *	06/09/88	PC	added the function
 */
unsigned short
Avail_Pages()
{
	return(free_count) ;
}

/*
 * get_pages(num,pto)
 *	num --- number of pages desired
 *      pto --- offset into emm_page array where the pages got are to be copied
 * return value:
 *	emm_page[] index (pointer to list of allocated pages)
 *	NULL_PAGE means failure.
 *	
 * 	05/06/88  ISP	Updated for MEMM removed handle as a parameter 
 */
unsigned
get_pages(num,pto)
register unsigned num;
register unsigned pto;
{
	register unsigned pg;
	unsigned	f_page;

	if(free_count < num)
		return(NULL_PAGE);	/* not enough memory */
	free_count -= num;		/* adjust free count */
	f_page = pg = pto;
/*	  emmpt_start += num;	*/	    /* new offset of avail area */

	/*
	 * copy num elements from the emm_free array
	 * to the emm_page table array and update the
	 * corresponding page frame table entry (with a 
	 * handle back pointer)
	 */
	wcopy(emm_free+free_top, emm_page+pg, num);
	free_top += num;
	return(f_page);
}


/*
 * free_pages(hp)
 *	hp --- handle whose pages should be deallocated
 *
 * Free the pages associated with the handle, but don't free the handle
 *
 *  05/09/88	ISP Pulled out from the deallocate page routine
 */
void
free_pages(hp)
register struct handle_ptr *hp;
{
	register unsigned		next;
	unsigned			new_start;
	unsigned			h_size;

	if (hp->page_count == 0) return ;
	/*
	 * copy freed pages to top of free stack 
	 */
	free_top -= hp->page_count;	/* free_top points to new top */
	free_count += hp->page_count;	/* bookkeeping */
	wcopy(emm_page+hp->page_index, /* addr of first of list */
		emm_free+free_top,	 /* addr of free space */
		hp->page_count);	 /* # of pages to be freed */

	/*
	 * now, the hard part. squeeze the newly created hole
	 * out of the emm_page array. this also requires updating the
	 *  handle_table entry via the backlink in the pft386 array.
	 *
	 * do this in two phases:
	 *	- copy the lower portion up to squeeze the hole out
	 *	- readjust the handle table to point to the new
	 *	   location of the head element
	 */

	next = hp->page_index + hp->page_count;
	if(next == emmpt_start )	/* any lists below? */
	{
		/* no, all done */
		emmpt_start -= hp->page_count;
		return;
	}

	new_start = emmpt_start - hp->page_count;
	wcopy(emm_page+next,	/* 1st of rest of list */
		emm_page+hp->page_index,/* addr of freed area */
		emmpt_start-next);	/* size of block of pages  */

	/*
	 * loop through the handle table entries, fixing up
	 * their page index fields
	 */
	h_size = hp->page_count;
	hp->page_count = 0;		/* not really necessary */
	for(hp=handle_table;hp < &handle_table[handle_table_size];hp++)
		if((hp->page_index != NULL_PAGE) &&
		   (hp->page_index >= next) )
			hp->page_index -= h_size;
	emmpt_start = new_start;		/* fix emmpt_start */
}

/*
 * get status
 *	no parameters
 *
 * return current status of EMM subsystem
 * (which, due to superior design is always just fine)
 *
 *  	05/06/88  ISP 	No Update needed for MEMM
 */
GetStatus()
{
	setAH((unsigned char)EMMstatus);	/* if we got here, we're OK */
}


/*
 * get page frame address
 *	no parameters
 *
 * return the address of where the pages get mapped 
 * in user space
 *
 *	05/06/88  ISP	Updated this routine from WIN386 sources.
 */
GetPageFrameAddress()
{
	extern unsigned short PF_Base;
	extern unsigned short page_frame_pages;

	/*
	 * return the 8086 style base address of
	 * the page frame base. 
	 */
	if ( page_frame_pages < 4 ) {
		setAH(EMM_HW_MALFUNCTION);	/* GET LOST!!! */
		if ( PF_Base == 0xFFFF )
			setBX(0xB000);		/* In case error is ignored */
		else
			setBX(PF_Base);	/* stunted page frame */
		return;
	}
	setBX(PF_Base);
	setAH((unsigned char)EMMstatus);	/* OK return */
}


/*
 * get unallocated page count
 *	no parameters
 *
 * returns:
 *	bx -- count of free pages
 *	dx -- total number of pages (free and allocated)
 *
 *	05/06/88  ISP	No update needed for MEMM
 */
GetUnallocatedPageCount()
{
	setBX(free_count);
	setDX(total_pages);
	setAH((unsigned char)EMMstatus);
}

/*
 * allocate pages
 *	parameters:
 *		n_pages (bx) -- allocation size request
 *
 * allocates the requested number of pages, creates
 * a handle table entry and returns a handle to the
 * allocated pages.
 *	calls AllocateRawPages
 *
 *  05/09/88  ISP   updated for MEMM.  Only handle value returned, not handle
 *		    value with high byte as not of handle value. call to get
 *		    pages also updated to remove handle parameter.
 */
AllocatePages()
{
#define	n_pages	((unsigned)regp->hregs.x.rbx)
	if(handle_count == handle_table_size){	/* no more handles? */
		setAH(NO_MORE_HANDLES);	/* nope */
		return;
	}

	if(n_pages == 0) {
		setAH(ZERO_PAGES);
		return;
	}

	AllocateRawPages() ;
}
#undef	n_pages

/*
 * allocate raw pages
 *	parameters:
 *		n_pages (bx) -- allocation size request
 *
 * allocates the requested number of raw pages,
 * allocating 0 page is Okay
 * calls allocated pages if non-zero.
 *
 * CREATED : 08/08/88 PLC
 */
AllocateRawPages()
{
#define	n_pages	((unsigned)regp->hregs.x.rbx)
	register unsigned handle;	/* handle table index */
	register struct handle_ptr *hp;

	if(handle_count == handle_table_size){	/* no more handles? */
		setAH(NO_MORE_HANDLES);	/* nope */
		return;
	}

	if(n_pages > total_pages) {
		setAH(NOT_ENOUGH_EXT_MEM);
		return;
	}

	/*
	 * loop through table to
	 * find available handle (page_index = NULL_PAGE)
	 */
	hp = (struct handle_ptr *)handle_table;
	for(handle=0;handle<handle_table_size;handle++,hp++)
		if(hp->page_index == NULL_PAGE) 
			break;		/* found a free one */
	/*
	 * try and allocate pages 
	 */
	if((hp->page_index=get_pages(n_pages,emmpt_start)) != NULL_PAGE) {
		emmpt_start += n_pages;
		setAH((unsigned char)EMMstatus);	/* got them! */
	}
	else {
		setAH(NOT_ENOUGH_FREE_MEM);	/* out of pages */
		return;
	}

	hp->page_count=n_pages;	/* set count */
	handle_count++;
	setDX(handle);

/*	AutoUpdate();	/* update status of Auto mode */

}
#undef	n_pages

/*
 * deallocate pages
 *	parameters:
 *		dx -- handle
 *
 * free up the pages and handle table entry associated
 * with this handle
 *
 * 05/09/88  ISP    Updated for MEMM. Pulled out free_page routine and
 *		    added support for handle name blanking.
 */
DeallocatePages()
{
#define	handle ((unsigned)regp->hregs.x.rdx)
	register struct handle_ptr	*hp;
	struct save_map			*smp;	/* save map table ptr */
	long	*Name ;		/* points to handle name entry to clear */

	if ( handle == 0 ) {		/* Special handle, don't release */
		int savbx = regp->hregs.x.rbx;
		regp->hregs.x.rbx = 0;
		ReallocatePages();
		regp->hregs.x.rbx = savbx;
		return;
	}

	if((hp=valid_handle(handle)) == NULL_HANDLE)
		return;  /* invalid handle, error code set */
	/*
	 * check for save area in use for this handle
	 */
	if( save_map[ (handle & 0x00FF) ].s_handle != (unsigned)NULL_HANDLE )
	{
		setAH(SAVED_PAGE_DEALLOC);
		return;
	}

	free_pages(hp); 	      /*free the pages associated with handle*/
	hp->page_index = NULL_PAGE;   /*and then free the handle*/
	hp->page_count = 0;	      /*bookkeeping*/
	Name = (long *)Handle_Name_Table[handle & 0xFF];
	*(Name+1) = *(Name) = 0L;     /* zero the eight byte name */
	handle_count--; 	      /* one less active handle */

/*	AutoUpdate();	/* update status of Auto mode */
	setAH((unsigned char)EMMstatus);	/* done */
}
#undef	handle 
	

/*
 * get emm version
 *	no parameters
 *
 * returns the version number of the emm driver
 *
 * 	05/06/88  ISP	No update needed for MEMM
 */
GetEMMVersion()
{
	setAX( (EMMstatus<<8) | EMM_VERSION );
}

/*
 * Get EMM handle count
 *	no parameters
 *
 * return the number of active EMM handles
 *
 * 	05/06/88  ISP 	No update needed for MEMM
 */
GetEMMHandleCount()
{
	setBX(handle_count);
	setAH((unsigned char)EMMstatus);
}

/*
 * Get EMM handle pages
 *	parameters:
 *		dx -- handle
 *
 * return the number of pages allocated to specified handle in BX
 *
 *	05/09/88  ISP	No update needed for MEMM
 */
GetEMMHandlePages()
{
#define	handle	((unsigned)regp->hregs.x.rdx)
	register struct handle_ptr *hp;

	if((hp=valid_handle(handle))==NULL_HANDLE)	/*valid handle? */
		return;				/* no */
	setBX(hp->page_count);
	setAH((unsigned char)EMMstatus);
}

/*
 * Get All EMM Handle Pages
 *	parameters:
 *		es:di -- userptr
 *
 * fill out array of handle/size pairs
 *
 * 05/09/88  ISP    Updated for MEMM (just removed upper byte of handle)
 */
GetAllEMMHandlePages()
{
	unsigned far *u_ptr;
	register struct handle_ptr *hp;
	register unsigned h_index;

	/*
	 * scan handle table and for each valid entry,
	 * copy handle and size to user array
	 */
	u_ptr = dest_addr();

	hp=handle_table;
	for(h_index=0;h_index<handle_table_size;h_index++)   
	{
		/* scan table for entries */
		if(hp->page_index != NULL_PAGE)	/* valid entry? */
		{
			*u_ptr++ = h_index;   /* handle */
			*u_ptr++ = hp->page_count;	/*# of pgs for handle*/
		}
		hp++;				/* next entry */
	}
	setBX(handle_count);			/* bx <-- handle count */
	setAH((unsigned char)EMMstatus);
}

/*
 * Get Page Mapping Register I/O Port Array
 *	parameters:
		es:di -- user array
 *
 *  05/09/88  ISP   Function not supported
 */
GetPageMappingRegisterIOArray() 
{

	setAH(INVALID_FUNCTION);
}

/*
 * Get Logical to Physical Page Translation Array
 *	parameters:
 *		es:di -- pointer to user array
 *		dx ----- EMM handle
 *
 *  05/09/88  ISP   Function not supported
 */
GetLogicalToPhysicalPageTrans()
{
	setAH(INVALID_FUNCTION);
}
