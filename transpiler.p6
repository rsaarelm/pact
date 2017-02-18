#!/usr/bin/env perl6

#| Turn a Pact symbol to an assembler symbol
sub mangle(Str $s) {
    die("Mangling immediate word $s") if $s ~~ m/ ';' || ':' || 'if' || 'then' /;

    # TODO: convert foo-bar to foo_bar
    # TODO: Match with special dictionary, '@' -> 'fetch' etc.
    # TODO: convert (xyzzy) to xyzzy_aux
    return $s;
}

sub words() {
    return gather for lines() {
        my $in_comment = False;

        for $_.split(/\s+/) {
            last if $_ ~~ m/ '\\' /;                # \: Comment to end of line

            $in_comment = True if $_ ~~ m/ '(' /;   # (: Start inline comment

            take $_ if not $in_comment;

            $in_comment = False if $_ ~~ m/ ')' /;  # ): End inline comment (must be whitespace-separated)
        }
    };
}

sub MAIN(Bool :$test = False) {
    if ($test) {
        test();
    } else {
        for words() { .say }
    }
}

sub test() {
    use Test;

    plan 10;
    throws-like { EVAL q[mangle(':')] }, $, "Didn't filter out immediate word";
    throws-like { EVAL q[mangle('if')] }, $, "Didn't filter out immediate word";
    is mangle(''),          '';
    is mangle('foo'),       'foo';
    is mangle('forklift'),  'forklift', "Don't match the 'if' immediate word inside";
    is mangle('(foo)'),     'foo_aux';
    is mangle('foo-bar'),   'foo_bar';
    is mangle('+'),         'plus';
    is mangle('@'),         'fetch';
    throws-like { EVAL q[mangle('<..=-=..>')] }, $, "Didn't fail on unknown unconvertable word";
}
