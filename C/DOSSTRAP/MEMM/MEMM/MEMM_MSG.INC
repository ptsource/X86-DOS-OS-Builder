
not_there	db	"EMM386 driver not installed.",CR,LF,BEL,"$"

vmode		db	"EMM386 Active.",CR,LF,"$"

rmode		db	"EMM386 Inactive.",CR,LF,"$"

amode		db	"EMM386 in Auto mode.",CR,LF,"$"

verr_msg	db	"Unable to activate EMM386.",CR,LF,BEL,"$"

rerr		db	"Unable to inactivate EMM386.",CR,LF,BEL,"$"

aerr		db	"Unable to place EMM386 in Auto mode.",CR,LF,BEL,"$"

parmerr 	db	"Usage: EMM386 [ ON | OFF | AUTO]"
		db	CR,LF,BEL,"$"
