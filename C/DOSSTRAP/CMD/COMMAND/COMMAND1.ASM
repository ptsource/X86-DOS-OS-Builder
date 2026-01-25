 page 80,132
;	SCCSID = @(#)command1.asm	1.1 85/05/14
;	SCCSID = @(#)command1.asm	1.1 85/05/14
TITLE	COMMAND - resident code for COMMAND.COM
NAME	COMMAND



.XCREF
.XLIST
	INCLUDE DOSSYM.INC
	INCLUDE comsw.asm
	INCLUDE comequ.asm
	INCLUDE resmsg.equ		;AN000;
.LIST
.CREF

CODERES 	SEGMENT PUBLIC BYTE	;AC000;
CODERES ENDS

DATARES SEGMENT PUBLIC BYTE
	EXTRN	BATCH:WORD
	EXTRN	ECHOFLAG:BYTE
	EXTRN	disp_class:byte 	;AN055;
	EXTRN	execemes_block:byte	;AC000;
	EXTRN	execemes_off:word	;AC000;
	EXTRN	execemes_subst:byte	;AC000;
	EXTRN	execemes_seg:word	;AC000;
	EXTRN	EXTCOM:BYTE
	EXTRN	FORFLAG:BYTE
	EXTRN	IFFlag:BYTE
	EXTRN	InitFlag:BYTE
	EXTRN	NEST:WORD
	EXTRN	number_subst:byte	;AC000;
	EXTRN	PIPEFLAG:BYTE
	EXTRN	RETCODE:WORD
	EXTRN	SINGLECOM:WORD
DATARES ENDS

BATARENA	SEGMENT PUBLIC PARA	;AC000;
BATARENA ENDS

BATSEG		SEGMENT PUBLIC PARA	;AC000;
BATSEG	 ENDS

ENVARENA	SEGMENT PUBLIC PARA	;AC000;
ENVARENA  ENDS

ENVIRONMENT SEGMENT PUBLIC PARA 	; Default COMMAND environment
ENVIRONMENT ENDS

INIT	SEGMENT PUBLIC PARA
	EXTRN	CONPROC:NEAR
	EXTRN	init_contc_specialcase:near
INIT	ENDS

TAIL	SEGMENT PUBLIC PARA
TAIL	ENDS

TRANCODE	SEGMENT PUBLIC PARA
TRANCODE	ENDS

TRANDATA	SEGMENT PUBLIC BYTE
TRANDATA	ENDS

TRANSPACE	SEGMENT PUBLIC BYTE
TRANSPACE	ENDS

TRANTAIL	SEGMENT PUBLIC PARA
TRANTAIL	ENDS

RESGROUP  GROUP CODERES,DATARES,BATARENA,BATSEG,ENVARENA,ENVIRONMENT,INIT,TAIL
TRANGROUP GROUP TRANCODE,TRANDATA,TRANSPACE,TRANTAIL

	INCLUDE envdata.asm

; START OF RESIDENT PORTION

CODERES 	SEGMENT PUBLIC BYTE	;AC000;


	PUBLIC	EXT_EXEC
	PUBLIC	CONTC
	PUBLIC	Exec_Wait

ASSUME	CS:RESGROUP,DS:NOTHING,ES:NOTHING,SS:NOTHING

	EXTRN	lodcom:near
	EXTRN	LODCOM1:near

	ORG	0
ZERO	=	$

	ORG 80h-1
	PUBLIC	RESCOM
RESCOM	LABEL BYTE

	ORG	100H

PROGSTART:
	JMP	RESGROUP:CONPROC

;
; COMMAND has issued an EXEC system call and it has returned an error.	We
; examine the error code and select an appropriate message.
;
EXEC_ERR:
	push	ds				;AC000; get transient segment
	pop	es				;AC000;     into ES
	push	cs				;AC000; get resident segment
	pop	ds				;AC000;     into DS
ASSUME	DS:RESGROUP				;AN000;
	MOV	BX,RBADNAM			;AC000; Get message number for Bad command
	CMP	AX,error_file_not_found
	JZ	GOTEXECEMES
	MOV	BX,TOOBIG			;AC000; Get message number for file not found
	CMP	AX,error_not_enough_memory
	JZ	GOTEXECEMES
	MOV	BX,EXEBAD			;AC000; Get message number for bad exe file
	CMP	AX,error_bad_format
	JZ	GOTEXECEMES
	MOV	BX,AccDen			;AC000; Get message number for access denied
	CMP	AX,error_access_denied
	JZ	GOTEXECEMES			;AC000; go print message

DEFAULT_MESSAGE:
	MOV	BX,EXECEMES			;AC000; Get message number for default message
	MOV	EXECEMES_OFF,DX 		;AN000; put offset of EXEC string in subst block
	MOV	EXECEMES_SEG,ES 		;AN000; put segment of EXEC string in subst block
	MOV	AL,EXECEMES_SUBST		;AN000; get number of substitutions
	MOV	NUMBER_SUBST,AL 		;AN000;
	MOV	SI,OFFSET RESGROUP:EXECEMES_BLOCK ;AN000; get address of subst block
GOTEXECEMES:
	PUSH	CS
	POP	ES				;AC000; get resident segment into ES
ASSUME	ES:RESGROUP				;AN000;
	MOV	DX,BX				;AN000; get message number in DX
	INVOKE	RPRINT
	JMP	SHORT NOEXEC
;
; The transient has set up everything for an EXEC system call.	For
; cleanliness, we issue the EXEC here in the resident so that we may be able
; to recover cleanly upon success.
;
EXT_EXEC:
	push	dx				;AN000; save the command name offset
	INT	int_command			; Do the EXEC
	pop	dx				;AN000; restore the command name offset
	JC	EXEC_ERR			; EXEC failed
;
; The exec has completed.  Retrieve the exit code.
;
EXEC_WAIT:
	push	cs				;AC000; get resident segment
	pop	ds				;AC000;     into DS
	MOV	AH,WAITPROCESS			;AC000; Get errorlevel
	INT	int_command			; Get the return code
	MOV	[RETCODE],AX
;
; We need to test to see if we can reload the transient.  THe external command
; may have overwritten part of the transient.
;
NOEXEC:
	JMP	LODCOM
;
; This is the default system INT 23 handler.  All processes (including
; COMMAND) get it by default.  There are some games that are played:  We
; ignore ^C during most of the INIT code.  This is because we may perform an
; ALLOC and diddle the header!	Also, if we are prompting for date/time in the
; init code, we are to treat ^C as empty responses.
;
CONTC	PROC	FAR
	ASSUME	CS:ResGroup,DS:NOTHING,ES:NOTHING,SS:NOTHING
	test	InitFlag,initINIT		; in initialization?
	jz	NotAtInit			; no
	test	InitFlag,initSpecial		; doing special stuff?
	jz	CmdIRet 			; no, ignore ^C
	jmp	resgroup:init_contc_specialcase ; Yes, go handle it
CmdIret:
	iret					; yes, ignore the ^C
NotAtInit:
	test	InitFlag,initCtrlC		; are we already in a ^C?
	jz	NotInit 			; nope too.
;
; We are interrupting ourselves in this ^C handler.  We need to set carry
; and return to the user sans flags only if the system call was a 1-12 one.
; Otherwise, we ignore the ^C.
;
	cmp	ah,1
	jb	CmdIRet
	cmp	ah,12
	ja	CmdIRet
	add	sp,6				; remove int frame
	stc
	ret	2				; remove those flags...
;
; We have now received a ^C for some process (maybe ourselves but not at INIT).
;
; Note that we are running on the user's stack!!!  Bad news if any of the
; system calls below go and issue another INT 24...  Massive stack overflow!
; Another bad point is that SavHand will save an already saved handle, thus
; losing a possible redirection...
;
; All we need to do is set the flag to indicate nested ^C.  The above code
; will correctly flag the ^C diring the message output and prompting while
; ignoring the ^C the rest of the time.
;
; Clean up: flush disk.  If we are in the middle of a batch file, we ask if
; he wants to terminate it.  If he does, then we turn off all internal flags
; and let the DOS abort.
;
NotInit:
	or	InitFlag,initCtrlC		; nested ^c is on
	STI
	PUSH	CS				; El Yucko!  Change the user's DS!!
	POP	DS
ASSUME	DS:RESGROUP
	MOV	DISP_CLASS,UTIL_MSG_CLASS	;AN055; reset display class
	MOV	NUMBER_SUBST,NO_SUBST		;AN055; reset number of substitutions
	MOV	AX,SingleCom
	OR	AX,AX
	JNZ	NoReset
	PUSH	AX
	MOV	AH,DISK_RESET
	INT	int_command			; Reset disks in case files were open
	POP	AX
NoReset:
;
; In the generalized version of FOR, PIPE and BATCH, we would walk the entire
; active list and free each segment.  Here, we just free the single batch
; segment.
;
	TEST	Batch,-1
	JZ	CONTCTERM
	OR	AX,AX
	JNZ	Contcterm
	invoke	SavHand
	invoke	ASKEND				; See if user wants to terminate batch
;
; If the carry flag is clear, we do NOT free up the batch file
;
	JNC	ContBatch
	mov	cl,echoflag			;AN000; get current echo flag
	PUSH	BX				;G

ClearBatch:
	MOV	ES,[BATCH]			; get batch segment
	mov	di,batfile			;AN000; get offset of batch file name
	mov	ax,mult_shell_brk		;AN000; does the SHELL want this terminated?
	int	2fh				;AN000; call the SHELL
	cmp	al,shell_action 		;AN000; does shell want this batch?
	jz	shell_bat_cont			;AN000; yes - keep it

	MOV	BX,ES:[BATFORPTR]		;G get old FOR segment
	cmp	bx,0				;G is a FOR in progress
	jz	no_bat_for			;G no - don't deallocate
	push	es				;G
	mov	es,bx				;G yes - free it up...
	MOV	AH,DEALLOC			;G
	INT	21H				;G
	pop	es				;G restore to batch segment

no_bat_for:
	mov	cl,ES:[batechoflag]		;G get old echo flag
	MOV	BX,ES:[BATLAST] 		;G get old batch segment
	MOV	AH,DEALLOC			; free it up...
	INT	21H
	MOV	[BATCH],BX			;G get ready to deallocate next batch
	DEC	NEST				;G Is there another batch file?
	JNZ	CLEARBATCH			;G Keep going until no batch file

;
; We are terminating a batch file; restore the echo status
;

shell_bat_cont: 				;AN000; continue batch for SHELL

	POP	BX				;G
	MOV	ECHOFLAG,CL			;G reset echo status
	MOV	PIPEFLAG,0			;G turn off pipeflag
ContBatch:
	invoke	CRLF				;G print out crlf before returning
	invoke	RestHand
;
; Yes, we are terminating.  Turn off flags and allow the DOS to abort.
;
CONTCTERM:
	XOR	AX,AX				; Indicate no read
	MOV	BP,AX
;
; The following resetting of the state flags is good for the generalized batch
; processing.
;
	MOV	IfFlag,AL			; turn off iffing
	MOV	[FORFLAG],AL			; Turn off for processing
	call	ResPipeOff
	CMP	[SINGLECOM],AX			; See if we need to set SINGLECOM
	JZ	NOSETSING
	MOV	[SINGLECOM],-1			; Cause termination on pipe, batch, for
NOSETSING:
;
; If we are doing an internal command, go through the reload process.  If we
; are doing an external, let DOS abort the process.  In both cases, we are
; now done with the ^C processing.
;
	AND	InitFlag,NOT initCtrlC
	CMP	[EXTCOM],AL
	JNZ	DODAB				; Internal ^C
	JMP	LODCOM1
DODAB:
	STC					; Tell DOS to abort
	RET					; Leave flags on stack
ContC	ENDP

public	ResPipeOff
	assume	ds:nothing,es:nothing
ResPipeOff:
	SaveReg <AX>
	xor	ax,ax
	xchg	PipeFlag,al
	or	al,al
	jz	NoPipePop
	shr	EchoFlag,1
NoPipePop:
	RestoreReg  <AX>
	return
CODERES ENDS
	END	PROGSTART
