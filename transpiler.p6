#!/usr/bin/env perl6

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
