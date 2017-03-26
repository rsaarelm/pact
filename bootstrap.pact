\ Bootstrap Pact code for the initial interpreter. Will be
\ transpiled into symbolic assembly.

: ram-start ( -- addr ) $40000000 ;

\ Hardcoded RAM map (relative to ram-start):
\ 0x0000    return stack
\ 0x0100    word buffer
\ 0x0180    LAST the dictionary address of the last regular word
\ 0x0184    HERE (the variable, not the value)
\ 0x0188    LAST-IMMEDIATE the dictionary address of the last immediate word
\ 0x018C    IS-COMPILING? the runtime is currently in compiling instead of executing mode
\ 0x0190
\ 0x0194
\ 0x0198
\ ( reserved for global vars )
\ 0x0200    here (the value, write memory starts here)

\ ****************************** Logic, arithmetic and basic stack operations

: =0 ( x -- !x ) if 0 else -1 then ;
: <> ( x y -- x<>y ) = =0 ;
: < ( x y -- x<y ) - <0 ;
: <= ( x y -- x<=y ) - 1 - <0 ;
: >= ( x y -- x>=y ) swap <= ;
: invert ( x -- ~x ) -1 xor ;
: ?dup ( x -- x x | 0 ) dup if dup then ;
: 2dup ( x y -- x y x y ) over over ;
: -rot ( x y z -- z x y ) rot rot ;
: 2drop ( x y -- ) drop drop ;
: nip ( x y -- y ) swap drop ;

: 1+ ( x -- x+1 ) 1 + ;
: 1- ( x -- x+1 ) 1 - ;

\ ****************************** Bitstring operations

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

\ ****************************** Memory operations

: cell ( x -- cell-size*x ) 4 * ;
: cell+ ( x -- x+cell-size ) 1 cell + ;

\ Align the address to the next machine word boundary
: aligned ( addr -- word-aligned-addr )
    dup 3 invert and swap 3 and if cell+ then ;

\ Write word at HERE and increment HERE by word length
: , ( word -- ) here @ ! here @ cell+ here ! ;

\ Align HERE to word boundary
: align ( -- ) here @ aligned here ! ;

: (.s) ( addr -- )
    dup sp0 = if exit then
    dup @ .hex cr cell+ tail-recurse ;

\ Dump stack to stdout
: .s ( -- ) sp@ (.s) drop ;

: (dump) ( addr len n -- )
    dup 30 = if drop 0 cr then
    -rot
    dup =0 if drop drop drop exit then
    over c@ dup $10 < if 0 .hex then .hex
    1- swap 1+ swap rot 1+ tail-recurse ;

\ Dump memory
: dump ( addr len -- ) 0 (dump) cr ;

\ ****************************** Text processing

\ Some ASCII constants

: '\n' 10 ;
: bl 32 ;   \ Can't use ' ' because that would parse into two tokens
: '"' 34 ;
: '$' 36 ;
: '-' 45 ;
: '0' 48 ;
: '9' 57 ;
: '?' 63 ;
: 'A' 65 ;
: 'F' 70 ;
: '\' 92 ;

: cr ( -- ) '\n' emit ;

: .digit ( x -- ) '0' + emit ;

: .hex-digit ( x -- ) dup 10 < if '0' + emit else 10 - 'A' + emit then ;

: (.hex) ( x -- )
    ?dup if
        dup 4 rshift (.hex)
        $f and .hex-digit
    then ;

: (") ( ptr -- )
    key
    dup '"' = if drop 0 swap c! exit then   \ Closing quote
    dup '\' = if drop key then              \ Escape the next char for " in string
    over word-buffer-end? if nip 0 swap c!  \ Discard further input at buffer end
    else over c! 1+ then                    \ TODO: Throw error when hit buffer end
    tail-recurse ;

\ Read double quote delimited string from input
: " ( -- str ) word-buffer (") word-buffer ;

: ("len) ( n str -- n )
    dup c@ =0 if drop exit then
    1+ swap 1+ swap tail-recurse ;

\ String length
: "len ( str -- n ) 0 swap ("len) ;

: "copy ( src dest -- )
    over c@ over c!
    over c@ =0 if 2drop exit then
    1+ swap 1+ swap tail-recurse ;

\ Place string in stack to dictionary
: ", ( str -- ) dup "len 1+ swap here @ "copy here @ + here ! ;

\ Read string literal and place in directory. May leave HERE unaligned.
: ," ( -- ) " ", ;

\ Print a hex word to stdout
: .hex ( x -- )
    dup if
        (.hex)
    else
        .hex-digit
    then ;

: . ( x -- ) '$' emit .hex ;                 \ TODO: Support decimal

\ Print a string to stdout
: .str ( addr -- )
    dup c@ =0 if drop else
    dup c@ emit 1+ tail-recurse then ;

\ Return whether two strings are equal
: streq ( adr1 adr2 -- ? )
    2dup c@ swap c@
    2dup <> if 2drop 2drop 0 exit then
    drop =0 if 2drop -1 exit then
    1+ swap 1+ tail-recurse ;

\ Move to byte address one past the terminating zero for string.
: string-end ( adr -- end-adr )
    dup c@ =0 if 1+ else 1+ tail-recurse then ;

: whitespace? ( key -- ? )
    dup bl = if drop -1 exit then
    dup '\n' = if drop -1 exit then
    drop 0 ;

\ ****************************** Machine interface

: emit ( char -- ) $E0000000 ! ;

: key ( -- c ) $E0000000 @ ;

: halt ( -- ) 1 $E000E020 ! ;

\ ****************************** Vocabulary operations

: (find-word) ( str vocab-ptr -- vocab-ptr T | str F )
    dup =0 if drop 0 exit then
    2dup word-name streq if nip -1 exit then
    @ tail-recurse ;

: find-word ( str -- vocab-ptr T | str F ) last @ (find-word) ;

: word-name ( vocab-ptr -- name-ptr ) cell+ 1+ ;

: word-code ( vocab-ptr -- code-addr ) word-name string-end aligned ;

: (words) ( vocab-ptr -- )
    ?dup if dup word-name .str $20 emit @ tail-recurse then ;

\ Dump vocabulary
: words ( -- ) last @ (words) cr ;

\ ****************************** Input parsing

: word-buffer ( -- ptr ) ram-start $100 + ;
: word-buffer-len ( -- n ) $80 ;

: word-buffer-end? ( ptr -- ? ) word-buffer word-buffer-len + 1 - >= ;

: (read) ( ptr -- )
    dup word-buffer-end? if 0 swap c! exit then
    key dup whitespace? if drop 0 swap c! exit then
    over c! 1+ tail-recurse ;

\ Read a word into input buffer, stops at first whitespace char
: read ( -- str )
    word-buffer (read)
    word-buffer ;

\ If str begins with '-', increment str by 1 byte and push -1 to stack,
\ otherwise leave str intact and push 1 to stack.
: (sign) ( str -- 1/-1 str' ) dup c@ '-' = if 1+ -1 else 1 then swap ;

: digit? ( c -- ? ) dup '0' >= swap '9' <= and ;

: hex-digit? ( c -- ? ) dup digit? swap dup 'A' >= swap 'F' <= and or ;

: >hex-digit ( c -- F | n T )
    dup hex-digit? if
    dup 'A' >= if 7 - then              \ Bring on top of the ASCII decimals
    '0' - -1 else drop 0 then ;

: (>hex-number) ( str n -- F | n T )
    over c@ =0 if nip -1 exit then
    over c@ >hex-digit if swap $10 * + swap 1+ swap tail-recurse then
    2drop 0 ;

: >hex-number ( str -- F | n T )
    (sign) 0 (>hex-number) if * -1 else 2drop 0 then ;

: >digit ( c -- F | n T )
    dup digit? if '0' - -1 else drop 0 then ;

: (>number) ( str n -- F | n T )
    over c@ =0 if nip -1 exit then
    over c@ >digit if swap 10 * + swap 1+ swap tail-recurse then
    2drop 0 ;

: >number ( str -- F | n T )
    dup c@ '$' = if 1+ >hex-number exit then
    (sign) 0 (>number) if * -1 else 2drop 0 then ;

\ ****************************** Compiling and interpreting

: is-compiling? ( -- ? ) is-compiling @ ;

\ Return whether dictionary word is an immediate word
: immediate? ( vocab-ptr -- ? ) cell+ c@ $20 and ;

\ Tag last word defined as immediate
\ NB: Won't work if LAST points to a word in ROM
: immediate! ( -- )
    last cell+ dup c@ $20 or swap c! ;

: handle-word ( vocab-ptr -- )
    dup immediate? is-compiling? invert or if
        word-code execute
    else word-code ,        \ If compiling, write words to memory
    then ;

: interpret ( -- )
    read
    find-word if handle-word exit then
    >number if handle-number exit then
    \ Error message otherwise
    '?' emit cr ;

\ Read word from input and find its address in directory
: ' ( -- addr ) read find-word if else nip then ;
\ XXX: This should be immediate word but we don't support that yet...

\ ****************************** Startup word

: boot ( -- ) interpret tail-recurse ;
