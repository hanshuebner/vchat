#!/usr/bin/perl -w -I/home/vchatd/vchat/server -

use strict;
use conf;

my $nick = shift @ARGV;

if (not defined $nick) {
    die "usage: $0 <nick>\n";
}

my @keys = split(/\n/, `cat $authorizedKeysFile`);

if (grep /"CHATNICK=$nick"/i, @keys) {
    warn "$0: \7\7\7warning: user $nick exists already\7\7\n";
}

my @key = <STDIN>;
my $key = shift @key;
$key =~ s/ *\n/ /;
foreach (@key) {
    chomp;
    if (/^\D/) {
	$key .= " ";	# cheap check for key id
    }
    $key .= $_;
}
    
print "[$key]\n";

open(KEYS, ">>$authorizedKeysFile")
    or die "$0: can't open $authorizedKeysFile for append: $!\n";
print KEYS "environment=\"CHATNICK=$nick\" $key\n";
close(KEYS);

print "$0: user $nick added\n";
