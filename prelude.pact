create : ' docol cell+ 1+ , ' create ,
' lit , ' docol cell+ 1+ , ' , , ' ] , ' exit ,

: ; lit exit , [ ' [ , ' exit , immediate!

: if ' 0branch , here @ $4 , ; immediate!

: end dup here @ swap - swap ! ; immediate!
