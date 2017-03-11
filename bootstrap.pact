\ Bootstrap Pact code for the initial interpreter. Will be
\ transpiled into symbolic assembly.

: =0 ( x -- !x ) if 0 else -1 then ;
: < ( x y -- x<y ) - <0 ;
: <= ( x y -- x<=y ) - 1 - <0 ;
: invert ( x -- ~x ) -1 xor ;
: ?dup ( x -- x x | 0 ) dup if dup then ;
: 2dup ( x y -- x y x y ) over over ;
: -rot ( x y z -- z x y ) rot rot ;
: 2drop ( x y -- ) drop drop ;
: nip ( x y -- y ) swap drop ;

: cell ( x -- cell-size*x ) 4 * ;
: cell+ ( x -- x+cell-size ) 1 cell + ;

: cr ( -- ) $a emit ;

: digit. ( x -- ) 48 + emit ;

: hex-digit. ( x -- ) dup 10 < if 48 + emit else 55 + emit then ;

: (hex.) ( x -- )
    ?dup if
        dup 4 rshift (hex.)
        $f and hex-digit.
    then ;

\ Print a hex word to stdout
: hex. ( x -- )
    dup if
        (hex.)
    else
        hex-digit.
    then ;

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

: main-loop ( -- )
    key emit cr 64 emit 65 emit cr halt ;

: boot ( -- ) main-loop ;
