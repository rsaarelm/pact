\ Bootstrap Pact code for the initial interpreter. Will be transpiled into symbolic assembly.
: < ( x y -- b ) - <0 ;
: <= ( x y -- b ) - 1 - <0 ;

: cell ( a -- cell-size*a ) 4 * ;
: cell+ ( a -- a+cell-size ) 1 cell + ;


: cr ( -- ) $a emit ;

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
    RCC-BASE $14 + dup @ 17 bit or swap ! \ GPIOA
    RCC-BASE $20 + dup @ 14 bit or swap ! \ USART1
    RCC-BASE $1C + dup @ 17 bit or swap ! \ USART2
;

: main-loop ( -- )
    $3f emit key emit cr led-on tail-recurse ;

: boot ( -- ) init-hw main-loop ;
