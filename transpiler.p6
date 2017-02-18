#!/usr/bin/env perl6

# Not using the macro in the main .S file because GAS keeps getting weird about
# stuff in the string macro argument.
sub defword(Str $word, Str $sym) {
say qq:to/END/;
.align 2
name_$sym:
    .long _latest_word
    .byte 0
    .asciz "$word"
_latest_word = name_$sym
.align 2
$sym:
    .long docol + 1
END
}

sub is_immediate(Str $word) {
    return <; : if then>.contains($word) && $word;
}

#| Turn a Pact symbol to an assembler symbol
sub mangle(Str $s) {
    die("Mangling immediate word $s") if is_immediate($s);

    my %predef = flat <
        @ fetch
        ! store
        + plus
        - minus
        * times
        = equals
        cell+ cell_inc
    >, (
        # Separate list for words that contain actual <, >.
        # Looks like they can be escaped with \ in the <..> list,
        # but the Vim syntax mode won't understand that and messes up the file.
        '<', 'lt',
        '<0', 'ltz',
        '<=', 'lte',
    );

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

sub emit(@words) {
    my @w = @words.reverse();

    my $in_def = False;

    while @w {
        my $x = @w.pop();
        next if not $x;

        # Word definition.
        if $x eq ':' {
            die "Nested word definition" if $in_def;
            my $word = @w.pop();
            my $sym = mangle($word);
            defword($word, $sym);
            $in_def = True;
        } elsif $x eq ';' {
            die "Unmatched word end" unless $in_def;
            say '';
            $in_def = False;
        } orwith +$x {
            # Number literal
            say ".long lit";
            say ".long $x";
        } else {
            # TODO: Handle immediate control words.
            my $sym = mangle($x);
            say ".long $sym";
        }
    }
}

sub MAIN(Bool :$test = False) {
    if ($test) {
        test();
    } else {
        emit(words());
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
