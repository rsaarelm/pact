create : ' docol cell+ 1+ , ' create ,
' lit , ' docol cell+ 1+ , ' , , ' ] , ' exit ,

: ; lit exit , [ ' [ , ' exit , immediate!

: if ' 0branch , here @ $4 , ; immediate!

: (end) dup here @ swap - swap ! ;

: end (end) ; immediate!

: else ' branch , here @ $4 , swap (end) ; immediate!

: tail-recurse ' branch , last @ word-code cell+ here @ - , ; immediate!

: \ key '\n' <> if tail-recurse end ; immediate!

\ Defined the comment word, now we can talk.

\ The definition of the ; word is hairy. It needs to define itself while
\ there's still not the full word defining machinery present, and it also
\ needs to do immediate word stuff. So first you add the LIT EXIT , bit where
\ the ; word will compile the terminating EXIT instruction to the word
\ definition on which it's being called. Then you exit the current compile
\ mode and go back to intepreting with [, this happens here in the interpreter
\ state, not in the code of ;. Then you compile the [ operation into the
\ definition of ; with ' [ ,. Then the actual EXIT for ; itself, (not the word
\ that ; will terminate later) with ' exit , (since we're still defining ; and
\ can't use it here to end the definition yet). Finally tag ; as an immediate
\ word.


: test if 'A' emit cr else 'F' emit cr end ;

0 test
-1 test
