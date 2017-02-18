#!/usr/bin/env perl6

sub is_immediate(Str $word) {
    return <; : if then>.contains($word) && $word;
}

#| Turn a Pact symbol to an assembler symbol
sub mangle(Str $s) {
    die("Mangling immediate word $s") if is_immediate($s);

    my %predef = <
        @ fetch
        ! store
        + plus
        - minus
        * times
    >;

    return %predef{$s} if %predef{$s};

    my $ret = $s;

    $ret = $ret.subst(/'-'/, '_');

    # '(foo)' => 'foo_aux'
    if $ret ~~ / '(' (.*) ')' / {
        $ret = $0 ~ '_aux';
    }

    die("Failed to sanitize $s") unless $ret ~~ /^<alpha><alnum>*$/;
    return $ret;
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

    plan 13;
    throws-like { EVAL q[mangle(':')] }, $, "Didn't filter out immediate word";
    throws-like { EVAL q[mangle('if')] }, $, "Didn't filter out immediate word";
    throws-like { EVAL q[mangle('')] }, $, "Didn't fail on empty word";
    is mangle('forklift'),  'forklift', "Don't match the 'if' immediate word inside";
    is mangle('foo'),       'foo';
    is mangle('_foo'),      '_foo';
    is mangle('foo_2'),      'foo_2';
    throws-like { EVAL q[mangle('2foo')] }, $, "Didn't fail on invalid initial char";
    is mangle('(foo)'),     'foo_aux';
    is mangle('foo-bar'),   'foo_bar';
    is mangle('+'),         'plus';
    is mangle('@'),         'fetch';
    throws-like { EVAL q[mangle('<..=-=..>')] }, $, "Didn't fail on unknown unconvertable word";
}
