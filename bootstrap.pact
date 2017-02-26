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
: make-bits ( num-bits lshift -- 0bits ) 24 lshift swap 16 lshift or ;

: bits-mask ( bits -- zero-mask )
    dup 16 rshift $ff and 1 swap lshift 1 - swap 24 rshift lshift invert ;

: bits-value ( bits -- value ) dup $ff and swap 24 rshift lshift ;

: unpack-bits ( bits -- value zero-mask ) dup bits-value swap bits-mask ;

: apply-bits ( value bits -- value' ) unpack-bits rot and or ;

\ Apply bitstring to memory address, leave bits outside the string intact.
: bits! ( bits addr -- ) dup @ rot apply-bits swap ! ;

\\ Hardware logic

: GPIO-BASE $40020000 ;

\ turn a position into a bit mask
: bit ( x -- 2^x ) 1 swap lshift ;

\ combine GPIO port and pin to single pin identifier
: io ( gpio# pin# -- pin ) swap 8 lshift or ;

\ convert pin to bit position
: io# ( pin -- x ) $1f and ;

\ convert pin to gpio address
: io-base ( pin -- addr ) $f00 and 2 lshift GPIO-BASE + ;

\ GPIOA = 0, GPIOB = 1, ...

\ XXX: These should be compile-time constants, but we don't have real
\ compile-time eval in bootstrap stage.

: USART1-TX 0 9 io ;
: USART1-RX 0 10 io ;
: USART2-TX 0 2 io ;
: USART2-RX 0 3 io ;

: USER-LED 0 5 io ;

: RCC-BASE $40021000 ;

: start-clocks ( -- )
    1 17 make-bits 1 or  RCC-BASE $14 + bits! \ GPIOA
    1 14 make-bits 1 or  RCC-BASE $20 + bits! \ USART1
    1 17 make-bits 1 or  RCC-BASE $1C + bits! \ USART1
;

: main-loop ( -- )
    $3f emit key emit cr led-on tail-recurse ;

: boot ( -- ) start-clocks init-hw main-loop ;
