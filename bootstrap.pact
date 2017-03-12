\ Bootstrap Pact code for the initial interpreter. Will be
\ transpiled into symbolic assembly.

: ram-start ( -- addr ) $40000000 ;

\ Hardcoded RAM map (relative to ram-start):
\ 0x0000    return stack
\ 0x0100    word buffer
\ 0x0180    LAST
\ 0x0184

: =0 ( x -- !x ) if 0 else -1 then ;
: < ( x y -- x<y ) - <0 ;
: <= ( x y -- x<=y ) - 1 - <0 ;
: >= ( x y -- x>=y ) swap <= ;
: invert ( x -- ~x ) -1 xor ;
: ?dup ( x -- x x | 0 ) dup if dup then ;
: 2dup ( x y -- x y x y ) over over ;
: -rot ( x y z -- z x y ) rot rot ;
: 2drop ( x y -- ) drop drop ;
: nip ( x y -- y ) swap drop ;

: cell ( x -- cell-size*x ) 4 * ;
: cell+ ( x -- x+cell-size ) 1 cell + ;

: cr ( -- ) $a emit ;

: .digit ( x -- ) 48 + emit ;

: .hex-digit ( x -- ) dup 10 < if 48 + emit else 55 + emit then ;

: (.hex) ( x -- )
    ?dup if
        dup 4 rshift (.hex)
        $f and .hex-digit
    then ;

\ Print a hex word to stdout
: .hex ( x -- )
    36 emit
    dup if
        (.hex)
    else
        .hex-digit
    then ;

\ Print a string to stdout
: .str ( addr -- )
    dup c@ =0 if drop else
    dup c@ emit 1 + tail-recurse then ;

: (.s) ( addr -- )
    dup sp0 = if exit then
    dup @ .hex cr cell+ tail-recurse ;

\ Dump stack to stdout
: .s ( -- ) sp@ (.s) drop ;

\\ Bitstring ops

\ Make a 0-valued bitstring word with given bit count and left shift
\ (The actual value can be applied with just an OR op to the 0bits.)
: make-bits ( lshift num-bits -- 0bits ) 16 lshift swap 24 lshift or ;

: bits-mask ( bits -- zero-mask )
    dup 16 rshift $ff and 1 swap lshift 1 - swap 24 rshift lshift invert ;

: bits-value ( bits -- value ) dup $ff and swap 24 rshift lshift ;

: unpack-bits ( bits -- value zero-mask ) dup bits-value swap bits-mask ;

: apply-bits ( value bits -- value' ) unpack-bits rot and or ;

\ Apply bitstring (combination of value and 0bits) to memory address,
\ leave bits outside the string intact.
: bits! ( addr 0bits value -- ) or swap dup @ rot apply-bits swap ! ;

: emit ( char -- ) $E0000000 ! ;

: key ( -- c ) $E0000000 @ ;

: halt ( -- ) 1 $E000E020 ! ;

\\ Input parsing

: word-buffer ( -- ptr ) ram-start $100 + ;
: word-buffer-len ( -- n ) $80 ;

: word-buffer-end? ( ptr -- ? ) word-buffer word-buffer-len + 1 - >= ;

: whitespace? ( key -- ? )
    dup 32 = if drop -1 exit then
    dup 10 = if drop -1 exit then
    drop 0 ;

: (read) ( ptr -- )
    dup word-buffer-end? if 0 swap c! exit then
    key dup whitespace? if drop 0 swap c! exit then
    over c! 1 + tail-recurse ;

\ Read a word into input buffer, stops at first whitespace char
: read ( -- str )
    word-buffer (read)
    word-buffer ;

: main-loop ( -- )
    read .str cr 64 emit 65 emit cr halt ;

: boot ( -- ) main-loop ;
