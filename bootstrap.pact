\ Bootstrap Pact code for the initial interpreter. Will be transpiled into symbolic assembly.
: not ( x -- b ) 0 = ;
: < ( x y -- b ) - <0 ;
: <= ( x y -- b ) - 1 - <0 ;

: cell ( a -- cell-size*a ) 4 * ;
: cell+ ( a -- a+cell-size ) 1 cell + ;
