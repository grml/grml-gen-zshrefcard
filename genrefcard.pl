#!/usr/bin/perl -w
use strict;
#{{{ readme
### Author: Frank Terbeck <ft@bewatermyfriend.org>
###
### This file is free software: you can redistribute it and/or modify
### it under the terms of the GNU General Public License as published
### by the Free Software Foundation, either version 3 of the License,
### or (at your option) any later version.
###
### This file is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### GNU General Public License for more details.
###
### generate grml zsh refcard.
### #v#: variables
### #f#: functions
### #a#: aliases
### #k#: keybindings
### #A#: abbreviations
### #d#: hasheddirs
### #o#: other
###
### consider these lines in zshrc:
### #a3# execute \kbd{apt-cache policy}
### alias acp='apt-cache policy'
###
### Now this script will add a new description for 'acp' into
### the replacement list created by the @@INSERT-aliases-debian@@
### tag.
###
### @@INSERT-aliases-default@@ == @@INSERT-aliases@@
### @@INSERT-aliases-all@@ will create a sorted list of _all_
### aliases from all subsections.
###
### @@INSERT-other-foobar@@ is special, just does text replaces
### without any special formatting, useful for:
### \command{umask @@INSERT-other-umask@@}{...
### 'other' does not have -default nor -all.
###
### you may specify certain subsections like this:
### #a3#, which will put the input in the into the
### @@INSERT-aliases-debian@@ tag.
###
### See the @secmap array below for section numbers.
### Yes, this could be done with real names instead of numbers.
### But names tend to be rather long. I don't want that.
###
### This scripts works on quite some global variables, which is *not*
### a good idea most of the time. Thank god it's just a ~500 line script. :)
###
#}}}

### variables {{{
my $refin = "./grml-zsh-refcard.tex.in";
if (defined($ARGV[0]) && $ARGV[0] =~ m!^[^+]!) {
    $refin = shift;
}

my $MAX_INPUT=10000;
my $verbose = 0;

if (defined($ARGV[0])) {
    $verbose = length($ARGV[0]);
}
my @secmap = (
    "default",    #0
    "system",     #1
    "user",       #2
    "debian",     #3
    "search",     #4
    "shortcuts",  #5
    "services"    #6
);
my (
    $i,
    $ln,
    $inc,     # global counter for input lines
    @input,
    %data,    # HoA
    %other,   # @@INSERT-other-*@@
    %splits   # if lists get long, we might need to split them. HoA
);

my $splitstring="\\commandlistend\n\\pagebreak\n\\commandlistbegin";
###}}}
### subroutines {{{

sub dumpdata { #{{{
    my ($key, $entry);

    if ($verbose < 5) { return; }
    xprint(5, " --- Data ---\n");

    foreach $key (sort keys(%other)) {
        xprint(5, "    \@\@INSERT-other-$key\@\@ -> $other{$key}\n");
    }

    foreach $key (sort keys(%data)) {
        xprint(5, "    \@\@INSERT-$key\@\@ =>\n");
        foreach $entry (sort @{ $data{$key} }) {
            xprint(5, "$entry\n");
        }
    }

    foreach $key (sort keys(%splits)) {
        xprint(5, "    List-Splitting Offset for $key:\n");
        foreach $entry (@{ $splits{$key} }) {
            xprint(5, "$entry\n");
        }
    }
    xprint(5, " --- Dump ---\n");
}
#}}}
sub xprint { #{{{
    my $level = shift;

    if ($verbose >= $level) {
        print STDERR @_;
    }
}
#}}}
sub escape_string { #{{{
    my ($in) = @_;

    $in =~ s!([\\\{\}\*\&~\$_])!\\$1!g;
    return($in)
}
#}}}
sub demystify_keys { #{{{
    # what an ugly hack :-)
    my ($keys) = @_;
    my ($k, $out, @tok);

    @tok = split(/(\\e[^\^]|\^.)/, $keys);
    $out = '';
    foreach $k (@tok) {
        if ($k eq '') {
            next;
        }

        if ($k =~ m!^[^\\\^]!) {
            $k =~ s!(.)! $1!g;
        } else {
            $k =~ s!\\e!ESC-!g;
            $k =~ s!\^I!TAB!g;
            $k =~ s!\^[jJmM]!return!g;
            $k =~ s!\^!CTRL-!g;
        }
        $out .= $k;
    }

    return($out);
}
#}}}
sub insert { #{{{
    my ($linenum, $cat, $sec) = @_;
    my ($entry, $count);

    if ($sec eq '') {
        $sec = 'default';
    }

    if (!defined($data{"$cat-$sec"})) {
        warn("Unknown insertion tag in line $linenum (\@\@INSERT-$cat-$sec\@\@). IGNORING.\n");
        return;
    }

    xprint(1, "inserting: category($cat) section($sec), line: $linenum\n");

    $count = 0;
    foreach $entry (sort @{ $data{"$cat-$sec"} }) {
        my $is;

        foreach $is (@{ $splits{"$cat-$sec"} } ) {
            if ($count == $is) {
                print("$splitstring\n");
                last;
            }
        }
        print("$entry\n");
        $count++;
    }
}
#}}}
sub set_option { #{{{
    my ($optstring) = @_;
    my ($opt, $val);

    $ln++;
    if ($optstring =~ m!([a-zA-Z0-9_-]+)\s+(.*)!) {
        $opt = $1;
        $val = $2;
        if ($opt eq 'split') {
            if ($val =~ m!([a-zA-Z0-9_-]+)\s+(.*)!) {
                my $what = $1;
                my $when = $2;
                xprint(2, "  splitting values (for $what): " . join(' ', split(/,/, $when)) . "\n");
                @{ $splits{"$what"} } = split(/,/, $when);
            } else {
                warn("Parsing split option failed in line $ln. IGNORING.\n");
            }
        } else {
            warn("Unknown option ($opt) in line $ln. IGNORING.\n");
        }
    } else {
        warn("Parsing option in line $ln failed. IGNORING.\n");
    }
}
#}}}

sub handle { #{{{
    # name:     hashdir, abbrev etc.
    # wfuncref: reference to the function, that does the work
    # sec:      section number
    # desc:     description string
    my ($name, $wfuncref, $sec, $desc) = @_;

    if ($sec eq '') {
        $sec = 0;
    }

    xprint(1, "Handling $name (section: secmap[$sec]) in line $ln ($desc)\n");

    $ln++;
    if (!$wfuncref->($sec, $desc)) {
        warn("Broken $name in line $ln. IGNORING.\n");
    }
}
#}}}
sub handle_manual { #{{{
    # this is different than the other handle_*() subs.
    my ($code, $key, $value) = @_;
    my ($sec);

    xprint(1, "Handling manual entry (code: $code) in line $ln ($key -> $value)\n");

    $sec = ( (length($code) > 1) ? substr($code, 1) : 0);
    if      (substr($code, 0, 1) eq 'a') {
        push(@{ $data{"aliases-$secmap[$sec]"} }, "\\command\{$key\}\{$value\}");
    } elsif (substr($code, 0, 1) eq 'A') {
        push(@{ $data{"abbrev-$secmap[$sec]"} }, "\\command\{$key\}\{$value\}");
    } elsif (substr($code, 0, 1) eq 'd') {
        push(@{ $data{"hasheddirs-$secmap[$sec]"} }, "\\command\{$key\}\{$value\}");
    } elsif (substr($code, 0, 1) eq 'f') {
        push(@{ $data{"functions-$secmap[$sec]"} }, "\\command\{$key\}\{$value\}");
    } elsif (substr($code, 0, 1) eq 'k') {
        push(@{ $data{"keybindings-$secmap[$sec]"} }, "\\command\{$key\}\{$value\}");
    } elsif (substr($code, 0, 1) eq 'o') {
        push(@{ $data{"other-$secmap[$sec]"} }, "\\command\{$key\}\{$value\}");
    } elsif (substr($code, 0, 1) eq 'v') {
        push(@{ $data{"variables-$secmap[$sec]"} }, "\\command\{$key\}\{$value\}");
    } else {
        warn("Unknown doc-definition character in manual-line $ln ($1). IGNORING.\n");
        $ln++;
    }
    $ln++;
}
#}}}
sub handle_other { #{{{
    # a very simple handler
    my ($sec, $desc) = @_;

    $desc =~ m!([^\s]+)\s+(.*)!;
    xprint(1, "Handling 'other' tag in line $ln ($1 -> $2))\n");
    $other{$1} = $2;
    $ln++;
}
#}}}
sub __abbrev { #{{{
    my ($sec, $desc) = @_;
    my ($abbrev, $value, $doc);

    xprint(1, "$ln, $i\n");
    while ($ln <= $i) { # the global $i
        if ($input[$ln] =~ m!^\s*#A[0-9]*#!) {
            xprint(1, "Ending abbreviation handling in line $ln.\n");
            $ln++;
            return 1;
        }

        $doc = '';
        if ($input[$ln] =~ s/\s+\#d\s*([^#]*)$//) {
            $doc = $1;
        }

        if ($input[$ln] =~ m!^\s*['"]([^"']*)['"]\s+\$?['"]([^"']*)['"]!) {
            $abbrev = $1; $value = &escape_string($2);
            xprint(2, "ab: $abbrev -> $value ($doc);\n");
            push(@{ $data{"abbrev-$secmap[$sec]"} }, "\\command\{$abbrev\}\{\\kbd\{$value" . ($doc ne '' ? "\}\\quad $doc" : "\}") . "\}");
        } else {
            xprint(0, "Line didn't look like abbreviation in abbreviations section: " . $input[$ln] . "\n");
        }
        $ln++;
    }
    return 0;
}
#}}}
sub __alias { #{{{
    my ($sec, $desc) = @_;
    my ($alias, $value);

    if ($input[$ln] =~ m!\s*alias (-[haocC] +)*([^=]*)=["'](.*)["']!) {
        $alias=$2; $value=&escape_string($3);
        $desc =~ s!\@a\@!$value!;
        push(@{ $data{"aliases-$secmap[$sec]"} }, "\\command\{$alias\}\{$desc\}");
    } else {
        return 0;
    }

    return 1;
}
#}}}
sub __function { #{{{
    my ($sec, $desc) = @_;

    if ($input[$ln] =~ m!\s*(function)?\s*([^(\s]*)!) {
        xprint(2, "  - $2()\n");
        push(@{ $data{"functions-$secmap[$sec]"} }, "\\command\{$2()\}\{$desc\}");
    } else {
        return 0;
    }

    return 1;
}
#}}}
sub __hashdir { #{{{
    my ($sec, $desc) = @_;
    my ($dir, $value);

    while ($ln <= $i) {

        if ($input[$ln] =~ m/^\s*\#d[0-9]*\#/) {
            xprint(1, "Ending hashed dir handling in line $ln.\n");
            $ln++;
            return 1;
        }

        if ($input[$ln] =~ m!\s*hash\s+-d\s+([^=]+)=(.*)!) {
            $dir=$1; $value=&escape_string($2);
            push(@{ $data{"hasheddirs-$secmap[$sec]"} }, "\\command\{$dir\}\{$value\}");
        } else {
            return 0;
        }

        $ln++;
    }
    return 0;
}
#}}}
sub __keybinding { #{{{
    my ($sec, $desc) = @_;
    my ($kbd, $value);

    if ($input[$ln] =~ m!^.*bindkey\s+[^'"]*(.*)['"]\s+([\w-]*)\#?.*!) {
        ($kbd, $value) = ($1, $2);
        $value=&escape_string($value);
        $kbd =~ s!^["']!!;
        $kbd =~ s/["']$//;
        $kbd=&demystify_keys($kbd);
        $desc =~ s!\@k\@!$value!;

       #xprint(0, "!-> DEBUG: kbd: $kbd - value: $value - desc: $desc\n");

        push(@{ $data{"keybindings-$secmap[$sec]"} }, "\\command\{$kbd\}\{$desc\}");
    } elsif ($input[$ln] =~ m!^.*bind2maps\s+([^-])+--\s+(.*)!) {
        my ($maps, $rest) = ($1, $2);
        my (@a) = split /\s+/, $rest, 2;
        if ($a[0] ne q{-s}) {
            push(@{ $data{"keybindings-$secmap[$sec]"} },
                 "\\command\{$a[0]\}\{$desc\}");
            return 1;
        }
        my $seq;
        $rest = $a[1];
        if ($rest =~ m!^'([^']+)'\s+!) {
            $seq = $1;
        } elsif ($rest =~ m!^"([^"]+)"\s+!) {
            $seq = $1;
        } else {
            $seq = $rest;
        }
        $seq = demystify_keys($seq);
        push(@{ $data{"keybindings-$secmap[$sec]"} }, "\\command\{$seq\}\{$desc\}");
    } else {
        return 0;
    }

    return 1;
}
#}}}
sub __variable { #{{{
    my ($sec, $desc) = @_;
    my ($var, $value);

    if ($input[$ln] =~ m/\s*(\S+)=(.+)$/) {
        $var = $1 ; $value = $2;
        $value =~ s!^\$\{\w*:-(.*)\}!$1!;
        $value =~ s!^['"]!!;
        $value =~ s/['"]$//;
        $value = &escape_string($value);
        push(@{ $data{"variables-$secmap[$sec]"} }, "\\command\{$var\}\{\\kbd\{$value" . ($desc ne '' ? "\}\\quad $desc" : "\}") . "\}");
    } else {
        return 0;
    }

    return 1;
}
#}}}

###}}}

### main() {{{

### read our input from stdin {{{
$i = 0;
$input[0]='index==linenumber :-)';
while (<STDIN>) {
    $i++;
    if ($i > $MAX_INPUT) {
        die "Sorry dude, input lines exeeded maximum ($MAX_INPUT)}\n";
    }
    chomp;
    push(@input, $_);
}

# work on the lines in memory (jumping back and forth is simple this way)
$ln = 1;
while ($ln <= $i) {
    if ($input[$ln] =~ m/^\#\@\#\s*(.*)$/) {
        &set_option($1);
        next;
    }

    if ($input[$ln] =~ m/^\s*\#([a-zA-Z])([0-9]*)\#\s*(.*)$/) {
        if      ($1 eq 'a') {
            &handle("alias", \&__alias, $2, $3);
        } elsif ($1 eq 'A') {
            &handle("abbreviation", \&__abbrev, $2, $3);
        } elsif ($1 eq 'd') {
            &handle("hashed dir", \&__hashdir, $2, $3);
        } elsif ($1 eq 'f') {
            &handle("function", \&__function, $2, $3);
        } elsif ($1 eq 'k') {
            &handle("keybinding", \&__keybinding, $2, $3);
        } elsif ($1 eq 'v') {
            &handle("variable", \&__variable, $2, $3);
        } elsif ($1 eq 'o') {
            &handle_other($2, $3);
        } elsif ($1 eq 'm') {
            my $arg = $3;
            $arg =~ m!^\s*([a-zA-Z][0-9]*)\s+(\S+)\s+(.*)!;
            &handle_manual($1, $2, $3);
        } else {
            warn("Unknown doc-definition character in line $ln ($1). IGNORING.\n");
            $ln++;
        }
    } else {
        $ln++;
    }
}
#}}}

&dumpdata();

# read the .in file and put in stuff we gathered from stdin earlier
open(IN, "<$refin") or die "could not open $refin: $!\n";

#{{{ output loop
$i=0;
while (<IN>) {
    $i++;
    while (m!\@\@INSERT-other-[^@]+\@\@!) {
        s!\@\@INSERT-other-([^@]+)\@\@!$other{$1}!;
        xprint(2, "Inserting \@\@INSERT-other-$1\@\@ -> $other{$1}\n");
    }

    if (m!^\@\@INSERT-([^-]*)-?(.*)\@\@!) {
        if ($1 eq '') {
            die "malformed insertion tag in line $i ($_). ABORT\n";
        }

        &insert($i, $1, $2);
    } else {
        print;
    }
}
#}}}

close(IN);

#}}}
