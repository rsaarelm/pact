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


\\ Hardware logic

: GPIO-BASE $48000000 ;

\ combine GPIO port and pin to single pin identifier
: io ( gpio# pin# -- pin ) swap 8 lshift or ;

\ convert pin to bit position
: io# ( pin -- x ) $1f and ;

\ convert pin to gpio address
: io-base ( pin -- addr ) $f00 and 2 lshift GPIO-BASE + ;

\ Index for io (GPIOB is 1, GPIOC is 2 and so on..)
: GPIOA 0 ;

\ XXX: These should be compile-time constants, but we don't have real
\ compile-time eval in bootstrap stage.

: USART1-TX GPIOA  9 io ;
: USART1-RX GPIOA 10 io ;
: USART2-TX GPIOA  2 io ;
: USART2-RX GPIOA  3 io ;
: USER-LED  GPIOA  5 io ;

\ GPIO layout
\  $0: Port mode
\  $4: Output type
\  $8: Output speed
\  $C: Pullup/pulldown
\ $10: Input data
\ $14: Output data
\ $18: Bit set / reset
\ $1C: Alternate function low
\ $20: Alternate function high
\ $28: Port bit reset

: (gpio-mode) ( pin -- addr 0bits )
    dup io-base swap io# 2 * 2 make-bits ;
: (gpio-output) ( pin -- addr 0bits )
    dup io-base $4 + swap io# 1 make-bits ;
: (gpio-speed) ( pin -- addr 0bits )
    dup io-base $8 + swap io# 2 * 2 make-bits ;
: (gpio-pup) ( pin -- addr 0bits )
    dup io-base $C + swap io# 2 * 2 make-bits ;
: (gpio-set) ( pin -- addr 0bits )
    dup io-base $18 + swap io# 1 make-bits ;
: (gpio-clr) ( pin -- addr 0bits )
    dup io-base $18 + swap io# 16 + 1 make-bits ;
: (gpio-func) ( pin -- addr 0bits )
    dup io-base over io# 8 < if $1C else $20 then +
    swap io# 7 and 4 * 4 make-bits ;


\ Drive pin high
: gpio-set ( pin -- ) (gpio-set) 1 bits! ;

\ Drive pin low
: gpio-clr ( pin -- ) (gpio-clr) 1 bits! ;

: gpio-pushpull ( pin -- ) (gpio-output) 0 bits! ;

: gpio-pup-neither ( pin -- ) (gpio-pup) 0 bits! ;

: gpio-high-speed ( pin -- ) (gpio-speed) 3 bits! ;

: gpio-input ( pin -- ) (gpio-mode) 0 bits! ;

: gpio-output ( pin -- ) (gpio-mode) 1 bits! ;

: gpio-func ( pin func -- )
    swap dup (gpio-mode) 2 bits!        ( alternate mode )
    (gpio-func) rot bits! ;

: RCC-BASE $40021000 ;

: start-clocks ( -- )
    RCC-BASE $14 +  17 1 make-bits 1 bits! \ GPIOA
    RCC-BASE $18 +  14 1 make-bits 1 bits! \ USART1
    RCC-BASE $1C +  17 1 make-bits 1 bits! \ USART2
;

: init-gpio ( -- )
    USART2-TX 1 gpio-func
    USART2-TX gpio-high-speed
    USART2-TX gpio-pup-neither
    USART2-TX gpio-pushpull

    USART2-RX 1 gpio-func
    USART2-RX gpio-high-speed
    USART2-RX gpio-pup-neither
    USART2-RX gpio-pushpull

    USER-LED gpio-output
    USER-LED gpio-pup-neither
    USER-LED gpio-pushpull
;

: led ( on? -- ) if USER-LED gpio-set else USER-LED gpio-clr then ;

: main-loop ( -- )
    $3f emit key emit cr  1 + dup 1 and led  tail-recurse ;

: boot ( -- ) start-clocks init-hw 1 led 1 main-loop ;
