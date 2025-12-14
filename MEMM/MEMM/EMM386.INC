
ifndef INC_LIST
.xlist
endif

;
;   Message Flag Equates
;
INC_PRC_MSG	equ	00000001b	; Incorrect processor type message
INC_DOS_MSG	equ	00000010b	; Incorrect DOS message
MEM_ERR_MSG	equ	00000100b	; Memory error message
INS_ERR_MSG	equ	00001000b	; Already Installed message
NO_PF_MSG	equ	00010000b	; Nowhere to put PF message
SIZE_ADJ_MSG	equ	00100000b	; EMM Pool size adjusted message
BASE_ADJ_MSG	equ	01000000b	; Page Frame Base adjusted msg
MAPA_ADJ_MSG	equ	10000000b	; Map register address adjusted msg
INV_PARM_MSG	equ    100000000b	; Invalid parameter message
PF_WARN_MSG	equ   1000000000b	; PF located over ROM warning message
;
;  These messages cause MEMM to not install
;
KILLER_MSG =	INC_PRC_MSG+INC_DOS_MSG+MEM_ERR_MSG+INS_ERR_MSG+NO_PF_MSG
;
.list	; end of EMM386.INC
