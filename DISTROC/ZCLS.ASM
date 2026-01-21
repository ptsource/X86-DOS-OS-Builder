BDOS	EQU	0005H	;System Call Location
TPA	EQU	0100H	;Transient Program Area
CROUT	EQU	2D	;Character Output Function
CTRZ	EQU	26D	;Control Z Character
	;
CLS	ORG	TPA	;Program Start Location
	MVI	C,CROUT ;Load Fuction Call
	MVI	E,CTRZ	;Load E with CTRZ
	CALL	BDOS	;Call CP/M to Output
	RET		;Return to CP/M Control
	;
	END
T ;Load Fuction Call
	MVI	E,CTRZ	;Load E with CTRZ