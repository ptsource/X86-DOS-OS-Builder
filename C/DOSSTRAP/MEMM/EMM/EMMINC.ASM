	page 58,132
;******************************************************************************
	title	EMMINC.ASM - lists all EMMLIB.LIB include files


.lfcond
.386p

;******************************************************************************
;	I N C L U D E S
;******************************************************************************
INC_LIST	EQU	1		; list include files

	page
	include	DESC.INC
	page
	include	EMMDEF.INC
	page
;	include	INSTR386.INC
;	page
	include	OEMDEP.INC
	page
	include	PAGE.INC
	page
	include	VDMSEG.INC
	page
	include	VDMSEL.INC

	end
