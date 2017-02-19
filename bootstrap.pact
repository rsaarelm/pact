\ Bootstrap Pact code for the initial interpreter. Will be transpiled into symbolic assembly.
: < ( x y -- b ) - <0 ;
: <= ( x y -- b ) - 1 - <0 ;

: cell ( a -- cell-size*a ) 4 * ;
: cell+ ( a -- a+cell-size ) 1 cell + ;


\\ Hardware logic

: GPIO-BASE $40020000 ;

\ turn a position into a bit mask
: bit ( x -- 2^x ) 1 swap lshift ;

\ combine GPIO port and pin to single identifier
: io ( gpio# pin# -- pin ) swap 8 lshift or ;

\ convert pin to bit position
: io# ( pin -- x ) $1f and ;
