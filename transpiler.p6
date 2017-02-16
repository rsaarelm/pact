#!/usr/bin/env perl6

#| Turn a Pact symbol to an assembler symbol
sub mangle(Str $s) {
    die("Mangling immediate word $s") if $s ~~ m/ ';' || ':' || 'if' || 'then' /;

    # TODO: convert foo-bar to foo_bar
    # TODO: Match with special dictionary, '@' -> 'fetch' etc.
    # TODO: convert (xyzzy) to xyzzy_aux
}

my @words = gather for lines() {
    my $in_comment = False;

    for $_.split(/\s+/) {
        last if $_ ~~ m/ '\\' /;                # Comment to end of line

        $in_comment = True if $_ ~~ m/ '(' /;   # Start inline comment

        take $_ if not $in_comment;

        $in_comment = False if $_ ~~ m/ ')' /;  # End inline comment (NB must have ')' as separated token)
    }
}

for @words { .say }
