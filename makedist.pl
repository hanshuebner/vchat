#!/usr/bin/perl

use FileHandle;
use strict;

sub findFiles
{
    my $dir = shift;
    if (defined $dir and $dir ne "") {
	$dir .= "/";
    }
    my @files;

#    print STDERR "DIR $dir\n";
    my $ENTRIES = new FileHandle("${dir}CVS/Entries");
    $ENTRIES or die "$0: can't open ${dir}CVS/Entries: $!\n";
    while (<$ENTRIES>) {
	chomp;
#	print STDERR "$dir: $_\n";
	my ($type, $file, $junk) = split(/\//);
	next if (not defined $file);
#	print "FILE [$type] $file\n";
	if ($type eq "") {
	    push @files, "${dir}".$file;
	} elsif ($type eq "D") {
	    push @files, findFiles($file);
	}
    }
    return @files;
}

my @files = findFiles();
print join("\n", @files), "\n";

