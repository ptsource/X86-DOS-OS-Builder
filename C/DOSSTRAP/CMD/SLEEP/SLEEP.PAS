{/*******************************************************/
/*                                                      */
/*               www.wiki.ptsource.eu                   */
/*                                                      */
/*******************************************************/}
PROGRAM SLEEP;

Uses Crt, Dos;

VAR i, k            : INTEGER;
    time1, time2    : LONGINT;
    ch              : CHAR;
    str             : STRING;
    stdout          : TEXT;
    returncode      : BYTE;
    h1, m1, s1, hu1 : WORD;
 
Begin
  If ParamCount >= 1 Then
  Begin
    str := Paramstr(1);
    Val(str, i, k);
    If k <> 0 Then
    Begin
      WriteLn(Chr(7));       {beep twice}
      WriteLn(Chr(7));
      WriteLn('Wrong parameter setting !!');
      i := 0;
    End
  End
  Else i := 0;
  Assign(stdout, '');                                {Assign standard output}
  Rewrite(stdout);
  WriteLn(stdout, 'Press any key to continue... ');
  GetTime(h1, m1, s1, hu1);
  time1 := 3600 * h1 + 60 * m1 + s1;
  time2 := time1;
  While (NOT KeyPressed) AND (ABS(time1 - time2) <= i) Do
  Begin
    GetTime(h1, m1, s1, hu1);
    time2 := 3600 * h1 + 60 * m1 + s1;
    If i = 0 Then time2 := time1;
  End;
  If KeyPressed Then
  Begin
    ch := ReadKey;
    Case ch Of
      '1'..'9': returncode := Ord(ch) - 48;   {code is 1..9 for keys 1..9}
      '0'     : returncode := 10;             {code is 10 for key 0}
      Chr(27) : returncode := 200;            {code is 200 for ESC}
    Else
      returncode := 100;                      {code is 100 for any other key}
    End;
  End
  Else
    returncode := 0;                          {code is 0 if timeout true}
  ASM
   mov ah, 4ch
   mov al, returncode
   int 21h
  End;
End.
