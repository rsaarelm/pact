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
        . dot
        1+ incr
        1- decr
        cell+ cell_inc
        and and_
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
    $ret = $ret.subst(/'?'/, 'p');
    $ret = $ret.subst(/'#'/, 'num');
    $ret = $ret.subst(/'>'/, 'to');
    $ret = $ret.subst(/'1'/, 'one');
    $ret = $ret.subst(/'2'/, 'two');

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
    my $current_word = False;
    my $current_sym = False;

    # TODO: put consecutive addrs (1:, 2:, ...) in jump stack when if or loop
    # words encountered.
    my @jump_stack;

    while @w {
        my $x = @w.pop();
        next if not $x;

        # Word definition.
        if $x eq ':' {
            die "Nested word definition" if $in_def;
            $current_word = @w.pop();
            $current_sym = mangle($current_word);
            defword($current_word, $current_sym);
            $in_def = True;
        } elsif $x eq ';' {
            die "Unmatched word end" unless $in_def;
            say '';
            $in_def = False;
            $current_word = False;
            $current_sym = False;
        } elsif $x eq 'tail-recurse' {
            # Recursion without expecting to return, emit a branch and don't add to stack.
            $current_sym or die("Recurse outside word definition");
            say '.long branch';
            say ".long ($current_sym - .)";
        } elsif $x eq 'recurse' {
            # Recursion without expecting to return, emit a branch and don't add to stack.
            $current_sym or die("Recurse outside word definition");
            say ".long $current_sym";
        # TODO: Handle conditionals and looping immediate words.
        } elsif $x.substr(0, 1) eq '%' and (my $parsed_binary_literal = $x.substr(1).parse-base(2)) ~~ Numeric {
            say ".long lit";
            say ".long $parsed_binary_literal";
        } elsif $x.substr(0, 1) eq '$' and (my $parsed_hex_literal = $x.substr(1).parse-base(16)) ~~ Numeric {
            say ".long lit";
            say ".long $parsed_hex_literal";
        } elsif (my $parsed_decimal_literal = +$x) ~~ Numeric {
            say ".long lit";
            say ".long $parsed_decimal_literal";
        } else {
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
    is mangle('foo_8'),      'foo_8';
    throws-like { EVAL q[mangle('8foo')] }, $, "Didn't fail on invalid initial char";
    is mangle('(foo)'),     'foo_aux';
    is mangle('foo-bar'),   'foo_bar';
    is mangle('+'),         'plus';
    is mangle('@'),         'fetch';
    throws-like { EVAL q[mangle('<..=-=..>')] }, $, "Didn't fail on unknown unconvertable word";
}
