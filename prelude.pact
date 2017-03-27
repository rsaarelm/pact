create : ' docol cell+ 1+ , ' create ,
' lit , ' docol cell+ 1+ , ' , , ' ] , ' exit ,

: ; lit exit , [ ' [ , ' exit , immediate!

: if ' 0branch , here @ $4 , ; immediate!

: (end) dup here @ swap - swap ! ;

: end (end) ; immediate!

: else ' branch , here @ $4 , swap (end) ; immediate!


: test if 'A' emit cr else 'F' emit cr end ;

0 test
-1 test
